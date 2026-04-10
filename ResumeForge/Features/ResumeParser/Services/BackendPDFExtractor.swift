import Foundation

// MARK: - Errors

enum BackendPDFExtractionError: Error, LocalizedError {
    case backendUnreachable
    case extractionFailed(String)

    var errorDescription: String? {
        switch self {
        case .backendUnreachable:
            return BackendError.unreachable.errorDescription
        case .extractionFailed(let detail):
            return "PDF extraction failed: \(detail)"
        }
    }
}

// MARK: - Extractor

/// Sends PDF data to the local Python backend for text extraction.
///
/// This replaces the previous PythonKit/docling approach with a simple
/// HTTP call to `http://127.0.0.1:8765/parse-pdf`, making the app's
/// PDF parsing fast and reliable without requiring PythonKit.
enum BackendPDFExtractor {
    static func extract(from data: Data) async throws -> String {
        do {
            return try await BackendService.parsePDF(data: data)
        } catch let error as BackendError {
            switch error {
            case .unreachable:
                throw BackendPDFExtractionError.backendUnreachable
            default:
                throw BackendPDFExtractionError.extractionFailed(
                    error.errorDescription ?? error.localizedDescription
                )
            }
        }
    }
}
