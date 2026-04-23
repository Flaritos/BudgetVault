# BudgetVault v3.3.1 — Pre-Ship Audit (2026-04-22)

**Scope:** 13 specialist agents + MobAI exhaustive sweep.
**Binary:** Debug build at `/tmp/bvbuild/Build/Products/Debug-iphonesimulator/BudgetVault.app`.
**State at audit start:** `project.yml` at `MARKETING_VERSION 3.3.0`, `CURRENT_PROJECT_VERSION 2`. Smoke test 5/5 PASS.

---

## Ship verdict: **NO-GO** until P0-SHIP items are fixed.

Five items block App Store submission. Fourteen items block a clean launch. Everything else is follow-up.

---

## P0 — SHIP BLOCKERS (must fix before upload)

1. **Version bump.** `project.yml:46,128` — bump to `MARKETING_VERSION "3.3.1"` + `CURRENT_PROJECT_VERSION "3"` (both targets). ASC will reject duplicate 3.3.0 upload.
2. **Export compliance plist key missing.** `BudgetVault/Info.plist` — add `ITSAppUsesNonExemptEncryption = false`. Also add to widget `Info.plist`. Every upload will otherwise block on the ASC compliance modal.
3. **Price mismatch.** `Configuration.storekit:5` says `$14.99`; 10+ hardcoded `$14.99` strings in code (PaywallView, ChatOnboardingView, DashboardView, MonthlyWrappedShareCard, LaunchPricingCardView). MEMORY.md + ASC say **$9.99**. Pick one source of truth and fix both sides. Divergence = Guideline 3.1.1 rejection risk.
4. **App Store screenshots stale.** `docs/appstore-v33/composed/` was captured 2026-04-21 16:30, PRE theme-picker removal. Also flagged as "pre-VaultRevamp" in memory. Re-capture from current build before upload. Guideline 2.3.3 risk.
5. **App icon missing dark + tinted variants.** `BudgetVault/Assets.xcassets/AppIcon.appiconset/Contents.json` declares only a single universal slot. iOS 18 users on tinted/dark home screens get flat default — review-passable but 1-star fuel.

---

## MobAI Round 2 — Live bugs observed on device

**A. Smart Spending Forecast math contradicts itself (confirmed on-screen).** Insights detail (tap Vault → Insights, scroll once): with $12.50 spent, the Smart Spending Forecast card reads:
- **"Predicted month-end total: $4.67"** (less than already spent — impossible)
- **"Accelerating"** trend badge
- **"Over by"** label with missing value
Simultaneously, the warning card says *"On pace to overspend. At your current rate, you'll spend $17.85 this month."* $17.85 disagrees with $4.67. Two different predictors diverging by 4× is the live version of AI Engineer F1/F2. Screenshot: `02-insights-scrolled.png`.

**B. Wrapped slide 1 nonsense with zero income (confirmed on-screen).** Tap Vault → Wrapped. Slide 1 reads: `"SAVED $0.00 / 0% / Out of $0.00 earned, you spent just $12.50."` Cannot save 0% of $0. Copy should detect zero-income state and say e.g. *"Log your monthly income to see your savings story."* This is the AI Engineer F3 bug (`InsightsEngine.swift:272`) surfacing in Wrapped, not just Insights. Screenshot: `05-wrapped-slide1-bug.png`.

**C. Tip IAP triggers real Apple-ID sign-in dialog on simulator (expected).** Paywall tested implicitly — Configuration.storekit is being read and $2.99 price is displayed. Cannot complete a purchase in the sim. No regression.

**D. Milestones grid renders correctly.** "Earned 3 / Total 12 / Streak 1" stats card + 3 earned (Clean Sweep, Zero Day, Getting Started) + 9 locked tiers. Screenshot: `08-milestones.png`.

**E. Income mode works.** Log Expense sheet → tapping "Income" segment flips to "New income" with a down-arrow icon and subhead "Income goes into your monthly budget pool." Screenshot: `09-income-mode.png`.

