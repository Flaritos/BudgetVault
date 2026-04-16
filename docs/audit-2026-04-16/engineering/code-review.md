# Engineering: Code Review Findings

## TL;DR
The codebase is solid (no force-unwraps in business logic, no `try!`, no `fatalError` in production paths, consistent `SafeSave` save/rollback discipline), but it carries three real risks: unbounded `@Query` fetches in five major Views, `deduplicateBudgets` duplicated and divergent across two files, and a `StreakService` `freezes` reset that can silently grant infinite freezes if the app misses a Monday foreground.

## Top 3 Opportunities (Ranked)
1. **@Query predicate refactor (1–2 days, high impact).** `DashboardView.swift:22`, `HistoryView.swift:11`, `InsightsView.swift:11`, `TransactionEntryView.swift:18`, `Finance/FinanceTabView.swift:14` all load `@Query(sort: \Transaction.date, order: .reverse)` with no predicate. Every render hydrates the entire transaction store. The TODOs (e.g. `InsightsView.swift:10`) explicitly defer this. Add `#Predicate { $0.date >= start && $0.date < end }` per view; cuts memory and SwiftData diff cost on power users with months of history.
2. **Decompose Dashboard + History (~3 days, maintainability).** `DashboardView.swift` is 1737 LOC, `HistoryView.swift` 895 LOC, `MonthlyWrappedView.swift` 877 LOC, `BudgetView.swift` 777 LOC. `TransactionEntryView.swift` was already split (671 LOC, 9 sub-views — the playbook works). Apply the same pattern to Dashboard before another feature lands and the type checker times out again.
3. **Single source of truth for budget dedup (4 hours, correctness).** `BudgetVaultApp.swift:310` and `CloudSyncService.swift:46` both implement `deduplicateBudgets`, and they differ — the app version reassigns transactions on category-name match (`:325`); the CloudSync version does not, and silently leaks transactions when names collide (`CloudSyncService.swift:57-62`). Extract one canonical `BudgetDedupService.deduplicate(context:)` and call it from both sites.

## Top 3 Risks / Debt Items
1. **`StreakService.processOnForeground` freeze logic is fragile.** `StreakService.swift:18` resets `freezes = 1` only when `weekday == 2` AND `lastFreezeReset != todayStr`. If the user opens the app every Monday, fine — but the `lastFreezeReset` write at `:21` happens inside the `if`, so a user who never opens on Monday never resets. Worse, the `if freezes > 0` branch at `:33` decrements but never refills, so a user who opens daily Tue–Sun for weeks can accumulate the original Monday freeze indefinitely. Replace with "freezes available this week = 1 if no freeze used in current ISO week."
2. **`AchievementService` rewards on a snapshot, not history.** `AchievementService.swift:116-127` checks `remainingCents >= 10000/50000/100000` against the current in-progress month's `budget.remainingCents`. A user mid-month with a $100 budget and $0 logged passes the `saved_100` check on day 1 — these "saving" achievements unlock before any saving has happened. Gate behind `isCompletedMonth` like the `under_budget_*` block at `:89` already does.
3. **Two places reset `wipeSwiftData` without the full model list.** `UITestSeedService.swift:66` enumerates 6 model types but omits `NetWorthAccount` and `NetWorthSnapshot` from the schema (`BudgetVaultSchemaV1.swift:46`). Test runs leave these tables dirty between launches. Either drop those tables from the schema (they're already removed from the product per memory) or include them in the wipe list.

## Quick Wins (<1 day each)
- `StoreKitManager.swift:88` — replace `print(...)` with the `Logger` already used in `BudgetLiveActivityService.swift:9` and `SafeSave.swift:5`. Production logs go to the Apple void.
- `NotificationService.scheduleWeeklySummary()` (no-arg) at `:214` is dead — the only call site is the data-aware overload at `:174`. Delete.
- `InsightsEngine.swift:97` — `calendar.date(byAdding: .day, value: daysSoFar, to: prev.periodStart)!` is the only force-unwrap in the engine. Wrap with `?? prev.nextPeriodStart`.
- `DebugSeedService.swift:225` — same `!` pattern. DEBUG-only, but easy to fix.
- `CSVImporter.parse(csv:)` at `:36` splits on `.newlines` only; CSV cells with embedded newlines inside quotes (the very case `parseCSVLine` handles) get truncated. Switch to a streaming line scanner that respects quote state.
- `CSVImporter.swift:148` uses `(row.amount * 100).rounded()` — Double rounding error on common bank exports (e.g. `19.99 * 100 = 1998.9999999`). Use `Decimal` parse + `*100` then `Int64`.
- `BudgetLiveActivityService.swift:25` reads `Activity.activities.first` — assumes only one activity exists. If the activity ever fails to end (app force-quit before `endAll`), `start` skips silently. Add a stale-period check: end the existing one if its `periodEndDate` is past.
- `ChatOnboardingView.swift` (975 LOC) — flag for split before localization work begins.

## Long Bets (>2 weeks but transformative)
- **Move money out of the View layer.** Computed properties like `Budget.totalSpentCents()` walk every category's transactions on every SwiftUI invalidation. Add a `BudgetCalculator` actor that memoizes per (budgetID, txCount, lastTxDate) — would unlock 60fps scrolling on 1000+ transaction histories and fix the rendering cost that the @Query refactor only half-addresses.
- **Schema V2 with indexes (per the migration checklist at `BudgetVaultSchemaV1.swift:4`).** Blocked on iOS 18 deployment target. When that lands, the indexes are an afternoon's work and are already specified. Pair with the @Query predicate refactor for compounding wins.

## What NOT to Do
- Don't introduce a generic dependency-injection container — current `enum Service` static-method pattern (NotificationService, StreakService, CSVImporter) is testable and idiomatic for this app size.
- Don't migrate `Int64` cents to `Decimal` — explicit memory rule and SwiftData has historically corrupted `Decimal`. The current discipline is good; keep it.
- Don't add `@Observable` to `Budget`/`Category` — they're SwiftData `@Model`, which is already observable. Wrapping doubles the invalidation work.
- Don't refactor `CategoryLearningService` to SwiftData — UserDefaults JSON blob (`CategoryLearningService.swift:51`) is fine at <100KB and avoids a schema migration for a non-critical feature.
