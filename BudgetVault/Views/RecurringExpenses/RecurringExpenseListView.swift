import SwiftUI
import SwiftData

struct RecurringExpenseListView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("isPremium") private var isPremium = false

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
                    message: "Add bills like Netflix or rent to auto-track them."
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
                                try? modelContext.save()
                            }
                            .tint(.orange)
                        }
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
                                expense.isActive = true
                                try? modelContext.save()
                            }
                            .tint(.green)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}
