# ResumeForge — Implementation Roadmap

> **How to use this doc:** Each feature is broken into numbered steps with exact file paths and the precise code to write. Work through them in order. Each step is self-contained and references the existing code it depends on.

---

## Current State (as of 2026-04-10)

| Feature | Status |
|---|---|
| Resume Parser (PDF/LaTeX → ParsedResumeData) | Done |
| AI Council (parallel multi-LLM analysis + synthesis) | Done |
| Profile CRUD (manual edit, add/remove exp/edu/skills) | Done |
| Provider settings (BYOK, Keychain, multi-provider) | Done |
| Job Description input | Done |
| Draft→Review→Commit resume import flow | Partial — save works, but no "Cancel discards draft" guard |
| AI Council 2.0 (single-key multi-perspective mode) | Missing |
| LaTeX parsing via LLM | Missing |
| Style-guided cover letters | Missing |
| Cover Letter feature | Placeholder only |
| Resume Builder feature | Placeholder only |
| Export (PDF / LaTeX / DOCX) | Placeholder only |
| PromptLibrary (centralised prompts) | Missing |

---

## Key Existing Files to Know

- `ResumeForge/Features/ResumeParser/ResumeParserViewModel.swift` — import + parse pipeline, `parserState: ResumeParserState`
- `ResumeForge/Features/AICouncil/Services/CouncilOrchestrator.swift` — parallel LLM calls, synthesis, `CouncilServiceDescriptor`
- `ResumeForge/Features/AICouncil/Services/CouncilPrompts.swift` — all system/user prompts for council
- `ResumeForge/Core/Services/AIServiceProtocol.swift` — `AIServiceProtocol` (stream + complete), `OllamaService`
- `ResumeForge/Core/Models/UserProfile.swift` — SwiftData `@Model` (fullName, email, phone, skills, experiences, education)
- `ResumeForge/Core/Models/GeneratedResume.swift` — SwiftData `@Model` (generatedContent, format: ResumeFormat)
- `ResumeForge/Core/UI/Router.swift` — `Route` enum with all destination cases
- `ResumeForge/Features/Profile/ProfileViewModel.swift` — `@Observable @MainActor`
- Placeholders (replace these): `CoverLetterPlaceholder.swift`, `ResumeBuilderPlaceholder.swift`, `ExportPlaceholder.swift`

---

## Feature 1 — Resume Import: Draft→Review→Commit

**Goal:** When parsing, hold results in a `DraftProfile` value type. The review screen lets the user edit fields before committing to SwiftData. Cancel discards the draft with zero data loss.

### Step 1.1 — Create `DraftProfile`

**New file:** `ResumeForge/Features/ResumeParser/DraftProfile.swift`

```swift
import Foundation

/// Ephemeral staging struct for a parsed resume before the user confirms.
/// Never persisted to SwiftData directly.
struct DraftProfile: Equatable {
    var fullName: String = ""
    var email: String = ""
    var phone: String = ""
    var linkedIn: String = ""
    var github: String = ""
    var website: String = ""
    var summary: String = ""
    var skills: [String] = []
    var experiences: [ParsedExperience] = []  // already exists in ParsedResumeData.swift
    var education: [ParsedEducation] = []     // already exists in ParsedResumeData.swift
}
```

### Step 1.2 — Update `ResumeParserViewModel`

**File:** `ResumeForge/Features/ResumeParser/ResumeParserViewModel.swift`

1. Replace `var parsedData: ParsedResumeData = ParsedResumeData()` with `var draft: DraftProfile = DraftProfile()`.
2. In `handlePickedURL`, after `parseWithLocalLLMFallback` returns, populate `draft` from the result instead of assigning to `parsedData`.
3. Add a `cancelImport()` method that resets `draft = DraftProfile()` and sets `parserState = .idle`.
4. In `saveToProfile(context:)`, read from `draft` fields instead of `parsedData`.

Helper to convert `ParsedResumeData → DraftProfile`:
```swift
private func makeDraft(from data: ParsedResumeData) -> DraftProfile {
    DraftProfile(
        fullName: data.name, email: data.email, phone: data.phone,
        linkedIn: data.linkedIn, github: data.github, website: data.website,
        summary: data.summary, skills: data.skills,
        experiences: data.experiences, education: data.education
    )
}
```

