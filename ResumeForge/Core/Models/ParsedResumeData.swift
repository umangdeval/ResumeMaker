import Foundation

// MARK: - Top-level result

/// Best-effort structured data extracted from a raw resume text.
/// All fields are optional — the parser fills what it can; the user corrects the rest.
struct ParsedResumeData: Sendable {
    var name: String
    var email: String
    var phone: String
    var linkedIn: String
    var github: String
    var website: String
    var summary: String
    var experiences: [ParsedExperience]
    var education: [ParsedEducation]
    var skills: [String]
    /// Section names that were detected in the raw text (used for UI display).
    var detectedSections: [String]

    init(
        name: String = "",
        email: String = "",
        phone: String = "",
        linkedIn: String = "",
        github: String = "",
        website: String = "",
        summary: String = "",
        experiences: [ParsedExperience] = [],
        education: [ParsedEducation] = [],
        skills: [String] = [],
        detectedSections: [String] = []
    ) {
        self.name = name
        self.email = email
        self.phone = phone
        self.linkedIn = linkedIn
        self.github = github
        self.website = website
        self.summary = summary
        self.experiences = experiences
        self.education = education
        self.skills = skills
        self.detectedSections = detectedSections
    }
}

// MARK: - Nested types

struct ParsedExperience: Sendable, Identifiable {
    var id: UUID = UUID()
    var company: String
    var title: String
    var startDate: Date?
    var endDate: Date?
    var isCurrent: Bool
    var bulletPoints: [String]

    init(
        company: String = "",
        title: String = "",
        startDate: Date? = nil,
        endDate: Date? = nil,
        isCurrent: Bool = false,
        bulletPoints: [String] = []
    ) {
        self.company = company
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.isCurrent = isCurrent
        self.bulletPoints = bulletPoints
    }
}

struct ParsedEducation: Sendable, Identifiable {
    var id: UUID = UUID()
    var institution: String
    var degree: String
    var field: String
    var graduationDate: Date?
    var gpa: String

    init(
        institution: String = "",
        degree: String = "",
        field: String = "",
        graduationDate: Date? = nil,
        gpa: String = ""
    ) {
        self.institution = institution
        self.degree = degree
        self.field = field
        self.graduationDate = graduationDate
        self.gpa = gpa
    }
}
