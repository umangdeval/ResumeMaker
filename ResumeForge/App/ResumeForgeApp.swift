import SwiftUI
import SwiftData

@main
struct ResumeForgeApp: App {
    let modelContainer: ModelContainer
    @State private var backendStatus: BackendStatus = .unreachable

    init() {
        do {
            modelContainer = try ModelContainer(
                for: UserProfile.self,
                     Experience.self,
                     Education.self,
                     GeneratedResume.self,
                     CoverLetter.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: false)
            )
        } catch {
            fatalError("Failed to initialize ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootTabView(backendStatus: backendStatus)
                .environment(Router())
                .task { backendStatus = await BackendService.checkHealth() }
        }
        .modelContainer(modelContainer)
        .defaultSize(width: 1100, height: 720)
    }
}
