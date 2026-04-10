import Foundation

// MARK: - Multi-strategy experience entry extractor

/// Extracts experience entries from a section body using five field-mapping strategies.
/// Each strategy is scored independently; the highest-confidence result is kept.
///
/// Handled formats:
///   A  "Title (Company) Jan 2020 – Dec 2022"            — inline parenthetical
///   B  "Title | Company | Location | Jan 2020 – Dec 2022" — pipe-separated
///   C  "Title at Company\nJan 2020 – Dec 2022"          — "at" / "@" connector
///   D  "Title\nCompany\nJan 2020 – Dec 2022"            — title-first multi-line
///   E  "Company\nTitle\nJan 2020 – Dec 2022"            — company-first multi-line
enum ExperienceEntryExtractor {

    struct EntryResult {
        var title: String = ""
        var company: String = ""
        var startDate: Date?
        var endDate: Date?
        var isCurrent: Bool = false
        var bulletPoints: [String] = []
        var confidence: ParseConfidence = .guessed
    }

    static func extract(from lines: [String]) -> [EntryResult] {
        let anchors = findDateAnchors(in: lines)
        guard !anchors.isEmpty else { return [] }

        return anchors.enumerated().map { idx, anchor in
            let prevEnd   = idx > 0 ? anchors[idx - 1].lineIndex : -1
            let nextStart = idx + 1 < anchors.count ? anchors[idx + 1].lineIndex : lines.count

            let headerLines = collectHeaderLines(before: anchor.lineIndex, after: prevEnd, in: lines)
            let bullets     = collectBullets(from: anchor.lineIndex + 1, to: nextStart, in: lines)
            let (title, company, conf) = resolveFields(inlinePrefix: anchor.inlinePrefix, headerLines: headerLines)

            return EntryResult(
                title: title, company: company,
                startDate: anchor.range.start,
                endDate: anchor.range.isCurrent ? nil : anchor.range.end,
                isCurrent: anchor.range.isCurrent,
                bulletPoints: bullets,
                confidence: conf
            )
        }
    }

    // MARK: - Date anchor detection

    private struct DateAnchor {
        let lineIndex: Int
        let range: ParsedDateRange
        /// Non-nil when the date was on the same line as other text (inline format).
        let inlinePrefix: String?
    }

    private static func findDateAnchors(in lines: [String]) -> [DateAnchor] {
        lines.enumerated().compactMap { i, line in
            if let (prefix, range) = DateRangeParser.parseSuffix(from: line) {
                return DateAnchor(lineIndex: i, range: range, inlinePrefix: prefix)
            }
            if let range = DateRangeParser.parse(from: line) {
                return DateAnchor(lineIndex: i, range: range, inlinePrefix: nil)
            }
            return nil
        }
    }

    // MARK: - Line collection

    /// Collects non-bullet, non-empty lines immediately before the date anchor,
    /// stopping at a blank line (entry boundary) or the previous entry's anchor line.
    private static func collectHeaderLines(before anchorLine: Int, after prevLine: Int, in lines: [String]) -> [String] {
        var result: [String] = []
        var i = anchorLine - 1
        while i > prevLine {
            let line = lines[i]
            if line.isEmpty { break }
            let isBullet = line.hasPrefix("•") || line.hasPrefix("–") || line.hasPrefix("-")
            let isDate   = DateRangeParser.parse(from: line) != nil
            if !isBullet && !isDate { result.insert(line, at: 0) }
            i -= 1
        }
        return result
    }

