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
    var parsedData: ParsedResumeData = ParsedResumeData()
    var error: Error?
    var fileName: String = ""

    // MARK: - Import & parse pipeline

    func startImport() {
        parserState = .importing
        isShowingFilePicker = true
    }

    func handlePickedURL(_ url: URL) async {
        print("[ResumeParser] 📂 File picked: \(url.path)")
        parserState = .parsing
        error = nil
        do {
            print("[ResumeParser] ⏳ Loading file data…")
            let file = try FileImportService.load(from: url)
            fileName = file.fileName
            print("[ResumeParser] ✅ File loaded: \(file.fileName) (\(file.fileType)) — \(file.data.count) bytes")
            print("[ResumeParser] ⏳ Starting text extraction…")
            extractedText = try await extractText(from: file)
            print("[ResumeParser] ✅ Extraction done — \(extractedText.count) chars")
            print("[ResumeParser] ⏳ Parsing content…")
            parsedData = ResumeContentParser.parse(extractedText)
            print("[ResumeParser] ✅ Parsing done")
            parserState = .review
        } catch {
            print("[ResumeParser] ❌ Error: \(error)")
            self.error = error
            parserState = .idle
        }
    }

    func handlePickerDismissed() {
        if parserState == .importing { parserState = .idle }
    }

    // MARK: - Save to profile

    func saveToProfile(context: ModelContext) async {
        parserState = .saving
        do {
            let profile = try fetchOrCreateProfile(context: context)
            apply(parsedData, to: profile)
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
            return try await Task.detached(priority: .userInitiated) {
                try LaTeXTextExtractor.extract(from: file.data)
            }.value

        case .pdf:
            // Write data to a temp file so Docling (which needs a file path) can access it
            let tmpURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString + ".pdf")
            try file.data.write(to: tmpURL)
            defer { try? FileManager.default.removeItem(at: tmpURL) }

            do {
                print("[ResumeParser] 🐍 Trying Docling extractor…")
                let text = try await DoclingPDFExtractor.extract(from: tmpURL)
                print("[ResumeParser] ✅ Docling extraction succeeded")
                return text
            } catch DoclingExtractionError.moduleNotAvailable {
                print("[ResumeParser] ⚠️  Docling unavailable — using PDFKit fallback")
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

    private func apply(_ data: ParsedResumeData, to profile: UserProfile) {
        if !data.name.isEmpty     { profile.fullName = data.name }
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
}
