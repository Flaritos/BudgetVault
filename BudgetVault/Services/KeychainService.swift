import Foundation
import Security

/// Lightweight Keychain wrapper for storing premium status as the authoritative
/// source of truth (resistant to backup-restore and UserDefaults manipulation).
///
/// Audit 2026-04-22 P2-6 — threat model notes:
///   1. **Storage size.** Value is a single byte (0 or 1). Keychain is
///      not used as a user secret here; it's a tamper-resistant flag.
///      A malicious process can't flip the bit without the passcode
///      (attacker would need `kSecAttrAccessibleAfterFirstUnlock...`
///      unlock context + the service/account key), but a user who
///      jailbreaks can — that's outside our threat model.
///   2. **No biometry ACL.** We deliberately don't set
///      `kSecAccessControl` with `.biometryCurrentSet` because the
///      premium flag must be readable during app launch BEFORE the
///      biometric lock screen appears, to render the Paywall in its
///      "Already Premium" state. A biometry ACL would cause a visible
///      Face ID prompt during cold start (bad UX) OR — more commonly —
///      would silently fail during app refresh when there's no UI to
///      present a prompt.
///   3. **Why not UserDefaults alone.** UserDefaults can be edited
///      via `defaults write` from a debugger or a restored backup.
///      Keychain is NOT included in non-encrypted iTunes backups, so
///      restoring to a new device correctly prompts for a StoreKit
///      Restore Purchases instead of inheriting premium for free.
///   4. **Accessibility class.** `AfterFirstUnlockThisDeviceOnly` is
///      the correct class for "survives reboot, doesn't sync via
///      iCloud Keychain, accessible to background refresh." Do not
///      downgrade to `WhenUnlocked` (breaks BG refresh) or upgrade
///      to `AfterFirstUnlock` without `ThisDeviceOnly` (entitles
///      premium on a restored device).
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
        // Audit 2026-04-23 Security P2: prior `SecItemDelete` + `SecItemAdd`
        // sequence is NON-atomic. A crash or kill between the two calls
        // leaves NO Keychain entry — StoreKitManager.checkEntitlements
        // would then read nil and (combined with our M3+S1 fix) preserve
        // cached state, which is OK but suboptimal. Prefer an atomic
        // SecItemUpdate when the item already exists; fall back to
        // SecItemAdd only when SecItemUpdate returns errSecItemNotFound.
        let lookup: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        let attributesToUpdate: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let updateStatus = SecItemUpdate(lookup as CFDictionary, attributesToUpdate as CFDictionary)
        if updateStatus == errSecSuccess {
            return errSecSuccess
        }
        if updateStatus == errSecItemNotFound {
            // First write — no prior item; add one.
            var addQuery = lookup
            addQuery[kSecValueData as String] = data
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            return SecItemAdd(addQuery as CFDictionary, nil)
        }
        // Other failures (e.g. errSecInteractionNotAllowed) — propagate.
        return updateStatus
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
