import Foundation
import os
import BudgetVaultShared

private let syncLog = Logger(subsystem: "io.budgetvault.app", category: "settings-sync")

/// Syncs key user settings across devices via NSUbiquitousKeyValueStore (iCloud KVS).
/// Listens for external changes and writes local changes on mutation.
enum SettingsSyncService {

    private static let kvStore = NSUbiquitousKeyValueStore.default

    // Keys mirrored to iCloud KVS
    // Audit 2026-04-23 Max Audit P1-12: add notification preference
    // toggles so the user's "on/off" choices follow them across
    // devices — inconsistent before now (billDueReminders /
    // closeVaultReminderEnabled / dailyReminderEnabled /
    // weeklyDigestEnabled / morningBriefingEnabled were device-local).
    private static let syncedKeys: [String] = [
        AppStorageKeys.selectedCurrency,
        AppStorageKeys.resetDay,
        AppStorageKeys.dailyReminderEnabled,
        AppStorageKeys.dailyReminderHour,
        AppStorageKeys.weeklyDigestEnabled,
        AppStorageKeys.billDueReminders,
        AppStorageKeys.closeVaultReminderEnabled,
        AppStorageKeys.morningBriefingEnabled,
        AppStorageKeys.morningBriefingHour,
    ]

    // Audit 2026-04-22 P1-18: retain the observer handle so we can
    // actually remove it when the user toggles iCloud off. Previously
    // the observer stayed registered forever, letting remote writes
    // continue flowing into UserDefaults via handleExternalChange even
    // though the toggle claimed sync was disabled.
    private static var externalChangeObserver: NSObjectProtocol?

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

        // Audit 2026-04-22 P1-18: guard against double-registration if
        // configure() is called a second time (e.g., user toggles off
        // then on again within one session).
        if externalChangeObserver == nil {
            externalChangeObserver = NotificationCenter.default.addObserver(
                forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
                object: kvStore,
                queue: .main
            ) { notification in
                handleExternalChange(notification)
            }
        }

        // Trigger an initial sync pull
        kvStore.synchronize()

