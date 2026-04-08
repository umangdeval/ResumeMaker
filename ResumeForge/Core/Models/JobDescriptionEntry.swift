import SwiftData
import Foundation

@Model
final class JobDescriptionEntry {
    var id: UUID
    var companyName: String
    var roleName: String
    /// Full raw text of the job description.
    var rawText: String
    /// Key requirements extracted by the AI or manually.
    var extractedRequirements: [String]
    var createdAt: Date

    init(
        id: UUID = UUID(),
        companyName: String = "",
        roleName: String = "",
        rawText: String = "",
        extractedRequirements: [String] = [],
        createdAt: Date = .now
    ) {
        self.id = id
        self.companyName = companyName
        self.roleName = roleName
        self.rawText = rawText
        self.extractedRequirements = extractedRequirements
        self.createdAt = createdAt
    }

    /// Display label used in lists.
    var displayTitle: String {
        "\(roleName.isEmpty ? "Untitled Role" : roleName) at \(companyName.isEmpty ? "Unknown Company" : companyName)"
    }
}
