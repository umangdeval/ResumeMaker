import SwiftUI
import SwiftData

// MARK: - Root tab container

struct RootTabView: View {
    let backendStatus: BackendStatus

    var body: some View {
        TabView {
            DashboardTab()
                .tabItem { Label("Dashboard", systemImage: "house") }

            CreateTab()
                .tabItem { Label("Create", systemImage: "plus.circle") }

            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }

            DocumentsTab()
                .tabItem { Label("Documents", systemImage: "doc.text") }

            SettingsTab(backendStatus: backendStatus)
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
    let backendStatus: BackendStatus
    @State private var currentStatus: BackendStatus = .unreachable
    @State private var backendURL: String = UserDefaults.standard.string(forKey: "backendURL") ?? ""

    var body: some View {
        NavigationStack {
            Form {
                backendSection
                Section("API Keys") {
                    Text("API key management — coming soon.")
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Settings")
            .onAppear { currentStatus = backendStatus }
        }
    }

    private var backendSection: some View {
        Section("Backend Server") {
            BackendSetupView(status: currentStatus) {
                Task { currentStatus = await BackendService.checkHealth() }
            }
            LabeledContent("Server URL") {
                TextField("http://127.0.0.1:8765", text: $backendURL)
                    .onSubmit {
                        UserDefaults.standard.set(backendURL, forKey: "backendURL")
                        Task { currentStatus = await BackendService.checkHealth() }
                    }
            }
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
