# Security & Privacy Audit — BudgetVault v3.3.2

**Date:** 2026-04-27
**Scope:** Source under `BudgetVault/`, `BudgetVaultShared/`, `BudgetVaultWidget/` at HEAD `0836b89` (main, MARKETING_VERSION 3.3.2 / build 4). Excluded: `.claude/worktrees/`, `build/`, archives.
**Auditor:** Read-only line-level audit covering 17 surfaces in P0/P1/P2 priority. No code modified.

## Executive summary

BudgetVault's security posture is **strong by structural choice**: zero `URLSession`, zero `WKWebView`, zero third-party SPM/CocoaPods deps, zero analytics SDKs, no pasteboard, no URL schemes, no universal links. The privacy story is materially defensible. Money is correctly persisted as `Int64` cents; biometric and StoreKit flows have iterated through multiple audit rounds and now fail closed correctly.

**Three findings warrant action before further App Store submissions:**

1. **HIGH — Siri intent bypasses biometric lock for dollar amounts.** `BudgetRemainingIntent` at `BudgetVault/AppIntents/BudgetAppIntents.swift:67-78` reads cached widget data with no biometric-lock check. Siri reads "You have $X remaining" while device is locked & in someone else's hands.
2. **HIGH — "Delete All Data" leaves CloudKit mirror intact.** `SettingsView.deleteAllData()` (`BudgetVault/Views/Settings/SettingsView.swift:1062`) wipes local + Keychain + App Group + notifications + Live Activities + tmp CSVs, but does NOT delete the CloudKit private-database mirror. Re-opening with iCloud sync still on resyncs the data back.
3. **HIGH — Premium gating bypass via `defaults write`.** Hard gates use `isPremium || storeKit.isPremium`. A `defaults write io.budgetvault.app isPremium true` survives launches because `StoreKitManager.checkEntitlements` does not clear the AppStorage cache when both stream-empty AND Keychain-nil. `defaults write` is local-debugger / jailbreak class, but the design contract in CLAUDE.md rule 9 says StoreKit is authoritative — current code violates that contract.

Eight MED findings and several LOW/defense-in-depth observations follow. Nothing here is App-Store-rejection class.

---

## Findings — Critical & High

### H-1 — Siri intent reads financial state with no biometric lock check
**Severity:** HIGH (privacy bypass)
**File:** `BudgetVault/AppIntents/BudgetAppIntents.swift:67-78`

`BudgetRemainingIntent.perform()` reads the App Group `widgetData` blob and dialogs back the remaining-budget amount. There is no consultation of `AppStorageKeys.biometricLockEnabled`. A locked phone in someone else's hands can ask Siri "What's my BudgetVault balance?" and hear the dollar amount.

The widget-data side (`Services/WidgetDataService.swift:64`) redacts category *names* when biometric lock is on, but not amounts — and the Siri intent makes no redaction at all.

**Fix:**
```swift
// BudgetRemainingIntent.perform()
if UserDefaults.standard.bool(forKey: AppStorageKeys.biometricLockEnabled) {
    return .result(dialog: "Open BudgetVault to view your balance.")
}
```
Or require biometric verification within the intent before disclosing.

---

### H-2 — "Delete All Data" does not delete CloudKit mirror
**Severity:** HIGH (privacy claim mismatch)
**File:** `BudgetVault/Views/Settings/SettingsView.swift:1062-1152`

`deleteAllData()` is comprehensive locally — wipes SwiftData, Keychain, App Group, notifications, Live Activities, FeedbackService log, tmp CSV exports, and prefix-matched UserDefaults keys. But CloudKit's mirror of the private database is untouched. If iCloud sync is enabled at delete time, the user reopens the app and the SwiftData/CloudKit integration repopulates everything from the iCloud copy.

The button's UX promise ("This permanently deletes…") is broken when iCloud sync is on.

