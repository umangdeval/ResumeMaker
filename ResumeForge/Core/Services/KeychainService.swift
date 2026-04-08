import Foundation
import Security

/// Thread-safe Keychain wrapper for storing and retrieving API keys.
/// All methods are non-throwing; failures surface as `KeychainError`.
enum KeychainService {
    // MARK: - Public API

    static func save(key: KeychainKey, value: String) throws(KeychainError) {
        guard let data = value.data(using: .utf8) else {
            throw .encodingFailed
        }
        // Delete any existing item first to avoid duplicate-item errors.
        delete(key: key)

        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key.rawValue,
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw .underlyingError(status)
        }
    }

    static func load(key: KeychainKey) throws(KeychainError) -> String {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key.rawValue,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            throw .notFound
        }
        return value
    }

    @discardableResult
    static func delete(key: KeychainKey) -> Bool {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key.rawValue
        ]
        return SecItemDelete(query as CFDictionary) == errSecSuccess
    }
}

// MARK: - Supporting types

enum KeychainKey: String {
    case openAIAPIKey  = "com.resumeforge.apikey.openai"
    case anthropicAPIKey = "com.resumeforge.apikey.anthropic"
    case geminiAPIKey  = "com.resumeforge.apikey.gemini"
}

enum KeychainError: Error, LocalizedError {
    case encodingFailed
    case notFound
    case underlyingError(OSStatus)

    var errorDescription: String? {
        switch self {
        case .encodingFailed:       return "Failed to encode value for Keychain."
        case .notFound:             return "No value found in Keychain for this key."
        case .underlyingError(let status): return "Keychain error (OSStatus \(status))."
        }
    }
}
