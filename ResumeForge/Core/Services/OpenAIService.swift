import Foundation

/// OpenAI (GPT-4o / GPT-4-turbo) provider.
final class OpenAIService: AIServiceProtocol, LLMServiceProtocol {
    let providerName = "OpenAI"
    let provider: LLMProvider = .openAI

    private let model: String
    private let baseURL: URL
    private let apiKeyStorageKey: String

    init(model: String = "gpt-4o", apiKeyStorageKey: String = KeychainKey.openAIAPIKey.rawValue, baseURLString: String = "https://api.openai.com/v1/chat/completions") {
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
                        if line == "data: [DONE]" {
                            break
                        }

                        let jsonData = Data(line.dropFirst(6).utf8)
                        let chunk = try JSONDecoder().decode(OpenAIStreamChunk.self, from: jsonData)
                        if let content = chunk.choices.first?.delta.content, !content.isEmpty {
                            continuation.yield(content)
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
                throw LLMServiceError.missingAPIKey(provider: .openAI)
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
            let decoded = try JSONDecoder().decode(OpenAIChatResponse.self, from: data)
            guard let content = decoded.choices.first?.message.content else {
                throw LLMServiceError.invalidResponse
            }

            return LLMResponse(
                content: content,
                model: model,
                provider: .openAI,
                tokensUsed: decoded.usage?.totalTokens,
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
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            OpenAIChatRequest(
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

// MARK: - Codable helpers (private to this file)

private struct OpenAIChatRequest: Encodable {
    let model: String
    let messages: [OpenAIChatMessage]
    let stream: Bool
    let maxTokens: Int

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case stream
        case maxTokens = "max_tokens"
    }

    init(model: String, systemPrompt: String, userPrompt: String, stream: Bool, maxTokens: Int) {
        self.model = model
        self.messages = [
            .init(role: "system", content: systemPrompt),
            .init(role: "user", content: userPrompt)
        ]
        self.stream = stream
        self.maxTokens = maxTokens
    }
}

private struct OpenAIChatMessage: Codable {
    let role: String
    let content: String
}

private struct OpenAIChatResponse: Decodable {
    struct Usage: Decodable {
        let totalTokens: Int?

        enum CodingKeys: String, CodingKey {
            case totalTokens = "total_tokens"
        }
    }

    struct Choice: Decodable {
        struct Message: Decodable { let content: String }
        let message: Message
    }

    let choices: [Choice]
    let usage: Usage?
}

private struct OpenAIStreamChunk: Decodable {
    struct Choice: Decodable {
        struct Delta: Decodable { let content: String? }
        let delta: Delta
    }
    let choices: [Choice]
}
