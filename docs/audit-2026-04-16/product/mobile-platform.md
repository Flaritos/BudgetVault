# Product: iOS Platform Exploitation Findings

## TL;DR
The Live Activity is **broken in production** — `BudgetLiveActivityService` requests an Activity but no `ActivityConfiguration` widget exists to render it; meanwhile iPad is locked off (`TARGETED_DEVICE_FAMILY: "1"`) despite CloudKit already being live, leaving 20–30% of the addressable Apple-tax-paying audience on the table.

## Top 3 Opportunities (Ranked)

1. **Ship the missing Live Activity UI + Dynamic Island** (1 week, high impact). `BudgetLiveActivityService.swift:54` calls `Activity.request` against `BudgetActivityAttributes` (Models/BudgetActivityAttributes.swift:4), but `BudgetVaultWidget.swift:395` `WidgetBundle` contains zero `ActivityConfiguration`. Result: every `start()` call either silently no-ops or throws (logged at line 62) — the v3.2 marquee feature does not visibly exist. Add a Lock Screen ring + remaining-cents view and a Dynamic Island compact (ring) / expanded (ring + daily allowance + "Log" button via `OpenAddExpenseIntent`). iOS 16.2+ — no deployment target change.

2. **iPad support via NavigationSplitView** (2–3 weeks, high LTV impact). `project.yml:46` is iPhone-only. CloudKit is already wired (`BudgetVaultApp.swift:86`, entitlements line 9–14), so an iPad family adds zero sync work. Premium ($14.99 one-time) buyers skew Apple-ecosystem-deep — iPad/Mac (Designed for iPad) unlocks a second purchase surface and Mac-mini visibility in Spotlight/Search. Use `NavigationSplitView` with sidebar = Home/History/Vault/Settings, detail = current views.

3. **Apple Watch companion (quick-add only, v1)** (2 weeks, retention impact). No Watch target exists. Smallest-viable scope: a single complication showing remaining-budget gauge (reuses `WidgetBudgetData` JSON in App Group `group.io.budgetvault.shared`, BudgetVaultWidget.swift:29) + a Digital Crown amount picker that writes via WatchConnectivity to a pending-transaction queue. Eliminates "phone in pocket → log later → forget" — the #1 cause of broken streaks.

## Top 3 Risks / Debt Items

1. **Streak data lives in `@AppStorage`, not CloudKit** (01_BudgetVault_Spec.md:54). Multi-device users (already possible since CloudKit is on) get divergent streaks today. Will get worse with iPad and catastrophic with Watch. Migrate to a `StreakRecord` SwiftData model before adding more devices.

2. **Three "iOS 18 — Add @Query predicate" TODOs in hot paths** (DashboardView.swift:21, TransactionEntryView.swift:17, InsightsView.swift:10). Unbounded SwiftData fetches × CloudKit sync = perceptible jank as users accumulate history. Independent of platform features but blocks iPad shipping (split-view amplifies fetch cost).

3. **Apple Intelligence not addressable on iOS 17.** Genmoji for category icons, Writing Tools for note polish, on-device summarization for Wrapped narration are all iOS 18.1+. Staying on iOS 17 leaves the privacy story un-augmented despite it being the literal product wedge.

## Quick Wins (<1 day each)

- Add `widgetURL(URL(string: "budgetvault://add"))` to widget views — currently zero deep-link routes (no matches for `widgetURL` in repo); button taps via `OpenAddExpenseIntent` only open the app cold.
- Wire `BudgetRemainingIntent` (BudgetAppIntents.swift:30) to a second `LogExpenseControl`-style Control: "Check Budget" — iOS 18 Control Center surface, ~30 lines mirroring BudgetVaultControl.swift:11.
- Add `.systemLarge` widget family — currently only `.systemSmall`/`.systemMedium` (BudgetVaultWidget.swift:343, 357); large unlocks the StandBy display surface for free.
- Add `AppShortcut` phrases for "No-spend day" — already a v3.2 feature, zero Siri exposure.

## Long Bets (>2 weeks but transformative)

- **iOS 18 deployment migration** — unlocks Apple Intelligence (Writing Tools on note field, Genmoji as category-icon picker), `@Animatable`, Tab+Sidebar morphing for iPad, native `AccessoryWidgetGroup`. Drop-iOS-17 cost: small (~5% of installed base by ship date).
- **visionOS Designed-for-iPad** — once iPad ships, visionOS is one App Store checkbox. Privacy story plays exceptionally well in spatial.
- **Mac Catalyst vs Designed for iPad** — pick Designed for iPad (zero code, ships with iPad work).

## What NOT to Do

- **No interactive Live Activity buttons in v1** — `LiveActivityIntent` requires iOS 17+ and works, but ActivityKit + SwiftData writes from extension process is fraught; ship read-only first.
- **No full standalone watchOS app** — independent app needs its own sync story. Pair-only Watch app reuses iPhone CloudKit context.
- **No StandBy-specific widget** — `.systemSmall` rotates into StandBy automatically; building a dedicated StandBy view is a wasted target.
- **No Genmoji shipping until iOS 18 migration is approved** — gating a feature on a deployment-target change you haven't decided on yet creates blocking dependencies.
