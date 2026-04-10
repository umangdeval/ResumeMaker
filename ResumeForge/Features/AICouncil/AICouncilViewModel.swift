import Foundation

@MainActor
@Observable
final class AICouncilViewModel {
    let profile: UserProfile
    let jobDescription: JobDescription

    var orchestrator = CouncilOrchestrator()
    var appliedRecommendations: Set<UUID> = []

    init(profile: UserProfile, jobDescription: JobDescription) {
        self.profile = profile
        self.jobDescription = jobDescription
    }

    var activeProviders: [LLMProvider] {
        orchestrator.configuredProviders()
    }

    var hasConfiguredProviders: Bool {
        !activeProviders.isEmpty
    }

    var estimate: CostEstimate {
        TokenCostEstimator.estimate(profile: profile, jobDescription: jobDescription, activeProviders: activeProviders)
    }

    var groupedRecommendations: [String: [CouncilRecommendation]] {
        Dictionary(grouping: orchestrator.recommendations) { $0.priority }
    }

    func conveneCouncil() {
        orchestrator.conveneCouncil(profile: profile, jobDescription: jobDescription)
    }

    func cancel() {
        orchestrator.cancel()
    }

    func applyRecommendation(_ recommendation: CouncilRecommendation) {
        appliedRecommendations.insert(recommendation.id)
    }
}
