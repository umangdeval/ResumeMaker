import SwiftUI
import SwiftData

@main
struct ResumeForgeApp: App {
    let modelContainer: ModelContainer
    @State private var pythonStatus: PythonEnvironmentStatus = .ready

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

        // Configure PythonKit to find the correct interpreter at startup.
        // Failure here just means Docling won't be available; PDFKit fallback still works.
        try? PythonEnvironmentService.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootTabView(pythonStatus: pythonStatus)
                .environment(Router())
                .task { pythonStatus = PythonEnvironmentService.checkDocling() }
        }
        .modelContainer(modelContainer)
        .defaultSize(width: 1100, height: 720)
    }
}
