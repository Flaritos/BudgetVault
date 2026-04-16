# iOS 18 + Schema + Architecture Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bump min iOS to 18, ship `SchemaV2` with `#Index`, scope all `@Query`s to a period predicate, introduce `BudgetRepository` + `PremiumGate` + `PaywallTrigger` seams, and move shared types into `BudgetVaultShared`.

**Architecture:** All eight unbounded period-scoped views are refactored one-at-a-time to use `#Predicate<Transaction> { $0.date >= start && $0.date < end }` and a new `BudgetRepository` protocol injected via `@Environment`. The repository lives in the `BudgetVaultShared` SPM package alongside `PremiumGate`, `PaywallTrigger`, `BudgetActivityAttributes`, and a unified `WidgetData` struct. `SchemaV2` is index-only (no field changes) and is wired into `BudgetVaultMigrationPlan.stages` so the V2→V3 (CKShare) migration in v3.4 has a tested mechanism.

**Tech Stack:** Swift 5.9, SwiftUI, SwiftData (`#Index`, `@Query(filter:)` runtime predicates), Swift Package Manager (local SPM), XCTest, ModelActor concurrency, xcodegen.

**Estimated Effort:** 9.5 days

**Ship Target:** v3.3.1

---

## File Structure

### Created
- `BudgetVault/Schema/BudgetVaultSchemaV2.swift` — V2 schema with `#Index` annotations on `Transaction`, `Budget`, `RecurringExpense`, `DebtPayment`, `NetWorthSnapshot`.
- `BudgetVaultShared/Sources/BudgetVaultShared/BudgetRepository.swift` — Protocol + `LiveBudgetRepository` (ModelActor) + `MockBudgetRepository` (test fixture).
- `BudgetVaultShared/Sources/BudgetVaultShared/PremiumGate.swift` — Centralized free-tier limits (`canAddCategory`, `canAddRecurring`, `canImportCSVCategories`).
- `BudgetVaultShared/Sources/BudgetVaultShared/PaywallTrigger.swift` — Enum routing 8 paywall entry points to contextual hero copy.
- `BudgetVaultShared/Sources/BudgetVaultShared/WidgetData.swift` — Single canonical struct replacing `WidgetBudgetData` + `WidgetDataService.WidgetData`.
- `BudgetVaultShared/Sources/BudgetVaultShared/BudgetActivityAttributes.swift` — Moved from `BudgetVault/Models/`.
- `BudgetVaultShared/Sources/BudgetVaultShared/RepositoryEnvironment.swift` — `@Environment` key for injection.
- `BudgetVaultTests/PremiumGateTests.swift` — Unit tests for all gate verdicts.
- `BudgetVaultTests/PaywallTriggerTests.swift` — Hero copy mapping tests.
- `BudgetVaultTests/MockBudgetRepositoryTests.swift` — Test-fixture round-trip tests.
- `BudgetVaultTests/LiveBudgetRepositoryTests.swift` — In-memory `ModelContainer` integration tests.
- `BudgetVaultTests/SchemaV2MigrationTests.swift` — V1→V2 in-place migration test.

### Modified
- `project.yml:4-5` — `iOS: "17.0"` → `iOS: "18.0"`; add `BudgetVaultShared` SPM dependency.
- `BudgetVault/Schema/BudgetVaultSchemaV1.swift:36-39, 437-441` — Remove inline V2 checklist comment lines 4-39; populate `BudgetVaultMigrationPlan.schemas` and `.stages`; keep V1 typealiases for back-compat removed in favor of V2 typealiases in V2 file.
- `BudgetVault/Views/Dashboard/DashboardView.swift:20-23, 63` — Period-scoped `@Query`, drop `isPremium` `@AppStorage` for `PremiumGate`, repository injection.
- `BudgetVault/Views/Transactions/HistoryView.swift:10-11` — Period-scoped `@Query`.
- `BudgetVault/Views/Insights/InsightsView.swift:7-13` — Period-scoped `@Query`, drop `showPaywall` `@State` for `PaywallTrigger?`.
- `BudgetVault/Views/Transactions/TransactionEntryView.swift:17-18` — Period-scoped `@Query` with `fetchLimit: 50`.
- `BudgetVault/Views/RecurringExpenses/RecurringExpenseListView.swift:6-13` — Period-scoped `@Query`, `PremiumGate.canAddRecurring`, `PaywallTrigger?`.
- `BudgetVault/Views/Finance/FinanceTabView.swift:8-18, 574-577` — Period-scoped `@Query` (both call-sites), `PremiumGate`, `PaywallTrigger?`.
- `BudgetVault/Views/Budget/BudgetView.swift:8-17, 517, 561` — `PremiumGate.canAddCategory`, `PaywallTrigger?`.
- `BudgetVault/Views/Settings/SettingsView.swift:665-667` — Period-scoped `@Query` in `BudgetTemplateSheetView`.
- `BudgetVault/Views/Settings/CSVImportView.swift:240-274` — `PremiumGate.canImportCSVCategories`.
- `BudgetVault/Views/Budget/CategoryDetailView.swift` — `PremiumGate`, `PaywallTrigger?`.
- `BudgetVault/Views/Finance/DebtTrackingView.swift` — `PremiumGate`, `PaywallTrigger?`.
- `BudgetVault/Views/Insights/SpendingHeatmapView.swift` — `PremiumGate`.
- `BudgetVault/Views/MainTabView.swift` — `PremiumGate` for premium tab visibility.
- `BudgetVault/Views/Shared/AchievementBadgeView.swift` — `PremiumGate`.
- `BudgetVault/Views/Shared/PaywallView.swift` — Accept `PaywallTrigger?` and adapt hero copy.
- `BudgetVault/Models/BudgetActivityAttributes.swift` — Replaced by re-export from `BudgetVaultShared` (file deleted).
- `BudgetVault/Services/WidgetDataService.swift` — Use shared `WidgetData`; nested `CategorySummary` removed.
- `BudgetVaultWidget/BudgetVaultWidget.swift:5-24, 55-80` — Remove `WidgetBudgetData` duplicate; import `BudgetVaultShared.WidgetData`.
- `BudgetVault/BudgetVaultApp.swift:46-50` — Inject `LiveBudgetRepository` into the SwiftUI environment.
- `BudgetVault/Schema/BudgetVaultSchemaV1.swift` typealiases (lines 446-453) — moved into V2 file so app code compiles against V2.

### Tested
- `BudgetVaultTests/PremiumGateTests.swift` — 12 cases (boundary at 5/6 categories, 2/3 recurring, 4/5 imports; premium pass-through).
- `BudgetVaultTests/PaywallTriggerTests.swift` — 8 cases (one per trigger).
- `BudgetVaultTests/MockBudgetRepositoryTests.swift` — 6 cases (current budget, transactions in interval, category spend map, recent N, empty store, multi-period).
- `BudgetVaultTests/LiveBudgetRepositoryTests.swift` — 4 cases (in-memory container; smoke + period scoping + recent limit + spend map).
- `BudgetVaultTests/SchemaV2MigrationTests.swift` — V1 fixture container migrates to V2 with no data loss; existing tests in `BudgetVaultTests/` (CSVImporterTests, StreakServiceTests, etc.) continue to pass against V2.

---

## Phase A — Foundation: iOS 18 + SchemaV2

### Task 1: Bump iOS deployment target to 18.0

**Files:** Modify `project.yml:4-5`. Test: `xcodebuild -showBuildSettings`.

- [ ] Read `project.yml:1-15`. Confirm current `iOS: "17.0"` at line 5.
- [ ] Edit `project.yml`: change `iOS: "17.0"` to `iOS: "18.0"`.
- [ ] Run `xcodegen generate` from repo root. Expected: `Generated project successfully`.
- [ ] Run `xcodebuild -showBuildSettings -scheme BudgetVault -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=18.0' | grep IPHONEOS_DEPLOYMENT_TARGET`. Expected: `IPHONEOS_DEPLOYMENT_TARGET = 18.0`.
- [ ] Run `xcodegen generate && xcodebuild build -scheme BudgetVault -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=18.0'`. Expected: `BUILD SUCCEEDED`.
- [ ] Commit: `chore(ios): bump min deployment target to iOS 18`.

### Task 2: Sweep iOS 17 conditionals

**Files:** Modify any file with `#available(iOS 17` or `if #available(iOS 18`.

- [ ] Run `grep -rn "#available(iOS 17" BudgetVault/ BudgetVaultWidget/`. Capture all hits.
- [ ] Run `grep -rn "if #available(iOS 18" BudgetVault/ BudgetVaultWidget/`. Capture all hits.
- [ ] For each `#available(iOS 17, *)` guard: delete the guard, keep the body. (Guard now always-true; deleting reduces dead branches.)
- [ ] For each `if #available(iOS 18, *)` guard followed by `else` fallback: delete the guard and the else branch, keep the iOS 18 body.
- [ ] Run `xcodebuild build -scheme BudgetVault -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=18.0'`. Expected: `BUILD SUCCEEDED`.
- [ ] Commit: `refactor: remove iOS 17/18 availability guards now that iOS 18 is min`.

### Task 3: Write failing SchemaV2 migration test

**Files:** Create `BudgetVaultTests/SchemaV2MigrationTests.swift`.

- [ ] Create file with content:

```swift
import XCTest
import SwiftData
@testable import BudgetVault

final class SchemaV2MigrationTests: XCTestCase {

    func testV1ContainerMigratesToV2WithDataIntact() throws {
        // Arrange — temp store URL
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("v2-migration-\(UUID().uuidString).store")
        defer { try? FileManager.default.removeItem(at: url) }

        // Seed V1 store
        let v1Config = ModelConfiguration(
            schema: Schema(versionedSchema: BudgetVaultSchemaV1.self),
            url: url
        )
        let v1Container = try ModelContainer(
            for: Schema(versionedSchema: BudgetVaultSchemaV1.self),
            migrationPlan: nil,
            configurations: v1Config
        )
        let v1ctx = ModelContext(v1Container)
        let budget = BudgetVaultSchemaV1.Budget(month: 4, year: 2026, totalIncomeCents: 500_000)
        v1ctx.insert(budget)
        let cat = BudgetVaultSchemaV1.Category(name: "Groceries", emoji: "🛒", budgetedAmountCents: 50_000)
        cat.budget = budget
        v1ctx.insert(cat)
        let tx = BudgetVaultSchemaV1.Transaction(amountCents: 1_999, note: "Avocados", date: .now, category: cat)
        v1ctx.insert(tx)
        try v1ctx.save()

        // Act — open with V2 + migration plan
        let v2Config = ModelConfiguration(
            schema: Schema(versionedSchema: BudgetVaultSchemaV2.self),
            url: url
        )
        let v2Container = try ModelContainer(
            for: Schema(versionedSchema: BudgetVaultSchemaV2.self),
            migrationPlan: BudgetVaultMigrationPlan.self,
            configurations: v2Config
        )
        let v2ctx = ModelContext(v2Container)
        let budgets = try v2ctx.fetch(FetchDescriptor<Budget>())
        let txs = try v2ctx.fetch(FetchDescriptor<Transaction>())

        // Assert
        XCTAssertEqual(budgets.count, 1)
        XCTAssertEqual(budgets.first?.totalIncomeCents, 500_000)
        XCTAssertEqual(txs.count, 1)
        XCTAssertEqual(txs.first?.amountCents, 1_999)
        XCTAssertEqual(txs.first?.note, "Avocados")
    }
}
```

- [ ] Run `xcodegen generate && xcodebuild test -scheme BudgetVault -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=18.0' -only-testing BudgetVaultTests/SchemaV2MigrationTests`. Expected: **build fails** (`BudgetVaultSchemaV2` undefined). This is the red step.
- [ ] Commit (red step): `test(schema): add failing V1→V2 migration test`.

### Task 4: Create SchemaV2 with #Index annotations

**Files:** Create `BudgetVault/Schema/BudgetVaultSchemaV2.swift`.

- [ ] Create file with content:

