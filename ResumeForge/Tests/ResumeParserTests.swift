import Testing
import Foundation
@testable import ResumeForge

// MARK: - 1. LaTeX command stripping

@Suite("LaTeXTextExtractor")
struct LaTeXTextExtractorTests {
    @Test("strips \\textbf and \\textit")
    func stripsBasicFormatting() throws {
        let latex = #"\textbf{John Doe} — \textit{Software Engineer}"#
        let result = try LaTeXTextExtractor.extract(from: Data(latex.utf8))
        #expect(result.contains("John Doe"))
        #expect(result.contains("Software Engineer"))
        #expect(!result.contains("\\textbf"))
        #expect(!result.contains("\\textit"))
    }

    @Test("converts \\section{} to ## heading")
    func convertsSectionToHeading() throws {
        let latex = #"\section{Experience}\nSome content here"#
        let result = try LaTeXTextExtractor.extract(from: Data(latex.utf8))
        #expect(result.contains("## Experience"))
    }

    @Test("strips \\href{url}{text} keeping text")
    func stripsHrefKeepsText() throws {
        let latex = #"\href{https://linkedin.com/in/johndoe}{John Doe on LinkedIn}"#
        let result = try LaTeXTextExtractor.extract(from: Data(latex.utf8))
        #expect(result.contains("John Doe on LinkedIn"))
        #expect(!result.contains("\\href"))
        #expect(!result.contains("https://linkedin.com"))
    }

    @Test("converts \\item bullets to • prefix")
    func convertsItemsToBullets() throws {
        let latex = "\\begin{itemize}\n\\item First bullet\n\\item Second bullet\n\\end{itemize}"
        let result = try LaTeXTextExtractor.extract(from: Data(latex.utf8))
        #expect(result.contains("• First bullet"))
        #expect(result.contains("• Second bullet"))
    }

    @Test("removes % comments")
    func removesComments() throws {
        let latex = "John Doe % this is a comment\nEngineer"
        let result = try LaTeXTextExtractor.extract(from: Data(latex.utf8))
        #expect(result.contains("John Doe"))
        #expect(!result.contains("this is a comment"))
    }

    @Test("throws emptyDocument on empty input")
    func throwsOnEmpty() {
        #expect(throws: LaTeXExtractionError.emptyDocument) {
            try LaTeXTextExtractor.extract(from: Data())
        }
    }
}

// MARK: - 2. Date range parsing

@Suite("DateRangeParser")
struct DateRangeParserTests {
    @Test("parses 'Jan 2020 – Present' as current")
    func parsesMonthYearToPresent() {
        let result = DateRangeParser.parse(from: "Jan 2020 – Present")
        #expect(result != nil)
        #expect(result?.isCurrent == true)
        let calendar = Calendar.current
        #expect(calendar.component(.year, from: result!.start) == 2020)
    }

    @Test("parses 'March 2018 - June 2020' with start and end")
    func parsesFullMonthRange() {
        let result = DateRangeParser.parse(from: "March 2018 - June 2020")
        #expect(result != nil)
        #expect(result?.isCurrent == false)
        #expect(result?.end != nil)
        let calendar = Calendar.current
        #expect(calendar.component(.year, from: result!.start) == 2018)
        #expect(calendar.component(.year, from: result!.end!) == 2020)
    }

    @Test("strips location suffix before parsing end date")
    func stripsLocationFromEndDate() {
        // Regression: "Apr 2025 | Guelph" was failing parseDate
        let result = DateRangeParser.parse(from: "Sep 2023 – Apr 2025 | Guelph")
        #expect(result != nil)
        #expect(result?.isCurrent == false)
        let calendar = Calendar.current
        #expect(calendar.component(.year, from: result!.end!) == 2025)
    }

    @Test("parses date with remote location suffix")
    func parsesDateWithRemoteSuffix() {
        let result = DateRangeParser.parse(from: "May 2025 – Present | Singapore (Remote)")
        #expect(result?.isCurrent == true)
        let calendar = Calendar.current
        #expect(calendar.component(.year, from: result!.start) == 2025)
    }

    @Test("parses '2019–2022' year-only range")
    func parsesYearOnlyRange() {
        let result = DateRangeParser.parse(from: "2019–2022")
        #expect(result != nil)
        #expect(result?.isCurrent == false)
        let calendar = Calendar.current
        #expect(calendar.component(.year, from: result!.start) == 2019)
        #expect(calendar.component(.year, from: result!.end!) == 2022)
    }

    @Test("parses 'Sep 2021 — current' as current")
    func parsesCurrent() {
        let result = DateRangeParser.parse(from: "Sep 2021 — current")
        #expect(result?.isCurrent == true)
    }

