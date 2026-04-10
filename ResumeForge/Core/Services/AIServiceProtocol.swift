import Foundation

// MARK: - Core AI protocol

/// Every LLM provider conforms to this protocol so the AI Council can
/// treat all models uniformly.
protocol AIServiceProtocol: Sendable {
    var providerName: String { get }

    /// Estimate the number of tokens a prompt will consume.
    func estimateTokens(for prompt: String) -> Int

    /// Send a prompt and stream back partial text chunks.
    /// The returned `AsyncThrowingStream` finishes when the full response is received
    /// or throws on network/API error.
    func stream(prompt: String, systemPrompt: String) -> AsyncThrowingStream<String, Error>

    /// Send a prompt and return the complete response as a single String.
    func complete(prompt: String, systemPrompt: String) async throws -> String
}

// MARK: - Request / Response types

struct AIPromptRequest: Sendable {
    let system: String
    let user: String
    let maxTokens: Int

    init(system: String = "", user: String, maxTokens: Int = 2048) {
        self.system = system
        self.user = user
        self.maxTokens = maxTokens
    }
}

// MARK: - Errors

enum AIServiceError: Error, LocalizedError {
    case missingAPIKey(provider: String)
    case invalidResponse
    case rateLimited
    case networkError(underlying: Error)
    case serverError(statusCode: Int, body: String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey(let p):    return "No API key configured for \(p). Add one in Settings."
        case .invalidResponse:         return "Received an unexpected response from the AI provider."
        case .rateLimited:             return "Rate limit reached. Please wait before retrying."
        case .networkError(let e):     return "Network error: \(e.localizedDescription)"
        case .serverError(let c, _):   return "Server error \(c). Please try again later."
        }
    }
}

// MARK: - Local Ollama provider

/// Local provider backed by an Ollama server.
/// Default model is Qwen2.5 3B instruct for lightweight structured extraction.
final class OllamaService: AIServiceProtocol {
    let providerName = "Ollama (Local)"

    private let model: String
    private let endpoint: URL

    init(model: String = "qwen2.5:3b-instruct", endpoint: URL? = nil) {
        self.model = model
        if let endpoint {
            self.endpoint = endpoint
        } else if let defaultEndpoint = URL(string: "http://127.0.0.1:11434/api/generate") {
            self.endpoint = defaultEndpoint
        } else {
            self.endpoint = URL(fileURLWithPath: "/")
        }
    }

    func estimateTokens(for prompt: String) -> Int {
        max(1, prompt.count / 4)
    }

    func stream(prompt: String, systemPrompt: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    var request = URLRequest(url: endpoint)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.timeoutInterval = 120
                    request.httpBody = try JSONEncoder().encode(
                        OllamaGenerateRequest(model: model, prompt: prompt, system: systemPrompt, stream: true)
                    )

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    try validateHTTPResponse(response)

                    for try await line in bytes.lines {
                        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { continue }
                        guard let data = trimmed.data(using: .utf8) else { continue }
                        let chunk = try JSONDecoder().decode(OllamaGenerateResponse.self, from: data)

                        if let text = chunk.response, !text.isEmpty {
                            continuation.yield(text)
                        }
                        if chunk.done == true {
                            continuation.finish()
                            return
                        }
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: AIServiceError.networkError(underlying: error))
                }
            }
        }
    }

    func complete(prompt: String, systemPrompt: String) async throws -> String {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120
        request.httpBody = try JSONEncoder().encode(
            OllamaGenerateRequest(model: model, prompt: prompt, system: systemPrompt, stream: false)
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTPResponse(response)

        let decoded = try JSONDecoder().decode(OllamaGenerateResponse.self, from: data)
        guard let text = decoded.response?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
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

private struct OllamaGenerateRequest: Encodable {
    let model: String
    let prompt: String
    let system: String
    let stream: Bool
}

private struct OllamaGenerateResponse: Decodable {
    let response: String?
    let done: Bool?
}
