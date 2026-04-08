import Foundation

/// Google Gemini provider.
final class GeminiService: AIServiceProtocol {
    let providerName = "Google Gemini"

    private let model: String

    init(model: String = "gemini-1.5-pro-latest") {
        self.model = model
    }

    func estimateTokens(for prompt: String) -> Int {
        max(1, prompt.count / 4)
    }

    private func endpoint() throws -> URL {
        let key = try KeychainService.load(key: .geminiAPIKey)
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(model):streamGenerateContent?key=\(key)"
        guard let url = URL(string: urlString) else { throw AIServiceError.invalidResponse }
        return url
    }

    func stream(prompt: String, systemPrompt: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let url = try endpoint()
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.httpBody = try JSONEncoder().encode(
                        GeminiRequest(systemPrompt: systemPrompt, userPrompt: prompt)
                    )
                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    try validateHTTPResponse(response)
                    // Gemini streaming returns newline-delimited JSON objects.
                    var buffer = ""
                    for try await character in bytes {
                        buffer.append(Character(UnicodeScalar(character)))
                        if buffer.hasSuffix("\n") {
                            let line = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
                            buffer = ""
                            guard !line.isEmpty,
                                  let data = line.data(using: .utf8),
                                  let chunk = try? JSONDecoder().decode(GeminiStreamChunk.self, from: data),
                                  let text = chunk.candidates.first?.content.parts.first?.text else { continue }
                            continuation.yield(text)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    func complete(prompt: String, systemPrompt: String) async throws -> String {
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent"
        guard let baseURL = URL(string: urlString) else { throw AIServiceError.invalidResponse }
        let apiKey = try KeychainService.load(key: .geminiAPIKey)
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        guard let url = components?.url else { throw AIServiceError.invalidResponse }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            GeminiRequest(systemPrompt: systemPrompt, userPrompt: prompt)
        )
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTPResponse(response)
        let decoded = try JSONDecoder().decode(GeminiResponse.self, from: data)
        guard let text = decoded.candidates.first?.content.parts.first?.text else {
            throw AIServiceError.invalidResponse
        }
        return text
    }

    private func validateHTTPResponse(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { return }
        switch http.statusCode {
        case 200...299: return
        case 429: throw AIServiceError.rateLimited
        default: throw AIServiceError.serverError(statusCode: http.statusCode, body: "")
        }
    }
}

// MARK: - Codable helpers

private struct GeminiRequest: Encodable {
    struct SystemInstruction: Encodable {
        struct Part: Encodable { let text: String }
        let parts: [Part]
    }
    struct Content: Encodable {
        struct Part: Encodable { let text: String }
        let role: String
        let parts: [Part]
    }
    let systemInstruction: SystemInstruction
    let contents: [Content]

    init(systemPrompt: String, userPrompt: String) {
        self.systemInstruction = .init(parts: [.init(text: systemPrompt)])
        self.contents = [.init(role: "user", parts: [.init(text: userPrompt)])]
    }
}

private struct GeminiResponse: Decodable {
    struct Candidate: Decodable {
        struct Content: Decodable {
            struct Part: Decodable { let text: String }
            let parts: [Part]
        }
        let content: Content
    }
    let candidates: [Candidate]
}

private typealias GeminiStreamChunk = GeminiResponse