**Fix options (pick one):**
- Toggle `iCloudSyncEnabled` to false *before* deletion, surface a "Note: iCloud Backup also retains a snapshot — to remove from iCloud, open Settings → iCloud → Manage Storage → BudgetVault." instructional.
- Call `CKContainer.default().privateCloudDatabase.deleteRecordZone(withID:)` on the SwiftData zone (or `deleteAllRecordZones()`) prior to local wipe. This is a destructive irreversible CloudKit operation; needs careful UX (extra confirm).
- Add a **second** explicit "Delete iCloud Copy Too?" confirmation that performs the CloudKit zone delete.

---

### H-3 — Premium-gating bypass via UserDefaults override
**Severity:** HIGH (design contract violation)
**Files:** `BudgetVault/Services/StoreKitManager.swift:319-331`; multiple view sites including `SettingsView.swift:1243`, `MainTabView.swift:31`, `InsightsView.swift:12`, `SpendingHeatmapView.swift:10`, `CSVImportView.swift:13`, `RecurringExpenseListView.swift:23`, `AchievementBadgeView.swift:16`.

CLAUDE.md rule 9: *"`storeKit.isPremium` is authoritative. `@AppStorage(isPremium)` is instant-UI cache; don't rely on it for hard gating."*

Every view computes `private var premium: Bool { isPremium || storeKit.isPremium }`. The OR is correct for instant UI (avoids a flash of "Free" on cold start before `checkEntitlements()` resolves), but it's also used for **hard gates**: e.g., `SettingsView:1243` — applying a budget template.

The bypass:
1. Attacker writes `defaults write io.budgetvault.app isPremium 1` (or a malicious backup restore puts the value in UserDefaults).
2. App relaunches. `StoreKitManager.init()` sets `isPremium=false`, then `Task { await checkEntitlements() }`.
3. `checkEntitlements()` iterates `currentEntitlements` — empty stream because no real receipt. Falls into the cache-fallback branch at line 319-331.
4. `KeychainService.getBool(forKey: "isPremium")` returns `nil` (no real Keychain entry).
5. The `else` branch at line 327 only enters `if let cached = ...` — when nil, the branch is skipped silently. **The malicious `@AppStorage(isPremium) = true` is never overwritten.**
6. Every `isPremium || storeKit.isPremium` site sees `true || false → true`. Premium granted for the session, persists across restarts.

Keychain authority does not save us here because the OR pattern bypasses Keychain whenever `@AppStorage(isPremium)` is true.

**Fix:**
- In the cache-fallback branch (`StoreKitManager.swift:319-331`), if `KeychainService.getBool(...)` returns `nil`, **explicitly set `UserDefaults.standard.set(false, forKey: AppStorageKeys.isPremium)` and `isPremium = false`**. The current code leaves the AppStorage value untouched.
- Long term: drop the `isPremium ||` half of every gating expression. Use `storeKit.isPremium` only. Accept the brief flash of free state on cold start (or render a skeleton until `checkEntitlements()` completes).

---

## Findings — Medium

### M-1 — Lock-screen widgets always show dollar amounts
**Severity:** MED
**Files:** `BudgetVaultWidget/BudgetVaultWidget.swift:280-340` (`AccessoryCircular`, `AccessoryInline`, `AccessoryRectangular`)

The redaction added in P0-6 only zeroes `topCategories[].name` — dollar amounts (`remainingBudgetCents`, `dailyAllowanceCents`, `topCategories[].spentCents`) render unredacted on the lock screen even when biometric lock is enabled.

Users who put a budget widget on their lock screen are explicitly opting in to that visibility, but the privacy-first marketing position is harder to defend if "Therapy bill" the *name* is hidden but "$1,247 remaining this month" is shown.

**Fix:** mirror the `redactCategoryNames` flag with `redactAmounts` derived from `biometricLockEnabled`, and have the lock-screen widget views switch to a "Tap to open" affordance when redacted.

