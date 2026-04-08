import PDFKit
import Foundation

// MARK: - Errors

enum PDFExtractionError: Error, LocalizedError {
    case invalidData
    case passwordProtected
    case noTextContent

    var errorDescription: String? {
        switch self {
        case .invalidData:       return "The file does not appear to be a valid PDF."
        case .passwordProtected: return "This PDF is password-protected. Please provide an unlocked copy."
        case .noTextContent:     return "No readable text was found in this PDF. It may be a scanned image."
        }
    }
}

// MARK: - Extractor

enum PDFTextExtractor {
    /// Extracts all readable text from `data`, preserving paragraph breaks between pages.
    static func extract(from data: Data) throws -> String {
        guard let document = PDFDocument(data: data) else {
            throw PDFExtractionError.invalidData
        }
        guard !document.isLocked else {
            throw PDFExtractionError.passwordProtected
        }
        guard document.pageCount > 0 else {
            throw PDFExtractionError.noTextContent
        }

        var pages: [String] = []
        for index in 0..<document.pageCount {
            guard let page = document.page(at: index),
                  let text = page.string, !text.isEmpty else { continue }
            pages.append(text)
        }

        let fullText = pages.joined(separator: "\n\n")
        guard !fullText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PDFExtractionError.noTextContent
        }
        return fullText
    }
}
