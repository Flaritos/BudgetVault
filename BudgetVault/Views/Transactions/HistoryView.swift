import SwiftUI
import SwiftData
import TipKit

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(AppStorageKeys.resetDay) private var resetDay = 1

    @Query(sort: [SortDescriptor(\Budget.year, order: .reverse), SortDescriptor(\Budget.month, order: .reverse)]) private var allBudgets: [Budget]
    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]

    @State private var searchText = ""
    @State private var filterMode: FilterMode = .all
    @State private var selectedCategoryID: UUID?
    @State private var editingTransaction: Transaction?
    @State private var viewingMonth: Int = 0
    @State private var viewingYear: Int = 0
    @State private var csvExportText: String?
    @State private var displayLimit = 50
    @State private var sortMode: SortMode = .date
    @State private var transactionToDelete: Transaction?
    @State private var showDeleteConfirmation = false

    // MARK: - Cached Filter State
    @State private var cachedFilteredTransactions: [Transaction] = []
    @State private var cachedGroupedByDay: [(date: Date, transactions: [Transaction])] = []
    @State private var totalSpent: Int64 = 0
    @State private var totalIncome: Int64 = 0

    enum FilterMode: String, CaseIterable {
        case all = "All"
        case expenses = "Expenses"
        case income = "Income"
    }

    enum SortMode: String, CaseIterable {
        case date = "Date"
        case amount = "Amount"
        case category = "Category"
    }

    private var currentBudget: Budget? {
        return allBudgets.first { $0.month == viewingMonth && $0.year == viewingYear }
    }

    private var isCurrentPeriod: Bool {
        let (m, y) = DateHelpers.currentBudgetPeriod(resetDay: resetDay)
        return viewingMonth == m && viewingYear == y
    }

    private var categories: [Category] {
        (currentBudget?.categories ?? []).filter { !$0.isHidden }.sorted { $0.sortOrder < $1.sortOrder }
    }

    // MARK: - Cached computed helpers

    private var filteredTransactions: [Transaction] {
        Array(cachedFilteredTransactions.prefix(displayLimit))
    }

    private var hasMoreTransactions: Bool {
        cachedFilteredTransactions.count > displayLimit
    }

    // MARK: - Period summary (cached in recomputeFilteredTransactions)

    // MARK: - Static DateFormatter

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("EEEMMMd")
        return f
    }()

    // MARK: - Recompute

    private func recomputeFilteredTransactions() {
        guard let budget = currentBudget else {
            cachedFilteredTransactions = []
            cachedGroupedByDay = []
            totalSpent = 0
            totalIncome = 0
            return
        }

        var transactions = allTransactions
            .filter { $0.date >= budget.periodStart && $0.date < budget.nextPeriodStart }

        switch filterMode {
        case .all: break
        case .expenses: transactions = transactions.filter { !$0.isIncome }
        case .income: transactions = transactions.filter { $0.isIncome }
        }

        if let catID = selectedCategoryID {
            transactions = transactions.filter { $0.category?.id == catID }
        }

        if !searchText.isEmpty {
            transactions = transactions.filter {
                $0.note.localizedCaseInsensitiveContains(searchText) ||
                ($0.category?.name.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }

        switch sortMode {
        case .date:
            transactions.sort { $0.date > $1.date }
        case .amount:
            transactions.sort { $0.amountCents > $1.amountCents }
        case .category:
            transactions.sort {
                ($0.category?.name ?? "") < ($1.category?.name ?? "")
            }
        }

        cachedFilteredTransactions = transactions
        totalSpent = transactions.filter { !$0.isIncome }.reduce(Int64(0)) { $0 + $1.amountCents }
        totalIncome = transactions.filter { $0.isIncome }.reduce(Int64(0)) { $0 + $1.amountCents }
        recomputeGroupedByDay()
    }

    private func recomputeGroupedByDay() {
        let calendar = Calendar.current
        let paginated = Array(cachedFilteredTransactions.prefix(displayLimit))
        let grouped = Dictionary(grouping: paginated) { tx in
            calendar.startOfDay(for: tx.date)
        }
        cachedGroupedByDay = grouped.sorted { $0.key > $1.key }
            .map { (date: $0.key, transactions: $0.value.sorted { $0.date > $1.date }) }
    }

    // MARK: - CSV

    private func generateCSV() -> String {
        var lines = ["Date,Category,Note,Amount,Currency,Type"]
        for tx in cachedFilteredTransactions.sorted(by: { $0.date < $1.date }) {
            let dateStr = tx.date.formatted(date: .numeric, time: .omitted)
            let cat = Self.csvEscape(tx.category?.name ?? "")
            let note = Self.csvEscape(tx.note)
            let amount = String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), Double(tx.amountCents) / 100.0)
            let currency = Locale.current.currency?.identifier ?? "USD"
            let type = tx.isIncome ? "Income" : "Expense"
            lines.append("\(dateStr),\(cat),\(note),\(amount),\(currency),\(type)")
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Compact gradient header
                gradientHeader

                // Content
                Group {
                    if cachedFilteredTransactions.isEmpty && searchText.isEmpty && filterMode == .all && selectedCategoryID == nil {
                        vaultEmptyState
                    } else if cachedFilteredTransactions.isEmpty && !searchText.isEmpty {
                        ContentUnavailableView.search(text: searchText)
                    } else if cachedFilteredTransactions.isEmpty {
                        EmptyStateView(
                            icon: "line.3.horizontal.decrease",
                            title: "No Matches",
                            message: "No transactions match your current filters. Try changing your filters."
                        )
                    } else {
                        transactionList
                    }
                }
            }
            // v3.2 audit K4: show an opaque navy toolbar so the system
            // .searchable field has a visible frosted background instead
            // of dark-on-dark invisibility. Also force dark color scheme
            // so the placeholder text is readable.
            .toolbarBackground(BudgetVaultTheme.navyDark, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search notes or categories")
            .onAppear {
                if viewingMonth == 0 {
                    let (m, y) = DateHelpers.currentBudgetPeriod(resetDay: resetDay)
                    viewingMonth = m
                    viewingYear = y
                }
                recomputeFilteredTransactions()
            }
            .sheet(item: $editingTransaction, onDismiss: {
                recomputeFilteredTransactions()
            }) { transaction in
                if let budget = currentBudget {
                    TransactionEditView(transaction: transaction, budget: budget, categories: categories)
                }
            }
            .onChange(of: filterMode) { _, newMode in
                if newMode == .income {
                    selectedCategoryID = nil
                }
                displayLimit = 50
                HapticManager.selection()
                recomputeFilteredTransactions()
            }
            .onChange(of: selectedCategoryID) { _, _ in
                displayLimit = 50
                recomputeFilteredTransactions()
            }
            .onChange(of: searchText) { _, _ in
                recomputeFilteredTransactions()
            }
            .onChange(of: sortMode) { _, _ in
                recomputeFilteredTransactions()
            }
            .onChange(of: viewingMonth) { _, _ in
                recomputeFilteredTransactions()
            }
            .onChange(of: viewingYear) { _, _ in
                recomputeFilteredTransactions()
            }
            .onChange(of: allTransactions.count) { _, _ in
                recomputeFilteredTransactions()
            }
            .onChange(of: displayLimit) { _, _ in
                recomputeGroupedByDay()
            }
            .tint(BudgetVaultTheme.electricBlue)
            .sheet(isPresented: Binding(
                get: { csvExportText != nil },
                set: { if !$0 { csvExportText = nil } }
            )) {
                if let csv = csvExportText {
                    NavigationStack {
                        ShareLink(item: csv, preview: SharePreview("Transactions.csv")) {
                            Label("Share CSV", systemImage: "square.and.arrow.up")
                        }
                        .padding()
                    }
                    .presentationDetents([.medium])
                }
            }
            .confirmationDialog(
                deleteConfirmationTitle,
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let tx = transactionToDelete {
                        modelContext.delete(tx)
                        guard SafeSave.save(modelContext) else {
                            modelContext.rollback()
                            transactionToDelete = nil
                            return
                        }
                        HapticManager.notification(.warning)
                        transactionToDelete = nil
                    }
                }
            } message: {
                if let tx = transactionToDelete {
                    Text("\(CurrencyFormatter.format(cents: tx.amountCents)) \u{2022} \(tx.note.isEmpty ? "No note" : tx.note)\n\(tx.date.formatted(date: .abbreviated, time: .omitted))\n\(tx.category?.name ?? "Income")")
                }
            }
        }
    }

    // MARK: - Compact Gradient Header

    @ViewBuilder
    private var gradientHeader: some View {
        VStack(spacing: 0) {
            HStack {
                // Left: back chevron with 44pt tap target
                Button {
                    navigateMonth(-1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Previous month")
                .frame(width: 88, alignment: .leading)

                Spacer()

                // Center: month title + optional "Back to Today"
                VStack(spacing: 2) {
                    Text(DateHelpers.monthYearString(month: viewingMonth, year: viewingYear))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)

                    if !isCurrentPeriod {
                        Button {
                            if reduceMotion {
                                let (m, y) = DateHelpers.currentBudgetPeriod(resetDay: resetDay)
                                viewingMonth = m
                                viewingYear = y
                                displayLimit = 50
                            } else {
                                withAnimation(.easeInOut(duration: BudgetVaultTheme.animationStandard)) {
                                    let (m, y) = DateHelpers.currentBudgetPeriod(resetDay: resetDay)
                                    viewingMonth = m
                                    viewingYear = y
                                    displayLimit = 50
                                }
                            }
                        } label: {
                            Text("Back to Today")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.white.opacity(0.85))
                                .underline()
                        }
                    }
                }

                Spacer()

                // Right: forward chevron + overflow menu
                HStack(spacing: 0) {
                    Button {
                        navigateMonth(1)
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.white.opacity(isCurrentPeriod ? 0.3 : 1))
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .disabled(isCurrentPeriod)
                    .accessibilityLabel("Next month")

                    Menu {
                        Section("Sort By") {
                            ForEach(SortMode.allCases, id: \.self) { mode in
                                Button {
                                    sortMode = mode
                                } label: {
                                    HStack {
                                        Text(mode.rawValue)
                                        if sortMode == mode {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        }

                        Section {
                            Button {
                                csvExportText = generateCSV()
                            } label: {
                                Label("Export CSV", systemImage: "square.and.arrow.up")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.7))
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("More options")
                }
                .frame(width: 88, alignment: .trailing)
            }
            .padding(.horizontal, BudgetVaultTheme.spacingMD)
            .padding(.bottom, BudgetVaultTheme.spacingSM)
        }
        .padding(.top, BudgetVaultTheme.spacingSM)
        // v3.2 audit H1: replaced royal-blue brandGradient (which clashed
        // with the rest of the app and made the search field unreadable)
        // with the same navy gradient used on Home's hero.
        .background {
            LinearGradient(
                colors: [BudgetVaultTheme.navyDark.opacity(0.95), BudgetVaultTheme.navyDark, BudgetVaultTheme.navyMid],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .top)
        }
    }

    // MARK: - Summary Card

    @ViewBuilder
    private var summaryCard: some View {
        HStack {
            VStack(spacing: 2) {
                Text("Spent")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                // v3.2 audit H2: neutral navy for normal spend totals;
                // red (BudgetVaultTheme.negative) is reserved for overspend.
                Text(CurrencyFormatter.format(cents: totalSpent))
                    .font(.system(.callout, design: .rounded).weight(.bold))
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)

            Divider().frame(height: 28)

            VStack(spacing: 2) {
                Text("Income")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                // v3.2 audit: only tint income green when there's actually income.
                Text(CurrencyFormatter.format(cents: totalIncome))
                    .font(.system(.callout, design: .rounded).weight(.bold))
                    .foregroundStyle(totalIncome > 0 ? BudgetVaultTheme.positive : Color.primary)
            }
            .frame(maxWidth: .infinity)

            Divider().frame(height: 28)

            VStack(spacing: 2) {
                // v3.2 audit L13: "COUNT" reads spreadsheet-y. "Entries" is warmer.
                Text("Entries")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                Text("\(cachedFilteredTransactions.count)")
                    .font(.system(.callout, design: .rounded).weight(.bold))
            }
            .frame(maxWidth: .infinity)
        }
        .padding(BudgetVaultTheme.spacingMD)
        .background(BudgetVaultTheme.cardBackground, in: RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusButton))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Period summary: Spent \(CurrencyFormatter.format(cents: totalSpent)), Income \(CurrencyFormatter.format(cents: totalIncome)), \(cachedFilteredTransactions.count) entries")
        .padding(.horizontal)
        .padding(.top, BudgetVaultTheme.spacingSM)
    }

    // MARK: - Segmented Filter

    @ViewBuilder
    private var segmentedFilter: some View {
        Picker("Filter", selection: $filterMode) {
            Text("All").tag(FilterMode.all)
            Text("Expenses").tag(FilterMode.expenses)
            Text("Income").tag(FilterMode.income)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .padding(.top, BudgetVaultTheme.spacingSM)
    }

    // MARK: - Category Chips (Circular)

    @ViewBuilder
    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: BudgetVaultTheme.spacingSM + 2) {
                // "All" chip
                Button {
                    selectedCategoryID = nil
                    HapticManager.selection()
                } label: {
                    VStack(spacing: 3) {
                        ZStack {
                            Circle()
                                .fill(selectedCategoryID == nil ? Color.accentColor : Color.secondary.opacity(0.06))
                                .frame(width: 36, height: 36)
                            Text("All")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(selectedCategoryID == nil ? .white : .secondary)
                        }
                        Text("All")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(selectedCategoryID == nil ? Color.accentColor : .secondary)
                    }
                    .frame(width: 48)
                }
                .accessibilityLabel("All categories")
                .accessibilityAddTraits(selectedCategoryID == nil ? .isSelected : [])

                // Category chips
                ForEach(categories, id: \.id) { cat in
                    let isSelected = selectedCategoryID == cat.id
                    let catColor = Color(hex: cat.color)

                    Button {
                        selectedCategoryID = isSelected ? nil : cat.id
                        HapticManager.selection()
                    } label: {
                        VStack(spacing: 3) {
                            ZStack {
                                Circle()
                                    .fill(isSelected ? catColor.opacity(0.15) : Color.secondary.opacity(0.06))
                                    .frame(width: 36, height: 36)
                                Circle()
                                    .strokeBorder(isSelected ? catColor : Color.clear, lineWidth: 2)
                                    .frame(width: 36, height: 36)
                                Text(cat.emoji)
                                    .font(.system(size: 16))
                            }
                            Text(cat.name)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(isSelected ? .primary : .secondary)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                                .minimumScaleFactor(0.85)
                        }
                        .frame(width: 58) // Round 7 H11: widened so "Entertainment"/"Savings" don't truncate
                    }
                    .accessibilityLabel(cat.name)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .padding(.horizontal)
        }
        .padding(.top, BudgetVaultTheme.spacingSM)
    }

    // MARK: - Vault Empty State

    @ViewBuilder
    private var vaultEmptyState: some View {
        EmptyStateView(
            icon: "clock.fill",
            title: "Nothing Logged Yet",
            message: "Your transaction history will appear here.",
            actionLabel: "Log Expense"
        ) {
            NotificationCenter.default.post(name: .openTransactionEntry, object: nil)
        }
    }

    // MARK: - Day Label

    private func dayLabel(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            return Self.dayFormatter.string(from: date)
        }
    }

    // MARK: - Transaction List

    private var deleteConfirmationTitle: String {
        "Delete this transaction?"
    }

    private func duplicateTransaction(_ transaction: Transaction) {
        let duplicate = Transaction(
            amountCents: transaction.amountCents,
            note: transaction.note,
            date: Date(),
            isIncome: transaction.isIncome,
            category: transaction.category
        )
        modelContext.insert(duplicate)
        guard SafeSave.save(modelContext) else {
            modelContext.rollback()
            return
        }
        HapticManager.notification(.success)
    }

    private let swipeToDeleteTip = SwipeToDeleteTip()

    @ViewBuilder
    private var transactionList: some View {
        List {
            // Tip
            TipView(swipeToDeleteTip)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
                .padding(.horizontal)

            // Summary card
            summaryCard
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

            // Segmented picker
            segmentedFilter
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

            // Category chips (only when not income filter)
            if filterMode != .income {
                categoryChips
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }

            // v3.2 Sprint 5 / audit M1: "Today" CTA only when today has
            // no transactions. When today DOES have transactions, the
            // existing cachedGroupedByDay renders a Today section header,
            // so showing a second row is redundant.
            if isCurrentPeriod && !hasTransactionToday {
                todaySummaryRow
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }

            // Grouped transactions by day
            ForEach(cachedGroupedByDay, id: \.date) { group in
                Section {
                    // Day group card
                    VStack(spacing: 0) {
                        ForEach(Array(group.transactions.enumerated()), id: \.element.id) { index, transaction in
                            Button {
                                editingTransaction = transaction
                            } label: {
                                transactionRow(transaction)
                            }
                            .tint(.primary)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    transactionToDelete = transaction
                                    showDeleteConfirmation = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    duplicateTransaction(transaction)
                                } label: {
                                    Label("Duplicate", systemImage: "doc.on.doc")
                                }
                                .tint(Color.accentColor)

                                Button {
                                    transaction.isReconciled.toggle()
                                    guard SafeSave.save(modelContext) else {
                                        modelContext.rollback()
                                        return
                                    }
                                    HapticManager.selection()
                                } label: {
                                    Label(
                                        transaction.isReconciled ? "Unreview" : "Reviewed",
                                        systemImage: transaction.isReconciled ? "checkmark.circle.fill" : "checkmark.circle"
                                    )
                                }
                                .tint(BudgetVaultTheme.positive)
                            }
                            .contextMenu {
                                Button {
                                    editingTransaction = transaction
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                Button {
                                    duplicateTransaction(transaction)
                                } label: {
                                    Label("Duplicate", systemImage: "doc.on.doc")
                                }
                                Button(role: .destructive) {
                                    transactionToDelete = transaction
                                    showDeleteConfirmation = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .accessibilityHint("Double tap to edit. Swipe left to delete, swipe right to duplicate.")

                            if index < group.transactions.count - 1 {
                                Divider()
                                    .padding(.leading, 60)
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text(dayLabel(for: group.date))
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(daySubtotal(group.transactions))
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, BudgetVaultTheme.spacingSM)
                }
            }

            // Pagination: Load More
            if hasMoreTransactions {
                Section {
                    Button {
                        displayLimit += 50
                    } label: {
                        HStack {
                            Spacer()
                            Text("Load More")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Color.accentColor)
                            Spacer()
                        }
                        .padding(.vertical, BudgetVaultTheme.spacingSM)
                    }
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .refreshable {
            recomputeFilteredTransactions()
        }
    }

    // MARK: - Transaction Row (H1B Card Style)

    /// v3.2: "Today" empty-state CTA. Only rendered when nothing has
    /// been logged today — otherwise the existing day-group header
    /// already shows Today's total and would be duplicated here.
    private var hasTransactionToday: Bool {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return allTransactions.contains {
            !$0.isIncome && cal.isDate($0.date, inSameDayAs: today)
        }
    }

    @ViewBuilder
    private var todaySummaryRow: some View {
        HStack(spacing: BudgetVaultTheme.spacingMD) {
            Image(systemName: "sun.max.fill")
                .font(.title3)
                .foregroundStyle(BudgetVaultTheme.caution)
                .frame(width: 36, height: 36)
                .background(
                    BudgetVaultTheme.caution.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusMD)
                )

            VStack(alignment: .leading, spacing: 1) {
                Text("Today")
                    .font(.subheadline.weight(.bold))
                Text("Nothing logged yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                NotificationCenter.default.post(name: .openTransactionEntry, object: nil)
            } label: {
                Text("Log")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .frame(minHeight: 44)
                    .background(Color.accentColor, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, BudgetVaultTheme.spacingSM + 2)
        .padding(.horizontal)
        .background(
            RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusLG)
                .fill(Color(.secondarySystemBackground))
        )
        .padding(.horizontal)
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("todayEmptyRow")
    }

    @ViewBuilder
    private func transactionRow(_ transaction: Transaction) -> some View {
        let catColor = transactionCategoryColor(transaction)

        HStack(spacing: BudgetVaultTheme.spacingMD) {
            // Category color bar
            RoundedRectangle(cornerRadius: 2)
                .fill(catColor)
                .frame(width: 3, height: 32)

            // Emoji in tinted rounded-rect
            Text(transactionEmoji(transaction))
                .font(.title3)
                .frame(width: 40, height: 40)
                .background(
                    catColor.opacity(0.06),
                    in: RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusMD)
                )

            // Info
            VStack(alignment: .leading, spacing: 1) {
                Text(transactionTitle(transaction))
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                HStack(spacing: BudgetVaultTheme.spacingXS) {
                    Text(transaction.category?.name ?? "Income")
                    Text("\u{00B7}")
                    Text(transaction.date, style: .time)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            // Amount + reconciled indicator
            VStack(alignment: .trailing, spacing: 2) {
                Text(transactionFormattedAmount(transaction))
                    .font(BudgetVaultTheme.rowAmount)
                    .foregroundStyle(transaction.isIncome ? BudgetVaultTheme.positive : .primary)
                if transaction.isReconciled {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.caption2)
                        .foregroundStyle(BudgetVaultTheme.positive.opacity(0.7))
                        .accessibilityLabel("Reviewed")
                }
            }
        }
        .padding(.vertical, BudgetVaultTheme.spacingSM + 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(transactionEmoji(transaction)) \(transactionTitle(transaction)), \(transactionFormattedAmount(transaction)), \(transaction.date.formatted(date: .abbreviated, time: .omitted))")
    }

    // MARK: - Transaction Row Helpers

    private func transactionTitle(_ transaction: Transaction) -> String {
        if !transaction.note.isEmpty {
            return transaction.note
        }
        return transaction.isIncome ? "Income" : (transaction.category?.name ?? "Expense")
    }

    private func transactionEmoji(_ transaction: Transaction) -> String {
        if transaction.isIncome { return "\u{1F4B5}" }
        return transaction.category?.emoji ?? "\u{1F4E6}"
    }

    private func transactionCategoryColor(_ transaction: Transaction) -> Color {
        if transaction.isIncome { return BudgetVaultTheme.positive }
        guard let hex = transaction.category?.color else { return Color(.systemGray4) }
        return Color(hex: hex)
    }

    private func transactionFormattedAmount(_ transaction: Transaction) -> String {
        let sign = transaction.isIncome ? "+" : "-"
        return "\(sign)\(CurrencyFormatter.format(cents: transaction.amountCents))"
    }

    // MARK: - Navigation

    private func navigateMonth(_ delta: Int) {
        if reduceMotion {
            let (m, y) = DateHelpers.navigateMonth(from: viewingMonth, year: viewingYear, delta: delta)
            viewingMonth = m
            viewingYear = y
            displayLimit = 50
        } else {
            withAnimation(.easeInOut(duration: BudgetVaultTheme.animationStandard)) {
                let (m, y) = DateHelpers.navigateMonth(from: viewingMonth, year: viewingYear, delta: delta)
                viewingMonth = m
                viewingYear = y
                displayLimit = 50
            }
        }
        HapticManager.selection()
    }

    private static func csvEscape(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") {
            return "\"\(field.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return field
    }

    private func daySubtotal(_ transactions: [Transaction]) -> String {
        let spent = transactions.filter { !$0.isIncome }.reduce(Int64(0)) { $0 + $1.amountCents }
        let earned = transactions.filter { $0.isIncome }.reduce(Int64(0)) { $0 + $1.amountCents }

        if earned > 0 && spent > 0 {
            return "-\(CurrencyFormatter.format(cents: spent)) / +\(CurrencyFormatter.format(cents: earned))"
        } else if earned > 0 {
            return "+\(CurrencyFormatter.format(cents: earned))"
        }
        return "-\(CurrencyFormatter.format(cents: spent))"
    }
}