### Step 1.3 — Create `DraftReviewView`

**New file:** `ResumeForge/Features/ResumeParser/DraftReviewView.swift`

```swift
import SwiftUI

struct DraftReviewView: View {
    @Binding var draft: DraftProfile
    let onCommit: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                DraftContactSection(draft: $draft)
                DraftSkillsSection(draft: $draft)
                DraftExperienceSection(draft: $draft)
                DraftEducationSection(draft: $draft)
            }
            .navigationTitle("Review Parsed Resume")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .destructive, action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Confirm", action: onCommit)
                }
            }
        }
    }
}
```

Split into sub-views in the same file: `DraftContactSection`, `DraftSkillsSection`, `DraftExperienceSection`, `DraftEducationSection`. Each is a simple `Section` with `TextField` / `List` rows bound to `$draft`.

### Step 1.4 — Wire into `ResumeParserView`

**File:** `ResumeForge/Features/ResumeParser/ResumeParserView.swift`

In the `.review` state branch, present `DraftReviewView` as a `.sheet` or full-screen view:
```swift
case .review:
    DraftReviewView(
        draft: $viewModel.draft,
        onCommit: { Task { await viewModel.saveToProfile(context: context) } },
        onCancel: { viewModel.cancelImport() }
    )
```

### Step 1.5 — Add "Clear Profile" with `confirmationDialog`

**File:** `ResumeForge/Features/Profile/ProfileView.swift`

Add to toolbar:
```swift
Button("Clear Profile", role: .destructive) { showClearConfirm = true }
.confirmationDialog("Delete all profile data?", isPresented: $showClearConfirm, titleVisibility: .visible) {
    Button("Delete Everything", role: .destructive) { viewModel.clearProfile(context: context) }
}
```

**File:** `ResumeForge/Features/Profile/ProfileViewModel.swift`

Add:
```swift
func clearProfile(context: ModelContext) {
    guard let profile else { return }
    context.delete(profile)
    try? context.save()
    self.profile = nil
    load(context: context)
}
```

---

## Feature 2 — AI Council 2.0 (Single-Key Multi-Perspective Mode)

**Goal:** If only one API key is configured, the Council still produces 3 analyses by calling the same model with 3 different system-prompt "personas". If multiple keys exist, the existing parallel path runs unchanged.

### Step 2.1 — Add Persona Prompts to `CouncilPrompts`

**File:** `ResumeForge/Features/AICouncil/Services/CouncilPrompts.swift`

Append:
```swift
static let personaRecruiter = """
You are a strict ATS recruiter. Focus on keyword density, format compliance,
quantified achievements, and whether the resume passes automated screening.
"""

static let personaHiringManager = """
You are a creative hiring manager who values narrative, cultural fit, career
trajectory, and storytelling. Focus on impact and uniqueness.
"""

static let personaTechnicalPeer = """
You are a senior technical peer reviewing for technical depth, stack relevance,
scope of past work, and engineering credibility.
"""

static var singleKeyPersonas: [(label: String, systemPrompt: String)] {
    [
        ("ATS Recruiter",    personaRecruiter),
        ("Hiring Manager",   personaHiringManager),
        ("Technical Peer",   personaTechnicalPeer),
    ]
}
```

### Step 2.2 — Extend `CouncilServiceDescriptor`

**File:** `ResumeForge/Features/AICouncil/Services/CouncilOrchestrator.swift`

```swift
struct CouncilServiceDescriptor: Identifiable {
    let id = UUID()
    let provider: LLMProvider
    let model: String
    let service: LLMServiceProtocol
    var systemPromptOverride: String? = nil   // used in single-key persona mode
    var label: String? = nil                  // display name, e.g. "ATS Recruiter"
}
```

### Step 2.3 — Update `conveneCouncil` for single-key mode

**File:** `ResumeForge/Features/AICouncil/Services/CouncilOrchestrator.swift`

