import Foundation

/// Anthropic (Claude) provider.
final class AnthropicService: AIServiceProtocol {
    let providerName = "Anthropic"

    private let model: String
    private let baseURL: URL
    private let apiKeyStorageKey: String

    init(model: String = "claude-sonnet-4-6", apiKeyStorageKey: String = KeychainKey.anthropicAPIKey.rawValue, baseURLString: String = "https://api.anthropic.com/v1/messages") {
        self.model = model
        self.apiKeyStorageKey = apiKeyStorageKey
        self.baseURL = URL(string: baseURLString) ?? URL(fileURLWithPath: "/")
    }

    func estimateTokens(for prompt: String) -> Int {
        max(1, prompt.count / 4)
    }

    func stream(prompt: String, systemPrompt: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let apiKey = try KeychainService.load(key: apiKeyStorageKey)
                    var request = URLRequest(url: baseURL)
                    request.httpMethod = "POST"
                    request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
                    request.httpBody = try JSONEncoder().encode(
                        AnthropicRequest(model: model, systemPrompt: systemPrompt, userPrompt: prompt, stream: true)
                    )
                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    try validateHTTPResponse(response)
                    for try await line in bytes.lines {
                        guard line.hasPrefix("data: ") else { continue }
                        let jsonData = Data(line.dropFirst(6).utf8)
                        if let event = try? JSONDecoder().decode(AnthropicStreamEvent.self, from: jsonData),
                           event.type == "content_block_delta",
                           let text = event.delta?.text {
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
        let apiKey = try KeychainService.load(key: apiKeyStorageKey)
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONEncoder().encode(
            AnthropicRequest(model: model, systemPrompt: systemPrompt, userPrompt: prompt, stream: false)
        )
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTPResponse(response)
        let decoded = try JSONDecoder().decode(AnthropicResponse.self, from: data)
        guard let text = decoded.content.first?.text else {
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

    init(model: String, systemPrompt: String, userPrompt: String, stream: Bool, maxTokens: Int = 2048) {
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
    let content: [Content]
}

private struct AnthropicStreamEvent: Decodable {
    struct Delta: Decodable { let text: String? }
    let type: String
    let delta: Delta?
}
