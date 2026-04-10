import SwiftUI

/// Shown in Settings when the backend server is not reachable or degraded.
struct BackendSetupView: View {
    let status: BackendStatus
    var onRetry: (() -> Void)?

    var body: some View {
        VStack(spacing: 24) {
            icon
            titleText
            instructionsList
            copyButton
            if let onRetry {
                Button("Retry Connection", action: onRetry)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(32)
        .frame(maxWidth: 540)
    }

    // MARK: - Subviews

    private var icon: some View {
        Image(systemName: statusIcon)
            .font(.system(size: 52))
            .foregroundStyle(statusColor)
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
            SetupStepView(number: "1", text: "Open **Terminal** and navigate to the project's `backend/` folder:")
            CodeBlockView(code: "cd /path/to/ResumeMaker/backend")

            SetupStepView(number: "2", text: "Create a virtual environment and install dependencies:")
            CodeBlockView(code: "python3 -m venv .venv && source .venv/bin/activate\npip install -r requirements.txt")

            SetupStepView(number: "3", text: "*(Optional)* Install docling for better PDF quality:")
            CodeBlockView(code: "pip install docling")

            SetupStepView(number: "4", text: "Start the backend server:")
            CodeBlockView(code: "python app.py")

            SetupStepView(number: "5", text: "The server runs on **http://127.0.0.1:8765**. Click **Retry Connection** above.")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
    }

    private var copyButton: some View {
        Button {
            let cmd = """
            cd backend
            python3 -m venv .venv && source .venv/bin/activate
            pip install -r requirements.txt
            python app.py
            """
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(cmd, forType: .string)
        } label: {
            Label("Copy setup commands", systemImage: "doc.on.doc")
        }
        .buttonStyle(.bordered)
    }

    // MARK: - Computed helpers

    private var statusIcon: String {
        switch status {
        case .unreachable: return "network.slash"
        case .degraded:    return "exclamationmark.triangle"
        case .connected:   return "checkmark.circle.fill"
        }
    }

    private var statusColor: Color {
        switch status {
        case .unreachable: return .red
        case .degraded:    return .orange
        case .connected:   return .green
        }
    }

    private var title: String {
        switch status {
        case .unreachable: return "Backend Not Running"
        case .degraded:    return "Backend Degraded"
        case .connected:   return "Backend Connected"
        }
    }

    private var subtitle: String {
        switch status {
        case .unreachable:
            return "The local Python server is not running. Follow the steps below to start it."
        case .degraded(let message):
            return message
        case .connected(let parsers):
            return "Connected. Available parsers: \(parsers.joined(separator: ", "))."
        }
    }
}

// MARK: - Helpers

private struct SetupStepView: View {
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

private struct CodeBlockView: View {
    let code: String

    var body: some View {
        Text(code)
            .font(.system(.caption, design: .monospaced))
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(NSColor.textBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
    }
}
