import Foundation

struct CostEstimate: Sendable {
    let estimatedInputTokens: Int
    let estimatedOutputTokens: Int
    let estimatedCostUSD: Double
    let breakdown: [(provider: LLMProvider, cost: Double)]
}

enum TokenCostEstimator {
    private struct Pricing {
        let inputPerMillion: Double
        let outputPerMillion: Double
    }

    private static let pricingTable: [LLMProvider: Pricing] = [
        .openAI: Pricing(inputPerMillion: 2.50, outputPerMillion: 10.00),
        .anthropic: Pricing(inputPerMillion: 3.00, outputPerMillion: 15.00),
        .gemini: Pricing(inputPerMillion: 0.075, outputPerMillion: 0.30)
    ]

    static func estimate(
        profile: UserProfile,
        jobDescription: JobDescription,
        activeProviders: [LLMProvider]
    ) -> CostEstimate {
        let promptBody = CouncilPrompts.buildAnalysisUserPrompt(profile: profile, jobDescription: jobDescription)
        let estimatedPromptTokens = max(1, promptBody.count / 4)
        let estimatedOutputPerProvider = max(400, Int(Double(estimatedPromptTokens) * 0.6))

        let estimatedInputTokens = estimatedPromptTokens * activeProviders.count
        let estimatedOutputTokens = estimatedOutputPerProvider * activeProviders.count

        let breakdown = activeProviders.map { provider in
            let pricing = pricingTable[provider] ?? Pricing(inputPerMillion: 2.5, outputPerMillion: 10.0)
            let inputCost = (Double(estimatedPromptTokens) / 1_000_000.0) * pricing.inputPerMillion
            let outputCost = (Double(estimatedOutputPerProvider) / 1_000_000.0) * pricing.outputPerMillion
            return (provider: provider, cost: inputCost + outputCost)
        }

        let totalCost = breakdown.reduce(0.0) { $0 + $1.cost }

        return CostEstimate(
            estimatedInputTokens: estimatedInputTokens,
            estimatedOutputTokens: estimatedOutputTokens,
            estimatedCostUSD: totalCost,
            breakdown: breakdown
        )
    }
}
