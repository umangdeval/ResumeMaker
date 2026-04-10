import Foundation

// MARK: - Parser

/// Heuristically parses plain text extracted from a PDF or LaTeX file into `ParsedResumeData`.
/// Handles both "inline" format (all fields on one line) and "multi-line" format.
/// Best-effort only — the user reviews and corrects the result.
enum ResumeContentParser {
    static func parse(_ text: String) -> ParsedResumeData {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .filter { !isIconMarker($0) }   // drop PDF icon artifacts: /mobile /envelope etc.

        var data = ParsedResumeData()
        let sections = splitIntoSections(lines)
        data.detectedSections = sections.map(\.name)

        data.name  = extractName(from: lines)

        // Scan first 20 lines — icon markers inflate line count in raw PDF text
        let contactWindow = Array(lines.prefix(20))
        data.email    = extractEmail(from: contactWindow)
        data.phone    = extractPhone(from: contactWindow)
        let links     = extractLinks(from: contactWindow)
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
            } else if lower.contains("project") {
                data.projects = parseProjects(from: section.body)
            } else if lower.contains("skill") || lower.contains("technologies") || lower.contains("competencies") {
                data.skills = parseSkills(from: section.body)
            }
        }

        return data
    }

    // MARK: - Section splitting

    private struct Section { let name: String; let body: [String] }

    private static let sectionKeywords = [
        // Experience
        "experience", "work history", "employment", "positions", "career history",
        "professional experience", "professional background", "work experience",
        "relevant experience", "industry experience",
        // Education
        "education", "academic", "qualifications", "academic background",
        "academic history", "educational background",
        // Skills
        "skills", "technologies", "competencies", "technical skills", "core competencies",
        "key skills", "proficiencies", "expertise", "tools",
        // Summary
        "summary", "objective", "profile", "about", "professional summary",
        "career objective", "personal statement", "overview",
        // Other
        "projects", "project", "achievements", "certifications", "awards",
        "publications", "volunteer", "languages", "interests", "activities",
        "references", "honors", "leadership"
    ]

    /// Icon artifacts from PDF icon fonts appear as "/word" lines (e.g. /mobile /envelope).
    private static func isIconMarker(_ line: String) -> Bool {
        line.hasPrefix("/") && line.dropFirst().allSatisfy(\.isLetter)
    }

    private static func isSectionHeading(_ line: String) -> Bool {
        let lower = line.lowercased()
        if line.hasPrefix("## ") || line.hasPrefix("### ") { return true }

        let allCapsExclusions = ["OOP", "API", "GPA", "UI", "UX", "IT", "QA", "OS", "ML", "AI"]
        if line == line.uppercased() && line.count > 3 && line.count <= 30
            && !allCapsExclusions.contains(line)
            && line.filter(\.isLetter).count >= 3 { return true }

        let wordCount = lower.split(separator: " ").count
        guard line.count < 55, wordCount <= 5 else { return false }
        // Exact match, suffix match ("Work Experience"), prefix match ("Experience Summary"),
        // or any keyword contained in a short line.
        return sectionKeywords.contains {
            lower == $0
                || lower.hasSuffix(" " + $0)
                || lower.hasPrefix($0 + " ")
                || (wordCount <= 3 && lower.contains($0))
        }
    }

    private static func splitIntoSections(_ lines: [String]) -> [Section] {
        var sections: [Section] = []
        var currentName = "Header"
        var currentBody: [String] = []
        for line in lines {
            if isSectionHeading(line) {
                if !currentBody.isEmpty { sections.append(Section(name: currentName, body: currentBody)) }
                currentName = line.replacingOccurrences(of: "^#+\\s*", with: "", options: .regularExpression)
                                  .trimmingCharacters(in: .whitespaces)
                currentBody = []
            } else {
                currentBody.append(line)
            }
        }
        if !currentBody.isEmpty { sections.append(Section(name: currentName, body: currentBody)) }
        return sections
    }

    // MARK: - Contact

    private static func extractName(from lines: [String]) -> String {
        for line in lines.prefix(5) {
            guard !line.contains("@"), !line.contains("http"), !line.contains("linkedin"),
                  !line.contains("github"), !line.contains("|"),
                  line.filter(\.isNumber).count <= 2, line.count > 2, line.count < 60 else { continue }
            let ratio = Double(line.filter { $0.isLetter || $0.isWhitespace }.count) / Double(line.count)
            if ratio > 0.85 { return line }
        }
        return ""
    }

    static func extractEmail(from lines: [String]) -> String {
        let p = #"[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}"#
        return lines.lazy.compactMap { line -> String? in
            guard let m = line.range(of: p, options: .regularExpression) else { return nil }
            return String(line[m])
        }.first ?? ""
    }

    static func extractPhone(from lines: [String]) -> String {
        let p = #"(?:\+?1[\s\-.]?)?\(?\d{3}\)?[\s\-.]?\d{3}[\s\-.]?\d{4}"#
        return lines.lazy.compactMap { line -> String? in
            guard let m = line.range(of: p, options: .regularExpression) else { return nil }
            return String(line[m])
        }.first ?? ""
    }

    private static func isLocationLine(_ line: String) -> Bool {
        guard !line.hasPrefix("•"), !line.hasPrefix("-"),
              DateRangeParser.parse(from: line) == nil else { return false }
        let words = line.split(separator: " ")
        return words.count <= 4 && (line == "Remote" || line.contains(","))
    }

    private static func extractLinks(from lines: [String]) -> [String] {
        let p = #"(?:https?://)?(?:www\.)?(?:[a-zA-Z0-9\-]+\.)+[a-zA-Z]{2,}(?:/[^\s,;|•)(<>\[\]]*)?"#
        var links: [String] = []; var seen = Set<String>()
        for line in lines {
            var s = line[line.startIndex...]
            while let m = s.range(of: p, options: .regularExpression) {
                let url = String(s[m]).trimmingCharacters(in: CharacterSet(charactersIn: ".,"))
                if (url.contains("/") || url.hasPrefix("http") || url.hasPrefix("www")), seen.insert(url).inserted {
                    links.append(url)
                }
                s = s[m.upperBound...]
            }
        }
        return links
    }

    // MARK: - Experience

    /// Delegates to `ExperienceEntryExtractor` which tries five field-mapping strategies
    /// and annotates each entry with a `ParseConfidence` score.
    private static func parseExperiences(from lines: [String]) -> [ParsedExperience] {
        ExperienceEntryExtractor.extract(from: lines).map { entry in
            ParsedExperience(
                company: entry.company,
                title: entry.title,
                startDate: entry.startDate,
                endDate: entry.endDate,
                isCurrent: entry.isCurrent,
                bulletPoints: entry.bulletPoints,
                confidence: entry.confidence
            )
        }
    }

    // MARK: - Education

    /// Handles inline: "Degree Institution City, Province yyyy-Present"
    /// and multi-line format with one field per line.
    private static func parseEducation(from lines: [String]) -> [ParsedEducation] {
        struct EduHeader { let lineIndex: Int; let prefix: String; let range: ParsedDateRange }
        var headers: [EduHeader] = []
        for (i, line) in lines.enumerated() {
            if let (prefix, range) = DateRangeParser.parseSuffix(from: line) {
                headers.append(EduHeader(lineIndex: i, prefix: prefix, range: range))
            } else if let range = DateRangeParser.parse(from: line) {
                headers.append(EduHeader(lineIndex: i, prefix: "", range: range))
            }
        }
        guard !headers.isEmpty else { return [] }

        return headers.enumerated().compactMap { (entryIdx, header) in
            let lowerBound = entryIdx > 0 ? headers[entryIdx - 1].lineIndex + 1 : 0
            let nextStart  = entryIdx + 1 < headers.count ? headers[entryIdx + 1].lineIndex : lines.count
            var edu = ParsedEducation()
            edu.graduationDate = header.range.end ?? header.range.start

            if !header.prefix.isEmpty {
                let (degree, field, institution) = splitEducationHeader(header.prefix)
                edu.degree = degree; edu.field = field; edu.institution = institution
            } else {
                var lookback = header.lineIndex - 1
                while lookback >= lowerBound {
                    let line = lines[lookback]
                    guard !line.hasPrefix("•"), !line.hasPrefix("-"), !isLocationLine(line),
                          !line.lowercased().contains("dean"), !line.lowercased().hasPrefix("minor")
                    else { lookback -= 1; continue }
                    let looksLikeDegree = line.range(of: #"(?i)\b(bachelor|master|diploma|doctor|phd|associate|certificate|computing|engineering|arts|science)"#, options: .regularExpression) != nil
                    let looksLikeInst   = line.range(of: #"(?i)\b(university|college|institute|school|academy)"#, options: .regularExpression) != nil
                    if looksLikeDegree && edu.degree.isEmpty { let (d, f) = splitDegree(line); edu.degree = d; edu.field = f }
                    else if looksLikeInst && edu.institution.isEmpty { edu.institution = line }
                    else if edu.institution.isEmpty && edu.degree.isEmpty { edu.institution = line }
                    lookback -= 1
                }
            }

            for line in lines[(header.lineIndex + 1)..<nextStart] {
                if line.lowercased().contains("gpa"),
                   let m = line.range(of: #"\d\.\d{1,2}"#, options: .regularExpression) {
                    edu.gpa = String(line[m])
                }
            }
            return (edu.institution.isEmpty && edu.degree.isEmpty) ? nil : edu
        }
    }

    /// Parses "Degree Field Institution City, Province" by splitting on institution keyword.
    private static func splitEducationHeader(_ header: String) -> (degree: String, field: String, institution: String) {
        for kw in ["University", "College", "Institute", "School", "Academy", "Polytechnic"] {
            guard let kwRange = header.range(of: "\\b\(kw)", options: [.regularExpression, .caseInsensitive]) else { continue }
            var instStart = kwRange.lowerBound
            // Include preceding proper noun (e.g. "Sheridan" before "College")
            let before = String(header[..<kwRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            let lastWord = before.components(separatedBy: .whitespaces).filter { !$0.isEmpty }.last ?? ""
            if lastWord.first?.isUppercase == true, !lastWord.hasSuffix(","),
               !lastWord.hasSuffix(")"), !lastWord.hasSuffix("."),
               let lwRange = header.range(of: lastWord, options: .backwards) {
                instStart = lwRange.lowerBound
            }
            let degreePart = String(header[..<instStart]).trimmingCharacters(in: .whitespaces)
            let instRaw    = String(header[instStart...]).trimmingCharacters(in: .whitespaces)
            let institution = instRaw.components(separatedBy: " ").reduce(into: [String]()) { acc, word in
                guard acc.isEmpty || !word.hasSuffix(",") else { return }
                if !word.hasSuffix(",") { acc.append(word) }
            }.joined(separator: " ")
            let (degree, field) = splitDegree(degreePart)
            return (degree, field, institution)
        }
        return (header, "", "")
    }

    private static func splitDegree(_ line: String) -> (degree: String, field: String) {
        let trim: (String) -> String = { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        for sep in [" in ", " of Science in ", " of Arts in ", " of Engineering in "] {
            if let r = line.range(of: sep, options: .caseInsensitive) {
                return (trim(String(line[..<r.lowerBound])), trim(String(line[r.upperBound...])))
            }
        }
        if let comma = line.firstIndex(of: ",") {
            let d = trim(String(line[..<comma])); let f = trim(String(line[line.index(after: comma)...]))
            if !d.isEmpty && !f.isEmpty { return (d, f) }
        }
        return (line, "")
    }

    // MARK: - Projects

    private static func parseProjects(from lines: [String]) -> [ParsedProject] {
        var projects: [ParsedProject] = []
        var currentName = ""; var currentYear = ""; var currentBullets: [String] = []

        func flush() {
            guard !currentName.isEmpty else { return }
            projects.append(ParsedProject(name: currentName, year: currentYear, bulletPoints: currentBullets))
        }

        for line in lines {
            if line.hasPrefix("•") || line.hasPrefix("-") {
                let bullet = String(line.dropFirst()).trimmingCharacters(in: .whitespaces)
                if !bullet.isEmpty { currentBullets.append(bullet) }
            } else if line.range(of: #"^\d{4}$"#, options: .regularExpression) != nil {
                currentYear = line  // standalone year on its own line
            } else {
                var name = line; var year = ""
                // "Project Name 2025" — trailing 4-digit year on same line
                if let yr = line.range(of: #"\s(\d{4})\s*$"#, options: .regularExpression) {
                    year = String(line[yr]).trimmingCharacters(in: .whitespaces)
                    name = String(line[..<yr.lowerBound]).trimmingCharacters(in: .whitespaces)
                }
                flush(); currentName = name; currentYear = year; currentBullets = []
            }
        }
        flush()
        return projects
    }

    // MARK: - Skills

    private static func parseSkills(from lines: [String]) -> [String] {
        var skills: [String] = []
        for line in lines {
            // Strip dotted leaders: "Programming Languages. . . . . . ." → "Programming Languages"
            let trimmed = line
                .replacingOccurrences(of: #"[\s.]*\.(\s*\.){2,}[\s.]*"#, with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            let wordCount = trimmed.split(separator: " ").count
            let isSubLabel = !trimmed.contains(",") && !trimmed.hasPrefix("•") && !trimmed.hasPrefix("-")
                && wordCount <= 3 && trimmed.filter(\.isNumber).count == 0 && trimmed.count < 25
            if isSubLabel { continue }

            if trimmed.contains(",") {
                skills.append(contentsOf: trimmed.components(separatedBy: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty })
            } else if trimmed.hasPrefix("•") || trimmed.hasPrefix("-") {
                let s = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
                if !s.isEmpty { skills.append(s) }
            } else {
                skills.append(trimmed)
            }
        }
        return skills
    }
}
