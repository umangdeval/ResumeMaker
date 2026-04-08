import SwiftUI
import SwiftData

@main
struct ResumeForgeApp: App {
    let modelContainer: ModelContainer

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
            RootTabView()
                .environment(Router())
        }
        .modelContainer(modelContainer)
        #if os(macOS)
        .defaultSize(width: 1100, height: 720)
        #endif
    }
}
