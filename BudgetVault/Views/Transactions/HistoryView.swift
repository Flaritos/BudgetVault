import SwiftUI
import SwiftData
import TipKit

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
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

    /// All matching transactions for the period (used for CSV export and counting)
    private var allFilteredTransactions: [Transaction] {
        guard let budget = currentBudget else { return [] }

        var transactions = Array(allTransactions
            .lazy
            .filter { $0.date >= budget.periodStart && $0.date < budget.nextPeriodStart })

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
                $0.note.localizedCaseInsensitiveContains(searchText)
            }
        }

        switch sortMode {
        case .date:
            return transactions.sorted { $0.date > $1.date }
        case .amount:
            return transactions.sorted { $0.amountCents > $1.amountCents }
        case .category:
            return transactions.sorted {
                ($0.category?.name ?? "") < ($1.category?.name ?? "")
            }
        }
    }

    /// Paginated view of filtered transactions
    private var filteredTransactions: [Transaction] {
        Array(allFilteredTransactions.prefix(displayLimit))
    }

    private var hasMoreTransactions: Bool {
        allFilteredTransactions.count > displayLimit
    }

    private var groupedByDay: [(date: Date, transactions: [Transaction])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredTransactions) { tx in
            calendar.startOfDay(for: tx.date)
        }
        return grouped.sorted { $0.key > $1.key }
            .map { (date: $0.key, transactions: $0.value.sorted { $0.date > $1.date }) }
    }

    private func generateCSV() -> String {
        var lines = ["Date,Category,Note,Amount,Type"]
        for tx in allFilteredTransactions.sorted(by: { $0.date < $1.date }) {
            let dateStr = tx.date.formatted(date: .numeric, time: .omitted)
            let cat = Self.csvEscape(tx.category?.name ?? "")
            let note = Self.csvEscape(tx.note)
            let amount = String(format: "%.2f", Double(tx.amountCents) / 100.0)
            let type = tx.isIncome ? "Income" : "Expense"
            lines.append("\(dateStr),\(cat),\(note),\(amount),\(type)")
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Navy gradient header
                gradientHeader

                // Content
                Group {
                    if filteredTransactions.isEmpty && searchText.isEmpty && filterMode == .all {
                        EmptyStateView(
                            icon: "clock.fill",
                            title: "No Transactions",
                            message: "Start logging to see your history here."
                        )
                    } else if filteredTransactions.isEmpty {
                        ContentUnavailableView.search(text: searchText)
                    } else {
                        transactionList
                    }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .searchable(text: $searchText, prompt: "Search notes")
            .onAppear {
                if viewingMonth == 0 {
                    let (m, y) = DateHelpers.currentBudgetPeriod(resetDay: resetDay)
                    viewingMonth = m
                    viewingYear = y
                }
            }
            .sheet(item: $editingTransaction) { transaction in
                if let budget = currentBudget {
                    TransactionEditView(transaction: transaction, budget: budget, categories: categories)
                }
            }
            .onChange(of: filterMode) { _, newMode in
                if newMode == .income {
                    selectedCategoryID = nil
                }
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
                        SafeSave.save(modelContext)
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

    // MARK: - Gradient Header

    @ViewBuilder
    private var gradientHeader: some View {
        ZStack {
            LinearGradient(
                colors: [BudgetVaultTheme.navyDark, BudgetVaultTheme.electricBlue],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea(edges: .top)

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                HStack {
                    // Back month
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

                    Spacer()

                    // Month/year title with Today button
                    VStack(spacing: 2) {
                        Text(DateHelpers.monthYearString(month: viewingMonth, year: viewingYear))
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)

                        if !isCurrentPeriod {
                            Button {
                                withAnimation(.easeInOut(duration: BudgetVaultTheme.animationStandard)) {
                                    let (m, y) = DateHelpers.currentBudgetPeriod(resetDay: resetDay)
                                    viewingMonth = m
                                    viewingYear = y
                                    displayLimit = 50
                                }
                            } label: {
                                Text("Back to Today")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                        }
                    }

                    Spacer()

                    // Forward month + overflow menu
                    HStack(spacing: BudgetVaultTheme.spacingMD) {
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

                        // Overflow menu: sort + export
                        Menu {
                            // Sort section
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
                                .foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .accessibilityLabel("More options")
                    }
                }
                .padding(.horizontal, BudgetVaultTheme.spacingLG)
                .padding(.bottom, BudgetVaultTheme.spacingSM)
            }
        }
        .frame(height: 100)
    }

    // MARK: - Day Label

    private func dayLabel(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            // "Mon, Mar 17"
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE, MMM d"
            return formatter.string(from: date)
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
        SafeSave.save(modelContext)
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
                .padding(.horizontal)

            // Filter chips
            Section {
                VStack(alignment: .leading, spacing: BudgetVaultTheme.spacingSM) {
                    Picker("Filter", selection: $filterMode) {
                        ForEach(FilterMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    if filterMode != .income {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: BudgetVaultTheme.spacingSM) {
                                chipButton(label: "All", isSelected: selectedCategoryID == nil) {
                                    selectedCategoryID = nil
                                }
                                ForEach(categories, id: \.id) { cat in
                                    chipButton(label: cat.emoji, isSelected: selectedCategoryID == cat.id) {
                                        selectedCategoryID = cat.id
                                    }
                                    .accessibilityLabel(cat.name)
                                }
                            }
                        }
                    }
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .padding(.horizontal)
            }

            // Grouped transactions by day
            ForEach(groupedByDay, id: \.date) { group in
                Section {
                    ForEach(group.transactions, id: \.id) { transaction in
                        Button {
                            editingTransaction = transaction
                        } label: {
                            TransactionRowView(transaction: transaction)
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
                    }
                } header: {
                    HStack {
                        Text(dayLabel(for: group.date))
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text(daySubtotal(group.transactions))
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
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
                                .font(.subheadline)
                            Spacer()
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    @ViewBuilder
    private func chipButton(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline)
                .padding(.horizontal, BudgetVaultTheme.spacingMD)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.08), in: Capsule())
                .foregroundStyle(isSelected ? Color.accentColor : .secondary)
        }
    }

    private func navigateMonth(_ delta: Int) {
        withAnimation(.easeInOut(duration: BudgetVaultTheme.animationStandard)) {
            let (m, y) = DateHelpers.navigateMonth(from: viewingMonth, year: viewingYear, delta: delta)
            viewingMonth = m
            viewingYear = y
            displayLimit = 50
        }
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
