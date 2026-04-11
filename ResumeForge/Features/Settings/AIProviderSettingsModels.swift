import AppKit
import SwiftUI

// MARK: - Provider model

enum AIProviderKind: String, Codable, CaseIterable, Identifiable {
    case openAICompatible = "openai-compatible"
    case anthropic = "anthropic"
    case gemini = "gemini"
    case openrouter = "openrouter"
    case ollama = "ollama"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .openAICompatible: return "OpenAI Compatible"
        case .anthropic: return "Anthropic"
        case .gemini: return "Gemini"
        case .openrouter: return "OpenRouter"
        case .ollama: return "Ollama"
        }
    }

    var defaultProviderName: String {
        switch self {
        case .openAICompatible: return "OpenAI"
        case .anthropic: return "Anthropic"
        case .gemini: return "Gemini"
        case .openrouter: return "OpenRouter"
        case .ollama: return "Ollama"
        }
    }

    var defaultEndpointURL: String {
        switch self {
        case .openAICompatible: return "https://api.openai.com/v1/chat/completions"
        case .anthropic: return "https://api.anthropic.com/v1/messages"
        case .gemini: return "https://generativelanguage.googleapis.com/v1beta/models"
        case .openrouter: return "https://openrouter.ai/api/v1/chat/completions"
        case .ollama: return "http://127.0.0.1:11434/api/generate"
        }
    }

    var defaultModel: String {
        switch self {
        case .openAICompatible: return "gpt-4o"
        case .anthropic: return "claude-sonnet-4-6"
        case .gemini: return "gemini-1.5-pro-latest"
        case .openrouter: return "mistral/mistral-7b-instruct"
        case .ollama: return "qwen2.5:3b-instruct"
        }
    }

    var modelSuggestions: [String] {
        switch self {
        case .openAICompatible:
            return ["gpt-4o", "gpt-4.1-mini", "gpt-4.1"]
        case .anthropic:
            return ["claude-sonnet-4-6", "claude-opus-4-1", "claude-haiku-4-5"]
        case .gemini:
            return ["gemini-2.5-pro", "gemini-1.5-pro-latest", "gemini-1.5-flash-latest"]
        case .openrouter:
            return ["mistral/mistral-7b-instruct", "qwen/qwen2.5-3b-instruct", "openai/gpt-4o", "anthropic/claude-sonnet-4-6"]
        case .ollama:
            return ["qwen2.5:3b-instruct", "qwen2.5:7b-instruct", "mistral:7b-instruct", "llama3.2:3b-instruct"]
        }
    }

    var usesAPIKey: Bool { self != .ollama }
}

