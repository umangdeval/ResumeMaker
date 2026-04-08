import SwiftData
import Foundation

/// A tailored resume generated for a specific job description.
@Model
final class Resume {
    var id: UUID
    var title: String
    /// Raw source text (PDF-extracted or LaTeX) used as the base for this resume.
    var sourceText: String
    /// The structured sections after parsing / generation.
    var sections: [ResumeSection]
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String = "",
        sourceText: String = "",
        sections: [ResumeSection] = [],
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.sourceText = sourceText
        self.sections = sections
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Value types

struct ResumeSection: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var kind: ResumeSectionKind
    var content: String
}

enum ResumeSectionKind: String, Codable, CaseIterable {
    case header
    case summary
    case workExperience
    case education
    case skills
    case projects
    case certifications
    case custom
}
