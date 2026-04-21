import SwiftUI
import SwiftData
import BudgetVaultShared

struct CategoryDetailView: View {
    let category: Category
    let budget: Budget

    @Environment(\.modelContext) private var modelContext
    @AppStorage(AppStorageKeys.isPremium) private var isPremium = false
    @State private var editingTransaction: Transaction?
    @State private var showPaywall = false
    @State private var showAddTransaction = false

    private var transactions: [Transaction] {
        (category.transactions ?? [])
            .filter { !$0.isIncome && $0.date >= budget.periodStart && $0.date < budget.nextPeriodStart }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        List {
            // Header
            Section {
                VStack(spacing: BudgetVaultTheme.spacingMD) {
                    Text(category.emoji)
                        .font(BudgetVaultTheme.iconLarge)

                    Text(category.name)
                        .font(.title2.bold())

                    // VaultRevamp v2.1: progress expressed via VaultDial
                    // instead of the retired BudgetRingView. Shows spent /
                    // budgeted as an arc inside the titanium bezel.
                    VaultDial(
                        size: .medium,
                        state: .progress(
                            category.budgetedAmountCents > 0
                                ? min(max(Double(category.spentCents(in: budget)) / Double(category.budgetedAmountCents), 0), 1)
                                : 0
                        )
                    )
                    .frame(width: 80, height: 80)

                    HStack {
                        Text("Spent: \(CurrencyFormatter.format(cents: category.spentCents(in: budget)))")
                        Text("of \(CurrencyFormatter.format(cents: category.budgetedAmountCents))")
                            .foregroundStyle(.secondary)
                    }
                    .font(.subheadline)
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(category.emoji) \(category.name): spent \(CurrencyFormatter.format(cents: category.spentCents(in: budget))) of \(CurrencyFormatter.format(cents: category.budgetedAmountCents))")
            }

            // Settings
            if isPremium {
                Section("Settings") {
                    Toggle("Roll over unspent amount", isOn: Binding(
                        get: { category.rollOverUnspent },
                        set: { newValue in
                            category.rollOverUnspent = newValue
                            guard SafeSave.save(modelContext) else {
                                modelContext.rollback()
                                return
                            }
                        }
                    ))

                    if category.rollOverUnspent {
                        Text("Unspent funds will carry forward to next month's budget for this category.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Section("Settings") {
                    Button {
                        showPaywall = true
                    } label: {
                        HStack {
                            Label("Roll over unspent", systemImage: "arrow.forward.circle")
                            Spacer()
                            Image(systemName: "lock.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tint(.primary)
                }
            }

            // Transactions
            Section("Transactions") {
                if transactions.isEmpty {
                    Text("No expenses in \(category.name) this period.")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                } else {
                    ForEach(transactions, id: \.id) { transaction in
                        Button {
                            editingTransaction = transaction
                        } label: {
                            TransactionRowView(transaction: transaction)
                        }
                        .tint(.primary)
                        .accessibilityHint("Double tap to edit transaction")
                    }
                }
            }
        }
        .navigationTitle(category.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddTransaction = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add expense to \(category.name)")
            }
        }
        .sheet(isPresented: $showAddTransaction) {
            TransactionEntryView(
                budget: budget,
                categories: (budget.categories ?? []).filter { !$0.isHidden }.sorted { $0.sortOrder < $1.sortOrder },
                prefillCategoryName: category.name
            )
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $editingTransaction) { transaction in
            TransactionEditView(transaction: transaction, budget: budget, categories: (budget.categories ?? []).filter { !$0.isHidden })
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
                .presentationDragIndicator(.visible)
        }
    }
}
