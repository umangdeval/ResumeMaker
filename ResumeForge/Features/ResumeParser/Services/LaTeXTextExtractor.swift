import Foundation

// MARK: - Errors

enum LaTeXExtractionError: Error, LocalizedError {
    case emptyDocument
    case invalidEncoding

    var errorDescription: String? {
        switch self {
        case .emptyDocument:    return "The LaTeX file appears to be empty."
        case .invalidEncoding:  return "The file encoding is not supported. Please save as UTF-8."
        }
    }
}

// MARK: - Extractor

/// Strips LaTeX commands and returns readable text with Markdown-style section markers.
/// Handles moderncv, europasscv, altacv, and Jake's Resume template conventions.
enum LaTeXTextExtractor {
    static func extract(from data: Data) throws -> String {
        guard let source = String(data: data, encoding: .utf8) ??
                           String(data: data, encoding: .isoLatin1) else {
            throw LaTeXExtractionError.invalidEncoding
        }
        guard !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw LaTeXExtractionError.emptyDocument
        }
        return process(source)
    }

    // MARK: - Processing pipeline

    private static func process(_ source: String) -> String {
        var text = source

        // 1. Remove comments
        text = removeComments(text)
        // 2. Extract document body (everything between \begin{document} … \end{document})
        text = extractBody(text)
        // 3. Convert section commands to Markdown headings
        text = convertSections(text)
        // 4. Convert list environments to plain bullets
        text = convertLists(text)
        // 5. Strip remaining environments
        text = stripEnvironments(text)
        // 6. Extract inner content from text-formatting commands
        text = extractCommandContent(text)
        // 7. Remove standalone commands
        text = removeStandaloneCommands(text)
        // 8. Clean up whitespace
        text = normalizeWhitespace(text)

        return text
    }

    // MARK: - Step implementations

    private static func removeComments(_ text: String) -> String {
        // Remove % comments (not preceded by \)
        let lines = text.components(separatedBy: .newlines)
        return lines.map { line -> String in
            var result = ""
            var escaped = false
            for char in line {
                if escaped { result.append(char); escaped = false; continue }
                if char == "\\" { escaped = true; result.append(char); continue }
                if char == "%" { break }
                result.append(char)
            }
            return result
        }.joined(separator: "\n")
    }

    private static func extractBody(_ text: String) -> String {
        if let range = text.range(of: #"\\begin\{document\}([\s\S]*?)\\end\{document\}"#,
                                   options: .regularExpression) {
            let body = String(text[range])
            // Drop the \begin{document} / \end{document} wrappers
            return body
                .replacingOccurrences(of: #"\\begin\{document\}"#, with: "", options: .regularExpression)
                .replacingOccurrences(of: #"\\end\{document\}"#,   with: "", options: .regularExpression)
        }
        return text
    }

    private static func convertSections(_ text: String) -> String {
        var result = text
        let patterns: [(String, String)] = [
            (#"\\section\*?\{([^}]+)\}"#,    "## $1"),
            (#"\\subsection\*?\{([^}]+)\}"#, "### $1"),
            (#"\\cventry\{[^}]*\}\{([^}]+)\}\{([^}]+)\}"#, "$1 at $2"),
            // moderncv: \cvitem{label}{content}
            (#"\\cvitem\{([^}]*)\}\{([^}]+)\}"#, "$1: $2"),
            // altacv: \cvsection{name}
            (#"\\cvsection\{([^}]+)\}"#, "## $1"),
            // Jake's: \resumeSubheading{title}{date}{company}{location}
            (#"\\resumeSubheading\{([^}]+)\}\{([^}]+)\}\{([^}]+)\}\{([^}]+)\}"#, "$1 | $3 | $2"),
        ]
        for (pattern, replacement) in patterns {
            result = result.replacingOccurrences(of: pattern, with: replacement, options: .regularExpression)
        }
        return result
    }

    private static func convertLists(_ text: String) -> String {
        var result = text
        // \item [optional label] → bullet point
        result = result.replacingOccurrences(
            of: #"\\item(?:\[[^\]]*\])?\s*"#,
            with: "• ",
            options: .regularExpression
        )
        // Strip list environment tags
        let listEnvs = ["itemize", "enumerate", "description", "resumeItemListStart",
                        "resumeItemListEnd", "cvitems"]
        for env in listEnvs {
            result = result.replacingOccurrences(of: #"\\(?:begin|end)\{"# + env + #"\}"#,
                                                  with: "", options: .regularExpression)
        }
        return result
    }

    private static func stripEnvironments(_ text: String) -> String {
        var result = text
        // Remove \begin{…} / \end{…} wrappers (keep content between them)
        result = result.replacingOccurrences(
            of: #"\\(?:begin|end)\{[^}]+\}"#, with: "", options: .regularExpression)
        return result
    }

    private static func extractCommandContent(_ text: String) -> String {
        var result = text
        // Commands where we keep only the last brace group: \textbf{X} → X
        let keepContent = ["textbf", "textit", "emph", "textrm", "texttt", "textsc",
                           "underline", "large", "Large", "LARGE", "huge", "Huge",
                           "small", "footnotesize", "normalsize",
                           "color", "textcolor"]  // \textcolor{color}{text} handled below
        for cmd in keepContent {
            result = result.replacingOccurrences(
                of: #"\\"# + cmd + #"\{([^}]*)\}"#,
                with: "$1",
                options: .regularExpression
            )
        }
        // \textcolor{color}{text} → text  (two-arg)
        result = result.replacingOccurrences(
            of: #"\\textcolor\{[^}]*\}\{([^}]*)\}"#,
            with: "$1", options: .regularExpression)
        // \href{url}{text} → text
        result = result.replacingOccurrences(
            of: #"\\href\{[^}]*\}\{([^}]*)\}"#,
            with: "$1", options: .regularExpression)
        // \url{url} → url
        result = result.replacingOccurrences(
            of: #"\\url\{([^}]*)\}"#,
            with: "$1", options: .regularExpression)
        // \newcommand definitions — drop entirely
        result = result.replacingOccurrences(
            of: #"\\(?:newcommand|renewcommand|providecommand)\{[^}]*\}(?:\[[^\]]*\])?\{[^}]*\}"#,
            with: "", options: .regularExpression)
        return result
    }

    private static func removeStandaloneCommands(_ text: String) -> String {
        var result = text
        // Remove known no-content commands
        let noOp = ["noindent", "centering", "raggedright", "raggedleft", "par",
                    "newline", "linebreak", "pagebreak", "newpage",
                    "hline", "hfill", "vfill", "medskip", "bigskip", "smallskip",
                    "resumeItem", "resumeSubItem"]
        for cmd in noOp {
            result = result.replacingOccurrences(
                of: #"\\\#(cmd)(?:\[[^\]]*\])?\b"#,
                with: "", options: .regularExpression)
        }
        // Remove any remaining \command{…} that we haven't handled — drop the command, keep braced content
        result = result.replacingOccurrences(
            of: #"\\[a-zA-Z]+\*?(?:\[[^\]]*\])?\{([^}]*)\}"#,
            with: "$1", options: .regularExpression)
        // Remove bare \command tokens
        result = result.replacingOccurrences(
            of: #"\\[a-zA-Z]+"#, with: "", options: .regularExpression)
        // Remove leftover braces
        result = result.replacingOccurrences(of: "{", with: "")
        result = result.replacingOccurrences(of: "}", with: "")
        return result
    }

    private static func normalizeWhitespace(_ text: String) -> String {
        // Collapse 3+ newlines to 2
        var result = text.replacingOccurrences(
            of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
        // Trim each line
        result = result.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .joined(separator: "\n")
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