    private static func collectBullets(from start: Int, to end: Int, in lines: [String]) -> [String] {
        lines[start..<min(end, lines.count)]
            .filter { $0.hasPrefix("•") || $0.hasPrefix("–") || $0.hasPrefix("-") }
            .map    { String($0.dropFirst()).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    // MARK: - Field resolution

    private static func resolveFields(
        inlinePrefix: String?,
        headerLines: [String]
    ) -> (title: String, company: String, confidence: ParseConfidence) {

        // Strategy A/B/C — inline: date was on the same line as the header text
        if let prefix = inlinePrefix, !prefix.isEmpty {
            let (t, c) = splitBySeparators(prefix)
            if !t.isEmpty { return (t, c, .certain) }
        }

        let relevant = headerLines.filter { !isLocationLine($0) }
        guard !relevant.isEmpty else { return ("", "", .missing) }

        // Strategies B/C on a standalone header line
        if relevant.count == 1 {
            let (t, c) = splitBySeparators(relevant[0])
            if !c.isEmpty { return (t, c, .certain) }
            return (relevant[0], "", .inferred)
        }

        // Strategies D/E — multi-line: score each line as title vs company
        return scoreMultiLine(relevant)
    }

    /// Splits a line using known separators: `(Company)`, ` | `, ` at `, ` @ `.
    private static func splitBySeparators(_ line: String) -> (title: String, company: String) {
        // Parenthetical: "Title (Company)"
        if let open = line.firstIndex(of: "("), let close = line[open...].firstIndex(of: ")") {
            let co = String(line[line.index(after: open)..<close]).trimmingCharacters(in: .whitespaces)
            let ti = String(line[..<open]).trimmingCharacters(in: CharacterSet(charactersIn: ", ").union(.whitespaces))
            if !co.isEmpty { return (ti, co) }
        }
        // Pipe: "Title | Company" or "Title | Company | Location"
        if line.contains(" | ") {
            let parts = line.components(separatedBy: " | ").map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count >= 2, !parts[1].isEmpty { return (parts[0], parts[1]) }
        }
        // "at" or "@" connectors: "Title at Company", "Title @ Company"
        for sep in [" at ", " @ "] {
            if let r = line.range(of: sep, options: .caseInsensitive) {
                let ti = String(line[..<r.lowerBound]).trimmingCharacters(in: .whitespaces)
                let co = String(line[r.upperBound...]).trimmingCharacters(in: .whitespaces)
                if !ti.isEmpty && !co.isEmpty { return (ti, co) }
            }
        }
        return (line, "")
    }

    // MARK: - Keyword scoring for multi-line entries

    private static let titleSignals: Set<String> = [
        "engineer", "developer", "designer", "analyst", "manager", "director", "lead",
        "architect", "consultant", "specialist", "coordinator", "supervisor", "associate",
        "intern", "administrator", "officer", "head", "chief", "researcher", "scientist",
        "technician", "programmer", "devops", "product", "project", "senior", "junior",
        "staff", "principal", "representative", "assistant", "co-op", "coop", "student"
    ]

    private static let companySignals: Set<String> = [
        "inc", "llc", "ltd", "corp", "company", "group", "solutions", "technologies",
        "systems", "services", "consulting", "labs", "studio", "studios", "partners",
        "associates", "foundation", "agency", "bank", "university", "college", "institute",
        "hospital", "clinic", "school", "government", "ministry", "department"
    ]

    private static func titleScore(_ line: String) -> Int {
        let lower = line.lowercased()
        return titleSignals.filter { lower.contains($0) }.count
    }

    private static func companyScore(_ line: String) -> Int {
        let tokens = line.lowercased()
            .components(separatedBy: .whitespaces)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
        return tokens.filter { companySignals.contains($0) }.count
    }

    private static func isLocationLine(_ line: String) -> Bool {
        guard !line.hasPrefix("•"), !line.hasPrefix("-"),
              DateRangeParser.parse(from: line) == nil else { return false }
        let words = line.split(separator: " ")
        return words.count <= 4 && (line == "Remote" || line.contains(","))
    }

    private static func scoreMultiLine(_ lines: [String]) -> (String, String, ParseConfidence) {
        let scored = lines.map { ($0, titleScore($0), companyScore($0)) }

        let titleHit   = scored.contains { $0.1 > 0 }
        let companyHit = scored.contains { $0.2 > 0 }

        guard titleHit || companyHit else {
            // No keywords matched — positional fallback: line[0] = title, line[1] = company
            return (lines[0], lines.count > 1 ? lines[1] : "", .guessed)
        }

        let bestTitle   = scored.max { $0.1 < $1.1 }.map { $0.0 } ?? ""
        let remaining   = scored.filter { $0.0 != bestTitle }
        let bestCompany = remaining.max { $0.2 < $1.2 }.map { $0.0 } ?? ""

        let conf: ParseConfidence = (titleHit && companyHit) ? .certain : .inferred
        return (bestTitle, bestCompany, conf)
    }
}
