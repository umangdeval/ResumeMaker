import Foundation

enum CouncilPhase: Equatable {
    case idle
    case analyzing
    case synthesizing
    case complete
    case error(String)
}

enum ModelRunState: Equatable {
    case pending
    case streaming
    case finished
    case failed(String)
}

struct ProviderRunProgress: Identifiable, Equatable {
    let id: UUID
    let provider: LLMProvider
    let model: String
    var label: String?          // persona label in single-key mode, nil otherwise
    var streamedText: String
    var latency: TimeInterval?
    var tokensUsed: Int?
    var status: ModelRunState

    var displayName: String { label ?? provider.displayName }
}

struct CouncilRecommendation: Identifiable, Equatable {
    let id = UUID()
    let priority: String
    let suggestion: String
    let agreedModels: [String]
}

@MainActor
@Observable
final class CouncilOrchestrator {
    var analysisPhase: CouncilPhase = .idle
    var providerProgress: [ProviderRunProgress] = []
    var synthesisText: String = ""
    var analyses: [LLMResponse] = []
    var recommendations: [CouncilRecommendation] = []
    var totalTokensUsed: Int = 0
    var synthesizerIndex: Int = 0   // which descriptor acts as Head of Council

    private let serviceDescriptorsProvider: @Sendable () -> [CouncilServiceDescriptor]
    private var activeTask: Task<Void, Never>?

    init(serviceDescriptorsProvider: (@Sendable () -> [CouncilServiceDescriptor])? = nil) {
        self.serviceDescriptorsProvider = serviceDescriptorsProvider ?? { Self.defaultServiceDescriptors() }
    }

    func configuredProviders() -> [LLMProvider] {
        serviceDescriptorsProvider().map(\.provider)
    }

    func cancel() {
        activeTask?.cancel()
        activeTask = nil
        analysisPhase = .idle
    }

    func conveneCouncil(profile: UserProfile, jobDescription: JobDescription) {
        cancel()

        activeTask = Task {
            do {
                try Task.checkCancellation()
                analysisPhase = .analyzing
                synthesisText = ""
                analyses = []
                recommendations = []
                totalTokensUsed = 0

                let rawDescriptors = serviceDescriptorsProvider()
                let descriptors: [CouncilServiceDescriptor]
                if rawDescriptors.count == 1 {
                    // Single-key mode: run 3 persona perspectives on the one available model
                    let base = rawDescriptors[0]
                    descriptors = CouncilPrompts.singleKeyPersonas.map { persona in
                        CouncilServiceDescriptor(
                            provider: base.provider,
                            model: base.model,
                            service: base.service,
                            systemPromptOverride: persona.systemPrompt,
                            label: persona.label
                        )
                    }
                } else {
                    descriptors = rawDescriptors
                }

                providerProgress = descriptors.map {
                    ProviderRunProgress(
                        id: $0.id,
                        provider: $0.provider,
                        model: $0.model,
                        label: $0.label,
                        streamedText: "",
                        latency: nil,
                        tokensUsed: nil,
                        status: .pending
                    )
                }

                let analysisPrompt = CouncilPrompts.buildAnalysisUserPrompt(profile: profile, jobDescription: jobDescription)
                let analysisResponses = try await runParallelAnalyses(descriptors: descriptors, prompt: analysisPrompt)

                try Task.checkCancellation()
                analyses = analysisResponses
                totalTokensUsed += analysisResponses.compactMap(\.tokensUsed).reduce(0, +)
                analysisPhase = .synthesizing

                let synthesizer = resolveSynthesizer(from: descriptors)
                let synthesisPrompt = CouncilPrompts.buildSynthesisUserPrompt(analyses: analysisResponses)
                let synthesis = try await runSynthesisStream(descriptor: synthesizer, prompt: synthesisPrompt)

                try Task.checkCancellation()
                totalTokensUsed += synthesis.tokensUsed ?? 0
                synthesisText = synthesis.content
                recommendations = parseRecommendations(from: synthesis.content)
                analysisPhase = .complete
            } catch is CancellationError {
                analysisPhase = .idle
            } catch {
                analysisPhase = .error(error.localizedDescription)
            }
        }
    }

    private func runParallelAnalyses(
        descriptors: [CouncilServiceDescriptor],
        prompt: String
    ) async throws -> [LLMResponse] {
        try await withThrowingTaskGroup(of: LLMResponse.self) { group in
            for descriptor in descriptors {
                group.addTask {
                    try await Self.consumeProviderStream(
                        service: descriptor.service,
                        descriptor: descriptor,
                        prompt: prompt,
                        systemPrompt: CouncilPrompts.analysisSystemPrompt,
                        onChunk: { chunk in
                            await MainActor.run {
                                self.appendChunk(chunk, for: descriptor.id)
                            }
                        },
                        onStatusChange: { status, latency, tokens in
                            await MainActor.run {
                                self.updateStatus(status, latency: latency, tokens: tokens, for: descriptor.id)
                            }
                        }
                    )
                }
            }

            var responses: [LLMResponse] = []
            for try await response in group {
                responses.append(response)
            }
            return responses
        }
    }

