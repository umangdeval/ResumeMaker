import SwiftData
import Foundation

@Model
final class CoverLetter {
    var id: UUID
    var targetJobTitle: String
    var targetCompany: String
    var content: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        targetJobTitle: String = "",
        targetCompany: String = "",
        content: String = "",
        createdAt: Date = .now
    ) {
        self.id = id
        self.targetJobTitle = targetJobTitle
        self.targetCompany = targetCompany
        self.content = content
        self.createdAt = createdAt
    }
}
