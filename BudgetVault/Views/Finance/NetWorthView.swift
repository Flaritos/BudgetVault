import SwiftUI
import SwiftData
import Charts

struct NetWorthView: View {
    @AppStorage(AppStorageKeys.isPremium) private var isPremium = false
    @Environment(\.modelContext) private var modelContext

    @Query(filter: #Predicate<NetWorthAccount> { $0.isActive }, sort: \NetWorthAccount.name)
    private var activeAccounts: [NetWorthAccount]

    @Query(sort: \NetWorthSnapshot.date)
    private var snapshots: [NetWorthSnapshot]

    @State private var showAddAccount = false
    @State private var showPaywall = false
    @State private var showUpdateBalances = false

    private var assetAccounts: [NetWorthAccount] {
        activeAccounts.filter { $0.accountType == "asset" }
    }

    private var liabilityAccounts: [NetWorthAccount] {
        activeAccounts.filter { $0.accountType == "liability" }
    }

    private var totalAssetsCents: Int64 {
        assetAccounts.reduce(0) { $0 + $1.balanceCents }
    }

    private var totalLiabilitiesCents: Int64 {
        liabilityAccounts.reduce(0) { $0 + $1.balanceCents }
    }

    private var netWorthCents: Int64 {
        totalAssetsCents - totalLiabilitiesCents
    }

    var body: some View {
        NavigationStack {
            List {
                netWorthHeaderSection

                if snapshots.count >= 2 {
                    trendChartSection
                }

                if !assetAccounts.isEmpty {
                    assetsSection
                }

                if !liabilityAccounts.isEmpty {
                    liabilitiesSection
                }

                if activeAccounts.isEmpty {
                    emptyStateSection
                }

                if !activeAccounts.isEmpty {
                    updateBalancesSection
                }
            }
            .navigationTitle("Net Worth")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        if isPremium {
                            showAddAccount = true
                        } else {
                            showPaywall = true
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                }
            }
            .sheet(isPresented: $showAddAccount) {
                AddAccountView()
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .sheet(isPresented: $showUpdateBalances) {
                UpdateBalancesView(
                    accounts: activeAccounts,
                    onSave: { saveSnapshotAndDismiss() }
                )
            }
        }
    }

    // MARK: - Net Worth Header

    private var netWorthHeaderSection: some View {
        Section {
            VStack(spacing: BudgetVaultTheme.spacingMD) {
                Text("Net Worth")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(CurrencyFormatter.format(cents: netWorthCents))
                    .font(.system(size: 36, weight: .heavy, design: .rounded))
                    .foregroundStyle(netWorthCents >= 0 ? BudgetVaultTheme.positive : BudgetVaultTheme.negative)

                HStack(spacing: BudgetVaultTheme.spacingXL) {
                    VStack(spacing: BudgetVaultTheme.spacingXS) {
                        Text("Assets")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(CurrencyFormatter.format(cents: totalAssetsCents))
                            .font(.subheadline.bold())
                            .foregroundStyle(BudgetVaultTheme.positive)
                    }

                    VStack(spacing: BudgetVaultTheme.spacingXS) {
                        Text("Liabilities")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(CurrencyFormatter.format(cents: totalLiabilitiesCents))
                            .font(.subheadline.bold())
                            .foregroundStyle(BudgetVaultTheme.negative)
                    }
                }

                if let lastSnapshot = snapshots.last, snapshots.count >= 2 {
                    let previousSnapshot = snapshots[snapshots.count - 2]
                    let changeCents = lastSnapshot.netWorthCents - previousSnapshot.netWorthCents
                    if changeCents != 0 {
                        HStack(spacing: BudgetVaultTheme.spacingXS) {
                            Image(systemName: changeCents > 0 ? "arrow.up.right" : "arrow.down.right")
                            Text(CurrencyFormatter.format(cents: abs(changeCents)))
                            Text("since last update")
                                .foregroundStyle(.secondary)
                        }
                        .font(.caption)
                        .foregroundStyle(changeCents > 0 ? BudgetVaultTheme.positive : BudgetVaultTheme.negative)
                    }
                }
            }
            .padding(.vertical, BudgetVaultTheme.spacingSM)
        }
    }

    // MARK: - Trend Chart

    private var trendChartSection: some View {
        Section("Trend") {
            Chart(snapshots) { snapshot in
                LineMark(
                    x: .value("Date", snapshot.date),
                    y: .value("Net Worth", Double(snapshot.netWorthCents) / 100.0)
                )
                .foregroundStyle(BudgetVaultTheme.electricBlue)
                .interpolationMethod(.catmullRom)

                AreaMark(
                    x: .value("Date", snapshot.date),
                    y: .value("Net Worth", Double(snapshot.netWorthCents) / 100.0)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [BudgetVaultTheme.electricBlue.opacity(0.3), BudgetVaultTheme.electricBlue.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value("Date", snapshot.date),
                    y: .value("Net Worth", Double(snapshot.netWorthCents) / 100.0)
                )
                .foregroundStyle(BudgetVaultTheme.electricBlue)
                .symbolSize(20)
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let doubleValue = value.as(Double.self) {
                            Text(CurrencyFormatter.format(cents: Int64(doubleValue * 100)))
                                .font(.caption2)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                }
            }
            .frame(height: 200)
            .padding(.vertical, BudgetVaultTheme.spacingSM)
        }
    }

    // MARK: - Assets Section

    private var assetsSection: some View {
        Section {
            ForEach(assetAccounts) { account in
                accountRow(account)
            }
            .onDelete(perform: deleteAssets)
        } header: {
            HStack {
                Text("Assets")
                Spacer()
                Text(CurrencyFormatter.format(cents: totalAssetsCents))
                    .font(.caption)
                    .foregroundStyle(BudgetVaultTheme.positive)
            }
        }
    }

    // MARK: - Liabilities Section

    private var liabilitiesSection: some View {
        Section {
            ForEach(liabilityAccounts) { account in
                accountRow(account)
            }
            .onDelete(perform: deleteLiabilities)
        } header: {
            HStack {
                Text("Liabilities")
                Spacer()
                Text(CurrencyFormatter.format(cents: totalLiabilitiesCents))
                    .font(.caption)
                    .foregroundStyle(BudgetVaultTheme.negative)
            }
        }
    }

    private func accountRow(_ account: NetWorthAccount) -> some View {
        HStack {
            Text(account.emoji)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text(account.name)
                    .font(.subheadline)
                Text("Updated \(account.lastUpdated, style: .relative) ago")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(CurrencyFormatter.format(cents: account.balanceCents))
                .font(BudgetVaultTheme.rowAmount)
                .foregroundStyle(account.isAsset ? BudgetVaultTheme.positive : BudgetVaultTheme.negative)
        }
    }

    // MARK: - Update Balances

    private var updateBalancesSection: some View {
        Section {
            Button {
                showUpdateBalances = true
            } label: {
                Label("Update Balances", systemImage: "arrow.triangle.2.circlepath")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, BudgetVaultTheme.spacingSM)
            }
            .buttonStyle(.borderedProminent)
            .listRowInsets(EdgeInsets(top: BudgetVaultTheme.spacingSM, leading: BudgetVaultTheme.spacingLG, bottom: BudgetVaultTheme.spacingSM, trailing: BudgetVaultTheme.spacingLG))
        }
    }

    // MARK: - Empty State

    private var emptyStateSection: some View {
        Section {
            VStack(spacing: BudgetVaultTheme.spacingLG) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)

                Text("Track Your Net Worth")
                    .font(.headline)

                Text("Add your bank accounts, investments, and liabilities to see your full financial picture over time.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button {
                    if isPremium {
                        showAddAccount = true
                    } else {
                        showPaywall = true
                    }
                } label: {
                    Label("Add First Account", systemImage: "plus.circle.fill")
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

    private func saveSnapshotAndDismiss() {
        let snapshot = NetWorthSnapshot(
            totalAssetsCents: totalAssetsCents,
            totalLiabilitiesCents: totalLiabilitiesCents
        )
        modelContext.insert(snapshot)
        SafeSave.save(modelContext)
        showUpdateBalances = false
    }

    private func deleteAssets(at offsets: IndexSet) {
        for index in offsets {
            assetAccounts[index].isActive = false
        }
        SafeSave.save(modelContext)
    }

    private func deleteLiabilities(at offsets: IndexSet) {
        for index in offsets {
            liabilityAccounts[index].isActive = false
        }
        SafeSave.save(modelContext)
    }
}

// MARK: - Update Balances View

struct UpdateBalancesView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let accounts: [NetWorthAccount]
    let onSave: () -> Void

    @State private var balanceTexts: [UUID: String] = [:]

    var body: some View {
        NavigationStack {
            Form {
                let assets = accounts.filter { $0.accountType == "asset" }
                let liabilities = accounts.filter { $0.accountType == "liability" }

                if !assets.isEmpty {
                    Section("Assets") {
                        ForEach(assets) { account in
                            balanceField(account)
                        }
                    }
                }

                if !liabilities.isEmpty {
                    Section("Liabilities") {
                        ForEach(liabilities) { account in
                            balanceField(account)
                        }
                    }
                }
            }
            .navigationTitle("Update Balances")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveBalances()
                    }
                }
            }
            .onAppear {
                for account in accounts {
                    balanceTexts[account.id] = String(format: "%.2f", Double(account.balanceCents) / 100.0)
                }
            }
        }
    }

    private func balanceField(_ account: NetWorthAccount) -> some View {
        HStack {
            Text(account.emoji)
            Text(account.name)
                .font(.subheadline)
            Spacer()
            HStack {
                Text(CurrencyFormatter.currencySymbol())
                    .foregroundStyle(.secondary)
                TextField("0", text: Binding(
                    get: { balanceTexts[account.id] ?? "" },
                    set: { balanceTexts[account.id] = $0 }
                ))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 120)
            }
        }
    }

    private func saveBalances() {
        for account in accounts {
            if let text = balanceTexts[account.id],
               let cents = MoneyHelpers.parseCurrencyString(text) {
                account.balanceCents = cents
                account.lastUpdated = Date.now
            }
        }
        SafeSave.save(modelContext)
        HapticManager.notification(.success)
        onSave()
    }
}
