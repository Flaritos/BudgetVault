import SwiftUI
import SwiftData
import UserNotifications

class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
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
    @AppStorage("resetDay") private var resetDay = 1
    @State private var storeKit = StoreKitManager()
    @State private var containerError: String?

    private let notificationDelegate = NotificationDelegate()

    init() {
        UNUserNotificationCenter.current().delegate = notificationDelegate

        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithDefaultBackground()
        navAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor(BudgetVaultTheme.navyDark)]
        navAppearance.titleTextAttributes = [.foregroundColor: UIColor(BudgetVaultTheme.navyDark)]
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance

        let schema = Schema(versionedSchema: BudgetVaultSchemaV1.self)
        let iCloudEnabled = UserDefaults.standard.bool(forKey: "iCloudSyncEnabled")

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
                        #if DEBUG
                        DebugSeedService.seedSampleData(container: container)
                        #endif
                    }
                    .onChange(of: scenePhase) { _, newPhase in
                        if newPhase == .active {
                            performMonthRollover(container: container)
                            processRecurringExpenses(container: container)
                            updateWidgetData(container: container)
                            StreakService.processOnForeground()
                            Task { await storeKit.checkEntitlements() }
                        }
                    }
            } else {
                databaseErrorView
            }
        }
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
                newCat.budget = newBudget
            }

            walkMonth = nextMonth
            walkYear = nextYear
        }

        SafeSave.save(context)
    }

    // MARK: - Recurring Expenses

    @MainActor
    private func processRecurringExpenses(container: ModelContainer) {
        let _ = RecurringExpenseScheduler.processOverdue(context: container.mainContext)
    }

    // MARK: - Widget Data

    @MainActor
    private func updateWidgetData(container: ModelContainer) {
        WidgetDataService.update(from: container.mainContext, resetDay: resetDay)
    }
}
