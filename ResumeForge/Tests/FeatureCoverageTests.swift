import Foundation
import SwiftData
import Testing
@testable import ResumeForge

@Suite("Feature Method Coverage")
@MainActor
struct FeatureCoverageTests {
    @Test("StylePersonaViewModel.load reads saved persona")
    func stylePersonaLoad() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let persona = StylePersona(sampleText: "sample", derivedTraits: "Formal")
        context.insert(persona)
        try context.save()

        let vm = StylePersonaViewModel()
        vm.load(context: context)

        #expect(vm.sampleText == "sample")
        #expect(vm.derivedTraits == "Formal")
    }

    @Test("StylePersonaViewModel.analyseStyle saves derived traits")
    func stylePersonaAnalyse() async throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let vm = StylePersonaViewModel()
        vm.sampleText = "I am excited to apply."

        let service = MockAIService(completeText: "Confident, direct, concise")
        await vm.analyseStyle(service: service, context: context)

        #expect(vm.derivedTraits.contains("Confident"))
        let rows = try context.fetch(FetchDescriptor<StylePersona>())
        #expect(rows.count == 1)
        #expect(rows[0].derivedTraits.contains("direct"))
    }

    @Test("CoverLetterViewModel.generate streams text")
    func coverLetterGenerate() async throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let vm = CoverLetterViewModel()

        let profile = UserProfile(fullName: "Jane Doe", summary: "iOS Engineer")
        let job = JobDescription(title: "Senior iOS Engineer", company: "Acme", rawText: "Swift, SwiftUI")
        let service = MockAIService(streamChunks: ["Hello ", "Acme", " team."])

        await vm.generate(profile: profile, job: job, styleTraits: "Formal", service: service, context: context)

        #expect(vm.generatedText == "Hello Acme team.")
        #expect(vm.error == nil)
    }

    @Test("CoverLetterViewModel.save inserts model")
    func coverLetterSave() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let vm = CoverLetterViewModel()
        vm.generatedText = "Final cover letter text"

        let job = JobDescription(title: "Engineer", company: "Contoso", rawText: "Job text")
        vm.save(job: job, context: context)

        let rows = try context.fetch(FetchDescriptor<CoverLetter>())
        #expect(rows.count == 1)
        #expect(rows[0].targetCompany == "Contoso")
        #expect(rows[0].content == "Final cover letter text")
    }

    @Test("ResumeBuilderViewModel.generate sets edited content")
    func resumeBuilderGenerate() async {
        let vm = ResumeBuilderViewModel()
        let profile = UserProfile(fullName: "Sam", summary: "Engineer")
        let job = JobDescription(title: "iOS", company: "Example", rawText: "Swift")
        let service = MockAIService(completeText: "ATS resume output")

        await vm.generate(
            profile: profile,
            job: job,
            councilSynthesis: "Focus keywords",
            outputFormat: .pdf,
            service: service
        )

        #expect(vm.editedContent == "ATS resume output")
        #expect(vm.error == nil)
    }

    @Test("ResumeBuilderViewModel.save inserts GeneratedResume")
    func resumeBuilderSave() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let vm = ResumeBuilderViewModel()
        vm.editedContent = "Tailored resume"
        let job = JobDescription(title: "iOS", company: "Northwind", rawText: "JD")

        vm.save(job: job, format: .latex, councilSynthesis: "Synth", context: context)

        let rows = try context.fetch(FetchDescriptor<GeneratedResume>())
        #expect(rows.count == 1)
        #expect(rows[0].format == .latex)
        #expect(rows[0].councilFeedback == "Synth")
        #expect(vm.savedResume != nil)
    }

    @Test("ResumeBuilder default format prefers LaTeX if last import was tex")
    func resumeBuilderDefaultFormat() {
        UserDefaults.standard.set("latex", forKey: "parser.lastImportedFileType")
        #expect(ResumeBuilderViewModel.preferredOutputFormatFromLastImport() == .latex)

        UserDefaults.standard.set("pdf", forKey: "parser.lastImportedFileType")
        #expect(ResumeBuilderViewModel.preferredOutputFormatFromLastImport() == .pdf)
    }

    @Test("PromptLibrary resume builder prompt is ATS and format aware")
    func promptLibraryATS() {
        let profile = UserProfile(fullName: "A", summary: "B")
        let job = JobDescription(title: "Role", company: "Company", rawText: "Desc")
        let prompt = PromptLibrary.resumeBuilderUser(profile: profile, job: job, synthesis: "s", outputFormat: .latex)

        #expect(prompt.contains("Required output format: LaTeX"))
        #expect(PromptLibrary.resumeBuilderSystem.contains("ATS"))
        #expect(PromptLibrary.resumeBuilderSystem.contains("Never invent facts"))
    }

    @Test("ExportService writes files for all formats")
    func exportServiceWrites() throws {
        let pdfURL = try ExportService.exportPDF(from: "hello", title: "sample")
        let texURL = try ExportService.exportLaTeX(from: "hello", title: "sample")
        let docxURL = try ExportService.exportDOCX(from: "hello", title: "sample")

        #expect(FileManager.default.fileExists(atPath: pdfURL.path))
        #expect(FileManager.default.fileExists(atPath: texURL.path))
        #expect(FileManager.default.fileExists(atPath: docxURL.path))
        #expect(pdfURL.pathExtension == "pdf")
        #expect(texURL.pathExtension == "tex")
        #expect(docxURL.pathExtension == "docx")
    }

    @Test("ExportViewModel exports and sets share state")
    func exportViewModelExport() {
        let vm = ExportViewModel()
        vm.selectedFormat = .docx
        let resume = GeneratedResume(targetJobTitle: "Role", targetCompany: "Co", generatedContent: "content")

        vm.export(resume: resume)

        #expect(vm.exportedURL != nil)
        #expect(vm.showShareSheet == true)
        #expect(vm.error == nil)
    }

    @Test("Integration: cover letter + resume builder + export")
    func fullFeatureFlow() async throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)

        let profile = UserProfile(fullName: "Jamie", summary: "iOS Developer")
        let job = JobDescription(title: "Senior iOS", company: "Acme", rawText: "SwiftUI, architecture")
        let style = StylePersona(sampleText: "sample", derivedTraits: "Formal, direct")
        context.insert(profile)
        context.insert(job)
        context.insert(style)
        try context.save()

        let llm = MockAIService(streamChunks: ["Dear ", "Acme"], completeText: "ATS resume")

        let cl = CoverLetterViewModel()
        await cl.generate(profile: profile, job: job, styleTraits: style.derivedTraits, service: llm, context: context)
        cl.save(job: job, context: context)
        #expect(try context.fetch(FetchDescriptor<CoverLetter>()).count == 1)

        let rb = ResumeBuilderViewModel()
        await rb.generate(profile: profile, job: job, councilSynthesis: "Keyword optimize", outputFormat: .pdf, service: llm)
        rb.save(job: job, format: .pdf, councilSynthesis: "Keyword optimize", context: context)

        let savedResumes = try context.fetch(FetchDescriptor<GeneratedResume>())
        #expect(savedResumes.count == 1)

        let exportVM = ExportViewModel()
        exportVM.selectedFormat = .pdf
        exportVM.export(resume: savedResumes[0])
        #expect(exportVM.exportedURL != nil)
        #expect(exportVM.showShareSheet == true)
    }
}

private func makeInMemoryContainer() throws -> ModelContainer {
    try ModelContainer(
        for: UserProfile.self,
        Experience.self,
        Education.self,
        JobDescription.self,
        GeneratedResume.self,
        CoverLetter.self,
        StylePersona.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
}

private struct MockAIService: AIServiceProtocol {
    let providerName: String = "Mock"
    let streamChunks: [String]
    let completeText: String

    init(streamChunks: [String] = ["ok"], completeText: String = "ok") {
        self.streamChunks = streamChunks
        self.completeText = completeText
    }

    func estimateTokens(for prompt: String) -> Int {
        max(1, prompt.count / 4)
    }

    func stream(prompt: String, systemPrompt: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                for chunk in streamChunks {
                    continuation.yield(chunk)
                }
                continuation.finish()
            }
        }
    }

    func complete(prompt: String, systemPrompt: String) async throws -> String {
        completeText
    }
}
