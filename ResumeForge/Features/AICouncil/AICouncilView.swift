import SwiftUI

struct AICouncilView: View {
    @State private var viewModel: AICouncilViewModel
    @State private var showAnalyses = false

    let onGenerateResume: () -> Void

    init(profile: UserProfile, jobDescription: JobDescription, onGenerateResume: @escaping () -> Void = {}) {
        _viewModel = State(initialValue: AICouncilViewModel(profile: profile, jobDescription: jobDescription))
        self.onGenerateResume = onGenerateResume
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    preAnalysisPanel
                    if viewModel.orchestrator.analysisPhase == .analyzing {
                        analysisPhasePanel
                    }
                    if viewModel.orchestrator.analysisPhase == .synthesizing {
                        synthesisPanel
                    }
                    if viewModel.orchestrator.analysisPhase == .complete {
                        resultsPanel
                    }
                }
                .padding()
            }
            .navigationTitle("AI Council")
            .toolbar {
                if viewModel.orchestrator.analysisPhase == .analyzing || viewModel.orchestrator.analysisPhase == .synthesizing {
                    ToolbarItem(placement: .automatic) {
                        Button("Cancel") { viewModel.cancel() }
                    }
                }
            }
        }
    }

    private var preAnalysisPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Pre-Analysis")
                .font(.headline)
            Text("Profile: \(viewModel.profile.fullName.isEmpty ? "Unnamed Profile" : viewModel.profile.fullName)")
            Text("Job: \(viewModel.jobDescription.displayTitle)")
            Text("Active providers: \(viewModel.activeProviders.count)")
            Text("Estimated tokens: input \(viewModel.estimate.estimatedInputTokens), output \(viewModel.estimate.estimatedOutputTokens)")
            Text(String(format: "Estimated cost: $%.4f", viewModel.estimate.estimatedCostUSD))
                .font(.subheadline.weight(.semibold))

            if !viewModel.hasConfiguredProviders {
                Text("No compatible AI providers configured. Add OpenAI, Anthropic, or Gemini keys in Settings.")
                    .foregroundStyle(.orange)
            }

            Button("Convene the Council") { viewModel.conveneCouncil() }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.hasConfiguredProviders)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private var analysisPhasePanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Analysis Phase")
                .font(.headline)
            ForEach(viewModel.orchestrator.providerProgress) { progress in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label(progress.provider.displayName, systemImage: icon(for: progress.provider))
                        Spacer()
                        statusIndicator(progress.status)
                    }
                    Text(progress.streamedText.isEmpty ? "Waiting for response..." : progress.streamedText)
                        .font(.caption)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                    HStack {
                        if let latency = progress.latency {
                            Text(String(format: "Elapsed: %.1fs", latency))
                        }
                        if let tokens = progress.tokensUsed {
                            Text("Tokens: \(tokens)")
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
                .padding()
                .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var synthesisPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Synthesizing recommendations...")
                .font(.headline)
            ProgressView()
            Text(viewModel.orchestrator.synthesisText)
                .font(.caption)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private var resultsPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Unified Recommendations")
                .font(.headline)

            recommendationSection(title: "Critical")
            recommendationSection(title: "Important")
            recommendationSection(title: "Nice to Have")

            DisclosureGroup("Individual Analyses", isExpanded: $showAnalyses) {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(viewModel.orchestrator.analyses.enumerated()), id: \.offset) { _, analysis in
                        VStack(alignment: .leading, spacing: 6) {
                            Text("\(analysis.provider.displayName) · \(analysis.model)")
                                .font(.subheadline.weight(.semibold))
                            Text(analysis.content)
                                .font(.caption)
                                .textSelection(.enabled)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            Text("Total tokens used: \(viewModel.orchestrator.totalTokensUsed)")
                .font(.caption)

            Button("Generate Resume", action: onGenerateResume)
                .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private func recommendationSection(title: String) -> some View {
        if let items = viewModel.groupedRecommendations[title], !items.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                ForEach(items) { recommendation in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(recommendation.suggestion)
                            .font(.subheadline)
                        if !recommendation.agreedModels.isEmpty {
                            Text("Agreed by: \(recommendation.agreedModels.joined(separator: ", "))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Button("Apply to Resume") {
                            viewModel.applyRecommendation(recommendation)
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                    .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    @ViewBuilder
    private func statusIndicator(_ status: ModelRunState) -> some View {
        switch status {
        case .pending, .streaming:
            ProgressView()
        case .finished:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .failed:
            Image(systemName: "xmark.octagon.fill").foregroundStyle(.red)
        }
    }

    private func icon(for provider: LLMProvider) -> String {
        switch provider {
        case .openAI: return "sparkles"
        case .anthropic: return "brain.head.profile"
        case .gemini: return "diamond.fill"
        case .openRouter: return "point.3.connected.trianglepath.dotted"
        case .ollama: return "cpu"
        }
    }
}

#Preview {
    AICouncilView(profile: UserProfile(), jobDescription: JobDescription())
}