At the start of `conveneCouncil`, replace the direct use of `serviceDescriptorsProvider()` with:
```swift
let rawDescriptors = serviceDescriptorsProvider()
let descriptors: [CouncilServiceDescriptor]
if rawDescriptors.count == 1 {
    // Single-key mode: clone with 3 personas
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
```

In `consumeProviderStream`, replace hardcoded `CouncilPrompts.analysisSystemPrompt` with:
```swift
let systemPrompt = descriptor.systemPromptOverride ?? CouncilPrompts.analysisSystemPrompt
```

### Step 2.4 — Show Persona Labels in `AICouncilView`

**File:** `ResumeForge/Features/AICouncil/AICouncilView.swift`

Where provider cards are rendered, use `descriptor.label ?? descriptor.provider.displayName` as the card title, so single-key mode shows "ATS Recruiter" / "Hiring Manager" / "Technical Peer" instead of three identical provider names.

### Step 2.5 — User-selectable Head of Council

**File:** `ResumeForge/Features/AICouncil/AICouncilViewModel.swift`

Add `var selectedSynthesizerIndex: Int = 0`.

Pass this to `CouncilOrchestrator` so `resolveSynthesizer` returns `descriptors[selectedSynthesizerIndex]` (clamped to valid range) instead of always using `descriptors[0]`.

In `AICouncilView`, add a `Picker("Head of Council", selection: $viewModel.selectedSynthesizerIndex)` above the Run button, populated from the configured providers/personas.

---

## Feature 3 — Centralised PromptLibrary + LaTeX Parsing via LLM

### Step 3.1 — Create `PromptLibrary`

**New file:** `ResumeForge/Core/Services/PromptLibrary.swift`

```swift
import Foundation

enum PromptLibrary {

    // MARK: LaTeX Extraction
    static let latexExtractionSystem = """
    You are a data extraction specialist.
    Return ONLY valid JSON — no markdown, no code fences, no comments.
    """

    static func latexExtractionUser(latexSource: String) -> String {
        """
        Convert this raw LaTeX resume into JSON with this exact shape:
        {
          "name": "", "email": "", "phone": "", "linkedin": "", "github": "",
          "website": "", "summary": "", "skills": [],
          "experiences": [{"company":"","title":"","dateRange":"","bulletPoints":[]}],
          "education": [{"institution":"","degree":"","field":"","graduationDate":"","gpa":""}],
          "projects": [{"name":"","year":"","bulletPoints":[]}]
        }
        Strip all LaTeX commands (\\textbf, \\hfill, \\begin, etc.).
        LaTeX source:
        \(latexSource)
        """
    }

    // MARK: Style Analysis
    static let styleAnalysisSystem = """
    You are a writing style analyst. Analyse the sample and return a concise
    list of tone descriptors (e.g. "Formal", "First-person narrative",
    "Direct call-to-action closing"). Return plain text, no JSON.
    """

    static func styleAnalysisUser(sample: String) -> String {
        "Analyse the writing style of this cover letter sample:\n\n\(sample)"
    }

    // MARK: Cover Letter
    static func coverLetterUser(profile: UserProfile, job: JobDescription, styleTraits: String) -> String {
        """
        Write a professional cover letter for this candidate applying to the role below.
        Tone guidelines derived from their past writing: \(styleTraits)

        Candidate: \(profile.fullName)
        Role: \(job.title) at \(job.company)
        Job description:
        \(job.rawText)
        """
    }

    static let coverLetterSystem = "You are an expert cover letter writer."

    // MARK: Resume Builder
    static func resumeBuilderUser(profile: UserProfile, job: JobDescription, synthesis: String) -> String {
        """
        Using the AI Council recommendations below, rewrite the candidate's resume
        tailored for the target role. Return the full resume as plain text only.

        AI Council recommendations:
        \(synthesis)

        Candidate: \(profile.fullName)
        Summary: \(profile.summary)
        Target role: \(job.title) at \(job.company)
        """
    }

    static let resumeBuilderSystem = "You are an expert resume writer. Return the full resume as plain text."
}
```

### Step 3.2 — Create `LLMLatexExtractor`

