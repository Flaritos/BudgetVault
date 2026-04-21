import Foundation
import BudgetVaultShared

/// Syncs key user settings across devices via NSUbiquitousKeyValueStore (iCloud KVS).
/// Listens for external changes and writes local changes on mutation.
enum SettingsSyncService {

    private static let kvStore = NSUbiquitousKeyValueStore.default

    // Keys mirrored to iCloud KVS
    private static let syncedKeys: [String] = [
        AppStorageKeys.selectedCurrency,
        AppStorageKeys.resetDay,
        AppStorageKeys.accentColorHex,
    ]

    /// Audit fix: KVS used to run unconditionally, even when the user
    /// had iCloud sync toggled OFF — contradicting the privacy label.
    /// Now all writes/observers are gated on the AppStorage toggle. The
    /// three synced keys are low-sensitivity preferences (currency,
    /// reset day, accent color) but respecting the toggle is the
    /// correct privacy posture.
    private static var iCloudSyncEnabled: Bool {
        UserDefaults.standard.bool(forKey: AppStorageKeys.iCloudSyncEnabled)
    }

    /// Call once on app launch to start observing remote changes and push initial values.
    static func configure() {
        guard iCloudSyncEnabled else { return }

        NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: kvStore,
            queue: .main
        ) { notification in
            handleExternalChange(notification)
        }

        // Trigger an initial sync pull
        kvStore.synchronize()

        // Push current local values if KVS is empty (first launch on new device)
        pushLocalSettingsIfNeeded()
    }

    /// Write a setting to both UserDefaults and iCloud KVS.
    static func set(_ value: Any?, forKey key: String) {
        UserDefaults.standard.set(value, forKey: key)
        if iCloudSyncEnabled && syncedKeys.contains(key) {
            kvStore.set(value, forKey: key)
        }
    }

    /// Push all synced settings from UserDefaults to KVS (used after local changes).
    static func pushAllSettings() {
        guard iCloudSyncEnabled else { return }
        for key in syncedKeys {
            if let value = UserDefaults.standard.object(forKey: key) {
                kvStore.set(value, forKey: key)
            }
        }
    }

    // MARK: - Private

    private static func pushLocalSettingsIfNeeded() {
        for key in syncedKeys {
            if kvStore.object(forKey: key) == nil,
               let localValue = UserDefaults.standard.object(forKey: key) {
                kvStore.set(localValue, forKey: key)
            }
        }
    }

    private static func handleExternalChange(_ notification: Notification) {
        guard let changedKeys = notification.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] else {
            return
        }

        for key in changedKeys where syncedKeys.contains(key) {
            if let remoteValue = kvStore.object(forKey: key) {
                UserDefaults.standard.set(remoteValue, forKey: key)
            }
        }
    }
}
