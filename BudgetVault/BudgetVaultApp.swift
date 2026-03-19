import SwiftUI
import SwiftData
import UserNotifications
import BackgroundTasks
import TipKit
import WidgetKit

class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        let actionIdentifier = response.actionIdentifier

        // Handle "Log Expense" action from notification
        if actionIdentifier == NotificationService.logExpenseActionIdentifier {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .openTransactionEntry, object: nil)
            }
            completionHandler()
            return
        }

        // Handle tap on daily reminder notification
        if let type = userInfo["type"] as? String, type == "dailyReminder" {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .openTransactionEntry, object: nil)
            }
        }
        completionHandler()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}

@main
struct BudgetVaultApp: App {

    private var container: ModelContainer?
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(AppStorageKeys.resetDay) private var resetDay = 1
    @State private var storeKit = StoreKitManager()
    @State private var containerError: String?

    private static let notificationDelegate = NotificationDelegate()
    static let bgRefreshIdentifier = "io.budgetvault.app.refresh"

    init() {
        UNUserNotificationCenter.current().delegate = Self.notificationDelegate

        // Register notification categories with actions
        NotificationService.registerCategories()

        // Configure TipKit
        try? Tips.configure([
            .displayFrequency(.daily),
            .datastoreLocation(.applicationDefault)
        ])

        // Configure iCloud KVS settings sync
        SettingsSyncService.configure()

        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithDefaultBackground()
        navAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor(BudgetVaultTheme.navyDark)]
        navAppearance.titleTextAttributes = [.foregroundColor: UIColor(BudgetVaultTheme.navyDark)]
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance

        let schema = Schema(versionedSchema: BudgetVaultSchemaV1.self)
        let iCloudEnabled = UserDefaults.standard.bool(forKey: AppStorageKeys.iCloudSyncEnabled)

        let config: ModelConfiguration
        if iCloudEnabled {
            config = ModelConfiguration(
                "BudgetVault",
                schema: schema,
                cloudKitDatabase: .private("iCloud.io.budgetvault.app")
            )
        } else {
            config = ModelConfiguration("BudgetVault", schema: schema, cloudKitDatabase: .none)
        }

