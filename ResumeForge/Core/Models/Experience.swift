import SwiftData
import Foundation

@Model
final class Experience {
    var id: UUID
    var company: String
    var title: String
    var startDate: Date
    /// `nil` means this is the current position.
    var endDate: Date?
    var jobDescription: String
    var bulletPoints: [String]

    init(
        id: UUID = UUID(),
        company: String = "",
        title: String = "",
        startDate: Date = .now,
        endDate: Date? = nil,
        jobDescription: String = "",
        bulletPoints: [String] = []
    ) {
        self.id = id
        self.company = company
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.jobDescription = jobDescription
        self.bulletPoints = bulletPoints
    }

    var isCurrent: Bool { endDate == nil }
}