**New file:** `ResumeForge/Features/ResumeParser/Services/LLMLatexExtractor.swift`

```swift
import Foundation

enum LLMLatexExtractor {
    /// Sends raw LaTeX to an LLM and returns ParsedResumeData.
    static func extract(from latexSource: String, service: AIServiceProtocol) async throws -> ParsedResumeData {
        let response = try await service.complete(
            prompt: PromptLibrary.latexExtractionUser(latexSource: latexSource),
            systemPrompt: PromptLibrary.latexExtractionSystem
        )
        return ResumeResultParser.parseJSON(response)  // see step 3.3
    }
}
```

### Step 3.3 — Add `parseJSON` to `ResumeResultParser`

**File:** `ResumeForge/Features/ResumeParser/Services/ResumeResultParser.swift`

Add a static method that decodes the exact JSON shape defined in `PromptLibrary.latexExtractionUser`:
```swift
static func parseJSON(_ jsonString: String) -> ParsedResumeData {
    guard let data = jsonString.data(using: .utf8),
          let raw = try? JSONDecoder().decode(LLMResumeJSON.self, from: data) else {
        return ParsedResumeData()
    }
    var result = ParsedResumeData()
    result.name = raw.name
    result.email = raw.email
    // ... map all fields
    return result
}

private struct LLMResumeJSON: Decodable {
    var name: String = ""; var email: String = ""; var phone: String = ""
    var linkedin: String = ""; var github: String = ""; var website: String = ""
    var summary: String = ""; var skills: [String] = []
    var experiences: [LLMExperience] = []; var education: [LLMEducation] = []

    struct LLMExperience: Decodable {
        var company: String = ""; var title: String = ""
        var dateRange: String = ""; var bulletPoints: [String] = []
    }
    struct LLMEducation: Decodable {
        var institution: String = ""; var degree: String = ""
        var field: String = ""; var graduationDate: String = ""; var gpa: String = ""
    }
}
```

### Step 3.4 — Wire `LLMLatexExtractor` into `ResumeParserViewModel`

**File:** `ResumeForge/Features/ResumeParser/ResumeParserViewModel.swift`

Change the `.latex` branch in `extractText(from:)`:
```swift
case .latex:
    let rawLatex = String(data: file.data, encoding: .utf8) ?? ""
    // Try LLM extraction first
    if let service = llmService {
        if let parsed = try? await LLMLatexExtractor.extract(from: rawLatex, service: service) {
            draft = makeDraft(from: parsed)
            return ""   // signal that draft is already populated
        }
    }
    // Fallback: regex extractor
    return try await Task.detached(priority: .userInitiated) {
        try LaTeXTextExtractor.extract(from: file.data)
    }.value
```

In `handlePickedURL`, skip the `parseWithLocalLLMFallback` call if `extractedText` is empty and `draft` is already populated.

---

## Feature 4 — Style-Guided Cover Letters

### Step 4.1 — Add `StylePersona` SwiftData model

**New file:** `ResumeForge/Core/Models/StylePersona.swift`

```swift
import SwiftData
import Foundation

@Model
final class StylePersona {
    var id: UUID
    var sampleText: String
    var derivedTraits: String
    var createdAt: Date

    init(sampleText: String = "", derivedTraits: String = "") {
        self.id = UUID()
        self.sampleText = sampleText
        self.derivedTraits = derivedTraits
        self.createdAt = .now
    }
}
```

**File:** `ResumeForge/App/ResumeForgeApp.swift`

Add `StylePersona.self` to the `Schema([...])` array in the `modelContainer` modifier.

### Step 4.2 — Create `StylePersonaViewModel`

**New file:** `ResumeForge/Features/Settings/StylePersonaViewModel.swift`

```swift
import SwiftData
import Foundation

@Observable @MainActor
final class StylePersonaViewModel {
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
        isAnalysing = true
        defer { isAnalysing = false }
        do {
            let traits = try await service.complete(
                prompt: PromptLibrary.styleAnalysisUser(sample: sampleText),
                systemPrompt: PromptLibrary.styleAnalysisSystem
            )
            derivedTraits = traits
            let existing = (try? context.fetch(FetchDescriptor<StylePersona>()))?.first
            let persona = existing ?? StylePersona()
            persona.sampleText = sampleText
            persona.derivedTraits = traits
            if existing == nil { context.insert(persona) }
            try? context.save()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
```

