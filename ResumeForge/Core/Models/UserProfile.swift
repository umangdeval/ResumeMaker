import SwiftData
import Foundation

@Model
final class UserProfile {
    var id: UUID
    var fullName: String
    var email: String
    var phone: String
    var linkedIn: String?
    var github: String?
    var website: String?
    var summary: String
    var skills: [String]
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade) var experiences: [Experience]
    @Relationship(deleteRule: .cascade) var education: [Education]

    init(
        id: UUID = UUID(),
        fullName: String = "",
        email: String = "",
        phone: String = "",
        linkedIn: String? = nil,
        github: String? = nil,
        website: String? = nil,
        summary: String = "",
        skills: [String] = [],
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.fullName = fullName
        self.email = email
        self.phone = phone
        self.linkedIn = linkedIn
        self.github = github
        self.website = website
        self.summary = summary
        self.skills = skills
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.experiences = []
        self.education = []
    }
}
