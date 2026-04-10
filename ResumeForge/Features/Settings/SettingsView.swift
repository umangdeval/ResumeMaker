import SwiftUI

@Observable
final class SettingsViewModel {
    var openAIKey: String = ""
    var anthropicKey: String = ""
    var geminiKey: String = ""
    var openRouterKey: String = ""
    
    var openAIEnabled: Bool = UserDefaults.standard.bool(forKey: "provider.openai.enabled")
    var anthropicEnabled: Bool = UserDefaults.standard.bool(forKey: "provider.anthropic.enabled")
    var geminiEnabled: Bool = UserDefaults.standard.bool(forKey: "provider.gemini.enabled")
    var openRouterEnabled: Bool = UserDefaults.standard.bool(forKey: "provider.openrouter.enabled")
    
    var selectedProvider: LLMProvider = LLMProvider(rawValue: UserDefaults.standard.string(forKey: "ai.selectedProvider") ?? "openai") ?? .openai
    
    var savedAlert: Bool = false
    var errorMessage: String?
    
    init() {
        Task {
            await loadKeysFromKeychain()
        }
    }
    
    @MainActor
    func loadKeysFromKeychain() async {
        if let key = try? KeychainService.load(key: .openAIAPIKey) {
            openAIKey = key
        }
        if let key = try? KeychainService.load(key: .anthropicAPIKey) {
            anthropicKey = key
        }
        if let key = try? KeychainService.load(key: .geminiAPIKey) {
            geminiKey = key
        }
        if let key = try? KeychainService.load(key: .openRouterAPIKey) {
            openRouterKey = key
        }
    }
    
    @MainActor
    func saveSettings() {
        do {
            // Save API keys
            if !openAIKey.isEmpty {
                try KeychainService.save(key: .openAIAPIKey, value: openAIKey)
            } else {
                KeychainService.delete(key: .openAIAPIKey)
            }
            
            if !anthropicKey.isEmpty {
                try KeychainService.save(key: .anthropicAPIKey, value: anthropicKey)
            } else {
                KeychainService.delete(key: .anthropicAPIKey)
            }
            
            if !geminiKey.isEmpty {
                try KeychainService.save(key: .geminiAPIKey, value: geminiKey)
            } else {
                KeychainService.delete(key: .geminiAPIKey)
            }
            
            if !openRouterKey.isEmpty {
                try KeychainService.save(key: .openRouterAPIKey, value: openRouterKey)
            } else {
                KeychainService.delete(key: .openRouterAPIKey)
            }
            
            // Save preferences
            UserDefaults.standard.setValue(openAIEnabled, forKey: "provider.openai.enabled")
            UserDefaults.standard.setValue(anthropicEnabled, forKey: "provider.anthropic.enabled")
            UserDefaults.standard.setValue(geminiEnabled, forKey: "provider.gemini.enabled")
            UserDefaults.standard.setValue(openRouterEnabled, forKey: "provider.openrouter.enabled")
            UserDefaults.standard.setValue(selectedProvider.rawValue, forKey: "ai.selectedProvider")
            
            savedAlert = true
            errorMessage = nil
        } catch let error as KeychainError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "An unexpected error occurred."
        }
    }
}

enum LLMProvider: String, CaseIterable {
    case openai = "openai"
    case anthropic = "anthropic"
    case gemini = "gemini"
    case openrouter = "openrouter"
    
    var displayName: String {
        switch self {
        case .openai: return "OpenAI (GPT-4o)"
        case .anthropic: return "Anthropic (Claude)"
        case .gemini: return "Google Gemini"
        case .openrouter: return "OpenRouter (Free & Paid)"
        }
    }
    
    var apiKeyLink: String {
        switch self {
        case .openai: return "https://platform.openai.com/api-keys"
        case .anthropic: return "https://console.anthropic.com/"
        case .gemini: return "https://ai.google.dev/tutorials/setup"
        case .openrouter: return "https://openrouter.ai"
        }
    }
}

struct SettingsView: View {
    @State private var viewModel = SettingsViewModel()

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("AI Council Providers")) {
                    Picker("Default Provider", selection: $viewModel.selectedProvider) {
                        ForEach(LLMProvider.allCases, id: \.self) { provider in
                            Text(provider.displayName).tag(provider)
                        }
                    }
                    .pickerStyle(.navigationLink)
                    
                    Text("Select which providers to enable for the AI Council.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                ProviderSection(
                    title: "OpenAI",
                    apiKeyLink: LLMProvider.openai.apiKeyLink,
                    key: $viewModel.openAIKey,
                    enabled: $viewModel.openAIEnabled,
                    description: "GPT-4o / GPT-4-turbo for high-quality analysis"
                )
                
                ProviderSection(
                    title: "Anthropic",
                    apiKeyLink: LLMProvider.anthropic.apiKeyLink,
                    key: $viewModel.anthropicKey,
                    enabled: $viewModel.anthropicEnabled,
                    description: "Claude models for nuanced resume parsing"
                )
                
                ProviderSection(
                    title: "Google Gemini",
                    apiKeyLink: LLMProvider.gemini.apiKeyLink,
                    key: $viewModel.geminiKey,
                    enabled: $viewModel.geminiEnabled,
                    description: "Gemini 1.5 Pro for fast, capable parsing"
                )
                
                ProviderSection(
                    title: "OpenRouter",
                    apiKeyLink: LLMProvider.openrouter.apiKeyLink,
                    key: $viewModel.openRouterKey,
                    enabled: $viewModel.openRouterEnabled,
                    description: "Free models (Mistral, Qwen) + premium options"
                )
                
                Section(header: Text("Local Parsing")) {
                    Text("Local Ollama + Qwen2.5 3B is enabled by default for fast, private parsing.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Link("Install Ollama", destination: URL(string: "https://ollama.ai")!)
                        .foregroundColor(.blue)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        viewModel.saveSettings()
                    }
                }
            }
            .alert("Settings Saved", isPresented: $viewModel.savedAlert) {
                Button("OK") { }
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? "An error occurred")
            }
        }
    }
}

struct ProviderSection: View {
    let title: String
    let apiKeyLink: String
    @Binding var key: String
    @Binding var enabled: Bool
    let description: String

    var body: some View {
        Section(header: HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(description).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            Toggle("", isOn: $enabled)
        }) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("API Key")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    if !key.isEmpty {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }
                
                SecureField("Paste your API key here", text: $key)
                    .monospacedDigit()
                    .textContentType(.password)
                
                Link("Get API Key →", destination: URL(string: apiKeyLink)!)
                    .font(.caption)
                    .foregroundColor(.blue)
            }
        }
    }
}

#Preview {
    SettingsView()
}
