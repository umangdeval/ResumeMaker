import Foundation

// MARK: - Parser

/// Heuristically parses plain text (from PDF or LaTeX extraction) into `ParsedResumeData`.
/// Best-effort only — the user reviews and corrects the result.
enum ResumeContentParser {
    static func parse(_ text: String) -> ParsedResumeData {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        var data = ParsedResumeData()
        let sections = splitIntoSections(lines)
        data.detectedSections = sections.map(\.name)

        data.name = extractName(from: lines)

        let contactWindow = Array(lines.prefix(10))
        data.email = extractEmail(from: contactWindow)
        data.phone = extractPhone(from: contactWindow)
        let links = extractLinks(from: contactWindow)
        data.linkedIn = links.first { $0.contains("linkedin") } ?? ""
        data.github   = links.first { $0.contains("github") }   ?? ""
        data.website  = links.first { !$0.contains("linkedin") && !$0.contains("github") } ?? ""

        for section in sections {
            let lower = section.name.lowercased()
            if lower.contains("summary") || lower.contains("objective") || lower.contains("profile") {
                data.summary = section.body.joined(separator: " ")
            } else if lower.contains("experience") || lower.contains("work") || lower.contains("employment") {
                data.experiences = parseExperiences(from: section.body)
            } else if lower.contains("education") || lower.contains("academic") {
                data.education = parseEducation(from: section.body)
            } else if lower.contains("skill") || lower.contains("technologies") || lower.contains("competencies") {
                data.skills = parseSkills(from: section.body)
            }
        }

        return data
    }

    // MARK: - Section splitting

    private struct Section {
        let name: String
        let body: [String]
    }

    /// Section heading keywords — intentionally excludes "tools" to avoid splitting skill sublists.
    private static let sectionKeywords = [
        "experience", "work history", "employment", "positions",
        "education", "academic", "qualifications",
        "skills", "technologies", "competencies",
        "summary", "objective", "profile", "about",
        "projects", "achievements", "certifications", "awards",
        "publications", "volunteer", "languages"
    ]

    private static func isSectionHeading(_ line: String) -> Bool {
        let lower = line.lowercased()
        // Markdown-style from LaTeX extractor
        if line.hasPrefix("## ") || line.hasPrefix("### ") { return true }
        // All-caps line that is NOT a common non-heading abbreviation
        let allCapsExclusions = ["OOP", "API", "GPA", "UI", "UX", "IT", "QA", "OS", "ML", "AI"]
        if line == line.uppercased() && line.count > 3 && line.count <= 30
            && !allCapsExclusions.contains(line)
            && line.filter(\.isLetter).count >= 3 { return true }
        // Match known section keyword only when it's the whole line (or nearly so)
        // — prevents short words like "tools" inside longer non-heading lines from triggering
        return sectionKeywords.contains { lower == $0 || lower.hasPrefix($0 + " ") } && line.count < 40
    }