**F. Wrapped 5-slide share flow reaches the share CTA.** Swiped through slides 1→2→3→4→5, final slide shows `budgetvault.io` watermark + "Share your April 2026 wrapped" + Save Image + End controls. Screenshot: `07-wrapped-slide5-share.png`.

**G. Debt tracker empty state + Add Debt form render correctly.** Name / Icon picker (10 emojis) / Current Balance / APR / Minimum / Due Day all present. Screenshot: `04-debt-add.png`.

---

## P0 — CODE (ship with known bugs)

6. **InsightsEngine statistical bugs** — `ViewModels/InsightsEngine.swift`
   - `:65` "On pace to overspend" projects vs `totalIncomeCents` instead of sum of category caps. Users get false negatives.
   - `:93-102` month-over-month "spending less" uses `periodStart + daysSoFar` as an absolute day count — compares full Feb (28d) to partial Mar (30d) and always falsely reports savings on Mar 30.
   - `:272` "Savings Rate" fires when `totalIncomeCents > 0` even if user logged zero income transactions — shows "95% of budget unspent" on day 1.
   - `:76-89` "Unusual expense" uses mean + 2× threshold — fragile with small N, misses obvious outliers in `[$500, $1000]`.
7. **Unbounded `@Query`** — 6 views load the full Transaction table then filter in Swift. Fine today; ugly at 2k+ rows. `DashboardView.swift:23`, `HistoryView.swift:12`, `FinanceTabView.swift:15,594`, `InsightsView.swift:12`, `TransactionEntryView.swift:16`, `RecurringExpenseListView.swift:23`.
8. **InsightsEngine runs on MainActor, blocks UI** — `ViewModels/InsightsEngine.swift:27` called synchronously from `DashboardView.swift:1786`, `FinanceTabView.swift:79` (recomputes every body eval, no cache), `InsightsView.swift:565`.
9. **`titanium500` (#5E6A7C) used for body text on navy fails WCAG 1.4.3 — 3.25:1 vs required 4.5:1** — `AchievementGridView.swift:133,194`, `SettingsView.swift:357`. Swap to `titanium400` (5.8:1).
10. **No VoiceOver announcement on achievement unlock** — `AchievementSheet.swift:143`. Haptic fires but no `UIAccessibility.post(.screenChanged)`.
11. **86 literal hex calls in onboarding** — `ChatOnboardingView.swift:251-876` bypasses the token system and introduces 2 novel blues (`#1E40AF`, `#1E3A8A`) not in the palette. First-impression brand surface.
12. **Three "brand blues" still coexist** — `BudgetVaultTheme.swift:15-48` (`electricBlue #2563EB`, `brightBlue #3B82F6`, `accentSoft #60A5FA`). Consolidate to two tokens, delete `userAccentColor`/`brightBlue`/`neonBlue` aliases.
13. **Biometric error handling collapses all LAErrors to generic text** — `BiometricAuthService.swift:67-74`. User sees "Canceled by the user" for `.userCancel`, nothing actionable for `.biometryLockout` / `.biometryNotEnrolled`.
14. **CloudKit quota / no-account failures invisible** — `CloudSyncService.swift:32-43`. Toggle iCloud on with no iCloud account → sync silently never runs. `syncError = nil` unconditionally on every change.
15. **CSV import fails on non-UTF-8** — `CSVImportView.swift:353` — Excel/Numbers default to UTF-16 or CP1252. Common path errors out.
16. **StoreKit surfaces raw error strings** — `StoreKitManager.swift:144-147`. Map `StoreKitError` / `Product.PurchaseError` to user copy; add Retry on `.networkError`.
17. **`dismissedLaunchBanner` dead `@AppStorage`** — `DashboardView.swift:77`. Declared, never read. Typo'd var name (`hasDissmissedLaunchBanner`).

---

## P1 — Strongly recommended before launch

18. **iCloud KVS observer not removed on toggle-off** — `SettingsSyncService.swift:30-43, 69-73`. `iCloudToggleChanged(enabled: false)` is no-op. Remote writes still flow inbound via `handleExternalChange`. Contradicts the privacy-toggle claim.
19. **iCloud KVS values not validated on read** — `SettingsSyncService.swift:86-95`. A compromised second device can push `resetDay = 999` or garbage currency. Validate before writing UserDefaults.
20. **Widget `PrivacyInfo.xcprivacy` thin** — only declares UserDefaults. Mirror main app's 4 categories (UserDefaults CA92.1, FileTimestamp C617.1, SystemBootTime 35F9.1, DiskSpace 0A2A.1).
21. **Delete All Data doesn't wipe Keychain or reset `hasCompletedOnboarding`** — `SettingsView.swift:817-863`, `BudgetVaultApp.swift:276-286`.
22. **Launch path walks Application Support dir stamping FileProtection every launch** — `BudgetVaultApp.swift:204-215`. Gate on one-shot `didStampFileProtection` flag.
23. **Month rollover + recurring expenses run synchronously on foreground** — `BudgetVaultApp.swift:152-156`. Detach to Task with brief spinner.
24. **`@MainActor` hygiene breaks Swift 6** — `BudgetVaultApp.swift:124` calls `@MainActor UITestSeedService` from non-isolated App.init. Compile error under Swift 6.
25. **Fire-and-forget `Task` blocks without cancellation** — `DashboardView.swift:233-241, 1767, 1819, 1889, 1922`. Toast chains survive tab switches.
26. **`DispatchQueue.main.asyncAfter` still in 7 files** — `HistoryView.swift:357`, `MonthlySummaryView.swift:164`, `ChatOnboardingView.swift:1603/1607/1704`, `SettingsView.swift:794`, `MonthlyWrappedView.swift:994`. None cancellable on dismiss.
27. **7 `UNUserNotificationCenter.add()` completion handlers ignored** — `NotificationService.swift:74/100/137/164/211/239+`.
28. **`BGTaskScheduler.submit` error swallowed** — `BudgetVaultApp.swift:223`. Log + gate on `UIApplication.backgroundRefreshStatus`.
29. **`handleBackgroundRefresh` has no deadline guard** — `BudgetVaultApp.swift:226-239`. Unbounded work can exceed 30s budget → iOS kills + reduces future scheduling.
30. **Transaction.category relationship has no explicit deleteRule** — `Schema/BudgetVaultSchemaV1.swift:211`. Inverse is `.cascade`; owning side infers `.nullify`. Make explicit.
31. **Category uniqueness not case-normalized on insert** — `TransactionEntryView` + `performMonthRollover`. "Food" and "food" can coexist.
32. **`RecurringExpenseScheduler` matches category name case-sensitively** — `:38`. Inconsistent with lowercased matching elsewhere.
33. **FinanceTabView.insights recomputes every body render** — `FinanceTabView.swift:77` — no cache (Dashboard caches correctly).
34. **Launch pricing magic number** — `StoreKitManager.swift:19` hardcoded `July 1, 2026 UTC`. Banner disappears before any user sees the app if review slips.
35. **AppIntent `AddExpenseIntent.amount` unvalidated** — `BudgetAppIntents.swift:10-28`. Siri can pass `NaN`, `-0.01`, `1e308`. Validate `> 0 && isFinite && < 10_000_000`.
36. **Keychain set/add errors ignored by StoreKitManager** — `StoreKitManager.swift:169, 190`. `errSecInteractionNotAllowed` (locked device) drops premium flag.
37. **6 P1 a11y issues** — see `Accessibility` section below.

### P1 Accessibility (Dynamic Type)

- **VaultDialButton inner glyphs fixed** — `VaultDialButton.swift:47-51`. Scale with `@ScaledMetric`.
- **FlipDigit plate seams fixed 1pt** — `FlipDigitDisplay.swift:98,104`. Multiply by scale.
- **Keypad glyph fonts fixed** — `QuietKeypad.swift:69,72`, `TitaniumKeypad.swift:97,100`. Scale via `@ScaledMetric`.
- **EnvelopeDepositBox "of $X" 10pt @ 0.55 opacity fails contrast (3.9:1)** — `:58`. Raise to 0.75 or use titanium300.
- **PaywallView chip scaleEffect ignores reduceMotion** — `:68-69`.
- **Settings premiumActiveBadge has no a11y group** — `:285-302`. Add `.accessibilityElement(children: .combine)`.
- **EngravedSectionHeader uses fixed 11pt + uppercase tracking** — `:19-23`. Doesn't scale under AX sizes.

---

## P2 — Hygiene / polish (future sprints)

- **`lastWrappedViewed` / `lastCelebratedMilestone` not in `AppStorageKeys`** — Dashboard + Finance use bare string literals. Consolidate.
- **`BrandMark` imageset (~1.5 MB) unused** — delete from Assets.xcassets.
- **14 legacy mockup HTMLs at repo root** — move to `mockups/` (already gitignored).
- **Stale doc references to `accentColorHex` / `accentColorOptions`** in 5 docs (`docs/superpowers/plans/03`, `/01`, `/07`; `docs/audit-2026-04-16/product/brand-guardian.md`; `AUDIT_PLAN.md`).
- **Widget `WidgetTheme.swift:9` duplicates `accentSoft`** — extract to `BudgetVaultShared`.
- **Keychain `isPremium` value is 1-byte Bool, no biometry ACL** — cache-grade, acceptable; add code comment.
- **CSV export temp file not FileProtection-stamped** — `CSVExporter.swift:57-59`. `temporaryDirectory` inherits weaker protection.
- **Widget App Group snapshot exposes category names on locked home screen** — document in privacy policy or elide names when locked.
- **App-switcher preview not blurred** — `ContentView.swift:45-49`. Lock engages on `.background` but snapshot captured on `.inactive`.
- **DateFormatter/NumberFormatter allocated in body/functions** — 12 sites. Hoist to `static let`.
- **No `.drawingGroup()` / `.compositingGroup()` anywhere** — VaultDial + FlipDigit + envelope cards are ideal candidates.
- **Monthly Wrapped TabView eager-loads all 5 slides** — precompute derived values once, pass plain.
- **HistoryView search is O(N) per keystroke** — `:253`. Debounce 250ms.
- **InsightsEngine judgmental copy** — "Payday splurge detected" / "Streak at risk!". Softer copy fits the brand.
- **Launch screen empty** — `Info.plist:48` `UILaunchScreen = <dict/>`. Add brand color or storyboard.
- **Monthly Wrapped slide 4 single blue cameo breaks the navy+purple palette** — `MonthlyWrappedView.swift:602`.
- **Screenshot slide `06-theme.png` absent but composer declared 9** — already fixed today (composer dropped to 8 slides).
- **`MigrationStage` empty but no V2 — add test asserting schema hash stability**.

---

## Recommended ASO copy (App Store Optimizer output)

- **Name (30):** `BudgetVault: Private Budget`
- **Subtitle (30):** `Envelope budget, on-device AI`
- **Keywords (100):** `envelope,ledger,offline,private,nosub,onetime,allowance,ynab,monarch,copilot,debt,cashflow,daily`
- **Promotional text (170):** "Your financial data belongs on your phone, not in a spreadsheet somewhere. No bank sync, no subscription, no tracking. Just envelope budgeting — $14.99, once."
- **Description opener:** "The budget app that works without your bank login. $14.99. Once. Forever."
- **What's New v3.3.1:** "Refined Vault. Retired theme picker — one canonical dark look. Accessibility pass. Dozens of fixes."

---

## Minimum viable ship-diff

To unblock submission *today*, only 5 things change:
1. `project.yml` version bump (3 line edit).
2. `Info.plist` + widget `Info.plist` — add `ITSAppUsesNonExemptEncryption = false`.
3. Price reconciliation — pick $9.99 or $14.99, update the 10+ literal strings + `Configuration.storekit`.
4. Re-export App Store screenshots from current composer.html (button press; ~2 min).
5. Dark + tinted AppIcon variants (design asset work, 30-60 min for a competent icon).

Everything else is post-launch v3.3.2 material. The P0 code bugs (InsightsEngine statistics) are technical-correctness issues but will not cause App Review rejection — they'll cause angry user mail months from now.
