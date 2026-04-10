import Foundation

// MARK: - Errors

/// Kept for backward compatibility. PDF extraction is now handled by BackendPDFExtractor.
enum DoclingExtractionError: Error, LocalizedError {
    case moduleNotAvailable
    case loadFailed
    case emptyResult

    var errorDescription: String? {
        switch self {
        case .moduleNotAvailable: return "Docling is not available. The backend server handles PDF extraction."
        case .loadFailed:         return "PDF conversion failed."
        case .emptyResult:        return "No text was extracted from this PDF."
        }
    }
}

// MARK: - Extractor (stub)

/// Legacy stub. PDF extraction is now handled via the HTTP backend (BackendPDFExtractor).
/// This type is retained so existing call-sites continue to compile during transition.
enum DoclingPDFExtractor {
    static func extract(from url: URL) async throws -> String {
        throw DoclingExtractionError.moduleNotAvailable
    }
}