### M-2 — `SettingsSyncService.isValid()` rejects every notification key it claims to sync
**Severity:** MED (functional bug, contradicts intent)
**File:** `BudgetVault/Services/SettingsSyncService.swift:174-188`

`syncedKeys` (line 19-29) lists `dailyReminderEnabled`, `dailyReminderHour`, `weeklyDigestEnabled`, `billDueReminders`, `closeVaultReminderEnabled`, `morningBriefingEnabled`, `morningBriefingHour`. The `isValid()` switch only handles `resetDay` and `selectedCurrency`; everything else falls through to `default: return false`.

Outbound: `set()` (line 90-99) calls `isValid()` and returns early on false → the boolean preference is never written to KVS. Inbound: `handleExternalChange()` (line 162) gates on `isValid()` → remote values are rejected.

**Net effect:** the P1-12 audit fix that "added notification preference toggles to sync across devices" is non-functional. Users see a setting toggle on Device A; Device B never learns.

**Fix:**
```swift
case AppStorageKeys.dailyReminderEnabled,
     AppStorageKeys.weeklyDigestEnabled,
     AppStorageKeys.billDueReminders,
     AppStorageKeys.closeVaultReminderEnabled,
     AppStorageKeys.morningBriefingEnabled:
    return value is Bool
case AppStorageKeys.dailyReminderHour,
     AppStorageKeys.morningBriefingHour:
    guard let hour = value as? Int else { return false }
    return (0...23).contains(hour)
```

### M-3 — `BiometricAuthService.isAuthenticated` is a public mutable var
**Severity:** MED (defensive coding)
**File:** `BudgetVault/Services/BiometricAuthService.swift:7`

`var isAuthenticated = false` — declared `var` with no `private(set)`. `ContentView.swift:92,98` writes `false` to force re-auth, which is by-design — but the property accepts `true` writes from any caller too. No current site does so, but the design contract is "the service controls this flag." A future developer accidentally writing `service.isAuthenticated = true` from a UI handler would silently bypass the entire biometric gate.

**Fix:** `private(set) var isAuthenticated = false` and expose `func lock()` for the cases that need to force re-auth (`ContentView.swift:92,98`).

### M-4 — `parseAmount()` accepts unbounded magnitudes
**Severity:** MED
**File:** `BudgetVault/Services/CSVImporter.swift:267-273`

`Double(cleaned)` accepts scientific notation and astronomically large values. `Decimal(row.amount) * 100 → Int64(truncating:)` (line 174-175) becomes undefined when the decimal value exceeds Int64 range — Apple's docs state behavior is undefined when `NSDecimalNumber.int64Value` is called on out-of-range values. Importing a malicious CSV row with `amount = 1e20` could produce arbitrary truncated cents.

The AppIntents path already caps amounts at `< 10_000_000` (`BudgetAppIntents.swift:27`); CSV import has no equivalent.

**Fix:** in `parseAmount`, after the `Double()` call, reject `!cleaned.isFinite || abs(value) > 1_000_000_000` (a billion-dollar transaction is implausible).

### M-5 — `parseCSVLine` quote-escape handling is wrong
**Severity:** MED (data integrity, not security)
**File:** `BudgetVault/Services/CSVImporter.swift:216-233`

Standard CSV escapes a literal quote inside a quoted field as `""`. The current implementation toggles `inQuotes` on every `"` and never appends a literal `"`. A note exported as `"She said ""ok"""` re-imports as `She said ok`, losing the quote characters.

**Fix:** detect lookahead-for-double-quote inside `inQuotes` and append a single `"`:
```swift
if char == "\"" {
    if inQuotes && next == "\"" {
        current.append("\"")
        skipNext = true
    } else { inQuotes.toggle() }
}
```
(Requires walking with index instead of `for char in line`.)

### M-6 — `containerError` surfaces raw error description
**Severity:** MED (info disclosure)
**File:** `BudgetVault/BudgetVaultApp.swift:165, 389-393`

