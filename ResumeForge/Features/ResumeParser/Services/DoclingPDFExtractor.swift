import Foundation
import PythonKit

// MARK: - Errors

enum DoclingExtractionError: Error, LocalizedError {
    case moduleNotAvailable
    case parseFailure(String)
    case emptyResult

    var errorDescription: String? {
        switch self {
        case .moduleNotAvailable:
            return "docling-parse is not available. Check Python environment in Settings."
        case .parseFailure(let msg):
            return "Docling failed to parse the PDF: \(msg)"
        case .emptyResult:
            return "Docling extracted no text from this PDF."
        }
    }
}

// MARK: - Extractor

/// Uses docling-parse (via PythonKit) to extract rich structured text from a PDF.
/// Falls back gracefully — callers should catch and use PDFTextExtractor on failure.
enum DoclingPDFExtractor {
    /// Extracts text from a PDF file at `url`.
    /// Runs on a detached task to keep the Python call off the main thread.
    static func extract(from url: URL) async throws -> String {
        try await Task.detached(priority: .userInitiated) {
            try extractSync(from: url)
        }.value
    }

    // MARK: - Synchronous extraction (runs on worker thread)

    private static func extractSync(from url: URL) throws -> String {
        guard let doclingParse = try? Python.attemptImport("docling_parse") else {
            throw DoclingExtractionError.moduleNotAvailable
        }

        let parser = doclingParse.DoclingParser()
        let result = parser.convert(url.path)

        // docling_parse returns a dict: {"pages": [{"text": "...", "cells": [...]}, ...]}
        guard result != Python.None else {
            throw DoclingExtractionError.parseFailure("Parser returned None")
        }

        let pages = result["pages"]
        guard pages != Python.None else {
            throw DoclingExtractionError.emptyResult
        }

        var textParts: [String] = []
        for page in pages {
            // Prefer structured cell text for accuracy
            let cells = page["cells"]
            if cells != Python.None {
                for cell in cells {
                    let cellText = String(cell["text"]) ?? ""
                    if !cellText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        textParts.append(cellText)
                    }
                }
            } else if let pageText = String(page["text"]), !pageText.isEmpty {
                textParts.append(pageText)
            }
        }

        let fullText = textParts.joined(separator: "\n")
        guard !fullText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DoclingExtractionError.emptyResult
        }
        return fullText
    }
}
