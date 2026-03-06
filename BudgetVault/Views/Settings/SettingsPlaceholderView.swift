import SwiftUI
import StoreKit

struct SettingsPlaceholderView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("biometricLockEnabled") private var biometricLockEnabled = false
    @AppStorage("selectedCurrency") private var selectedCurrency = "USD"
    @AppStorage("resetDay") private var resetDay = 1
    @AppStorage("userName") private var userName = ""
    @AppStorage("isPremium") private var isPremium = false
    @AppStorage("dailyReminderEnabled") private var dailyReminderEnabled = false
    @AppStorage("dailyReminderHour") private var dailyReminderHour = 20
    @AppStorage("weeklyDigestEnabled") private var weeklyDigestEnabled = false
    @AppStorage("billDueReminders") private var billDueReminders = false
    @AppStorage("reviewPromptCount") private var reviewPromptCount = 0
    @AppStorage("iCloudSyncEnabled") private var iCloudSyncEnabled = false

    @State private var showRecurring = false
    @State private var showRestartAlert = false
    @State private var cloudSync = CloudSyncService()
    @State private var showPaywall = false
    @State private var showCurrencyPicker = false
    @State private var showCSVImport = false
    @State private var exportURL: URL?
    @State private var showExportShare = false
    @State private var tempCurrency = ""
    @Environment(StoreKitManager.self) private var storeKit
    @State private var showNotificationDeniedAlert = false

    var body: some View {
        NavigationStack {
            Form {
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
                if let url = CSVExporter.export(context: modelContext, premiumOnly: isPremium, resetDay: resetDay) {
                    exportURL = url
                    showExportShare = true
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
                        Image(systemName: "lock.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
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
                        requestNotificationPermission()
                        NotificationService.scheduleDailyReminder(hour: dailyReminderHour)
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
                        requestNotificationPermission()
                        NotificationService.scheduleWeeklySummary()
                    } else {
                        NotificationService.cancelWeeklySummary()
                    }
                }

            Toggle("Bill Due Reminders", isOn: $billDueReminders)
                .onChange(of: billDueReminders) { _, enabled in
                    if enabled {
                        checkNotificationPermission()
                        requestNotificationPermission()
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
                        .foregroundStyle(.green)
                    Text("BudgetVault Premium")
                        .font(.subheadline.bold())
                    Spacer()
                    Text("Active")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            } else {
                Button {
                    showPaywall = true
                } label: {
                    HStack {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                        Text("Upgrade to Premium")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
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
                        .foregroundStyle(.red)
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

            ShareLink(item: URL(string: "https://apps.apple.com/app/budgetvault/id000000000")!,
                       subject: Text("BudgetVault"),
                       message: Text("I use BudgetVault to manage my budget \u{2014} private, on-device, and no subscription. Check it out!")) {
                Label("Share BudgetVault", systemImage: "heart.fill")
            }

            Link(destination: URL(string: "https://budgetvault.app/privacy")!) {
                Label("Privacy Policy", systemImage: "hand.raised.fill")
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

    private func formatHour(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        var components = DateComponents()
        components.hour = hour
        components.minute = 0
        guard let date = Calendar.current.date(from: components) else { return "\(hour):00" }
        return formatter.string(from: date)
    }
}
