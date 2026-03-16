import SwiftUI

struct MonthlyWrappedView: View {
    let budget: Budget
    let allTransactions: [Transaction]

    @Environment(\.dismiss) private var dismiss

    private var calendar: Calendar { Calendar.current }

    // MARK: - Computed Data

    private var periodTransactions: [Transaction] {
        allTransactions.filter { tx in
            !tx.isIncome && tx.date >= budget.periodStart && tx.date < budget.nextPeriodStart
        }
    }

    private var totalSpentCents: Int64 {
        periodTransactions.reduce(0) { $0 + $1.amountCents }
    }

    private var categories: [Category] {
        (budget.categories ?? []).filter { !$0.isHidden }.sorted { $0.sortOrder < $1.sortOrder }
    }

    private var topCategory: Category? {
        categories.max(by: { $0.spentCents(in: budget) < $1.spentCents(in: budget) })
    }

    private var topCategorySpent: Int64 {
        topCategory?.spentCents(in: budget) ?? 0
    }

    private var topCategoryPercent: Double {
        guard totalSpentCents > 0 else { return 0 }
        return Double(topCategorySpent) / Double(totalSpentCents) * 100
    }

    private var daysInMonth: Int {
        let comps = DateComponents(year: budget.year, month: budget.month)
        guard let date = calendar.date(from: comps),
              let range = calendar.range(of: .day, in: .month, for: date) else { return 30 }
        return range.count
    }

    /// Daily spending totals keyed by day-of-month
    private var dailySpending: [Int: Int64] {
        var result: [Int: Int64] = [:]
        for tx in periodTransactions {
            let day = calendar.component(.day, from: tx.date)
            result[day, default: 0] += tx.amountCents
        }
        return result
    }

    private var biggestSpendingDay: (day: Int, amount: Int64)? {
        dailySpending.max(by: { $0.value < $1.value }).map { ($0.key, $0.value) }
    }

    private var lightestSpendingDay: (day: Int, amount: Int64)? {
        // Only consider days with at least one transaction
        let daysWithSpending = dailySpending.filter { $0.value > 0 }
        return daysWithSpending.min(by: { $0.value < $1.value }).map { ($0.key, $0.value) }
    }

    private var averageDailySpendCents: Int64 {
        guard daysInMonth > 0 else { return 0 }
        return totalSpentCents / Int64(daysInMonth)
    }

    private var dailyAllowanceCents: Int64 {
        guard daysInMonth > 0 else { return 0 }
        return budget.totalIncomeCents / Int64(daysInMonth)
    }

    private var daysUnderAllowance: Int {
        var count = 0
        for day in 1...daysInMonth {
            let spent = dailySpending[day] ?? 0
            if spent <= dailyAllowanceCents {
                count += 1
            }
        }
        return count
    }

    private var daysOverAllowance: Int {
        daysInMonth - daysUnderAllowance
    }

    private var currentStreak: Int {
        UserDefaults.standard.integer(forKey: AppStorageKeys.currentStreak)
    }

    private var isUnderBudget: Bool {
        budget.remainingCents >= 0
    }

    private var verdict: String {
        isUnderBudget ? "Budget Hero" : "Room to Grow"
    }

    private var verdictEmoji: String {
        isUnderBudget ? "medal" : "chart.line.uptrend.xyaxis"
    }

    private var deltaCents: Int64 {
        budget.totalIncomeCents - totalSpentCents
    }

    private var top3Categories: [Category] {
        Array(
            categories
                .sorted { $0.spentCents(in: budget) > $1.spentCents(in: budget) }
                .filter { $0.spentCents(in: budget) > 0 }
                .prefix(3)
        )
    }

