import Foundation
import SwiftData

@Observable
@MainActor
final class StylePersonaViewModel {
    enum StylePersonaError: LocalizedError {
        case emptySample
        case noConfiguredProvider

        var errorDescription: String? {
            switch self {
            case .emptySample:
                return "Paste a sample cover letter before analyzing."
            case .noConfiguredProvider:
                return "No enabled AI provider is configured. Enable one in Settings first."
            }
        }
    }

    var sampleText: String = ""
    var derivedTraits: String = ""
    var isAnalysing: Bool = false
    var error: String?

    func load(context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<StylePersona>()))?.first
        sampleText = existing?.sampleText ?? ""
        derivedTraits = existing?.derivedTraits ?? ""
    }

    func analyseStyle(service: AIServiceProtocol, context: ModelContext) async {
        let trimmed = sampleText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            error = StylePersonaError.emptySample.localizedDescription
            return
        }

        isAnalysing = true
        defer { isAnalysing = false }

        do {
            let traits = try await service.complete(
                prompt: PromptLibrary.styleAnalysisUser(sample: trimmed),
                systemPrompt: PromptLibrary.styleAnalysisSystem
            )
            derivedTraits = traits
            let existing = (try? context.fetch(FetchDescriptor<StylePersona>()))?.first
            let persona = existing ?? StylePersona()
            persona.sampleText = trimmed
            persona.derivedTraits = traits
            if existing == nil {
                context.insert(persona)
            }
            try context.save()
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    func makePreferredService() -> AIServiceProtocol? {
        let providers = AIProviderSettingsStore.loadProviders().filter(\.isEnabled)
        if let defaultProvider = providers.first(where: { $0.isDefault }),
           let service = AIProviderServiceFactory.makeService(for: defaultProvider) {
            return service
        }
        if let ollama = providers.first(where: { $0.kind == .ollama }),
           let service = AIProviderServiceFactory.makeService(for: ollama) {
            return service
        }
        return providers.compactMap { AIProviderServiceFactory.makeService(for: $0) }.first
    }
}
