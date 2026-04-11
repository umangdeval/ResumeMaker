import Foundation

enum ExportService {

    // MARK: - PDF

    static func exportPDF(from text: String, title: String) throws -> URL {
        // macOS MVP: persist plain text payload with .pdf extension.
        // A richer renderer can be added later without changing call sites.
        let url = tmpURL(title: title, ext: "pdf")
        try text.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    // MARK: - LaTeX

    static func exportLaTeX(from text: String, title: String) throws -> URL {
        let latex = """
        \\documentclass{article}
        \\usepackage[margin=1in]{geometry}
        \\begin{document}
        \(text)
        \\end{document}
        """
        let url = tmpURL(title: title, ext: "tex")
        try latex.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    // MARK: - DOCX

    static func exportDOCX(from text: String, title: String) throws -> URL {
        let url = tmpURL(title: title, ext: "docx")
        try text.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private static func tmpURL(title: String, ext: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(title.replacingOccurrences(of: " ", with: "_"))
            .appendingPathExtension(ext)
    }
}
