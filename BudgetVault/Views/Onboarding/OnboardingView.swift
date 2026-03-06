import SwiftUI
import SwiftData
import UserNotifications

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("selectedCurrency") private var selectedCurrency = "USD"
    @AppStorage("resetDay") private var resetDay = 1
    @AppStorage("dailyReminderEnabled") private var dailyReminderEnabled = false

    @State private var currentPage = 0
    @State private var monthlyIncome = ""
    @State private var tempCurrency = "USD"
    @State private var selectedTemplate: BudgetTemplate = .single
    @State private var selectedCategories: [(name: String, emoji: String, color: String, pct: Double)] = BudgetTemplate.single.categories
    @State private var budgetCreated = false

    // MARK: - Budget Templates

    private enum BudgetTemplate: String, CaseIterable {
        case single = "Single"
        case couple = "Couple"
        case family = "Family"
        case custom = "Custom"

        var icon: String {
            switch self {
            case .single: return "person.fill"
            case .couple: return "person.2.fill"
            case .family: return "person.3.fill"
            case .custom: return "slider.horizontal.3"
            }
        }

        var categories: [(name: String, emoji: String, color: String, pct: Double)] {
            switch self {
            case .single:
                return [
                    ("Rent", "\u{1F3E0}", "#5856D6", 0.30),
                    ("Groceries", "\u{1F6D2}", "#34C759", 0.15),
                    ("Transport", "\u{1F697}", "#FF9500", 0.10),
                    ("Dining Out", "\u{1F37D}\u{FE0F}", "#FF2D55", 0.10),
                    ("Entertainment", "\u{1F3AC}", "#AF52DE", 0.05),
                    ("Savings", "\u{1F3E6}", "#007AFF", 0.10),
                ]
            case .couple:
                return [
                    ("Housing", "\u{1F3E0}", "#5856D6", 0.30),
                    ("Groceries", "\u{1F6D2}", "#34C759", 0.15),
                    ("Dining Out", "\u{1F37D}\u{FE0F}", "#FF2D55", 0.10),
                    ("Transport", "\u{1F697}", "#FF9500", 0.10),
                    ("Date Night", "\u{2764}\u{FE0F}", "#AF52DE", 0.05),
                    ("Savings", "\u{1F3E6}", "#007AFF", 0.10),
                ]
            case .family:
                return [
                    ("Housing", "\u{1F3E0}", "#5856D6", 0.30),
                    ("Groceries", "\u{1F6D2}", "#34C759", 0.15),
                    ("Kids", "\u{1F476}", "#FF2D55", 0.10),
                    ("Transport", "\u{1F697}", "#FF9500", 0.10),
                    ("Utilities", "\u{1F4A1}", "#FFCC00", 0.05),
                    ("Savings", "\u{1F3E6}", "#007AFF", 0.10),
                ]
            case .custom:
                return []
            }
        }
    }

    var body: some View {
        TabView(selection: $currentPage) {
            welcomePage.tag(0)
            envelopeExplainerPage.tag(1)
            currencyPage.tag(2)
            templatePage.tag(3)
            budgetSetupPage.tag(4)
            notificationPage.tag(5)
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .animation(.easeInOut, value: currentPage)
        .onAppear { tempCurrency = selectedCurrency }
    }

    // MARK: - Page 0: Welcome + Privacy

    private var welcomePage: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "vault.fill")
                .font(.system(size: 80))
                .foregroundStyle(Color.accentColor)

            Text("Welcome to BudgetVault")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)

            Text("Your budget stays on your device. No accounts, no servers, no tracking.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            Button {
                withAnimation { currentPage = 1 }
            } label: {
                Text("Get Started")
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Page 1: Envelope Explainer

    private var envelopeExplainerPage: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "tray.2.fill")
                .font(.system(size: 64))
                .foregroundStyle(Color.accentColor)
                .symbolEffect(.pulse)

            Text("Envelope Budgeting")
                .font(.title2.bold())

            VStack(alignment: .leading, spacing: 16) {
                explainerStep(number: "1", text: "Divide your income into spending categories")
                explainerStep(number: "2", text: "Spend from each envelope throughout the month")
                explainerStep(number: "3", text: "When an envelope is empty, stop or move money")
            }
            .padding(.horizontal, 32)

            Text("It's the method behind YNAB, used by millions \u{2014} now private and on your device.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            Button { withAnimation { currentPage = 2 } } label: { Text("Continue") }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
        }
    }

    private func explainerStep(number: String, text: String) -> some View {
        HStack(spacing: 12) {
            Text(number)
                .font(.headline)
                .frame(width: 32, height: 32)
                .background(Color.accentColor.opacity(0.15), in: Circle())
            Text(text)
                .font(.subheadline)
        }
    }

    // MARK: - Page 2: Currency

    private var currencyPage: some View {
        VStack(spacing: 16) {
            Text("Choose Your Currency")
                .font(.title2.bold())
                .padding(.top, 32)

            CurrencyPickerView(selectedCurrency: $tempCurrency)

            Button {
                selectedCurrency = tempCurrency
                withAnimation { currentPage = 3 }
            } label: {
                Text("Continue")
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Page 3: Template Selection + Category Customization

    private var templatePage: some View {
        VStack(spacing: 16) {
            Text("Choose a Template")
                .font(.title2.bold())
                .padding(.top, 32)

            Text("Pick a starting point, then customize your categories.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            // Template grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(BudgetTemplate.allCases, id: \.rawValue) { template in
                    Button {
                        selectedTemplate = template
                        selectedCategories = template.categories
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: template.icon)
                                .font(.title2)
                            Text(template.rawValue)
                                .font(.subheadline.bold())
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(selectedTemplate == template ? Color.accentColor.opacity(0.15) : Color(.secondarySystemBackground))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(selectedTemplate == template ? Color.accentColor : Color.clear, lineWidth: 2)
                        )
                    }
                    .foregroundStyle(selectedTemplate == template ? Color.accentColor : .primary)
                }
            }
            .padding(.horizontal, 24)

            // Category list
            if !selectedCategories.isEmpty {
                List {
                    ForEach(selectedCategories.indices, id: \.self) { index in
                        HStack(spacing: 12) {
                            Text(selectedCategories[index].emoji)
                                .font(.title3)
                            TextField("Category name", text: Binding(
                                get: { selectedCategories[index].name },
                                set: { selectedCategories[index].name = $0 }
                            ))
                            .textFieldStyle(.plain)
                            Spacer()
                            Text("\(Int(selectedCategories[index].pct * 100))%")
                                .foregroundStyle(.secondary)
                                .font(.subheadline)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                selectedCategories.remove(at: index)
                            } label: {
                                Label("Remove", systemImage: "trash")
                            }
                        }
                    }

                    Button {
                        selectedCategories.append(("New Category", "\u{1F4E6}", "#8E8E93", 0.05))
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(Color.accentColor)
                            Text("Add Category")
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                }
                .listStyle(.plain)
            } else {
                // Custom template with empty list
                List {
                    Button {
                        selectedCategories.append(("New Category", "\u{1F4E6}", "#8E8E93", 0.05))
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(Color.accentColor)
                            Text("Add Category")
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                }
                .listStyle(.plain)
            }

            Button {
                withAnimation { currentPage = 4 }
            } label: {
                Text("Continue")
            }
            .buttonStyle(PrimaryButtonStyle(isEnabled: !selectedCategories.isEmpty))
            .disabled(selectedCategories.isEmpty)
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Page 4: Income Entry + Preview

    private var budgetSetupPage: some View {
        VStack(spacing: 24) {
            Text("Set Your Monthly Income")
                .font(.title2.bold())
                .padding(.top, 32)

            let totalPct = selectedCategories.reduce(0.0) { $0 + $1.pct }
            let pctString = String(format: "%.0f", totalPct * 100)
            Text("We'll allocate \(pctString)% across your \(selectedCategories.count) categories. You can customize everything later.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            HStack {
                Text(currencySymbol)
                    .font(.title)
                    .foregroundStyle(.secondary)
                TextField("0", text: $monthlyIncome)
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 40)

            if let cents = MoneyHelpers.parseCurrencyString(monthlyIncome), cents > 0 {
                let allocated = selectedCategories.reduce(Int64(0)) { $0 + Int64(Double(cents) * $1.pct) }
                let totalPctVal = selectedCategories.reduce(0.0) { $0 + $1.pct }
                VStack(spacing: 8) {
                    ForEach(selectedCategories.indices, id: \.self) { index in
                        let cat = selectedCategories[index]
                        let catCents = Int64(Double(cents) * cat.pct)
                        HStack {
                            Text("\(cat.emoji) \(cat.name) (\(Int(cat.pct * 100))%)")
                            Spacer()
                            Text(CurrencyFormatter.format(cents: catCents))
                                .foregroundStyle(.secondary)
                        }
                        .font(.subheadline)
                    }

                    if totalPctVal < 1.0 {
                        let unallocatedPct = Int((1.0 - totalPctVal) * 100)
                        HStack {
                            Text("Unallocated (\(unallocatedPct)%)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(CurrencyFormatter.format(cents: cents - allocated))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(.horizontal, 40)
            }

            Spacer()

            Button {
                completeOnboarding()
            } label: {
                Text("Create My Budget")
            }
            .buttonStyle(PrimaryButtonStyle(isEnabled: isValidIncome))
            .disabled(!isValidIncome)
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Page 5: Notifications

    private var notificationPage: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "bell.badge.fill")
                .font(.system(size: 64))
                .foregroundStyle(.orange)

            Text("Stay on Track")
                .font(.title2.bold())

            Text("A daily reminder helps you log expenses before you forget. Most BudgetVault users log at 8pm.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                requestNotificationPermission()
            } label: {
                Text("Enable Daily Reminder")
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, 40)

            Button {
                finishOnboarding()
            } label: {
                Text("Not Now")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    // MARK: - Helpers

    private var isValidIncome: Bool {
        guard let cents = MoneyHelpers.parseCurrencyString(monthlyIncome) else { return false }
        return cents > 0
    }

    private var currencySymbol: String {
        CurrencyPickerView.currencies.first { $0.code == selectedCurrency }?.symbol ?? "$"
    }

    private func completeOnboarding() {
        guard let incomeCents = MoneyHelpers.parseCurrencyString(monthlyIncome), incomeCents > 0 else { return }

        let (month, year) = DateHelpers.currentBudgetPeriod(resetDay: resetDay)
        let budget = Budget(month: month, year: year, totalIncomeCents: incomeCents, resetDay: resetDay)
        modelContext.insert(budget)

        for (index, cat) in selectedCategories.enumerated() {
            let catCents = Int64(Double(incomeCents) * cat.pct)
            let category = Category(name: cat.name, emoji: cat.emoji, budgetedAmountCents: catCents, color: cat.color, sortOrder: index)
            category.budget = budget
        }

        SafeSave.save(modelContext)
        budgetCreated = true
        withAnimation { currentPage = 5 }
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            DispatchQueue.main.async {
                if granted {
                    NotificationService.scheduleDailyReminder(hour: 20)
                    dailyReminderEnabled = true
                }
                finishOnboarding()
            }
        }
    }

    private func finishOnboarding() {
        hasCompletedOnboarding = true
    }
}
