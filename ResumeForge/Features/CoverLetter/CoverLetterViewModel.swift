import Foundation
import SwiftData

@Observable
@MainActor
final class CoverLetterViewModel {
    enum CoverLetterError: LocalizedError {
        case noConfiguredProvider

        var errorDescription: String? {
            switch self {
            case .noConfiguredProvider:
                return "No enabled AI provider is configured. Enable one in Settings first."
            }
        }
    }

    var streamBuffer: String = ""
    var generatedText: String = ""
    var isGenerating: Bool = false
    var error: String?

    func generate(
        profile: UserProfile,
        job: JobDescription,
        styleTraits: String,
        service: AIServiceProtocol,
        context: ModelContext
    ) async {
        isGenerating = true
        streamBuffer = ""
        error = nil
        defer { isGenerating = false }

        do {
            let companyFacts = await resolveCompanyResearch(for: job, context: context)
            let prompt = PromptLibrary.coverLetterUser(
                profile: profile,
                job: job,
                styleTraits: styleTraits,
                companyFacts: companyFacts
            )

            for try await chunk in service.stream(
                prompt: prompt,
                systemPrompt: PromptLibrary.coverLetterSystem
            ) {
                streamBuffer += chunk
            }
            generatedText = streamBuffer
        } catch {
            self.error = error.localizedDescription
        }
    }

    func save(job: JobDescription, context: ModelContext) {
        let trimmed = generatedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let letter = CoverLetter(
            targetJobTitle: job.title,
            targetCompany: job.company,
            content: trimmed
        )
        context.insert(letter)

        do {
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

    private func resolveCompanyResearch(for job: JobDescription, context: ModelContext) async -> String {
        let existing = (job.companyResearchNotes ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !existing.isEmpty {
            return existing
        }

        let link = (job.companyWebsiteURL ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !link.isEmpty else { return "" }

        if let fetched = await fetchCompanyFacts(from: link) {
            job.companyResearchNotes = fetched
            job.updatedAt = .now
            try? context.save()
            return fetched
        }

        return ""
    }

    private func fetchCompanyFacts(from link: String) async -> String? {
        guard let url = URL(string: link),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            return nil
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode),
              let html = String(data: data, encoding: .utf8) else {
            return nil
        }

        let noScripts = html.replacingOccurrences(
            of: "<script[\\s\\S]*?</script>|<style[\\s\\S]*?</style>",
            with: " ",
            options: .regularExpression
        )
        let plain = noScripts.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        let compact = plain.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !compact.isEmpty else { return nil }
        return String(compact.prefix(1200))
    }
}
