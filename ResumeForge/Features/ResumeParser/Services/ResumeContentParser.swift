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

        // Name: first non-empty, non-contact line that looks like a name
        data.name = extractName(from: lines)

        // Contact block: scan first 10 lines
        let contactWindow = Array(lines.prefix(10))
        data.email = extractEmail(from: contactWindow)
        data.phone = extractPhone(from: contactWindow)
        let links = extractLinks(from: contactWindow)
        data.linkedIn = links.first { $0.contains("linkedin") } ?? ""
        data.github   = links.first { $0.contains("github") }   ?? ""
        data.website  = links.first { !$0.contains("linkedin") && !$0.contains("github") } ?? ""

        // Per-section extraction
        for section in sections {
            let lower = section.name.lowercased()
            if lower.contains("summary") || lower.contains("objective") || lower.contains("profile") {
                data.summary = section.body.joined(separator: " ")
            } else if lower.contains("experience") || lower.contains("work") || lower.contains("employment") {
                data.experiences = parseExperiences(from: section.body)
            } else if lower.contains("education") || lower.contains("academic") {
                data.education = parseEducation(from: section.body)
            } else if lower.contains("skill") || lower.contains("technologies") || lower.contains("tools") {
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

    private static let sectionKeywords = [
        "experience", "work history", "employment", "positions",
        "education", "academic", "qualifications",
        "skills", "technologies", "tools", "competencies",
        "summary", "objective", "profile", "about",
        "projects", "achievements", "certifications", "awards",
        "publications", "volunteer", "languages"
    ]

    private static func isSectionHeading(_ line: String) -> Bool {
        let lower = line.lowercased()
        // Markdown-style from LaTeX extractor
        if line.hasPrefix("## ") || line.hasPrefix("### ") { return true }
        // All-caps short line (≤ 30 chars)
        if line == line.uppercased() && line.count <= 30 && line.count > 2 { return true }
        // Line matches known keyword
        return sectionKeywords.contains { lower.contains($0) } && line.count < 40
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
        // Skip lines that look like contact info; take the first "word-like" line
        for line in lines.prefix(5) {
            let hasAt = line.contains("@")
            let hasDigits = line.filter(\.isNumber).count > 4
            let hasURL = line.contains("http") || line.contains("www") || line.contains("linkedin")
            if !hasAt && !hasDigits && !hasURL && line.count > 2 && line.count < 60 {
                return line
            }
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
        // Matches common phone formats: +1 (555) 555-5555, 555.555.5555, etc.
        let pattern = #"(?:\+?1[\s\-.]?)?\(?\d{3}\)?[\s\-.]?\d{3}[\s\-.]?\d{4}"#
        for line in lines {
            if let match = line.range(of: pattern, options: .regularExpression) {
                return String(line[match])
            }
        }
        return ""
    }

    private static func extractLinks(from lines: [String]) -> [String] {
        let pattern = #"(?:https?://|www\.)[^\s,;|•]+"#
        var links: [String] = []
        for line in lines {
            var search = line[line.startIndex...]
            while let match = search.range(of: pattern, options: .regularExpression) {
                links.append(String(search[match]))
                search = search[match.upperBound...]
            }
        }
        return links
    }

    // MARK: - Experience parsing

    private static func parseExperiences(from lines: [String]) -> [ParsedExperience] {
        var result: [ParsedExperience] = []
        var current: ParsedExperience?
        var bullets: [String] = []

        func flush() {
            guard var exp = current else { return }
            exp.bulletPoints = bullets
            result.append(exp)
            current = nil
            bullets = []
        }

        for line in lines {
            if let dateRange = DateRangeParser.parse(from: line) {
                flush()
                current = ParsedExperience(
                    startDate: dateRange.start,
                    endDate: dateRange.end,
                    isCurrent: dateRange.isCurrent
                )
            } else if line.hasPrefix("•") || line.hasPrefix("-") {
                let bullet = String(line.dropFirst()).trimmingCharacters(in: .whitespaces)
                if !bullet.isEmpty { bullets.append(bullet) }
            } else if current != nil {
                // First non-bullet line after date → try to extract title/company
                if current?.title.isEmpty == true {
                    current?.title = line
                } else if current?.company.isEmpty == true {
                    current?.company = line
                }
            }
        }
        flush()
        return result
    }

    // MARK: - Education parsing

    private static func parseEducation(from lines: [String]) -> [ParsedEducation] {
        var result: [ParsedEducation] = []
        var current = ParsedEducation()
        var lineIndex = 0

        for line in lines {
            if let dateRange = DateRangeParser.parse(from: line) {
                current.graduationDate = dateRange.end ?? dateRange.start
                lineIndex = 0
            } else {
                switch lineIndex {
                case 0: current.institution = line
                case 1:
                    // Try to split "Bachelor of Science in Computer Science"
                    let (deg, field) = splitDegree(line)
                    current.degree = deg
                    current.field = field
                default:
                    if line.lowercased().contains("gpa") {
                        current.gpa = line
                    }
                }
                lineIndex += 1
            }
        }
        if !current.institution.isEmpty { result.append(current) }
        return result
    }

    private static func splitDegree(_ line: String) -> (degree: String, field: String) {
        let separators = [" in ", " of Science in ", " of Arts in ", " of Engineering in "]
        for sep in separators {
            if let range = line.range(of: sep, options: .caseInsensitive) {
                let degree = String(line[..<range.lowerBound])
                let field = String(line[range.upperBound...])
                return (degree.trimmed, field.trimmed)
            }
        }
        return (line, "")
    }

    // MARK: - Skills parsing

    private static func parseSkills(from lines: [String]) -> [String] {
        var skills: [String] = []
        for line in lines {
            // Comma-separated
            let parts = line.components(separatedBy: ",")
            if parts.count > 1 {
                skills.append(contentsOf: parts.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty })
            } else if line.hasPrefix("•") || line.hasPrefix("-") {
                let skill = String(line.dropFirst()).trimmingCharacters(in: .whitespaces)
                if !skill.isEmpty { skills.append(skill) }
            } else if !line.isEmpty {
                skills.append(line)
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
        let separators = ["–", "-", "to", "—"]
        for sep in separators {
            let parts = line.components(separatedBy: sep).map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count == 2 else { continue }
            guard let start = parseDate(parts[0]) else { continue }
            let endStr = parts[1].lowercased()
            if endStr.contains("present") || endStr.contains("current") || endStr.contains("now") {
                return ParsedDateRange(start: start, end: nil, isCurrent: true)
            }
            if let end = parseDate(parts[1]) {
                return ParsedDateRange(start: start, end: end, isCurrent: false)
            }
        }
        // Year-only range: "2019 – 2022" or "2019-2022"
        let yearPattern = #"((?:19|20)\d{2})\s*[–\-—to]+\s*((?:19|20)\d{2}|[Pp]resent)"#
        if let match = line.range(of: yearPattern, options: .regularExpression) {
            let matched = String(line[match])
            return parse(from: matched)
        }
        return nil
    }

    static func parseDate(_ raw: String) -> Date? {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        let formatters: [DateFormatter] = {
            let monthYear   = DateFormatter(); monthYear.dateFormat   = "MMMM yyyy"
            let abbrvYear   = DateFormatter(); abbrvYear.dateFormat   = "MMM yyyy"
            let yearOnly    = DateFormatter(); yearOnly.dateFormat    = "yyyy"
            let monthDotYear = DateFormatter(); monthDotYear.dateFormat = "MM/yyyy"
            return [monthYear, abbrvYear, yearOnly, monthDotYear]
        }()
        for fmt in formatters {
            if let date = fmt.date(from: trimmed) { return date }
        }
        return nil
    }
}

