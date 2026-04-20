# Engineering: Security Engineer Findings

## TL;DR
Zero third-party SDKs and zero network code make the "Data Not Collected" claim defensible — but the `PrivacyInfo.xcprivacy` is incomplete (3 required-reason APIs undeclared, widget has no manifest at all), which is the single highest risk to the privacy label surviving App Review.

## Top 3 Opportunities (Ranked)
1. **Complete `PrivacyInfo.xcprivacy` for app + widget** (1 day, brand-saving) — `BudgetVault/PrivacyInfo.xcprivacy:12-21` declares only `UserDefaults` (CA92.1). The codebase also triggers required-reason APIs that must be declared: `FileManager` disk-space/timestamp via `CSVExporter.swift:49` (atomic write = `fileTimestamp`, reason C617.1), `Documents` writes in `FeedbackService.swift:64`, and `utsname()` in `FeedbackService.swift:107` (system-boot-time category, reason 35F9.1). `BudgetVaultWidget/` has **no PrivacyInfo.xcprivacy at all** despite reading App Group UserDefaults at `BudgetVaultWidget.swift:47`. Apple is rejecting submissions for missing widget manifests as of 2025. Add both files; copy CA92.1 + 35F9.1 + C617.1 reasons.
2. **Harden Keychain accessibility class** (2 hours, anti-fraud) — `KeychainService.swift:10-21` writes premium status with no `kSecAttrAccessible` attribute. Default is `kSecAttrAccessibleWhenUnlocked`, which **migrates across device backups**. A user can buy premium on Device A, restore the encrypted backup to Device B, and inherit premium without an Apple ID re-verification. Add `kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` to both `set` and `getBool` queries. Pairs with the existing StoreKit re-verification on launch (`StoreKitManager.swift:62`) for defense-in-depth.
3. **Screenshot/screen-recording masking on sensitive surfaces** (1 day, premium-perceived-quality) — No `.privacySensitive()` or `UIScreen.isCaptured` checks anywhere. Hero balance, paywall amounts, and Vault tab are recorded to iOS screenshot history and visible in App Switcher snapshots stored on disk. Add `.privacySensitive()` to `DashboardView` balance row + `PaywallView`, and a blur overlay in `ContentView.body` when `scenePhase == .inactive` (the App Switcher snapshot is taken in that phase, before `.background`).

## Top 3 Risks / Debt Items
1. **CloudKit sync surface is opaque to the user** — `BudgetVaultApp.swift:82-87` activates `cloudKitDatabase: .private(...)` when `iCloudSyncEnabled` is set. All transactions, notes, amounts go to iCloud private DB. Apple encrypts in transit and at rest, but the App Store privacy label currently says "Data Not Collected" — this is technically accurate (Apple, not us, holds it) but a regulator or competitor could argue otherwise. Mitigate: add an explicit "Data leaves your device when iCloud Sync is on" disclosure in Settings and the onboarding toggle. Do not enable iCloud silently.
2. **Feedback log persisted to Documents (iCloud-backed)** — `FeedbackService.swift:39-41` writes `feedback-log.json` to `.documentDirectory`, which is included in iTunes/iCloud device backups. The file contains device model, OS version, app version, and free-text user complaints. Move to `.applicationSupportDirectory` and set `URLResourceValues.isExcludedFromBackup = true`. Same treatment for any future debug-export.
3. **`print()` in release build leaks StoreKit error details** — `StoreKitManager.swift:88` calls `print("Failed to load products: \(error)")` unconditionally. In release this goes to the unified log and is harvestable via Console.app over USB. Wrap in `#if DEBUG` or replace with `Logger(subsystem:..., category:"storekit").debug(...)` with `privacy: .private` interpolation.

## Quick Wins (<1 day each)
- Add `.privacySensitive()` to balance/amount Text views (12 call sites, all in `DashboardView.swift` + `PaywallView.swift`)
- Set `URLFileProtection.complete` on the feedback-log file (currently only set on Application Support directory at `BudgetVaultApp.swift:97-102`)
- Strip `print()` from `StoreKitManager.swift:88`
- Re-lock biometric on `scenePhase == .inactive`, not just `.background` (`ContentView.swift:44-48`) — App Switcher reveals content for ~1s today
- Add `kSecAttrSynchronizable: false` to `KeychainService` queries to prevent iCloud Keychain sync of premium flag

## Long Bets (>2 weeks but transformative)
- **End-to-end encrypted CloudKit fields** for transaction notes/amounts using a user-derived key stored in Keychain (would let marketing claim "even Apple can't read your data" — true privacy moat that Plaid-based competitors can never match)
- **App Attest for receipt validation** — bind premium entitlement to a DeviceCheck attestation key so jailbroken-device piracy and backup-restore fraud are cryptographically blocked
- **Public security disclosure policy + bug bounty page** at budgetvault.io/security — converts the privacy story from marketing copy into a verifiable claim, drives organic press

## What NOT to Do
- **Don't add Sentry/Crashlytics/Bugsnag.** Even "anonymized" crash reporting has bitten "Data Not Collected" labels (Apple now classifies crash logs with stack symbols as Diagnostics → Crash Data → must be declared). Use Apple's built-in MetricKit if signal is needed; it's exempted.
- **Don't add receipt-validation server.** Server-side StoreKit2 verification would require sending the JWS to budgetvault.io, which is a network call that breaks the wedge. The on-device `VerificationResult.verified` path at `StoreKitManager.swift:197-204` is sufficient given iOS's hardware-backed signing.
- **Don't enable CloudKit by default.** Current opt-in design is correct; making it default-on would invalidate the privacy label the moment a user upgrades.
- **Don't roll a passcode-fallback PIN.** `BiometricAuthService.swift` correctly uses `.deviceOwnerAuthentication` which falls back to device passcode — adding an in-app PIN would be custom auth crypto and a regression.
