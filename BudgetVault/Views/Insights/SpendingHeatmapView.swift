import SwiftUI

struct SpendingHeatmapView: View {
    let budget: Budget
    let allTransactions: [Transaction]

    @AppStorage("isPremium") private var isPremium = false
    @State private var selectedDay: DayData?
    @State private var popoverAnchor: CGPoint = .zero

    // MARK: - Computed

    private var calendar: Calendar { Calendar.current }

    private var daysInMonth: Int {
        let comps = DateComponents(year: budget.year, month: budget.month)
        guard let date = calendar.date(from: comps),
              let range = calendar.range(of: .day, in: .month, for: date) else { return 30 }
        return range.count
    }

    /// Daily budget allowance in cents
    private var dailyAllowanceCents: Int64 {
        guard daysInMonth > 0 else { return 0 }
        return budget.totalIncomeCents / Int64(daysInMonth)
    }

    /// Weekday index (0 = Sun) of day 1 of the month
    private var firstWeekday: Int {
        let comps = DateComponents(year: budget.year, month: budget.month, day: 1)
        guard let date = calendar.date(from: comps) else { return 0 }
        return calendar.component(.weekday, from: date) - 1 // 0-indexed
    }

    /// Spending per day (1-indexed by day of month)
    private var dailySpending: [Int: Int64] {
        var result: [Int: Int64] = [:]
        let periodTransactions = allTransactions.filter { tx in
            !tx.isIncome && tx.date >= budget.periodStart && tx.date < budget.nextPeriodStart
        }
        for tx in periodTransactions {
            let day = calendar.component(.day, from: tx.date)
            result[day, default: 0] += tx.amountCents
        }
        return result
    }

    /// Transaction count per day
    private var dailyTransactionCount: [Int: Int] {
        var result: [Int: Int] = [:]
        let periodTransactions = allTransactions.filter { tx in
            !tx.isIncome && tx.date >= budget.periodStart && tx.date < budget.nextPeriodStart
        }
        for tx in periodTransactions {
            let day = calendar.component(.day, from: tx.date)
            result[day, default: 0] += 1
        }
        return result
    }

    /// Grid data: 6 rows x 7 columns max
    private var gridData: [[DayData?]] {
        var rows: [[DayData?]] = []
        var currentRow: [DayData?] = Array(repeating: nil, count: firstWeekday)
        for day in 1...daysInMonth {
            let spent = dailySpending[day] ?? 0
            let count = dailyTransactionCount[day] ?? 0
            let data = DayData(day: day, spentCents: spent, transactionCount: count)
            currentRow.append(data)
            if currentRow.count == 7 {
                rows.append(currentRow)
                currentRow = []
            }
        }
        if !currentRow.isEmpty {
            while currentRow.count < 7 { currentRow.append(nil) }
            rows.append(currentRow)
        }
        return rows
    }

    private let dayLabels = ["S", "M", "T", "W", "T", "F", "S"]

