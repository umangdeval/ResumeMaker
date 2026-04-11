import Foundation

@Observable
@MainActor
final class ExportViewModel {
    var selectedFormat: ResumeFormat = .pdf
    var exportedURL: URL?
    var showShareSheet: Bool = false
    var error: String?

    func export(resume: GeneratedResume) {
        do {
            let title = resume.displayTitle
            switch selectedFormat {
            case .pdf:
                exportedURL = try ExportService.exportPDF(from: resume.generatedContent, title: title)
            case .latex:
                exportedURL = try ExportService.exportLaTeX(from: resume.generatedContent, title: title)
            case .docx:
                exportedURL = try ExportService.exportDOCX(from: resume.generatedContent, title: title)
            }
            showShareSheet = true
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }
}