        do {
            container = try ModelContainer(for: schema, migrationPlan: BudgetVaultMigrationPlan.self, configurations: [config])

            // Set NSFileProtectionComplete on the Application Support directory
            // so the SwiftData store is encrypted at rest and inaccessible while the device is locked.
            if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
                try? (appSupport as NSURL).setResourceValue(
                    URLFileProtection.complete,
                    forKey: .fileProtectionKey
                )
            }
        } catch {
            container = nil
            _containerError = State(initialValue: error.localizedDescription)
        }
    }

    var body: some Scene {
        WindowGroup {
            if let container {
                ContentView()
                    .modelContainer(container)
                    .environment(storeKit)
                    .task {
                        // Debug seeding disabled — use Settings > Seed Sample Data if needed
                    }
                    .onChange(of: scenePhase) { _, newPhase in
                        if newPhase == .active {
                            performMonthRollover(container: container)
                            processRecurringExpenses(container: container)
                            StreakService.processOnForeground()
                            Task { await storeKit.checkEntitlements() }
                            // Schedule re-engagement notifications (reset timer on each foreground)
                            NotificationService.scheduleReengagementNotifications()
                        } else if newPhase == .background {
                            try? container.mainContext.save()
                            scheduleBackgroundRefresh()
                        }
                    }
            } else {
                databaseErrorView
            }
        }
        .backgroundTask(.appRefresh(Self.bgRefreshIdentifier)) {
            await handleBackgroundRefresh()
        }
    }

    // MARK: - Background App Refresh

    private func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Self.bgRefreshIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60) // 1 hour
        try? BGTaskScheduler.shared.submit(request)
    }

    @MainActor
    private func handleBackgroundRefresh() async {
        guard let container else { return }

        // Process overdue recurring expenses
        let _ = RecurringExpenseScheduler.processOverdue(context: container.mainContext)

        // Update widget data
        let rd = max(1, min(UserDefaults.standard.integer(forKey: AppStorageKeys.resetDay), 28))
        WidgetDataService.update(from: container.mainContext, resetDay: rd)

        // Schedule next refresh
        scheduleBackgroundRefresh()
    }

    // MARK: - Database Error Recovery

    private var databaseErrorView: some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.red)

            Text("Database Error")
                .font(.title2.bold())

            Text(containerError ?? "An unknown error occurred while opening the database.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button(role: .destructive) {
                resetDatabase()
            } label: {
                Text("Reset Database")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red, in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 40)

            Text("This will delete all local data and start fresh.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func resetDatabase() {
        let fileManager = FileManager.default
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
        let storeURL = appSupport.appendingPathComponent("BudgetVault.store")
        try? fileManager.removeItem(at: storeURL)
        // Also remove WAL and SHM files
        try? fileManager.removeItem(at: storeURL.appendingPathExtension("wal"))
        try? fileManager.removeItem(at: storeURL.appendingPathExtension("shm"))
        // Prompt user to restart
        containerError = "Database has been reset. Please quit and relaunch the app."
    }

    // MARK: - Month Rollover

    @MainActor
    private func performMonthRollover(container: ModelContainer) {
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

            // Find the source budget for this rollover step
            let srcM = walkMonth
            let srcY = walkYear
            let srcDescriptor = FetchDescriptor<Budget>(
                predicate: #Predicate<Budget> { $0.month == srcM && $0.year == srcY }
            )
            let sourceBudget = (try? context.fetch(srcDescriptor).first) ?? latestBudget

            // Create new budget by cloning the source budget's structure
            let newBudget = Budget(
                month: nextMonth,
                year: nextYear,
                totalIncomeCents: sourceBudget.totalIncomeCents,
                resetDay: resetDay,
                isAutoCreated: true
            )
            context.insert(newBudget)

            // Clone categories from the source budget
            for cat in sourceBudget.categories ?? [] {
                var newBudgetedCents = cat.budgetedAmountCents

                // If rollOverUnspent is enabled, add unspent amount from source
                if cat.rollOverUnspent {
                    let unspent = cat.budgetedAmountCents - cat.spentCents(in: sourceBudget)
                    if unspent > 0 {
                        newBudgetedCents += unspent
                    }
                }

                let newCat = Category(
                    name: cat.name,
                    emoji: cat.emoji,
                    budgetedAmountCents: newBudgetedCents,
                    color: cat.color,
                    sortOrder: cat.sortOrder
                )
                newCat.isHidden = cat.isHidden
                newCat.rollOverUnspent = cat.rollOverUnspent
                newCat.goalAmountCents = cat.goalAmountCents
                newCat.goalDate = cat.goalDate
                newCat.goalType = cat.goalType
                newCat.budget = newBudget
            }

            walkMonth = nextMonth
            walkYear = nextYear
        }

        SafeSave.save(context)

        // Dedup check: merge any duplicate budgets for the same month/year (0.4)
        deduplicateBudgets(context: context)
    }

    /// Removes duplicate budgets for the same month/year, merging categories into the oldest one.
    @MainActor
    private func deduplicateBudgets(context: ModelContext) {
        let descriptor = FetchDescriptor<Budget>(
            sortBy: [SortDescriptor(\Budget.year), SortDescriptor(\Budget.month)]
        )
        guard let allBudgets = try? context.fetch(descriptor) else { return }

        var seen: [String: Budget] = [:]
        for budget in allBudgets {
            let key = "\(budget.year)-\(budget.month)"
            if let existing = seen[key] {
                // Merge: move any categories from the duplicate to the keeper
                for cat in budget.categories ?? [] {
                    let existingNames = Set((existing.categories ?? []).map { $0.name.lowercased() })
                    if !existingNames.contains(cat.name.lowercased()) {
                        cat.budget = existing
                    }
                }
                // Move any transactions that reference categories in the duplicate
                context.delete(budget)
            } else {
                seen[key] = budget
            }
        }
        SafeSave.save(context)
    }

    // MARK: - Recurring Expenses

    @MainActor
    private func processRecurringExpenses(container: ModelContainer) {
        let _ = RecurringExpenseScheduler.processOverdue(context: container.mainContext)
    }

}
