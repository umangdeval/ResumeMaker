import SwiftUI
import SwiftData

@main
struct ResumeForgeApp: App {
    let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try ModelContainer(
                for: Resume.self, UserProfile.self, JobDescriptionEntry.self, CoverLetter.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: false)
            )
        } catch {
            fatalError("Failed to initialize ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(AppRouter())
        }
        .modelContainer(modelContainer)
        #if os(macOS)
        .defaultSize(width: 1100, height: 720)
        #endif
    }
}
