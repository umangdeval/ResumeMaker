import Foundation

/// Google Gemini provider.
final class GoogleGeminiService: AIServiceProtocol, LLMServiceProtocol {
    let providerName = "Google Gemini"
    let provider: LLMProvider = .gemini

    private let model: String
    private let apiKeyStorageKey: String
    private let baseURLString: String

    init(model: String = "gemini-1.5-flash", apiKeyStorageKey: String = KeychainKey.geminiAPIKey.rawValue, baseURLString: String = "https://generativelanguage.googleapis.com/v1/models") {
        self.model = model
        self.apiKeyStorageKey = apiKeyStorageKey
        self.baseURLString = baseURLString
    }

    func estimateTokens(for prompt: String) -> Int { estimateTokenCount(text: prompt) }

    private func streamingEndpoint(model: String) throws -> URL {
        let key = try KeychainService.load(key: apiKeyStorageKey)
        let urlString = "\(baseURLString)/\(model):streamGenerateContent?alt=sse&key=\(key)"
        guard let url = URL(string: urlString) else { throw AIServiceError.invalidResponse }
        return url
    }

    func stream(prompt: String, systemPrompt: String) -> AsyncThrowingStream<String, Error> {
        streamMessage(prompt: prompt, systemPrompt: systemPrompt, model: model, maxTokens: 2_048)
    }

    func streamMessage(
        prompt: String,
        systemPrompt: String,
        model: String,
        maxTokens: Int
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let url = try streamingEndpoint(model: model)
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.httpBody = try JSONEncoder().encode(
                        GeminiRequest(systemPrompt: systemPrompt, userPrompt: prompt, maxOutputTokens: maxTokens)
                    )

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    try validateStreamingResponse(response)

                    for try await line in bytes.lines {
                        guard line.hasPrefix("data:") else { continue }
                        let payload = line.replacingOccurrences(of: "data:", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !payload.isEmpty, payload != "[DONE]", let data = payload.data(using: .utf8) else { continue }
                        let chunk = try JSONDecoder().decode(GeminiStreamChunk.self, from: data)
                        if let text = chunk.candidates.first?.content.parts.first?.text, !text.isEmpty {
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
        let response = try await sendMessage(prompt: prompt, systemPrompt: systemPrompt, model: model, maxTokens: 2_048)
        return response.content
    }

    func sendMessage(
        prompt: String,
        systemPrompt: String,
        model: String,
        maxTokens: Int
    ) async throws -> LLMResponse {
        let startedAt = Date()

        return try await executeWithRetry { [self] in
            let url = try self.completionEndpoint(model: model)
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(
                GeminiRequest(systemPrompt: systemPrompt, userPrompt: prompt, maxOutputTokens: maxTokens)
            )

            let (data, response) = try await URLSession.shared.data(for: request)
            try self.validateHTTPResponse(data: data, response: response)
            let decoded = try JSONDecoder().decode(GeminiResponse.self, from: data)
            guard let text = decoded.candidates.first?.content.parts.first?.text else {
                throw LLMServiceError.invalidResponse
            }

            return LLMResponse(
                content: text,
                model: model,
                provider: .gemini,
                tokensUsed: decoded.usageMetadata?.totalTokenCount,
                latency: Date().timeIntervalSince(startedAt)
            )
        }
    }

    private func completionEndpoint(model: String) throws -> URL {
        let urlString = "\(baseURLString)/\(model):generateContent"
        guard let baseURL = URL(string: urlString) else { throw LLMServiceError.invalidURL }

        let apiKey: String
        do {
            apiKey = try KeychainService.load(key: apiKeyStorageKey)
        } catch {
            throw LLMServiceError.missingAPIKey(provider: .gemini)
        }

        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        guard let finalURL = components?.url else { throw LLMServiceError.invalidURL }
        return finalURL
    }

    private func validateStreamingResponse(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { return }
        switch http.statusCode {
        case 200...299: return
        case 429: throw LLMServiceError.rateLimited(retryAfter: http.value(forHTTPHeaderField: "Retry-After").flatMap(TimeInterval.init))
        default: throw LLMServiceError.server(statusCode: http.statusCode, body: "")
        }
    }
}

typealias GeminiService = GoogleGeminiService

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
    struct GenerationConfig: Encodable {
        let maxOutputTokens: Int

        enum CodingKeys: String, CodingKey {
            case maxOutputTokens = "maxOutputTokens"
        }
    }

    let systemInstruction: SystemInstruction
    let contents: [Content]
    let generationConfig: GenerationConfig

    init(systemPrompt: String, userPrompt: String, maxOutputTokens: Int) {
        self.systemInstruction = .init(parts: [.init(text: systemPrompt)])
        self.contents = [.init(role: "user", parts: [.init(text: userPrompt)])]
        self.generationConfig = .init(maxOutputTokens: maxOutputTokens)
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

    struct UsageMetadata: Decodable {
        let totalTokenCount: Int?
        let promptTokenCount: Int?
        let candidatesTokenCount: Int?
    }

    let candidates: [Candidate]
    let usageMetadata: UsageMetadata?
}

private typealias GeminiStreamChunk = GeminiResponse