        // Push current local values if KVS is empty (first launch on new device)
        pushLocalSettingsIfNeeded()
    }

    /// Audit 2026-04-22 P1-18: tear down the observer when the user
    /// disables iCloud sync. Without this, remote writes from other
    /// devices continue to overwrite local UserDefaults via
    /// handleExternalChange — contradicting the privacy toggle.
    static func teardown() {
        if let observer = externalChangeObserver {
            NotificationCenter.default.removeObserver(observer)
            externalChangeObserver = nil
        }
    }

    /// Write a setting to both UserDefaults and iCloud KVS.
    /// Audit 2026-04-23 Max Audit P1-21: validate outbound values too.
    /// Prior code trusted the local UserDefaults; a corrupted local
    /// value (from a prior bug / crash) would silently propagate
    /// garbage to other devices, which would then REJECT via the
    /// inbound validator — a confusing "sync broke with no signal"
    /// story. Fail silently but log.
    static func set(_ value: Any?, forKey key: String) {
        UserDefaults.standard.set(value, forKey: key)
        if iCloudSyncEnabled && syncedKeys.contains(key) {
            if let value, !isValid(value: value, forKey: key) {
                syncLog.info("SettingsSyncService.set rejected invalid outbound value for \(key, privacy: .public).")
                return
            }
            kvStore.set(value, forKey: key)
        }
    }

    // Audit 2026-04-23 Max Audit P1-13: coalesce rapid-fire pushes
    // (currency picker scroll, reset-day picker scrub) so we don't
    // hammer `NSUbiquitousKeyValueStore` at keystroke speed — iCloud
    // KVS is rate-limited.
    nonisolated(unsafe) private static var pushDebounceTask: Task<Void, Never>?

    /// Push all synced settings from UserDefaults to KVS (used after local changes).
    static func pushAllSettings() {
        guard iCloudSyncEnabled else { return }
        pushDebounceTask?.cancel()
        pushDebounceTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            for key in syncedKeys {
                if let value = UserDefaults.standard.object(forKey: key) {
                    kvStore.set(value, forKey: key)
                }
            }
        }
    }

    /// Audit fix: call from Settings when the user toggles
    /// iCloudSyncEnabled. Registers the KVS observer + pushes initial
    /// values without requiring an app relaunch. `configure` short-
    /// circuits when the toggle is off, so disabling is automatic —
    /// any existing observer stays silent because the gated reads
    /// inside `set()` / `pushAllSettings()` early-return.
    static func iCloudToggleChanged(enabled: Bool) {
        if enabled {
            configure()
        } else {
            // Audit 2026-04-22 P1-18: actually remove the observer so
            // inbound KVS writes stop flowing. The `handleExternalChange`
            // gate below is a belt-and-suspenders defense for anything
            // that managed to enqueue before teardown.
            teardown()
        }
    }

    // MARK: - Private

    private static func pushLocalSettingsIfNeeded() {
        for key in syncedKeys {
            if kvStore.object(forKey: key) == nil,
               let localValue = UserDefaults.standard.object(forKey: key) {
                // Audit 2026-04-27 L-4: validate before pushing local
                // values to KVS. The receiving device's validator would
                // reject junk on inbound, but the leak still crosses
                // the wire — defense in depth catches it on outbound.
                guard isValid(value: localValue, forKey: key) else {
                    syncLog.info("pushLocalSettingsIfNeeded skipped invalid local value for \(key, privacy: .public).")
                    continue
                }
                kvStore.set(localValue, forKey: key)
            }
        }
    }

    private static func handleExternalChange(_ notification: Notification) {
        // Audit 2026-04-22 P1-18: belt-and-suspenders — even if a stale
        // observer fires after teardown, respect the current toggle.
        guard iCloudSyncEnabled else { return }

        guard let changedKeys = notification.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] else {
            return
        }

        for key in changedKeys where syncedKeys.contains(key) {
            if let remoteValue = kvStore.object(forKey: key),
               isValid(value: remoteValue, forKey: key) {
                UserDefaults.standard.set(remoteValue, forKey: key)
            }
        }
    }

    /// Audit 2026-04-22 P1-19: KVS is trusted by default — any
    /// compromised device signed into the same iCloud account can push
    /// arbitrary values. Validate before writing to local UserDefaults:
    /// `resetDay` must be 1–28 (cap matches the picker's range and the
    /// "all months work" rule); `selectedCurrency` must be a known
    /// ISO code. Unknown keys are rejected outright.
    ///
    /// Audit 2026-04-27 M-2: prior implementation only handled `resetDay`
    /// and `selectedCurrency`; every other key in `syncedKeys` (the seven
    /// notification-preference toggles + hour pickers added by P1-12)
    /// fell through to `default: return false` — meaning the sync surface
    /// claimed to mirror them but the validator silently rejected every
    /// inbound + outbound write. Notification keys now type-checked +
    /// hour keys range-checked.
    private static func isValid(value: Any, forKey key: String) -> Bool {
        switch key {
        case AppStorageKeys.resetDay:
            guard let day = value as? Int else { return false }
            return (1...28).contains(day)
        case AppStorageKeys.selectedCurrency:
            guard let code = value as? String else { return false }
            // 3-letter uppercase ISO codes only; reject anything else
            // immediately so we don't even do the list lookup on junk.
            guard code.count == 3, code.allSatisfy({ $0.isASCII && $0.isUppercase }) else { return false }
            return Locale.commonISOCurrencyCodes.contains(code)
        case AppStorageKeys.dailyReminderEnabled,
             AppStorageKeys.weeklyDigestEnabled,
             AppStorageKeys.billDueReminders,
             AppStorageKeys.closeVaultReminderEnabled,
             AppStorageKeys.morningBriefingEnabled:
            // Bool toggles — accept only true/false. NSNumber backs
            // UserDefaults boolean storage so an `as? Bool` works for
            // both literal Bool and NSNumber-wrapped values.
            return value is Bool
        case AppStorageKeys.dailyReminderHour,
             AppStorageKeys.morningBriefingHour:
            // Audit 2026-04-27 L-5: range-clamp 0–23 so a malicious
            // (or restored-from-old-version) value can't construct a
            // DateComponents that silently builds a nil trigger.
            guard let hour = value as? Int else { return false }
            return (0...23).contains(hour)
        default:
            return false
        }
    }
}