### Step 4.3 — Create `StyleReferenceView`

**New file:** `ResumeForge/Features/Settings/StyleReferenceView.swift`

```swift
import SwiftUI

struct StyleReferenceView: View {
    @Environment(\.modelContext) private var context
    @State private var viewModel = StylePersonaViewModel()
    // inject a service via environment or init

    var body: some View {
        Form {
            Section("Paste a cover letter you liked") {
                TextEditor(text: $viewModel.sampleText)
                    .frame(minHeight: 200)
            }
            Section {
                Button("Analyse My Style") {
                    Task { await viewModel.analyseStyle(service: /* inject */, context: context) }
                }
                .disabled(viewModel.sampleText.isEmpty || viewModel.isAnalysing)
            }
            if !viewModel.derivedTraits.isEmpty {
                Section("Your Style Traits") {
                    Text(viewModel.derivedTraits)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Writing Style Reference")
        .onAppear { viewModel.load(context: context) }
    }
}
```

Add a `NavigationLink("Writing Style Reference", destination: StyleReferenceView())` row to `SettingsView`.

---

## Feature 5 — Cover Letter Feature (Full)

**Dependencies:** Feature 4 complete, `CoverLetter` SwiftData model exists at `ResumeForge/Core/Models/CoverLetter.swift`.

### Step 5.1 — Create `CoverLetterViewModel`

**New file:** `ResumeForge/Features/CoverLetter/CoverLetterViewModel.swift`

```swift
import SwiftData
import Foundation

@Observable @MainActor
final class CoverLetterViewModel {
    var streamBuffer: String = ""
    var generatedText: String = ""
    var isGenerating: Bool = false
    var error: String?

    func generate(profile: UserProfile, job: JobDescription, styleTraits: String, service: AIServiceProtocol) async {
        isGenerating = true
        streamBuffer = ""
        defer { isGenerating = false }
        do {
            for try await chunk in service.stream(
                prompt: PromptLibrary.coverLetterUser(profile: profile, job: job, styleTraits: styleTraits),
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
        // Populate the existing CoverLetter @Model and insert
        // (check CoverLetter.swift for exact field names)
        try? context.save()
    }
}
```

### Step 5.2 — Replace `CoverLetterPlaceholder.swift`

**File:** `ResumeForge/Features/CoverLetter/CoverLetterPlaceholder.swift`

Replace the comment with:
```swift
import SwiftUI
import SwiftData

struct CoverLetterView: View {
    @Environment(\.modelContext) private var context
    @State private var viewModel = CoverLetterViewModel()
    // pass in profile, job, styleTraits, and service via environment or init

    var body: some View {
        VStack {
            if viewModel.isGenerating {
                ScrollView { Text(viewModel.streamBuffer).padding() }
                ProgressView("Generating…")
            } else if !viewModel.generatedText.isEmpty {
                TextEditor(text: $viewModel.generatedText)
                Button("Save") { viewModel.save(job: /* job */, context: context) }
            } else {
                Button("Generate Cover Letter") {
                    Task { await viewModel.generate(profile: /* */, job: /* */, styleTraits: /* */, service: /* */) }
                }
            }
        }
        .navigationTitle("Cover Letter")
    }
}
```

---

## Feature 6 — Resume Builder Feature (Full)

### Step 6.1 — Create `ResumeBuilderViewModel`

**New file:** `ResumeForge/Features/ResumeBuilder/ResumeBuilderViewModel.swift`

