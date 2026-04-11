import SwiftUI

struct StartupGuideView: View {
    let pythonStatus: PythonEnvironmentStatus
    let ollamaModel: String
    let onContinue: () -> Void
    @State private var showAutoSetupControls = false
    @State private var installOllama = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    hero
                    doclingSection
                    ollamaSection
                    setupControls
                    footer
                }
                .padding(20)
            }
            .appScreenBackground()
            .navigationTitle("First Run Guide")
            .tint(AppTheme.blue)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Continue", action: onContinue)
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.blue)
                }
            }
        }
        .frame(minWidth: 760, minHeight: 680)
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Welcome to ResumeForge")
                .font(AppTheme.heroTitle)
                .foregroundStyle(.white)
            Text("Follow these setup steps once, then you can start parsing resumes and using local Ollama commands.")
                .font(AppTheme.body)
                .foregroundStyle(.white.opacity(0.84))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color.black, in: RoundedRectangle(cornerRadius: 12))
    }

    private var doclingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Docling / Python")
                .font(AppTheme.sectionTitle)
                .foregroundStyle(AppTheme.text)

            if pythonStatus == .ready {
                Label("Docling is ready. ResumeForge can use the local Python parser.", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(AppTheme.body)
            } else {
                Text("Set up Python and docling-parse so PDF parsing has the best results.")
                    .font(AppTheme.body)
                    .foregroundStyle(AppTheme.textSecondary)

                VStack(alignment: .leading, spacing: 6) {
                    Text("1. Install Python 3")
                    Text("2. Create a virtual environment in the project folder")
                    Text("3. Install docling-parse")
                    Text("4. Restart ResumeForge")
                }
                .font(AppTheme.caption)
                .foregroundStyle(AppTheme.text)

                CodeBlock(code: "brew install python\npython3 -m venv .venv\n./.venv/bin/python -m pip install --upgrade pip docling-parse")
            }
        }
        .padding(16)
        .appCard()
    }

    private var ollamaSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ollama / Local Models")
                .font(AppTheme.sectionTitle)
                .foregroundStyle(AppTheme.text)

            Text("Use Ollama when you want local parsing or local model access on your Mac.")
                .font(AppTheme.body)
                .foregroundStyle(AppTheme.textSecondary)

            VStack(alignment: .leading, spacing: 6) {
                Text("1. Install Ollama")
                Text("2. Start the service")
                Text("3. Pull the model below")
                Text("4. Keep Ollama running at http://127.0.0.1:11434")
            }
            .font(AppTheme.caption)
            .foregroundStyle(AppTheme.text)

            CodeBlock(code: "brew install --cask ollama\nollama serve\nollama pull \(ollamaModel)\nollama run \(ollamaModel)")

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString("brew install --cask ollama\nollama serve\nollama pull \(ollamaModel)\nollama run \(ollamaModel)", forType: .string)
            } label: {
                Label("Copy Ollama commands", systemImage: "doc.on.doc")
            }
            .buttonStyle(.bordered)
            .tint(AppTheme.blue)
        }
        .padding(16)
        .appCard()
    }

    private var setupControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Initial Setup Script")
                .font(AppTheme.sectionTitle)
                .foregroundStyle(AppTheme.text)

            Text("Click Auto Setup to open Terminal and run the startup script. You can choose whether Ollama gets installed.")
                .font(AppTheme.body)
                .foregroundStyle(AppTheme.textSecondary)

            if showAutoSetupControls {
                Toggle("Install Ollama during setup", isOn: $installOllama)
                    .font(AppTheme.body)
                    .foregroundStyle(AppTheme.text)
            }

            HStack(spacing: 10) {
                Button(showAutoSetupControls ? "Run Auto Setup" : "Auto Setup") {
                    if showAutoSetupControls == false {
                        showAutoSetupControls = true
                        return
                    }
                    runAutoSetup()
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.blue)

                Button("Continue Without Setup", action: onContinue)
                    .buttonStyle(.bordered)
                    .tint(AppTheme.blue)
            }
        }
        .padding(16)
        .appCard()
    }

    private func runAutoSetup() {
        let commands = setupCommandText(installOllama: installOllama)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(commands, forType: .string)

        let script = "tell application \"Terminal\"\nactivate\ndo script \"clear; echo 'ResumeForge auto setup'; echo ''; pbpaste; echo ''; echo 'Commands copied to clipboard.'\"\nend tell"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus != 0 {
                onContinue()
            }
        } catch {
            onContinue()
        }
    }

    private func setupCommandText(installOllama: Bool) -> String {
        let ollamaBlock = installOllama ? "brew install --cask ollama\nollama serve\nollama pull \(ollamaModel)\nollama run \(ollamaModel)" : "ollama serve\nollama pull \(ollamaModel)\nollama run \(ollamaModel)"
        return """
        brew install python
        python3 -m venv .venv
        ./.venv/bin/python -m pip install --upgrade pip docling-parse
        \(ollamaBlock)
        """
    }

    private var footer: some View {
        Text("You can change providers later in Settings. This guide only appears the first time you open the app.")
            .font(AppTheme.caption)
            .foregroundStyle(AppTheme.textSecondary)
            .padding(.horizontal, 4)
    }
}

private struct CodeBlock: View {
    let code: String

    var body: some View {
        Text(code)
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(AppTheme.text)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 10))
    }
}