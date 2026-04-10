import Foundation
import Testing
@testable import ResumeForge

@Suite("AI Council")
@MainActor
struct AICouncilTests {
    @Test("token estimation uses 4-char heuristic")
    func tokenCountHeuristic() {
        let service = MockLLMService(provider: .openAI)
        let tokens = service.estimateTokenCount(text: "12345678")
        #expect(tokens == 2)
    }

    @Test("cost estimator returns provider breakdown")
    func costEstimation() {
        let profile = sampleProfile()
        let job = sampleJob()

        let estimate = TokenCostEstimator.estimate(
            profile: profile,
            jobDescription: job,
            activeProviders: [.openAI, .anthropic, .gemini]
        )

        #expect(estimate.estimatedInputTokens > 0)
        #expect(estimate.estimatedOutputTokens > 0)
        #expect(estimate.estimatedCostUSD > 0)
        #expect(estimate.breakdown.count == 3)
    }

    @Test("analysis prompt uses XML structure")
    func promptTemplateXML() {
        let prompt = CouncilPrompts.buildAnalysisUserPrompt(profile: sampleProfile(), jobDescription: sampleJob())

        #expect(prompt.contains("<analysis_request>"))
        #expect(prompt.contains("<candidate_profile>"))
        #expect(prompt.contains("<target_job>"))
    }

    @Test("orchestrator transitions idle-analyzing-synthesizing-complete")
    func orchestratorTransitions() async throws {
        let services: [CouncilServiceDescriptor] = [
            .init(provider: .openAI, model: "gpt-4o", service: MockLLMService(provider: .openAI, chunks: ["A1", "A2"])),
            .init(provider: .anthropic, model: "claude-sonnet", service: MockLLMService(provider: .anthropic, chunks: ["B1", "B2"]))
        ]

        let orchestrator = CouncilOrchestrator(serviceDescriptorsProvider: { services })
        orchestrator.conveneCouncil(profile: sampleProfile(), jobDescription: sampleJob())

        try await waitUntil(timeoutSeconds: 1.0) {
            await MainActor.run {
                orchestrator.analysisPhase != .idle
            }
        }

        #expect(orchestrator.analysisPhase == .analyzing || orchestrator.analysisPhase == .synthesizing || orchestrator.analysisPhase == .complete)

        try await waitUntil(timeoutSeconds: 2.0) {
            await MainActor.run {
                if case .complete = orchestrator.analysisPhase {
                    return true
                }
                return false
            }
        }

        if case .complete = orchestrator.analysisPhase {
            #expect(!orchestrator.analyses.isEmpty)
        } else {
            Issue.record("Expected orchestrator to reach complete phase")
        }
    }
}

private func sampleProfile() -> UserProfile {
    let profile = UserProfile(fullName: "Jane Doe", email: "jane@example.com", summary: "iOS Engineer", skills: ["Swift", "SwiftUI", "Testing"])
    profile.experiences = [
        Experience(company: "Acme", title: "iOS Engineer", jobDescription: "Built shipping apps", bulletPoints: ["Improved onboarding conversion by 22%"])
    ]
    profile.education = [
        Education(institution: "University", degree: "BSc", field: "Computer Science")
    ]
    return profile
}

private func sampleJob() -> JobDescription {
    JobDescription(
        title: "Senior iOS Engineer",
        company: "Example Corp",
        rawText: "Looking for Swift, SwiftUI, architecture leadership, and testing discipline.",
        extractedSkills: ["Swift", "SwiftUI", "Testing", "Architecture"]
    )
}

private func waitUntil(timeoutSeconds: TimeInterval, condition: @escaping @Sendable () async -> Bool) async throws {
    let start = Date()
    while Date().timeIntervalSince(start) < timeoutSeconds {
        if await condition() { return }
        try await Task.sleep(nanoseconds: 20_000_000)
    }
    throw CancellationError()
}

private struct MockLLMService: LLMServiceProtocol {
    let provider: LLMProvider
    var chunks: [String] = ["mock"]

    func sendMessage(prompt: String, systemPrompt: String, model: String, maxTokens: Int) async throws -> LLMResponse {
        LLMResponse(content: chunks.joined(), model: model, provider: provider, tokensUsed: estimateTokenCount(text: chunks.joined()), latency: 0.01)
    }

    func estimateTokenCount(text: String) -> Int {
        max(1, text.count / 4)
    }

    func streamMessage(prompt: String, systemPrompt: String, model: String, maxTokens: Int) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                for chunk in chunks {
                    continuation.yield(chunk)
                }
                continuation.finish()
            }
        }
    }
}
