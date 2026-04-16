import SwiftUI
import SwiftData
import BudgetVaultShared

struct RecurringExpenseListView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage(AppStorageKeys.isPremium) private var isPremium = false

    @Query(sort: \RecurringExpense.nextDueDate) private var allExpenses: [RecurringExpense]
    @Query(sort: \Transaction.date, order: .reverse) private var recentTransactions: [Transaction]

    @State private var showForm = false
    @State private var editingExpense: RecurringExpense?
    @State private var showPaywall = false

    private var activeExpenses: [RecurringExpense] {
        allExpenses.filter { $0.isActive }
    }

    private var inactiveExpenses: [RecurringExpense] {
        allExpenses.filter { !$0.isActive }
    }

    private var recentRecurringTransactions: [Transaction] {
        recentTransactions
            .filter { $0.isRecurring }
            .prefix(5)
            .map { $0 }
    }

    var body: some View {
        Group {
            if allExpenses.isEmpty {
                EmptyStateView(
                    icon: "repeat",
                    title: "No Recurring Expenses",
                    message: "Add bills like Netflix or rent to auto-track them.",
                    actionLabel: "Add Recurring Expense",
                    action: { showForm = true }
                )
            } else {
                expenseList
            }
        }
        .navigationTitle("Recurring Expenses")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    let activeCount = activeExpenses.count
                    if !isPremium && activeCount >= 3 {
                        showPaywall = true
                    } else {
                        showForm = true
                    }
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add recurring expense")
            }
            if !isPremium {
                ToolbarItem(placement: .bottomBar) {
                    Text("\(activeExpenses.count)/3 active")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .sheet(isPresented: $showForm) {
            RecurringExpenseFormView(expense: nil)
        }
        .sheet(item: $editingExpense) { expense in
            RecurringExpenseFormView(expense: expense)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .onChange(of: isPremium) { _, newValue in
            if newValue && showPaywall {
                showPaywall = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showForm = true
                }
            }
        }
    }

    @ViewBuilder
    private var expenseList: some View {
        List {
            if !activeExpenses.isEmpty {
                Section("Upcoming") {
                    ForEach(activeExpenses, id: \.id) { expense in
                        Button {
                            editingExpense = expense
                        } label: {
                            RecurringExpenseRowView(expense: expense)
                        }
                        .tint(.primary)
                        .swipeActions(edge: .trailing) {
                            Button("Deactivate") {
                                expense.isActive = false
                                guard SafeSave.save(modelContext) else {
                                    modelContext.rollback()
                                    return
                                }
                            }
                            .tint(BudgetVaultTheme.caution)
                        }
                        .accessibilityHint("Double tap to edit. Swipe left to deactivate.")
                    }
                }
            }

            if !recentRecurringTransactions.isEmpty {
                Section("Recently Posted") {
                    ForEach(recentRecurringTransactions, id: \.id) { tx in
                        TransactionRowView(transaction: tx)
                    }
                }
            }

            if !inactiveExpenses.isEmpty {
                Section("Inactive") {
                    ForEach(inactiveExpenses, id: \.id) { expense in
                        Button {
                            editingExpense = expense
                        } label: {
                            RecurringExpenseRowView(expense: expense)
                                .opacity(0.5)
                        }
                        .tint(.primary)
                        .swipeActions(edge: .trailing) {
                            Button("Activate") {
                                if !isPremium && activeExpenses.count >= 3 {
                                    showPaywall = true
                                } else {
                                    expense.isActive = true
                                    guard SafeSave.save(modelContext) else {
                                        modelContext.rollback()
                                        return
                                    }
                                }
                            }
                            .tint(BudgetVaultTheme.positive)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}
