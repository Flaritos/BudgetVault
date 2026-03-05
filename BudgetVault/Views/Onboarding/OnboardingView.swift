import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("selectedCurrency") private var selectedCurrency = "USD"
    @AppStorage("resetDay") private var resetDay = 1

    @State private var currentPage = 0
    @State private var monthlyIncome = ""
    @State private var tempCurrency = "USD"

    private let defaultCategories: [(name: String, emoji: String, color: String, pct: Double)] = [
        ("Rent", "🏠", "#5856D6", 0.30),
        ("Groceries", "🛒", "#34C759", 0.20),
        ("Transport", "🚗", "#FF9500", 0.10),
        ("Other", "📦", "#FF2D55", 0.20),
    ]

    var body: some View {
        TabView(selection: $currentPage) {
            welcomePage.tag(0)
            currencyPage.tag(1)
            budgetSetupPage.tag(2)
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .animation(.easeInOut, value: currentPage)
        .onAppear { tempCurrency = selectedCurrency }
    }

    // MARK: - Page 1: Welcome + Privacy

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
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
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
                withAnimation { currentPage = 2 }
            } label: {
                Text("Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Page 3: Quick Budget Setup

    private var budgetSetupPage: some View {
        VStack(spacing: 24) {
            Text("Set Your Monthly Income")
                .font(.title2.bold())
                .padding(.top, 32)

            Text("We'll split 80% across 4 default categories. You can customize everything later.")
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
                let allocated = defaultCategories.reduce(Int64(0)) { $0 + Int64(Double(cents) * $1.pct) }
                VStack(spacing: 8) {
                    ForEach(defaultCategories, id: \.name) { cat in
                        let catCents = Int64(Double(cents) * cat.pct)
                        HStack {
                            Text("\(cat.emoji) \(cat.name) (\(Int(cat.pct * 100))%)")
                            Spacer()
                            Text(CurrencyFormatter.format(cents: catCents))
                                .foregroundStyle(.secondary)
                        }
                        .font(.subheadline)
                    }

                    HStack {
                        Text("Unallocated (20%)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(CurrencyFormatter.format(cents: cents - allocated))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, 40)
            }

            Spacer()

            Button {
                completeOnboarding()
            } label: {
                Text("Create My Budget")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isValidIncome ? Color.accentColor : Color.gray, in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(.white)
            }
            .disabled(!isValidIncome)
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
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

        for (index, cat) in defaultCategories.enumerated() {
            let catCents = Int64(Double(incomeCents) * cat.pct)
            let category = Category(name: cat.name, emoji: cat.emoji, budgetedAmountCents: catCents, color: cat.color, sortOrder: index)
            category.budget = budget
        }

        try? modelContext.save()
        hasCompletedOnboarding = true
    }
}
