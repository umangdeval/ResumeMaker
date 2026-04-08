import Foundation

extension String {
    /// Returns true if the string is not empty after trimming whitespace.
    var isNotEmpty: Bool { !trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    /// Trims whitespace and newlines.
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }

    /// Splits the string into lines, filtering out blank lines.
    var nonBlankLines: [String] {
        components(separatedBy: .newlines).filter { $0.isNotEmpty }
    }
}
