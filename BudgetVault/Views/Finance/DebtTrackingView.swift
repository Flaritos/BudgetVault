import SwiftUI
import SwiftData
import BudgetVaultShared

struct DebtTrackingView: View {
    @AppStorage(AppStorageKeys.isPremium) private var isPremium = false
    @Environment(\.modelContext) private var modelContext

    @Query(filter: #Predicate<DebtAccount> { $0.isActive }, sort: \DebtAccount.createdAt)
    private var activeDebts: [DebtAccount]

    @Query(sort: \DebtAccount.createdAt)
    private var allDebts: [DebtAccount]

    @State private var showAddDebt = false
    @State private var showPaywall = false
    @State private var selectedStrategy: PayoffStrategy = .avalanche

    enum PayoffStrategy: String, CaseIterable {
        case snowball = "Snowball"
        case avalanche = "Avalanche"

        var description: String {
            switch self {
            case .snowball: "Pay smallest balance first"
            case .avalanche: "Pay highest interest first"
            }
        }

        var systemImage: String {
            switch self {
            case .snowball: "arrow.down.circle"
            case .avalanche: "arrow.up.circle"
            }
        }
    }

    private var totalDebtCents: Int64 {
        activeDebts.reduce(0) { $0 + $1.currentBalanceCents }
    }

    private var totalOriginalCents: Int64 {
        activeDebts.reduce(0) { $0 + $1.originalBalanceCents }
    }

    private var overallPaidPercentage: Double {
        guard totalOriginalCents > 0 else { return 0 }
        let totalPaid = activeDebts.reduce(Int64(0)) { $0 + $1.totalPaidCents }
        return min(max(Double(totalPaid) / Double(totalOriginalCents), 0), 1.0)
    }

    private var sortedDebts: [DebtAccount] {
        switch selectedStrategy {
        case .snowball:
            return activeDebts.sorted { $0.currentBalanceCents < $1.currentBalanceCents }
        case .avalanche:
            return activeDebts.sorted { $0.interestRate > $1.interestRate }
        }
    }

    private var paidOffDebts: [DebtAccount] {
        allDebts.filter { !$0.isActive }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: BudgetVaultTheme.spacingLG) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Debts")
                                .font(.system(size: 24, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white)
                            Text("Track and eliminate")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.5))
                        }
                        Spacer()
                        Button {
                            if isPremium {
                                showAddDebt = true
                            } else {
                                showPaywall = true
                            }
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundStyle(BudgetVaultTheme.brightBlue)
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .accessibilityLabel("Add debt")
                    }
                    .padding(.horizontal)

                    if !activeDebts.isEmpty {
                        // Total Debt Summary Card
                        totalDebtCard

                        // Strategy Picker
                        strategySection

                        // Focus Next
                        if let focusDebt = sortedDebts.first {
                            focusNextCard(focusDebt)
                        }

                        // Active Debt Cards
                        VStack(spacing: BudgetVaultTheme.spacingSM) {
                            ForEach(sortedDebts) { debt in
                                NavigationLink(destination: DebtDetailView(debt: debt)) {
                                    debtCard(debt)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Paid Off Section
                    if !paidOffDebts.isEmpty {
                        paidOffSection
                    }

                    // Empty State
                    if activeDebts.isEmpty && paidOffDebts.isEmpty {
                        emptyStateCard
                    }
                }
                .padding(.vertical)
            }
            .background(BudgetVaultTheme.navyDark.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(BudgetVaultTheme.navyDark, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .sheet(isPresented: $showAddDebt) {
                AddDebtView()
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
        }
    }

    // MARK: - Total Debt Card

    private var totalDebtCard: some View {
        VStack(spacing: BudgetVaultTheme.spacingMD) {
            Text("Total Remaining")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))
                .textCase(.uppercase)
                .tracking(1)

            Text(CurrencyFormatter.format(cents: totalDebtCents))
                .font(BudgetVaultTheme.priceDisplay)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
                .foregroundStyle(.white)

            // Progress bar
            VStack(spacing: BudgetVaultTheme.spacingXS) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.white.opacity(0.08))
                            .frame(height: 8)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(BudgetVaultTheme.positive)
                            .frame(width: max(0, geo.size.width * overallPaidPercentage), height: 8)
                    }
                }
                .frame(height: 8)

                HStack {
                    Text("\(Int(overallPaidPercentage * 100))% paid off")
                        .font(.caption)
                        .foregroundStyle(BudgetVaultTheme.positive)
                    Spacer()
                    Text("\(activeDebts.count) active")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
        }
        .padding(BudgetVaultTheme.spacingXL)
        .background(
            RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusLG)
                .fill(.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusLG)
                        .stroke(.white.opacity(0.06), lineWidth: 1)
                )
        )
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Total debt: \(CurrencyFormatter.format(cents: totalDebtCents)), \(Int(overallPaidPercentage * 100)) percent paid off, \(activeDebts.count) active debts")
    }

    // MARK: - Strategy Section

    private var strategySection: some View {
        VStack(alignment: .leading, spacing: BudgetVaultTheme.spacingSM) {
            Picker("Strategy", selection: $selectedStrategy) {
                ForEach(PayoffStrategy.allCases, id: \.self) { strategy in
                    Text(strategy.rawValue).tag(strategy)
                }
            }
            .pickerStyle(.segmented)
            .colorMultiply(BudgetVaultTheme.brightBlue)

            HStack(spacing: BudgetVaultTheme.spacingSM) {
                Image(systemName: selectedStrategy.systemImage)
                    .foregroundStyle(BudgetVaultTheme.electricBlue)
                Text(selectedStrategy.description)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Focus Next Card

    private func focusNextCard(_ debt: DebtAccount) -> some View {
        VStack(alignment: .leading, spacing: BudgetVaultTheme.spacingSM) {
            HStack(spacing: 4) {
                Text("FOCUS NEXT")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(BudgetVaultTheme.caution)
                    .tracking(1)
                Text("\u{26A1}")
                    .font(.caption)
            }

            HStack(spacing: BudgetVaultTheme.spacingSM) {
                Text(debt.emoji)
                    .font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text(debt.name)
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                    if debt.interestRate > 0 {
                        Text("\(debt.interestRate, specifier: "%.1f")% APR")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(CurrencyFormatter.format(cents: debt.currentBalanceCents))
                        .font(BudgetVaultTheme.rowAmount)
                        .foregroundStyle(.white)
                    if let months = debt.estimatedMonthsToPayoff {
                        Text("~\(months) mo")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
            }
        }
        .padding(BudgetVaultTheme.spacingLG)
        .background(
            RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusMD)
                .fill(BudgetVaultTheme.caution.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusMD)
                        .stroke(BudgetVaultTheme.caution.opacity(0.2), lineWidth: 1)
                )
        )
        .padding(.horizontal)
    }

    // MARK: - Debt Card

    private func debtCard(_ debt: DebtAccount) -> some View {
        VStack(spacing: BudgetVaultTheme.spacingSM) {
            HStack {
                Text(debt.emoji)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text(debt.name)
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                    HStack(spacing: BudgetVaultTheme.spacingSM) {
                        if debt.interestRate > 0 {
                            Text("\(debt.interestRate, specifier: "%.1f")% APR")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.4))
                        }
                        if debt.dueDay > 0 {
                            Text("Due \(ordinal(debt.dueDay))")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.4))
                        }
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(CurrencyFormatter.format(cents: debt.currentBalanceCents))
                        .font(BudgetVaultTheme.rowAmount)
                        .foregroundStyle(.white)
                    Text("of \(CurrencyFormatter.format(cents: debt.originalBalanceCents))")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.4))
                }
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(.white.opacity(0.08))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(BudgetVaultTheme.positive)
                        .frame(width: max(0, geo.size.width * debt.paidOffPercentage), height: 6)
                }
            }
            .frame(height: 6)

            HStack {
                Text("\(Int(debt.paidOffPercentage * 100))% paid")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.4))
                Spacer()
                if let months = debt.estimatedMonthsToPayoff {
                    Text("~\(months) mo to payoff")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
        }
        .padding(BudgetVaultTheme.spacingLG)
        .background(
            RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusMD)
                .fill(.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusMD)
                        .stroke(.white.opacity(0.06), lineWidth: 1)
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(debt.emoji) \(debt.name): \(CurrencyFormatter.format(cents: debt.currentBalanceCents)) of \(CurrencyFormatter.format(cents: debt.originalBalanceCents))\(debt.interestRate > 0 ? ", \(String(format: "%.1f", debt.interestRate)) percent APR" : ""), \(Int(debt.paidOffPercentage * 100)) percent paid off")
    }

    // MARK: - Paid Off Section

    private var paidOffSection: some View {
        VStack(alignment: .leading, spacing: BudgetVaultTheme.spacingSM) {
            HStack(spacing: 6) {
                Text("PAID OFF")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(BudgetVaultTheme.positive)
                    .tracking(1)
                Text("\u{1F389}")
                    .font(.caption)
            }
            .padding(.horizontal)

            ForEach(paidOffDebts) { debt in
                HStack {
                    Text(debt.emoji)
                        .font(.title3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(debt.name)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.5))
                            .strikethrough(color: .white.opacity(0.3))
                        Text(CurrencyFormatter.format(cents: debt.originalBalanceCents))
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.3))
                    }
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(BudgetVaultTheme.positive)
                        .font(.title3)
                }
                .padding(BudgetVaultTheme.spacingMD)
                .background(
                    RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusMD)
                        .fill(BudgetVaultTheme.positive.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusMD)
                                .stroke(BudgetVaultTheme.positive.opacity(0.12), lineWidth: 1)
                        )
                )
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateCard: some View {
        VStack(spacing: BudgetVaultTheme.spacingLG) {
            Image(systemName: "creditcard.trianglebadge.exclamationmark")
                .font(.system(size: 48))
                .foregroundStyle(.white.opacity(0.3))

            Text("No Debts Tracked")
                .font(.headline)
                .foregroundStyle(.white)

            Text("Add your debts to track payoff progress and find the best strategy to become debt-free.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)

            Button {
                if isPremium {
                    showAddDebt = true
                } else {
                    showPaywall = true
                }
            } label: {
                Label("Add First Debt", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, BudgetVaultTheme.spacingMD)
                    .background(BudgetVaultTheme.electricBlue, in: RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusButton))
            }
        }
        .padding(BudgetVaultTheme.spacingXL)
        .padding(.horizontal)
    }

    // MARK: - Actions

    private func archiveDebts(at offsets: IndexSet) {
        for index in offsets {
            sortedDebts[index].isActive = false
        }
        guard SafeSave.save(modelContext) else {
            modelContext.rollback()
            return
        }
    }

    // MARK: - Helpers

    private func ordinal(_ day: Int) -> String {
        let suffix: String
        switch day {
        case 1, 21, 31: suffix = "st"
        case 2, 22: suffix = "nd"
        case 3, 23: suffix = "rd"
        default: suffix = "th"
        }
        return "\(day)\(suffix)"
    }
}