struct AIProviderConfig: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var kind: AIProviderKind
    var providerName: String
    var apiKeyName: String
    var endpointURL: String
    var model: String
    var isEnabled: Bool
    var isDefault: Bool
    var apiKeyValue: String = ""

    enum CodingKeys: String, CodingKey {
        case id, kind, providerName, apiKeyName, endpointURL, model, isEnabled, isDefault
    }

    init(
        id: UUID = UUID(),
        kind: AIProviderKind,
        providerName: String,
        apiKeyName: String,
        endpointURL: String,
        model: String,
        isEnabled: Bool,
        isDefault: Bool = false,
        apiKeyValue: String = ""
    ) {
        self.id = id
        self.kind = kind
        self.providerName = providerName
        self.apiKeyName = apiKeyName
        self.endpointURL = endpointURL
        self.model = model
        self.isEnabled = isEnabled
        self.isDefault = isDefault
        self.apiKeyValue = apiKeyValue
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        kind = try container.decode(AIProviderKind.self, forKey: .kind)
        providerName = try container.decode(String.self, forKey: .providerName)
        apiKeyName = try container.decode(String.self, forKey: .apiKeyName)
        endpointURL = try container.decode(String.self, forKey: .endpointURL)
        model = try container.decode(String.self, forKey: .model)
        isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
        isDefault = try container.decodeIfPresent(Bool.self, forKey: .isDefault) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(kind, forKey: .kind)
        try container.encode(providerName, forKey: .providerName)
        try container.encode(apiKeyName, forKey: .apiKeyName)
        try container.encode(endpointURL, forKey: .endpointURL)
        try container.encode(model, forKey: .model)
        try container.encode(isEnabled, forKey: .isEnabled)
        try container.encode(isDefault, forKey: .isDefault)
    }

    static func makeDefault(kind: AIProviderKind) -> AIProviderConfig {
        AIProviderConfig(
            kind: kind,
            providerName: kind.defaultProviderName,
            apiKeyName: defaultAPIKeyName(for: kind),
            endpointURL: kind.defaultEndpointURL,
            model: kind.defaultModel,
            isEnabled: kind == .ollama,
            isDefault: kind == .ollama
        )
    }

    static func defaultAPIKeyName(for kind: AIProviderKind) -> String {
        switch kind {
        case .openAICompatible: return KeychainKey.openAIAPIKey.rawValue
        case .anthropic: return KeychainKey.anthropicAPIKey.rawValue
        case .gemini: return KeychainKey.geminiAPIKey.rawValue
        case .openrouter: return KeychainKey.openRouterAPIKey.rawValue
        case .ollama: return ""
        }
    }

    var ollamaCommandText: String {
        """
        brew install --cask ollama
        ollama serve
        ollama list
        ollama pull \(model)
        ollama run \(model)
        curl http://127.0.0.1:11434/api/tags
        """
    }
}

// MARK: - Persistence

enum AIProviderSettingsStore {
    private static let providersKey = "ai.providerConfigs"
    private static let localParsingKey = "parser.localLLMEnabled"
    private static let initialSetupUsedKey = "startup.initialSetupUsed"
    private static let initialSetupOllamaOnlyKey = "startup.initialSetupOllamaOnly"

    static func loadProviders() -> [AIProviderConfig] {
        if isInitialSetupOllamaOnlyEnabled {
            return ollamaOnlyProviders(from: defaultProviders())
        }

        if let data = UserDefaults.standard.data(forKey: providersKey),
           let decoded = try? JSONDecoder().decode([AIProviderConfig].self, from: data),
           !decoded.isEmpty {
            let normalizedProviders = normalized(decoded)
            return isInitialSetupOllamaOnlyEnabled
                ? ollamaOnlyProviders(from: normalizedProviders)
                : normalizedProviders
        }
        let defaults = defaultProviders()
        return isInitialSetupOllamaOnlyEnabled
            ? ollamaOnlyProviders(from: defaults)
            : defaults
    }

    static func saveProviders(_ providers: [AIProviderConfig]) {
        let normalizedProviders = normalized(providers)
        let encoded = isInitialSetupOllamaOnlyEnabled
            ? ollamaOnlyProviders(from: normalizedProviders)
            : normalizedProviders

        if let data = try? JSONEncoder().encode(encoded) {
            UserDefaults.standard.set(data, forKey: providersKey)
        }
    }

    static func markInitialSetupUsed(ollamaOnly: Bool) {
        UserDefaults.standard.set(true, forKey: initialSetupUsedKey)
        UserDefaults.standard.set(ollamaOnly, forKey: initialSetupOllamaOnlyKey)

        guard ollamaOnly else { return }
        saveLocalParsingEnabled(true)
        saveProviders(ollamaOnlyProviders(from: loadProviders()))
    }

    static func loadLocalParsingEnabled() -> Bool {
        UserDefaults.standard.object(forKey: localParsingKey) as? Bool ?? true
    }

