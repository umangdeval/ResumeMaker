import Foundation
import SwiftData

@Model
final class StylePersona {
    var id: UUID
    var sampleText: String
    var derivedTraits: String
    var createdAt: Date

    init(sampleText: String = "", derivedTraits: String = "") {
        self.id = UUID()
        self.sampleText = sampleText
        self.derivedTraits = derivedTraits
        self.createdAt = .now
    }
}
