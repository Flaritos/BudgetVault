import Foundation
import Security

/// Lightweight Keychain wrapper for storing premium status as the authoritative
/// source of truth (resistant to backup-restore and UserDefaults manipulation).
enum KeychainService {
    private static let service = "io.budgetvault.app"

    /// Store a Bool value in the Keychain under the given key.
    ///
    /// Audit fix: explicitly set `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`
    /// so the premium flag survives device reboots but never syncs via
    /// iCloud Keychain backups (which would entitle premium on a
    /// restored device without a matching StoreKit transaction).
    @discardableResult
    static func set(_ value: Bool, forKey key: String) -> OSStatus {
        let data = Data([value ? 1 : 0])
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        // Delete any existing item first, then insert.
        SecItemDelete(query as CFDictionary)
        return SecItemAdd(query as CFDictionary, nil)
    }

    /// Retrieve a Bool value from the Keychain, or nil if not found.
    static func getBool(forKey key: String) -> Bool? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data, !data.isEmpty else {
            return nil
        }
        return data[0] == 1
    }

    /// Delete a value from the Keychain.
    static func delete(forKey key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}
