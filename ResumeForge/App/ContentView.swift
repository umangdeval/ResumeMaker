import SwiftUI

struct ContentView: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var router = router
        NavigationStack(path: $router.path) {
            DashboardView()
                .navigationDestination(for: AppDestination.self) { destination in
                    destinationView(for: destination)
                }
        }
    }

    @ViewBuilder
    private func destinationView(for destination: AppDestination) -> some View {
        switch destination {
        case .profile:
            Text("Profile — coming soon")
        case .resumeParser:
            Text("Resume Parser — coming soon")
        case .jobDescription:
            Text("Job Description — coming soon")
        case .aiCouncil:
            Text("AI Council — coming soon")
        case .resumeBuilder:
            Text("Resume Builder — coming soon")
        case .coverLetter:
            Text("Cover Letter — coming soon")
        case .export:
            Text("Export — coming soon")
        case .settings:
            Text("Settings — coming soon")
        }
    }
}

// MARK: - Dashboard (temporary scaffold)

private struct DashboardView: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        List {
            dashboardRow(title: "My Profile", subtitle: "Manage your base resume info", destination: .profile)
            dashboardRow(title: "Parse Resume", subtitle: "Import PDF or LaTeX resume", destination: .resumeParser)
            dashboardRow(title: "Job Description", subtitle: "Add a job to target", destination: .jobDescription)
            dashboardRow(title: "Settings", subtitle: "API keys and preferences", destination: .settings)
        }
        .navigationTitle("ResumeForge")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
    }

    private func dashboardRow(title: String, subtitle: String, destination: AppDestination) -> some View {
        Button {
            router.push(destination)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}
