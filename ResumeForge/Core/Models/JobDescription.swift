import Foundation
import SwiftData

@Model
final class JobDescription {
    var id: UUID
    var title: String
    var company: String
    var rawText: String
    var companyWebsiteURL: String?
    var companyResearchNotes: String?
    var extractedSkills: [String]
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String = "",
        company: String = "",
        rawText: String = "",
        companyWebsiteURL: String? = nil,
        companyResearchNotes: String? = nil,
        extractedSkills: [String] = [],
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.company = company
        self.rawText = rawText
        self.companyWebsiteURL = companyWebsiteURL
        self.companyResearchNotes = companyResearchNotes
        self.extractedSkills = extractedSkills
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var displayTitle: String {
        let role = title.isEmpty ? "Untitled Role" : title
        let employer = company.isEmpty ? "Unknown Company" : company
        return "\(role) at \(employer)"
    }
}
