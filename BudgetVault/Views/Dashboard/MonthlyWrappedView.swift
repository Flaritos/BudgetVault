import SwiftUI
import Photos
import BudgetVaultShared

struct MonthlyWrappedView: View {
    let budget: Budget
    let allTransactions: [Transaction]

    @Environment(\.dismiss) private var dismiss
    @State private var currentPage = 0
    @State private var showSaveSuccess = false
    @State private var showPhotoPermissionDenied = false
    @State private var ringAppeared = false
    @State private var shareImage: Image?
    @State private var sharePNGData: Data?
    @State private var shareImageGenerationStarted = false

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

    /// Audit fix: was `calendar.range(of: .day, in: .month)` which
    /// returns calendar-month length. But a budget period can span two
    /// calendar months when `resetDay` is ≠ 1 — so the right length is
    /// `periodStart → nextPeriodStart`, not the calendar month of the
    /// budget's year/month. Using the budget's actual period length
    /// fixes the "two different days-16 collide into one bucket" bug
    /// and produces correct length at month boundaries (28–31) without
    /// depending on month/year.
    private var daysInMonth: Int {
        let comps = calendar.dateComponents([.day], from: budget.periodStart, to: budget.nextPeriodStart)
        return comps.day ?? 30
    }

    /// Days elapsed within the period (clamped so future days don't
    /// count toward "under allowance" until the month actually ends).
    private var daysElapsed: Int {
        let now = Date()
        let end = min(now, budget.nextPeriodStart)
        let elapsed = calendar.dateComponents([.day], from: budget.periodStart, to: end).day ?? 0
        return max(0, min(elapsed, daysInMonth))
    }