```swift
import SwiftData
import Foundation

@Observable @MainActor
final class ResumeBuilderViewModel {
    var editedContent: String = ""
    var isGenerating: Bool = false
    var error: String?
    var savedResume: GeneratedResume?

    func generate(profile: UserProfile, job: JobDescription, councilSynthesis: String, service: AIServiceProtocol) async {
        isGenerating = true
        defer { isGenerating = false }
        do {
            editedContent = try await service.complete(
                prompt: PromptLibrary.resumeBuilderUser(profile: profile, job: job, synthesis: councilSynthesis),
                systemPrompt: PromptLibrary.resumeBuilderSystem
            )
        } catch {
            self.error = error.localizedDescription
        }
    }

    func save(job: JobDescription, format: ResumeFormat, context: ModelContext) {
        let resume = GeneratedResume(
            targetJobTitle: job.title,
            targetCompany: job.company,
            jobDescription: job.rawText,
            generatedContent: editedContent,
            format: format
        )
        context.insert(resume)
        try? context.save()
        savedResume = resume
    }
}
```

### Step 6.2 — Replace `ResumeBuilderPlaceholder.swift`

**File:** `ResumeForge/Features/ResumeBuilder/ResumeBuilderPlaceholder.swift`

Replace with `ResumeBuilderView`:
```swift
import SwiftUI
import SwiftData

struct ResumeBuilderView: View {
    @Environment(\.modelContext) private var context
    @State private var viewModel = ResumeBuilderViewModel()
    @State private var selectedFormat: ResumeFormat = .pdf
    // pass profile, job, councilSynthesis, service via init or environment

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isGenerating {
                ProgressView("Building resume…").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                TextEditor(text: $viewModel.editedContent)
                    .font(.system(.body, design: .monospaced))
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Picker("Format", selection: $selectedFormat) {
                    ForEach(ResumeFormat.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.segmented)
            }
            ToolbarItem(placement: .primaryAction) {
                Button("Save") { viewModel.save(job: /* */, format: selectedFormat, context: context) }
                    .disabled(viewModel.editedContent.isEmpty)
            }
        }
        .navigationTitle("Resume Builder")
    }
}
```

---

## Feature 7 — Export (PDF / LaTeX / DOCX)

### Step 7.1 — Create `ExportService`

**New file:** `ResumeForge/Core/Services/ExportService.swift`

```swift
import Foundation
#if canImport(UIKit)
import UIKit
#endif

enum ExportService {

    // MARK: PDF
    static func exportPDF(from text: String, title: String) throws -> URL {
        #if canImport(UIKit)
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 595, height: 842))
        let data = renderer.pdfData { ctx in
            ctx.beginPage()
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: 11, weight: .regular)
            ]
            (text as NSString).draw(in: CGRect(x: 40, y: 40, width: 515, height: 762), withAttributes: attrs)
        }
        let url = tmpURL(title: title, ext: "pdf")
        try data.write(to: url)
        return url
        #else
        // macOS: use NSAttributedString → NSPrintOperation or write plain text
        let url = tmpURL(title: title, ext: "pdf")
        try text.write(to: url, atomically: true, encoding: .utf8)
        return url
        #endif
    }

    // MARK: LaTeX
    static func exportLaTeX(from text: String, title: String) throws -> URL {
        let latex = """
        \\documentclass{article}
        \\usepackage[margin=1in]{geometry}
        \\begin{document}
        \(text)
        \\end{document}
        """
        let url = tmpURL(title: title, ext: "tex")
        try latex.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    // MARK: DOCX (minimal MVP — plain text with .docx extension)
    // For proper OOXML: add ZIPFoundation via SPM and build the XML structure.
    static func exportDOCX(from text: String, title: String) throws -> URL {
        let url = tmpURL(title: title, ext: "docx")
        try text.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private static func tmpURL(title: String, ext: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(title.replacingOccurrences(of: " ", with: "_"))
            .appendingPathExtension(ext)
    }
}
```

