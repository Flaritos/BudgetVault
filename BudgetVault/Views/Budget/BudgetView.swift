import SwiftUI
import SwiftData
import TipKit
import BudgetVaultShared

struct BudgetView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage(AppStorageKeys.resetDay) private var resetDay = 1
    @AppStorage(AppStorageKeys.isPremium) private var isPremium = false

    @Query(sort: [SortDescriptor(\Budget.year, order: .reverse), SortDescriptor(\Budget.month, order: .reverse)]) private var allBudgets: [Budget]

    @Environment(\.dismiss) private var dismiss
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
    @State private var cachedSpentMap: [UUID: Int64] = [:]
    @FocusState private var isInputFocused: Bool

    private var viewingBudget: Budget? {
        allBudgets.first { $0.month == viewingMonth && $0.year == viewingYear }
    }

    private var isCurrentPeriod: Bool {
        let (m, y) = DateHelpers.currentBudgetPeriod(resetDay: max(resetDay, 1))
        return viewingMonth == m && viewingYear == y
    }

    private var visibleCategories: [Category] {
        guard let budget = viewingBudget else { return [] }
        return (budget.categories ?? [])
            .filter { !$0.isHidden }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    private var archivedCategories: [Category] {
        guard let budget = viewingBudget else { return [] }
        return (budget.categories ?? []).filter { $0.isHidden }
    }

    private var unallocatedCents: Int64 {
        guard let budget = viewingBudget else { return 0 }
        let allocated = (budget.categories ?? []).filter { !$0.isHidden }.reduce(Int64(0)) { $0 + $1.budgetedAmountCents }
        return budget.totalIncomeCents - allocated
    }

    private var allocationPercentage: Double {
        guard let budget = viewingBudget, budget.totalIncomeCents > 0 else { return 0 }
        let allocated = (budget.categories ?? []).filter { !$0.isHidden }.reduce(Int64(0)) { $0 + $1.budgetedAmountCents }
        return min(Double(allocated) / Double(budget.totalIncomeCents), 1.0)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Compact gradient header with month navigation
                gradientHeader

                // Content
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
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)
            // Audit 2026-04-23 Max Audit P0-9: when presented from
            // Dashboard's `activeSheet = .budgetEditor`, there was no
            // dismiss affordance except the drag indicator — and
            // drag-dismiss on a newly-set budget was easy to miss.
            // Explicit Done button.
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(BudgetVaultTheme.accentSoft)
                }
            }
            .onAppear {
                let (m, y) = DateHelpers.currentBudgetPeriod(resetDay: max(resetDay, 1))
                if viewingMonth == 0 || viewingBudget == nil {
                    viewingMonth = m
                    viewingYear = y
                }
                refreshCachedSpent()
            }
            .onChange(of: viewingMonth) { _, _ in refreshCachedSpent() }
            .onChange(of: viewingYear) { _, _ in refreshCachedSpent() }
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
                if let budget = viewingBudget {
                    MoveMoneyView(categories: visibleCategories, budget: budget)
                        .presentationDragIndicator(.visible)
                }
            }
            .onChange(of: isPremium) { _, newValue in
                if newValue && showPaywall {
                    showPaywall = false
                    Task {
                        try? await Task.sleep(for: .milliseconds(500))
                        showAddCategory = true
                    }
                }
            }
        }
    }

    // MARK: - Compact Gradient Header

    @ViewBuilder
    private var gradientHeader: some View {
        VStack(spacing: 0) {
            HStack {
                // Left: back chevron
                Button {
                    navigateMonthBy(-1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Previous month")
                .frame(width: 44, alignment: .leading)

                Spacer()

                // Center: month title
                VStack(spacing: 2) {
                    Text(DateHelpers.monthYearString(month: viewingMonth, year: viewingYear))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)

                    if !isCurrentPeriod {
                        Button {
                            let (m, y) = DateHelpers.currentBudgetPeriod(resetDay: resetDay)
                            viewingMonth = m
                            viewingYear = y
                        } label: {
                            Text("Back to Today")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.white.opacity(0.85))
                                .underline()
                        }
                    }
                }

                Spacer()

                // Right: actions
                HStack(spacing: 0) {
                    if isCurrentPeriod && visibleCategories.count >= 2 && viewingBudget != nil {
                        Button {
                            showMoveMoney = true
                        } label: {
                            Image(systemName: "arrow.left.arrow.right")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.7))
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .accessibilityLabel("Move money between categories")
                    }

                    Button {
                        showRecurring = true
                    } label: {
                        Image(systemName: "repeat")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.7))
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Recurring expenses")

                    Button {
                        navigateMonthBy(1)
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.white.opacity(isCurrentPeriod ? 0.3 : 1))
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .disabled(isCurrentPeriod)
                    .accessibilityLabel("Next month")
                }
            }
            .padding(.horizontal, BudgetVaultTheme.spacingMD)
            .padding(.bottom, BudgetVaultTheme.spacingSM)
        }
        .padding(.top, BudgetVaultTheme.spacingSM)
        .background {
            LinearGradient(
                colors: [BudgetVaultTheme.navyDark.opacity(0.95), BudgetVaultTheme.navyDark, BudgetVaultTheme.navyMid],
                startPoint: .top,
                endPoint: .bottom
            )
                .ignoresSafeArea(edges: .top)
        }
    }

    // MARK: - Budget Content

    private let moveMoneyTip = MoveMoneyTip()

    @ViewBuilder
    private func budgetContent(budget: Budget) -> some View {
        ScrollView {
            VStack(spacing: BudgetVaultTheme.spacingLG) {
                // Move money tip
                if isCurrentPeriod && visibleCategories.count >= 2 {
                    TipView(moveMoneyTip)
                        .padding(.horizontal)
                }

                // Income summary card — navy gradient, tappable
                incomeCard(budget: budget)

                // Category rows in a white card
                if !visibleCategories.isEmpty {
                    categorySection(budget: budget)
                }

                // Add Envelope button
                if isCurrentPeriod {
                    addEnvelopeButton
                }

                // Archived section
                if !archivedCategories.isEmpty {
                    archivedSection
                }
            }
            .padding(.vertical, BudgetVaultTheme.spacingSM)
        }
    }

    // MARK: - Income Card

    @ViewBuilder
    private func incomeCard(budget: Budget) -> some View {
        Button {
            if isCurrentPeriod {
                incomeText = CurrencyFormatter.formatRaw(cents: budget.totalIncomeCents)
                showIncomeEditor = true
            }
        } label: {
            VStack(spacing: BudgetVaultTheme.spacingSM) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Monthly Income")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                            .textCase(.uppercase)
                            .tracking(0.5)
                        Text(CurrencyFormatter.format(cents: budget.totalIncomeCents))
                            .font(BudgetVaultTheme.cardAmount)
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Unallocated")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                        Text(CurrencyFormatter.format(cents: unallocatedCents))
                            .font(.subheadline.bold())
                            .foregroundStyle(unallocatedCents >= 0 ? BudgetVaultTheme.positive : BudgetVaultTheme.negative)
                    }
                }

                // Allocation progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(.white.opacity(0.15))
                            .frame(height: 6)

                        RoundedRectangle(cornerRadius: 3)
                            .fill(allocationPercentage >= 1.0 ? BudgetVaultTheme.positive : .white.opacity(0.6))
                            .frame(width: max(0, geo.size.width * allocationPercentage), height: 6)
                    }
                }
                .frame(height: 6)

                HStack {
                    Text("\(Int(allocationPercentage * 100))% allocated")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.5))
                    Spacer()
                    if isCurrentPeriod {
                        HStack(spacing: 2) {
                            Text("Edit")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.5))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.3))
                                .accessibilityHidden(true)
                        }
                    }
                }
            }
            .padding(BudgetVaultTheme.spacingLG)
            .background(
                BudgetVaultTheme.brandGradient,
                in: RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusLG)
            )
        }
        .buttonStyle(.plain)
        .disabled(!isCurrentPeriod)
        .padding(.horizontal)
        .accessibilityLabel("Monthly Income: \(CurrencyFormatter.format(cents: budget.totalIncomeCents)), Unallocated: \(CurrencyFormatter.format(cents: unallocatedCents)), tap to edit")
    }

    // MARK: - Category Section

    @ViewBuilder
    private func categorySection(budget: Budget) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(visibleCategories.enumerated()), id: \.element.id) { index, category in
                VStack(spacing: 0) {
                    NavigationLink {
                        CategoryDetailView(category: category, budget: budget)
                    } label: {
                        categoryRow(category: category, budget: budget)
                    }
                    .buttonStyle(.plain)

                    // Rollover toggle
                    if isCurrentPeriod {
                        rolloverToggle(category: category)
                            .padding(.horizontal, BudgetVaultTheme.spacingLG)
                            .padding(.bottom, BudgetVaultTheme.spacingSM)
                    }

                    if index < visibleCategories.count - 1 {
                        Divider()
                            .padding(.leading, BudgetVaultTheme.spacingLG + 4 + BudgetVaultTheme.spacingSM)
                    }
                }
                .swipeActions(edge: .trailing) {
                    if isCurrentPeriod {
                        Button("Archive") {
                            category.isHidden = true
                            guard SafeSave.save(modelContext) else {
                                category.isHidden = false
                                return
                            }
                        }
                        .tint(BudgetVaultTheme.caution)
                    }
                }
                .accessibilityHint(isCurrentPeriod ? "Swipe left to archive" : "")
            }
            .onMove { from, to in
                guard isCurrentPeriod else { return }
                moveCategories(from: from, to: to)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusLG)
                .fill(BudgetVaultTheme.cardBackground)
                .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
        )
        .padding(.horizontal)
    }

    // MARK: - Category Row

    @ViewBuilder
    private func categoryRow(category: Category, budget: Budget) -> some View {
        let spent = cachedSpentMap[category.id] ?? category.spentCents(in: budget)
        let budgetedAmt = category.budgetedAmountCents
        let pct = budgetedAmt > 0 ? Double(spent) / Double(budgetedAmt) : 0

        HStack(spacing: BudgetVaultTheme.spacingSM) {
            // Color bar on left
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(hex: category.color))
                .frame(width: 4, height: 44)

            // Emoji
            Text(category.emoji)
                .font(.title3)

            // Name + subtitle
            VStack(alignment: .leading, spacing: 2) {
                Text(category.name)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)

                HStack(spacing: 4) {
                    Text(CurrencyFormatter.format(cents: spent))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if budgetedAmt > 0 {
                        Text("\u{00B7} \(Int(min(pct, 9.99) * 100))%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            // Warning indicator for >80%
            if pct > 0.9 {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(BudgetVaultTheme.negative)
                    .accessibilityLabel("Over budget")
            } else if pct > 0.8 {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(BudgetVaultTheme.caution)
                    .accessibilityLabel("Near budget limit")
            }

            // Budgeted amount (tappable to edit)
            Button {
                if isCurrentPeriod {
                    categoryAmountText = CurrencyFormatter.formatRaw(cents: category.budgetedAmountCents)
                    editingCategoryAmount = category
                }
            } label: {
                Text(CurrencyFormatter.format(cents: category.budgetedAmountCents))
                    .font(BudgetVaultTheme.rowAmount)
                    .foregroundStyle(isCurrentPeriod ? Color.accentColor : .secondary)
            }
            .disabled(!isCurrentPeriod)
            .accessibilityLabel("Edit \(category.name) budget: \(CurrencyFormatter.format(cents: category.budgetedAmountCents))")

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.quaternary)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, BudgetVaultTheme.spacingLG)
        .padding(.vertical, BudgetVaultTheme.spacingSM)
        .accessibilityValue("\(Int(min(pct, 1.0) * 100)) percent spent")
    }

    // MARK: - Rollover Toggle

    @ViewBuilder
    private func rolloverToggle(category: Category) -> some View {
        if isPremium {
            Toggle("Roll over unspent", isOn: Binding(
                get: { category.rollOverUnspent },
                set: { newVal in
                    let oldVal = category.rollOverUnspent
                    category.rollOverUnspent = newVal
                    if !SafeSave.save(modelContext) {
                        category.rollOverUnspent = oldVal
                        modelContext.rollback()
                    }
                }
            ))
            .toggleStyle(.switch)
            .font(.caption)
            .foregroundStyle(.secondary)
        } else {
            Button {
                showPaywall = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.forward.circle")
                        .font(.caption)
                        .accessibilityHidden(true)
                    Text("Roll over unspent")
                        .font(.caption)
                    Spacer()
                    Image(systemName: "lock.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
                .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Add Envelope Button

    private var addEnvelopeButton: some View {
        Button {
            let count = visibleCategories.count
            if !isPremium && count >= 6 {
                showPaywall = true
            } else {
                showAddCategory = true
            }
        } label: {
            HStack {
                Image(systemName: "plus")
                    .font(.body.weight(.medium))
                Text("Add Envelope")
                    .font(.subheadline.weight(.medium))
                if !isPremium {
                    Spacer()
                    Text("\(visibleCategories.count)/6")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .foregroundStyle(Color.accentColor)
            .padding(BudgetVaultTheme.spacingMD)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusLG)
                    .strokeBorder(Color.accentColor.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
            )
        }
        .padding(.horizontal)
    }

    // MARK: - Archived Section

    private var archivedSection: some View {
        VStack(spacing: 0) {
            DisclosureGroup(isExpanded: $showArchived) {
                ForEach(archivedCategories, id: \.id) { category in
                    HStack {
                        Text("\(category.emoji) \(category.name)")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(CurrencyFormatter.format(cents: category.budgetedAmountCents))
                            .foregroundStyle(.secondary)

                        if isCurrentPeriod {
                            Button("Restore") {
                                if !isPremium && visibleCategories.count >= 6 {
                                    showPaywall = true
                                } else {
                                    category.isHidden = false
                                    guard SafeSave.save(modelContext) else {
                                        category.isHidden = true
                                        return
                                    }
                                }
                            }
                            .font(.caption)
                            .buttonStyle(.bordered)
                            .controlSize(.mini)
                            .tint(Color.accentColor)
                        }
                    }
                    .padding(.vertical, BudgetVaultTheme.spacingXS)
                }
            } label: {
                Text("Archived (\(archivedCategories.count))")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .padding(BudgetVaultTheme.spacingLG)
        }
        .background(
            RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusLG)
                .fill(BudgetVaultTheme.cardBackground)
                .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
        )
        .padding(.horizontal)
    }

    // MARK: - Income Editor Sheet

    private var incomeEditorSheet: some View {
        NavigationStack {
            VStack(spacing: BudgetVaultTheme.spacingXL) {
                Text(CurrencyFormatter.displayAmount(text: incomeText))
                    .font(BudgetVaultTheme.amountEntry)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .dynamicTypeSize(...DynamicTypeSize.accessibility3)
                    .padding(.top, BudgetVaultTheme.spacing2XL)

                QuietKeypad(text: $incomeText)
                    .padding(.horizontal, BudgetVaultTheme.spacingXL)

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
                            let oldIncome = budget.totalIncomeCents
                            budget.totalIncomeCents = cents
                            if !SafeSave.save(modelContext) {
                                budget.totalIncomeCents = oldIncome
                                modelContext.rollback()
                            }
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
                VStack(spacing: BudgetVaultTheme.spacingXL) {
                    Text("\(category.emoji) \(category.name)")
                        .font(.headline)
                        .padding(.top, BudgetVaultTheme.spacingLG)

                    Text(CurrencyFormatter.displayAmount(text: categoryAmountText))
                        .font(BudgetVaultTheme.amountEntry)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .dynamicTypeSize(...DynamicTypeSize.accessibility3)

                    QuietKeypad(text: $categoryAmountText)
                        .padding(.horizontal, BudgetVaultTheme.spacingXL)

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
                                .focused($isInputFocused)
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
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { isInputFocused = false }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { editingCategoryAmount = nil }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let oldBudgeted = category.budgetedAmountCents
                        let oldGoalType = category.goalType
                        let oldGoalAmount = category.goalAmountCents
                        let oldGoalDate = category.goalDate
                        let oldRollOver = category.rollOverUnspent

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
                        if !SafeSave.save(modelContext) {
                            category.budgetedAmountCents = oldBudgeted
                            category.goalType = oldGoalType
                            category.goalAmountCents = oldGoalAmount
                            category.goalDate = oldGoalDate
                            category.rollOverUnspent = oldRollOver
                            modelContext.rollback()
                        }
                        editingCategoryAmount = nil
                    }
                }
            }
            .onAppear {
                // Reset all state to the editing category's values to prevent leaks between sheets
                categoryAmountText = CurrencyFormatter.formatRaw(cents: category.budgetedAmountCents)
                isSavingsGoal = category.goalType == "savings"
                if let goal = category.goalAmountCents {
                    goalAmountText = CurrencyFormatter.formatRaw(cents: goal)
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

    private func navigateMonthBy(_ delta: Int) {
        let (m, y) = DateHelpers.navigateMonth(from: viewingMonth, year: viewingYear, delta: delta)
        viewingMonth = m
        viewingYear = y
    }

    private func moveCategories(from source: IndexSet, to destination: Int) {
        var cats = visibleCategories
        let oldOrders = cats.map { $0.sortOrder }
        cats.move(fromOffsets: source, toOffset: destination)
        for (i, cat) in cats.enumerated() {
            cat.sortOrder = i
        }
        if !SafeSave.save(modelContext) {
            // Restore original sort orders
            let original = visibleCategories
            for (i, cat) in original.enumerated() where i < oldOrders.count {
                cat.sortOrder = oldOrders[i]
            }
            modelContext.rollback()
        }
    }

    /// Pre-compute spent values for all categories (0.1 performance fix)
    private func refreshCachedSpent() {
        guard let budget = viewingBudget else {
            cachedSpentMap = [:]
            return
        }
        var map: [UUID: Int64] = [:]
        for cat in budget.categories ?? [] {
            map[cat.id] = cat.spentCents(in: budget)
        }
        cachedSpentMap = map
    }
}
