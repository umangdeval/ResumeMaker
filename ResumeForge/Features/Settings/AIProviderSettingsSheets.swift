import AppKit
import SwiftUI

struct ProviderEditorSheet: View {
    let title: String
    let onSave: (AIProviderConfig) -> Void
    let onOpenOllamaHelp: (String) -> Void

    @State private var draft: AIProviderConfig
    @Environment(\.dismiss) private var dismiss

    init(
        title: String,
        initialProvider: AIProviderConfig,
        onSave: @escaping (AIProviderConfig) -> Void,
        onOpenOllamaHelp: @escaping (String) -> Void
    ) {
        self.title = title
        self.onSave = onSave
        self.onOpenOllamaHelp = onOpenOllamaHelp
        _draft = State(initialValue: initialProvider)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Provider Name", text: $draft.providerName)
                Picker("Type", selection: $draft.kind) {
                    ForEach(AIProviderKind.allCases) { kind in
                        Text(kind.displayName).tag(kind)
                    }
                }
                .pickerStyle(.menu)
                Toggle("Enabled", isOn: $draft.isEnabled)
                Toggle("Default", isOn: $draft.isDefault)
                TextField("API Key Name", text: $draft.apiKeyName)

                if draft.kind.usesAPIKey {
                    SecureField("API Key", text: $draft.apiKeyValue)
                }

                TextField("URL", text: $draft.endpointURL)
                HStack {
                    TextField("Model", text: $draft.model)
                    Menu("Suggestions") {
                        ForEach(draft.kind.modelSuggestions, id: \.self) { model in
                            Button(model) { draft.model = model }
                        }
                    }
                }

                if draft.kind == .ollama {
                    Button("Open Ollama Setup") {
                        onOpenOllamaHelp(draft.model)
                    }
                }
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(draft)
                        dismiss()
                    }
                }
            }
        }
        .frame(minWidth: 520, minHeight: 420)
    }
}

struct EditableOllamaCommandSheet: View {
    let commandText: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Terminal will open, but nothing runs automatically.")
                        .font(.headline)
                    Text("Commands")
                        .font(.subheadline.weight(.semibold))
                    Text(commandText)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
                        .textSelection(.enabled)
                    Text("Tip: copy the commands or paste them into the Terminal window that opened for you.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            .navigationTitle("Ollama Commands")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Copy") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(commandText, forType: .string)
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
