# Engineering: Performance Benchmarker Findings

## TL;DR
Every primary tab (`DashboardView`, `HistoryView`, `InsightsView`, `FinanceTabView`, `MonthlyWrappedShell`) loads **the entire `Transaction` table unfiltered** via `@Query(sort: \Transaction.date, order: .reverse)`; with no SwiftData indexes, app launch and tab-switch latency degrade linearly with lifetime transaction count and will become the #1 user-visible perf regression by the 12-month mark.

## Top 3 Opportunities (Ranked)

1. **Predicate-bounded `@Query` refactor across 7 views** — every view should query the current/visible budget period only via `#Predicate<Transaction> { $0.date >= start && $0.date < end }`. Currently unbounded at: `DashboardView.swift:22`, `HistoryView.swift:11`, `InsightsView.swift:11`, `FinanceTabView.swift:14` & `:577`, `RecurringExpenseListView.swift:9`, `TransactionEntryView.swift:18`. With `@Query` re-evaluating on every insert and feeding 4–6 tabs at once, an N=10k user pays the full 10k cost on every keystroke in HistoryView search. Effort: 2 days. Impact: 5–10× faster tab switches at scale, no schema migration needed.

2. **Ship `BudgetVaultSchemaV2` with `#Index` annotations** — checklist already exists at `BudgetVaultSchemaV1.swift:4–39`. Required indexes: `Transaction(date)`, `Transaction(category, date)`, `Transaction(isIncome, date)`, `Budget(year, month)`, `RecurringExpense(isActive, nextDueDate)`. Today every `spentCents(in:)` call is O(n) over the whole transaction relationship. Blocked on iOS 18 deployment target — pair with the predicate refactor in v3.3. Effort: 1 day + lightweight migration. Impact: O(log n) range queries, fixes Wrapped/Insights stalls.

3. **Cache `Category.spentCents(in:)` per render pass** — called repeatedly inside `MonthlyWrappedView` (`:34, :118–124, :147–151`), `Budget.totalSpentCents()` (`Schema:93`), and chip lists. Each call re-filters the whole `transactions` relationship. A `[UUID: Int64]` map computed once in `.task` (DashboardView already does this at `:86`) brings this to O(1) lookups in the body. Effort: 4 hours. Impact: kills Wrapped slide jank.

## Top 3 Risks / Debt Items

1. **`MonthlyWrappedView` body does heavy work synchronously** — `dailySpending` (`:54`) iterates all period tx, `top3Categories` (`:118`), `sortedCategories` (`:147`), and `zeroSpendDays` (`:153`) each re-walk inside a `TabView`. Combined with 5 slides and animations, expect frame drops on iPhone 12 and below at >500 tx/month. No memoization.

2. **`HistoryView` re-recomputes on every `allTransactions.count` change** — `:223` triggers a full `recomputeFilteredTransactions` (filter + sort + group) for every transaction inserted anywhere in the database, even from a different month. Combined with sticky-Today and `cachedGroupedByDay` rebuild, edits in remote periods stall the UI.

3. **`scheduleEveningCloseVault` (`NotificationService.swift:115–138`) is fire-and-forget without error logging** and called on every foreground (`BudgetVaultApp.swift:134`). The `getPendingNotificationRequests` callback hops threads but has no Logger; failures are silent. Low CPU cost but high debuggability cost.

## Quick Wins (<1 day each)

- Add `descriptor.fetchLimit = 50` to the `@Query` for `recentTransactions` in `DashboardView` and `TransactionEntryView` (MRU chips only need 20).
- Replace `allTransactions.count` change-listener in `HistoryView:223` with `.onReceive` of a `ModelContext` save publisher scoped to the period.
- Memoize `BudgetRingView`'s `progress` computation; it currently re-stamps `withAnimation` on parent recompute (`BudgetRingView.swift:39`).
- Add `.drawingGroup()` to the `VaultDialMark` ring glow stack (`VaultDialMark.swift:22–48`) — 12-tick `ForEach` + blur composites every frame.
- Move `ImageRenderer` calls in `MonthlyWrappedView:820`, `:848`, and `InsightsView:633` off the main thread via `await MainActor.run` inside a detached task; today they block the UI for 200–800ms on share.
- Cancel `BGAppRefreshTaskRequest` in `applicationWillTerminate` to avoid stale registrations (`BudgetVaultApp.swift:151`).

## Long Bets (>2 weeks but transformative)

- **Materialize per-period spend rollups** — a tiny `BudgetPeriodCache` model (cents per category, per day) updated on transaction CRUD makes Wrapped + Insights + Dashboard O(1) regardless of lifetime tx count. Required before partner sharing (CKShare amplifies query cost).
- **Move ML compute (`InsightsView.computeMLResults`) into a `BackgroundTask` actor** so anomaly + forecast jobs run during background refresh, not on `.task` appear. Eliminates the 1–2s Insights-tab stall.

## What NOT to Do

- **Do not split the SwiftData store per-period.** Considered as a way to bound queries, but it breaks `@Relationship` cascade and CloudKit sync. Indexes + predicates achieve 95% of the benefit with zero data-model risk.
- **Do not add image caching for share cards.** They are user-triggered, one-shot renders; an LRU cache would inflate memory for no observable win.
- **Do not pre-warm `@Query` in `BudgetVaultApp.init`.** Fetching at scene-init time blocks first-frame; SwiftData's lazy fetch on first body pass is correct here — fix the predicates instead.
