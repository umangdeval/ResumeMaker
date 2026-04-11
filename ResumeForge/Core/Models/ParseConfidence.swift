import Foundation

/// Confidence level assigned to a value produced by the resume parser.
/// Surfaces in the review UI so users know which fields need attention.
enum ParseConfidence: Int, Comparable, Equatable, Sendable {
    /// Field was not found; value is empty or default.
    case missing = 0
    /// Positional guess — no structural signal matched; user should verify.
    case guessed = 1
    /// Heuristic match — keyword or pattern found, likely correct.
    case inferred = 2
    /// Strong structural signal — explicit separator, regex match, or multi-strategy agreement.
    case certain = 3

    static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }

    /// True when the value should be highlighted for user review.
    var needsReview: Bool { self <= .guessed }

    var label: String {
        switch self {
        case .missing:  return "Not found"
        case .guessed:  return "Guessed — please verify"
        case .inferred: return "Likely correct"
        case .certain:  return "High confidence"
        }
    }
}
