import Foundation

/// Sends raw LaTeX source to an LLM and returns structured `ParsedResumeData`.
/// Falls back to the regex-based `LaTeXTextExtractor` when no service is available
/// or when the model returns unusable output.
enum LLMLatexExtractor {
    static func extract(from latexSource: String, service: AIServiceProtocol) async throws -> ParsedResumeData {
        let response = try await service.complete(
            prompt: PromptLibrary.latexExtractionUser(latexSource: latexSource),
            systemPrompt: PromptLibrary.latexExtractionSystem
        )
        return ResumeResultParser.parseJSON(response)
    }
}
