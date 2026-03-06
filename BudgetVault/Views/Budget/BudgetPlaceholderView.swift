import SwiftUI
import SwiftData

struct BudgetPlaceholderView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("resetDay") private var resetDay = 1
    @AppStorage("isPremium") private var isPremium = false

    @Query(sort: \Budget.year, order: .reverse) private var allBudgets: [Budget]

    @State private var viewingMonth: Int = 0
    @State private var viewingYear: Int = 0
    @State private var showIncomeEditor = false
    @State private var incomeText = ""
    @State private var showAddCategory = false
    @State private var showPaywall = false
    @State private var editingCategoryAmount: Category?
    @State private var categoryAmountText = ""
    @State private var showArchived = false
    @State private var showRecurring = false
    @State private var showMoveMoney = false
    @State private var goalAmountText = ""
    @State private var goalDate = Date()
    @State private var isSavingsGoal = false

    private var viewingBudget: Budget? {
        allBudgets.first { $0.month == viewingMonth && $0.year == viewingYear }
    }

    private var isCurrentPeriod: Bool {
        let (m, y) = DateHelpers.currentBudgetPeriod(resetDay: resetDay)
        return viewingMonth == m && viewingYear == y
    }

    private var visibleCategories: [Category] {
        guard let budget = viewingBudget else { return [] }
        return budget.categories
            .filter { !$0.isHidden }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    private var archivedCategories: [Category] {
        guard let budget = viewingBudget else { return [] }
        return budget.categories.filter { $0.isHidden }
    }

    private var unallocatedCents: Int64 {
        guard let budget = viewingBudget else { return 0 }
        let allocated = budget.categories.filter { !$0.isHidden }.reduce(Int64(0)) { $0 + $1.budgetedAmountCents }
        return budget.totalIncomeCents - allocated
    }

    var body: some View {
        NavigationStack {
            Group {
                if let budget = viewingBudget {
                    budgetContent(budget: budget)
                } else {
                    EmptyStateView(
                        icon: "calendar.badge.exclamationmark",
                        title: "No Budget",
                        message: "No budget found for this period."
                    )
                }
            }
            .navigationTitle(DateHelpers.monthYearString(month: viewingMonth, year: viewingYear))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        navigateMonth(-1)
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .accessibilityLabel("Previous month")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        if isCurrentPeriod && visibleCategories.count >= 2 {
                            Button {
                                showMoveMoney = true
                            } label: {
                                Image(systemName: "arrow.left.arrow.right")
                            }
                            .accessibilityLabel("Move money between categories")
                        }

                        Button {
                            showRecurring = true
                        } label: {
                            Image(systemName: "repeat")
                        }
                        .accessibilityLabel("Recurring expenses")

                        if isCurrentPeriod {
                            Button {
                                navigateMonth(1)
                            } label: {
                                Image(systemName: "chevron.right")
                            }
                            .disabled(true)
                            .accessibilityLabel("Next month")
                        } else {
                            Button {
                                navigateMonth(1)
                            } label: {
                                Image(systemName: "chevron.right")
                            }
                            .accessibilityLabel("Next month")
                        }
                    }
                }
            }
            .onAppear {
                if viewingMonth == 0 {
                    let (m, y) = DateHelpers.currentBudgetPeriod(resetDay: resetDay)
                    viewingMonth = m
                    viewingYear = y
                }
            }
            .sheet(isPresented: $showIncomeEditor) {
                incomeEditorSheet
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showAddCategory) {
                if let budget = viewingBudget {
                    AddCategoryView(budget: budget)
                        .presentationDragIndicator(.visible)
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showRecurring) {
                NavigationStack {
                    RecurringExpenseListView()
                }
                .presentationDragIndicator(.visible)
            }
            .sheet(item: $editingCategoryAmount) { category in
                categoryAmountSheet(category: category)
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showMoveMoney) {
                MoveMoneyView(categories: visibleCategories)
                    .presentationDragIndicator(.visible)
            }
        }
    }

    // MARK: - Budget Content

    @ViewBuilder
    private func budgetContent(budget: Budget) -> some View {
        List {
            // Income section
            Section {
                Button {
                    if isCurrentPeriod {
                        incomeText = formatCentsToString(budget.totalIncomeCents)
                        showIncomeEditor = true
                    }
                } label: {
                    HStack {
                        Text("Monthly Income")
                        Spacer()
                        Text(CurrencyFormatter.format(cents: budget.totalIncomeCents))
                            .foregroundStyle(.secondary)
                        if isCurrentPeriod {
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .tint(.primary)
                .disabled(!isCurrentPeriod)

                // Unallocated
                HStack {
                    Text("Unallocated")
                        .font(.subheadline)
                    Spacer()
                    Text(CurrencyFormatter.format(cents: unallocatedCents))
                        .font(.subheadline.bold())
                        .foregroundStyle(unallocatedCents >= 0 ? .green : .red)
                }
                .accessibilityLabel("Unallocated: \(CurrencyFormatter.format(cents: unallocatedCents)), \(unallocatedCents >= 0 ? "positive" : "negative")")
            }

            // Categories
            Section("Categories") {
                ForEach(visibleCategories, id: \.id) { category in
                    categoryRow(category: category, budget: budget)
                }
                .onMove { from, to in
                    guard isCurrentPeriod else { return }
                    moveCategories(from: from, to: to)
                }

                if isCurrentPeriod {
                    Button {
                        let count = visibleCategories.count
                        if !isPremium && count >= 4 {
                            showPaywall = true
                        } else {
                            showAddCategory = true
                        }
                    } label: {
                        Label("Add Category", systemImage: "plus.circle")
                    }
                }
            }

            // Archived
            if !archivedCategories.isEmpty {
                Section {
                    DisclosureGroup("Archived (\(archivedCategories.count))", isExpanded: $showArchived) {
                        ForEach(archivedCategories, id: \.id) { category in
                            HStack {
                                Text("\(category.emoji) \(category.name)")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(CurrencyFormatter.format(cents: category.budgetedAmountCents))
                                    .foregroundStyle(.secondary)
                            }
                            .swipeActions(edge: .trailing) {
                                if isCurrentPeriod {
                                    Button("Restore") {
                                        category.isHidden = false
                                        SafeSave.save(modelContext)
                                    }
                                    .tint(.blue)
                                }
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .environment(\.editMode, isCurrentPeriod ? .constant(.active) : .constant(.inactive))
    }

    // MARK: - Category Row

    @ViewBuilder
    private func categoryRow(category: Category, budget: Budget) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text("\(category.emoji) \(category.name)")
                    .font(.body)
                Spacer()
                Button {
                    if isCurrentPeriod {
                        categoryAmountText = formatCentsToString(category.budgetedAmountCents)
                        editingCategoryAmount = category
                    }
                } label: {
                    Text(CurrencyFormatter.format(cents: category.budgetedAmountCents))
                        .foregroundStyle(isCurrentPeriod ? Color.accentColor : .secondary)
                }
                .disabled(!isCurrentPeriod)
            }

            // Spent progress
            let spent = category.spentCents(in: budget)
            let pct = category.percentSpent(in: budget)
            HStack {
                ProgressView(value: min(pct, 1.0))
                    .tint(pct > 0.9 ? .red : pct > 0.75 ? .yellow : .green)
                Text(CurrencyFormatter.format(cents: spent))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Roll over toggle
            if isCurrentPeriod {
                Toggle("Roll over unspent", isOn: Binding(
                    get: { category.rollOverUnspent },
                    set: { newVal in
                        category.rollOverUnspent = newVal
                        SafeSave.save(modelContext)
                    }
                ))
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .swipeActions(edge: .trailing) {
            if isCurrentPeriod {
                Button("Archive") {
                    category.isHidden = true
                    SafeSave.save(modelContext)
                }
                .tint(.orange)
            }
        }
    }

    // MARK: - Income Editor Sheet

    private var incomeEditorSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text(displayAmount(incomeText))
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .padding(.top, 32)

                NumberPadView(text: $incomeText)
                    .padding(.horizontal, 24)

                Spacer()
            }
            .navigationTitle("Monthly Income")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showIncomeEditor = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let cents = MoneyHelpers.parseCurrencyString(incomeText), let budget = viewingBudget {
                            budget.totalIncomeCents = cents
                            SafeSave.save(modelContext)
                        }
                        showIncomeEditor = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Category Amount Sheet

    private func categoryAmountSheet(category: Category) -> some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Text("\(category.emoji) \(category.name)")
                        .font(.headline)
                        .padding(.top, 16)

                    Text(displayAmount(categoryAmountText))
                        .font(.system(size: 48, weight: .bold, design: .rounded))

                    NumberPadView(text: $categoryAmountText)
                        .padding(.horizontal, 24)

                    Divider()
                        .padding(.horizontal)

                    Toggle("Savings Goal", isOn: $isSavingsGoal)
                        .font(.subheadline)
                        .padding(.horizontal)

                    if isSavingsGoal {
                        HStack {
                            Text("Target: \(CurrencyFormatter.currencySymbol())")
                                .font(.subheadline)
                            TextField("0", text: $goalAmountText)
                                .keyboardType(.decimalPad)
                                .font(.subheadline)
                        }
                        .padding(.horizontal)

                        DatePicker("Target Date", selection: $goalDate, displayedComponents: .date)
                            .font(.subheadline)
                            .padding(.horizontal)
                    }
                }
            }
            .navigationTitle("Category Budget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { editingCategoryAmount = nil }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let cents = MoneyHelpers.parseCurrencyString(categoryAmountText) {
                            category.budgetedAmountCents = cents
                        }
                        if isSavingsGoal {
                            category.goalType = "savings"
                            category.goalAmountCents = MoneyHelpers.parseCurrencyString(goalAmountText)
                            category.goalDate = goalDate
                            category.rollOverUnspent = true
                        } else {
                            category.goalType = nil
                            category.goalAmountCents = nil
                            category.goalDate = nil
                        }
                        SafeSave.save(modelContext)
                        editingCategoryAmount = nil
                    }
                }
            }
            .onAppear {
                isSavingsGoal = category.goalType == "savings"
                if let goal = category.goalAmountCents {
                    goalAmountText = String(goal / 100)
                } else {
                    goalAmountText = ""
                }
                if let date = category.goalDate {
                    goalDate = date
                } else {
                    goalDate = Date()
                }
            }
        }
        .presentationDetents([.large])
    }

    // MARK: - Helpers

    private func navigateMonth(_ delta: Int) {
        if delta > 0 {
            let (m, y) = DateHelpers.nextMonth(from: viewingMonth, year: viewingYear)
            viewingMonth = m
            viewingYear = y
        } else {
            let (m, y) = DateHelpers.previousMonth(from: viewingMonth, year: viewingYear)
            viewingMonth = m
            viewingYear = y
        }
    }

    private func moveCategories(from source: IndexSet, to destination: Int) {
        var cats = visibleCategories
        cats.move(fromOffsets: source, toOffset: destination)
        for (i, cat) in cats.enumerated() {
            cat.sortOrder = i
        }
        SafeSave.save(modelContext)
    }

    private func displayAmount(_ text: String) -> String {
        let symbol = CurrencyFormatter.currencySymbol()
        if text.isEmpty { return "\(symbol)0" }
        return "\(symbol)\(text)"
    }

    private func formatCentsToString(_ cents: Int64) -> String {
        let dollars = cents / 100
        let remainder = cents % 100
        if remainder == 0 { return "\(dollars)" }
        return String(format: "%d.%02d", dollars, remainder)
    }
}
