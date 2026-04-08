import Testing
@testable import ResumeForge

@Suite("Router")
@MainActor
struct RouterTests {
    @Test("push appends a route")
    func pushAppends() {
        let router = Router()
        router.push(.profile)
        #expect(!router.path.isEmpty)
    }

    @Test("pop on empty path is a no-op")
    func popOnEmpty() {
        let router = Router()
        router.pop()
        #expect(router.path.isEmpty)
    }

    @Test("popToRoot clears all routes")
    func popToRoot() {
        let router = Router()
        router.push(.profile)
        router.push(.settings)
        router.popToRoot()
        #expect(router.path.isEmpty)
    }
}
