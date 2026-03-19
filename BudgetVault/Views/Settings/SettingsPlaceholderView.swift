import SwiftUI
import SwiftData
import StoreKit

struct SettingsPlaceholderView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage(AppStorageKeys.biometricLockEnabled) private var biometricLockEnabled = false
    @AppStorage(AppStorageKeys.selectedCurrency) private var selectedCurrency = "USD"
    @AppStorage(AppStorageKeys.resetDay) private var resetDay = 1
    @AppStorage(AppStorageKeys.userName) private var userName = ""
    // Synced by StoreKitManager.checkEntitlements() on every launch
    @AppStorage(AppStorageKeys.isPremium) private var isPremium = false
    @AppStorage(AppStorageKeys.dailyReminderEnabled) private var dailyReminderEnabled = false
    @AppStorage(AppStorageKeys.dailyReminderHour) private var dailyReminderHour = 20
    @AppStorage(AppStorageKeys.weeklyDigestEnabled) private var weeklyDigestEnabled = false
    @AppStorage(AppStorageKeys.billDueReminders) private var billDueReminders = false
    @AppStorage(AppStorageKeys.reviewPromptCount) private var reviewPromptCount = 0
    @AppStorage(AppStorageKeys.iCloudSyncEnabled) private var iCloudSyncEnabled = false

    @AppStorage(AppStorageKeys.accentColorHex) private var accentColorHex = "#2563EB"

    @State private var showRecurring = false
    @State private var showRestartAlert = false
    @State private var cloudSync = CloudSyncService()
    @State private var showPaywall = false
    @State private var showCurrencyPicker = false
    @State private var showCSVImport = false
    @State private var exportURL: URL?
    @State private var showExportShare = false
    @State private var tempCurrency = ""
    @State private var showThemePicker = false
    @State private var showBudgetTemplates = false
    @State private var showDebtTracking = false
    @State private var showNetWorth = false
    @State private var showAchievements = false
    @State private var templateAppliedAlert = false
    @Environment(StoreKitManager.self) private var storeKit
    @State private var showNotificationDeniedAlert = false
    @State private var showExportError = false
    @State private var exportErrorMessage = ""
    @State private var showDeleteAllConfirm = false
    @State private var showDeleteAllFinalConfirm = false

    var body: some View {
        NavigationStack {
            Form {
                premiumBadge
                securitySection
                profileSection
                dataSection
                notificationsSection
                premiumSection
                iCloudSection
                aboutSection
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showRecurring) {
                NavigationStack {
                    RecurringExpenseListView()
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .sheet(isPresented: $showCurrencyPicker) {
                NavigationStack {
                    CurrencyPickerView(selectedCurrency: $tempCurrency)
                        .navigationTitle("Currency")
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") {
                                    selectedCurrency = tempCurrency
                                    showCurrencyPicker = false
                                }
                            }
                        }
                }
            }
            .sheet(isPresented: $showCSVImport) {
                CSVImportView()
            }
            .sheet(isPresented: $showExportShare) {
                if let url = exportURL {
                    ShareSheetView(url: url)
                }
            }
            .sheet(isPresented: $showThemePicker) {
                ThemePickerView()
            }
            .sheet(isPresented: $showBudgetTemplates) {
                BudgetTemplateSheetView()
            }
            .sheet(isPresented: $showDebtTracking) {
                DebtTrackingView()
            }
            .sheet(isPresented: $showNetWorth) {
                NetWorthView()
            }
            .sheet(isPresented: $showAchievements) {
                AchievementGridView()
            }
            .alert("Template Applied", isPresented: $templateAppliedAlert) {
                Button("OK") {}
            } message: {
                Text("Missing categories from the template have been added to your current budget.")
            }
            .alert("Export Failed", isPresented: $showExportError) {
                Button("OK") {}
            } message: {
                Text(exportErrorMessage)
            }
            .alert("Delete All Data?", isPresented: $showDeleteAllConfirm) {
                Button("Export Data First") {
                    // Trigger export, then show final confirm
                    do {
                        let url = try CSVExporter.export(context: modelContext, premiumOnly: isPremium, resetDay: resetDay)
                        exportURL = url
                        showExportShare = true
                    } catch {
                        // If export fails, go straight to final confirm
                        showDeleteAllFinalConfirm = true
                    }
                }
                Button("Continue Without Exporting", role: .destructive) {
                    showDeleteAllFinalConfirm = true
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("We recommend exporting your data before deleting. This cannot be undone.")
            }
            .alert("Are you sure?", isPresented: $showDeleteAllFinalConfirm) {
                Button("Delete Everything", role: .destructive) {
                    deleteAllData()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete all budgets, transactions, and settings. This action cannot be undone.")
            }
        }
    }

    // MARK: - Premium Badge

    private var premiumBadge: some View {
        Section {
            if isPremium || storeKit.isPremium {
                HStack(spacing: 8) {
                    VaultDialMark(size: 22, color: BudgetVaultTheme.electricBlue)
                    Text("BudgetVault Premium")
                        .font(.subheadline.bold())
                        .foregroundStyle(BudgetVaultTheme.electricBlue)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .listRowBackground(BudgetVaultTheme.electricBlue.opacity(0.08))
            } else {
                Button {
                    showPaywall = true
                } label: {
                    HStack(spacing: 10) {
                        VaultDialMark(size: 28, color: .white)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("BudgetVault Premium")
                                .font(.subheadline.bold())
                                .foregroundStyle(.white)
                            Text("Open the full vault")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.8))
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.bold())
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(BudgetVaultTheme.brandGradient)
                        .padding(.vertical, 2)
                )
            }
        }
    }

    // MARK: - Security

    private var securitySection: some View {
        Section("Security") {
            Toggle(isOn: $biometricLockEnabled) {
                Label("Biometric Lock", systemImage: "faceid")
            }
        }
    }

    // MARK: - Profile

    private var profileSection: some View {
        Section("Profile") {
            HStack {
                Text("Name")
                Spacer()
                TextField("Your name", text: $userName)
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(.secondary)
            }

            Button {
                tempCurrency = selectedCurrency
                showCurrencyPicker = true
            } label: {
                HStack {
                    Text("Currency")
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(selectedCurrency)
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Button {
                if isPremium {
                    showThemePicker = true
                } else {
                    showPaywall = true
                }
            } label: {
                HStack {
                    Text("Accent Color")
                        .foregroundStyle(.primary)
                    Spacer()
                    Circle()
                        .fill(Color(hex: accentColorHex))
                        .frame(width: 22, height: 22)
                    if !isPremium {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Picker("Budget Reset Day", selection: $resetDay) {
                ForEach(1...28, id: \.self) { day in
                    Text("\(day)").tag(day)
                }
            }

            Text("Changing the reset day takes effect next month.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Data

    private var dataSection: some View {
        Section("Data") {
            Button {
                showRecurring = true
            } label: {
                Label("Recurring Expenses", systemImage: "repeat")
            }

            Button {
                do {
                    let url = try CSVExporter.export(context: modelContext, premiumOnly: isPremium, resetDay: resetDay)
                    exportURL = url
                    showExportShare = true
                } catch {
                    exportErrorMessage = error.localizedDescription
                    showExportError = true
                }
            } label: {
                Label(isPremium ? "Export CSV (Full History)" : "Export CSV (Last 30 Days)", systemImage: "square.and.arrow.up")
            }

            Button {
                if isPremium {
                    showCSVImport = true
                } else {
                    showPaywall = true
                }
            } label: {
                HStack {
                    Label("Import CSV", systemImage: "square.and.arrow.down")
                    if !isPremium {
                        Spacer()
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Button {
                showBudgetTemplates = true
            } label: {
                Label("Budget Templates", systemImage: "doc.on.doc")
            }

            // TODO: Re-enable Debt Tracking and Net Worth once fully tested
            // Button {
            //     if isPremium {
            //         showDebtTracking = true
            //     } else {
            //         showPaywall = true
            //     }
            // } label: {
            //     HStack {
            //         Label("Debt Tracking", systemImage: "creditcard.fill")
            //         if !isPremium {
            //             Spacer()
            //             Image(systemName: "star.fill")
            //                 .font(.caption)
            //                 .foregroundStyle(.secondary)
            //         }
            //     }
            // }

            // Button {
            //     if isPremium {
            //         showNetWorth = true
            //     } else {
            //         showPaywall = true
            //     }
            // } label: {
            //     HStack {
            //         Label("Net Worth", systemImage: "chart.line.uptrend.xyaxis")
            //         if !isPremium {
            //             Spacer()
            //             Image(systemName: "star.fill")
            //                 .font(.caption)
            //                 .foregroundStyle(.secondary)
            //         }
            //     }
            // }

            Button {
                showAchievements = true
            } label: {
                Label("Achievements", systemImage: "trophy.fill")
            }

            Button(role: .destructive) {
                showDeleteAllConfirm = true
            } label: {
                Label("Delete All Data", systemImage: "trash.fill")
                    .foregroundStyle(.red)
            }
        }
    }

    // MARK: - Notifications

    private var notificationsSection: some View {
        Section("Notifications") {
            Toggle("Daily Reminder", isOn: $dailyReminderEnabled)
                .onChange(of: dailyReminderEnabled) { _, enabled in
                    if enabled {
                        checkNotificationPermission()
                        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                            if granted {
                                DispatchQueue.main.async {
                                    NotificationService.scheduleDailyReminder(hour: dailyReminderHour)
                                }
                            }
                        }
                    } else {
                        NotificationService.cancelDailyReminder()
                    }
                }

            if dailyReminderEnabled {
                Picker("Reminder Time", selection: $dailyReminderHour) {
                    ForEach(6...23, id: \.self) { hour in
                        Text(formatHour(hour)).tag(hour)
                    }
                }
                .onChange(of: dailyReminderHour) { _, newHour in
                    NotificationService.scheduleDailyReminder(hour: newHour)
                }
            }

            Toggle("Weekly Summary", isOn: $weeklyDigestEnabled)
                .onChange(of: weeklyDigestEnabled) { _, enabled in
                    if enabled {
                        checkNotificationPermission()
                        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                            if granted {
                                DispatchQueue.main.async {
                                    NotificationService.scheduleWeeklySummary()
                                }
                            }
                        }
                    } else {
                        NotificationService.cancelWeeklySummary()
                    }
                }

            Toggle("Bill Due Reminders", isOn: $billDueReminders)
                .onChange(of: billDueReminders) { _, enabled in
                    if enabled {
                        checkNotificationPermission()
                        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
                    }
                }
        }
        .alert("Notifications Disabled", isPresented: $showNotificationDeniedAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Notifications are disabled for BudgetVault. Please enable them in Settings to receive reminders.")
        }
    }

    // MARK: - Premium

    private var premiumSection: some View {
        Section("Premium") {
            if isPremium || storeKit.isPremium {
                HStack {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(BudgetVaultTheme.positive)
                    Text("BudgetVault Premium")
                        .font(.subheadline.bold())
                    Spacer()
                    Text("Active")
                        .font(.caption)
                        .foregroundStyle(BudgetVaultTheme.positive)
                }
            } else {
                Button {
                    showPaywall = true
                } label: {
                    HStack {
                        Image(systemName: "star.fill")
                            .foregroundStyle(BudgetVaultTheme.caution)
                        Text("Upgrade to Premium")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            if !isPremium && !storeKit.isPremium {
                Button("Restore Purchases") {
                    Task { await storeKit.restorePurchases() }
                }
                .font(.subheadline)
            }

            if storeKit.tipProduct != nil {
                Button {
                    Task {
                        if let tip = storeKit.tipProduct {
                            await storeKit.purchase(tip)
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(.pink)
                        Text("Leave a Tip")
                        Spacer()
                        Text(storeKit.tipProduct?.displayPrice ?? "")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - iCloud

    private var iCloudSection: some View {
        Section("iCloud Sync") {
            Toggle("iCloud Sync", isOn: Binding(
                get: { iCloudSyncEnabled },
                set: { newValue in
                    iCloudSyncEnabled = newValue
                    showRestartAlert = true
                }
            ))

            if iCloudSyncEnabled {
                HStack {
                    Text("Last Sync")
                    Spacer()
                    if cloudSync.isSyncing {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text(cloudSync.lastSyncText)
                            .foregroundStyle(.secondary)
                    }
                }

                if let error = cloudSync.syncError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(BudgetVaultTheme.negative)
                }
            }

            Text("Data stays on Apple's servers only. No third-party servers.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .alert("Restart Required", isPresented: $showRestartAlert) {
            Button("OK") {}
        } message: {
            Text("Enabling or disabling iCloud sync requires restarting the app. Please quit and relaunch BudgetVault.")
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        Section("About") {
            HStack {
                Text("Version")
                Spacer()
                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                    .foregroundStyle(.secondary)
            }

            ShareLink(item: URL(string: "https://budgetvault.io")!,
                       subject: Text("BudgetVault"),
                       message: Text("I use BudgetVault to manage my budget \u{2014} private, on-device, and no subscription. Check it out!")) {
                Label("Share BudgetVault", systemImage: "heart.fill")
            }

            Text("Your data never leaves this device.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Link(destination: URL(string: "https://budgetvault.io/privacy")!) {
                Label("Privacy Policy", systemImage: "hand.raised.fill")
            }

            Link(destination: URL(string: "https://budgetvault.io/terms")!) {
                Label("Terms of Service", systemImage: "doc.text.fill")
            }
        }
    }

    // MARK: - Helpers

    private func checkNotificationPermission() {
        Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            if settings.authorizationStatus == .denied {
                await MainActor.run {
                    showNotificationDeniedAlert = true
                }
            }
        }
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            if !granted {
                DispatchQueue.main.async {
                    // Could show alert to open Settings
                }
            }
        }
    }

    private static let hourFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }()

    private func deleteAllData() {
        // Delete all model objects
        let types: [any PersistentModel.Type] = [
            Budget.self, Category.self, Transaction.self,
            RecurringExpense.self, DebtAccount.self, DebtPayment.self,
            NetWorthAccount.self, NetWorthSnapshot.self
        ]
        for type in types {
            try? modelContext.delete(model: type)
        }
        try? modelContext.save()

        // Reset UserDefaults — enumerate all keys and remove any that match app prefixes
        // This catches dynamic keys like "lastCategoryAlert-*" and "underBudget_*_*"
        let appPrefixes = [
            "resetDay", "hasCompleted", "hasLogged", "userName", "isPremium",
            "debugPremium", "lastPaywall", "reviewPrompt", "selectedCurrency",
            "accentColor", "biometricLock", "currentStreak", "lastLog",
            "streakFreezes", "lastFreeze", "lastSummary", "dailyReminder",
            "weeklyDigest", "billDue", "iCloudSync", "underBudget",
            "lastCategoryAlert", "unlockedAchievements",
        ]
        for key in UserDefaults.standard.dictionaryRepresentation().keys {
            if appPrefixes.contains(where: { key.hasPrefix($0) }) {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
        NotificationService.cancelDailyReminder()
        NotificationService.cancelWeeklySummary()
    }

    private func formatHour(_ hour: Int) -> String {
        var components = DateComponents()
        components.hour = hour
        components.minute = 0
        guard let date = Calendar.current.date(from: components) else { return "\(hour):00" }
        return Self.hourFormatter.string(from: date)
    }
}

// MARK: - Budget Template Sheet

struct BudgetTemplateSheetView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppStorageKeys.resetDay) private var resetDay = 1
    @AppStorage(AppStorageKeys.isPremium) private var isPremium = false

    @Query(sort: [SortDescriptor(\Budget.year, order: .reverse), SortDescriptor(\Budget.month, order: .reverse)]) private var allBudgets: [Budget]

    @State private var showAppliedAlert = false
    @State private var appliedTemplateName = ""

    private var currentBudget: Budget? {
        let (m, y) = DateHelpers.currentBudgetPeriod(resetDay: resetDay)
        return allBudgets.first { $0.month == m && $0.year == y }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Applying a template adds any missing categories to your current budget. Existing categories are not removed.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                ForEach(BudgetTemplates.settingsTemplates, id: \.name) { template in
                    Button {
                        applyTemplate(template)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: template.icon)
                                .font(.title3)
                                .foregroundStyle(Color.accentColor)
                                .frame(width: 32)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(template.name)
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.primary)
                                Text(template.categories.map(\.emoji).joined(separator: " "))
                                    .font(.caption)
                            }

                            Spacer()

                            Image(systemName: "plus.circle")
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                }
            }
            .navigationTitle("Budget Templates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Template Applied", isPresented: $showAppliedAlert) {
                Button("OK") { dismiss() }
            } message: {
                Text("Categories from \"\(appliedTemplateName)\" have been added to your budget.")
            }
        }
    }

    private func applyTemplate(_ template: BudgetTemplates.SettingsTemplate) {
        guard let budget = currentBudget else { return }
        let existingNames = Set((budget.categories ?? []).map { $0.name.lowercased() })
        let maxSortOrder = (budget.categories ?? []).map(\.sortOrder).max() ?? 0
        var nextOrder = maxSortOrder + 1

        let currentCount = (budget.categories ?? []).filter { !$0.isHidden }.count
        let freeLimit = 6
        var added = 0

        for cat in template.categories {
            guard !existingNames.contains(cat.name.lowercased()) else { continue }
            if !isPremium && (currentCount + added) >= freeLimit { break }
            let newCategory = Category(
                name: cat.name,
                emoji: cat.emoji,
                budgetedAmountCents: 0,
                color: cat.color,
                sortOrder: nextOrder
            )
            newCategory.budget = budget
            modelContext.insert(newCategory)
            nextOrder += 1
            added += 1
        }

        try? modelContext.save()
        appliedTemplateName = template.name
        showAppliedAlert = true
    }
}
