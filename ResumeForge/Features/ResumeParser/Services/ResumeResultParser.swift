import Foundation

// MARK: - Structured result parser

/// Converts mixed-format parser results into `ParsedResumeData`.
/// Falls back to the heuristic plain-text parser when content is not structured JSON.
enum ResumeResultParser {
    /// Decodes the strict JSON shape produced by `PromptLibrary.latexExtractionUser`.
    /// Returns an empty `ParsedResumeData` if the JSON is malformed.
    static func parseJSON(_ jsonString: String) -> ParsedResumeData {
        let trimmed = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = trimmed.data(using: .utf8),
              let raw = try? JSONDecoder().decode(LLMResumeJSON.self, from: data) else {
            return ParsedResumeData()
        }

        let experiences: [ParsedExperience] = raw.experiences.map { exp in
            let range = DateRangeParser.parse(from: exp.dateRange)
            let isCurrent = exp.dateRange.lowercased().contains("present")
                || exp.dateRange.lowercased().contains("current")
            return ParsedExperience(
                company: exp.company, title: exp.title,
                startDate: range?.start, endDate: isCurrent ? nil : range?.end,
                isCurrent: isCurrent, bulletPoints: exp.bulletPoints
            )
        }

        let education: [ParsedEducation] = raw.education.map { edu in
            let grad = DateRangeParser.parseDate(edu.graduationDate)
            return ParsedEducation(
                institution: edu.institution, degree: edu.degree,
                field: edu.field, graduationDate: grad, gpa: edu.gpa
            )
        }

        return ParsedResumeData(
            name: raw.name, email: raw.email, phone: raw.phone,
            linkedIn: raw.linkedin, github: raw.github, website: raw.website,
            summary: raw.summary, experiences: experiences,
            education: education, skills: raw.skills
        )
    }

    static func parse(_ raw: String) -> ParsedResumeData {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return ParsedResumeData() }

        if let structured = parseStructured(trimmed) {
            return structured
        }