`databaseErrorView` shows `Text(containerError ?? ...)` where `containerError = error.localizedDescription` from the SwiftData/CoreData `ModelContainer(for:)` failure. Could leak file paths, schema details, or migration internals to end users.

**Fix:** map known cases (`isMigrationError`, `isDiskFullError`, etc.) to user copy; default to "An unexpected database error occurred. Please contact support if this keeps happening." Log the raw error with `privacy: .private` for diagnostics.

### M-7 — Reset Database does not pre-clear iCloud sync flag
**Severity:** MED (privacy claim mismatch, sibling of H-2)
**File:** `BudgetVault/BudgetVaultApp.swift:413-433`

The emergency `resetDatabase()` removes the local `.store/.wal/.shm` files and clears Keychain + onboarding flags, but doesn't touch `AppStorageKeys.iCloudSyncEnabled`. After relaunch, if sync was on, CloudKit repopulates the database. Same root cause as H-2.

**Fix:** also `UserDefaults.standard.set(false, forKey: AppStorageKeys.iCloudSyncEnabled)` in `resetDatabase()`. Document that "Reset" is local; for a full wipe direct users to iOS Settings → iCloud → Manage Storage.

### M-8 — `DebugSeedService` creates retired NetWorth entities
**Severity:** MED (audit-comment lie + dead schema growth)
**File:** `BudgetVault/Services/DebugSeedService.swift:170-188`

`Schema/BudgetVaultSchemaV1.swift:451` claims *"no code path creates `NetWorthAccount` / `NetWorthSnapshot`"*. `DebugSeedService` does (5 accounts + 3 snapshots). Currently inert in production because `BudgetVaultApp.body.task` says `// Debug seeding disabled for production` (line 176-177), and the `@available(*, deprecated)` initializers should at least surface a warning during development.

If a debug seed run gets accidentally wired up before V2 retirement, those CloudKit rows propagate to user iCloud accounts and complicate the V2 migration zone reset.

**Fix:** wrap the `NetWorthAccount(...)` / `NetWorthSnapshot(...)` calls in `DebugSeedService` with `#if DEBUG && SEED_NETWORTH` (a compile flag that is never set in any scheme), or remove them entirely. Update the schema comment to match.

---

## Findings — Low / Defense-in-Depth

### L-1 — KeychainService: no explicit `kSecAttrSynchronizable=false`
**File:** `BudgetVault/Services/KeychainService.swift:52-69`

iCloud Keychain sync defaults to off, but explicit `kSecAttrSynchronizable: false` defends against future Keychain library changes and is a one-line addition.

### L-2 — CSV export file lives in `temporaryDirectory` indefinitely
**File:** `BudgetVault/Services/CSVExporter.swift:142-157`

A successful export writes `BudgetVault_Export.csv` to `tmp/` with `FileProtectionType.complete`. The file persists until iOS purges. Containing every transaction + note + debt name, it's the most sensitive on-disk artifact the app produces. `deleteAllData()` does delete it (`SettingsView.swift:1146-1151`), but a normal "share, then forget about it" flow doesn't.

**Fix:** delete the file on share-sheet completion, OR write to a `URLRelationship.contains`-cleaned location, OR include `tmp/` purge in `app.willTerminate`.

### L-3 — `SafeSave` log uses default privacy interpolation
**File:** `BudgetVault/Utilities/SafeSave.swift:13`

`logger.error("SwiftData save failed: \(error.localizedDescription)")` relies on Swift's os.Logger default of `.private` for String interpolations in release builds. Defaults can change; explicit `\(error.localizedDescription, privacy: .private)` is one keystroke.

### L-4 — `pushLocalSettingsIfNeeded` writes without validation
**File:** `BudgetVault/Services/SettingsSyncService.swift:142-149`