> **DOCX note:** Add [ZIPFoundation](https://github.com/weichsel/ZIPFoundation) via SPM for proper `.docx`. The minimal MVP above is a text file renamed `.docx`.

### Step 7.2 — Create `ExportViewModel`

**New file:** `ResumeForge/Features/Export/ExportViewModel.swift`

```swift
import Foundation

@Observable @MainActor
final class ExportViewModel {
    var selectedFormat: ResumeFormat = .pdf
    var exportedURL: URL?
    var showShareSheet: Bool = false
    var error: String?

    func export(resume: GeneratedResume) {
        do {
            let title = resume.displayTitle
            switch selectedFormat {
            case .pdf:   exportedURL = try ExportService.exportPDF(from: resume.generatedContent, title: title)
            case .latex: exportedURL = try ExportService.exportLaTeX(from: resume.generatedContent, title: title)
            case .docx:  exportedURL = try ExportService.exportDOCX(from: resume.generatedContent, title: title)
            }
            showShareSheet = true
        } catch {
            self.error = error.localizedDescription
        }
    }
}
```

### Step 7.3 — Replace `ExportPlaceholder.swift`

**File:** `ResumeForge/Features/Export/ExportPlaceholder.swift`

Replace with `ExportView`:
```swift
import SwiftUI
import SwiftData

struct ExportView: View {
    @Query private var resumes: [GeneratedResume]
    @State private var viewModel = ExportViewModel()
    @State private var selectedResume: GeneratedResume?

    var body: some View {
        List(resumes) { resume in
            Button(resume.displayTitle) { selectedResume = resume }
        }
        .safeAreaInset(edge: .bottom) {
            if let resume = selectedResume {
                VStack(spacing: 12) {
                    Picker("Format", selection: $viewModel.selectedFormat) {
                        ForEach(ResumeFormat.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Button("Export") { viewModel.export(resume: resume) }
                        .buttonStyle(.borderedProminent)
                }
                .padding()
                .background(.regularMaterial)
            }
        }
        .sheet(isPresented: $viewModel.showShareSheet) {
            if let url = viewModel.exportedURL {
                ShareSheet(items: [url])  // see below
            }
        }
        .navigationTitle("Export")
    }
}

// Thin UIViewControllerRepresentable wrapper for UIActivityViewController (iOS)
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
```

> On macOS, replace `ShareSheet` with a `NSSavePanel` call or use `ShareLink` from SwiftUI 16+.

---

## Wiring All Routes

**File:** `ResumeForge/App/ContentView.swift` (wherever `.navigationDestination(for: Route.self)` lives)

Ensure every `Route` case maps to a real view:
```swift
.navigationDestination(for: Route.self) { route in
    switch route {
    case .profile:        ProfileView()
    case .parseResume:    ResumeParserView()
    case .jobDescription: JobDescriptionView()
    case .aiCouncil:      AICouncilView()
    case .resumeBuilder:  ResumeBuilderView()   // was placeholder
    case .coverLetter:    CoverLetterView()      // was placeholder
    case .export:         ExportView()           // was placeholder
    case .settings:       SettingsView()
    }
}
```

### AICouncil → ResumeBuilder handoff

After `CouncilOrchestrator.analysisPhase == .complete`, show a "Build Resume" button in `AICouncilView` that calls `router.push(.resumeBuilder)` and passes `synthesisText` via a shared environment object or a dedicated `BuildSession` observable.

---

## Recommended Build Order

| # | Task | Depends on |
|---|---|---|
| 1 | `DraftProfile` + `DraftReviewView` | nothing |
| 2 | `PromptLibrary` | nothing |
| 3 | Single-key Council personas | `CouncilPrompts` (done) |
| 4 | `LLMLatexExtractor` + `parseJSON` | `PromptLibrary` |
| 5 | `StylePersona` model + `StylePersonaViewModel` | `PromptLibrary` |
| 6 | `StyleReferenceView` in Settings | step 5 |
| 7 | `CoverLetterViewModel` + `CoverLetterView` | steps 2, 5 |
| 8 | `ResumeBuilderViewModel` + `ResumeBuilderView` | step 2 |
| 9 | `ExportService` + `ExportView` | `GeneratedResume` (done) |
| 10 | Wire all routes in `ContentView` | all above |

---

## Coding Rules (never break these)

- `@Observable` only — never `ObservableObject` / `@Published`
- No force-unwrap `!` without an inline comment explaining why it's safe
- No view body > ~40 lines — split into named subviews
- Business logic in ViewModels and Services, never in Views
- All errors as typed Swift `Error` enums
- API keys only in Keychain — never UserDefaults or source code
- No file > 300 lines — split into extensions
- `async/await` only — no completion handlers or Combine
