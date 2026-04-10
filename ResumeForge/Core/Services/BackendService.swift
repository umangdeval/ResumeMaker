import Foundation

// MARK: - Status

enum BackendStatus: Sendable, Equatable {
    case connected(parsers: [String])
    case unreachable
    case degraded(message: String)
}

// MARK: - Errors

enum BackendError: Error, LocalizedError {
    case unreachable
    case httpError(statusCode: Int, detail: String)
    case decodingFailed
    case emptyResult

    var errorDescription: String? {
        switch self {
        case .unreachable:
            return "The ResumeForge backend is not running. Start it with: cd backend && python app.py"
        case .httpError(let code, let detail):
            return "Backend error \(code): \(detail)"
        case .decodingFailed:
            return "Unexpected response from the backend."
        case .emptyResult:
            return "The backend returned no text for this file."
        }
    }
}

// MARK: - Response models

struct HealthResponse: Decodable {
    let status: String
    let parsers: [String]
    let message: String?
}

struct ParseResponse: Decodable {
    let text: String
    let parser: String
    let charCount: Int

    enum CodingKeys: String, CodingKey {
        case text, parser
        case charCount = "char_count"
    }
}

struct ParseLatexResponse: Decodable {
    let text: String
    let charCount: Int

    enum CodingKeys: String, CodingKey {
        case text
        case charCount = "char_count"
    }
}

struct BackendErrorResponse: Decodable {
    let detail: String
}

// MARK: - Service

/// Manages HTTP communication with the local ResumeForge Python backend.
///
/// The backend runs at `http://127.0.0.1:8765` by default. Users can
/// change the URL in Settings if they run it on a different port.
enum BackendService {
    static var baseURL: URL {
        let stored = UserDefaults.standard.string(forKey: "backendURL") ?? ""
        return URL(string: stored.isEmpty ? "http://127.0.0.1:8765" : stored)
            ?? URL(string: "http://127.0.0.1:8765")! // swiftlint:disable:this force_unwrapping
    }

    // MARK: - Health check

    static func checkHealth() async -> BackendStatus {
        let url = baseURL.appendingPathComponent("health")
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse else {
                return .unreachable
            }
            let decoded = try JSONDecoder().decode(HealthResponse.self, from: data)
            if http.statusCode == 503 {
                return .degraded(message: decoded.message ?? "No parsers available.")
            }
            return .connected(parsers: decoded.parsers)
        } catch {
            return .unreachable
        }
    }

    // MARK: - PDF parsing

    static func parsePDF(data: Data, preferDocling: Bool = true) async throws -> String {
        let url = baseURL.appendingPathComponent("parse-pdf")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = multipartBody(
            pdfData: data,
            preferDocling: preferDocling,
            boundary: boundary
        )

        return try await performParseRequest(request)
    }

    // MARK: - LaTeX parsing

    static func parseLaTeX(source: String) async throws -> String {
        let url = baseURL.appendingPathComponent("parse-latex")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = latexMultipartBody(source: source, boundary: boundary)

        let (data, response) = try await performRequest(request)
        guard let http = response as? HTTPURLResponse else {
            throw BackendError.unreachable
        }
        if http.statusCode != 200 {
            let detail = (try? JSONDecoder().decode(BackendErrorResponse.self, from: data))?.detail ?? ""
            throw BackendError.httpError(statusCode: http.statusCode, detail: detail)
        }
        guard let decoded = try? JSONDecoder().decode(ParseLatexResponse.self, from: data) else {
            throw BackendError.decodingFailed
        }
        guard !decoded.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw BackendError.emptyResult
        }
        return decoded.text
    }

    // MARK: - Private helpers

    private static func performParseRequest(_ request: URLRequest) async throws -> String {
        let (data, response) = try await performRequest(request)
        guard let http = response as? HTTPURLResponse else {
            throw BackendError.unreachable
        }
        if http.statusCode != 200 {
            let detail = (try? JSONDecoder().decode(BackendErrorResponse.self, from: data))?.detail ?? ""
            throw BackendError.httpError(statusCode: http.statusCode, detail: detail)
        }
        guard let decoded = try? JSONDecoder().decode(ParseResponse.self, from: data) else {
            throw BackendError.decodingFailed
        }
        guard !decoded.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw BackendError.emptyResult
        }
        return decoded.text
    }

    private static func performRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await URLSession.shared.data(for: request)
        } catch is URLError {
            // Any network-level error means the backend is unreachable.
            throw BackendError.unreachable
        }
    }

    // MARK: - Multipart helpers

    private static func multipartBody(
        pdfData: Data,
        preferDocling: Bool,
        boundary: String
    ) -> Data {
        var body = Data()
        let crlf = "\r\n"

        // File field
        body.append("--\(boundary)\(crlf)".utf8Data)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"resume.pdf\"\(crlf)".utf8Data)
        body.append("Content-Type: application/pdf\(crlf)\(crlf)".utf8Data)
        body.append(pdfData)
        body.append(crlf.utf8Data)

        // prefer_docling field
        body.append("--\(boundary)\(crlf)".utf8Data)
        body.append("Content-Disposition: form-data; name=\"prefer_docling\"\(crlf)\(crlf)".utf8Data)
        body.append("\(preferDocling)".utf8Data)
        body.append(crlf.utf8Data)

        body.append("--\(boundary)--\(crlf)".utf8Data)
        return body
    }

    private static func latexMultipartBody(source: String, boundary: String) -> Data {
        var body = Data()
        let crlf = "\r\n"

        body.append("--\(boundary)\(crlf)".utf8Data)
        body.append("Content-Disposition: form-data; name=\"source\"\(crlf)\(crlf)".utf8Data)
        body.append(source.utf8Data)
        body.append(crlf.utf8Data)
        body.append("--\(boundary)--\(crlf)".utf8Data)
        return body
    }
}

// MARK: - String/Data helpers

private extension String {
    var utf8Data: Data { Data(utf8) }
}
