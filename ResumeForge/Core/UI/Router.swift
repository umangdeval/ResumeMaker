import SwiftUI

// MARK: - Route destinations

enum Route: Hashable {
    case profile
    case parseResume
    case jobDescription
    case aiCouncil
    case resumeBuilder
    case coverLetter
    case export
    case settings
}

// MARK: - Router

@Observable
@MainActor
final class Router {
    var path = NavigationPath()

    func push(_ route: Route) {
        path.append(route)
    }

    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    func popToRoot() {
        path.removeLast(path.count)
    }
}
