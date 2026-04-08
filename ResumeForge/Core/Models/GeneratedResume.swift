import SwiftData
import Foundation

@Model
final class GeneratedResume {
    var id: UUID
    var targetJobTitle: String
    var targetCompany: String
    var jobDescription: String
    /// The full resume text or markup ready for export.
    var generatedContent: String
    var format: ResumeFormat
    /// Merged AI Council feedback used to produce this resume.
    var councilFeedback: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        targetJobTitle: String = "",
        targetCompany: String = "",
        jobDescription: String = "",
        generatedContent: String = "",
        format: ResumeFormat = .pdf,
        councilFeedback: String = "",
        createdAt: Date = .now
    ) {
        self.id = id
        self.targetJobTitle = targetJobTitle
        self.targetCompany = targetCompany
        self.jobDescription = jobDescription
        self.generatedContent = generatedContent
        self.format = format
        self.councilFeedback = councilFeedback
        self.createdAt = createdAt
    }

    /// Display label for use in lists.
    var displayTitle: String {
        let company = targetCompany.isEmpty ? "Unknown Company" : targetCompany
        let role = targetJobTitle.isEmpty ? "Untitled Role" : targetJobTitle
        return "\(role) at \(company)"
    }
}

// MARK: - Supporting enum

enum ResumeFormat: String, Codable, CaseIterable {
    case pdf
    case latex
    case docx

    var displayName: String {
        switch self {
        case .pdf:   return "PDF"
        case .latex: return "LaTeX"
        case .docx:  return "DOCX"
        }
    }
}