    static func saveLocalParsingEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: localParsingKey)
    }

    static func defaultProviders() -> [AIProviderConfig] {
        [
            AIProviderConfig(
                kind: .openAICompatible,
                providerName: AIProviderKind.openAICompatible.defaultProviderName,
                apiKeyName: AIProviderConfig.defaultAPIKeyName(for: .openAICompatible),
                endpointURL: AIProviderKind.openAICompatible.defaultEndpointURL,
                model: AIProviderKind.openAICompatible.defaultModel,
                isEnabled: UserDefaults.standard.bool(forKey: "provider.openai.enabled")
            ),
            AIProviderConfig(
                kind: .anthropic,
                providerName: AIProviderKind.anthropic.defaultProviderName,
                apiKeyName: AIProviderConfig.defaultAPIKeyName(for: .anthropic),
                endpointURL: AIProviderKind.anthropic.defaultEndpointURL,
                model: AIProviderKind.anthropic.defaultModel,
                isEnabled: UserDefaults.standard.bool(forKey: "provider.anthropic.enabled")
            ),
            AIProviderConfig(
                kind: .gemini,
                providerName: AIProviderKind.gemini.defaultProviderName,
                apiKeyName: AIProviderConfig.defaultAPIKeyName(for: .gemini),
                endpointURL: AIProviderKind.gemini.defaultEndpointURL,
                model: AIProviderKind.gemini.defaultModel,
                isEnabled: UserDefaults.standard.bool(forKey: "provider.gemini.enabled")
            ),
            AIProviderConfig(
                kind: .openrouter,
                providerName: AIProviderKind.openrouter.defaultProviderName,
                apiKeyName: AIProviderConfig.defaultAPIKeyName(for: .openrouter),
                endpointURL: AIProviderKind.openrouter.defaultEndpointURL,
                model: AIProviderKind.openrouter.defaultModel,
                isEnabled: UserDefaults.standard.bool(forKey: "provider.openrouter.enabled")
            ),
            AIProviderConfig(
                kind: .ollama,
                providerName: AIProviderKind.ollama.defaultProviderName,
                apiKeyName: AIProviderConfig.defaultAPIKeyName(for: .ollama),
                endpointURL: AIProviderKind.ollama.defaultEndpointURL,
                model: AIProviderKind.ollama.defaultModel,
                isEnabled: loadLocalParsingEnabled(),
                isDefault: true
            )
        ]
    }

    static func normalized(_ providers: [AIProviderConfig]) -> [AIProviderConfig] {
        var result = providers
        if result.contains(where: { $0.isDefault }) == false, let firstEnabledIndex = result.firstIndex(where: { $0.isEnabled }) {
            result[firstEnabledIndex].isDefault = true
        }
        if result.contains(where: { $0.isDefault }) == false, let firstIndex = result.indices.first {
            result[firstIndex].isDefault = true
        }
        return result
    }

    private static var isInitialSetupOllamaOnlyEnabled: Bool {
        UserDefaults.standard.bool(forKey: initialSetupUsedKey) &&
        UserDefaults.standard.bool(forKey: initialSetupOllamaOnlyKey)
    }

    private static func ollamaOnlyProviders(from providers: [AIProviderConfig]) -> [AIProviderConfig] {
        let source = providers.first(where: { $0.kind == .ollama })
        var ollama = source ?? AIProviderConfig.makeDefault(kind: .ollama)
        ollama.isEnabled = true
        ollama.isDefault = true
        return [ollama]
    }
}

// MARK: - Service factory

enum AIProviderServiceFactory {
    static func makeService(for config: AIProviderConfig) -> AIServiceProtocol? {
        guard config.isEnabled else { return nil }
        let apiKeyName = config.apiKeyName.isEmpty ? AIProviderConfig.defaultAPIKeyName(for: config.kind) : config.apiKeyName
        switch config.kind {
        case .openAICompatible:
            return OpenAIService(model: config.model, apiKeyStorageKey: apiKeyName, baseURLString: config.endpointURL)
        case .anthropic:
            return AnthropicService(model: config.model, apiKeyStorageKey: apiKeyName, baseURLString: config.endpointURL)
        case .gemini:
            return GeminiService(model: config.model, apiKeyStorageKey: apiKeyName, baseURLString: config.endpointURL)
        case .openrouter:
            return OpenRouterService(model: config.model, apiKeyStorageKey: apiKeyName, baseURLString: config.endpointURL)
        case .ollama:
            return OllamaService(model: config.model, endpoint: URL(string: config.endpointURL))
        }
    }
}