The first-launch push of local settings to KVS bypasses `isValid()`. A corrupted local UserDefaults value (from an older buggy build, or `defaults write`) propagates to KVS as junk; the *receiving* device's validator catches it, but the leak crosses the wire.

**Fix:** wrap the inner `kvStore.set(localValue, forKey: key)` call in an `isValid()` gate.

### L-5 — `dailyReminderHour` not range-validated
**File:** `BudgetVault/Services/SettingsSyncService.swift:174-188` + downstream

The picker is bounded to 0-23 in the UI, but no defensive `(0...23).contains(hour)` check exists when reading the value back into `DateComponents`. A malicious or restored value of 99 would build a `DateComponents` whose `Calendar.date(from:)` returns nil, causing the schedule to silently no-op. (Also addressed by M-2 fix.)

### L-6 — Documents/feedback-log.json eligible for iCloud Backup
**File:** `BudgetVault/Services/FeedbackService.swift:39-42`

The user-typed bug-report log lives in `Documents/`. iOS includes Documents in iCloud Backup by default. For a privacy-first app, free-text user input crossing to Apple's backup is worth documenting in privacy policy (or excluding from backup):
```swift
var url = fileURL
var values = URLResourceValues()
values.isExcludedFromBackup = true
try? url.setResourceValues(values)
```

### L-7 — `BiometricAuthService` has no `evaluatedPolicyDomainState` capture
**File:** `BudgetVault/Services/BiometricAuthService.swift:107-122`

Best-practice for biometric-bound secrets is to capture the `LAContext.evaluatedPolicyDomainState` (an opaque blob representing current biometric enrollment) on first auth, persist it, and re-check on subsequent auths. If a user adds a new face/finger after gaining device passcode access, the blob changes and you can refuse authentication.

This is post-passcode-compromise defense — outside BudgetVault's documented threat model — but standard for high-assurance financial apps.

### L-8 — `escapeCSVField` no-op on empty strings
**File:** `BudgetVault/Services/CSVExporter.swift:166-172`

`guard let first = value.first else { return "" }` — empty notes return an unquoted empty string, but call sites wrap output with `"\"\(escaped)\""` so the column ends up as `""`. ✓ Safe today, but if a caller forgets to wrap, an empty field after a `,` becomes ambiguous.

### L-9 — Notification throttle keys never cleaned up
**File:** `BudgetVault/Services/NotificationService.swift:504, 541`

`"lastCategoryAlert-\(category.id.uuidString)"` writes to UserDefaults indefinitely. A user who creates and deletes 100 categories accumulates 100 stale keys. Memory bloat, not security. The prefix-match cleanup in `deleteAllData` does catch them via `"lastCategoryAlert"` prefix.

---

## Surfaces Verified Clean

| Surface | Status | Evidence |
|---|---|---|
| Network code | None | 0 `URLSession`, 0 `WKWebView`, 0 `URLRequest` |
| Third-party deps | None | 0 SPM remotes, 0 CocoaPods, 0 vendored binaries |
| Pasteboard | None | 0 `UIPasteboard` references |
| URL schemes | None | 0 `CFBundleURLTypes`, 0 `onOpenURL` handlers |
| Universal links | None | 0 associated-domains entitlement |
| Shell exec | None | 0 `Process()`, no `system()`, no `popen()` |
| Required-reason APIs | Declared | UserDefaults (CA92.1), FileTimestamp (C617.1) match grep results |
| `print()` / `NSLog` | Clean | 2 `print()` calls in `Schema` are inside `#if DEBUG` |
| `try!` / force-unwrap | Mostly clean | 3 `!` in `DebugSeedService` are static date components — safe |
| StoreKit verification | Verified | `checkVerified` throws on unverified; `iterated && !anyVerifiedForProduct` revokes |
| Half-open date intervals | Compliant | All audited query sites use `< nextPeriodStart` |
| Money invariant | Compliant | All persisted amounts are `Int64`; transient `Double` math rounded via `NSDecimalNumberHandler` banker's rounding |
| App-switcher snapshot blur | Implemented | `ContentView.swift:48-57` overlay at `.inactive` before `.background` |
| Inactivity re-auth timeout | Implemented | 30-second threshold, fail-closed on timer reset |
| SwiftData FileProtection | Implemented | `URLFileProtection.completeUnlessOpen` + per-file walk on first launch |
| File protection on tmp CSV | Implemented | `FileProtectionType.complete` set after write |
| Lock-screen notification redaction | Implemented for category/bill/amount text | Multiple `lockEnabled` branches in `NotificationService` |
| KVS validator (P1-19) | Implemented for `resetDay`, `selectedCurrency` | See M-2 for incomplete coverage |
| iCloud account presence detection | Implemented | `CloudSyncService.refreshAvailability()` |
| StoreKit revocation handling | Inline + listener | `StoreKitManager.swift:295-299, 361-365` |
| Bidi/control-char strip on Siri input | Implemented | `BudgetAppIntents.stripControlAndBidi` |
| Privacy manifest | Both targets correct | `NSPrivacyTracking=false`, `NSPrivacyCollectedDataTypes=[]`, declared APIs match grep |