    private static func sectionName(from line: String) -> String {
        line.replacingOccurrences(of: "^#+\\s*", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }

    private static func splitIntoSections(_ lines: [String]) -> [Section] {
        var sections: [Section] = []
        var currentName = "Header"
        var currentBody: [String] = []

        for line in lines {
            if isSectionHeading(line) {
                if !currentBody.isEmpty {
                    sections.append(Section(name: currentName, body: currentBody))
                }
                currentName = sectionName(from: line)
                currentBody = []
            } else {
                currentBody.append(line)
            }
        }
        if !currentBody.isEmpty {
            sections.append(Section(name: currentName, body: currentBody))
        }
        return sections
    }

    // MARK: - Name extraction

    private static func extractName(from lines: [String]) -> String {
        for line in lines.prefix(5) {
            guard !line.contains("@"),
                  !line.contains("http"),
                  !line.contains("linkedin"),
                  !line.contains("github"),
                  !line.contains("|"),
                  line.filter(\.isNumber).count <= 2,
                  line.count > 2,
                  line.count < 60
            else { continue }
            // Looks like a name if it's mostly letters and spaces
            let letterRatio = Double(line.filter { $0.isLetter || $0.isWhitespace }.count) / Double(line.count)
            if letterRatio > 0.85 { return line }
        }
        return ""
    }

    // MARK: - Contact extraction

    static func extractEmail(from lines: [String]) -> String {
        let pattern = #"[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}"#
        for line in lines {
            if let match = line.range(of: pattern, options: .regularExpression) {
                return String(line[match])
            }
        }
        return ""
    }

    static func extractPhone(from lines: [String]) -> String {
        let pattern = #"(?:\+?1[\s\-.]?)?\(?\d{3}\)?[\s\-.]?\d{3}[\s\-.]?\d{4}"#
        for line in lines {
            if let match = line.range(of: pattern, options: .regularExpression) {
                return String(line[match])
            }
        }
        return ""
    }

    private static func extractLinks(from lines: [String]) -> [String] {
        // Match URLs with or without scheme (e.g. linkedin.com/in/... or https://linkedin.com/...)
        let pattern = #"(?:https?://)?(?:www\.)?(?:[a-zA-Z0-9\-]+\.)+[a-zA-Z]{2,}(?:/[^\s,;|•)(<>\[\]]*)?"#
        var links: [String] = []
        var seen = Set<String>()
        for line in lines {
            var search = line[line.startIndex...]
            while let match = search.range(of: pattern, options: .regularExpression) {
                let urlStr = String(search[match]).trimmingCharacters(in: CharacterSet(charactersIn: ".,"))
                // Skip plain domain-like words that aren't URLs (e.g. "e.g", "i.e")
                if urlStr.contains("/") || urlStr.hasPrefix("http") || urlStr.hasPrefix("www") {
                    if !seen.contains(urlStr) {
                        links.append(urlStr)
                        seen.insert(urlStr)
                    }
                }
                search = search[match.upperBound...]
            }
        }
        return links
    }

    // MARK: - Experience parsing

    /// Handles the common resume pattern:
    ///   Company | Title           ← line BEFORE date
    ///   Date – Date | Location    ← date line (may include location after |)
    ///   • Bullet…
    private static func parseExperiences(from lines: [String]) -> [ParsedExperience] {
        // Pass 1: find indices of all date-range lines
        var dateLine: [(index: Int, range: ParsedDateRange)] = []
        for (i, line) in lines.enumerated() {
            if let range = DateRangeParser.parse(from: line) {
                dateLine.append((i, range))
            }
        }

        guard !dateLine.isEmpty else { return [] }

        var result: [ParsedExperience] = []

        for (entryIdx, entry) in dateLine.enumerated() {
            let nextStart = entryIdx + 1 < dateLine.count ? dateLine[entryIdx + 1].index : lines.count

            // Collect bullet points — lines after the date until the next entry
            let bodyLines = lines[(entry.index + 1)..<nextStart]
            let bullets = bodyLines
                .filter { $0.hasPrefix("•") || $0.hasPrefix("–") || $0.hasPrefix("-") }
                .map { $0.dropFirst().trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }

            // Look backwards for the company/title line (immediately before date line)
            var company = ""
            var title = ""
            if entry.index > 0 {
                let candidate = lines[entry.index - 1]
                // Skip if it's a bullet or another date
                if !candidate.hasPrefix("•") && DateRangeParser.parse(from: candidate) == nil {
                    if candidate.contains(" | ") {
                        // "Company | Title" same-line format
                        let parts = candidate.components(separatedBy: " | ")
                        company = parts[0].trimmingCharacters(in: .whitespaces)
                        title = parts.dropFirst().joined(separator: " | ").trimmingCharacters(in: .whitespaces)
                    } else {
                        // Guess: title-only or company-only line
                        title = candidate
                    }
                }
            }

            result.append(ParsedExperience(
                company: company,
                title: title,
                startDate: entry.range.start,
                endDate: entry.range.isCurrent ? nil : entry.range.end,
                isCurrent: entry.range.isCurrent,
                bulletPoints: bullets
            ))
        }
        return result
    }

    // MARK: - Education parsing

    /// Handles both "Expected YYYY" graduation years and "YYYY – YYYY | GPA: X.X" combined lines.
    private static func parseEducation(from lines: [String]) -> [ParsedEducation] {
        // Split into institution blocks: a new block starts on a line that is
        // not a bullet, not a date range, and looks like an institution name
        // (determined by not being a descriptor line for the current block).
        var blocks: [[String]] = []
        var currentBlock: [String] = []

        for line in lines {
            let isBullet = line.hasPrefix("•") || line.hasPrefix("-")
            let isDate = DateRangeParser.parse(from: line) != nil
            let isExpected = line.lowercased().hasPrefix("expected")
            let isGPA = line.lowercased().contains("gpa")
            let isMinor = line.lowercased().hasPrefix("minor")
            let isDeansList = line.lowercased().contains("dean")

            // A line that starts a new institution: not a bullet, not a date/meta line,
            // and there's already content in the current block.
            let isMeta = isBullet || isDate || isExpected || isGPA || isMinor || isDeansList
            if !isMeta && !currentBlock.isEmpty {
                // Heuristic: if current block already has an institution name (first line)
                // and this new line looks like another institution, start a new block.
                blocks.append(currentBlock)
                currentBlock = []
            }
            currentBlock.append(line)
        }
        if !currentBlock.isEmpty { blocks.append(currentBlock) }

        return blocks.compactMap { parseEducationBlock($0) }
    }

    private static func parseEducationBlock(_ lines: [String]) -> ParsedEducation? {
        var edu = ParsedEducation()
        var lineIdx = 0
        for line in lines {
            if let range = DateRangeParser.parse(from: line) {
                edu.graduationDate = range.end ?? range.start
            } else if line.lowercased().hasPrefix("expected") {
                // "Expected 2028" — extract the 4-digit year
                let yearMatch = line.range(of: #"(?:19|20)\d{2}"#, options: .regularExpression)
                if let r = yearMatch, let date = DateRangeParser.parseDate(String(line[r])) {
                    edu.graduationDate = date
                }
            } else if line.lowercased().contains("gpa") {
                // Extract numeric GPA value
                let gpaMatch = line.range(of: #"\d\.\d{1,2}"#, options: .regularExpression)
                edu.gpa = gpaMatch.map { String(line[$0]) } ?? line
            } else if line.lowercased().hasPrefix("minor") || line.lowercased().contains("dean") {
                // Metadata — skip
                continue
            } else {
                switch lineIdx {
                case 0: edu.institution = line
                case 1:
                    let (deg, field) = splitDegree(line)
                    edu.degree = deg
                    edu.field = field
                default: break
                }
                lineIdx += 1
            }
        }
        return edu.institution.isEmpty ? nil : edu
    }

    private static func splitDegree(_ line: String) -> (degree: String, field: String) {
        let trim: (String) -> String = { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        let separators = [" in ", " of Science in ", " of Arts in ", " of Engineering in "]
        for sep in separators {
            if let range = line.range(of: sep, options: .caseInsensitive) {
                return (trim(String(line[..<range.lowerBound])),
                        trim(String(line[range.upperBound...])))
            }
        }
        // Try comma split: "B.Comp, Computer Science" → ("B.Comp", "Computer Science")
        if let commaIdx = line.firstIndex(of: ",") {
            let degree = trim(String(line[..<commaIdx]))
            let field  = trim(String(line[line.index(after: commaIdx)...]))
            if !degree.isEmpty && !field.isEmpty { return (degree, field) }
        }
        return (line, "")
    }

    // MARK: - Skills parsing

    private static func parseSkills(from lines: [String]) -> [String] {
        var skills: [String] = []
        for line in lines {
            // Skip subsection labels (short single-word lines without commas or bullets)
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let isSubLabel = !trimmed.contains(",") && !trimmed.hasPrefix("•") && trimmed.split(separator: " ").count <= 2
            if isSubLabel && trimmed.filter(\.isNumber).count == 0 && trimmed.count < 20 { continue }

            let parts = trimmed.components(separatedBy: ",")
            if parts.count > 1 {
                skills.append(contentsOf: parts.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty })
            } else if trimmed.hasPrefix("•") || trimmed.hasPrefix("-") {
                let skill = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
                if !skill.isEmpty { skills.append(skill) }
            } else if !trimmed.isEmpty {
                skills.append(trimmed)
            }
        }
        return skills
    }
}

// MARK: - Date range parser (internal, also used by tests)

struct ParsedDateRange: Sendable {
    let start: Date
    let end: Date?
    let isCurrent: Bool
}

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
        let yearPattern = #"((?:19|20)\d{2})\s*[–\-—]|to\s+((?:19|20)\d{2}|[Pp]resent)"#
        let fullYearPattern = #"((?:19|20)\d{2})\s*(?:[–\-—]|to)\s*((?:19|20)\d{2}|[Pp]resent)"#
        if let match = cleaned.range(of: fullYearPattern, options: .regularExpression) {
            let matched = String(cleaned[match])
            if let result = tryParse(matched, separator: "–") { return result }
            if let result = tryParse(matched, separator: "-") { return result }
        }

        return nil
    }

    private static func stripLocationSuffix(_ line: String) -> String {
        // "May 2025 – Present | Singapore (Remote)" → "May 2025 – Present"
        guard let pipeRange = line.range(of: " | ") else { return line }
        // Only strip if the part before | contains a separator (it's a date range, not "Company | Title")
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

    static func parseDate(_ raw: String) -> Date? {
        let cleaned = raw.trimmingCharacters(in: .whitespaces)
        // Reject clearly non-date strings quickly
        guard !cleaned.isEmpty,
              cleaned.filter(\.isNumber).count >= 2 else { return nil }

        let formats = ["MMMM yyyy", "MMM yyyy", "yyyy", "MM/yyyy", "MMMM d, yyyy", "MMM d, yyyy"]
        for fmt in formats {
            let f = DateFormatter()
            f.dateFormat = fmt
            f.locale = Locale(identifier: "en_US_POSIX")
            if let date = f.date(from: cleaned) { return date }
        }
        return nil
    }
}

