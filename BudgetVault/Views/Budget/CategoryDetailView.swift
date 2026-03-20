import SwiftUI
import SwiftData

struct CategoryDetailView: View {
    let category: Category
    let budget: Budget

    @Environment(\.modelContext) private var modelContext
    @AppStorage(AppStorageKeys.isPremium) private var isPremium = false
    @State private var editingTransaction: Transaction?
    @State private var showPaywall = false

    private var transactions: [Transaction] {
        (category.transactions ?? [])
            .filter { !$0.isIncome && $0.date >= budget.periodStart && $0.date < budget.nextPeriodStart }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        List {
            // Header
            Section {
                VStack(spacing: 12) {
                    Text(category.emoji)
                        .font(.system(size: 48))

                    Text(category.name)
                        .font(.title2.bold())

                    BudgetRingView(spent: category.spentCents(in: budget), budgeted: category.budgetedAmountCents)
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
            }

            // Settings
            if isPremium {
                Section("Settings") {
                    Toggle("Roll over unspent amount", isOn: Binding(
                        get: { category.rollOverUnspent },
                        set: { newValue in
                            category.rollOverUnspent = newValue
                            SafeSave.save(modelContext)
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
                    Text("No expenses in \(category.name) this month.")
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
                    }
                }
            }
        }
        .navigationTitle(category.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editingTransaction) { transaction in
            TransactionEditView(transaction: transaction, budget: budget, categories: (budget.categories ?? []).filter { !$0.isHidden })
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
                .presentationDragIndicator(.visible)
        }
    }
}
