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
        ZStack {
            BudgetVaultTheme.navyDark.ignoresSafeArea()

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
        }
        .navigationTitle("Recurring Expenses")
        .toolbarBackground(BudgetVaultTheme.navyDark, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
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
                Section {
                    ForEach(activeExpenses, id: \.id) { expense in
                        Button {
                            editingExpense = expense
                        } label: {
                            chamberRow(RecurringExpenseRowView(expense: expense))
                        }
                        .tint(.primary)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 4, leading: BudgetVaultTheme.spacingLG, bottom: 4, trailing: BudgetVaultTheme.spacingLG))
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
                } header: {
                    engravedSectionHeader("UPCOMING")
                }
            }

            if !recentRecurringTransactions.isEmpty {
                Section {
                    ForEach(recentRecurringTransactions, id: \.id) { tx in
                        chamberRow(TransactionRowView(transaction: tx))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 4, leading: BudgetVaultTheme.spacingLG, bottom: 4, trailing: BudgetVaultTheme.spacingLG))
                    }
                } header: {
                    engravedSectionHeader("RECENTLY POSTED")
                }
            }

            if !inactiveExpenses.isEmpty {
                Section {
                    ForEach(inactiveExpenses, id: \.id) { expense in
                        Button {
                            editingExpense = expense
                        } label: {
                            chamberRow(RecurringExpenseRowView(expense: expense))
                                .opacity(0.6)
                        }
                        .tint(.primary)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 4, leading: BudgetVaultTheme.spacingLG, bottom: 4, trailing: BudgetVaultTheme.spacingLG))
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
                } header: {
                    engravedSectionHeader("INACTIVE")
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(BudgetVaultTheme.navyDark)
    }

    /// Wraps any row content in a chamber-surface background so the
    /// preserved List swipe-actions still live inside navy/titanium
    /// chrome instead of default iOS grouped rows.
    @ViewBuilder
    private func chamberRow<Content: View>(_ content: Content) -> some View {
        content
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(BudgetVaultTheme.chamberBackground, in: RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(BudgetVaultTheme.titanium700.opacity(0.3), lineWidth: 1)
            )
    }

    private func engravedSectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold))
            .tracking(2.0)
            .foregroundStyle(BudgetVaultTheme.titanium300)
            .padding(.top, BudgetVaultTheme.spacingMD)
            .padding(.bottom, BudgetVaultTheme.spacingXS)
            .listRowInsets(EdgeInsets(top: 0, leading: BudgetVaultTheme.spacingLG, bottom: 0, trailing: BudgetVaultTheme.spacingLG))
    }
}
