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

            ProfileTab()
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }

            DocumentsTab()
                .tabItem { Label("Documents", systemImage: "doc.text") }

            SettingsTab(pythonStatus: pythonStatus)
                .tabItem { Label("Settings", systemImage: "gear") }
        }
        .tint(AppTheme.blue)
    }
}

// MARK: - Dashboard tab

private struct DashboardTab: View {
    @Query(sort: \GeneratedResume.createdAt, order: .reverse) private var resumes: [GeneratedResume]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    welcomeSection
                    if !resumes.isEmpty {
                        recentSection
                    }
                }
                .padding(20)
            }
            .appScreenBackground()
            .navigationTitle("ResumeForge")
        }
    }

    private var welcomeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Welcome to ResumeForge")
                .font(AppTheme.heroTitle)
                .foregroundStyle(.white)
            Text("Parse your resume, describe a job, and let your AI Council tailor the perfect application.")
                .font(AppTheme.body)
                .foregroundStyle(.white.opacity(0.86))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background(Color.black, in: RoundedRectangle(cornerRadius: 14))
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent Resumes")
                .font(AppTheme.sectionTitle)
                .foregroundStyle(AppTheme.text)
            ForEach(resumes) { resume in
                VStack(alignment: .leading, spacing: 4) {
                    Text(resume.displayTitle)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(AppTheme.text)
                    Text(resume.createdAt.formatted(date: .abbreviated, time: .omitted))
                        .font(AppTheme.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .padding(.vertical, 3)
            }
        }
        .padding(18)
        .appCard()
    }
}

// MARK: - Create tab

private struct ProfileTab: View {
    var body: some View {
        ProfileView()
    }
}

private struct CreateTab: View {
    var body: some View {
        NavigationStack {
            CreateWorkflowView()
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

    var body: some View {
        SettingsView(pythonStatus: pythonStatus)
    }
}

// MARK: - Shared placeholder

private struct PlaceholderTabView: View {
    let title: String
    let icon: String
    let description: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 44))
                .foregroundStyle(.white)
            Text(title)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.white)
            Text(description)
                .font(AppTheme.body)
                .foregroundStyle(.white.opacity(0.82))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 560)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .appScreenBackground()
    }
}