    var body: some View {
        VStack(alignment: .leading, spacing: BudgetVaultTheme.spacingMD) {
            // Title
            HStack {
                Image(systemName: "calendar.badge.clock")
                    .foregroundStyle(BudgetVaultTheme.electricBlue)
                Text("Spending Heatmap")
                    .font(.headline)
                Spacer()
                if !isPremium {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            ZStack {
                VStack(spacing: BudgetVaultTheme.spacingXS) {
                    // Day labels
                    HStack(spacing: BudgetVaultTheme.spacingXS) {
                        ForEach(0..<7, id: \.self) { i in
                            Text(dayLabels[i])
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                        }
                    }

                    // Grid
                    ForEach(0..<gridData.count, id: \.self) { row in
                        HStack(spacing: BudgetVaultTheme.spacingXS) {
                            ForEach(0..<7, id: \.self) { col in
                                if let dayData = gridData[row][col] {
                                    dayCellView(dayData)
                                } else {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.clear)
                                        .aspectRatio(1, contentMode: .fit)
                                        .frame(maxWidth: .infinity)
                                }
                            }
                        }
                    }

                    // Legend
                    HStack(spacing: BudgetVaultTheme.spacingSM) {
                        Text("Less")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        legendCell(intensity: .none)
                        legendCell(intensity: .light)
                        legendCell(intensity: .medium)
                        legendCell(intensity: .heavy)
                        Text("More")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, BudgetVaultTheme.spacingSM)
                }

                // Premium lock overlay
                if !isPremium {
                    RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusMD)
                        .fill(.ultraThinMaterial)
                        .overlay {
                            VStack(spacing: BudgetVaultTheme.spacingSM) {
                                Image(systemName: "lock.fill")
                                    .font(.title2)
                                Text("Upgrade to Premium")
                                    .font(.subheadline.weight(.semibold))
                            }
                            .foregroundStyle(.secondary)
                        }
                }
            }
        }
        .padding(BudgetVaultTheme.spacingLG)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusMD))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
        .popover(item: $selectedDay) { day in
            dayPopover(day)
                .presentationCompactAdaptation(.popover)
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private func dayCellView(_ data: DayData) -> some View {
        let color = intensityColor(for: data.spentCents)
        RoundedRectangle(cornerRadius: 4)
            .fill(color)
            .aspectRatio(1, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .overlay {
                Text("\(data.day)")
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(data.spentCents > 0 ? .white.opacity(0.8) : .secondary.opacity(0.6))
            }
            .shadow(color: color.opacity(0.3), radius: 2, y: 1)
            .onTapGesture {
                if isPremium {
                    selectedDay = data
                }
            }
            .accessibilityLabel("Day \(data.day): \(CurrencyFormatter.format(cents: data.spentCents)) spent, \(data.transactionCount) transactions")
    }

    @ViewBuilder
    private func legendCell(intensity: SpendingIntensity) -> some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(intensityColorForLevel(intensity))
            .frame(width: 14, height: 14)
    }

    @ViewBuilder
    private func dayPopover(_ data: DayData) -> some View {
        VStack(spacing: BudgetVaultTheme.spacingSM) {
            Text(dayDateString(data.day))
                .font(.subheadline.weight(.semibold))
            HStack(spacing: BudgetVaultTheme.spacingLG) {
                VStack {
                    Text("Spent")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(CurrencyFormatter.format(cents: data.spentCents))
                        .font(.subheadline.weight(.bold))
                }
                VStack {
                    Text("Transactions")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(data.transactionCount)")
                        .font(.subheadline.weight(.bold))
                }
            }
            if dailyAllowanceCents > 0 {
                let pct = Double(data.spentCents) / Double(dailyAllowanceCents) * 100
                Text(String(format: "%.0f%% of daily allowance", pct))
                    .font(.caption)
                    .foregroundStyle(pct > 100 ? BudgetVaultTheme.negative : BudgetVaultTheme.positive)
            }
        }
        .padding(BudgetVaultTheme.spacingMD)
    }

    // MARK: - Helpers

    private func dayDateString(_ day: Int) -> String {
        let comps = DateComponents(year: budget.year, month: budget.month, day: day)
        guard let date = calendar.date(from: comps) else { return "" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    private func intensityColor(for spentCents: Int64) -> Color {
        let level = intensityLevel(for: spentCents)
        return intensityColorForLevel(level)
    }

    private func intensityColorForLevel(_ level: SpendingIntensity) -> Color {
        switch level {
        case .none:
            return Color(.systemGray5)
        case .light:
            return BudgetVaultTheme.positive.opacity(0.35)
        case .medium:
            return BudgetVaultTheme.caution.opacity(0.6)
        case .heavy:
            return BudgetVaultTheme.negative.opacity(0.8)
        }
    }

    private func intensityLevel(for spentCents: Int64) -> SpendingIntensity {
        guard spentCents > 0 else { return .none }
        guard dailyAllowanceCents > 0 else { return .light }

        let ratio = Double(spentCents) / Double(dailyAllowanceCents)
        if ratio <= 0.5 {
            return .light
        } else if ratio <= 1.0 {
            return .medium
        } else {
            return .heavy
        }
    }
}

// MARK: - Supporting Types

extension SpendingHeatmapView {
    struct DayData: Identifiable {
        let day: Int
        let spentCents: Int64
        let transactionCount: Int
        var id: Int { day }
    }

    enum SpendingIntensity {
        case none, light, medium, heavy
    }
}

#Preview {
    SpendingHeatmapView(
        budget: Budget(month: 3, year: 2026, totalIncomeCents: 500000, resetDay: 1),
        allTransactions: []
    )
    .padding()
}
