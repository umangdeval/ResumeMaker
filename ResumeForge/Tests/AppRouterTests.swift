import Testing
@testable import ResumeForge

@Suite("AppRouter")
@MainActor
struct AppRouterTests {
    @Test("push appends destination")
    func pushAppendsDestination() {
        let router = AppRouter()
        router.push(.profile)
        #expect(router.path == [.profile])
    }

    @Test("pop removes last destination")
    func popRemovesLast() {
        let router = AppRouter()
        router.push(.profile)
        router.push(.settings)
        router.pop()
        #expect(router.path == [.profile])
    }

    @Test("pop on empty path is a no-op")
    func popOnEmpty() {
        let router = AppRouter()
        router.pop()
        #expect(router.path.isEmpty)
    }

    @Test("popToRoot clears all destinations")
    func popToRoot() {
        let router = AppRouter()
        router.push(.profile)
        router.push(.settings)
        router.popToRoot()
        #expect(router.path.isEmpty)
    }
}
