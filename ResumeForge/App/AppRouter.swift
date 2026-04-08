import SwiftUI

/// Top-level navigation destinations for the app.
enum AppDestination: Hashable {
    case profile
    case resumeParser
    case jobDescription
    case aiCouncil(resumeID: String, jobDescriptionID: String)
    case resumeBuilder(resumeID: String)
    case coverLetter(coverLetterID: String)
    case export(resumeID: String)
    case settings
}

/// Shared router injected via @Environment. Drives NavigationStack from the root.
@Observable
@MainActor
final class AppRouter {
    var path: [AppDestination] = []

    func push(_ destination: AppDestination) {
        path.append(destination)
    }

    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    func popToRoot() {
        path.removeAll()
    }
}