    @Test("returns nil for lines with no date")
    func returnsNilForNonDate() {
        #expect(DateRangeParser.parse(from: "Software Engineer at Acme Corp") == nil)
        #expect(DateRangeParser.parse(from: "Bachelor of Science in Computer Science") == nil)
    }
}

// MARK: - 3. Email / phone extraction

@Suite("ResumeContentParser — contact extraction")
struct ResumeContentParserContactTests {
    @Test("extracts plain email address")
    func extractsPlainEmail() {
        let lines = ["John Doe", "john.doe@example.com", "+1 (555) 123-4567"]
        #expect(ResumeContentParser.extractEmail(from: lines) == "john.doe@example.com")
    }

    @Test("extracts email embedded in a longer line")
    func extractsEmbeddedEmail() {
        let lines = ["Contact: jane@company.io | github.com/jane"]
        #expect(ResumeContentParser.extractEmail(from: lines) == "jane@company.io")
    }

    @Test("returns empty string when no email present")
    func returnsEmptyWhenNoEmail() {
        let lines = ["John Doe", "New York, NY", "github.com/johndoe"]
        #expect(ResumeContentParser.extractEmail(from: lines) == "")
    }

    @Test("extracts standard US phone number")
    func extractsPhone() {
        let lines = ["(555) 867-5309"]
        let phone = ResumeContentParser.extractPhone(from: lines)
        #expect(!phone.isEmpty)
        #expect(phone.contains("555"))
    }

    @Test("extracts dotted phone format")
    func extractsDottedPhone() {
        let lines = ["jane.doe@email.com • 555.234.5678 • linkedin.com/in/jane"]
        let phone = ResumeContentParser.extractPhone(from: lines)
        #expect(!phone.isEmpty)
    }

    @Test("returns empty string when no phone present")
    func returnsEmptyWhenNoPhone() {
        let lines = ["John Doe", "john@example.com"]
        #expect(ResumeContentParser.extractPhone(from: lines) == "")
    }
}

// MARK: - 4. Structured result parsing

@Suite("ResumeResultParser")
struct ResumeResultParserTests {
        @Test("parses direct JSON payload to ParsedResumeData")
        func parsesDirectJSON() {
                let payload = #"""
                {
                    "name": "Jane Doe",
                    "email": "jane@acme.io",
                    "summary": "Senior iOS Engineer",
                    "skills": ["Swift", "SwiftUI", "XCTest"],
                    "experiences": [
                        {
                            "company": "Acme",
                            "title": "iOS Engineer",
                            "dateRange": "Jan 2022 - Present",
                            "bulletPoints": ["Built ResumeForge", "Improved parsing quality"]
                        }
                    ]
                }
                """#

                let parsed = ResumeResultParser.parse(payload)
                #expect(parsed.name == "Jane Doe")
                #expect(parsed.email == "jane@acme.io")
                #expect(parsed.skills.contains("SwiftUI"))
                #expect(parsed.experiences.count == 1)
                #expect(parsed.experiences[0].company == "Acme")
                #expect(parsed.experiences[0].isCurrent == true)
        }

        @Test("parses markdown fenced JSON from nested result container")
        func parsesFencedJSONContainer() {
                let payload = #"""
                Here is your structured result:
                ```json
                {
                    "result": {
                        "full_name": "Alex Johnson",
                        "links": {
                            "linkedin": "linkedin.com/in/alexjohnson",
                            "github": "github.com/alexj"
                        },
                        "education": [
                            {
                                "institution": "University of Waterloo",
                                "degree": "Bachelor of Applied Science",
                                "field": "Computer Engineering",
                                "graduationDate": "2024"
                            }
                        ]
                    }
                }
                ```
                """#

                let parsed = ResumeResultParser.parse(payload)
                #expect(parsed.name == "Alex Johnson")
                #expect(parsed.linkedIn.contains("linkedin"))
                #expect(parsed.github.contains("github"))
                #expect(parsed.education.count == 1)
                #expect(parsed.education[0].institution.contains("Waterloo"))
        }

        @Test("falls back to heuristic parser for plain text")
        func fallsBackToPlainText() {
                let text = """
                John Smith
                john.smith@example.com
                +1 (555) 222-3333

                Skills
                Swift, SwiftUI, Python
                """

                let parsed = ResumeResultParser.parse(text)
                #expect(parsed.name == "John Smith")
                #expect(parsed.email == "john.smith@example.com")
                #expect(parsed.skills.contains("Swift"))
        }
}
