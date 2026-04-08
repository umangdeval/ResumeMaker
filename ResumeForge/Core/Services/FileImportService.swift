import SwiftUI
import UniformTypeIdentifiers

// MARK: - File type enum

enum ResumeFileType: Sendable {
    case pdf
    case latex

    static let supportedUTTypes: [UTType] = [.pdf, .init(filenameExtension: "tex") ?? .plainText]
}

// MARK: - Import result

struct ImportedFile: Sendable {
    let data: Data
    let fileType: ResumeFileType
    let fileName: String
}

// MARK: - Errors

enum FileImportError: Error, LocalizedError {
    case accessDenied
    case unreadable(URL)
    case unsupportedType(String)

    var errorDescription: String? {
        switch self {
        case .accessDenied:           return "Access to the file was denied."
        case .unreadable(let url):    return "Could not read file: \(url.lastPathComponent)"
        case .unsupportedType(let e): return "Unsupported file type: .\(e)"
        }
    }
}

// MARK: - Service

/// Wraps SwiftUI's `fileImporter` interaction and handles security-scoped resource access.
/// Usage: attach `.fileImporter(…)` to a view, pass the result URL here to load data.
enum FileImportService {
    static func load(from url: URL) throws -> ImportedFile {
        // Gain access to security-scoped resource (required for files picked via file importer).
        let accessGranted = url.startAccessingSecurityScopedResource()
        defer {
            if accessGranted { url.stopAccessingSecurityScopedResource() }
        }

        guard let data = try? Data(contentsOf: url) else {
            throw FileImportError.unreadable(url)
        }

        let ext = url.pathExtension.lowercased()
        let fileType: ResumeFileType
        switch ext {
        case "pdf":  fileType = .pdf
        case "tex":  fileType = .latex
        default:     throw FileImportError.unsupportedType(ext)
        }

        return ImportedFile(data: data, fileType: fileType, fileName: url.lastPathComponent)
    }
}
