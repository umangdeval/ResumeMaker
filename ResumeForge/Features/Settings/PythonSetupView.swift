import SwiftUI

/// Shown when docling is not installed or Python is not found.
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
            }
        }
        .padding(32)
        .frame(maxWidth: 520)
    }

    // MARK: - Subviews

    private var icon: some View {
        Image(systemName: "puzzlepiece.extension")
            .font(.system(size: 52))
            .foregroundStyle(.orange)
    }

    private var titleText: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.title2.bold())
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var instructionsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            if case .pythonNotFound = status {
                SetupStep(number: "1", text: "Install Python 3 from **python.org** or via Homebrew:")
                CodeBlock(code: "brew install python")
                SetupStep(number: "2", text: "Install docling:")
                CodeBlock(code: "pip install docling")
            } else {
                SetupStep(number: "1", text: "Open Terminal and run:")
                CodeBlock(code: "pip install docling")
                SetupStep(number: "2", text: "Restart ResumeForge after installation.")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
    }

    private var copyButton: some View {
        Button {
            let cmd = (status == .pythonNotFound)
                ? "brew install python && pip install docling"
                : "pip install docling"
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(cmd, forType: .string)
        } label: {
            Label("Copy install command", systemImage: "doc.on.doc")
        }
        .buttonStyle(.bordered)
    }

    // MARK: - Computed text

    private var title: String {
        switch status {
        case .pythonNotFound:    return "Python 3 not found"
        case .doclingNotInstalled: return "docling not installed"
        default:                 return "Python setup required"
        }
    }

    private var subtitle: String {
        switch status {
        case .pythonNotFound:
            return "ResumeForge uses docling for high-quality PDF text extraction, which requires Python 3."
        case .doclingNotInstalled:
            return "Python was found but docling is not installed. One command will fix this."
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
                .foregroundStyle(.secondary)
                .frame(width: 20)
            Text(text)
                .font(.subheadline)
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
            .background(Color(NSColor.textBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
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
