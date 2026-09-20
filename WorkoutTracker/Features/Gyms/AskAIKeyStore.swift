import Foundation
import Security

/// The developer's API key, in the keychain (this device only, available
/// after first unlock — a gym scan happens with the phone unlocked). Under
/// `-uiTestReset` an in-memory slot stands in, so no UI test ever touches
/// the Simulator's keychain; the Ask AI fixture pre-fills it.
enum AskAIKeyStore {
    private static let service = (Bundle.main.bundleIdentifier ?? "workouttracker") + ".askai"
    private static let account = "openai-api-key"
    private static var memory: String? = (AskAI.fixtureIsEnabled || TerraAccess.fixture) ? "uitest-key" : nil

    static func read() -> String? {
        if WorkoutTrackerStore.isUITestReset { return memory }
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let key = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !key.isEmpty
        else { return nil }
        return key
    }

    /// Replaces whatever is stored. An empty key deletes.
    static func write(_ key: String) throws {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { delete(); return }
        if WorkoutTrackerStore.isUITestReset { memory = trimmed; return }
        delete()
        var attributes = baseQuery
        attributes[kSecValueData as String] = Data(trimmed.utf8)
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError(status: status) }
    }

    static func delete() {
        if WorkoutTrackerStore.isUITestReset { memory = nil; return }
        SecItemDelete(baseQuery as CFDictionary)
    }

    private static var baseQuery: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }

    struct KeychainError: Error, LocalizedError {
        let status: OSStatus
        var errorDescription: String? {
            "Could not save the key to the keychain (\(status))."
        }
    }
}