    private var monthYearString: String {
        DateHelpers.monthYearString(month: budget.month, year: budget.year)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    slideHero
                    slideTopCategory
                    slideDailyPattern
                    slideStreakDiscipline
                    slideSummaryCard
                }
            }
            .background(BudgetVaultTheme.navyDark)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }

    // MARK: - Slide 1: Hero

    private var slideHero: some View {
        VStack(spacing: BudgetVaultTheme.spacingXL) {
            VaultDialMark(size: 60, color: .white, showGlow: true)

            Text("Your \(monthYearString) Recap")
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)

            Text(CurrencyFormatter.format(cents: totalSpentCents))
                .font(BudgetVaultTheme.heroAmount)
                .foregroundStyle(.white)
                .contentTransition(.numericText())

            Text("total spent")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .background(
            LinearGradient(
                colors: BudgetVaultTheme.premiumGradient,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    // MARK: - Slide 2: Top Category

    private var slideTopCategory: some View {
        VStack(spacing: BudgetVaultTheme.spacingLG) {
            if let cat = topCategory {
                Text(cat.emoji)
                    .font(.system(size: 56))

                Text("You spent \(CurrencyFormatter.format(cents: topCategorySpent)) on \(cat.name)")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text(String(format: "%.0f%% of your total spending", topCategoryPercent))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
            } else {
                Text("No spending recorded")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .padding(.horizontal, BudgetVaultTheme.spacingXL)
        .background(BudgetVaultTheme.navyMid)
    }

    // MARK: - Slide 3: Daily Pattern

    private var slideDailyPattern: some View {
        VStack(spacing: BudgetVaultTheme.spacingXL) {
            if let biggest = biggestSpendingDay {
                HStack(spacing: BudgetVaultTheme.spacingMD) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(BudgetVaultTheme.negative)
                    VStack(alignment: .leading) {
                        Text("Biggest spending day")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                        Text("\(dayString(biggest.day)) - \(CurrencyFormatter.format(cents: biggest.amount))")
                            .font(.headline)
                            .foregroundStyle(.white)
                    }
                    Spacer()
                }
            }

            if let lightest = lightestSpendingDay {
                HStack(spacing: BudgetVaultTheme.spacingMD) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.title2)
                        .foregroundStyle(BudgetVaultTheme.positive)
                    VStack(alignment: .leading) {
                        Text("Lightest spending day")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                        Text("\(dayString(lightest.day)) - \(CurrencyFormatter.format(cents: lightest.amount))")
                            .font(.headline)
                            .foregroundStyle(.white)
                    }
                    Spacer()
                }
            }

            HStack(spacing: BudgetVaultTheme.spacingMD) {
                Image(systemName: "chart.bar.fill")
                    .font(.title2)
                    .foregroundStyle(BudgetVaultTheme.info)
                VStack(alignment: .leading) {
                    Text("Average daily spend")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                    Text(CurrencyFormatter.format(cents: averageDailySpendCents))
                        .font(.headline)
                        .foregroundStyle(.white)
                }
                Spacer()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .padding(.horizontal, BudgetVaultTheme.spacingXL)
        .background(
            LinearGradient(
                colors: [BudgetVaultTheme.navyDark, BudgetVaultTheme.electricBlue.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    // MARK: - Slide 4: Streak & Discipline

    private var slideStreakDiscipline: some View {
        VStack(spacing: BudgetVaultTheme.spacingXL) {
            // Streak
            HStack(spacing: BudgetVaultTheme.spacingMD) {
                Text("\(currentStreak)")
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                VStack(alignment: .leading) {
                    Text("day streak")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("Keep it going!")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
            }

            // Under/over breakdown
            HStack(spacing: BudgetVaultTheme.spacing2XL) {
                VStack {
                    Text("\(daysUnderAllowance)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(BudgetVaultTheme.positive)
                    Text("days under")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
                VStack {
                    Text("\(daysOverAllowance)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(BudgetVaultTheme.negative)
                    Text("days over")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }

            // Verdict
            HStack(spacing: BudgetVaultTheme.spacingSM) {
                Image(systemName: verdictEmoji)
                    .font(.title3)
                Text(verdict)
                    .font(.title3.weight(.bold))
            }
            .foregroundStyle(isUnderBudget ? BudgetVaultTheme.positive : BudgetVaultTheme.caution)
            .padding(.horizontal, BudgetVaultTheme.spacingXL)
            .padding(.vertical, BudgetVaultTheme.spacingMD)
            .background(
                Capsule().fill((isUnderBudget ? BudgetVaultTheme.positive : BudgetVaultTheme.caution).opacity(0.15))
            )
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .background(BudgetVaultTheme.navyMid)
    }

    // MARK: - Slide 5: Summary Card (Shareable)

    private var slideSummaryCard: some View {
        VStack(spacing: BudgetVaultTheme.spacingXL) {
            Text("Share your recap")
                .font(.headline)
                .foregroundStyle(.white)

            shareCardContent
                .padding(BudgetVaultTheme.spacingXL)
                .background(.white, in: RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusXL))
                .shadow(color: .black.opacity(0.15), radius: 20, y: 10)
                .padding(.horizontal, BudgetVaultTheme.spacingLG)

            ShareLink(item: shareCardImage, preview: SharePreview("My \(monthYearString) Recap", image: shareCardImage)) {
                Label("Share Card", systemImage: "square.and.arrow.up")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, BudgetVaultTheme.spacingMD)
                    .background(BudgetVaultTheme.electricBlue, in: RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusMD))
            }
            .padding(.horizontal, BudgetVaultTheme.spacingXL)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .background(
            LinearGradient(
                colors: [BudgetVaultTheme.navyDark, BudgetVaultTheme.navyMid],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    // MARK: - Share Card Content

    private var shareCardContent: some View {
        VStack(spacing: BudgetVaultTheme.spacingMD) {
            VaultDialMark(size: 36, color: BudgetVaultTheme.electricBlue)

            Text(monthYearString)
                .font(.headline)
                .foregroundStyle(.primary)

            HStack(spacing: BudgetVaultTheme.spacingXL) {
                VStack(spacing: 2) {
                    Text("Income")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(CurrencyFormatter.format(cents: budget.totalIncomeCents))
                        .font(.subheadline.weight(.bold))
                }
                VStack(spacing: 2) {
                    Text("Spent")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(CurrencyFormatter.format(cents: totalSpentCents))
                        .font(.subheadline.weight(.bold))
                }
                VStack(spacing: 2) {
                    Text(deltaCents >= 0 ? "Saved" : "Over")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(CurrencyFormatter.format(cents: abs(deltaCents)))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(deltaCents >= 0 ? BudgetVaultTheme.positive : BudgetVaultTheme.negative)
                }
            }

            if !top3Categories.isEmpty {
                Divider()
                ForEach(top3Categories, id: \.id) { cat in
                    HStack {
                        Text(cat.emoji)
                        Text(cat.name)
                            .font(.caption)
                        Spacer()
                        Text(CurrencyFormatter.format(cents: cat.spentCents(in: budget)))
                            .font(.caption.weight(.bold))
                    }
                }
            }

            Divider()

            Text("Tracked with BudgetVault")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Image Renderer

    @MainActor
    private var shareCardImage: Image {
        let cardView = shareCardContent
            .padding(BudgetVaultTheme.spacingXL)
            .frame(width: 320)
            .background(.white, in: RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusXL))
            .environment(\.colorScheme, .light)

        let renderer = ImageRenderer(content: cardView)
        renderer.scale = 3
        if let uiImage = renderer.uiImage {
            return Image(uiImage: uiImage)
        }
        return Image(systemName: "square")
    }

    // MARK: - Helpers

    private func dayString(_ day: Int) -> String {
        let comps = DateComponents(year: budget.year, month: budget.month, day: day)
        guard let date = calendar.date(from: comps) else { return "Day \(day)" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

#Preview {
    MonthlyWrappedView(
        budget: Budget(month: 3, year: 2026, totalIncomeCents: 500000, resetDay: 1),
        allTransactions: []
    )
}
