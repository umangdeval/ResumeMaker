import AppKit
import SwiftUI

@MainActor
@Observable
final class EditableProviderSettingsViewModel {
    var providers: [AIProviderConfig] = AIProviderSettingsStore.loadProviders()
    var localParsingEnabled: Bool = AIProviderSettingsStore.loadLocalParsingEnabled()
    var savedAlert = false
    var errorMessage: String?
    var isShowingOllamaCommands = false
    var ollamaCommandText = ""
    private let providerRowHeight: CGFloat = 56
    private let providerListMinHeight: CGFloat = 180
    private let providerListMaxHeight: CGFloat = 320

    init() {
        loadSecrets()
    }

    func addProvider(_ config: AIProviderConfig) {
        providers.append(config)
    }

    func updateProvider(_ updated: AIProviderConfig) {
        guard let index = providers.firstIndex(where: { $0.id == updated.id }) else { return }
        providers[index] = updated
    }

    func removeProvider(id: UUID) {
        providers.removeAll { $0.id == id }
        if providers.contains(where: { $0.isDefault }) == false, let firstIndex = providers.indices.first {
            providers[firstIndex].isDefault = true
        }
    }

    func setDefault(id: UUID) {
        for index in providers.indices {
            providers[index].isDefault = providers[index].id == id
        }
    }

    func provider(with id: UUID?) -> AIProviderConfig? {
        guard let id else { return nil }
        return providers.first(where: { $0.id == id })
    }

    func loadSecrets() {
        for index in providers.indices {
            let keyName = providers[index].apiKeyName.isEmpty ? AIProviderConfig.defaultAPIKeyName(for: providers[index].kind) : providers[index].apiKeyName
            guard !keyName.isEmpty else { continue }
            if let value = try? KeychainService.load(key: keyName) {
                providers[index].apiKeyValue = value
            }
        }
    }

    func saveSettings() {
        do {
            for index in providers.indices {
                let trimmedKeyName = providers[index].apiKeyName.trimmingCharacters(in: .whitespacesAndNewlines)
                let keyName = trimmedKeyName.isEmpty
                    ? AIProviderConfig.defaultAPIKeyName(for: providers[index].kind)
                    : trimmedKeyName
                let keyValue = providers[index].apiKeyValue

                if providers[index].kind.usesAPIKey, !keyName.isEmpty, !keyValue.isEmpty {
                    try KeychainService.save(key: keyName, value: keyValue)
                } else if !keyName.isEmpty {
                    KeychainService.delete(key: keyName)
                }

                providers[index].apiKeyName = keyName
                providers[index].endpointURL = providers[index].endpointURL.trimmingCharacters(in: .whitespacesAndNewlines)
                providers[index].model = providers[index].model.trimmingCharacters(in: .whitespacesAndNewlines)
                providers[index].providerName = providers[index].providerName.trimmingCharacters(in: .whitespacesAndNewlines)
            }

            providers = AIProviderSettingsStore.normalized(providers)
            AIProviderSettingsStore.saveProviders(providers)
            AIProviderSettingsStore.saveLocalParsingEnabled(localParsingEnabled)
            savedAlert = true
            errorMessage = nil
        } catch {
            errorMessage = "An unexpected error occurred."
        }
    }

    func showOllamaCommands(for model: String) {
        ollamaCommandText = AIProviderConfig(
            kind: .ollama,
            providerName: "Ollama",
            apiKeyName: "",
            endpointURL: "",
            model: model,
            isEnabled: true
        ).ollamaCommandText
        isShowingOllamaCommands = true
        openTerminal(withCommands: ollamaCommandText)
    }

    var providerListHeight: CGFloat {
        let contentHeight = CGFloat(max(providers.count, 3)) * providerRowHeight
        return min(max(contentHeight, providerListMinHeight), providerListMaxHeight)
    }

    var ollamaModelForSetup: String {
        providers.first(where: { $0.kind == .ollama })?.model ?? AIProviderKind.ollama.defaultModel
    }

    private func openTerminal(withCommands commands: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(commands, forType: .string)

        let terminalCommand = "clear; echo 'ResumeForge Ollama setup commands:'; echo ''; pbpaste; echo ''; echo 'Commands were copied to clipboard too.'"
        let script = "tell application \"Terminal\"\nactivate\ndo script \"\(terminalCommand)\"\nend tell"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus != 0 {
                errorMessage = "Terminal opened, but commands could not be auto-printed. Use the copy button in the command sheet."
            }
        } catch {
            errorMessage = "Terminal opened, but commands could not be auto-printed. Use the copy button in the command sheet."
        }
    }
}

