import SwiftUI
import SwiftData

@main
struct BudgetVaultApp: App {

    let container: ModelContainer
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("resetDay") private var resetDay = 1
    @State private var storeKit = StoreKitManager()

    init() {
        let schema = Schema(versionedSchema: BudgetVaultSchemaV1.self)
        let iCloudEnabled = UserDefaults.standard.bool(forKey: "iCloudSyncEnabled")

        let config: ModelConfiguration
        if iCloudEnabled {
            config = ModelConfiguration(
                "BudgetVault",
                schema: schema,
                cloudKitDatabase: .private("iCloud.com.budgetvault.app")
            )
        } else {
            config = ModelConfiguration("BudgetVault", schema: schema)
        }

        do {
            container = try ModelContainer(for: schema, migrationPlan: BudgetVaultMigrationPlan.self, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                performMonthRollover()
                processRecurringExpenses()
                updateWidgetData()
            }
        }
    }

    // MARK: - Month Rollover

    @MainActor
    private func performMonthRollover() {
        let context = container.mainContext
        let (currentMonth, currentYear) = DateHelpers.currentBudgetPeriod(resetDay: resetDay)

        // Find the most recent budget
        var descriptor = FetchDescriptor<Budget>(
            sortBy: [SortDescriptor(\Budget.year, order: .reverse), SortDescriptor(\Budget.month, order: .reverse)]
        )
        descriptor.fetchLimit = 1

        guard let latestBudget = try? context.fetch(descriptor).first else { return }

        // Walk forward from latest budget until we reach current period
        var walkMonth = latestBudget.month
        var walkYear = latestBudget.year

        while (walkYear < currentYear) || (walkYear == currentYear && walkMonth < currentMonth) {
            let (nextMonth, nextYear) = DateHelpers.nextMonth(from: walkMonth, year: walkYear)

            // Check if this budget already exists
            let m = nextMonth
            let y = nextYear
            let checkDescriptor = FetchDescriptor<Budget>(
                predicate: #Predicate<Budget> { $0.month == m && $0.year == y }
            )
            if let existing = try? context.fetch(checkDescriptor), !existing.isEmpty {
                walkMonth = nextMonth
                walkYear = nextYear
                continue
            }

            // Create new budget by cloning the latest budget's structure
            let newBudget = Budget(
                month: nextMonth,
                year: nextYear,
                totalIncomeCents: latestBudget.totalIncomeCents,
                resetDay: resetDay,
                isAutoCreated: true
            )
            context.insert(newBudget)

            // Clone categories from the latest budget
            for cat in latestBudget.categories {
                let newCat = Category(
                    name: cat.name,
                    emoji: cat.emoji,
                    budgetedAmountCents: cat.budgetedAmountCents,
                    color: cat.color,
                    sortOrder: cat.sortOrder
                )
                newCat.isHidden = cat.isHidden
                newCat.rollOverUnspent = cat.rollOverUnspent
                newCat.budget = newBudget
            }

            walkMonth = nextMonth
            walkYear = nextYear
        }

        try? context.save()
    }

    // MARK: - Recurring Expenses

    @MainActor
    private func processRecurringExpenses() {
        let _ = RecurringExpenseScheduler.processOverdue(context: container.mainContext)
    }

    // MARK: - Widget Data

    @MainActor
    private func updateWidgetData() {
        WidgetDataService.update(from: container.mainContext, resetDay: resetDay)
    }
}