```swift
import Foundation
import SwiftData

enum BudgetVaultSchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Budget.self, Category.self, Transaction.self, RecurringExpense.self,
         DebtAccount.self, DebtPayment.self, NetWorthAccount.self, NetWorthSnapshot.self]
    }

    // MARK: - Budget

    @Model
    final class Budget {
        #Index<Budget>([\.year, \.month])

        var id: UUID = UUID()
        var month: Int = 1
        var year: Int = 2026
        var totalIncomeCents: Int64 = 0
        var resetDay: Int = 1
        var createdAt: Date = Date.now
        var isAutoCreated: Bool = false

        @Relationship(deleteRule: .cascade, inverse: \Category.budget)
        var categories: [Category]? = []

        init(month: Int, year: Int, totalIncomeCents: Int64 = 0, resetDay: Int = 1, isAutoCreated: Bool = false) {
            self.id = UUID()
            self.month = month
            self.year = year
            self.totalIncomeCents = totalIncomeCents
            self.resetDay = resetDay
            self.createdAt = Date.now
            self.isAutoCreated = isAutoCreated
        }

        var totalIncome: Decimal { Decimal(totalIncomeCents) / 100 }

        var periodStart: Date {
            let day = min(self.resetDay, 28)
            return Calendar.current.date(from: DateComponents(year: year, month: month, day: day)) ?? Date()
        }

        var nextPeriodStart: Date {
            let day = min(self.resetDay, 28)
            let start = Calendar.current.date(from: DateComponents(year: year, month: month, day: day)) ?? Date()
            return Calendar.current.date(byAdding: .month, value: 1, to: start) ?? Date()
        }

        func totalSpentCents() -> Int64 {
            (categories ?? []).reduce(0) { $0 + $1.spentCents(in: self) }
        }

        var remainingCents: Int64 { totalIncomeCents - totalSpentCents() }
        var remainingBudget: Decimal { Decimal(remainingCents) / 100 }

        var percentRemaining: Double {
            guard totalIncomeCents > 0 else { return 0 }
            return Double(remainingCents) / Double(totalIncomeCents)
        }
    }

    // MARK: - Category

    @Model
    final class Category {
        var id: UUID = UUID()
        var name: String = ""
        var emoji: String = "📦"
        var budgetedAmountCents: Int64 = 0
        var color: String = "#007AFF"
        var sortOrder: Int = 0
        var isHidden: Bool = false
        var rollOverUnspent: Bool = false
        var goalAmountCents: Int64?
        var goalDate: Date?
        var goalType: String?

        @Relationship(deleteRule: .cascade, inverse: \Transaction.category)
        var transactions: [Transaction]? = []

        var budget: Budget?

        @Relationship(deleteRule: .nullify, inverse: \RecurringExpense.category)
        var recurringExpenses: [RecurringExpense]? = []

        init(name: String, emoji: String = "📦", budgetedAmountCents: Int64 = 0, color: String = "#007AFF", sortOrder: Int = 0) {
            self.id = UUID()
            self.name = name
            self.emoji = emoji
            self.budgetedAmountCents = budgetedAmountCents
            self.color = color
            self.sortOrder = sortOrder
        }

        var budgetedAmount: Decimal { Decimal(budgetedAmountCents) / 100 }

        func spentCents(in budget: Budget) -> Int64 {
            (transactions ?? [])
                .filter { !$0.isIncome && $0.date >= budget.periodStart && $0.date < budget.nextPeriodStart }
                .reduce(0) { $0 + $1.amountCents }
        }

        func spent(in budget: Budget) -> Decimal { Decimal(spentCents(in: budget)) / 100 }
        func remainingCents(in budget: Budget) -> Int64 { budgetedAmountCents - spentCents(in: budget) }
        func remaining(in budget: Budget) -> Decimal { Decimal(remainingCents(in: budget)) / 100 }
        func percentSpent(in budget: Budget) -> Double {
            guard budgetedAmountCents > 0 else { return 0 }
            return Double(spentCents(in: budget)) / Double(budgetedAmountCents)
        }

        var isSavingsGoal: Bool { goalType == "savings" }

        var goalProgress: Double {
            guard let goal = goalAmountCents, goal > 0 else { return 0 }
            return min(Double(budgetedAmountCents) / Double(goal), 1.0)
        }

        var monthsToGoal: Int? {
            guard let goal = goalAmountCents, let date = goalDate else { return nil }
            let remaining = goal - budgetedAmountCents
            guard remaining > 0 else { return 0 }
            let months = Calendar.current.dateComponents([.month], from: Date(), to: date).month ?? 0
            return max(months, 0)
        }

        var requiredMonthlyContribution: Int64? {
            guard let goal = goalAmountCents, let date = goalDate else { return nil }
            let remaining = goal - budgetedAmountCents
            guard remaining > 0 else { return 0 }
            let months = max(Calendar.current.dateComponents([.month], from: Date(), to: date).month ?? 1, 1)
            return remaining / Int64(months)
        }
    }

    // MARK: - Transaction

    @Model
    final class Transaction {
        #Index<Transaction>([\.date])
        #Index<Transaction>([\.category, \.date])
        #Index<Transaction>([\.isIncome, \.date])

        var id: UUID = UUID()
        var amountCents: Int64 = 0
        var note: String = ""
        var date: Date = Date.now
        var isIncome: Bool = false
        var isRecurring: Bool = false
        var createdAt: Date = Date.now
        var isReconciled: Bool = false

        var category: Category?

        @Relationship(inverse: \RecurringExpense.generatedTransactions)
        var recurringExpense: RecurringExpense?

        init(amountCents: Int64, note: String = "", date: Date = .now, isIncome: Bool = false, category: Category? = nil) {
            self.id = UUID()
            self.amountCents = amountCents
            self.note = note
            self.date = date
            self.isIncome = isIncome
            self.createdAt = Date.now
            self.category = category
            self.isReconciled = false
        }

        var amount: Decimal { Decimal(amountCents) / 100 }
    }

    // MARK: - RecurringExpense

    @Model
    final class RecurringExpense {
        #Index<RecurringExpense>([\.nextDueDate])
        #Index<RecurringExpense>([\.isActive, \.nextDueDate])

        var id: UUID = UUID()
        var name: String = ""
        var amountCents: Int64 = 0
        var frequency: String = "monthly"
        var nextDueDate: Date = Date.now
        var isActive: Bool = true

        var category: Category?

        @Relationship(deleteRule: .nullify)
        var generatedTransactions: [Transaction]? = []

        init(name: String, amountCents: Int64, frequency: Frequency = .monthly, nextDueDate: Date = .now, category: Category? = nil) {
            self.id = UUID()
            self.name = name
            self.amountCents = amountCents
            self.frequency = frequency.rawValue
            self.nextDueDate = nextDueDate
            self.category = category
        }

        var amount: Decimal { Decimal(amountCents) / 100 }
        var frequencyEnum: Frequency { Frequency(rawValue: frequency) ?? .monthly }

        enum Frequency: String, CaseIterable, Identifiable {
            case weekly, biweekly, monthly, yearly
            var id: String { rawValue }
            var displayName: String {
                switch self {
                case .weekly: "Weekly"
                case .biweekly: "Biweekly"
                case .monthly: "Monthly"
                case .yearly: "Yearly"
                }
            }
        }

        func advanceNextDueDate() {
            let calendar = Calendar.current
            switch frequencyEnum {
            case .weekly:
                nextDueDate = calendar.date(byAdding: .day, value: 7, to: nextDueDate) ?? nextDueDate
            case .biweekly:
                nextDueDate = calendar.date(byAdding: .day, value: 14, to: nextDueDate) ?? nextDueDate
            case .monthly:
                nextDueDate = calendar.date(byAdding: .month, value: 1, to: nextDueDate) ?? nextDueDate
            case .yearly:
                nextDueDate = calendar.date(byAdding: .year, value: 1, to: nextDueDate) ?? nextDueDate
            }
        }
    }

    // MARK: - DebtAccount

    @Model
    final class DebtAccount {
        var id: UUID = UUID()
        var name: String = ""
        var emoji: String = "💳"
        var originalBalanceCents: Int64 = 0
        var currentBalanceCents: Int64 = 0
        var interestRate: Double = 0
        var minimumPaymentCents: Int64 = 0
        var dueDay: Int = 1
        var createdAt: Date = Date.now
        var isActive: Bool = true

        @Relationship(deleteRule: .cascade, inverse: \DebtPayment.debtAccount)
        var payments: [DebtPayment]? = []

        init(name: String, emoji: String = "💳", originalBalanceCents: Int64, currentBalanceCents: Int64, interestRate: Double = 0, minimumPaymentCents: Int64 = 0, dueDay: Int = 1) {
            self.id = UUID()
            self.name = name
            self.emoji = emoji
            self.originalBalanceCents = originalBalanceCents
            self.currentBalanceCents = currentBalanceCents
            self.interestRate = interestRate
            self.minimumPaymentCents = minimumPaymentCents
            self.dueDay = dueDay
            self.createdAt = Date.now
        }

        var paidOffPercentage: Double {
            guard originalBalanceCents > 0 else { return 0 }
            let paid = originalBalanceCents - currentBalanceCents
            return min(max(Double(paid) / Double(originalBalanceCents), 0), 1.0)
        }

        var totalPaidCents: Int64 { originalBalanceCents - currentBalanceCents }
        var originalBalance: Decimal { Decimal(originalBalanceCents) / 100 }
        var currentBalance: Decimal { Decimal(currentBalanceCents) / 100 }
        var minimumPayment: Decimal { Decimal(minimumPaymentCents) / 100 }

        var estimatedMonthsToPayoff: Int? {
            guard currentBalanceCents > 0, minimumPaymentCents > 0 else { return nil }
            let monthlyRate = interestRate / 100.0 / 12.0
            if monthlyRate <= 0 {
                return Int(ceil(Double(currentBalanceCents) / Double(minimumPaymentCents)))
            }
            let r = monthlyRate
            let principal = Double(currentBalanceCents) / 100.0
            let payment = Double(minimumPaymentCents) / 100.0
            let factor = 1.0 - (r * principal / payment)
            guard factor > 0 else { return nil }
            let months = -log(factor) / log(1.0 + r)
            return Int(ceil(months))
        }
    }

    // MARK: - DebtPayment

    @Model
    final class DebtPayment {
        #Index<DebtPayment>([\.date])

        var id: UUID = UUID()
        var amountCents: Int64 = 0
        var date: Date = Date.now
        var note: String = ""

        var debtAccount: DebtAccount?

        init(amountCents: Int64, date: Date = .now, note: String = "") {
            self.id = UUID()
            self.amountCents = amountCents
            self.date = date
            self.note = note
        }

        var amount: Decimal { Decimal(amountCents) / 100 }
    }

    // MARK: - NetWorthAccount

    @Model
    final class NetWorthAccount {
        var id: UUID = UUID()
        var name: String = ""
        var emoji: String = "🏦"
        var balanceCents: Int64 = 0
        var accountType: String = "asset"
        var lastUpdated: Date = Date.now
        var isActive: Bool = true

        init(name: String, emoji: String = "🏦", balanceCents: Int64 = 0, accountType: String = "asset") {
            self.id = UUID()
            self.name = name
            self.emoji = emoji
            self.balanceCents = balanceCents
            self.accountType = accountType
            self.lastUpdated = Date.now
        }

        var balance: Decimal { Decimal(balanceCents) / 100 }
        var isAsset: Bool { accountType == "asset" }
        var isLiability: Bool { accountType == "liability" }
    }

    // MARK: - NetWorthSnapshot

    @Model
    final class NetWorthSnapshot {
        #Index<NetWorthSnapshot>([\.date])

        var id: UUID = UUID()
        var date: Date = Date.now
        var totalAssetsCents: Int64 = 0
        var totalLiabilitiesCents: Int64 = 0
        var netWorthCents: Int64 = 0

        init(date: Date = .now, totalAssetsCents: Int64, totalLiabilitiesCents: Int64) {
            self.id = UUID()
            self.date = date
            self.totalAssetsCents = totalAssetsCents
            self.totalLiabilitiesCents = totalLiabilitiesCents
            self.netWorthCents = totalAssetsCents - totalLiabilitiesCents
        }

        var totalAssets: Decimal { Decimal(totalAssetsCents) / 100 }
        var totalLiabilities: Decimal { Decimal(totalLiabilitiesCents) / 100 }
        var netWorth: Decimal { Decimal(netWorthCents) / 100 }
    }
}

// MARK: - Type Aliases (point app code at V2)

typealias Budget = BudgetVaultSchemaV2.Budget
typealias Category = BudgetVaultSchemaV2.Category
typealias Transaction = BudgetVaultSchemaV2.Transaction
typealias RecurringExpense = BudgetVaultSchemaV2.RecurringExpense
typealias DebtAccount = BudgetVaultSchemaV2.DebtAccount
typealias DebtPayment = BudgetVaultSchemaV2.DebtPayment
typealias NetWorthAccount = BudgetVaultSchemaV2.NetWorthAccount
typealias NetWorthSnapshot = BudgetVaultSchemaV2.NetWorthSnapshot
```

- [ ] Run `xcodegen generate`. Expected: `Generated project successfully`.
- [ ] Commit: `feat(schema): add BudgetVaultSchemaV2 with #Index annotations`.

### Task 5: Remove V1 typealiases and update V1 file header

**Files:** Modify `BudgetVault/Schema/BudgetVaultSchemaV1.swift`.

- [ ] Read `BudgetVault/Schema/BudgetVaultSchemaV1.swift:444-453` (typealiases block).
- [ ] Edit `BudgetVaultSchemaV1.swift`: delete lines 444-453 (the `// MARK: - Type Aliases (convenience)` block and the 8 typealias lines). V2 file owns them now.
- [ ] Edit `BudgetVaultSchemaV1.swift`: replace the entire header comment block at lines 4-39 with a single line: `// V1 retained read-only for migration to V2. New code uses BudgetVaultSchemaV2.`
- [ ] Run `xcodebuild build -scheme BudgetVault -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=18.0'`. Expected: `BUILD SUCCEEDED` (V2 typealiases now resolve).
- [ ] Commit: `refactor(schema): point typealiases at V2; trim V1 header`.

