import Foundation

/// Anthropic (Claude) provider.
final class AnthropicService: AIServiceProtocol, LLMServiceProtocol {
    let providerName = "Anthropic"
    let provider: LLMProvider = .anthropic

    private let model: String
    private let baseURL: URL
    private let apiKeyStorageKey: String

    init(model: String = "claude-sonnet-4-6", apiKeyStorageKey: String = KeychainKey.anthropicAPIKey.rawValue, baseURLString: String = "https://api.anthropic.com/v1/messages") {
        self.model = model
        self.apiKeyStorageKey = apiKeyStorageKey
        self.baseURL = URL(string: baseURLString) ?? URL(fileURLWithPath: "/")
    }

    func estimateTokens(for prompt: String) -> Int { estimateTokenCount(text: prompt) }

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
                    let apiKey = try KeychainService.load(key: apiKeyStorageKey)
                    let request = try makeRequest(
                        apiKey: apiKey,
                        prompt: prompt,
                        systemPrompt: systemPrompt,
                        model: model,
                        maxTokens: maxTokens,
                        stream: true
                    )

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    try validateStreamingResponse(response)

                    for try await line in bytes.lines {
                        guard line.hasPrefix("data: ") else { continue }
                        if line == "data: [DONE]" { break }

                        let jsonData = Data(line.dropFirst(6).utf8)
                        let event = try JSONDecoder().decode(AnthropicStreamEvent.self, from: jsonData)
                        if event.type == "content_block_delta", let text = event.delta?.text, !text.isEmpty {
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
            let apiKey: String
            do {
                apiKey = try KeychainService.load(key: self.apiKeyStorageKey)
            } catch {
                throw LLMServiceError.missingAPIKey(provider: .anthropic)
            }

            let request = try self.makeRequest(
                apiKey: apiKey,
                prompt: prompt,
                systemPrompt: systemPrompt,
                model: model,
                maxTokens: maxTokens,
                stream: false
            )

            let (data, response) = try await URLSession.shared.data(for: request)
            try self.validateHTTPResponse(data: data, response: response)

            let decoded = try JSONDecoder().decode(AnthropicResponse.self, from: data)
            let text = decoded.content.map(\.text).joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else {
                throw LLMServiceError.invalidResponse
            }

            return LLMResponse(
                content: text,
                model: model,
                provider: .anthropic,
                tokensUsed: decoded.usage?.outputTokens,
                latency: Date().timeIntervalSince(startedAt)
            )
        }
    }

    private func makeRequest(
        apiKey: String,
        prompt: String,
        systemPrompt: String,
        model: String,
        maxTokens: Int,
        stream: Bool
    ) throws -> URLRequest {
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONEncoder().encode(
            AnthropicRequest(
                model: model,
                systemPrompt: systemPrompt,
                userPrompt: prompt,
                stream: stream,
                maxTokens: maxTokens
            )
        )
        return request
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

// MARK: - Codable helpers

private struct AnthropicRequest: Encodable {
    let model: String
    let system: String
    let messages: [AnthropicMessage]
    let maxTokens: Int
    let stream: Bool

    enum CodingKeys: String, CodingKey {
        case model, system, messages, stream
        case maxTokens = "max_tokens"
    }

    init(model: String, systemPrompt: String, userPrompt: String, stream: Bool, maxTokens: Int) {
        self.model = model
        self.system = systemPrompt
        self.messages = [.init(role: "user", content: userPrompt)]
        self.maxTokens = maxTokens
        self.stream = stream
    }
}

private struct AnthropicMessage: Encodable {
    let role: String
    let content: String
}

private struct AnthropicResponse: Decodable {
    struct Content: Decodable { let text: String }
    struct Usage: Decodable {
        let inputTokens: Int?
        let outputTokens: Int?

        enum CodingKeys: String, CodingKey {
            case inputTokens = "input_tokens"
            case outputTokens = "output_tokens"
        }
    }

    let content: [Content]
    let usage: Usage?
}

private struct AnthropicStreamEvent: Decodable {
    struct Delta: Decodable { let text: String? }
    let type: String
    let delta: Delta?
}
