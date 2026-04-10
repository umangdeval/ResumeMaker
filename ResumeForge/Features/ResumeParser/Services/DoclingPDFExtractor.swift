import Foundation
import PythonKit

// MARK: - Errors

enum DoclingExtractionError: Error, LocalizedError {
    case moduleNotAvailable
    case loadFailed
    case emptyResult

    var errorDescription: String? {
        switch self {
        case .moduleNotAvailable: return "docling is not available. Check Python environment in Settings."
        case .loadFailed:         return "docling could not convert this PDF."
        case .emptyResult:        return "docling extracted no text from this PDF."
        }
    }
}

// MARK: - Extractor

/// Uses docling (via PythonKit) for ML-powered, layout-aware PDF conversion.
/// All complex Python setup is delegated to docling_helper.py sitting next to this file.
enum DoclingPDFExtractor {

    static func extract(from url: URL) async throws -> String {
        try await Task.detached(priority: .userInitiated) {
            try extractSync(from: url)
        }.value
    }

    // MARK: - Synchronous extraction (runs on worker thread)

    private static func extractSync(from url: URL) throws -> String {
        print("[Docling] 🐍 Worker thread started for: \(url.lastPathComponent)")

        guard let sys = try? Python.attemptImport("sys") else {
            print("[Docling] ❌ Could not import sys")
            throw DoclingExtractionError.moduleNotAvailable
        }

        // Inject venv site-packages
        print("[Docling] 🔍 Injecting venv paths…")
        PythonEnvironmentService.injectVenvSitePaths(into: sys)
        print("[Docling] ✅ sys.path injected")

        // Add the Services/ directory to sys.path so docling_helper.py can be imported
        let helperDir = URL(fileURLWithPath: #file).deletingLastPathComponent().path
        if (Array(sys.path) ?? []).compactMap({ String($0) }).contains(helperDir) == false {
            sys.path.insert(0, PythonObject(helperDir))
        }
        print("[Docling] 🔍 Helper dir on path: \(helperDir)")

        // Import the thin helper — all complex Python lives there
        print("[Docling] 🔍 Importing docling_helper…")
        guard let helper = try? Python.attemptImport("docling_helper") else {
            print("[Docling] ❌ docling_helper not importable (docling may not be installed)")
            throw DoclingExtractionError.moduleNotAvailable
        }
        print("[Docling] ✅ Helper imported")

        // Resolve local models path (project root / Models/)
        let modelsPath = URL(fileURLWithPath: #file)
            .deletingLastPathComponent() // Services/
            .deletingLastPathComponent() // ResumeParser/
            .deletingLastPathComponent() // Features/
            .deletingLastPathComponent() // ResumeForge/
            .deletingLastPathComponent() // project root
            .appendingPathComponent("Models")
            .path
        print("[Docling] 🔍 Models path: \(modelsPath)")

        // Create converter via helper (avoids Python enum/dict construction in Swift)
        print("[Docling] 🔍 Creating converter…")
        let converter = helper.create_converter(modelsPath)
        print("[Docling] ✅ Converter ready")

        // Convert PDF → Markdown
        print("[Docling] 🔍 Converting document…")
        guard let markdown = String(helper.convert_to_markdown(converter, url.path)),
              !markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("[Docling] ❌ Conversion returned empty")
            throw DoclingExtractionError.emptyResult
        }

        let lineCount = markdown.components(separatedBy: .newlines).count
        print("[Docling] ✅ Done — \(lineCount) lines, \(markdown.count) chars")
        return markdown
    }
}