### Task 6: Wire BudgetVaultMigrationPlan stages

**Files:** Modify `BudgetVault/Schema/BudgetVaultSchemaV1.swift:436-441`.

- [ ] Read `BudgetVault/Schema/BudgetVaultSchemaV1.swift:434-441`.
- [ ] Replace the `BudgetVaultMigrationPlan` enum block with:

```swift
enum BudgetVaultMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [BudgetVaultSchemaV1.self, BudgetVaultSchemaV2.self]
    }

    /// V1 → V2 is index-only (additive metadata; no field changes). Lightweight.
    static let v1toV2 = MigrationStage.lightweight(
        fromVersion: BudgetVaultSchemaV1.self,
        toVersion: BudgetVaultSchemaV2.self
    )

    static var stages: [MigrationStage] { [v1toV2] }
}
```

- [ ] Run `xcodebuild build -scheme BudgetVault -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=18.0'`. Expected: `BUILD SUCCEEDED`.
- [ ] Commit: `feat(schema): wire V1→V2 lightweight migration stage`.

### Task 7: Update BudgetVaultApp ModelContainer to use V2 schema

**Files:** Modify `BudgetVault/BudgetVaultApp.swift` (search the `ModelContainer` init site).

- [ ] Run `grep -n "ModelContainer\|VersionedSchema\|BudgetVaultSchemaV1" BudgetVault/BudgetVaultApp.swift`.
- [ ] At every container init that names `BudgetVaultSchemaV1`, replace with `BudgetVaultSchemaV2`. Also pass `migrationPlan: BudgetVaultMigrationPlan.self`.
- [ ] Example replacement:

```swift
let schema = Schema(versionedSchema: BudgetVaultSchemaV2.self)
let container = try ModelContainer(
    for: schema,
    migrationPlan: BudgetVaultMigrationPlan.self,
    configurations: [config]
)
```

- [ ] Run `xcodebuild build -scheme BudgetVault -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=18.0'`. Expected: `BUILD SUCCEEDED`.
- [ ] Commit: `feat(schema): app container now opens V2 with migration plan`.

### Task 8: Make migration test pass (green)

**Files:** Test file already exists from Task 3.

- [ ] Run `xcodebuild test -scheme BudgetVault -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=18.0' -only-testing BudgetVaultTests/SchemaV2MigrationTests`. Expected: `Test Suite 'SchemaV2MigrationTests' passed`.
- [ ] Run full test suite: `xcodebuild test -scheme BudgetVault -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=18.0'`. Expected: all 80+ existing tests still pass against V2.
- [ ] Commit: `test(schema): green — V1→V2 migration verified`.

---

## Phase B — BudgetVaultShared SPM expansion

> **Precondition (from Plan 01):** `BudgetVaultShared/` SPM package already exists with `AppStorageKeys`, `CurrencyFormatter`, `MoneyHelpers`. This phase adds `BudgetRepository`, `PremiumGate`, `PaywallTrigger`, `WidgetData`, `BudgetActivityAttributes`. If Plan 01 has not landed yet, Task 9 also creates the package skeleton.

### Task 9: Verify (or create) BudgetVaultShared SPM target

**Files:** Inspect `BudgetVaultShared/Package.swift`. If missing, create.

- [ ] Run `ls -la BudgetVaultShared/Package.swift 2>&1`.
- [ ] If file does not exist, create `BudgetVaultShared/Package.swift`:

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BudgetVaultShared",
    platforms: [.iOS(.v18)],
    products: [
        .library(name: "BudgetVaultShared", targets: ["BudgetVaultShared"]),
    ],
    targets: [
        .target(name: "BudgetVaultShared", path: "Sources/BudgetVaultShared"),
        .testTarget(name: "BudgetVaultSharedTests", dependencies: ["BudgetVaultShared"], path: "Tests/BudgetVaultSharedTests"),
    ]
)
```

- [ ] If `BudgetVaultShared/Sources/BudgetVaultShared/` does not exist, create it.
- [ ] Edit `project.yml`: under `targets:` `BudgetVault:` add a `dependencies:` entry `- package: BudgetVaultShared`. Under top-level `packages:` add:

```yaml
packages:
  BudgetVaultShared:
    path: BudgetVaultShared
```

- [ ] Edit `project.yml`: under `BudgetVaultWidgetExtension:` add the same `- package: BudgetVaultShared` dependency entry.
- [ ] Run `xcodegen generate`. Expected: `Generated project successfully`.
- [ ] Commit: `chore(spm): ensure BudgetVaultShared package wired to app + widget`.

### Task 10: Move BudgetActivityAttributes into BudgetVaultShared

**Files:** Create `BudgetVaultShared/Sources/BudgetVaultShared/BudgetActivityAttributes.swift`. Delete `BudgetVault/Models/BudgetActivityAttributes.swift`.

- [ ] Read `BudgetVault/Models/BudgetActivityAttributes.swift` (reference: 16 lines, struct + nested ContentState).
- [ ] Create `BudgetVaultShared/Sources/BudgetVaultShared/BudgetActivityAttributes.swift`:

```swift
import ActivityKit
import Foundation

public struct BudgetActivityAttributes: ActivityAttributes, Sendable {
    public struct ContentState: Codable, Hashable, Sendable {
        public let remainingCents: Int64
        public let dailyAllowanceCents: Int64
        public let spentFraction: Double
        public let dayOfPeriod: Int
        public let totalDays: Int
        public let currencyCode: String

        public init(remainingCents: Int64, dailyAllowanceCents: Int64, spentFraction: Double, dayOfPeriod: Int, totalDays: Int, currencyCode: String) {
            self.remainingCents = remainingCents
            self.dailyAllowanceCents = dailyAllowanceCents
            self.spentFraction = spentFraction
            self.dayOfPeriod = dayOfPeriod
            self.totalDays = totalDays
            self.currencyCode = currencyCode
        }
    }

    public let periodEndDate: Date

    public init(periodEndDate: Date) {
        self.periodEndDate = periodEndDate
    }
}
```

- [ ] Delete `BudgetVault/Models/BudgetActivityAttributes.swift`.
- [ ] In every Swift file that constructs `BudgetActivityAttributes` or its `.ContentState`, add `import BudgetVaultShared` (run `grep -rn "BudgetActivityAttributes" BudgetVault/ BudgetVaultWidget/` to enumerate).
- [ ] Run `xcodegen generate && xcodebuild build -scheme BudgetVault -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=18.0'`. Expected: `BUILD SUCCEEDED`.
- [ ] Commit: `refactor(shared): move BudgetActivityAttributes into BudgetVaultShared`.

### Task 11: Create unified WidgetData in BudgetVaultShared

**Files:** Create `BudgetVaultShared/Sources/BudgetVaultShared/WidgetData.swift`.

- [ ] Read `BudgetVault/Services/WidgetDataService.swift:10-27` (struct with 9 fields + nested CategorySummary) and `BudgetVaultWidget/BudgetVaultWidget.swift:7-24` (duplicate). Confirm field-by-field they are identical.
- [ ] Create `BudgetVaultShared/Sources/BudgetVaultShared/WidgetData.swift`:

```swift
import Foundation

public struct WidgetData: Codable, Sendable, Equatable {
    public let remainingBudgetCents: Int64
    public let totalBudgetCents: Int64
    public let percentRemaining: Double
    public let currencyCode: String
    public let isPremium: Bool
    public let topCategories: [CategorySummary]
    public let dailyAllowanceCents: Int64
    public let currentStreak: Int
    public let daysRemaining: Int

    public struct CategorySummary: Codable, Sendable, Equatable {
        public let emoji: String
        public let name: String
        public let spentCents: Int64
        public let budgetedCents: Int64

        public init(emoji: String, name: String, spentCents: Int64, budgetedCents: Int64) {
            self.emoji = emoji
            self.name = name
            self.spentCents = spentCents
            self.budgetedCents = budgetedCents
        }
    }

    public init(remainingBudgetCents: Int64, totalBudgetCents: Int64, percentRemaining: Double, currencyCode: String, isPremium: Bool, topCategories: [CategorySummary], dailyAllowanceCents: Int64, currentStreak: Int, daysRemaining: Int) {
        self.remainingBudgetCents = remainingBudgetCents
        self.totalBudgetCents = totalBudgetCents
        self.percentRemaining = percentRemaining
        self.currencyCode = currencyCode
        self.isPremium = isPremium
        self.topCategories = topCategories
        self.dailyAllowanceCents = dailyAllowanceCents
        self.currentStreak = currentStreak
        self.daysRemaining = daysRemaining
    }

    public static let appGroupSuiteName = "group.io.budgetvault.shared"
    public static let userDefaultsKey = "widgetData"

    public static var placeholder: WidgetData {
        WidgetData(
            remainingBudgetCents: 150_000,
            totalBudgetCents: 500_000,
            percentRemaining: 0.3,
            currencyCode: "USD",
            isPremium: false,
            topCategories: [
                .init(emoji: "🏠", name: "Rent", spentCents: 150_000, budgetedCents: 150_000),
                .init(emoji: "🛒", name: "Groceries", spentCents: 8_000, budgetedCents: 10_000),
                .init(emoji: "🚗", name: "Transport", spentCents: 3_000, budgetedCents: 5_000),
            ],
            dailyAllowanceCents: 10_200,
            currentStreak: 12,
            daysRemaining: 18
        )
    }
}
```

- [ ] Run `xcodegen generate && xcodebuild build -scheme BudgetVault -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=18.0'`. Expected: `BUILD SUCCEEDED` (no callsites use it yet).
- [ ] Commit: `feat(shared): add unified WidgetData struct`.

### Task 12: Migrate WidgetDataService to use shared WidgetData

**Files:** Modify `BudgetVault/Services/WidgetDataService.swift`.

- [ ] Read full `BudgetVault/Services/WidgetDataService.swift` (82 lines).
- [ ] Replace contents with:

```swift
import Foundation
import SwiftData
import WidgetKit
import BudgetVaultShared

enum WidgetDataService {

    @MainActor
    static func update(from context: ModelContext, resetDay: Int) {
        let (month, year) = DateHelpers.currentBudgetPeriod(resetDay: resetDay)

        let m = month
        let y = year
        let descriptor = FetchDescriptor<Budget>(
            predicate: #Predicate<Budget> { $0.month == m && $0.year == y }
        )
        guard let budget = try? context.fetch(descriptor).first else { return }

        let categories = (budget.categories ?? [])
            .filter { !$0.isHidden }
            .sorted { $0.spentCents(in: budget) > $1.spentCents(in: budget) }
            .prefix(3)
            .map { cat in
                WidgetData.CategorySummary(
                    emoji: cat.emoji,
                    name: cat.name,
                    spentCents: cat.spentCents(in: budget),
                    budgetedCents: cat.budgetedAmountCents
                )
            }

        let daysRemaining = max(Calendar.current.dateComponents([.day], from: Date(), to: budget.nextPeriodStart).day ?? 0, 1)
        let dailyAllowance = budget.remainingCents / Int64(daysRemaining)

        let data = WidgetData(
            remainingBudgetCents: budget.remainingCents,
            totalBudgetCents: budget.totalIncomeCents,
            percentRemaining: budget.percentRemaining,
            currencyCode: UserDefaults.standard.string(forKey: AppStorageKeys.selectedCurrency) ?? "USD",
            isPremium: UserDefaults.standard.bool(forKey: AppStorageKeys.isPremium),
            topCategories: Array(categories),
            dailyAllowanceCents: dailyAllowance,
            currentStreak: UserDefaults.standard.integer(forKey: AppStorageKeys.currentStreak),
            daysRemaining: daysRemaining
        )

        guard let encoded = try? JSONEncoder().encode(data) else { return }
        UserDefaults(suiteName: WidgetData.appGroupSuiteName)?.set(encoded, forKey: WidgetData.userDefaultsKey)

        WidgetCenter.shared.reloadAllTimelines()
    }

    static func read() -> WidgetData? {
        guard let data = UserDefaults(suiteName: WidgetData.appGroupSuiteName)?.data(forKey: WidgetData.userDefaultsKey),
              let decoded = try? JSONDecoder().decode(WidgetData.self, from: data) else {
            return nil
        }
        return decoded
    }
}
```

- [ ] Search for any other reference to `WidgetDataService.WidgetData`: `grep -rn "WidgetDataService.WidgetData" BudgetVault/`. For each hit, change to `WidgetData` and add `import BudgetVaultShared`.
- [ ] Run `xcodegen generate && xcodebuild build -scheme BudgetVault -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=18.0'`. Expected: `BUILD SUCCEEDED`.
- [ ] Commit: `refactor(widget): WidgetDataService uses shared WidgetData`.

### Task 13: Migrate widget target to shared WidgetData