struct EditableProviderSettingsView: View {
    let pythonStatus: PythonEnvironmentStatus
    @AppStorage("didShowStartupGuide") private var didShowStartupGuide = false
    @State private var viewModel = EditableProviderSettingsViewModel()
    @State private var selectedProviderID: UUID?
    @State private var isShowingAddSheet = false
    @State private var editingProvider: AIProviderConfig?
    @State private var addDraft = AIProviderConfig.makeDefault(kind: .openAICompatible)
    @State private var isShowingStartupGuide = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    pythonSection
                    providersSection
                    parsingSection
                    HStack {
                        Spacer()
                        Button("Save") { viewModel.saveSettings() }
                            .buttonStyle(.borderedProminent)
                            .tint(AppTheme.blue)
                    }
                }
                .padding(20)
                .appContentWidth()
            }
            .appScreenBackground()
            .navigationTitle("Settings")
            .tint(AppTheme.blue)
            .alert("Settings Saved", isPresented: $viewModel.savedAlert) {
                Button("OK") { }
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "An error occurred")
            }
            .sheet(isPresented: $viewModel.isShowingOllamaCommands) {
                EditableOllamaCommandSheet(commandText: viewModel.ollamaCommandText)
                    .frame(minWidth: 500, minHeight: 320)
            }
            .sheet(isPresented: $isShowingAddSheet) {
                ProviderEditorSheet(
                    title: "Add API Provider",
                    initialProvider: addDraft,
                    onSave: { provider in
                        viewModel.addProvider(provider)
                    },
                    onOpenOllamaHelp: { model in
                        viewModel.showOllamaCommands(for: model)
                    }
                )
            }
            .sheet(item: $editingProvider) { provider in
                ProviderEditorSheet(
                    title: "Edit API Provider",
                    initialProvider: provider,
                    onSave: { updated in
                        viewModel.updateProvider(updated)
                    },
                    onOpenOllamaHelp: { model in
                        viewModel.showOllamaCommands(for: model)
                    }
                )
            }
            .sheet(isPresented: $isShowingStartupGuide) {
                StartupGuideView(
                    pythonStatus: pythonStatus,
                    ollamaModel: viewModel.ollamaModelForSetup
                ) {
                    isShowingStartupGuide = false
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Provider & Local Parsing")
                .font(AppTheme.heroTitle)
                .foregroundStyle(AppTheme.text)
            Text("Configure model providers, API keys, and local parsing behavior.")
                .font(AppTheme.body)
                .foregroundStyle(AppTheme.textSecondary)

            NavigationLink {
                StyleReferenceView()
            } label: {
                Label("Writing Style Reference", systemImage: "text.quote")
            }
            .buttonStyle(.bordered)

            Button {
                didShowStartupGuide = false
                isShowingStartupGuide = true
            } label: {
                Label("Reset Initial Startup", systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .appCard()
    }

    private var pythonSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Python / Docling")
                .font(AppTheme.sectionTitle)
                .foregroundStyle(AppTheme.text)
            if pythonStatus != .ready {
                PythonSetupView(status: pythonStatus) {
                    viewModel.loadSecrets()
                }
            } else {
                Label("docling-parse is installed and ready.", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(AppTheme.body)
            }
        }
        .padding(16)
        .appCard()
    }

    private var providersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("API Providers")
                .font(AppTheme.sectionTitle)
                .foregroundStyle(AppTheme.text)

            List(selection: $selectedProviderID) {
                ForEach(viewModel.providers) { provider in
                    ProviderListRow(provider: provider)
                        .tag(provider.id)
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) {
                            editingProvider = provider
                        }
                }
            }
                .scrollContentBackground(.hidden)
                .background(.clear)
            .frame(height: viewModel.providerListHeight)

            HStack {
                Button {
                    addDraft = AIProviderConfig.makeDefault(kind: .openAICompatible)
                    isShowingAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)

                Button {
                    if let selectedProviderID {
                        viewModel.removeProvider(id: selectedProviderID)
                        self.selectedProviderID = nil
                    }
                } label: {
                    Image(systemName: "minus")
                }
                .buttonStyle(.borderless)
                .disabled(selectedProviderID == nil)

                Button("Edit") {
                    editingProvider = viewModel.provider(with: selectedProviderID)
                }
                .disabled(selectedProviderID == nil)
            }
        }
        .padding(16)
        .appCard()
    }

    private var ollamaSetupSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Local Ollama Setup")
                .font(AppTheme.sectionTitle)
                .foregroundStyle(AppTheme.text)
            Text("Run these once to use local parsing and local model responses.")
                .font(AppTheme.body)
                .foregroundStyle(AppTheme.textSecondary)

            VStack(alignment: .leading, spacing: 6) {
                Text("1. Install and start Ollama")
                Text("2. Pull your selected model")
                Text("3. Keep the service running at http://127.0.0.1:11434")
            }
            .font(AppTheme.caption)
            .foregroundStyle(AppTheme.text)

            Button("Open Terminal + Show Commands") {
                viewModel.showOllamaCommands(for: viewModel.ollamaModelForSetup)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.blue)
        }
        .padding(16)
        .appCard()
    }

    private var parsingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Local Parsing")
                .font(AppTheme.sectionTitle)
                .foregroundStyle(AppTheme.text)
            Toggle("Use local Ollama for parsing", isOn: $viewModel.localParsingEnabled)
                .foregroundStyle(AppTheme.text)
                .toggleStyle(.switch)
            ollamaSetupSection
        }
        .padding(16)
        .appCard()
    }
}

struct ProviderListRow: View {
    let provider: AIProviderConfig

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: provider.kind == .ollama ? "cpu" : "key.horizontal")
                .foregroundStyle(AppTheme.blue)
            VStack(alignment: .leading, spacing: 2) {
                Text(provider.providerName.isEmpty ? provider.kind.displayName : provider.providerName)
                    .font(AppTheme.body.weight(.semibold))
                    .foregroundStyle(AppTheme.text)
                Text(provider.endpointURL)
                    .font(AppTheme.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer()
            Toggle("", isOn: .constant(provider.isEnabled))
                .labelsHidden()
                .disabled(true)
        }
        .padding(.vertical, 4)
        .listRowBackground(AppTheme.surface)
    }
}
