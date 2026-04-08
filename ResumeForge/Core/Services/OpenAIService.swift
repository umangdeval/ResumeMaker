import Foundation

/// OpenAI (GPT-4o / GPT-4-turbo) provider.
final class OpenAIService: AIServiceProtocol {
    let providerName = "OpenAI"

    private let model: String
    private let baseURL = URL(string: "https://api.openai.com/v1/chat/completions")! // swiftlint:disable:this force_unwrapping

    init(model: String = "gpt-4o") {
        self.model = model
    }

    func estimateTokens(for prompt: String) -> Int {
        // Rough approximation: ~4 characters per token.
        max(1, prompt.count / 4)
    }

    func stream(prompt: String, systemPrompt: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let apiKey = try KeychainService.load(key: .openAIAPIKey)
                    var request = URLRequest(url: baseURL)
                    request.httpMethod = "POST"
                    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.httpBody = try JSONEncoder().encode(
                        OpenAIChatRequest(model: model, systemPrompt: systemPrompt, userPrompt: prompt, stream: true)
                    )
                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    try validateHTTPResponse(response)
                    for try await line in bytes.lines {
                        guard line.hasPrefix("data: "),
                              line != "data: [DONE]" else { continue }
                        let jsonData = Data(line.dropFirst(6).utf8)
                        if let chunk = try? JSONDecoder().decode(OpenAIStreamChunk.self, from: jsonData),
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
        let apiKey = try KeychainService.load(key: .openAIAPIKey)
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            OpenAIChatRequest(model: model, systemPrompt: systemPrompt, userPrompt: prompt, stream: false)
        )
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTPResponse(response)
        let decoded = try JSONDecoder().decode(OpenAIChatResponse.self, from: data)
        guard let content = decoded.choices.first?.message.content else {
            throw AIServiceError.invalidResponse
        }
        return content
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

// MARK: - Codable helpers (private to this file)

private struct OpenAIChatRequest: Encodable {
    let model: String
    let messages: [OpenAIChatMessage]
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

private struct OpenAIChatMessage: Codable {
    let role: String
    let content: String
}

private struct OpenAIChatResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable { let content: String }
        let message: Message
    }
    let choices: [Choice]
}

private struct OpenAIStreamChunk: Decodable {
    struct Choice: Decodable {
        struct Delta: Decodable { let content: String? }
        let delta: Delta
    }
    let choices: [Choice]
}