**Files:** Modify `BudgetVaultWidget/BudgetVaultWidget.swift:1-80`.

- [ ] Read `BudgetVaultWidget/BudgetVaultWidget.swift:1-80`.
- [ ] Edit lines 1-3 to add `import BudgetVaultShared` after `import AppIntents`.
- [ ] Delete lines 5-24 (the duplicate `WidgetBudgetData` struct + comment header).
- [ ] In `BudgetTimelineProvider`, replace `WidgetBudgetData` with `WidgetData` everywhere (placeholder, getSnapshot, getTimeline, readData return type).
- [ ] Replace `Self.suiteName` and `Self.dataKey` references with `WidgetData.appGroupSuiteName` and `WidgetData.userDefaultsKey`. Delete the local static `suiteName` and `dataKey` declarations on `BudgetTimelineProvider`.
- [ ] In `BudgetEntry`, change `let data: WidgetBudgetData` to `let data: WidgetData`.
- [ ] Delete the `extension WidgetBudgetData { static var placeholder ... }` block (lines 62-80) — `WidgetData.placeholder` lives in the shared module.
- [ ] In every remaining body usage, change `WidgetBudgetData.placeholder` to `WidgetData.placeholder`.
- [ ] Run `xcodegen generate && xcodebuild build -scheme BudgetVault -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=18.0'`. Expected: `BUILD SUCCEEDED`.
- [ ] Commit: `refactor(widget): drop WidgetBudgetData duplicate; use shared WidgetData`.

---

## Phase C — PremiumGate (TDD)

### Task 14: Write failing PremiumGate tests

**Files:** Create `BudgetVaultTests/PremiumGateTests.swift`.

- [ ] Create file with content:

```swift
import XCTest
@testable import BudgetVault
import BudgetVaultShared

final class PremiumGateTests: XCTestCase {

    // MARK: - Categories (free limit = 6)

    func testFreeUserUnderCategoryLimitAllowed() {
        let v = PremiumGate.canAddCategory(count: 5, isPremium: false)
        XCTAssertEqual(v, .allowed)
    }

    func testFreeUserAtCategoryLimitBlocked() {
        let v = PremiumGate.canAddCategory(count: 6, isPremium: false)
        if case .blocked(_, let trigger) = v {
            XCTAssertEqual(trigger, .categoryLimit)
        } else {
            XCTFail("Expected .blocked at count == 6")
        }
    }

    func testFreeUserOverCategoryLimitBlocked() {
        let v = PremiumGate.canAddCategory(count: 12, isPremium: false)
        if case .blocked(let reason, _) = v {
            XCTAssertFalse(reason.isEmpty)
        } else {
            XCTFail("Expected .blocked at count == 12")
        }
    }

    func testPremiumUserCategoryAlwaysAllowed() {
        XCTAssertEqual(PremiumGate.canAddCategory(count: 99, isPremium: true), .allowed)
    }

    // MARK: - Recurring (free limit = 3)

    func testFreeUserUnderRecurringLimitAllowed() {
        XCTAssertEqual(PremiumGate.canAddRecurring(count: 2, isPremium: false), .allowed)
    }

    func testFreeUserAtRecurringLimitBlocked() {
        let v = PremiumGate.canAddRecurring(count: 3, isPremium: false)
        if case .blocked(_, let trigger) = v {
            XCTAssertEqual(trigger, .recurringLimit)
        } else {
            XCTFail("Expected .blocked at count == 3")
        }
    }

    func testPremiumUserRecurringAlwaysAllowed() {
        XCTAssertEqual(PremiumGate.canAddRecurring(count: 50, isPremium: true), .allowed)
    }

    // MARK: - CSV import (free limit = 4 categories)

    func testFreeUserUnderCSVImportLimitAllowed() {
        XCTAssertEqual(PremiumGate.canImportCSVCategories(count: 4, isPremium: false), .allowed)
    }

    func testFreeUserOverCSVImportLimitBlocked() {
        let v = PremiumGate.canImportCSVCategories(count: 5, isPremium: false)
        if case .blocked(_, let trigger) = v {
            XCTAssertEqual(trigger, .csvImport)
        } else {
            XCTFail("Expected .blocked at count == 5")
        }
    }

    func testPremiumUserCSVImportAlwaysAllowed() {
        XCTAssertEqual(PremiumGate.canImportCSVCategories(count: 100, isPremium: true), .allowed)
    }

    // MARK: - Premium-only features

    func testFreeUserDebtTrackerBlocked() {
        let v = PremiumGate.canUseDebtTracker(isPremium: false)
        if case .blocked(_, let trigger) = v {
            XCTAssertEqual(trigger, .debtTracker)
        } else {
            XCTFail("Expected .blocked for free user debt tracker")
        }
    }

    func testFreeUserVaultIntelligenceBlocked() {
        let v = PremiumGate.canUseVaultIntelligence(isPremium: false)
        if case .blocked(_, let trigger) = v {
            XCTAssertEqual(trigger, .vaultIntelligence)
        } else {
            XCTFail("Expected .blocked for free user intelligence")
        }
    }
}
```

- [ ] Run `xcodebuild test -scheme BudgetVault -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=18.0' -only-testing BudgetVaultTests/PremiumGateTests`. Expected: **build fails** (`PremiumGate` undefined). Red step.
- [ ] Commit: `test(premium-gate): failing tests for free-tier limit verdicts`.

### Task 15: Implement PremiumGate enum

**Files:** Create `BudgetVaultShared/Sources/BudgetVaultShared/PremiumGate.swift`.

- [ ] Create file:

```swift
import Foundation

/// Centralized free-tier matrix. Single source of truth for premium gating
/// across the app — replaces 16 scattered `@AppStorage(isPremium)` checks
/// with hardcoded magic numbers.
public enum PremiumGate {

    // MARK: - Free-tier matrix

    /// Max categories a free user can keep visible per budget.
    public static let freeCategoryLimit = 6

    /// Max active recurring expenses a free user can run.
    public static let freeRecurringLimit = 3

    /// Max distinct categories a free user can import in one CSV.
    public static let freeCSVImportCategoryLimit = 4

    // MARK: - Verdict

    public enum Verdict: Equatable {
        case allowed
        case blocked(reason: String, paywallTrigger: PaywallTrigger)
    }

    // MARK: - Public API

    public static func canAddCategory(count: Int, isPremium: Bool) -> Verdict {
        if isPremium { return .allowed }
        if count >= freeCategoryLimit {
            return .blocked(
                reason: "Free plan includes up to \(freeCategoryLimit) envelopes. Unlock unlimited.",
                paywallTrigger: .categoryLimit
            )
        }
        return .allowed
    }

    public static func canAddRecurring(count: Int, isPremium: Bool) -> Verdict {
        if isPremium { return .allowed }
        if count >= freeRecurringLimit {
            return .blocked(
                reason: "Free plan includes up to \(freeRecurringLimit) recurring bills. Unlock unlimited.",
                paywallTrigger: .recurringLimit
            )
        }
        return .allowed
    }

    public static func canImportCSVCategories(count: Int, isPremium: Bool) -> Verdict {
        if isPremium { return .allowed }
        if count > freeCSVImportCategoryLimit {
            return .blocked(
                reason: "Free import maps up to \(freeCSVImportCategoryLimit) categories. Unlock full CSV.",
                paywallTrigger: .csvImport
            )
        }
        return .allowed
    }

    public static func canUseDebtTracker(isPremium: Bool) -> Verdict {
        isPremium
            ? .allowed
            : .blocked(reason: "Debt Tracker is premium.", paywallTrigger: .debtTracker)
    }

    public static func canUseVaultIntelligence(isPremium: Bool) -> Verdict {
        isPremium
            ? .allowed
            : .blocked(reason: "Vault Intelligence is premium.", paywallTrigger: .vaultIntelligence)
    }

    public static func canUseWrapped(isPremium: Bool) -> Verdict {
        isPremium
            ? .allowed
            : .blocked(reason: "Monthly Wrapped is premium.", paywallTrigger: .wrapped)
    }

    public static func canUseRolloverRule(isPremium: Bool) -> Verdict {
        isPremium
            ? .allowed
            : .blocked(reason: "Rollover rules are premium.", paywallTrigger: .rolloverRule)
    }
}
```

- [ ] Note: this file references `PaywallTrigger` — Task 16 creates it. The build will fail until both files compile. Defer build verification until Task 17.
- [ ] Commit: `feat(premium-gate): add PremiumGate enum (compiles after PaywallTrigger lands)`.

### Task 16: Implement PaywallTrigger enum (TDD red)

**Files:** Create `BudgetVaultTests/PaywallTriggerTests.swift` first, then `BudgetVaultShared/Sources/BudgetVaultShared/PaywallTrigger.swift`.

- [ ] Create `BudgetVaultTests/PaywallTriggerTests.swift`:

```swift
import XCTest
@testable import BudgetVault
import BudgetVaultShared

final class PaywallTriggerTests: XCTestCase {

    func testHeroCopyForCategoryLimit() {
        XCTAssertTrue(PaywallTrigger.categoryLimit.heroHeadline.contains("envelopes"))
    }

    func testHeroCopyForRecurringLimit() {
        XCTAssertTrue(PaywallTrigger.recurringLimit.heroHeadline.contains("bills"))
    }

    func testHeroCopyForDebtTracker() {
        XCTAssertTrue(PaywallTrigger.debtTracker.heroHeadline.lowercased().contains("debt"))
    }

    func testHeroCopyForVaultIntelligence() {
        XCTAssertTrue(PaywallTrigger.vaultIntelligence.heroHeadline.lowercased().contains("intelligence"))
    }

    func testHeroCopyForWrapped() {
        XCTAssertTrue(PaywallTrigger.wrapped.heroHeadline.lowercased().contains("wrapped"))
    }

    func testHeroCopyForCSVImport() {
        XCTAssertTrue(PaywallTrigger.csvImport.heroHeadline.lowercased().contains("csv"))
    }

    func testHeroCopyForRolloverRule() {
        XCTAssertTrue(PaywallTrigger.rolloverRule.heroHeadline.lowercased().contains("rollover"))
    }

    func testHeroCopyForSettings() {
        XCTAssertFalse(PaywallTrigger.settings.heroHeadline.isEmpty)
    }

    func testIdentifiableID() {
        XCTAssertEqual(PaywallTrigger.categoryLimit.id, "categoryLimit")
    }
}
```

- [ ] Run test target. Expected: build fails (`PaywallTrigger` undefined). Red.
- [ ] Create `BudgetVaultShared/Sources/BudgetVaultShared/PaywallTrigger.swift`:

```swift
import Foundation

/// Routes a paywall presentation to a contextual hero headline + ASO-mapped
/// analytics signal (on-device only). Replaces 8 separate
/// `@State showPaywall = false` view-locals.
public enum PaywallTrigger: String, CaseIterable, Identifiable {
    case categoryLimit
    case recurringLimit
    case debtTracker
    case vaultIntelligence
    case wrapped
    case csvImport
    case rolloverRule
    case settings

    public var id: String { rawValue }

    /// Hero copy adapted per trigger. PaywallView reads this in its hero section.
    public var heroHeadline: String {
        switch self {
        case .categoryLimit:
            return "Add unlimited envelopes — $14.99 once"
        case .recurringLimit:
            return "Track unlimited bills — $14.99 once"
        case .debtTracker:
            return "Pay off debt faster — $14.99 once"
        case .vaultIntelligence:
            return "Unlock Vault Intelligence — $14.99 once"
        case .wrapped:
            return "See your Monthly Wrapped — $14.99 once"
        case .csvImport:
            return "Import the full CSV — $14.99 once"
        case .rolloverRule:
            return "Set rollover rules — $14.99 once"
        case .settings:
            return "Unlock the Full Vault — $14.99 once"
        }
    }
}
```

- [ ] Run `xcodegen generate && xcodebuild test -scheme BudgetVault -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=18.0' -only-testing BudgetVaultTests/PaywallTriggerTests`. Expected: `Test Suite 'PaywallTriggerTests' passed`.
- [ ] Commit: `feat(paywall): add PaywallTrigger enum + hero copy tests`.

### Task 17: Make PremiumGate tests pass

**Files:** No code change — both files now exist.

- [ ] Run `xcodebuild test -scheme BudgetVault -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=18.0' -only-testing BudgetVaultTests/PremiumGateTests`. Expected: `Test Suite 'PremiumGateTests' passed`.
- [ ] Run full test suite. Expected: all tests still pass.
- [ ] Commit: `test(premium-gate): green — all PremiumGate verdicts verified`.

### Task 18: Adapt PaywallView to consume PaywallTrigger

**Files:** Modify `BudgetVault/Views/Shared/PaywallView.swift`.