    /// Daily spending totals keyed by day-offset-from-period-start
    /// (1-based). Keys survive across calendar-month boundaries and
    /// stay stable for custom `resetDay` users.
    private var dailySpending: [Int: Int64] {
        var result: [Int: Int64] = [:]
        for tx in periodTransactions {
            let offset = calendar.dateComponents([.day], from: budget.periodStart, to: tx.date).day ?? 0
            let dayIndex = offset + 1
            guard dayIndex >= 1, dayIndex <= daysInMonth else { continue }
            result[dayIndex, default: 0] += tx.amountCents
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

    /// Audit fix: previously counted every day 1...daysInMonth even if
    /// the month wasn't over yet, inflating "under allowance" days. Cap
    /// the scan at daysElapsed so future days don't pre-emptively count
    /// as under-allowance. Once the period ends, daysElapsed == daysInMonth.
    private var daysUnderAllowance: Int {
        guard daysElapsed > 0 else { return 0 }
        var count = 0
        for day in 1...daysElapsed {
            let spent = dailySpending[day] ?? 0
            if spent <= dailyAllowanceCents {
                count += 1
            }
        }
        return count
    }

    private var daysOverAllowance: Int {
        daysElapsed - daysUnderAllowance
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

    // MARK: - Additional Computed Data for Wrapped

    private var savedCents: Int64 {
        max(budget.totalIncomeCents - totalSpentCents, 0)
    }

    private var savedPercent: Double {
        guard budget.totalIncomeCents > 0 else { return 0 }
        return Double(savedCents) / Double(budget.totalIncomeCents) * 100
    }

    private var spentPercent: Double {
        guard budget.totalIncomeCents > 0 else { return 0 }
        return min(Double(totalSpentCents) / Double(budget.totalIncomeCents) * 100, 100)
    }

    private var sortedCategories: [Category] {
        categories
            .filter { $0.spentCents(in: budget) > 0 }
            .sorted { $0.spentCents(in: budget) > $1.spentCents(in: budget) }
    }

    private var zeroSpendDays: Int {
        var count = 0
        for day in 1...daysInMonth {
            if dailySpending[day] == nil || dailySpending[day] == 0 {
                count += 1
            }
        }
        return count
    }

    private var mostLoggedItem: (note: String, count: Int)? {
        let notes = periodTransactions.map(\.note).filter { !$0.isEmpty }
        guard !notes.isEmpty else { return nil }
        var counts: [String: Int] = [:]
        for n in notes { counts[n, default: 0] += 1 }
        guard let top = counts.max(by: { $0.value < $1.value }) else { return nil }
        return (top.key, top.value)
    }

    // Audit 2026-04-23 Perf P1: hoisted DateFormatter.
    private static let monthNameFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM"
        return f
    }()

    private var monthName: String {
        let comps = DateComponents(year: budget.year, month: budget.month, day: 1)
        guard let date = calendar.date(from: comps) else { return "" }
        return Self.monthNameFormatter.string(from: date).uppercased()
    }

    private var personalityType: (name: String, emoji: String, description: String, traits: [(String, String)]) {
        // Audit 2026-04-23 UX P0-5: zero-income user with $12 spent
        // was labeled "Free Spirit / You lived fully." Tone-deaf. Guard.
        if budget.totalIncomeCents == 0 {
            return (
                "Ready to Begin",
                "\u{1F511}",
                "Set a monthly budget to see your spending personality next month.",
                [("Setup", "\u{1F6E0}\u{FE0F}"), ("Curious", "\u{1F50D}"), ("Starting", "\u{1F331}")]
            )
        }
        if savedPercent > 70 {
            return (
                "Vault Guardian",
                "\u{1F6E1}\u{FE0F}",
                "You treat your budget like a fortress. Every dollar has a mission, and most of them stayed right where they belong. Your discipline is rare.",
                [("Disciplined", "\u{1F3AF}"), ("Strategic", "\u{1F9E0}"), ("Resilient", "\u{1F4AA}")]
            )
        } else if savedPercent > 50 {
            return (
                "Smart Saver",
                "\u{1F48E}",
                "You know when to spend and when to hold back. More than half your income stayed safe this month. That balance is your superpower.",
                [("Balanced", "\u{2696}\u{FE0F}"), ("Intentional", "\u{1F4A1}"), ("Growing", "\u{1F331}")]
            )
        } else if savedPercent > 30 {
            return (
                "Balanced Spender",
                "\u{2696}\u{FE0F}",
                "Life costs money, and you're making it work. You saved a solid chunk while still living your life. Keep building that momentum.",
                [("Practical", "\u{1F527}"), ("Steady", "\u{26F5}"), ("Aware", "\u{1F440}")]
            )
        } else {
            return (
                "Free Spirit",
                "\u{1F30A}",
                "You lived fully this month. Sometimes the best memories cost a little extra. Next month is a fresh start to find your balance.",
                [("Adventurous", "\u{1F680}"), ("Present", "\u{2728}"), ("Optimistic", "\u{2600}\u{FE0F}")]
            )
        }
    }

    // MARK: - Colors (theme tokens)

    private let wrappedNavy = BudgetVaultTheme.navyDark
    private let wrappedNavyMid = BudgetVaultTheme.navyMid
    private let wrappedPurple = BudgetVaultTheme.neonPurple
    private let wrappedGreen = BudgetVaultTheme.neonGreen
    private let wrappedRed = BudgetVaultTheme.negative

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottom) {
            // Audit 2026-04-22 P2-12: TabView(.page) eagerly builds all
            // 5 slides on first render because iOS needs neighbor slides
            // hot for swipe gestures. Each slide reads derived computed
            // properties (totalSpentCents, topCategory, etc.) that
            // filter/reduce periodTransactions — ×5 every body eval.
            //
            // Acceptable at current scale because P0-7 bounded
            // MonthlyWrappedShell's @Query to a 2-month window, so
            // periodTransactions is small (~30–200 rows). A future
            // precompute-into-@State refactor is tracked but not done
            // in this audit pass — the invasive refactor risk exceeds
            // the measured perf gain on a bounded dataset.
            TabView(selection: $currentPage) {
                slide1StoryIntro.tag(0)
                slide2WhereItWent.tag(1)
                slide3Personality.tag(2)
                slide4ByTheNumbers.tag(3)
                slide5ShareCard.tag(4)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Wrapped slides")
            .accessibilityValue("Slide \(currentPage + 1) of 5")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment:
                    if currentPage < 4 {
                        currentPage += 1
                        UIAccessibility.post(notification: .pageScrolled,
                                             argument: "Slide \(currentPage + 1) of 5")
                    }
                case .decrement:
                    if currentPage > 0 {
                        currentPage -= 1
                        UIAccessibility.post(notification: .pageScrolled,
                                             argument: "Slide \(currentPage + 1) of 5")
                    }
                @unknown default: break
                }
            }

            pageDots
        }
        .overlay(alignment: .topTrailing) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.white.opacity(0.15), in: Circle())
            }
            .accessibilityLabel("Close")
            .accessibilityHint("Closes your wrapped recap")
            .padding(.top, 56)
            .padding(.trailing, 16)
        }
        .preferredColorScheme(.dark)
        // Audit 2026-04-23 A11y P1: cap removed so AX4/AX5 users can
        // read Wrapped. Slides use VStack/Spacer layouts that reflow.
        // If layout breaks under larger sizes, fix the layout —
        // don't deny users their accessibility preference.
        .alert("Image Saved", isPresented: $showSaveSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your wrapped card has been saved to your photo library.")
        }
        .alert("Photo Access Required", isPresented: $showPhotoPermissionDenied) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("BudgetVault needs photo library access to save images. Please enable it in Settings.")
        }
    }

    // MARK: - Page Dots

    private var pageDots: some View {
        HStack(spacing: 6) {
            ForEach(0..<5, id: \.self) { i in
                if i == currentPage {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.white)
                        .frame(width: 24, height: 8)
                } else {
                    Circle()
                        .fill(.white.opacity(0.7))
                        .frame(width: 8, height: 8)
                }
            }
        }
        .frame(minWidth: 44, minHeight: 44)
        .contentShape(Rectangle())
        .animation(.easeInOut(duration: 0.2), value: currentPage)
        .padding(.bottom, 44)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Page indicator")
        .accessibilityValue("Slide \(currentPage + 1) of 5")
    }

    // MARK: - Slide 1: Story Intro

    private var slide1StoryIntro: some View {
        ZStack {
            LinearGradient(
                colors: [wrappedNavy, wrappedNavy.opacity(0.8), wrappedNavyMid],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: BudgetVaultTheme.spacing2XL) {
                Spacer()

                Text("YOUR \(monthName) STORY")
                    .font(.caption.weight(.bold))
                    .tracking(4)
                    .foregroundStyle(.white.opacity(0.7))

                // Donut ring
                // Audit 2026-04-23 M2: when totalIncomeCents == 0, the
                // ring celebrated "$0 / 0%" as the giant visual hero —
                // cognitively dissonant with the "Set a monthly budget"
                // subhead below. Replace the donut with a lock glyph
                // when there's nothing to visualize.
                if budget.totalIncomeCents == 0 {
                    ZStack {
                        Circle()
                            .stroke(.white.opacity(0.06), lineWidth: 18)
                            .frame(width: 220, height: 220)
                        Image(systemName: "lock.fill")
                            .font(.system(size: 72, weight: .light))
                            .foregroundStyle(wrappedGreen.opacity(0.8))
                    }
                } else {
                    ZStack {
                        // Track
                        Circle()
                            .stroke(.white.opacity(0.04), lineWidth: 18)
                            .frame(width: 220, height: 220)

                        // Spent arc (red, at the end)
                        Circle()
                            .trim(from: ringAppeared ? max(1.0 - spentPercent / 100.0, 0) : 1.0, to: 1.0)
                            .stroke(
                                wrappedRed.opacity(0.3),
                                style: StrokeStyle(lineWidth: 18, lineCap: .round)
                            )
                            .frame(width: 220, height: 220)
                            .rotationEffect(.degrees(-90))

                        // Saved arc (green, glowing)
                        Circle()
                            .trim(from: 0, to: ringAppeared ? min(savedPercent / 100.0, 1.0) : 0)
                            .stroke(
                                wrappedGreen,
                                style: StrokeStyle(lineWidth: 18, lineCap: .round)
                            )
                            .frame(width: 220, height: 220)
                            .rotationEffect(.degrees(-90))
                            .shadow(color: wrappedGreen.opacity(0.5), radius: 8)

                        // Center text
                        VStack(spacing: 4) {
                            Text("SAVED")
                                .font(.caption2.weight(.semibold))
                                .tracking(2)
                                .foregroundStyle(.white.opacity(0.7))

                            Text(CurrencyFormatter.format(cents: savedCents))
                                .font(.system(size: 42, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)

                            Text(String(format: "%.0f%%", savedPercent))
                                .font(.system(size: 22, weight: .semibold, design: .rounded))
                                .foregroundStyle(wrappedGreen)
                        }
                    }
                }

                VStack(spacing: BudgetVaultTheme.spacingSM) {
                    // Audit 2026-04-22 P0-6 Fix 6: guard zero-income case.
                    // MobAI caught "Out of $0.00 earned, you spent just $12.50"
                    // which can't happen logically. Also corrected "earned"
                    // → "budgeted" — this field is the budget target per
                    // InsightsEngine:267-270, not a sum of income txns.
                    Group {
                        if budget.totalIncomeCents == 0 {
                            Text("Set a monthly budget to see your savings story.")
                        } else {
                            Text("Out of \(CurrencyFormatter.format(cents: budget.totalIncomeCents)) budgeted, you spent just \(CurrencyFormatter.format(cents: totalSpentCents)).")
                        }
                    }
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)

                    Text("The vault held strong. Let's see where it went \u{2192}")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(.horizontal, BudgetVaultTheme.spacingXL)

                Spacer()
                Spacer()
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.0).delay(0.3)) {
                ringAppeared = true
            }
        }
        .accessibilityElement(children: .combine)
        // Audit 2026-04-23 M2: VO label also said "percent of income"
        // when income=0 — matches the sentence-copy fix in P0-6 Fix 6
        // but VO was untouched. Branch here too.
        .accessibilityLabel(
            budget.totalIncomeCents == 0
                ? "Your \(monthName) story. Set a monthly budget to see your savings story."
                : "Your \(monthName) story. Saved \(CurrencyFormatter.format(cents: savedCents)), \(String(format: "%.0f", savedPercent)) percent of budget."
        )
    }

    // MARK: - Slide 2: Where It Went

    private var slide2WhereItWent: some View {
        ZStack {
            LinearGradient(
                colors: [wrappedNavy, wrappedPurple.opacity(0.15), wrappedNavyMid],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: BudgetVaultTheme.spacingXL) {
                    Spacer(minLength: 80)

                    Text("WHERE IT WENT")
                        .font(.caption.weight(.bold))
                        .tracking(4)
                        .foregroundStyle(.white.opacity(0.7))

                    if let cat = topCategory {
                        VStack(spacing: BudgetVaultTheme.spacingMD) {
                            Text("Your biggest expense was")
                                .font(.body)
                                .foregroundStyle(.white.opacity(0.6))

                            HStack(spacing: BudgetVaultTheme.spacingMD) {
                                Text(cat.emoji)
                                    .font(.system(size: 48))
                                Text(cat.name)
                                    .font(.system(size: 48, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                            }

                            Text(CurrencyFormatter.format(cents: topCategorySpent))
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(wrappedPurple)

                            Text(String(format: "That's %.0f%% of everything you spent.", topCategoryPercent))
                                .font(.callout)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }

                    // Horizontal bar chart
                    VStack(spacing: BudgetVaultTheme.spacingMD) {
                        ForEach(sortedCategories, id: \.id) { cat in
                            categoryBar(for: cat)
                        }
                    }
                    .padding(.horizontal, BudgetVaultTheme.spacingXL)
                    .padding(.top, BudgetVaultTheme.spacingLG)

                    Spacer(minLength: 80)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Where it went. Top category: \(topCategory?.name ?? "none"), \(CurrencyFormatter.format(cents: topCategorySpent))")
    }

    private func categoryBar(for cat: Category) -> some View {
        let spent = cat.spentCents(in: budget)
        let maxSpent = sortedCategories.first?.spentCents(in: budget) ?? 1
        let ratio = maxSpent > 0 ? CGFloat(spent) / CGFloat(maxSpent) : 0

        return HStack(spacing: BudgetVaultTheme.spacingSM) {
            Text(cat.emoji)
                .font(.system(size: 18))
                .frame(width: 28)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.white.opacity(0.06))
                        .frame(height: 28)

                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(hex: cat.color).opacity(0.7))
                        .frame(width: max(geo.size.width * ratio, 60), height: 28)

                    HStack {
                        Text(cat.name)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                        Spacer()
                        Text(CurrencyFormatter.format(cents: spent))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .padding(.horizontal, BudgetVaultTheme.spacingSM)
                }
            }
            .frame(height: 28)
        }
    }

    // MARK: - Slide 3: Spending Personality

    private var slide3Personality: some View {
        let personality = personalityType

        return ZStack {
            LinearGradient(
                colors: [wrappedNavy, wrappedNavyMid.opacity(0.9), wrappedPurple.opacity(0.1)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: BudgetVaultTheme.spacing2XL) {
                Spacer()

                Text("YOUR SPENDING TYPE")
                    .font(.caption.weight(.bold))
                    .tracking(4)
                    .foregroundStyle(.white.opacity(0.7))

                // Giant emoji with glow
                Text(personality.emoji)
                    .font(.system(size: 80))
                    .shadow(color: wrappedPurple.opacity(0.4), radius: 20)

                // Personality name
                Text(personality.name)
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [wrappedGreen, wrappedPurple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                // Description
                Text(personality.description)
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, BudgetVaultTheme.spacing2XL)

                // Trait cards
                HStack(spacing: BudgetVaultTheme.spacingMD) {
                    ForEach(personality.traits, id: \.0) { trait in
                        VStack(spacing: BudgetVaultTheme.spacingXS) {
                            Text(trait.1)
                                .font(.system(size: 24))
                            Text(trait.0)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, BudgetVaultTheme.spacingMD)
                        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusMD))
                    }
                }
                .padding(.horizontal, BudgetVaultTheme.spacingXL)

                Spacer()
                Spacer()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Your spending type: \(personality.name). \(personality.description)")
    }

    // MARK: - Slide 4: By The Numbers

    private var slide4ByTheNumbers: some View {
        ZStack {
            // Audit 2026-04-22 P2-16: was `electricBlue.opacity(0.08)` —
            // the only blue cameo across the 5-slide navy+purple deck.
            // Swapped to `wrappedPurple.opacity(0.08)` so slide 4
            // lineages with its neighbors (slide 2 + 3 both use purple).
            LinearGradient(
                colors: [wrappedNavy, wrappedPurple.opacity(0.08), wrappedNavyMid],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer(minLength: 80)

                    Text("BY THE NUMBERS")
                        .font(.caption.weight(.bold))
                        .tracking(4)
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.bottom, BudgetVaultTheme.spacing2XL)

                    // Transaction count
                    statRow(
                        number: "\(periodTransactions.count)",
                        description: "transactions logged",
                        detail: "an average of \(String(format: "%.1f", Double(periodTransactions.count) / Double(max(daysInMonth, 1)))) per day"
                    )

                    statDivider

                    // Average daily spend
                    statRow(
                        number: CurrencyFormatter.format(cents: averageDailySpendCents),
                        description: "average daily spend",
                        detail: nil
                    )

                    statDivider

                    // Biggest day
                    if let biggest = biggestSpendingDay {
                        statRow(
                            number: dayString(biggest.day),
                            description: "was your biggest day",
                            detail: "\(CurrencyFormatter.format(cents: biggest.amount)) \u{2014} rent day hits different"
                        )
                        statDivider
                    }

                    // Most logged item
                    if let item = mostLoggedItem {
                        statRow(
                            number: "\"\(item.note)\"",
                            description: "most logged item",
                            detail: "appeared \(item.count) time\(item.count == 1 ? "" : "s")"
                        )
                        statDivider
                    }

                    // Zero-spend days
                    statRow(
                        number: "\(zeroSpendDays)",
                        description: "zero-spend days",
                        detail: zeroSpendDays > 5 ? "your wallet thanks you" : "every day counts"
                    )

                    Spacer(minLength: 80)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("By the numbers. \(periodTransactions.count) transactions, \(CurrencyFormatter.format(cents: averageDailySpendCents)) average daily spend, \(zeroSpendDays) zero-spend days.")
    }

    private func statRow(number: String, description: String, detail: String?) -> some View {
        HStack(alignment: .top, spacing: BudgetVaultTheme.spacingLG) {
            Text(number)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(minWidth: 80, alignment: .trailing)
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            VStack(alignment: .leading, spacing: 4) {
                Text(description)
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.8))

                if let detail {
                    Text(detail)
                        .font(.callout)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }

            Spacer()
        }
        .padding(.horizontal, BudgetVaultTheme.spacingXL)
        .padding(.vertical, BudgetVaultTheme.spacingLG)
    }

    private var statDivider: some View {
        Rectangle()
            .fill(.white.opacity(0.06))
            .frame(height: 1)
            .padding(.horizontal, BudgetVaultTheme.spacingXL)
    }

    // MARK: - Slide 5: Share Card

    private var slide5ShareCard: some View {
        ZStack {
            LinearGradient(
                colors: [wrappedNavy, wrappedPurple.opacity(0.1), wrappedNavyMid],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: BudgetVaultTheme.spacingXL) {
                Spacer()

                // In-sheet preview (downscaled 1080×1920 card)
                shareCardContent
                    .padding(BudgetVaultTheme.spacingXL)
                    .background(
                        RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusXL)
                            .fill(
                                LinearGradient(
                                    colors: [wrappedNavyMid, wrappedPurple.opacity(0.3), wrappedNavy],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusXL)
                            .strokeBorder(.white.opacity(0.08), lineWidth: 1)
                    )
                    .shadow(color: wrappedPurple.opacity(0.2), radius: 30, y: 10)
                    .padding(.horizontal, BudgetVaultTheme.spacingXL)

                // Share button — auto-presents once the 1080×1920 PNG is ready.
                if let image = shareImage {
                    ShareLink(
                        item: image,
                        subject: Text("My \(monthYearString) Recap"),
                        message: Text(shareCaption),
                        preview: SharePreview("My \(monthYearString) Recap", image: image)
                    ) {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(wrappedNavy)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 44)
                            .padding(.vertical, BudgetVaultTheme.spacingMD)
                            .background(.white, in: RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusButton))
                    }
                    .accessibilityLabel("Share your \(monthYearString) wrapped")
                    .accessibilityHint("Opens the share sheet")
                    .simultaneousGesture(TapGesture().onEnded {
                        LocalMetricsService.increment(.wrappedShareTaps)
                        // TODO(plan-04-aso): wire ReviewPromptService on wrapped-shared event
                        let count = UserDefaults.standard.integer(forKey: AppStorageKeys.wrappedSharesAllTime)
                        UserDefaults.standard.set(count + 1, forKey: AppStorageKeys.wrappedSharesAllTime)
                        HapticManager.impact(.light)
                        UIAccessibility.post(notification: .announcement, argument: "Sharing your wrapped")
                    })
                    .padding(.horizontal, BudgetVaultTheme.spacingXL)
                } else {
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .padding(.horizontal, BudgetVaultTheme.spacingXL)
                        .accessibilityLabel("Preparing share image")
                }

                // Save Image button (manual photos save)
                Button {
                    saveImage()
                } label: {
                    Label("Save Image", systemImage: "arrow.down.to.line")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 44)
                        .padding(.vertical, BudgetVaultTheme.spacingMD)
                        .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusButton))
                        .overlay(
                            RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusButton)
                                .strokeBorder(.white.opacity(0.2), lineWidth: 1)
                        )
                }
                .accessibilityHint("Saves the wrapped card to your photo library")
                .padding(.horizontal, BudgetVaultTheme.spacingXL)

                Spacer()
                Spacer()
            }
        }
        .task {
            await generateShareArtifactIfNeeded()
        }
    }

    /// Pre-filled caption per spec 5.10 — quotes the saved amount and
    /// includes `budgetvault.io` for branded SEO + free attribution.
    /// Audit 2026-04-23 M2 / UX P0-4: zero-income share caption
    /// previously read "I budgeted $0.00 this month" — embarrassing.
    /// Branch on income.
    private var shareCaption: String {
        if budget.totalIncomeCents == 0 {
            return "Budgeting without a bank login. BudgetVault.\n\nbudgetvault.io"
        }
        let saved = CurrencyFormatter.format(cents: savedCents)
        return "I budgeted \(saved) this month without giving any app my bank login.\n\nbudgetvault.io"
    }

    // MARK: - Share Card Content

    private var shareCardContent: some View {
        VStack(spacing: BudgetVaultTheme.spacingLG) {
            // Header
            HStack(spacing: BudgetVaultTheme.spacingSM) {
                VaultDial(size: .icon, state: .locked, tint: .white)
                    .frame(width: 24, height: 24)
                Text("BUDGETVAULT WRAPPED")
                    .font(.caption.weight(.bold))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.6))
            }

            // Month/Year
            Text(monthYearString)
                .font(.headline)
                .foregroundStyle(.white.opacity(0.7))

            // Hero saved amount
            VStack(spacing: 4) {
                Text(CurrencyFormatter.format(cents: savedCents))
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("saved this month")
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.7))
            }

            // Stats row
            HStack(spacing: BudgetVaultTheme.spacingLG) {
                VStack(spacing: 2) {
                    Text(personalityType.emoji)
                        .font(.title2)
                    Text(personalityType.name)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.7))
                }

                VStack(spacing: 2) {
                    Text(String(format: "%.0f%%", savedPercent))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(wrappedGreen)
                    Text("saved")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.7))
                }

                VStack(spacing: 2) {
                    Text("\(periodTransactions.count)")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                    Text("entries")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }

            // Rotating brag pill (spec 5.10)
            Text(BragStatRotator.currentBragStat(
                streakDays: currentStreak,
                txCount: periodTransactions.count,
                zeroSpendDays: zeroSpendDays
            ))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.85))
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(.white.opacity(0.10), in: Capsule())

            // Footer
            Text("budgetvault.io")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    // MARK: - Image Renderer

    @MainActor
    private func renderShareCardImage() -> Image {
        // Legacy synchronous path retained for in-sheet preview only;
        // off-screen 1080x1920 render is in generateShareArtifactIfNeeded().
        let card = MonthlyWrappedShareCard(
            variant: .finalCTA,
            monthName: monthName, monthYear: monthYearString,
            savedCents: savedCents, savedPercent: savedPercent, spentPercent: spentPercent,
            totalIncomeCents: budget.totalIncomeCents, totalSpentCents: totalSpentCents,
            topCategoryName: topCategory?.name ?? "—",
            topCategoryEmoji: topCategory?.emoji ?? "\u{1F4B0}",
            topCategoryCents: topCategorySpent, topCategoryPercent: topCategoryPercent,
            transactionCount: periodTransactions.count,
            avgDailyCents: averageDailySpendCents,
            zeroSpendDays: zeroSpendDays,
            streakDays: currentStreak,
            personalityName: personalityType.name,
            personalityEmoji: personalityType.emoji,
            bragStat: BragStatRotator.currentBragStat(
                streakDays: currentStreak,
                txCount: periodTransactions.count,
                zeroSpendDays: zeroSpendDays
            )
        )
        .scaleEffect(0.33)
        .frame(width: 360, height: 640)

        let renderer = ImageRenderer(content: card)
        renderer.scale = 3
        if let uiImage = renderer.uiImage {
            return Image(uiImage: uiImage)
        }
        return Image(systemName: "square")
    }

    /// Renders the full 1080×1920 share artifact OFF the main thread.
    /// Spec 5.9: fixes the 200–800ms UI block flagged by the Performance
    /// audit. Sets `shareImage` + `sharePNGData` when complete.
    private func generateShareArtifactIfNeeded() async {
        guard !shareImageGenerationStarted else { return }
        shareImageGenerationStarted = true

        // Capture facts on main, render on background.
        let snapshot = (
            monthName: monthName,
            monthYear: monthYearString,
            savedCents: savedCents,
            savedPercent: savedPercent,
            spentPercent: spentPercent,
            totalIncomeCents: budget.totalIncomeCents,
            totalSpentCents: totalSpentCents,
            topCategoryName: topCategory?.name ?? "—",
            topCategoryEmoji: topCategory?.emoji ?? "\u{1F4B0}",
            topCategoryCents: topCategorySpent,
            topCategoryPercent: topCategoryPercent,
            transactionCount: periodTransactions.count,
            avgDailyCents: averageDailySpendCents,
            zeroSpendDays: zeroSpendDays,
            streakDays: currentStreak,
            personalityName: personalityType.name,
            personalityEmoji: personalityType.emoji,
            bragStat: BragStatRotator.currentBragStat(
                streakDays: currentStreak,
                txCount: periodTransactions.count,
                zeroSpendDays: zeroSpendDays
            )
        )

        let pngData: Data? = await Task.detached(priority: .userInitiated) { @MainActor in
            let card = MonthlyWrappedShareCard(
                variant: .finalCTA,
                monthName: snapshot.monthName, monthYear: snapshot.monthYear,
                savedCents: snapshot.savedCents, savedPercent: snapshot.savedPercent,
                spentPercent: snapshot.spentPercent,
                totalIncomeCents: snapshot.totalIncomeCents,
                totalSpentCents: snapshot.totalSpentCents,
                topCategoryName: snapshot.topCategoryName,
                topCategoryEmoji: snapshot.topCategoryEmoji,
                topCategoryCents: snapshot.topCategoryCents,
                topCategoryPercent: snapshot.topCategoryPercent,
                transactionCount: snapshot.transactionCount,
                avgDailyCents: snapshot.avgDailyCents,
                zeroSpendDays: snapshot.zeroSpendDays,
                streakDays: snapshot.streakDays,
                personalityName: snapshot.personalityName,
                personalityEmoji: snapshot.personalityEmoji,
                bragStat: snapshot.bragStat
            )
            let renderer = ImageRenderer(content: card)
            renderer.scale = 1
            renderer.proposedSize = .init(CGSize(width: 1080, height: 1920))
            return renderer.uiImage?.pngData()
        }.value

        if let data = pngData, let ui = UIImage(data: data) {
            await MainActor.run {
                self.sharePNGData = data
                self.shareImage = Image(uiImage: ui)
            }
        }
    }

    @MainActor
    private func saveImage() {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            DispatchQueue.main.async {
                if status == .authorized || status == .limited {
                    let cardView = shareCardContent
                        .padding(BudgetVaultTheme.spacingXL)
                        .frame(width: 360)
                        .background(
                            RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusXL)
                                .fill(
                                    LinearGradient(
                                        colors: [wrappedNavyMid, wrappedPurple.opacity(0.3), wrappedNavy],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                        .environment(\.colorScheme, .dark)

                    let renderer = ImageRenderer(content: cardView)
                    renderer.scale = 3
                    if let uiImage = renderer.uiImage {
                        UIImageWriteToSavedPhotosAlbum(uiImage, nil, nil, nil)
                        showSaveSuccess = true
                        HapticManager.impact(.light)
                        UIAccessibility.post(notification: .announcement, argument: "Wrapped image saved to Photos")
                    }
                } else {
                    showPhotoPermissionDenied = true
                }
            }
        }
    }

    // MARK: - Helpers

    // Audit 2026-04-23 Perf P1: hoisted from per-call allocation.
    private static let dayStringFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

    private func dayString(_ day: Int) -> String {
        let comps = DateComponents(year: budget.year, month: budget.month, day: day)
        guard let date = calendar.date(from: comps) else { return "Day \(day)" }
        return Self.dayStringFormatter.string(from: date)
    }
}

#Preview {
    MonthlyWrappedView(
        budget: Budget(month: 3, year: 2026, totalIncomeCents: 500000, resetDay: 1),
        allTransactions: []
    )
}
