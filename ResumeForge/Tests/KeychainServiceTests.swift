import Testing
@testable import ResumeForge

@Suite("KeychainService")
struct KeychainServiceTests {
    // Use a test-specific key so production data is never touched.
    private let testKey = KeychainKey.openAIAPIKey

    @Test("save and load roundtrip")
    func saveAndLoad() throws {
        try KeychainService.save(key: testKey, value: "test-api-key-123")
        let loaded = try KeychainService.load(key: testKey)
        #expect(loaded == "test-api-key-123")
        KeychainService.delete(key: testKey)
    }

    @Test("load throws notFound when key absent")
    func loadMissing() {
        KeychainService.delete(key: testKey)
        #expect(throws: KeychainError.notFound) {
            try KeychainService.load(key: testKey)
        }
    }

    @Test("overwrite replaces existing value")
    func overwrite() throws {
        try KeychainService.save(key: testKey, value: "first")
        try KeychainService.save(key: testKey, value: "second")
        let loaded = try KeychainService.load(key: testKey)
        #expect(loaded == "second")
        KeychainService.delete(key: testKey)
    }
}
