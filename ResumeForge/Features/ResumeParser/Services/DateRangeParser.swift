import Foundation

// MARK: - Parsed date range

struct ParsedDateRange: Sendable {
    let start: Date
    let end: Date?
    let isCurrent: Bool
}

// MARK: - Date range parser

enum DateRangeParser {
    static func parse(from line: String) -> ParsedDateRange? {
        // Strip location info appended after " | " before attempting date parse
        // e.g. "Apr 2025 | Guelph" → "Apr 2025"
        let cleaned = stripLocationSuffix(line)

        let separators = ["–", "—", " to "]
        for sep in separators {
            if let result = tryParse(cleaned, separator: sep) { return result }
        }

        // Hyphen "-" only when surrounded by spaces to avoid "Co-op", "full-time", etc.
        if let result = tryParse(cleaned, separator: " - ") { return result }

        // Year-only range: "2019 – 2022", "2019-2022"
        let fullYearPattern = #"((?:19|20)\d{2})\s*(?:[–\-—]|to)\s*((?:19|20)\d{2}|[Pp]resent)"#
        if let match = cleaned.range(of: fullYearPattern, options: .regularExpression) {
            let matched = String(cleaned[match])
            if let result = tryParse(matched, separator: "–") { return result }
            if let result = tryParse(matched, separator: "-") { return result }
        }

        return nil
    }

    private static func stripLocationSuffix(_ line: String) -> String {
        guard let pipeRange = line.range(of: " | ") else { return line }
        let beforePipe = String(line[..<pipeRange.lowerBound])
        let hasSeparator = ["–", "—", " - ", " to "].contains { beforePipe.contains($0) }
            || beforePipe.range(of: #"(?:19|20)\d{2}"#, options: .regularExpression) != nil
        return hasSeparator ? beforePipe : line
    }

    private static func tryParse(_ line: String, separator: String) -> ParsedDateRange? {
        let parts = line.components(separatedBy: separator).map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count == 2, let start = parseDate(parts[0]) else { return nil }
        let endStr = parts[1].lowercased()
        if endStr.contains("present") || endStr.contains("current") || endStr.contains("now") || endStr.isEmpty {
            return ParsedDateRange(start: start, end: nil, isCurrent: true)
        }
        if let end = parseDate(parts[1]) {
            return ParsedDateRange(start: start, end: end, isCurrent: false)
        }
        return nil
    }

    /// Finds a date range embedded within a longer line (inline resume format).
    /// Returns `nil` if the date occupies the whole line — use `parse(from:)` for that.
    static func parseSuffix(from line: String) -> (prefix: String, range: ParsedDateRange)? {
        let patterns = [
            // M/yyyy - M/yyyy or MM/yyyy - Present
            #"\d{1,2}/\d{4}\s*[-–—]\s*(?:\d{1,2}/\d{4}|[Pp]resent|[Cc]urrent|[Nn]ow)"#,
            // MMM yyyy – MMM yyyy or MMM yyyy – Present
            #"(?:Jan(?:uary)?|Feb(?:ruary)?|Mar(?:ch)?|Apr(?:il)?|May|Jun(?:e)?|Jul(?:y)?|Aug(?:ust)?|Sep(?:tember)?|Oct(?:ober)?|Nov(?:ember)?|Dec(?:ember)?)\s+\d{4}\s*[-–—]\s*(?:(?:Jan(?:uary)?|Feb(?:ruary)?|Mar(?:ch)?|Apr(?:il)?|May|Jun(?:e)?|Jul(?:y)?|Aug(?:ust)?|Sep(?:tember)?|Oct(?:ober)?|Nov(?:ember)?|Dec(?:ember)?)\s+\d{4}|[Pp]resent|[Cc]urrent)"#,
            // yyyy–yyyy or yyyy-Present
            #"(?:19|20)\d{2}\s*[-–—]\s*(?:(?:19|20)\d{2}|[Pp]resent|[Cc]urrent)"#,
        ]
        for pattern in patterns {
            guard let matchRange = line.range(of: pattern, options: .regularExpression) else { continue }
            let prefix = String(line[..<matchRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            guard !prefix.isEmpty else { continue }   // pure date line — caller uses parse(from:)
            let dateStr = String(line[matchRange])
            if let range = parse(from: dateStr) { return (prefix, range) }
        }
        return nil
    }

    static func parseDate(_ raw: String) -> Date? {
        let cleaned = raw.trimmingCharacters(in: .whitespaces)
        guard !cleaned.isEmpty, cleaned.filter(\.isNumber).count >= 2 else { return nil }

        let formats = ["MMMM yyyy", "MMM yyyy", "yyyy", "MM/yyyy", "M/yyyy", "MMMM d, yyyy", "MMM d, yyyy"]
        for fmt in formats {
            let f = DateFormatter()
            f.dateFormat = fmt
            f.locale = Locale(identifier: "en_US_POSIX")
            if let date = f.date(from: cleaned) { return date }
        }
        return nil
    }
}