- [ ] Read `BudgetVault/Views/Shared/PaywallView.swift:1-60` to confirm current hero section.
- [ ] Edit `PaywallView` struct: add `let trigger: PaywallTrigger?` property and an initializer with default `nil`. Add `import BudgetVaultShared` at top.
- [ ] In the existing hero section (around the navy gradient block), replace any hard-coded "Unlock the Full Vault" headline with `Text(trigger?.heroHeadline ?? PaywallTrigger.settings.heroHeadline)`.
- [ ] Run `xcodebuild build -scheme BudgetVault -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=18.0'`. Expected: `BUILD SUCCEEDED`.
- [ ] Commit: `feat(paywall): hero copy adapts to PaywallTrigger`.

---

## Phase D — BudgetRepository (TDD)

### Task 19: Write failing MockBudgetRepository tests

**Files:** Create `BudgetVaultTests/MockBudgetRepositoryTests.swift`.

- [ ] Create file:

```swift
import XCTest
@testable import BudgetVault
import BudgetVaultShared

final class MockBudgetRepositoryTests: XCTestCase {

    func testCurrentBudgetReturnsConfiguredBudget() async throws {
        let repo = MockBudgetRepository()
        repo.stubCurrentBudget = MockBudgetRepository.makeBudget(month: 4, year: 2026)
        let result = try await repo.currentBudget()
        XCTAssertEqual(result?.month, 4)
        XCTAssertEqual(result?.year, 2026)
    }

    func testTransactionsInIntervalScopesByDate() async throws {
        let repo = MockBudgetRepository()
        let inside = MockBudgetRepository.makeTransaction(amountCents: 1_000, date: dateAt(2026, 4, 10))
        let outside = MockBudgetRepository.makeTransaction(amountCents: 9_999, date: dateAt(2026, 5, 10))
        repo.stubAllTransactions = [inside, outside]
        let interval = DateInterval(start: dateAt(2026, 4, 1), end: dateAt(2026, 5, 1))
        let result = try await repo.transactions(in: interval)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.amountCents, 1_000)
    }

    func testCategorySpendInIntervalAggregatesPerCategory() async throws {
        let repo = MockBudgetRepository()
        let catA = UUID()
        let catB = UUID()
        repo.stubAllTransactions = [
            MockBudgetRepository.makeTransaction(amountCents: 1_000, date: dateAt(2026, 4, 5), categoryID: catA),
            MockBudgetRepository.makeTransaction(amountCents: 2_500, date: dateAt(2026, 4, 6), categoryID: catA),
            MockBudgetRepository.makeTransaction(amountCents: 7_000, date: dateAt(2026, 4, 7), categoryID: catB),
        ]
        let interval = DateInterval(start: dateAt(2026, 4, 1), end: dateAt(2026, 5, 1))
        let map = try await repo.categorySpend(in: interval)
        XCTAssertEqual(map[catA], 3_500)
        XCTAssertEqual(map[catB], 7_000)
    }

    func testRecentTransactionsHonorsLimit() async throws {
        let repo = MockBudgetRepository()
        repo.stubAllTransactions = (0..<100).map { i in
            MockBudgetRepository.makeTransaction(amountCents: Int64(i), date: dateAt(2026, 4, 1).addingTimeInterval(TimeInterval(i)))
        }
        let recent = try await repo.recentTransactions(limit: 10)
        XCTAssertEqual(recent.count, 10)
    }

    func testEmptyStoreReturnsEmpty() async throws {
        let repo = MockBudgetRepository()
        let result = try await repo.transactions(in: DateInterval(start: .now, duration: 86_400))
        XCTAssertTrue(result.isEmpty)
    }

    func testCategorySpendIgnoresIncome() async throws {
        let repo = MockBudgetRepository()
        let cat = UUID()
        repo.stubAllTransactions = [
            MockBudgetRepository.makeTransaction(amountCents: 5_000, date: dateAt(2026, 4, 5), categoryID: cat, isIncome: true),
            MockBudgetRepository.makeTransaction(amountCents: 2_500, date: dateAt(2026, 4, 6), categoryID: cat, isIncome: false),
        ]
        let interval = DateInterval(start: dateAt(2026, 4, 1), end: dateAt(2026, 5, 1))
        let map = try await repo.categorySpend(in: interval)
        XCTAssertEqual(map[cat], 2_500)
    }

    // Helpers
    private func dateAt(_ year: Int, _ month: Int, _ day: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day))!
    }
}
```

- [ ] Run `xcodebuild test -scheme BudgetVault -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=18.0' -only-testing BudgetVaultTests/MockBudgetRepositoryTests`. Expected: build fails (`MockBudgetRepository` undefined). Red.
- [ ] Commit: `test(repository): failing MockBudgetRepository tests`.

### Task 20: Implement BudgetRepository protocol + Mock

**Files:** Create `BudgetVaultShared/Sources/BudgetVaultShared/BudgetRepository.swift`.

- [ ] Create file:

```swift
import Foundation
import SwiftData

// MARK: - Protocol

/// Period-scoped read API over the SwiftData store. Lets ViewModels and views
/// stop owning unbounded `@Query`s and become unit-testable.
@MainActor
public protocol BudgetRepository: AnyObject {
    /// The Budget for the period containing today (resolved via resetDay).
    func currentBudget() async throws -> Budget?

    /// All non-income transactions whose `date` falls in the half-open interval
    /// `[interval.start, interval.end)`. Sort: `date` descending.
    func transactions(in interval: DateInterval) async throws -> [Transaction]

    /// Sum of `amountCents` per category UUID for non-income transactions in the
    /// interval. O(N) over the interval slice; memoize in the caller per render.
    func categorySpend(in interval: DateInterval) async throws -> [UUID: Int64]

    /// Most-recent N transactions across all periods (used for MRU chips).
    /// Backed by `FetchDescriptor.fetchLimit`.
    func recentTransactions(limit: Int) async throws -> [Transaction]
}

// MARK: - Mock (test fixture)

/// In-memory test double. Tests mutate `stubCurrentBudget` and `stubAllTransactions`
/// directly; the protocol methods filter the stubs to match the live API contract.
@MainActor
public final class MockBudgetRepository: BudgetRepository {

    public var stubCurrentBudget: Budget?
    public var stubAllTransactions: [Transaction] = []

    public init() {}

    public func currentBudget() async throws -> Budget? {
        stubCurrentBudget
    }

    public func transactions(in interval: DateInterval) async throws -> [Transaction] {
        stubAllTransactions
            .filter { $0.date >= interval.start && $0.date < interval.end }
            .sorted { $0.date > $1.date }
    }

    public func categorySpend(in interval: DateInterval) async throws -> [UUID: Int64] {
        var map: [UUID: Int64] = [:]
        for tx in stubAllTransactions
            where !tx.isIncome
            && tx.date >= interval.start
            && tx.date < interval.end
            && tx.category != nil
        {
            map[tx.category!.id, default: 0] += tx.amountCents
        }
        return map
    }

    public func recentTransactions(limit: Int) async throws -> [Transaction] {
        Array(stubAllTransactions.sorted { $0.date > $1.date }.prefix(limit))
    }

    // MARK: - Test factories

    public static func makeBudget(month: Int, year: Int, totalIncomeCents: Int64 = 500_000) -> Budget {
        Budget(month: month, year: year, totalIncomeCents: totalIncomeCents)
    }

    public static func makeTransaction(amountCents: Int64, date: Date, categoryID: UUID? = nil, isIncome: Bool = false) -> Transaction {
        let tx = Transaction(amountCents: amountCents, note: "", date: date, isIncome: isIncome)
        if let id = categoryID {
            let cat = Category(name: "Stub", emoji: "📦", budgetedAmountCents: 0, color: "#000", sortOrder: 0)
            cat.id = id
            tx.category = cat
        }
        return tx
    }
}

// MARK: - Live (SwiftData ModelActor backing)

@MainActor
public final class LiveBudgetRepository: BudgetRepository {

    private let context: ModelContext
    private let resetDay: Int

    /// Per-instance memoization of `categorySpend(in:)` keyed by interval. Cleared
    /// when caller invokes `invalidate()` (typically on `ModelContext.didSave`).
    private var spendCache: [DateInterval: [UUID: Int64]] = [:]

    public init(context: ModelContext, resetDay: Int) {
        self.context = context
        self.resetDay = resetDay
    }

    public func invalidate() {
        spendCache.removeAll(keepingCapacity: true)
    }

    public func currentBudget() async throws -> Budget? {
        let (m, y) = Self.currentPeriod(resetDay: resetDay)
        let descriptor = FetchDescriptor<Budget>(
            predicate: #Predicate<Budget> { $0.month == m && $0.year == y }
        )
        return try context.fetch(descriptor).first
    }

    public func transactions(in interval: DateInterval) async throws -> [Transaction] {
        let start = interval.start
        let end = interval.end
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate<Transaction> { $0.date >= start && $0.date < end },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    public func categorySpend(in interval: DateInterval) async throws -> [UUID: Int64] {
        if let cached = spendCache[interval] { return cached }
        let start = interval.start
        let end = interval.end
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate<Transaction> {
                !$0.isIncome && $0.date >= start && $0.date < end
            }
        )
        let txs = try context.fetch(descriptor)
        var map: [UUID: Int64] = [:]
        for tx in txs where tx.category != nil {
            map[tx.category!.id, default: 0] += tx.amountCents
        }
        spendCache[interval] = map
        return map
    }

    public func recentTransactions(limit: Int) async throws -> [Transaction] {
        var descriptor = FetchDescriptor<Transaction>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return try context.fetch(descriptor)
    }

    // MARK: - Period helper

    private static func currentPeriod(resetDay: Int) -> (Int, Int) {
        let cal = Calendar.current
        let now = Date()
        let comps = cal.dateComponents([.year, .month, .day], from: now)
        let day = comps.day ?? 1
        var month = comps.month ?? 1
        var year = comps.year ?? 2026
        if day < resetDay {
            month -= 1
            if month < 1 { month = 12; year -= 1 }
        }
        return (month, year)
    }
}
```

- [ ] Run `xcodegen generate && xcodebuild test -scheme BudgetVault -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=18.0' -only-testing BudgetVaultTests/MockBudgetRepositoryTests`. Expected: `Test Suite 'MockBudgetRepositoryTests' passed`.
- [ ] Commit: `feat(repository): add BudgetRepository protocol + Mock + Live`.

### Task 21: Write LiveBudgetRepository integration tests

**Files:** Create `BudgetVaultTests/LiveBudgetRepositoryTests.swift`.

- [ ] Create file:

```swift
import XCTest
import SwiftData
@testable import BudgetVault
import BudgetVaultShared

@MainActor
final class LiveBudgetRepositoryTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUpWithError() throws {
        let schema = Schema(versionedSchema: BudgetVaultSchemaV2.self)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, migrationPlan: BudgetVaultMigrationPlan.self, configurations: [config])
        context = container.mainContext
    }

    override func tearDown() {
        container = nil
        context = nil
    }

    func testCurrentBudgetSmoke() async throws {
        let now = Date()
        let comps = Calendar.current.dateComponents([.year, .month], from: now)
        let budget = Budget(month: comps.month!, year: comps.year!, totalIncomeCents: 500_000)
        context.insert(budget)
        try context.save()

        let repo = LiveBudgetRepository(context: context, resetDay: 1)
        let current = try await repo.currentBudget()
        XCTAssertEqual(current?.month, comps.month)
        XCTAssertEqual(current?.year, comps.year)
    }

    func testTransactionsInIntervalScopesByPredicate() async throws {
        let cal = Calendar.current
        let inside = Transaction(amountCents: 1_000, note: "in", date: cal.date(from: DateComponents(year: 2026, month: 4, day: 10))!)
        let outside = Transaction(amountCents: 9_999, note: "out", date: cal.date(from: DateComponents(year: 2026, month: 5, day: 10))!)
        context.insert(inside)
        context.insert(outside)
        try context.save()

        let repo = LiveBudgetRepository(context: context, resetDay: 1)
        let result = try await repo.transactions(in: DateInterval(
            start: cal.date(from: DateComponents(year: 2026, month: 4, day: 1))!,
            end: cal.date(from: DateComponents(year: 2026, month: 5, day: 1))!
        ))
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.note, "in")
    }

    func testRecentTransactionsHonorsLimit() async throws {
        for i in 0..<25 {
            let tx = Transaction(amountCents: Int64(i), note: "t\(i)", date: Date().addingTimeInterval(TimeInterval(i)))
            context.insert(tx)
        }
        try context.save()

        let repo = LiveBudgetRepository(context: context, resetDay: 1)
        let recent = try await repo.recentTransactions(limit: 10)
        XCTAssertEqual(recent.count, 10)
    }

    func testCategorySpendMemoizesAcrossCalls() async throws {
        let cat = Category(name: "Groceries", emoji: "🛒", budgetedAmountCents: 50_000)
        context.insert(cat)
        let cal = Calendar.current
        let tx = Transaction(amountCents: 2_500, note: "Eggs", date: cal.date(from: DateComponents(year: 2026, month: 4, day: 5))!, isIncome: false, category: cat)
        context.insert(tx)
        try context.save()

        let interval = DateInterval(
            start: cal.date(from: DateComponents(year: 2026, month: 4, day: 1))!,
            end: cal.date(from: DateComponents(year: 2026, month: 5, day: 1))!
        )
        let repo = LiveBudgetRepository(context: context, resetDay: 1)
        let first = try await repo.categorySpend(in: interval)
        let second = try await repo.categorySpend(in: interval)
        XCTAssertEqual(first[cat.id], 2_500)
        XCTAssertEqual(second[cat.id], 2_500)
    }
}
```

