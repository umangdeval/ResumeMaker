import Foundation

/// OpenRouter provider — access to free and paid models via single API key.
/// Visit https://openrouter.ai to get your API key.
final class OpenRouterService: AIServiceProtocol {
    let providerName = "OpenRouter"

    private let model: String
    private let baseURL: URL
    private let apiKeyStorageKey: String

    init(model: String = "mistral/mistral-7b-instruct", apiKeyStorageKey: String = KeychainKey.openRouterAPIKey.rawValue, baseURLString: String = "https://openrouter.ai/api/v1/chat/completions") {
        self.model = model
        self.apiKeyStorageKey = apiKeyStorageKey
        self.baseURL = URL(string: baseURLString) ?? URL(fileURLWithPath: "/")
    }

    func estimateTokens(for prompt: String) -> Int {
        // Rough approximation: ~4 characters per token.
        max(1, prompt.count / 4)
    }

    func stream(prompt: String, systemPrompt: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let apiKey = try KeychainService.load(key: apiKeyStorageKey)
                    var request = URLRequest(url: baseURL)
                    request.httpMethod = "POST"
                    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                    request.setValue("https://resumeforge.local", forHTTPHeaderField: "HTTP-Referer")
                    request.setValue("ResumeForge/1.0", forHTTPHeaderField: "User-Agent")
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.httpBody = try JSONEncoder().encode(
                        OpenRouterRequest(model: model, systemPrompt: systemPrompt, userPrompt: prompt, stream: true)
                    )
                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    try validateHTTPResponse(response)
                    for try await line in bytes.lines {
                        guard line.hasPrefix("data: "),
                              line != "data: [DONE]" else { continue }
                        let jsonData = Data(line.dropFirst(6).utf8)
                        if let chunk = try? JSONDecoder().decode(OpenRouterStreamChunk.self, from: jsonData),
                           let content = chunk.choices.first?.delta.content {
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
        let apiKey = try KeychainService.load(key: apiKeyStorageKey)
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("https://resumeforge.local", forHTTPHeaderField: "HTTP-Referer")
        request.setValue("ResumeForge/1.0", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            OpenRouterRequest(model: model, systemPrompt: systemPrompt, userPrompt: prompt, stream: false)
        )
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTPResponse(response)
        let decoded = try JSONDecoder().decode(OpenRouterResponse.self, from: data)
        guard let text = decoded.choices.first?.message.content else {
            throw AIServiceError.invalidResponse
        }
        return text
    }

    private func validateHTTPResponse(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { return }
        switch http.statusCode {
        case 200...299: return
        case 429: throw AIServiceError.rateLimited
        case 401: throw AIServiceError.missingAPIKey(provider: providerName)
        default: throw AIServiceError.serverError(statusCode: http.statusCode, body: "")
        }
    }
}

// MARK: - Codable helpers

private struct OpenRouterRequest: Encodable {
    let model: String
    let messages: [OpenRouterMessage]
    let stream: Bool

    init(model: String, systemPrompt: String, userPrompt: String, stream: Bool) {
        self.model = model
        self.messages = [
            .init(role: "system", content: systemPrompt),
            .init(role: "user", content: userPrompt)
        ]
        self.stream = stream
    }
}

private struct OpenRouterMessage: Encodable {
    let role: String
    let content: String
}

private struct OpenRouterResponse: Decodable {
    let choices: [OpenRouterChoice]

    private enum CodingKeys: String, CodingKey {
        case choices
    }
}

private struct OpenRouterChoice: Decodable {
    let message: OpenRouterMessageResponse
    let finishReason: String?

    private enum CodingKeys: String, CodingKey {
        case message
        case finishReason = "finish_reason"
    }
}

private struct OpenRouterMessageResponse: Decodable {
    let content: String
}

private struct OpenRouterStreamChunk: Decodable {
    let choices: [OpenRouterStreamChoice]
}

private struct OpenRouterStreamChoice: Decodable {
    let delta: OpenRouterDelta
}

private struct OpenRouterDelta: Decodable {
    let content: String?
}
