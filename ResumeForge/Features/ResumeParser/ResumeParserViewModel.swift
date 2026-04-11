import SwiftUI
import SwiftData

// MARK: - View state

enum ResumeParserState: Equatable {
    case idle
    case importing
    case parsing
    case review
    case saving
    case saved
}

// MARK: - ViewModel

@Observable
@MainActor
final class ResumeParserViewModel {
    // State
    var parserState: ResumeParserState = .idle
    var isShowingFilePicker = false
    var extractedText: String = ""
    var draft: DraftProfile = DraftProfile()
    var error: Error?
    var fileName: String = ""
    var parsingMethodDescription: String = ""
    var structuringMethodDescription: String = ""
    var parsedDataMethodDescription: String = ""

    private let llmService: AIServiceProtocol?

    init(llmService: AIServiceProtocol? = nil) {
        self.llmService = llmService
    }

    // MARK: - Import & parse pipeline

    func startImport() {
        parserState = .importing
        isShowingFilePicker = true
    }

    func handlePickedURL(_ url: URL) async {
        parserState = .parsing
        error = nil
        parsingMethodDescription = "Detecting file type and selecting parser…"
        structuringMethodDescription = ""
        parsedDataMethodDescription = ""
        do {
            let file = try FileImportService.load(from: url)
            fileName = file.fileName
            extractedText = try await extractText(from: file)
            // LLM LaTeX extraction populates draft directly and returns ""
            if extractedText.isEmpty {
                parsedDataMethodDescription = parsingMethodDescription
                parserState = .review
                return
            }
            let parsed = await parseWithLocalLLMFallback(extractedText)
            draft = makeDraft(from: parsed)
            parsedDataMethodDescription = [parsingMethodDescription, structuringMethodDescription]
                .filter { !$0.isEmpty }
                .joined(separator: " ")
            parserState = .review
        } catch {
            self.error = error
            parserState = .idle
        }
    }

    func handlePickerDismissed() {
        if parserState == .importing { parserState = .idle }
    }

    func cancelImport() {
        draft = DraftProfile()
        parserState = .idle
    }

    // MARK: - Save to profile

    func saveToProfile(context: ModelContext) async {
        parserState = .saving
        do {
            let profile = try fetchOrCreateProfile(context: context)
            apply(draft, to: profile)
            try context.save()
            parserState = .saved
        } catch {
            self.error = error
            parserState = .review
        }
    }

    // MARK: - Private helpers