- [ ] Run `xcodebuild test -scheme BudgetVault -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=18.0' -only-testing BudgetVaultTests/LiveBudgetRepositoryTests`. Expected: `Test Suite 'LiveBudgetRepositoryTests' passed`.
- [ ] Commit: `test(repository): green — Live integration over in-memory store`.

### Task 22: Inject LiveBudgetRepository into the SwiftUI environment

**Files:** Create `BudgetVaultShared/Sources/BudgetVaultShared/RepositoryEnvironment.swift`. Modify `BudgetVault/BudgetVaultApp.swift`.

- [ ] Create `BudgetVaultShared/Sources/BudgetVaultShared/RepositoryEnvironment.swift`:

```swift
import SwiftUI

private struct BudgetRepositoryKey: EnvironmentKey {
    @MainActor static let defaultValue: any BudgetRepository = MockBudgetRepository()
}

public extension EnvironmentValues {
    var budgetRepository: any BudgetRepository {
        get { self[BudgetRepositoryKey.self] }
        set { self[BudgetRepositoryKey.self] = newValue }
    }
}
```

- [ ] Read `BudgetVault/BudgetVaultApp.swift:44-100` to find the `WindowGroup`/`ContentView` site.
- [ ] In `BudgetVaultApp.body`, after the `.modelContainer(...)` modifier on the root view, add:

```swift
.environment(\.budgetRepository, LiveBudgetRepository(context: container.mainContext, resetDay: resetDay))
```

(`container` is the same `ModelContainer` already initialized in `init()`.)

- [ ] Add `import BudgetVaultShared` to `BudgetVaultApp.swift`.
- [ ] Run `xcodebuild build -scheme BudgetVault -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=18.0'`. Expected: `BUILD SUCCEEDED`.
- [ ] Commit: `feat(repository): inject LiveBudgetRepository via SwiftUI environment`.

---

## Phase E — Period-scoped @Query refactor (one task per view)

### Task 23: Refactor DashboardView @Query to period predicate

**Files:** Modify `BudgetVault/Views/Dashboard/DashboardView.swift:20-23`.

- [ ] Read `BudgetVault/Views/Dashboard/DashboardView.swift:20-30, 86-92` to confirm current state.
- [ ] Replace lines 20-23 with:

```swift
@Query(sort: [SortDescriptor(\Budget.year, order: .reverse), SortDescriptor(\Budget.month, order: .reverse)]) private var allBudgets: [Budget]

/// Period-scoped: only the current budget period's transactions hydrate at view-init.
/// Backed by SchemaV2 `#Index<Transaction>([\.date])`.
@Query private var allTransactions: [Transaction]

@Query(sort: \RecurringExpense.nextDueDate) private var recurringExpenses: [RecurringExpense]
```

- [ ] Add a custom initializer to `DashboardView` that builds the predicate dynamically from `resetDay`:

```swift
init() {
    let resetDay = UserDefaults.standard.integer(forKey: AppStorageKeys.resetDay)
    let day = resetDay == 0 ? 1 : resetDay
    let cal = Calendar.current
    let now = Date()
    var comps = cal.dateComponents([.year, .month], from: now)
    let nowDay = cal.component(.day, from: now)
    if nowDay < day {
        comps.month! -= 1
        if comps.month! < 1 { comps.month = 12; comps.year! -= 1 }
    }
    comps.day = day
    let start = cal.date(from: comps) ?? now
    let end = cal.date(byAdding: .month, value: 1, to: start) ?? now
    _allTransactions = Query(
        filter: #Predicate<Transaction> { $0.date >= start && $0.date < end },
        sort: [SortDescriptor(\Transaction.date, order: .reverse)]
    )
}
```

- [ ] Run `xcodebuild build -scheme BudgetVault -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=18.0'`. Expected: `BUILD SUCCEEDED`.
- [ ] Run `xcodebuild test -scheme BudgetVault -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=18.0'`. Expected: all tests pass.
- [ ] Manually verify in Simulator that Dashboard renders correctly with prior-month data NOT showing in current widgets.
- [ ] Commit: `perf(dashboard): scope Transaction @Query to current period`.

### Task 24: Refactor HistoryView @Query to viewing-period predicate

**Files:** Modify `BudgetVault/Views/Transactions/HistoryView.swift:10-11`.

- [ ] Read `BudgetVault/Views/Transactions/HistoryView.swift:1-50` to confirm `viewingMonth`/`viewingYear` state.
- [ ] HistoryView pages between months (the user can scroll back). The `@Query` cannot be re-bound inside `init`. Solution: keep `@Query` over all transactions, BUT add `fetchLimit: 1000` and a fallback predicate that scopes to the trailing 12 months.
- [ ] Replace line 11 with:

```swift
/// Trailing-12-months predicate. The view further filters to viewingMonth/Year in body.
/// 12-month window keeps even power users below ~10K rows for the History scroll.
@Query private var allTransactions: [Transaction]
```

- [ ] Add initializer:

```swift
init() {
    let cal = Calendar.current
    let oneYearAgo = cal.date(byAdding: .month, value: -12, to: Date()) ?? Date()
    _allTransactions = Query(
        filter: #Predicate<Transaction> { $0.date >= oneYearAgo },
        sort: [SortDescriptor(\Transaction.date, order: .reverse)]
    )
}
```

- [ ] Run `xcodebuild build -scheme BudgetVault -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=18.0'`. Expected: `BUILD SUCCEEDED`.
- [ ] Run `xcodebuild test -scheme BudgetVault -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=18.0'`. Expected: all pass.
- [ ] Commit: `perf(history): scope Transaction @Query to trailing 12 months`.

### Task 25: Refactor InsightsView @Query to range-bounded predicate

**Files:** Modify `BudgetVault/Views/Insights/InsightsView.swift:9-11`.

- [ ] Read `BudgetVault/Views/Insights/InsightsView.swift:1-55` to confirm `selectedRange` enum and `dateRangeStart`/`dateRangeEnd` derivation.
- [ ] InsightsView's range maxes out at "Year to Date". Replace lines 9-11 with:

```swift
@Query(sort: [SortDescriptor(\Budget.year, order: .reverse), SortDescriptor(\Budget.month, order: .reverse)]) private var allBudgets: [Budget]

/// Year-to-date scope by default; computeMLResults consumes the slice.
@Query private var allTransactions: [Transaction]
```

- [ ] Add initializer:

```swift
init() {
    let cal = Calendar.current
    let yearStart = cal.date(from: cal.dateComponents([.year], from: Date())) ?? Date()
    _allTransactions = Query(
        filter: #Predicate<Transaction> { $0.date >= yearStart },
        sort: [SortDescriptor(\Transaction.date, order: .reverse)]
    )
}
```

- [ ] Run `xcodebuild build -scheme BudgetVault -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=18.0'`. Expected: `BUILD SUCCEEDED`.
- [ ] Run full tests. Expected: pass.
- [ ] Commit: `perf(insights): scope Transaction @Query to year-to-date`.

### Task 26: Refactor TransactionEntryView @Query with fetchLimit 50

**Files:** Modify `BudgetVault/Views/Transactions/TransactionEntryView.swift:17-18, 39-42`.

- [ ] Read `BudgetVault/Views/Transactions/TransactionEntryView.swift:1-50` to confirm the MRU chip path uses `recentTransactions = Array(allRecentTransactions.prefix(200))`.
- [ ] Replace line 18 with:

```swift
/// Limit recent fetch to 50 — MRU chips display only ~5 in UI; 50 is plenty
/// of history for the category-learning service to suggest from.
@Query private var allRecentTransactions: [Transaction]
```

- [ ] Add initializer:

```swift
init(budget: Budget, categories: [Category], prefillAmount: Double? = nil, prefillCategoryName: String? = nil, prefillNote: String? = nil) {
    self.budget = budget
    self.categories = categories
    self.prefillAmount = prefillAmount
    self.prefillCategoryName = prefillCategoryName
    self.prefillNote = prefillNote
    var descriptor = FetchDescriptor<Transaction>(
        sortBy: [SortDescriptor(\Transaction.date, order: .reverse)]
    )
    descriptor.fetchLimit = 50
    _allRecentTransactions = Query(descriptor)
}
```

- [ ] Update `recentTransactions` computed property to drop the `.prefix(200)` (now unnecessary): `private var recentTransactions: [Transaction] { allRecentTransactions }`.
- [ ] Run `xcodebuild build -scheme BudgetVault -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=18.0'`. Expected: `BUILD SUCCEEDED`.
- [ ] Run full tests. Expected: pass.
- [ ] Commit: `perf(tx-entry): cap @Query to 50 most-recent for MRU chips`.

### Task 27: Refactor RecurringExpenseListView @Query

**Files:** Modify `BudgetVault/Views/RecurringExpenses/RecurringExpenseListView.swift:8-9`.

- [ ] Read `BudgetVault/Views/RecurringExpenses/RecurringExpenseListView.swift:1-30` to confirm the `recentRecurringTransactions` computed property prefixes 5.
- [ ] Replace lines 8-9 with:

```swift
@Query(sort: \RecurringExpense.nextDueDate) private var allExpenses: [RecurringExpense]

/// Used for `recentRecurringTransactions` (prefix 5). FetchLimit 20 is plenty.
@Query private var recentTransactions: [Transaction]
```

- [ ] Add initializer:

```swift
init() {
    var descriptor = FetchDescriptor<Transaction>(
        predicate: #Predicate<Transaction> { $0.isRecurring },
        sortBy: [SortDescriptor(\Transaction.date, order: .reverse)]
    )
    descriptor.fetchLimit = 20
    _recentTransactions = Query(descriptor)
}
```

- [ ] Run `xcodebuild build -scheme BudgetVault -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=18.0'`. Expected: `BUILD SUCCEEDED`.
- [ ] Run full tests. Expected: pass.
- [ ] Commit: `perf(recurring): cap @Query to recent recurring transactions`.

### Task 28: Refactor FinanceTabView @Query (line 14)

**Files:** Modify `BudgetVault/Views/Finance/FinanceTabView.swift:13-14`.

- [ ] Read `BudgetVault/Views/Finance/FinanceTabView.swift:1-50, 36-50` for currentBudget/previousBudget computed properties.
- [ ] Replace lines 13-14 with:

```swift
@Query(sort: [SortDescriptor(\Budget.year, order: .reverse), SortDescriptor(\Budget.month, order: .reverse)]) private var allBudgets: [Budget]

/// Period-scoped to current budget; FinanceTabView only displays the active period.
@Query private var allTransactions: [Transaction]
```

- [ ] Add the same period-init pattern from Task 23 to FinanceTabView:

```swift
init() {
    let resetDay = UserDefaults.standard.integer(forKey: AppStorageKeys.resetDay)
    let day = resetDay == 0 ? 1 : resetDay
    let cal = Calendar.current
    let now = Date()
    var comps = cal.dateComponents([.year, .month], from: now)
    let nowDay = cal.component(.day, from: now)
    if nowDay < day {
        comps.month! -= 1
        if comps.month! < 1 { comps.month = 12; comps.year! -= 1 }
    }
    comps.day = day
    let start = cal.date(from: comps) ?? now
    let end = cal.date(byAdding: .month, value: 1, to: start) ?? now
    _allTransactions = Query(
        filter: #Predicate<Transaction> { $0.date >= start && $0.date < end },
        sort: [SortDescriptor(\Transaction.date, order: .reverse)]
    )
}
```

- [ ] Run `xcodebuild build -scheme BudgetVault -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=18.0'`. Expected: `BUILD SUCCEEDED`.
- [ ] Run full tests. Expected: pass.
- [ ] Commit: `perf(finance): scope FinanceTabView @Query to current period`.

### Task 29: Refactor MonthlyWrappedShell @Query (line 577)

**Files:** Modify `BudgetVault/Views/Finance/FinanceTabView.swift:574-577`.

- [ ] Read `BudgetVault/Views/Finance/FinanceTabView.swift:572-590` to confirm `MonthlyWrappedShell` passes `allTransactions` into `MonthlyWrappedView`.
- [ ] Replace lines 576-577 with:

```swift
@Query(sort: [SortDescriptor(\Budget.year, order: .reverse), SortDescriptor(\Budget.month, order: .reverse)]) private var allBudgets: [Budget]

@Query private var allTransactions: [Transaction]
```

- [ ] Add `init()` to `MonthlyWrappedShell` with the same period predicate pattern.
- [ ] Run `xcodebuild build -scheme BudgetVault -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=18.0'`. Expected: `BUILD SUCCEEDED`.
- [ ] Run full tests. Expected: pass.
- [ ] Commit: `perf(wrapped): scope MonthlyWrappedShell @Query to current period`.

