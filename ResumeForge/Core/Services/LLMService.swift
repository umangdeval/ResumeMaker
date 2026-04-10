import Foundation

enum LLMProvider: String, Codable, CaseIterable, Identifiable, Hashable {
    case openAI
    case anthropic
    case gemini
    case openRouter
    case ollama

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .openAI: return "OpenAI"
        case .anthropic: return "Anthropic"
        case .gemini: return "Google Gemini"
        case .openRouter: return "OpenRouter"
        case .ollama: return "Ollama"
        }
    }
}

struct LLMResponse: Sendable {
    let content: String
    let model: String
    let provider: LLMProvider
    let tokensUsed: Int?
    let latency: TimeInterval
}

protocol LLMServiceProtocol: Sendable {
    var provider: LLMProvider { get }

    func sendMessage(
        prompt: String,
        systemPrompt: String,
        model: String,
        maxTokens: Int
    ) async throws -> LLMResponse

    func estimateTokenCount(text: String) -> Int

    func streamMessage(
        prompt: String,
        systemPrompt: String,
        model: String,
        maxTokens: Int
    ) -> AsyncThrowingStream<String, Error>
}

enum LLMServiceError: Error, LocalizedError, Sendable {
    case missingAPIKey(provider: LLMProvider)
    case invalidURL
    case invalidResponse
    case malformedStreamEvent
    case rateLimited(retryAfter: TimeInterval?)
    case network(underlying: String)
    case server(statusCode: Int, body: String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey(let provider):
            return "No API key configured for \(provider.displayName)."
        case .invalidURL:
            return "Unable to build request URL."
        case .invalidResponse:
            return "The provider returned an unexpected response."
        case .malformedStreamEvent:
            return "The provider returned malformed streaming data."
        case .rateLimited:
            return "Rate limit reached. Please retry shortly."
        case .network(let message):
            return "Network error: \(message)"
        case .server(let code, _):
            return "Provider server error (\(code))."
        }
    }
}

enum LLMRetryPolicy {
    static let maxAttempts = 3

    static func shouldRetry(_ error: Error, attempt: Int) -> Bool {
        guard attempt < maxAttempts else { return false }

        if case LLMServiceError.rateLimited = error {
            return true
        }

        if case LLMServiceError.network = error {
            return true
        }

        if case LLMServiceError.server(let code, _) = error {
            return code >= 500
        }

        return false
    }

    static func delay(for attempt: Int, error: Error) -> UInt64 {
        if case LLMServiceError.rateLimited(let retryAfter) = error,
           let retryAfter,
           retryAfter > 0 {
            return UInt64(retryAfter * 1_000_000_000)
        }

        let seconds = pow(2.0, Double(attempt - 1))
        let jitter = Double.random(in: 0.0...0.25)
        return UInt64((seconds + jitter) * 1_000_000_000)
    }
}

extension LLMServiceProtocol {
    func estimateTokenCount(text: String) -> Int {
        max(1, text.count / 4)
    }

    func executeWithRetry<T: Sendable>(
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        var attempt = 0

        while true {
            attempt += 1
            do {
                return try await operation()
            } catch {
                guard LLMRetryPolicy.shouldRetry(error, attempt: attempt) else {
                    throw error
                }
                try await Task.sleep(nanoseconds: LLMRetryPolicy.delay(for: attempt, error: error))
            }
        }
    }

    func validateHTTPResponse(data: Data, response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw LLMServiceError.invalidResponse
        }

        if (200...299).contains(http.statusCode) {
            return
        }

        if http.statusCode == 429 {
            let retryAfter = http.value(forHTTPHeaderField: "Retry-After").flatMap(TimeInterval.init)
            throw LLMServiceError.rateLimited(retryAfter: retryAfter)
        }

        let body = String(data: data, encoding: .utf8) ?? ""
        throw LLMServiceError.server(statusCode: http.statusCode, body: body)
    }
}
