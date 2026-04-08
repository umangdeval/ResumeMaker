import SwiftData
import Foundation

@Model
final class CoverLetter {
    var id: UUID
    /// The job this cover letter targets.
    var jobDescriptionID: UUID
    /// The resume this cover letter was generated alongside.
    var resumeID: UUID
    var content: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        jobDescriptionID: UUID,
        resumeID: UUID,
        content: String = "",
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.jobDescriptionID = jobDescriptionID
        self.resumeID = resumeID
        self.content = content
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