    private func extractText(from file: ImportedFile) async throws -> String {
        switch file.fileType {
        case .latex:
            let rawLatex = String(data: file.data, encoding: .utf8) ?? ""
            parsingMethodDescription = "LaTeX: trying LLM-based structure extraction first."
            // Try LLM extraction first — more accurate for complex nested LaTeX
            if let service = llmService ?? Self.makeLocalLLMServiceIfAvailable() {
                if let parsed = try? await LLMLatexExtractor.extract(from: rawLatex, service: service),
                   hasUsefulData(parsed) {
                    parsingMethodDescription = "LaTeX parsed with LLM extraction."
                    draft = makeDraft(from: parsed)
                    return ""   // draft is populated; skip parseWithLocalLLMFallback
                }
            }
            // Fallback: regex-based extractor
            parsingMethodDescription = "LaTeX LLM unavailable; using regex fallback parser."
            return try await Task.detached(priority: .userInitiated) {
                try LaTeXTextExtractor.extract(from: file.data)
            }.value

        case .pdf:
            parsingMethodDescription = "PDF: trying Docling extraction first."
            // Write data to a temp file so Docling (which needs a file path) can access it
            let tmpURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString + ".pdf")
            try file.data.write(to: tmpURL)
            defer { try? FileManager.default.removeItem(at: tmpURL) }

            do {
                // Try Docling first — richer, layout-aware extraction
                let text = try await DoclingPDFExtractor.extract(from: tmpURL)
                parsingMethodDescription = "PDF parsed with Docling."
                return text
            } catch DoclingExtractionError.moduleNotAvailable {
                // Docling not installed — fall back silently to PDFKit
                parsingMethodDescription = "Docling not available; using PDFKit fallback parser."
                return try await Task.detached(priority: .userInitiated) {
                    try PDFTextExtractor.extract(from: file.data)
                }.value
            }
            // Other Docling errors (parse failure, empty) propagate to the caller
        }
    }

    private func fetchOrCreateProfile(context: ModelContext) throws -> UserProfile {
        let descriptor = FetchDescriptor<UserProfile>()
        let existing = try context.fetch(descriptor)
        if let profile = existing.first { return profile }
        let newProfile = UserProfile()
        context.insert(newProfile)
        return newProfile
    }

    private func makeDraft(from data: ParsedResumeData) -> DraftProfile {
        DraftProfile(
            fullName: data.name, email: data.email, phone: data.phone,
            linkedIn: data.linkedIn, github: data.github, website: data.website,
            summary: data.summary, skills: data.skills,
            experiences: data.experiences, education: data.education
        )
    }

    private func apply(_ data: DraftProfile, to profile: UserProfile) {
        if !data.fullName.isEmpty { profile.fullName = data.fullName }
        if !data.email.isEmpty    { profile.email    = data.email }
        if !data.phone.isEmpty    { profile.phone    = data.phone }
        if !data.linkedIn.isEmpty { profile.linkedIn = data.linkedIn }
        if !data.github.isEmpty   { profile.github   = data.github }
        if !data.website.isEmpty  { profile.website  = data.website }
        if !data.summary.isEmpty  { profile.summary  = data.summary }
        if !data.skills.isEmpty   { profile.skills   = data.skills }

        for parsed in data.experiences {
            let exp = Experience(
                company: parsed.company,
                title: parsed.title,
                startDate: parsed.startDate ?? .now,
                endDate: parsed.isCurrent ? nil : parsed.endDate,
                bulletPoints: parsed.bulletPoints
            )
            profile.experiences.append(exp)
        }
        for parsed in data.education {
            let edu = Education(
                institution: parsed.institution,
                degree: parsed.degree,
                field: parsed.field,
                graduationDate: parsed.graduationDate ?? .now,
                gpa: parsed.gpa.isEmpty ? nil : parsed.gpa
            )
            profile.education.append(edu)
        }
        profile.updatedAt = .now
    }

    // MARK: - Local LLM parser pass

    private func parseWithLocalLLMFallback(_ text: String) async -> ParsedResumeData {
        let fallback = ResumeResultParser.parse(text)
        structuringMethodDescription = "Structured with deterministic local parser."

        guard UserDefaults.standard.bool(forKey: "parser.localLLMEnabled") else {
            return fallback
        }

        structuringMethodDescription = "Trying local LLM for structured data extraction."

        let systemPrompt = """
        You are a resume parser.
        Return valid JSON only.
        Do not wrap JSON in markdown.
        Omit comments and explanations.
        """

        let userPrompt = """
        Parse this resume text into JSON with the following shape:
        {
            "name": String,
            "email": String,
            "phone": String,
            "summary": String,
            "linkedin": String,
            "github": String,
            "website": String,
            "skills": [String],
            "experiences": [
                {
                    "company": String,
                    "title": String,
                    "dateRange": String,
                    "bulletPoints": [String]
                }
            ],
            "education": [
                {
                    "institution": String,
                    "degree": String,
                    "field": String,
                    "graduationDate": String,
                    "gpa": String
                }
            ],
            "projects": [
                {
                    "name": String,
                    "year": String,
                    "bulletPoints": [String]
                }
            ]
        }

        Resume text:
        \(text)
        """

        do {
            let llmOutput = try await (llmService ?? Self.makeLocalLLMService()).complete(
                prompt: userPrompt,
                systemPrompt: systemPrompt
            )
            let llmParsed = ResumeResultParser.parse(llmOutput)
            if hasUsefulData(llmParsed) {
                structuringMethodDescription = "Structured with local LLM parser."
                return llmParsed
            }
            structuringMethodDescription = "Local LLM output was incomplete; used deterministic local parser."
        } catch {
            // Fall back to deterministic parser when local model is unavailable.
            structuringMethodDescription = "Local LLM unavailable; used deterministic local parser."
        }

        return fallback
    }

    /// Returns any enabled provider's service — cloud or local.
    /// Prefers Ollama (free, no cost) but falls back to cloud providers.
    private static func makeLocalLLMServiceIfAvailable() -> AIServiceProtocol? {
        let providers = AIProviderSettingsStore.loadProviders().filter(\.isEnabled)
        // Prefer local (Ollama) — no API cost
        if let ollama = providers.first(where: { $0.kind == .ollama }) {
            return AIProviderServiceFactory.makeService(for: ollama)
        }
        // Fall back to any cloud provider with a configured key
        return providers.compactMap { AIProviderServiceFactory.makeService(for: $0) }.first
    }

    private static func makeLocalLLMService() -> AIServiceProtocol {
        makeLocalLLMServiceIfAvailable() ?? OllamaService()
    }

    private func hasUsefulData(_ data: ParsedResumeData) -> Bool {
        !data.name.isEmpty
            || !data.email.isEmpty
            || !data.phone.isEmpty
            || !data.summary.isEmpty
            || !data.skills.isEmpty
            || !data.experiences.isEmpty
            || !data.education.isEmpty
            || !data.projects.isEmpty
    }
}
