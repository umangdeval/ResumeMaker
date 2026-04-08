import SwiftData
import Foundation

@Model
final class UserProfile {
    var id: UUID
    var fullName: String
    var email: String
    var phone: String
    var location: String
    var linkedInURL: String
    var githubURL: String
    var websiteURL: String
    var summary: String
    var workExperiences: [WorkExperience]
    var educations: [Education]
    var skills: [String]
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        fullName: String = "",
        email: String = "",
        phone: String = "",
        location: String = "",
        linkedInURL: String = "",
        githubURL: String = "",
        websiteURL: String = "",
        summary: String = "",
        workExperiences: [WorkExperience] = [],
        educations: [Education] = [],
        skills: [String] = [],
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.fullName = fullName
        self.email = email
        self.phone = phone
        self.location = location
        self.linkedInURL = linkedInURL
        self.githubURL = githubURL
        self.websiteURL = websiteURL
        self.summary = summary
        self.workExperiences = workExperiences
        self.educations = educations
        self.skills = skills
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Embedded value types (stored as Codable blobs by SwiftData)

struct WorkExperience: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var company: String
    var title: String
    var location: String
    var startDate: Date
    var endDate: Date?
    var isCurrent: Bool
    var bullets: [String]
}

struct Education: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var institution: String
    var degree: String
    var field: String
    var startDate: Date
    var endDate: Date?
    var gpa: String
}