    private func runSynthesisStream(
        descriptor: CouncilServiceDescriptor,
        prompt: String
    ) async throws -> LLMResponse {
        var text = ""
        let startedAt = Date()

        for try await chunk in descriptor.service.streamMessage(
            prompt: prompt,
            systemPrompt: CouncilPrompts.synthesisSystemPrompt,
            model: descriptor.model,
            maxTokens: 2_500
        ) {
            try Task.checkCancellation()
            text += chunk
            synthesisText = text
        }

        return LLMResponse(
            content: text,
            model: descriptor.model,
            provider: descriptor.provider,
            tokensUsed: descriptor.service.estimateTokenCount(text: text),
            latency: Date().timeIntervalSince(startedAt)
        )
    }

    private func parseRecommendations(from synthesis: String) -> [CouncilRecommendation] {
        guard let data = synthesis.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(SynthesisPayload.self, from: data) else {
            return [CouncilRecommendation(priority: "Important", suggestion: synthesis, agreedModels: [])]
        }

        return decoded.recommendations.map {
            CouncilRecommendation(priority: $0.priority, suggestion: $0.suggestion, agreedModels: $0.agreedModels)
        }
    }

    private func appendChunk(_ chunk: String, for id: UUID) {
        guard let index = providerProgress.firstIndex(where: { $0.id == id }) else { return }
        providerProgress[index].streamedText += chunk
        providerProgress[index].status = .streaming
    }

    private func updateStatus(_ status: ModelRunState, latency: TimeInterval?, tokens: Int?, for id: UUID) {
        guard let index = providerProgress.firstIndex(where: { $0.id == id }) else { return }
        providerProgress[index].status = status
        providerProgress[index].latency = latency
        providerProgress[index].tokensUsed = tokens
    }

    nonisolated private static func defaultServiceDescriptors() -> [CouncilServiceDescriptor] {
        AIProviderSettingsStore
            .loadProviders()
            .filter(\.isEnabled)
            .compactMap { config in
                switch config.kind {
                case .openAICompatible:
                    return CouncilServiceDescriptor(
                        provider: .openAI,
                        model: config.model,
                        service: OpenAIService(model: config.model, apiKeyStorageKey: config.apiKeyName, baseURLString: config.endpointURL)
                    )
                case .anthropic:
                    return CouncilServiceDescriptor(
                        provider: .anthropic,
                        model: config.model,
                        service: AnthropicService(model: config.model, apiKeyStorageKey: config.apiKeyName, baseURLString: config.endpointURL)
                    )
                case .gemini:
                    return CouncilServiceDescriptor(
                        provider: .gemini,
                        model: config.model,
                        service: GoogleGeminiService(model: config.model, apiKeyStorageKey: config.apiKeyName, baseURLString: config.endpointURL)
                    )
                default:
                    return nil
                }
            }
    }

    private func resolveSynthesizer(from descriptors: [CouncilServiceDescriptor]) -> CouncilServiceDescriptor {
        // User-selected head takes priority
        if synthesizerIndex > 0, synthesizerIndex < descriptors.count {
            return descriptors[synthesizerIndex]
        }
        // Fall back to the provider marked as default in settings
        let defaults = AIProviderSettingsStore.loadProviders()
        if let defaultConfig = defaults.first(where: { $0.isEnabled && $0.isDefault }) {
            switch defaultConfig.kind {
            case .openAICompatible:
                return descriptors.first(where: { $0.provider == .openAI }) ?? descriptors[0]
            case .anthropic:
                return descriptors.first(where: { $0.provider == .anthropic }) ?? descriptors[0]
            case .gemini:
                return descriptors.first(where: { $0.provider == .gemini }) ?? descriptors[0]
            default:
                return descriptors[0]
            }
        }
        return descriptors[0]
    }
}

struct CouncilServiceDescriptor: Identifiable {
    let id = UUID()
    let provider: LLMProvider
    let model: String
    let service: LLMServiceProtocol
    var systemPromptOverride: String? = nil   // persona system prompt in single-key mode
    var label: String? = nil                  // display name, e.g. "ATS Recruiter"
}

private struct SynthesisPayload: Decodable {
    struct Recommendation: Decodable {
        let priority: String
        let suggestion: String
        let agreedModels: [String]
    }

    let recommendations: [Recommendation]
}

private extension CouncilOrchestrator {
    static func consumeProviderStream(
        service: LLMServiceProtocol,
        descriptor: CouncilServiceDescriptor,
        prompt: String,
        systemPrompt: String,
        onChunk: @escaping @Sendable (String) async -> Void,
        onStatusChange: @escaping @Sendable (ModelRunState, TimeInterval?, Int?) async -> Void
    ) async throws -> LLMResponse {
        let startedAt = Date()
        var text = ""

        let resolvedSystemPrompt = descriptor.systemPromptOverride ?? systemPrompt
        do {
            for try await chunk in service.streamMessage(prompt: prompt, systemPrompt: resolvedSystemPrompt, model: descriptor.model, maxTokens: 1_800) {
                try Task.checkCancellation()
                text += chunk
                await onChunk(chunk)
            }

            let tokens = service.estimateTokenCount(text: text)
            let latency = Date().timeIntervalSince(startedAt)
            await onStatusChange(.finished, latency, tokens)
            return LLMResponse(content: text, model: descriptor.model, provider: descriptor.provider, tokensUsed: tokens, latency: latency)
        } catch {
            await onStatusChange(.failed(error.localizedDescription), nil, nil)
            throw error
        }
    }
}
