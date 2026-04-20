# Engineering: Software Architecture Findings

## TL;DR
The codebase is a SwiftUI/SwiftData "fat-View" monolith with no service-injection boundary; before partner sharing or iPad ship, you need a `BudgetRepository` seam, a `PremiumGate` type, and a `Shared` Swift package — without these, every future feature pays compounding interest.

## Top 3 Opportunities (Ranked)

1. **Introduce a `BudgetRepository` protocol + `BudgetPeriodViewModel`** (3–5 days, high impact). Today every screen owns its own unbounded `@Query` — `DashboardView.swift:20-23`, `HistoryView.swift:10-11`, `InsightsView.swift:9-11`, `BudgetView.swift:10`, `FinanceTabView.swift:13-15`, `SettingsView.swift:667` all fetch *all* budgets and *all* transactions and filter in memory. `Category.spentCents(in:)` then walks `transactions ?? []` per call (Schema:146). At 5,000 tx this is fine; at 50,000 + Live Activity ticks it is not. Wrapping reads in a repository (a) creates the test seam Swift unit tests need so that `BudgetVaultTests/` can grow past 553 lines of pure-utility tests, (b) enables a single place to add the deferred `@Attribute(.index)` work, and (c) is a precondition for iPad split-view (which renders two of these heavy views simultaneously).

2. **Extract a `Shared` Swift Package + collapse the Widget data duplication** (2 days, high impact). `WidgetDataService.WidgetData` (Services:10) and `WidgetBudgetData` (Widget:7) are identical structs hand-maintained in two targets — App Intents already had to reach back into `WidgetDataService.WidgetData` from the main app (BudgetAppIntents:39), which silently couples Intents to the app target rather than the widget. A `BudgetVaultShared` SPM module containing `BudgetActivityAttributes`, `WidgetData`, `CurrencyFormatter`, `MoneyHelpers`, `AppStorageKeys`, and the new repository protocol would (a) unblock a Watch target (which cannot import the app), (b) prevent the next codec drift bug, (c) let the Live Activity & Widget ship UI updates without rebuilding the main app.

3. **Centralize premium gating in a `PremiumGate` enum** (1 day, high leverage). `@AppStorage(AppStorageKeys.isPremium)` is read in 16 view files with hardcoded numerics scattered everywhere: `>= 6` categories at `BudgetView.swift:517,561`, `>= 3` recurring at `RecurringExpenseListView.swift:49,133`, `> 4` import categories at `CSVImportView.swift:246,266`. There is no single source for the free-tier matrix, so a price-tier change ($14.99 → $24.99 partner tier) means a 16-file sweep with no compiler help. A `PremiumGate.canAddCategory(count:)` returning `.allowed | .blocked(reason:)` makes tier rules diff-able and unit-testable.

## Top 3 Risks / Debt Items

1. **VersionedSchema V2 plan is documented (Schema:1-39) but `BudgetVaultMigrationPlan.stages` is empty (Schema:441)** — the V1→V2 path has never been exercised. Add an empty-stages V2 with one trivial field now (in iOS 17 form, indexes guarded by `#if`) so the migration mechanism is proven before iOS 18 forces it.
2. **CKShare / partner sharing is architecturally blocked** by the current schema. `Budget` has no `ownerID`; `@Relationship` cascades from `Budget→Category→Transaction` mean a shared budget would drag *all* a user's transactions into the share zone. Partner sharing requires a sharing-root model and explicit zone partitioning — design before V2 is locked.
3. **`BudgetVaultApp.performMonthRollover` (App.swift:222) and `deduplicateBudgets` (App.swift:310) are 117 lines of business logic in `@main`** with no test coverage — exactly the code that breaks during DST/locale edge cases. Move into a testable `BudgetRolloverService`.

## Quick Wins (<1 day each)
- Delete `WidgetBudgetData` duplicate; have widget import the shared struct via App Group bundle resource or an `@_implementationOnly` shared target.
- Replace `NotificationCenter.default.post(.openTransactionEntry)` (AppIntents:24, App.swift:20,29) with a `@Observable RouterStore` — current pattern is untestable and breaks under SwiftUI scene restoration.
- Add `Sendable` conformance to `WidgetData` and `BudgetActivityAttributes.ContentState` (already `Codable, Hashable`) ahead of Swift 6 strict concurrency.
- Move `AppStorageKeys.isPremium` reads behind one `@Observable EntitlementStore` so debug overrides flow through one path, not two (StoreKitManager:154-159 vs view-level `@AppStorage`).

## Long Bets (>2 weeks but transformative)
- Modularize into SPM packages: `Shared`, `Persistence` (repositories + Schema), `Features/{Dashboard,Budget,Insights,Finance}`, `Premium`. Enables parallel feature work, slashes incremental build times, and is the only sane substrate for an iPad two-pane layout, a Watch target, and partner sharing.
- Replace per-view in-memory aggregation with materialized `BudgetSnapshot` rows updated on transaction write — the same data the widget consumes — so dashboard, widget, Live Activity, and Siri all read one source.

## What NOT to Do
- Do **not** introduce TCA, Redux, or a DI container. The MVVM-with-services pattern is fine; the gap is *seams*, not paradigms. Adding a framework now ossifies bad boundaries.
- Do **not** migrate money to `Decimal` "for correctness" — Int64 cents is correct and SwiftData-safe (per project memory). Resist the temptation.
- Do **not** ship CKShare on top of the current schema. Without a sharing root and zone-aware models, you will leak every transaction into the partner's iCloud.
- Do **not** raise iOS deployment target to 18 just to get `#Index` — the migration plan should land on iOS 17 first; indexes are an additive V2 stage when ready.
