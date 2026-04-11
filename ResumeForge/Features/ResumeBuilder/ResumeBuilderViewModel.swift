import Foundation
import SwiftData

@Observable
@MainActor
final class ResumeBuilderViewModel {
    enum ResumeBuilderError: LocalizedError {
        case noConfiguredProvider

        var errorDescription: String? {
            switch self {
            case .noConfiguredProvider:
                return "No enabled AI provider is configured. Enable one in Settings first."
            }
        }
    }

    var editedContent: String = ""
    var isGenerating: Bool = false
    var error: String?
    var savedResume: GeneratedResume?

    static func preferredOutputFormatFromLastImport() -> ResumeFormat {
        let lastType = UserDefaults.standard.string(forKey: "parser.lastImportedFileType")
        return lastType == "latex" ? .latex : .pdf
    }

    func generate(
        profile: UserProfile,
        job: JobDescription,
        councilSynthesis: String,
        outputFormat: ResumeFormat,
        service: AIServiceProtocol
    ) async {
        isGenerating = true
        defer { isGenerating = false }

        do {
            editedContent = try await service.complete(
                prompt: PromptLibrary.resumeBuilderUser(
                    profile: profile,
                    job: job,
                    synthesis: councilSynthesis,
                    outputFormat: outputFormat
                ),
                systemPrompt: PromptLibrary.resumeBuilderSystem
            )
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    func save(job: JobDescription, format: ResumeFormat, councilSynthesis: String, context: ModelContext) {
        let trimmed = editedContent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let resume = GeneratedResume(
            targetJobTitle: job.title,
            targetCompany: job.company,
            jobDescription: job.rawText,
            generatedContent: trimmed,
            format: format,
            councilFeedback: councilSynthesis
        )
        context.insert(resume)

        do {
            try context.save()
            savedResume = resume
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
