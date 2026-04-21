import SwiftUI
import SwiftData
import BudgetVaultShared

/// Recurring Expenses list — VaultRevamp v2.1 Phase 8.3 §7.
///
/// ScrollView of ChamberCard sections with HingeRule(.thin) dividers
/// between rows inside each card. Sections:
///   1. Upcoming  (active expenses, sorted by next due date)
///   2. Recently Posted (last 5 transactions flagged `isRecurring`)
///   3. Inactive (deactivated expenses, rendered at 0.6 opacity as a
///      recessed group)
///
/// Swipe actions retired per §7 trade-off (SwiftUI's ScrollView doesn't
/// support them natively). Active/inactive toggling moves to a
/// contextMenu (long-press) on each row — tap still opens the edit
/// sheet, so the primary interaction is unchanged.
struct RecurringExpenseListView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage(AppStorageKeys.isPremium) private var isPremium = false

    @Query(sort: \RecurringExpense.nextDueDate) private var allExpenses: [RecurringExpense]
    @Query(sort: \Transaction.date, order: .reverse) private var recentTransactions: [Transaction]

    @State private var showForm = false
    @State private var editingExpense: RecurringExpense?
    @State private var showPaywall = false
    @State private var postPurchaseTask: Task<Void, Never>?

    private var activeExpenses: [RecurringExpense] {
        allExpenses.filter { $0.isActive }
    }

    private var inactiveExpenses: [RecurringExpense] {
        allExpenses.filter { !$0.isActive }
    }

    private var recentRecurringTransactions: [Transaction] {
        Array(recentTransactions.filter { $0.isRecurring }.prefix(5))
    }

    var body: some View {
        ZStack {
            BudgetVaultTheme.navyDark.ignoresSafeArea()

            if allExpenses.isEmpty {
                emptyState
            } else {
                expenseScroll
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
                .tint(BudgetVaultTheme.accentSoft)
                .accessibilityLabel("Add recurring expense")
            }
            if !isPremium {
                ToolbarItem(placement: .bottomBar) {
                    Text("\(activeExpenses.count)/3 active")
                        .font(.caption)
                        .foregroundStyle(BudgetVaultTheme.titanium400)
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
                // Audit fix: cancellable Task replaces
                // `DispatchQueue.main.asyncAfter` so the delayed
                // showForm trigger doesn't fire on a dismissed view
                // (which produced "view not in hierarchy" warnings).
                postPurchaseTask?.cancel()
                postPurchaseTask = Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(500))
                    guard !Task.isCancelled else { return }
                    showForm = true
                }
            }
        }
        .onDisappear {
            postPurchaseTask?.cancel()
        }
    }

    // MARK: - Scroll view

    @ViewBuilder
    private var expenseScroll: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BudgetVaultTheme.spacingLG) {
                if !activeExpenses.isEmpty {
                    section(
                        title: "Upcoming",
                        count: activeExpenses.count,
                        content: {
                            ForEach(Array(activeExpenses.enumerated()), id: \.element.id) { index, expense in
                                expenseRow(expense, isLast: index == activeExpenses.count - 1)
                            }
                        }
                    )
                }

                if !recentRecurringTransactions.isEmpty {
                    section(
                        title: "Recently Posted",
                        count: recentRecurringTransactions.count,
                        content: {
                            ForEach(Array(recentRecurringTransactions.enumerated()), id: \.element.id) { index, tx in
                                transactionRow(tx, isLast: index == recentRecurringTransactions.count - 1)
                            }
                        }
                    )
                }

                if !inactiveExpenses.isEmpty {
                    section(
                        title: "Inactive",
                        count: inactiveExpenses.count,
                        content: {
                            ForEach(Array(inactiveExpenses.enumerated()), id: \.element.id) { index, expense in
                                expenseRow(expense, isLast: index == inactiveExpenses.count - 1)
                            }
                        },
                        dimmed: true
                    )
                }
            }
            .padding(.horizontal, BudgetVaultTheme.spacingLG)
            .padding(.top, BudgetVaultTheme.spacingMD)
            .padding(.bottom, BudgetVaultTheme.spacingXL)
        }
    }

    // MARK: - Section builder

    @ViewBuilder
    private func section<Content: View>(
        title: String,
        count: Int,
        @ViewBuilder content: @escaping () -> Content,
        dimmed: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .lastTextBaseline) {
                EngravedSectionHeader(title: title)
                Spacer()
                Text("\(count)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .tracking(1.5)
                    .foregroundStyle(BudgetVaultTheme.titanium500)
                    .padding(.top, 20)
            }

            ChamberCard(padding: 0) {
                VStack(spacing: 0) {
                    content()
                }
            }
            .opacity(dimmed ? 0.6 : 1.0)
        }
    }

    // MARK: - Rows

    @ViewBuilder
    private func expenseRow(_ expense: RecurringExpense, isLast: Bool) -> some View {
        Button {
            editingExpense = expense
        } label: {
            RecurringExpenseRowView(expense: expense)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                editingExpense = expense
            } label: {
                Label("Edit", systemImage: "pencil")
            }

            if expense.isActive {
                Button {
                    expense.isActive = false
                    if !SafeSave.save(modelContext) {
                        modelContext.rollback()
                    }
                } label: {
                    Label("Deactivate", systemImage: "pause.circle")
                }
            } else {
                Button {
                    if !isPremium && activeExpenses.count >= 3 {
                        showPaywall = true
                    } else {
                        expense.isActive = true
                        if !SafeSave.save(modelContext) {
                            modelContext.rollback()
                        }
                    }
                } label: {
                    Label("Activate", systemImage: "play.circle")
                }
            }
        }
        .accessibilityHint("Double tap to edit. Press and hold for more actions.")

        if !isLast {
            HingeRule(weight: .thin)
                .padding(.horizontal, 16)
        }
    }

    @ViewBuilder
    private func transactionRow(_ tx: Transaction, isLast: Bool) -> some View {
        TransactionRowView(transaction: tx)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

        if !isLast {
            HingeRule(weight: .thin)
                .padding(.horizontal, 16)
        }
    }

    // MARK: - Empty state

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: BudgetVaultTheme.spacingLG) {
            Spacer()

            // Titanium bolt-head hero glyph per §7 empty state
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                BudgetVaultTheme.titanium200,
                                BudgetVaultTheme.titanium500,
                                BudgetVaultTheme.titanium800
                            ],
                            center: UnitPoint(x: 0.35, y: 0.30),
                            startRadius: 0,
                            endRadius: 48
                        )
                    )
                    .overlay(
                        Circle()
                            .strokeBorder(BudgetVaultTheme.titanium800, lineWidth: 2)
                    )
                    .frame(width: 88, height: 88)
                    .shadow(color: .black.opacity(0.4), radius: 6, y: 4)

                Image(systemName: "repeat")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(BudgetVaultTheme.titanium900)
            }

            VStack(spacing: 8) {
                Text("No recurring expenses yet")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)

                Text("Add the bills that show up every month — subscriptions, rent, utilities — and BudgetVault will track them automatically.")
                    .font(.system(size: 14))
                    .foregroundStyle(BudgetVaultTheme.titanium400)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, BudgetVaultTheme.spacingXL)
            }

            Button {
                showForm = true
            } label: {
                Label("Add your first", systemImage: "plus")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(14)
            }
            .background(
                LinearGradient(
                    colors: [BudgetVaultTheme.brightBlue, BudgetVaultTheme.electricBlue],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: BudgetVaultTheme.electricBlue.opacity(0.4), radius: 12, y: 4)
            .padding(.horizontal, BudgetVaultTheme.spacingXL)
            .padding(.top, BudgetVaultTheme.spacingSM)

            Spacer()
            Spacer()
        }
        .padding(.horizontal, BudgetVaultTheme.spacingLG)
    }
}