        return ResumeContentParser.parse(raw)
    }

    private static func parseStructured(_ text: String) -> ParsedResumeData? {
        if let object = extractJSONObject(from: text) {
            return map(rootObject: object)
        }

        if let fenced = extractJSONCodeFence(from: text), let object = extractJSONObject(from: fenced) {
            return map(rootObject: object)
        }

        return nil
    }

    private static func extractJSONCodeFence(from text: String) -> String? {
        guard let regex = try? NSRegularExpression(
            pattern: "```(?:json)?\\s*([\\s\\S]*?)\\s*```",
            options: [.caseInsensitive]
        ) else { return nil }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range), match.numberOfRanges >= 2,
              let fencedRange = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[fencedRange])
    }

    private static func extractJSONObject(from text: String) -> [String: Any]? {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) else { return nil }

        if let dict = json as? [String: Any] {
            return unwrapContainer(dict)
        }

        if let array = json as? [[String: Any]], let first = array.first {
            return unwrapContainer(first)
        }

        return nil
    }

    private static func unwrapContainer(_ source: [String: Any]) -> [String: Any] {
        let wrapperKeys = ["result", "data", "resume", "parsed", "parsedResume", "parsed_resume", "payload", "profile", "candidate"]
        var current = source

        for _ in 0..<4 {
            var moved = false
            for key in wrapperKeys {
                guard let nested = current[key] as? [String: Any] else { continue }
                current = nested
                moved = true
                break
            }
            if !moved { break }
        }

        return current
    }

    private static func map(rootObject root: [String: Any]) -> ParsedResumeData {
        var parsed = ParsedResumeData()

        parsed.name = string(from: root, keys: ["name", "fullName", "full_name", "candidateName", "candidate_name"])
        parsed.email = string(from: root, keys: ["email", "mail"])
        parsed.phone = string(from: root, keys: ["phone", "phoneNumber", "phone_number", "mobile"])
        parsed.summary = string(from: root, keys: ["summary", "objective", "profileSummary", "profile_summary"])

        if let links = dictionary(from: root, keys: ["links", "social", "socialLinks", "social_links"]) {
            parsed.linkedIn = string(from: links, keys: ["linkedin", "linkedIn", "linkedinUrl", "linkedin_url"])
            parsed.github = string(from: links, keys: ["github", "githubUrl", "github_url"])
            parsed.website = string(from: links, keys: ["website", "portfolio", "url", "personalWebsite", "personal_website"])
        }

        if parsed.linkedIn.isEmpty {
            parsed.linkedIn = string(from: root, keys: ["linkedin", "linkedIn", "linkedinUrl", "linkedin_url"])
        }
        if parsed.github.isEmpty {
            parsed.github = string(from: root, keys: ["github", "githubUrl", "github_url"])
        }
        if parsed.website.isEmpty {
            parsed.website = string(from: root, keys: ["website", "portfolio", "url", "personalWebsite", "personal_website"])
        }

        parsed.skills = normalizeSkills(root)
        parsed.experiences = normalizeExperiences(root)
        parsed.education = normalizeEducation(root)
        parsed.projects = normalizeProjects(root)
        parsed.detectedSections = normalizeSections(root)

        return parsed
    }

    private static func normalizeSections(_ root: [String: Any]) -> [String] {
        if let values = arrayOfStrings(from: root, keys: ["detectedSections", "detected_sections", "sections"]) {
            return values
        }

        var sections: [String] = []
        if !normalizeExperiences(root).isEmpty { sections.append("Experience") }
        if !normalizeEducation(root).isEmpty { sections.append("Education") }
        if !normalizeProjects(root).isEmpty { sections.append("Projects") }
        if !normalizeSkills(root).isEmpty { sections.append("Skills") }
        if !string(from: root, keys: ["summary", "objective", "profileSummary", "profile_summary"]).isEmpty {
            sections.append("Summary")
        }
        return sections
    }

    private static func normalizeSkills(_ root: [String: Any]) -> [String] {
        if let values = arrayOfStrings(from: root, keys: ["skills", "skillSet", "skill_set", "technologies"]) {
            return values
        }

        let skillText = string(from: root, keys: ["skills", "skillSet", "skill_set", "technologies"])
        if !skillText.isEmpty {
            return skillText
                .components(separatedBy: CharacterSet(charactersIn: ",;\n"))
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }

        return []
    }

    private static func normalizeExperiences(_ root: [String: Any]) -> [ParsedExperience] {
        let keys = ["experiences", "experience", "workExperience", "work_experience", "employment", "workHistory", "work_history"]
        guard let items = arrayOfDictionaries(from: root, keys: keys) else { return [] }

        return items.map { item in
            let range = dateRange(from: item)
            let rangeText = string(from: item, keys: ["dateRange", "date_range", "duration"]).lowercased()
            let endRaw = string(from: item, keys: ["end", "endDate", "end_date", "to"])
            let isCurrent = bool(from: item, keys: ["isCurrent", "is_current", "current"])
                || endRaw.lowercased().contains("present")
                || endRaw.lowercased().contains("current")
                || rangeText.contains("present")
                || rangeText.contains("current")
                || rangeText.contains("now")

            return ParsedExperience(
                company: string(from: item, keys: ["company", "organization", "employer"]),
                title: string(from: item, keys: ["title", "position", "role", "jobTitle", "job_title"]),
                startDate: range.start,
                endDate: isCurrent ? nil : range.end,
                isCurrent: isCurrent,
                bulletPoints: bullets(from: item)
            )
        }
    }

    private static func normalizeEducation(_ root: [String: Any]) -> [ParsedEducation] {
        let keys = ["education", "educations", "academic", "academicHistory", "academic_history"]
        guard let items = arrayOfDictionaries(from: root, keys: keys) else { return [] }

        return items.map { item in
            let grad = date(from: item, keys: ["graduationDate", "graduation_date", "graduated", "endDate", "end_date", "year"])
            return ParsedEducation(
                institution: string(from: item, keys: ["institution", "school", "college", "university"]),
                degree: string(from: item, keys: ["degree", "qualification"]),
                field: string(from: item, keys: ["field", "major", "program", "specialization"]),
                graduationDate: grad,
                gpa: string(from: item, keys: ["gpa", "grade"])
            )
        }
    }

    private static func normalizeProjects(_ root: [String: Any]) -> [ParsedProject] {
        let keys = ["projects", "project", "portfolioProjects", "portfolio_projects"]
        guard let items = arrayOfDictionaries(from: root, keys: keys) else { return [] }

        return items.map { item in
            ParsedProject(
                name: string(from: item, keys: ["name", "title", "projectName", "project_name"]),
                year: string(from: item, keys: ["year", "date"]),
                bulletPoints: bullets(from: item)
            )
        }
    }

    private static func bullets(from object: [String: Any]) -> [String] {
        if let values = arrayOfStrings(from: object, keys: ["bulletPoints", "bullet_points", "bullets", "highlights", "achievements", "responsibilities", "points"]) {
            return values
        }

        let text = string(from: object, keys: ["description", "summary", "details", "bulletPoints", "bullet_points"])
        guard !text.isEmpty else { return [] }

        return text
            .components(separatedBy: CharacterSet.newlines)
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: " -•\t")) }
            .filter { !$0.isEmpty }
    }

    private static func dateRange(from object: [String: Any]) -> (start: Date?, end: Date?) {
        let rangeText = string(from: object, keys: ["dateRange", "date_range", "duration"])
        if !rangeText.isEmpty, let range = DateRangeParser.parse(from: rangeText) {
            return (range.start, range.end)
        }

        return (
            date(from: object, keys: ["start", "startDate", "start_date", "from"]),
            date(from: object, keys: ["end", "endDate", "end_date", "to"])
        )
    }

    private static func date(from object: [String: Any], keys: [String]) -> Date? {
        for key in keys {
            guard let value = object[key] else { continue }

            if let number = value as? TimeInterval {
                let unix = number > 10_000_000_000 ? number / 1000 : number
                return Date(timeIntervalSince1970: unix)
            }

            if let text = value as? String {
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { continue }
                if let parsed = DateRangeParser.parseDate(trimmed) { return parsed }
                if let iso = ISO8601DateFormatter().date(from: trimmed) { return iso }
            }
        }
        return nil
    }

    private static func string(from object: [String: Any], keys: [String]) -> String {
        for key in keys {
            guard let value = object[key] else { continue }
            if let text = value as? String {
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { return trimmed }
            }
        }
        return ""
    }

    private static func bool(from object: [String: Any], keys: [String]) -> Bool {
        for key in keys {
            guard let value = object[key] else { continue }
            if let boolValue = value as? Bool { return boolValue }
            if let text = value as? String {
                let lower = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                if lower == "true" || lower == "yes" || lower == "1" { return true }
                if lower == "false" || lower == "no" || lower == "0" { return false }
            }
        }
        return false
    }

    private static func dictionary(from object: [String: Any], keys: [String]) -> [String: Any]? {
        for key in keys {
            if let dict = object[key] as? [String: Any] { return dict }
        }
        return nil
    }

    private static func arrayOfStrings(from object: [String: Any], keys: [String]) -> [String]? {
        for key in keys {
            guard let values = object[key] as? [Any] else { continue }
            let strings = values
                .compactMap { $0 as? String }
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            if !strings.isEmpty { return strings }
        }
        return nil
    }

    private static func arrayOfDictionaries(from object: [String: Any], keys: [String]) -> [[String: Any]]? {
        for key in keys {
            guard let values = object[key] as? [Any] else { continue }
            let dictionaries = values.compactMap { $0 as? [String: Any] }
            if !dictionaries.isEmpty { return dictionaries }
        }
        return nil
    }
}

// MARK: - LLM JSON shape (used by parseJSON)

private struct LLMResumeJSON: Decodable {
    var name: String = ""
    var email: String = ""
    var phone: String = ""
    var linkedin: String = ""
    var github: String = ""
    var website: String = ""
    var summary: String = ""
    var skills: [String] = []
    var experiences: [LLMExperience] = []
    var education: [LLMEducation] = []

    struct LLMExperience: Decodable {
        var company: String = ""
        var title: String = ""
        var dateRange: String = ""
        var bulletPoints: [String] = []
    }

    struct LLMEducation: Decodable {
        var institution: String = ""
        var degree: String = ""
        var field: String = ""
        var graduationDate: String = ""
        var gpa: String = ""
    }
}