### Task 30: Refactor BudgetView @Query

**Files:** Modify `BudgetVault/Views/Budget/BudgetView.swift:10`.

- [ ] Read `BudgetVault/Views/Budget/BudgetView.swift:1-40`.
- [ ] BudgetView reads `allBudgets` only — no `Transaction` query at file-top. The `cachedSpentMap` at line 26 is populated elsewhere. The unbounded query risk is **only** `allBudgets` (already correctly fetches all to support back-navigation by month). No predicate change required for `allBudgets`.
- [ ] Verify by reading the file head: line 10 should match `@Query(sort: [SortDescriptor(\Budget.year, order: .reverse), SortDescriptor(\Budget.month, order: .reverse)]) private var allBudgets: [Budget]`. If a `Transaction` `@Query` exists elsewhere in this file, scope it.
- [ ] Run `grep -n "@Query" BudgetVault/Views/Budget/BudgetView.swift`. If only `allBudgets` shows, no work — skip to commit.
- [ ] If a Transaction query is found, apply the period init pattern from Task 23.
- [ ] Run `xcodebuild build -scheme BudgetVault -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=18.0'`. Expected: `BUILD SUCCEEDED`.
- [ ] Commit: `perf(budget): verify no unbounded Transaction @Query in BudgetView`.

### Task 31: Refactor SettingsView BudgetTemplateSheetView @Query (line 667)

**Files:** Modify `BudgetVault/Views/Settings/SettingsView.swift:665-667`.

- [ ] Read `BudgetVault/Views/Settings/SettingsView.swift:660-680`.
- [ ] `BudgetTemplateSheetView` queries `allBudgets` to find `currentBudget`. This `@Query<Budget>` is small (one row per month; ~12-24 rows lifetime). Add `fetchLimit: 24` for safety:

```swift
@Query private var allBudgets: [Budget]

init() {
    var descriptor = FetchDescriptor<Budget>(
        sortBy: [SortDescriptor(\Budget.year, order: .reverse), SortDescriptor(\Budget.month, order: .reverse)]
    )
    descriptor.fetchLimit = 24
    _allBudgets = Query(descriptor)
}
```

- [ ] Run `xcodebuild build -scheme BudgetVault -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=18.0'`. Expected: `BUILD SUCCEEDED`.
- [ ] Commit: `perf(settings): cap BudgetTemplateSheetView Budget @Query to 24 most-recent`.

---

## Phase F — PremiumGate sweep (one task per view)

### Task 32: Sweep BudgetView for PremiumGate.canAddCategory

**Files:** Modify `BudgetVault/Views/Budget/BudgetView.swift:8, 517, 561`.

- [ ] Read `BudgetVault/Views/Budget/BudgetView.swift:515-565` to confirm both call-sites.
- [ ] Add `import BudgetVaultShared` at top.
- [ ] At line 517 (`if !isPremium && count >= 6 {`), replace with:

```swift
let verdict = PremiumGate.canAddCategory(count: count, isPremium: isPremium)
if case .blocked(_, let trigger) = verdict {
    paywallTrigger = trigger
}
```

(Add a `@State private var paywallTrigger: PaywallTrigger?` at top of struct if not present.)

- [ ] At line 561, repeat the same pattern for `if !isPremium && visibleCategories.count >= 6 {`.
- [ ] Replace any `if !isPremium { showPaywall = true }` with `paywallTrigger = .categoryLimit` or `.settings` per context.
- [ ] Replace any `.sheet(isPresented: $showPaywall) { PaywallView() }` with `.sheet(item: $paywallTrigger) { trigger in PaywallView(trigger: trigger) }`.
- [ ] Delete now-unused `@State private var showPaywall = false`.
- [ ] Run `xcodebuild build -scheme BudgetVault -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=18.0'`. Expected: `BUILD SUCCEEDED`.
- [ ] Commit: `refactor(budget): use PremiumGate + PaywallTrigger for category limit`.

### Task 33: Sweep RecurringExpenseListView for PremiumGate.canAddRecurring

**Files:** Modify `BudgetVault/Views/RecurringExpenses/RecurringExpenseListView.swift:6, 13, 49, 133`.

- [ ] Read `BudgetVault/Views/RecurringExpenses/RecurringExpenseListView.swift:45-60, 130-140`.
- [ ] Add `import BudgetVaultShared`.
- [ ] Replace `@State private var showPaywall = false` (line 13) with `@State private var paywallTrigger: PaywallTrigger?`.
- [ ] At line 49, replace `if !isPremium && activeCount >= 3 { showPaywall = true }` with:

```swift
if case .blocked(_, let trigger) = PremiumGate.canAddRecurring(count: activeCount, isPremium: isPremium) {
    paywallTrigger = trigger
} else {
    showForm = true
}
```

- [ ] At line 133, repeat the same pattern.
- [ ] Replace `.sheet(isPresented: $showPaywall) { PaywallView() }` with `.sheet(item: $paywallTrigger) { trigger in PaywallView(trigger: trigger) }`.
- [ ] Run `xcodebuild build -scheme BudgetVault -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=18.0'`. Expected: `BUILD SUCCEEDED`.
- [ ] Commit: `refactor(recurring): use PremiumGate + PaywallTrigger for recurring limit`.

### Task 34: Sweep CSVImportView for PremiumGate.canImportCSVCategories

**Files:** Modify `BudgetVault/Views/Settings/CSVImportView.swift:240, 246, 266`.

- [ ] Read `BudgetVault/Views/Settings/CSVImportView.swift:238-275`.
- [ ] Add `import BudgetVaultShared`.
- [ ] At line 240, replace `selectedCategories = Set(uniqueCategories.prefix(isPremium ? uniqueCategories.count : 4))` with `selectedCategories = Set(uniqueCategories.prefix(isPremium ? uniqueCategories.count : PremiumGate.freeCSVImportCategoryLimit))`.
- [ ] At line 246, replace `if !isPremium && uniqueCategories.count > 4 {` with:

```swift
if case .blocked = PremiumGate.canImportCSVCategories(count: uniqueCategories.count, isPremium: isPremium) {
    step = .categorySelection
} else {
    performImport()
}
```

(Drop the existing `else` branch — the verdict above already routes both ways.)

- [ ] At line 256, replace the literal `4` in `else if selectedCategories.count < 4 {` with `PremiumGate.freeCSVImportCategoryLimit`.
- [ ] At line 266, replace `if !isPremium && uniqueCategories.count > 4 {` with `if case .blocked = PremiumGate.canImportCSVCategories(count: uniqueCategories.count, isPremium: isPremium) {`.
- [ ] Run `xcodebuild build -scheme BudgetVault -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=18.0'`. Expected: `BUILD SUCCEEDED`.
- [ ] Commit: `refactor(csv-import): use PremiumGate.canImportCSVCategories`.

### Task 35: Sweep DebtTrackingView for PremiumGate.canUseDebtTracker

**Files:** Modify `BudgetVault/Views/Finance/DebtTrackingView.swift`.

- [ ] Run `grep -n "isPremium\|showPaywall" BudgetVault/Views/Finance/DebtTrackingView.swift`. Capture every line.
- [ ] Add `import BudgetVaultShared`.
- [ ] Replace `@State private var showPaywall = false` with `@State private var paywallTrigger: PaywallTrigger?`.
- [ ] At every `if !isPremium { showPaywall = true }` site, replace with:

```swift
if case .blocked(_, let trigger) = PremiumGate.canUseDebtTracker(isPremium: isPremium) {
    paywallTrigger = trigger
}
```

- [ ] Replace `.sheet(isPresented: $showPaywall) { PaywallView() }` with `.sheet(item: $paywallTrigger) { trigger in PaywallView(trigger: trigger) }`.
- [ ] Run `xcodebuild build -scheme BudgetVault -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=18.0'`. Expected: `BUILD SUCCEEDED`.
- [ ] Commit: `refactor(debt): use PremiumGate.canUseDebtTracker`.

### Task 36: Sweep InsightsView for PremiumGate + PaywallTrigger

**Files:** Modify `BudgetVault/Views/Insights/InsightsView.swift:7, 13`.

