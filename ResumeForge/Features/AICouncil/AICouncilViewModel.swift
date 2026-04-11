import Foundation

@MainActor
@Observable
final class AICouncilViewModel {
    let profile: UserProfile
    let jobDescription: JobDescription

    var orchestrator = CouncilOrchestrator()
    var appliedRecommendations: Set<UUID> = []
    var selectedSynthesizerIndex: Int = 0

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

    /// Names shown in the Head of Council picker.
    /// Single-key mode shows persona names; multi-key shows provider display names.
    var synthesizerOptions: [String] {
        if activeProviders.count == 1 {
            return CouncilPrompts.singleKeyPersonas.map(\.label)
        }
        return activeProviders.map(\.displayName)
    }

    var estimate: CostEstimate {
        TokenCostEstimator.estimate(profile: profile, jobDescription: jobDescription, activeProviders: activeProviders)
    }

    var groupedRecommendations: [String: [CouncilRecommendation]] {
        Dictionary(grouping: orchestrator.recommendations) { $0.priority }
    }

    func conveneCouncil() {
        orchestrator.synthesizerIndex = selectedSynthesizerIndex
        orchestrator.conveneCouncil(profile: profile, jobDescription: jobDescription)
    }

    func cancel() {
        orchestrator.cancel()
    }

    func applyRecommendation(_ recommendation: CouncilRecommendation) {
        appliedRecommendations.insert(recommendation.id)
    }
}
