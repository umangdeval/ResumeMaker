import SwiftUI
import SwiftData

// MARK: - Sidebar items

enum SidebarItem: String, Hashable, CaseIterable, Identifiable {
    case dashboard   = "Dashboard"
    case profile     = "Profile"
    case create      = "Create"
    case documents   = "Documents"
    case settings    = "Settings"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .dashboard:  return "house"
        case .profile:    return "person.crop.circle"
        case .create:     return "wand.and.sparkles"
        case .documents:  return "doc.text"
        case .settings:   return "gear"
        }
    }
}

// MARK: - Root view

struct RootTabView: View {
    let pythonStatus: PythonEnvironmentStatus
    @AppStorage("didShowStartupGuide") private var didShowStartupGuide = false
    @State private var isShowingStartupGuide = false
    @State private var selection: SidebarItem? = .dashboard

    var body: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            sidebar
        } detail: {
            detailView
        }
        .task {
            if !didShowStartupGuide {
                isShowingStartupGuide = true
            }
        }
        .sheet(isPresented: $isShowingStartupGuide, onDismiss: { didShowStartupGuide = true }) {
            StartupGuideView(
                pythonStatus: pythonStatus,
                ollamaModel: AIProviderConfig.makeDefault(kind: .ollama).model
            ) { isShowingStartupGuide = false }
        }
    }

    private var sidebar: some View {
        List(SidebarItem.allCases, selection: $selection) { item in
            Label(item.rawValue, systemImage: item.icon)
        }
        .listStyle(.sidebar)
        .navigationTitle("ResumeForge")
        .navigationSplitViewColumnWidth(min: 180, ideal: 200)
    }

    @ViewBuilder
    private var detailView: some View {
        switch selection ?? .dashboard {
        case .dashboard:  DashboardView()
        case .profile:    ProfileView()
        case .create:     NavigationStack { CreateWorkflowView() }
        case .documents:  DocumentsView()
        case .settings:   SettingsView(pythonStatus: pythonStatus)
        }
    }
}

// MARK: - Dashboard

private struct DashboardView: View {
    @Query(sort: \GeneratedResume.createdAt, order: .reverse) private var resumes: [GeneratedResume]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                welcomeHeader
                if !resumes.isEmpty {
                    recentResumes
                }
                quickActions
            }
            .padding(24)
            .appContentWidth()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(AppTheme.bg)
        .navigationTitle("Dashboard")
    }

    private var welcomeHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Welcome to ResumeForge")
                .font(AppTheme.heroTitle)
                .foregroundStyle(AppTheme.text)
            Text("Parse your resume, describe a job, and let your AI Council tailor the perfect application.")
                .font(AppTheme.body)
                .foregroundStyle(AppTheme.textSecondary)
        }
    }

    private var recentResumes: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent Resumes")
                .font(AppTheme.sectionTitle)
                .foregroundStyle(AppTheme.text)
            ForEach(resumes.prefix(5)) { resume in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(resume.displayTitle)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AppTheme.text)
                        Text(resume.createdAt.formatted(date: .abbreviated, time: .omitted))
                            .font(AppTheme.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .appCard()
            }
        }
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quick Actions")
                .font(AppTheme.sectionTitle)
                .foregroundStyle(AppTheme.text)
            HStack(spacing: 10) {
                quickAction(label: "Import Resume", icon: "doc.text.viewfinder", color: AppTheme.blue)
                quickAction(label: "New Job", icon: "doc.plaintext", color: .purple)
                quickAction(label: "AI Council", icon: "person.3.sequence", color: .teal)
            }
        }
    }

    private func quickAction(label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundStyle(color)
            Text(label)
                .font(AppTheme.caption)
                .foregroundStyle(AppTheme.text)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .appCard()
    }
}

// MARK: - Documents

private struct DocumentsView: View {
    var body: some View {
        ContentUnavailableView(
            "No Documents Yet",
            systemImage: "doc.text",
            description: Text("Saved resumes and cover letters will appear here.")
        )
        .navigationTitle("Documents")
    }
}