---

## Recommendations summary

| ID | Severity | Action | Effort |
|---|---|---|---|
| H-1 | HIGH | Add biometric-lock check to `BudgetRemainingIntent` | <1h |
| H-2 | HIGH | Either toggle off iCloud sync before delete + warn, or call CloudKit zone delete | 2-4h |
| H-3 | HIGH | Force-clear `@AppStorage(isPremium)` to false in `checkEntitlements` cache-fallback branch when Keychain is nil | <1h |
| M-1 | MED | Mirror amount redaction onto lock-screen widgets when biometric lock is on | 2h |
| M-2 | MED | Extend `SettingsSyncService.isValid()` to handle Bool + 0-23 hour keys | <1h |
| M-3 | MED | `private(set)` on `BiometricAuthService.isAuthenticated`; expose `lock()` | <1h |
| M-4 | MED | Range-clamp `parseAmount` (reject `>= 1e9`) | <1h |
| M-5 | MED | Fix `parseCSVLine` `""` escape handling | 1h |
| M-6 | MED | Map raw SwiftData errors to user copy in `databaseErrorView` | 1h |
| M-7 | MED | Clear `iCloudSyncEnabled` in `resetDatabase()` | <1h |
| M-8 | MED | Compile-gate `DebugSeedService` NetWorth seeds; sync schema comment | <1h |
| L-1 to L-9 | LOW | Defense-in-depth — fold into next slack cycle | varies |

**Total H/M effort:** ~10-15 hours of focused work.

**Suggested release plan:**
- v3.3.3 (hotfix): H-1, H-3, M-2, M-3 — pure code, no UX changes, low test surface.
- v3.4.0: H-2, M-1, M-7 — touches user-facing flows, needs design + QA.
- Backlog: M-4, M-5, M-6, M-8, all L-*.

---

## Methodology notes

- Audit performed by line-level read of every file in `BudgetVault/`, `BudgetVaultShared/`, `BudgetVaultWidget/` reachable from production targets. Test code, build artifacts, and `.claude/worktrees/` excluded.
- Required-reason API coverage cross-checked by greppinkg against Apple's published list (UserDefaults, FileTimestamp, SystemBootTime, DiskSpace, ActiveKeyboard).
- StoreKit gating audit traced from each `isPremium` read site backward to a verified entitlement origin.
- CloudKit posture inferred from `cloudKitDatabase: .private(...)` config + the absence of `@Attribute(.allowsCloudEncryption)` on any field.
- All findings include file:line citations; no statement is based on memory of prior audits.
- This audit does NOT cover: runtime behavior under jailbreak, state-restoration scenarios beyond cold launch, race conditions only triggerable with sub-millisecond scheduling, App Store Connect submission metadata.
