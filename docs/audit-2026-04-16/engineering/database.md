# Engineering: SwiftData Schema & Query Audit

## TL;DR
The schema is sound (Int64 cents, VersionedSchema, no `#Unique`) but every hot view does an unbounded `@Query` on the entire `Transaction` table and then filters in Swift — a guaranteed perf cliff at ~5K rows that v3.3 (split tx, tags, partner sharing) will accelerate.

## Top 3 Opportunities (Ranked)
1. **Bump min target to iOS 18 + ship SchemaV2 with `#Index`** — the inline checklist in `BudgetVaultSchemaV1.swift:4-39` already enumerates the exact indexes needed (`Transaction.date`, `(category, date)`, `(isIncome, date)`, `Budget.(year, month)`, `RecurringExpense.(isActive, nextDueDate)`, `DebtPayment.date`, `NetWorthSnapshot.date`). Lightweight additive migration, ~1 day, fixes the dashboard/history/insights perf ceiling permanently. **High impact, low effort.**
2. **Predicate-bound `@Query` on the 8 unbounded views** — `DashboardView.swift:22`, `HistoryView.swift:11`, `InsightsView.swift:11`, `TransactionEntryView.swift:18`, `RecurringExpenseListView.swift:9`, `FinanceTabView.swift:14,577` all fetch ALL transactions. With iOS 18's `@Query(filter:)` accepting runtime values, scope each to `date >= currentBudget.periodStart && date < currentBudget.nextPeriodStart`. Pair with `fetchLimit` for "recent N" callsites. **Medium effort, eliminates O(N) view-render cost.**
3. **Schema V2 design for v3.3 features now** — split transactions, tags, and partner sharing each add fields. Land the empty-V2 stage in v3.3.0 (no field changes, just the migration plumbing in `BudgetVaultMigrationPlan.stages`) so future custom migrations don't ship as a single risky monolith.

## Top 3 Risks / Debt Items
1. **Aggregates computed in Swift, not predicates.** `Budget.totalSpentCents()` (line 92), `Category.spentCents(in:)` (line 146), and the `(transactions ?? []).filter{...}.reduce` pattern force materialization of every Transaction relationship per render. With CloudKit-mandated optionality these arrays can be huge. Move to `fetchCount` / aggregate `FetchDescriptor` with sum predicates where possible, or memoize per-budget on the ViewModel.
2. **Inverse relationship asymmetry.** `Transaction.recurringExpense` declares `@Relationship(inverse: \RecurringExpense.generatedTransactions)` (line 213) but `RecurringExpense.generatedTransactions` (line 245) ALSO declares `@Relationship(deleteRule: .nullify)` without naming an inverse — this is a duplicate-inverse hazard SwiftData has been known to corrupt under CloudKit. Pick ONE side to own the inverse declaration. Same risk pattern across all 5 relationships — audit them.
3. **No soft-delete / no undo.** `modelContext.delete(...)` is called in 8 places (HistoryView swipe, TransactionEditView, DebtDetailView, RecurringExpenseFormView, etc.) with zero undo affordance. Onboarding-grade users will lose data. Add `isDeleted: Bool` + `deletedAt: Date?` on Transaction (and exclude from queries) to enable a "Recently Deleted" view and 30-day purge — also a CloudKit win since hard deletes there are race-prone.

## Quick Wins (<1 day each)
- Add `fetchLimit: 50` to `TransactionEntryView`'s `allRecentTransactions` query — the view only shows MRU chips.
- Replace `BudgetVaultApp.swift:227` linear "find latest budget" with the existing `FetchDescriptor<Budget>` already declared right below it (currently fetches ALL budgets just to take `.first`).
- `CSVImporter.swift:156` dedup predicate compares `date == txDate` AND date-range bounds — the bounds are redundant when equality is used; drop them to let SQLite pick a tighter plan.
- Add `Category.budget` index column once iOS 18 lands — it's the join key for every per-budget category query.
- Document the "every model field needs a default" rule in the schema file header (CloudKit-readiness gate; already followed but undocumented).

## Long Bets (>2 weeks but transformative)
- **CKShare partner sharing** requires every model to be CloudKit-clean: review optionals, drop any future `#Unique` temptation, ensure no orphaned inverse, ship a CloudKit-zone test harness. Best done as a v3.3 SchemaV2 effort bundled with #1 above.
- **Move `InsightsEngine` aggregations to a background ModelActor** — current dashboard render is on MainActor with synchronous reduces. Concurrency win + unblocks larger transaction histories.

## What NOT to Do
- **Don't add `#Unique` macro** — known to break CloudKit (already in MEMORY rules).
- **Don't normalize Category across budgets.** The current "Category duplicated per Budget" model is awkward but it's what makes monthly rollover/history navigation cheap; normalizing would force every historical query to join + time-filter. Spec already chose this trade-off (`01_BudgetVault_Spec.md:42`).
- **Don't migrate money to `Decimal`** — confirmed corruption risk in MEMORY; Int64 cents is correct.
- **Don't precompute `spentCents` into a stored field** — invalidation on every transaction edit/delete is a sync nightmare; index + predicate is the right fix.

---
Findings written to `/Users/zachgold/Claude/BudgetVault/docs/audit-2026-04-16/engineering/database.md`.
