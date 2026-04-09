import SwiftUI
import SwiftData

// MARK: - Root tab container

struct RootTabView: View {
    let pythonStatus: PythonEnvironmentStatus

    var body: some View {
        TabView {
            DashboardTab()
                .tabItem { Label("Dashboard", systemImage: "house") }

            CreateTab()
                .tabItem { Label("Create", systemImage: "plus.circle") }

            DocumentsTab()
                .tabItem { Label("Documents", systemImage: "doc.text") }

            SettingsTab(pythonStatus: pythonStatus)
                .tabItem { Label("Settings", systemImage: "gear") }
        }
    }
}

// MARK: - Dashboard tab

private struct DashboardTab: View {
    @Query(sort: \GeneratedResume.createdAt, order: .reverse) private var resumes: [GeneratedResume]

    var body: some View {
        NavigationStack {
            List {
                welcomeSection
                if !resumes.isEmpty {
                    recentSection
                }
            }
            .navigationTitle("ResumeForge")
        }
    }

    private var welcomeSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("Welcome to ResumeForge")
                    .font(.headline)
                Text("Parse your resume, describe a job, and let your AI Council tailor the perfect application.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
    }

    private var recentSection: some View {
        Section("Recent Resumes") {
            ForEach(resumes) { resume in
                VStack(alignment: .leading, spacing: 4) {
                    Text(resume.displayTitle).font(.headline)
                    Text(resume.createdAt.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
            }
        }
    }
}

// MARK: - Create tab

private struct CreateTab: View {
    var body: some View {
        NavigationStack {
            ResumeParserView()
        }
    }
}

// MARK: - Documents tab

private struct DocumentsTab: View {
    var body: some View {
        NavigationStack {
            PlaceholderTabView(title: "Documents", icon: "doc.text", description: "Saved resumes and cover letters — coming soon.")
                .navigationTitle("Documents")
        }
    }
}

// MARK: - Settings tab

private struct SettingsTab: View {
    let pythonStatus: PythonEnvironmentStatus
    @State private var currentStatus: PythonEnvironmentStatus = .ready

    var body: some View {
        NavigationStack {
            Form {
                if currentStatus != .ready {
                    Section("Python / Docling Setup") {
                        PythonSetupView(status: currentStatus) {
                            currentStatus = PythonEnvironmentService.checkDocling()
                        }
                    }
                } else {
                    Section("Python / Docling") {
                        Label("docling-parse is installed and ready.", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
                Section("API Keys") {
                    Text("API key management — coming soon.")
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Settings")
            .onAppear { currentStatus = pythonStatus }
        }
    }
}

// MARK: - Shared placeholder

private struct PlaceholderTabView: View {
    let title: String
    let icon: String
    let description: String

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: icon)
        } description: {
            Text(description)
        }
    }
}