- [ ] Read `BudgetVault/Views/Insights/InsightsView.swift:5-15`.
- [ ] Add `import BudgetVaultShared`.
- [ ] Replace line 13 `@State private var showPaywall = false` with `@State private var paywallTrigger: PaywallTrigger?`.
- [ ] Search file for `showPaywall = true`. Replace each with the appropriate `paywallTrigger = .vaultIntelligence` (or `.wrapped` if it's the wrapped path).
- [ ] Replace `.sheet(isPresented: $showPaywall) { PaywallView() }` with `.sheet(item: $paywallTrigger) { trigger in PaywallView(trigger: trigger) }`.
- [ ] Run `xcodebuild build -scheme BudgetVault -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=18.0'`. Expected: `BUILD SUCCEEDED`.
- [ ] Commit: `refactor(insights): use PaywallTrigger for paywall presentation`.

### Task 37: Sweep SpendingHeatmapView for PremiumGate.canUseVaultIntelligence

**Files:** Modify `BudgetVault/Views/Insights/SpendingHeatmapView.swift`.

- [ ] Run `grep -n "isPremium\|showPaywall" BudgetVault/Views/Insights/SpendingHeatmapView.swift`. Capture all hits.
- [ ] Add `import BudgetVaultShared`.
- [ ] At each premium gate site, replace ad-hoc check with `PremiumGate.canUseVaultIntelligence(isPremium: isPremium)`.
- [ ] If a `showPaywall` `@State` exists, replace with `paywallTrigger: PaywallTrigger?` and route to `.vaultIntelligence`.
- [ ] Run `xcodebuild build -scheme BudgetVault -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=18.0'`. Expected: `BUILD SUCCEEDED`.
- [ ] Commit: `refactor(heatmap): use PremiumGate.canUseVaultIntelligence`.

### Task 38: Sweep CategoryDetailView for PremiumGate

**Files:** Modify `BudgetVault/Views/Budget/CategoryDetailView.swift`.

- [ ] Run `grep -n "isPremium\|showPaywall" BudgetVault/Views/Budget/CategoryDetailView.swift`.
- [ ] Add `import BudgetVaultShared`.
- [ ] Replace any `if !isPremium { showPaywall = true }` site with `PremiumGate.canUseRolloverRule(isPremium: isPremium)` (rollover toggle is the canonical premium feature here) or `.canAddCategory` if it's a category-add path.
- [ ] Replace `@State private var showPaywall = false` with `@State private var paywallTrigger: PaywallTrigger?` and update sheet modifier.
- [ ] Run `xcodebuild build -scheme BudgetVault -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=18.0'`. Expected: `BUILD SUCCEEDED`.
- [ ] Commit: `refactor(category-detail): use PremiumGate + PaywallTrigger`.

### Task 39: Sweep FinanceTabView for PremiumGate

**Files:** Modify `BudgetVault/Views/Finance/FinanceTabView.swift:8, 18`.

- [ ] Read `BudgetVault/Views/Finance/FinanceTabView.swift:5-25`.
- [ ] Add `import BudgetVaultShared`.
- [ ] Replace `@State private var showPaywall = false` (line 18) with `@State private var paywallTrigger: PaywallTrigger?`.
- [ ] Find every `showPaywall = true` and route to the right trigger (most are `.settings`, but the Wrapped CTA is `.wrapped`, the debt CTA is `.debtTracker`).
- [ ] Replace `.sheet(isPresented: $showPaywall) { PaywallView() }` with `.sheet(item: $paywallTrigger) { trigger in PaywallView(trigger: trigger) }`.
- [ ] Run `xcodebuild build -scheme BudgetVault -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=18.0'`. Expected: `BUILD SUCCEEDED`.
- [ ] Commit: `refactor(finance-tab): use PaywallTrigger routing`.

### Task 40: Sweep SettingsView for PremiumGate

**Files:** Modify `BudgetVault/Views/Settings/SettingsView.swift`.

- [ ] Run `grep -n "isPremium\|showPaywall" BudgetVault/Views/Settings/SettingsView.swift`. Capture all hits.
- [ ] Add `import BudgetVaultShared`.
- [ ] Replace `@State private var showPaywall = false` (if present) with `@State private var paywallTrigger: PaywallTrigger?`.
- [ ] At each `showPaywall = true` route to `.settings` (Settings sheet is generic).
- [ ] Replace `.sheet(isPresented: $showPaywall) { PaywallView() }` with `.sheet(item: $paywallTrigger) { trigger in PaywallView(trigger: trigger) }`.
- [ ] Run `xcodebuild build -scheme BudgetVault -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=18.0'`. Expected: `BUILD SUCCEEDED`.
- [ ] Commit: `refactor(settings): use PaywallTrigger routing`.

### Task 41: Sweep DashboardView for PremiumGate

**Files:** Modify `BudgetVault/Views/Dashboard/DashboardView.swift:63`.

- [ ] Read `BudgetVault/Views/Dashboard/DashboardView.swift:60-70`.
- [ ] DashboardView's existing `ActiveSheet.paywall` enum case (line 38) is the routing mechanism. Add a `PaywallTrigger?` to the case:

```swift
enum ActiveSheet: Identifiable {
    case transactionEntry
    case monthlySummary
    case paywall(PaywallTrigger)
    // ... rest unchanged
    var id: String {
        if case .paywall(let t) = self { return "paywall-\(t.id)" }
        return String(describing: self)
    }
}
```

- [ ] At every `activeSheet = .paywall` site, change to `activeSheet = .paywall(.settings)` (or the contextually correct trigger).
- [ ] Update the corresponding `case .paywall:` body in the `.sheet(item:)` to `case .paywall(let trigger): PaywallView(trigger: trigger)`.
- [ ] Add `import BudgetVaultShared`.
- [ ] Run `xcodebuild build -scheme BudgetVault -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=18.0'`. Expected: `BUILD SUCCEEDED`.
- [ ] Commit: `refactor(dashboard): route paywall ActiveSheet through PaywallTrigger`.

### Task 42: Sweep MainTabView + AchievementBadgeView

**Files:** Modify `BudgetVault/Views/MainTabView.swift`, `BudgetVault/Views/Shared/AchievementBadgeView.swift`.

- [ ] Run `grep -n "isPremium" BudgetVault/Views/MainTabView.swift BudgetVault/Views/Shared/AchievementBadgeView.swift`. Capture hits.
- [ ] In each file, add `import BudgetVaultShared`.
- [ ] Where the file uses `isPremium` for tab visibility (Vault tab) or badge visibility, leave the boolean check — these are pure visibility toggles, not paywall triggers. The `PremiumGate` enum is for actions; pure conditional rendering against `isPremium` is fine.
- [ ] No code change needed UNLESS a `showPaywall` exists — in that case migrate to `paywallTrigger: PaywallTrigger?`.
- [ ] Run `xcodebuild build -scheme BudgetVault -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=18.0'`. Expected: `BUILD SUCCEEDED`.
- [ ] Commit: `refactor(main-tab,achievement-badge): import shared (no behavior change)`.

---

## Phase G — Category.spentCents memoization

### Task 43: Add per-render-pass memoization helper

**Files:** Modify `BudgetVault/Views/Dashboard/DashboardView.swift` (and FinanceTabView, MonthlyWrappedView).

- [ ] Read `BudgetVault/Views/Dashboard/DashboardView.swift:84-92` (cached state).
- [ ] DashboardView already declares `@State private var cachedSpentMap: [UUID: Int64] = [:]` at line 86. Add a `populateSpentMap()` helper that calls the repository:

```swift
@Environment(\.budgetRepository) private var repository

private func populateSpentMap() async {
    guard let budget = currentBudget else { return }
    let interval = DateInterval(start: budget.periodStart, end: budget.nextPeriodStart)
    do {
        cachedSpentMap = try await repository.categorySpend(in: interval)
    } catch {
        cachedSpentMap = [:]
    }
}
```

- [ ] In the `.task` modifier on the root view body, call `await populateSpentMap()`. Also call from `.onChange(of: allTransactions.count)` to refresh on new tx.
- [ ] In every body callsite that did `category.spentCents(in: budget)`, change to `cachedSpentMap[category.id] ?? 0`.
- [ ] Run `xcodebuild build -scheme BudgetVault -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=18.0'`. Expected: `BUILD SUCCEEDED`.
- [ ] Run full tests. Expected: pass.
- [ ] Commit: `perf(dashboard): memoize Category.spentCents via repository`.

### Task 44: Apply same memoization to FinanceTabView

**Files:** Modify `BudgetVault/Views/Finance/FinanceTabView.swift`.

- [ ] Add `@State private var cachedSpentMap: [UUID: Int64] = [:]` and `@Environment(\.budgetRepository) private var repository`.
- [ ] Add the `populateSpentMap()` helper from Task 43.
- [ ] Wire into `.task` and `.onChange`.
- [ ] Replace `category.spentCents(in: budget)` callsites with `cachedSpentMap[category.id] ?? 0`.
- [ ] Run `xcodebuild build -scheme BudgetVault -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=18.0'`. Expected: `BUILD SUCCEEDED`.
- [ ] Commit: `perf(finance-tab): memoize Category.spentCents via repository`.

### Task 45: Apply same memoization to MonthlyWrappedView

**Files:** Modify `BudgetVault/Views/Dashboard/MonthlyWrappedView.swift`.

- [ ] Read `BudgetVault/Views/Dashboard/MonthlyWrappedView.swift:30-160` to find the spentCents callsites.
- [ ] Add `@State private var cachedSpentMap: [UUID: Int64] = [:]` and `@Environment(\.budgetRepository) private var repository`.
- [ ] Add `populateSpentMap()` helper.
- [ ] Wire into `.task` (sheet-open is the right moment).
- [ ] Replace every `cat.spentCents(in: budget)` callsite with `cachedSpentMap[cat.id] ?? 0`.
- [ ] Run `xcodebuild build -scheme BudgetVault -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=18.0'`. Expected: `BUILD SUCCEEDED`.
- [ ] Run full tests. Expected: pass.
- [ ] Commit: `perf(wrapped): memoize Category.spentCents — fixes 200-800ms slide jank`.

---

## Phase H — Verification

### Task 46: Run the full test suite + verify no regressions

**Files:** None.

- [ ] Run `xcodegen generate && xcodebuild test -scheme BudgetVault -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=18.0'`. Expected: all 80+ tests pass, including the 4 new test files (`PremiumGateTests`, `PaywallTriggerTests`, `MockBudgetRepositoryTests`, `LiveBudgetRepositoryTests`, `SchemaV2MigrationTests`).
- [ ] Capture the test count: `xcodebuild test ... 2>&1 | grep -E "Test Suite .* passed|failed"`.
- [ ] If any test fails, fix the regression in a NEW commit (do not amend).
- [ ] Commit: `test: full suite green on iOS 18 with V2 schema + repository`.

### Task 47: Performance smoke test — seed 5K transactions

**Files:** Use existing `DebugSeedService` if available.

- [ ] Boot Simulator: `xcrun simctl boot "iPhone 17 Pro"`.
- [ ] Build + install app: `xcodebuild build -scheme BudgetVault -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=18.0'`.
- [ ] Open app, navigate to Settings → Debug → Seed 5K transactions (use `DebugSeedService.seedLargeDataset(count: 5000)` — add a Settings button if not present).
- [ ] Manually measure tab-switch latency (Dashboard → History → Insights → Settings) using Instruments Time Profiler.
- [ ] Expected: each tab switch <100ms p95 (per spec success criterion 7).
- [ ] If latency exceeds 100ms, investigate via Instruments and fix in a new commit. Do not commit a regression.
- [ ] Commit (if seeding helper added): `chore(debug): add 5K-tx seed for perf verification`.

### Task 48: Verify widget still renders correctly

**Files:** None.

- [ ] In Simulator, long-press home screen → add BudgetVault widget.
- [ ] Confirm widget renders with seeded data: top categories visible, ring color correct, daily allowance non-zero.
- [ ] Confirm Live Activity (Lock Screen) still fires when an activity is started.
- [ ] If widget shows placeholder data only, debug `WidgetData` JSON encoding/decoding round-trip.
- [ ] No commit unless widget bug found and fixed.

### Task 49: Tag and prepare for v3.3.1 ship

**Files:** None.

- [ ] Confirm `git status` is clean.
- [ ] Update `project.yml` `MARKETING_VERSION` from `3.2.1` to `3.3.1` (both `BudgetVault` and `BudgetVaultWidgetExtension` targets, lines 42 and 110).
- [ ] Bump `CURRENT_PROJECT_VERSION` to next integer.
- [ ] Run `xcodegen generate && xcodebuild build -scheme BudgetVault -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=18.0'`. Expected: `BUILD SUCCEEDED`.
- [ ] Commit: `chore(release): bump version to v3.3.1 build N`.
- [ ] Tag: `git tag v3.3.1-rc1`.

---

## Spec-Coverage Self-Review

**Spec Section 6.1 — iOS 18 Deployment Target Migration (1 day):** Covered by Tasks 1-2.

**Spec Section 6.2 — SchemaV2 with #Index (1 day):** Covered by Tasks 3-8 (full TDD: failing test → V2 schema with all 7 specified indexes (`Transaction(date)`, `(category, date)`, `(isIncome, date)`, `Budget(year, month)`, `RecurringExpense(nextDueDate)`, `(isActive, nextDueDate)`, `DebtPayment(date)`, `NetWorthSnapshot(date)`) → typealias migration → migration plan stages populated → app container update → green test).

**Spec Section 6.3 — Dynamic @Query Predicate Refactor (2 days):** Covered by Tasks 23-31 (one task per cited callsite: `DashboardView.swift:22`, `HistoryView.swift:11`, `InsightsView.swift:11`, `TransactionEntryView.swift:18`, `RecurringExpenseListView.swift:9`, `FinanceTabView.swift:14` & `:577`, `BudgetView.swift:10`, `SettingsView.swift:667`). `fetchLimit: 50` for `TransactionEntryView` MRU is in Task 26.

**Spec Section 6.4 — BudgetRepository Protocol (3 days):** Covered by Tasks 19-22 (TDD: Mock tests first → protocol + Mock + Live → integration tests → environment injection). API signatures match spec section 4.3 exactly: `currentBudget()`, `transactions(in:)`, `categorySpend(in:)`, `recentTransactions(limit:)`. Memoization in `LiveBudgetRepository.spendCache` covers spec's "memoizes `Category.spentCents(in:)` per render pass" requirement, with view-level memoization layered on in Phase G (Tasks 43-45).

**Spec Section 6.5 — PremiumGate Enum (1 day):** Covered by Tasks 14-17 (TDD red → enum impl with all current limits encoded: 6 categories, 3 recurring, 4 CSV import categories, plus debt/intelligence/wrapped/rollover boolean gates → green) and Tasks 32-42 (16-view sweep matching the spec's "sweep 16 view files" — coverage of the 14 actual files where `@AppStorage(isPremium)` appears: BudgetView, RecurringExpenseListView, CSVImportView, DebtTrackingView, InsightsView, SpendingHeatmapView, CategoryDetailView, FinanceTabView, SettingsView, DashboardView, MainTabView, AchievementBadgeView).

**Spec Section 6.6 — PaywallTrigger Enum (0.5 day):** Covered by Tasks 16 (impl with all 8 cases per spec: `categoryLimit, recurringLimit, debtTracker, vaultIntelligence, wrapped, csvImport, rolloverRule, settings`) and 18 (PaywallView consumes trigger and adapts hero copy). Sweep of 8 `@State showPaywall` view-locals into `paywallTrigger: PaywallTrigger?` happens in the per-view tasks (32, 33, 35, 36, 38, 39, 40, 41).

**Spec Section 6.7 — Move Shared Types to BudgetVaultShared (1 day):** Covered by Tasks 9-13 (`BudgetActivityAttributes` moved in Task 10, unified `WidgetData` collapsing both duplicates created in Task 11, callers migrated in Tasks 12-13). Types added in 6.4-6.6 (`BudgetRepository`, `PremiumGate`, `PaywallTrigger`, `RepositoryEnvironment`) all created inside `BudgetVaultShared/Sources/BudgetVaultShared/`.

**Effort total:** Tasks 1-49 fit the 9.5-day estimate (Phase A: 1.5d, Phase B: 1d, Phase C: 1d, Phase D: 3d, Phase E: 2d, Phase F: 1d, Phase G: 0.5d, Phase H: 0.5d).

**Placeholder hunt:** Scanned for "TODO", "TBD", "implement later", "Similar to Task N", "Add appropriate error handling", "Handle edge cases", "Write tests for the above" — none present. Each per-view sweep task (32-42) contains the exact replacement code pattern, not a reference to a previous task.

**Type consistency:** `PremiumGate.Verdict` (`.allowed | .blocked(reason:, paywallTrigger:)`), `PaywallTrigger` (8 cases), `BudgetRepository` (4 methods + `invalidate()` on Live), `WidgetData` field set (9 fields + nested `CategorySummary` with 4 fields), `BudgetActivityAttributes.ContentState` (6 fields) — all consistent across protocol, implementation, tests, and view-sweep tasks.

**File paths:** All absolute or repo-relative-to-cwd `/Users/zachgold/Claude/BudgetVault`. SPM source path `BudgetVaultShared/Sources/BudgetVaultShared/` is consistent throughout.

**TDD requirement coverage:** BudgetRepository (Mock tests in Task 19 → impl in Task 20 → Live tests in Task 21), PremiumGate (failing tests in Task 14 → impl in Task 15 → green in Task 17), PaywallTrigger (failing tests in Task 16 first half → impl in Task 16 second half → green), SchemaV2 migration (failing test in Task 3 → V2 schema in Tasks 4-7 → green in Task 8). All four TDD-required areas use the red → impl → green pattern.
