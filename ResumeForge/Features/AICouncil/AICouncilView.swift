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
                    header
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
                .appContentWidth()
            }
            .appScreenBackground()
            .navigationTitle("AI Council")
            .tint(AppTheme.blue)
            .toolbar {
                if viewModel.orchestrator.analysisPhase == .analyzing || viewModel.orchestrator.analysisPhase == .synthesizing {
                    ToolbarItem(placement: .automatic) {
                        Button("Cancel") { viewModel.cancel() }
                    }
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("AI Council")
                .font(AppTheme.heroTitle)
                .foregroundStyle(AppTheme.text)
            Text("Parallel model analysis followed by one unified synthesis.")
                .font(AppTheme.body)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var preAnalysisPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Pre-Analysis")
                .font(AppTheme.sectionTitle)
                .foregroundStyle(AppTheme.text)
            Text("Profile: \(viewModel.profile.fullName.isEmpty ? "Unnamed Profile" : viewModel.profile.fullName)")
                .foregroundStyle(AppTheme.text)
            Text("Job: \(viewModel.jobDescription.displayTitle)")
                .foregroundStyle(AppTheme.text)
            Text("Active providers: \(viewModel.activeProviders.count)")
                .foregroundStyle(AppTheme.text)
            Text("Estimated tokens: input \(viewModel.estimate.estimatedInputTokens), output \(viewModel.estimate.estimatedOutputTokens)")
                .foregroundStyle(AppTheme.text)
            Text(String(format: "Estimated cost: $%.4f", viewModel.estimate.estimatedCostUSD))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.text)

            if !viewModel.hasConfiguredProviders {
                Text("No compatible AI providers configured. Add OpenAI, Anthropic, or Gemini keys in Settings.")
                    .foregroundStyle(.orange)
            }

            if viewModel.synthesizerOptions.count > 1 {
                Picker("Head of Council", selection: $viewModel.selectedSynthesizerIndex) {
                    ForEach(Array(viewModel.synthesizerOptions.enumerated()), id: \.offset) { i, name in
                        Text(name).tag(i)
                    }
                }
                .pickerStyle(.menu)
                .tint(AppTheme.blue)
            }

            Button("Convene the Council") { viewModel.conveneCouncil() }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.blue)
                .disabled(!viewModel.hasConfiguredProviders)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
    }

    private var analysisPhasePanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Analysis Phase")
                .font(AppTheme.sectionTitle)
                .foregroundStyle(AppTheme.text)
            ForEach(viewModel.orchestrator.providerProgress) { progress in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label(progress.displayName, systemImage: icon(for: progress.provider))
                        Spacer()
                        statusIndicator(progress.status)
                    }
                    Text(progress.streamedText.isEmpty ? "Waiting for response..." : progress.streamedText)
                        .font(.caption)
                        .foregroundStyle(AppTheme.text)
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
                .appCard(cornerRadius: 8)
            }
        }
        .padding(16)
        .appCard()
    }

    private var synthesisPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Synthesizing recommendations...")
                .font(AppTheme.sectionTitle)
                .foregroundStyle(AppTheme.text)
            ProgressView()
                .tint(AppTheme.blue)
            Text(viewModel.orchestrator.synthesisText)
                .font(.caption)
                .foregroundStyle(AppTheme.text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .padding()
        .appCard()
    }

    private var resultsPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Unified Recommendations")
                .font(AppTheme.sectionTitle)
                .foregroundStyle(AppTheme.text)

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
                .foregroundStyle(AppTheme.textSecondary)

            Button("Generate Resume", action: onGenerateResume)
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.blue)
        }
        .padding()
        .appCard()
    }

    @ViewBuilder
    private func recommendationSection(title: String) -> some View {
        if let items = viewModel.groupedRecommendations[title], !items.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppTheme.text)
                ForEach(items) { recommendation in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(recommendation.suggestion)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.text)
                        if !recommendation.agreedModels.isEmpty {
                            Text("Agreed by: \(recommendation.agreedModels.joined(separator: ", "))")
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        Button("Apply to Resume") {
                            viewModel.applyRecommendation(recommendation)
                        }
                        .buttonStyle(.bordered)
                        .tint(AppTheme.blue)
                    }
                    .padding()
                    .appCard(cornerRadius: 8)
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
