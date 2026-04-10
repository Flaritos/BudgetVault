import SwiftUI
import SwiftData
import Charts

struct InsightsView: View {
    @AppStorage(AppStorageKeys.resetDay) private var resetDay = 1
    @AppStorage(AppStorageKeys.isPremium) private var isPremium = false

    @Query(sort: [SortDescriptor(\Budget.year, order: .reverse), SortDescriptor(\Budget.month, order: .reverse)]) private var allBudgets: [Budget]
    // TODO: iOS 18 - Add @Query predicate for budget filtering to avoid loading all records
    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]

    @State private var showPaywall = false
    @State private var selectedRange: DateRange = .thisMonth
    @State private var showShareSheet = false
    @State private var shareUIImage: UIImage?

    // Cached ML results (0.1 — computed in .task, not view body)
    @State private var cachedPrediction: SpendingPrediction?
    @State private var cachedPattern: SpendingPattern?
    @State private var cachedForecasts: [CategoryForecast] = []
    @State private var cachedAnomalies: [AnomalyResult] = []
    @State private var cachedInsights: [Insight] = []

    enum DateRange: String, CaseIterable {
        case thisMonth = "This Month"
        case lastMonth = "Last Month"
        case threeMonths = "3 Months"
        case yearToDate = "Year to Date"
    }

    private var currentBudget: Budget? {
        let (m, y) = DateHelpers.currentBudgetPeriod(resetDay: resetDay)
        return allBudgets.first { $0.month == m && $0.year == y }
    }

    private var previousBudget: Budget? {
        let (m, y) = DateHelpers.currentBudgetPeriod(resetDay: resetDay)
        let (pm, py) = DateHelpers.previousMonth(from: m, year: y)
        return allBudgets.first { $0.month == pm && $0.year == py }
    }

    private var dateRangeStart: Date {
        let calendar = Calendar.current
        let now = Date()
        switch selectedRange {
        case .thisMonth:
            return currentBudget?.periodStart ?? calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        case .lastMonth:
            return previousBudget?.periodStart ?? calendar.date(byAdding: .month, value: -1, to: now) ?? now
        case .threeMonths:
            return calendar.date(byAdding: .month, value: -3, to: now) ?? now
        case .yearToDate:
            return calendar.date(from: DateComponents(year: calendar.component(.year, from: now), month: 1, day: 1)) ?? now
        }
    }

    private var dateRangeEnd: Date {
        switch selectedRange {
        case .thisMonth:
            return currentBudget?.nextPeriodStart ?? Date()
        case .lastMonth:
            return currentBudget?.periodStart ?? Date()
        case .threeMonths, .yearToDate:
            return Date()
        }
    }

    private var periodTransactions: [Transaction] {
        return Array(allTransactions.lazy.filter { $0.date >= dateRangeStart && $0.date < dateRangeEnd })
    }

    private var monthlyTotals: [(month: String, spent: Int64)] {
        allBudgets
            .sorted { ($0.year, $0.month) < ($1.year, $1.month) }
            .suffix(12)
            .map { budget in
                let label = DateHelpers.monthYearString(month: budget.month, year: budget.year)
                let spent = budget.totalSpentCents()
                return (month: label, spent: spent)
            }
    }

    // insights is now cached in @State cachedInsights, computed in .task

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: BudgetVaultTheme.spacingLG) {
                    // Title header
                    VStack(spacing: BudgetVaultTheme.spacingXS) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Insights")
                                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                                    .foregroundStyle(.white)
                                Text("Powered by on-device AI")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                            Spacer()
                            if currentBudget != nil {
                                Button {
                                    renderAndShare()
                                } label: {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.body.weight(.medium))
                                        .foregroundStyle(.white.opacity(0.7))
                                        .frame(width: 44, height: 44)
                                        .contentShape(Rectangle())
                                }
                                .accessibilityLabel("Share insights")
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Date range picker — dark segmented
                    Picker("Range", selection: $selectedRange) {
                        ForEach(DateRange.allCases, id: \.self) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)
                    .colorMultiply(BudgetVaultTheme.brightBlue)
                    .padding(.horizontal)

                    if let budget = currentBudget {
                        // FREE: Trend chart (only shown for single-month ranges)
                        if selectedRange == .thisMonth || selectedRange == .lastMonth {
                            let trendBudget = selectedRange == .lastMonth ? (previousBudget ?? budget) : budget
                            insightsDarkCard {
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(BudgetVaultTheme.brightBlue)
                                        .frame(width: 8, height: 8)
                                        .shadow(color: BudgetVaultTheme.brightBlue.opacity(0.6), radius: 4)
                                    Text("SPENDING TREND")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(.white.opacity(0.5))
                                        .tracking(1)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)

                                TrendChartView(budget: trendBudget, transactions: periodTransactions)
                                    .environment(\.colorScheme, .dark)
                            }
                        }

                        // FREE: Category breakdown
                        insightsDarkCard {
                            CategoryBreakdownChart(budget: budget)
                                .environment(\.colorScheme, .dark)
                        }

                        // FREE: Monthly Totals bar chart
                        if monthlyTotals.count > 1 {
                            insightsDarkCard {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Monthly Spending")
                                        .font(.headline)
                                        .foregroundStyle(.white)

                                    Chart(Array(monthlyTotals.enumerated()), id: \.offset) { _, item in
                                        BarMark(
                                            x: .value("Month", item.month),
                                            y: .value("Spent", Double(truncating: MoneyHelpers.centsToDollars(item.spent) as NSDecimalNumber))
                                        )
                                        .foregroundStyle(BudgetVaultTheme.brightBlue.gradient)
                                        .cornerRadius(4)
                                    }
                                    .frame(height: 200)
                                    .chartXAxis {
                                        AxisMarks(values: .automatic) { value in
                                            AxisValueLabel {
                                                if let str = value.as(String.self) {
                                                    Text(str)
                                                        .font(.caption2)
                                                        .foregroundStyle(.white.opacity(0.5))
                                                        .rotationEffect(.degrees(-45))
                                                }
                                            }
                                        }
                                    }
                                    .chartYAxis {
                                        AxisMarks { value in
                                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                                .foregroundStyle(.white.opacity(0.08))
                                            AxisValueLabel {
                                                if let val = value.as(Double.self) {
                                                    Text(CurrencyFormatter.format(amount: Decimal(val)))
                                                        .font(.caption2)
                                                        .foregroundStyle(.white.opacity(0.5))
                                                }
                                            }
                                        }
                                    }
                                }
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel("Monthly spending bar chart showing \(monthlyTotals.count) months of spending data")
                            }
                        }

                        // PREMIUM: Smart Forecasts (consolidated teaser 1)
                        premiumSection("AI PREDICTION", dotColor: BudgetVaultTheme.brightBlue) {
                            VStack(spacing: 12) {
                                if let prediction = cachedPrediction {
                                    SpendingPredictionCard(prediction: prediction)
                                        .environment(\.colorScheme, .dark)
                                }
                                if let pattern = cachedPattern {
                                    SpendingPatternCard(pattern: pattern)
                                        .environment(\.colorScheme, .dark)
                                }
                                if !cachedForecasts.isEmpty {
                                    CategoryForecastCard(forecasts: cachedForecasts)
                                        .environment(\.colorScheme, .dark)
                                }
                            }
                        }

                        // PREMIUM: Deep Analysis (consolidated teaser 2)
                        premiumSection("SPENDING PATTERN", dotColor: BudgetVaultTheme.neonPurple) {
                            VStack(spacing: 12) {
                                AnomalyListCard(anomalies: cachedAnomalies)
                                    .environment(\.colorScheme, .dark)

                                SpendingHeatmapView(budget: budget, allTransactions: periodTransactions)
                                    .environment(\.colorScheme, .dark)

                                comparisonCards(budget: budget)

                                insightCards

                                topSpendingDays(budget: budget)
                            }
                        }
                    } else {
                        EmptyStateView(
                            icon: "lightbulb.fill",
                            title: "No Data",
                            message: "Start logging expenses to see insights."
                        )
                        .environment(\.colorScheme, .dark)
                    }
                }
                .padding(.vertical)
            }
            .background(BudgetVaultTheme.navyDark.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(BudgetVaultTheme.navyDark, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .sheet(isPresented: $showShareSheet) {
                if let img = shareUIImage {
                    ActivityView(items: [img])
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .task {
                await computeMLResults()
            }
            .task(id: selectedRange) {
                await computeMLResults()
            }
        }
    }

    // MARK: - Dark Card Wrapper

    @ViewBuilder
    private func insightsDarkCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: BudgetVaultTheme.spacingSM) {
            content()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusLG)
                .fill(.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusLG)
                        .stroke(.white.opacity(0.06), lineWidth: 1)
                )
        )
        .padding(.horizontal)
    }

    // MARK: - Section Label with Glow Dot

    @ViewBuilder
    private func sectionLabel(_ text: String, dotColor: Color) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(dotColor)
                .frame(width: 8, height: 8)
                .shadow(color: dotColor.opacity(0.6), radius: 4)
            Text(text)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white.opacity(0.5))
                .tracking(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Premium Section Wrapper

    @ViewBuilder
    private func premiumSection<Content: View>(_ title: String, dotColor: Color, @ViewBuilder content: () -> Content) -> some View {
        if isPremium {
            insightsDarkCard {
                sectionLabel(title, dotColor: dotColor)
                content()
            }
        } else {
            ZStack {
                // Show placeholder skeleton on dark background
                premiumPlaceholderSkeleton(title: title, dotColor: dotColor)

                VStack(spacing: 8) {
                    Image(systemName: "lock.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                    Text("Unlock Premium Insights")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                    Button("Upgrade") {
                        showPaywall = true
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .controlSize(.small)
                }
            }
            .padding(.horizontal)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Premium feature. Tap to learn about upgrading.")
            .accessibilityAddTraits(.isButton)
            .onTapGesture { showPaywall = true }
        }
    }

    // MARK: - Premium Placeholder Skeleton

    @ViewBuilder
    private func premiumPlaceholderSkeleton(title: String, dotColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel(title, dotColor: dotColor)

            ForEach(0..<3, id: \.self) { _ in
                HStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.white.opacity(0.06))
                        .frame(width: 24, height: 24)
                    VStack(alignment: .leading, spacing: 4) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(.white.opacity(0.06))
                            .frame(width: 120, height: 12)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(.white.opacity(0.04))
                            .frame(width: 80, height: 10)
                    }
                    Spacer()
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.white.opacity(0.06))
                        .frame(width: 50, height: 12)
                }
                .padding(8)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusLG)
                .fill(.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusLG)
                        .stroke(.white.opacity(0.06), lineWidth: 1)
                )
        )
    }

    // MARK: - Comparison Cards

    @ViewBuilder
    private func comparisonCards(budget: Budget) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("vs. Last Month")
                .font(.headline)
                .foregroundStyle(.white)

            if let prev = previousBudget {
                let categories = (budget.categories ?? []).filter { !$0.isHidden }
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(categories, id: \.id) { cat in
                        let current = cat.spentCents(in: budget)
                        let prevCat = (prev.categories ?? []).first { $0.name == cat.name }
                        let previous = prevCat?.spentCents(in: prev) ?? 0
                        let delta = current - previous

                        VStack(spacing: 4) {
                            Text(cat.emoji)
                                .font(.title3)
                            Text(cat.name)
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            Text(CurrencyFormatter.format(cents: current))
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.7))
                            HStack(spacing: 2) {
                                Image(systemName: delta > 0 ? "arrow.up" : delta < 0 ? "arrow.down" : "minus")
                                    .font(.caption2)
                                Text(CurrencyFormatter.format(cents: abs(delta)))
                                    .font(.caption2)
                            }
                            .foregroundStyle(delta > 0 ? BudgetVaultTheme.negative : delta < 0 ? BudgetVaultTheme.positive : .white.opacity(0.4))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusSM)
                                .fill(.white.opacity(0.04))
                                .overlay(
                                    RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusSM)
                                        .stroke(.white.opacity(0.06), lineWidth: 1)
                                )
                        )
                        .accessibilityLabel("\(cat.name): \(CurrencyFormatter.format(cents: current)) this month, \(delta > 0 ? "up" : "down") \(CurrencyFormatter.format(cents: abs(delta))) from last month")
                    }
                }
            } else {
                Text("No previous month data available.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
    }

    // MARK: - Insight Cards

    @ViewBuilder
    private var insightCards: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Insights")
                .font(.headline)
                .foregroundStyle(.white)

            if cachedInsights.isEmpty {
                Text("Keep logging -- insights appear as patterns emerge.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.4))
            } else {
                ForEach(cachedInsights) { insight in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: insight.severity.iconName)
                            .foregroundStyle(severityColor(insight.severity))
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(insight.title)
                                .font(.subheadline.bold())
                                .foregroundStyle(.white)
                            Text(insight.message)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusSM)
                            .fill(.white.opacity(0.04))
                            .overlay(
                                RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusSM)
                                    .stroke(.white.opacity(0.06), lineWidth: 1)
                            )
                    )
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(insight.severity.rawValue): \(insight.title). \(insight.message)")
                }
            }
        }
    }

    // MARK: - Top Spending Days

    @ViewBuilder
    private func topSpendingDays(budget: Budget) -> some View {
        let expenses = periodTransactions.filter { !$0.isIncome }
        let grouped = Dictionary(grouping: expenses) { tx in
            Calendar.current.startOfDay(for: tx.date)
        }
        let topDays = grouped
            .map { (date: $0.key, total: $0.value.reduce(Int64(0)) { $0 + $1.amountCents }) }
            .sorted { $0.total > $1.total }
            .prefix(3)

        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Circle()
                    .fill(BudgetVaultTheme.caution)
                    .frame(width: 8, height: 8)
                    .shadow(color: BudgetVaultTheme.caution.opacity(0.6), radius: 4)
                Text("ANOMALIES")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white.opacity(0.5))
                    .tracking(1)
            }

            Text("Top Spending Days")
                .font(.headline)
                .foregroundStyle(.white)

            if topDays.isEmpty {
                Text("No spending data yet.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.4))
            } else {
                ForEach(Array(topDays.enumerated()), id: \.offset) { index, day in
                    HStack {
                        Text("\(index + 1).")
                            .font(.headline)
                            .foregroundStyle(.white.opacity(0.4))
                            .frame(width: 24)
                        Text(day.date, style: .date)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.8))
                        Spacer()
                        Text(CurrencyFormatter.format(cents: day.total))
                            .font(.subheadline.bold())
                            .foregroundStyle(.white)
                    }
                    .accessibilityLabel("Number \(index + 1): \(day.date.formatted(date: .abbreviated, time: .omitted)), \(CurrencyFormatter.format(cents: day.total))")
                }
            }
        }
    }

    // MARK: - ML Computation (off main actor path, run once in .task)

    private func computeMLResults() async {
        // Pick the budget matching the selected range
        let targetBudget: Budget? = {
            switch selectedRange {
            case .thisMonth: return currentBudget
            case .lastMonth: return previousBudget
            case .threeMonths, .yearToDate: return currentBudget
            }
        }()
        guard let budget = targetBudget else { return }

        NotificationService.checkAndScheduleCategoryAlerts(budget: budget)

        // ML predictions are only meaningful for a single complete/current period
        let mlApplicable = (selectedRange == .thisMonth)

        // Gather expenses once and pass to all ML functions (0.1)
        let expenses = BudgetMLEngine.gatherExpenses(budget: budget)

        cachedPrediction = mlApplicable ? BudgetMLEngine.predictMonthEndSpending(budget: budget, expenses: expenses) : nil
        cachedPattern = mlApplicable ? BudgetMLEngine.classifySpendingPattern(budget: budget, expenses: expenses) : nil
        cachedForecasts = mlApplicable ? BudgetMLEngine.forecastCategories(budget: budget) : []
        cachedAnomalies = mlApplicable ? BudgetMLEngine.detectAnomalies(budget: budget) : []
        cachedInsights = InsightsEngine.generateInsights(
            budget: budget, previousBudget: previousBudget, allBudgets: allBudgets
        )
    }

    // MARK: - Helpers

    private func severityColor(_ severity: Insight.Severity) -> Color {
        switch severity {
        case .warning: BudgetVaultTheme.negative
        case .info: BudgetVaultTheme.info
        case .success: BudgetVaultTheme.positive
        case .nudge: BudgetVaultTheme.caution
        }
    }

    @MainActor
    private func renderAndShare() {
        guard let budget = currentBudget else { return }
        let topCats = (budget.categories ?? [])
            .filter { !$0.isHidden }
            .sorted { $0.spentCents(in: budget) > $1.spentCents(in: budget) }
            .prefix(5)

        let card = VStack(spacing: 12) {
            Text("Insights - \(DateHelpers.monthYearString(month: budget.month, year: budget.year))")
                .font(.headline)

            HStack(spacing: 24) {
                VStack {
                    Text("Income")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(CurrencyFormatter.format(cents: budget.totalIncomeCents))
                        .font(.subheadline.bold())
                }
                VStack {
                    Text("Spent")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(CurrencyFormatter.format(cents: budget.totalSpentCents()))
                        .font(.subheadline.bold())
                }
            }

            Divider()

            ForEach(Array(topCats), id: \.id) { cat in
                HStack {
                    Text(cat.emoji)
                    Text(cat.name)
                        .font(.caption)
                    Spacer()
                    Text(CurrencyFormatter.format(cents: cat.spentCents(in: budget)))
                        .font(.caption.bold())
                }
            }

            Text("Tracked with BudgetVault")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
        .padding(20)
        .frame(width: 320)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .environment(\.colorScheme, .light)

        let renderer = ImageRenderer(content: card)
        renderer.scale = 3
        if let image = renderer.uiImage {
            shareUIImage = image
            showShareSheet = true
        }
    }
}

private struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
