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
