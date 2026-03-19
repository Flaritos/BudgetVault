import SwiftUI
import SwiftData

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

    var body: some View {
        NavigationStack {
            List {
                if !activeDebts.isEmpty {
                    totalDebtSection
                    payoffStrategySection
                    debtsListSection
                }

                let paidOff = allDebts.filter { !$0.isActive }
                if !paidOff.isEmpty {
                    paidOffSection(paidOff)
                }

                if activeDebts.isEmpty && allDebts.filter({ !$0.isActive }).isEmpty {
                    emptyStateSection
                }
            }
            .navigationTitle("Debt Tracker")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        if isPremium {
                            showAddDebt = true
                        } else {
                            showPaywall = true
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                    .accessibilityLabel("Add debt")
                }
            }
            .sheet(isPresented: $showAddDebt) {
                AddDebtView()
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
        }
    }

    // MARK: - Total Debt Section

    private var totalDebtSection: some View {
        Section {
            VStack(spacing: BudgetVaultTheme.spacingMD) {
                Text("Total Debt")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(CurrencyFormatter.format(cents: totalDebtCents))
                    .font(.system(size: 36, weight: .heavy, design: .rounded))
                    .foregroundStyle(BudgetVaultTheme.negative)

                // Overall progress
                VStack(spacing: BudgetVaultTheme.spacingXS) {
                    ProgressView(value: overallPaidPercentage)
                        .tint(BudgetVaultTheme.positive)

                    HStack {
                        Text("\(Int(overallPaidPercentage * 100))% paid off")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(activeDebts.count) active debt\(activeDebts.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, BudgetVaultTheme.spacingSM)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Total debt: \(CurrencyFormatter.format(cents: totalDebtCents)), \(Int(overallPaidPercentage * 100)) percent paid off, \(activeDebts.count) active debts")
        }
    }

    // MARK: - Payoff Strategy Section

    private var payoffStrategySection: some View {
        Section {
            VStack(alignment: .leading, spacing: BudgetVaultTheme.spacingMD) {
                Text("Payoff Strategy")
                    .font(.headline)

                Picker("Strategy", selection: $selectedStrategy) {
                    ForEach(PayoffStrategy.allCases, id: \.self) { strategy in
                        Text(strategy.rawValue).tag(strategy)
                    }
                }
                .pickerStyle(.segmented)

                HStack(spacing: BudgetVaultTheme.spacingSM) {
                    Image(systemName: selectedStrategy.systemImage)
                        .foregroundStyle(BudgetVaultTheme.electricBlue)
                    Text(selectedStrategy.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let focusDebt = sortedDebts.first {
                    HStack(spacing: BudgetVaultTheme.spacingSM) {
                        Text(focusDebt.emoji)
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Focus extra payments on:")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(focusDebt.name)
                                .font(.subheadline.bold())
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text(CurrencyFormatter.format(cents: focusDebt.currentBalanceCents))
                                .font(BudgetVaultTheme.rowAmount)
                                .foregroundStyle(BudgetVaultTheme.negative)
                            if focusDebt.interestRate > 0 {
                                Text("\(focusDebt.interestRate, specifier: "%.1f")% APR")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(BudgetVaultTheme.spacingMD)
                    .background(
                        RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusSM)
                            .fill(Color.accentColor.opacity(0.08))
                    )
                }
            }
            .padding(.vertical, BudgetVaultTheme.spacingXS)
        }
    }

    // MARK: - Debts List Section

    private var debtsListSection: some View {
        Section("Active Debts") {
            ForEach(sortedDebts) { debt in
                NavigationLink(destination: DebtDetailView(debt: debt)) {
                    debtRow(debt)
                }
            }
            .onDelete(perform: archiveDebts)
        }
    }

    private func debtRow(_ debt: DebtAccount) -> some View {
        VStack(spacing: BudgetVaultTheme.spacingSM) {
            HStack {
                Text(debt.emoji)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text(debt.name)
                        .font(.subheadline.bold())
                    if debt.interestRate > 0 {
                        Text("\(debt.interestRate, specifier: "%.1f")% APR")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(CurrencyFormatter.format(cents: debt.currentBalanceCents))
                        .font(BudgetVaultTheme.rowAmount)
                        .foregroundStyle(BudgetVaultTheme.negative)
                    Text("of \(CurrencyFormatter.format(cents: debt.originalBalanceCents))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            ProgressView(value: debt.paidOffPercentage)
                .tint(BudgetVaultTheme.positive)
        }
        .padding(.vertical, BudgetVaultTheme.spacingXS)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(debt.emoji) \(debt.name): \(CurrencyFormatter.format(cents: debt.currentBalanceCents)) of \(CurrencyFormatter.format(cents: debt.originalBalanceCents))\(debt.interestRate > 0 ? ", \(String(format: "%.1f", debt.interestRate)) percent APR" : ""), \(Int(debt.paidOffPercentage * 100)) percent paid off")
    }

    // MARK: - Paid Off Section

    private func paidOffSection(_ paidOff: [DebtAccount]) -> some View {
        Section("Paid Off") {
            ForEach(paidOff) { debt in
                HStack {
                    Text(debt.emoji)
                        .font(.title3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(debt.name)
                            .font(.subheadline)
                            .strikethrough()
                        Text(CurrencyFormatter.format(cents: debt.originalBalanceCents))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(BudgetVaultTheme.positive)
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateSection: some View {
        Section {
            VStack(spacing: BudgetVaultTheme.spacingLG) {
                Image(systemName: "creditcard.trianglebadge.exclamationmark")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)

                Text("No Debts Tracked")
                    .font(.headline)

                Text("Add your debts to track payoff progress and find the best strategy to become debt-free.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
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
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, BudgetVaultTheme.spacingMD)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.vertical, BudgetVaultTheme.spacingXL)
        }
    }

    // MARK: - Actions

    private func archiveDebts(at offsets: IndexSet) {
        for index in offsets {
            sortedDebts[index].isActive = false
        }
        SafeSave.save(modelContext)
    }
}
