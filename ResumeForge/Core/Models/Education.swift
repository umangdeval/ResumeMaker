import SwiftData
import Foundation

@Model
final class Education {
    var id: UUID
    var institution: String
    var degree: String
    var field: String
    var graduationDate: Date
    var gpa: String?

    init(
        id: UUID = UUID(),
        institution: String = "",
        degree: String = "",
        field: String = "",
        graduationDate: Date = .now,
        gpa: String? = nil
    ) {
        self.id = id
        self.institution = institution
        self.degree = degree
        self.field = field
        self.graduationDate = graduationDate
        self.gpa = gpa
    }
}
