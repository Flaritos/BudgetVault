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

    @State private var showRecurring = false
    @State private var showPaywall = false
    @State private var showCurrencyPicker = false
    @State private var showCSVImport = false
    @State private var exportURL: URL?
    @State private var showExportShare = false
    @State private var tempCurrency = ""
    @State private var storeKit = StoreKitManager()

    var body: some View {
        NavigationStack {
            Form {
                securitySection
                profileSection
                dataSection
                notificationsSection
                premiumSection
                // iCloud: HIDDEN until Step 8
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
                    if enabled { requestNotificationPermission() }
                }

            if dailyReminderEnabled {
                Picker("Reminder Time", selection: $dailyReminderHour) {
                    ForEach(6...23, id: \.self) { hour in
                        Text(formatHour(hour)).tag(hour)
                    }
                }
            }

            Toggle("Weekly Summary", isOn: $weeklyDigestEnabled)
                .onChange(of: weeklyDigestEnabled) { _, enabled in
                    if enabled { requestNotificationPermission() }
                }

            Toggle("Bill Due Reminders", isOn: $billDueReminders)
                .onChange(of: billDueReminders) { _, enabled in
                    if enabled { requestNotificationPermission() }
                }
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

    // MARK: - About

    private var aboutSection: some View {
        Section("About") {
            HStack {
                Text("Version")
                Spacer()
                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                    .foregroundStyle(.secondary)
            }

            // Privacy policy placeholder
            Button {
                // Will open SafariView with privacy policy URL
            } label: {
                Label("Privacy Policy", systemImage: "hand.raised.fill")
            }
        }
    }

    // MARK: - Helpers

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
