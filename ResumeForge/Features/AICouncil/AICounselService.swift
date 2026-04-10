import Foundation

/// AI Council — orchestrates multiple LLM providers for better resume analysis.
/// Each enabled provider independently analyzes the resume + job description,
/// then a synthesizer combines their insights.
@MainActor
final class AICounselService {
    private var providers: [AIServiceProtocol] = []
    private let synthesizerProvider: AIServiceProtocol

    init() {
        // Build provider list from enabled settings
        var activeProviders: [AIServiceProtocol] = []
        
        if UserDefaults.standard.bool(forKey: "provider.openai.enabled") {
            activeProviders.append(OpenAIService())
        }
        if UserDefaults.standard.bool(forKey: "provider.anthropic.enabled") {
            activeProviders.append(AnthropicService())
        }
        if UserDefaults.standard.bool(forKey: "provider.gemini.enabled") {
            activeProviders.append(GeminiService())
        }
        if UserDefaults.standard.bool(forKey: "provider.openrouter.enabled") {
            activeProviders.append(OpenRouterService())
        }
        
        // Fall back to local Ollama if no providers enabled
        self.providers = activeProviders.isEmpty ? [OllamaService()] : activeProviders
        
        // Synthesizer can be any provider (OpenAI preferred if available)
        let selectedRaw = UserDefaults.standard.string(forKey: "ai.selectedProvider") ?? "openai"
        self.synthesizerProvider = selectProvider(for: selectedRaw)
    }

    /// Run the full AI Council analysis on a resume.
    /// Returns synthesized output combining all providers' analyses.
    func analyzeResume(text: String, jobDescription: String) async throws -> String {
        let prompt = """
        Analyze this resume in the context of the job description below.
        Return a concise JSON object with:
        - "strengths": [list of relevant strengths]
        - "gaps": [list of missing qualifications]
        - "keywords": [relevant keywords to highlight]
        - "suggestions": [actionable improvements]

        RESUME:
        \(text)

        JOB DESCRIPTION:
        \(jobDescription)
        """

        let systemPrompt = """
        You are an expert resume analyzer and career coach.
        Return ONLY valid JSON, no markdown, no explanations.
        """

        // Collect analyses from all providers in parallel
        let analyses = try await withThrowingTaskGroup(
            of: (String, String).self
        ) { group -> [(String, String)] in
            for provider in providers {
                group.addTask {
                    let output = try await provider.complete(prompt: prompt, systemPrompt: systemPrompt)
                    return (provider.providerName, output)
                }
            }

            var results: [(String, String)] = []
            for try await result in group {
                results.append(result)
            }
            return results
        }

        // Synthesize results
        let synthesisPrompt = """
        You are a career counsel synthesizer. You have received analyses from multiple AI experts.
        Combine their insights into a single, cohesive recommendation that highlights the best ideas
        and resolves any conflicts by consensus.

        EXPERT ANALYSES:
        \(analyses.map { "\($0.0): \($0.1)" }.joined(separator: "\n\n"))

        Return a comprehensive JSON summary with:
        - "top_strengths": [the strongest points]
        - "critical_improvements": [must-fix items]
        - "tailored_keywords": [keywords most relevant to job]
        - "action_plan": [step-by-step improvements]
        """

        let synthesis = try await synthesizerProvider.complete(
            prompt: synthesisPrompt,
            systemPrompt: systemPrompt
        )

        return synthesis
    }

    private func selectProvider(for rawValue: String) -> AIServiceProtocol {
        switch rawValue {
        case "openai": return OpenAIService()
        case "anthropic": return AnthropicService()
        case "gemini": return GeminiService()
        case "openrouter": return OpenRouterService()
        default: return OllamaService()
        }
    }
}

// MARK: - UI ViewModel

@Observable
final class AICouncelViewModel {
    var state: AICouncilState = .idle
    var councilOutput: String?
    var errorMessage: String?

    private let councilService = AICounselService()

    func runCouncil(resumeText: String, jobDescription: String) async {
        state = .analyzing
        errorMessage = nil

        do {
            let result = try await councilService.analyzeResume(
                text: resumeText,
                jobDescription: jobDescription
            )
            councilOutput = result
            state = .complete
        } catch {
            errorMessage = error.localizedDescription
            state = .error
        }
    }
}

enum AICouncilState {
    case idle
    case analyzing
    case complete
    case error
}
