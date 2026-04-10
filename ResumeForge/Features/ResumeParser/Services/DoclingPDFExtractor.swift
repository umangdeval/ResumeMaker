import Foundation

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

/// Uses a local Python backend process (docling-parse) to extract rich structured text from a PDF.
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
        do {
            return try DoclingBackendService.extractText(from: url)
        } catch let error as DoclingBackendServiceError {
            switch error {
            case .pythonNotFound, .backendScriptNotFound:
                throw DoclingExtractionError.moduleNotAvailable
            case .backendError(let message):
                if message.localizedCaseInsensitiveContains("no text") {
                    throw DoclingExtractionError.emptyResult
                }
                throw DoclingExtractionError.parseFailure(message)
            case .launchFailed(let details):
                throw DoclingExtractionError.parseFailure(details)
            case .timedOut:
                throw DoclingExtractionError.parseFailure("Timed out while parsing PDF")
            case .invalidResponse:
                throw DoclingExtractionError.parseFailure("Invalid backend response")
            }
        }
    }
}
