import SwiftUI

/// Shown when docling-parse is not installed or Python is not found.
struct PythonSetupView: View {
    let status: PythonEnvironmentStatus
    var onDismiss: (() -> Void)?

    var body: some View {
        VStack(spacing: 24) {
            icon
            titleText
            instructionsList
            copyButton
            if let onDismiss {
                Button("I've installed it — retry", action: onDismiss)
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.blue)
            }
        }
        .padding(32)
        .frame(maxWidth: 520)
        .appCard()
    }

    // MARK: - Subviews

    private var icon: some View {
        Image(systemName: "puzzlepiece.extension")
            .font(.system(size: 52))
            .foregroundStyle(AppTheme.blue)
    }

    private var titleText: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(AppTheme.sectionTitle)
                .foregroundStyle(AppTheme.text)
            Text(subtitle)
                .font(AppTheme.body)
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    private var instructionsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            if case .pythonNotFound = status {
                SetupStep(number: "1", text: "Install Python 3 from **python.org** or via Homebrew:")
                CodeBlock(code: "brew install python")
                SetupStep(number: "2", text: "From the ResumeForge project folder, create a local virtual environment:")
                CodeBlock(code: "python3 -m venv .venv")
                SetupStep(number: "3", text: "Install docling-parse in that environment:")
                CodeBlock(code: "./.venv/bin/python -m pip install --upgrade pip docling-parse")
            } else {
                SetupStep(number: "1", text: "Open Terminal and run:")
                CodeBlock(code: "./.venv/bin/python -m pip install --upgrade pip docling-parse")
                SetupStep(number: "2", text: "Restart ResumeForge after installation.")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(AppTheme.surface.opacity(0.85), in: RoundedRectangle(cornerRadius: 10))
    }

    private var copyButton: some View {
        Button {
            let cmd = (status == .pythonNotFound)
                ? "brew install python && python3 -m venv .venv && ./.venv/bin/python -m pip install --upgrade pip docling-parse"
                : "./.venv/bin/python -m pip install --upgrade pip docling-parse"
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(cmd, forType: .string)
        } label: {
            Label("Copy install command", systemImage: "doc.on.doc")
        }
        .buttonStyle(.bordered)
        .tint(AppTheme.blue)
    }

    // MARK: - Computed text

    private var title: String {
        switch status {
        case .pythonNotFound:    return "Python 3 not found"
        case .doclingNotInstalled: return "docling-parse not installed"
        default:                 return "Python setup required"
        }
    }

    private var subtitle: String {
        switch status {
        case .pythonNotFound:
            return "ResumeForge uses docling-parse for high-quality PDF text extraction, which requires Python 3."
        case .doclingNotInstalled:
            return "Python was found but docling-parse is not installed. One command will fix this."
        default:
            return "A Python dependency is required for PDF parsing."
        }
    }
}

// MARK: - Helpers

private struct SetupStep: View {
    let number: String
    let text: LocalizedStringKey

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(number)
                .font(.headline)
                .foregroundStyle(AppTheme.textSecondary)
                .frame(width: 20)
            Text(text)
                .font(AppTheme.body)
                .foregroundStyle(AppTheme.text)
        }
    }
}

private struct CodeBlock: View {
    let code: String

    var body: some View {
        Text(code)
            .font(.system(.caption, design: .monospaced))
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white, in: RoundedRectangle(cornerRadius: 6))
            .foregroundStyle(AppTheme.text)
    }
}

// MARK: - Make PythonEnvironmentStatus Equatable for the copy button switch

extension PythonEnvironmentStatus: Equatable {
    static func == (lhs: PythonEnvironmentStatus, rhs: PythonEnvironmentStatus) -> Bool {
        switch (lhs, rhs) {
        case (.ready, .ready),
             (.pythonNotFound, .pythonNotFound),
             (.doclingNotInstalled, .doclingNotInstalled): return true
        case (.error(let a), .error(let b)): return a == b
        default: return false
        }
    }
}
