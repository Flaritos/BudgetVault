import SwiftUI
import SwiftData
import TipKit
import BudgetVaultShared

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(AppStorageKeys.resetDay) private var resetDay = 1

    @Query(sort: [SortDescriptor(\Budget.year, order: .reverse), SortDescriptor(\Budget.month, order: .reverse)]) private var allBudgets: [Budget]
    // Audit 2026-04-22 P0-7: intentionally unbounded — this IS the full
    // history view. Pagination in Swift via displayLimit (see :23). A
    // future fetchLimit+"show older" UX is tracked separately, not here.
    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]

    @State private var searchText = ""
    @State private var searchActive = false
    @FocusState private var searchFieldFocused: Bool
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

    // Audit 2026-04-22 P1-26: cancellable handle for the deferred
    // search-field focus (100ms after opening the search toggle).
    @State private var searchFocusTask: Task<Void, Never>?
    // Audit 2026-04-22 P2-13: debounce handle for searchText changes.
    // Prior behavior ran recomputeFilteredTransactions on EVERY
    // keystroke — at 2k+ rows each recompute noticeably stuttered.
    // 250ms debounce is long enough to coalesce typing bursts, short
    // enough to feel responsive.
    @State private var searchDebounceTask: Task<Void, Never>?
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

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
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

    /// Days in the current period that had zero expense transactions.
    private var noSpendDaysThisPeriod: Int {
        guard let budget = currentBudget else { return 0 }
        let cal = Calendar.current
        let start = cal.startOfDay(for: budget.periodStart)
        let today = cal.startOfDay(for: Date())
        let end = min(today, cal.startOfDay(for: budget.nextPeriodStart.addingTimeInterval(-1)))
        guard end >= start else { return 0 }

        let spendingDays = Set(allTransactions
            .filter { !$0.isIncome && $0.date >= start && $0.date < (cal.date(byAdding: .day, value: 1, to: end) ?? end) }
            .map { cal.startOfDay(for: $0.date) })

        let totalDays = (cal.dateComponents([.day], from: start, to: end).day ?? 0) + 1
        return max(0, totalDays - spendingDays.count)
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

    // MARK: - Body — VaultRevamp v2.1 §7.10 "bound ledger" skin

    var body: some View {
        NavigationStack {
            ZStack {
                // Cream paper gradient — the whole page is a page of the
                // bound ledger book.
                LinearGradient(
                    colors: [BudgetVaultTheme.ledgerPaperLight, BudgetVaultTheme.ledgerPaperDark],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Titanium hinge at the top (the cover's metal edge).
                    HingeRule(weight: .heavy)

                    ZStack(alignment: .top) {
                        // L-shaped corner brackets inset 16pt on each side —
                        // "this is a page inside a bound volume."
                        cornerBrackets

                        VStack(spacing: 0) {
                            // Breathing room below the hinge rule so the
                            // corner brackets live in their own margin (per
                            // HTML: 60→80px gap before the "History" title).
                            Spacer().frame(height: 28)

                            ledgerHeader
                                .padding(.horizontal, 28)
                                .padding(.bottom, 18)

                            if searchActive {
                                ledgerSearchField
                                    .padding(.horizontal, 28)
                                    .padding(.bottom, 14)
                                    .transition(.move(edge: .top).combined(with: .opacity))
                            }

                            monthNavigator
                                .padding(.horizontal, 28)
                                .padding(.bottom, 18)

                            statsRow
                                .padding(.horizontal, 28)
                                .padding(.bottom, 18)

                            ledgerContent
                        }
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                if viewingMonth == 0 {
                    let (m, y) = DateHelpers.currentBudgetPeriod(resetDay: resetDay)
                    viewingMonth = m
                    viewingYear = y
                }
                recomputeFilteredTransactions()
            }
            .onDisappear {
                // Audit 2026-04-22 P1-26: kill the deferred search-field
                // focus if the user navigated away before it fired.
                searchFocusTask?.cancel()
                // Audit 2026-04-22 P2-13: also kill any pending debounce.
                searchDebounceTask?.cancel()
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
                // Audit 2026-04-22 P2-13: debounce keystroke-driven
                // refilters. Typing "grocery" used to trigger 7
                // recomputations; now it triggers 1.
                searchDebounceTask?.cancel()
                searchDebounceTask = Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(250))
                    guard !Task.isCancelled else { return }
                    recomputeFilteredTransactions()
                }
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
            .tint(BudgetVaultTheme.ledgerInk)
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
                        // Audit 2026-04-23 UX P1: refresh widget + Live
                        // Activity after delete so home-screen widget
                        // doesn't show the deleted row's phantom spend
                        // until next foreground.
                        WidgetDataService.update(from: modelContext, resetDay: resetDay)
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

    // MARK: - Corner brackets (bound-book visual)

    @ViewBuilder
    private var cornerBrackets: some View {
        VStack {
            HStack {
                CornerBracket(corner: .topLeft, size: 18)
                Spacer()
                CornerBracket(corner: .topRight, size: 18)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .allowsHitTesting(false)
    }

    // MARK: - Ledger header — "History" + "APRIL 2026" + icon buttons

    @ViewBuilder
    private var ledgerHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 5) {
                Text("History")
                    .font(.system(size: 38, weight: .bold))
                    .tracking(-1.14)
                    .foregroundStyle(BudgetVaultTheme.ledgerInk)
                    .lineSpacing(0)

                Text(DateHelpers.monthYearString(month: viewingMonth, year: viewingYear).uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(2.5)
                    .foregroundStyle(BudgetVaultTheme.ledgerInkStrong)
            }

            Spacer()

            HStack(spacing: 6) {
                ledgerIconButton(systemImage: searchActive ? "xmark" : "magnifyingglass") {
                    let willOpen = !searchActive
                    searchActive = willOpen
                    if !willOpen {
                        searchText = ""
                        searchFieldFocused = false
                    } else {
                        // Focus on next runloop tick once the field is in the hierarchy.
                        // Audit 2026-04-22 P1-26: cancellable Task so
                        // dismissing the search toggle before 100ms
                        // elapses doesn't steal focus after dismiss.
                        searchFocusTask?.cancel()
                        searchFocusTask = Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(100))
                            guard !Task.isCancelled else { return }
                            searchFieldFocused = true
                        }
                    }
                }
                .accessibilityLabel(searchActive ? "Close search" : "Search history")

                Menu {
                    Section("Show") {
                        ForEach(FilterMode.allCases, id: \.self) { mode in
                            Button {
                                filterMode = mode
                            } label: {
                                HStack {
                                    Text(mode.rawValue)
                                    if filterMode == mode { Image(systemName: "checkmark") }
                                }
                            }
                        }
                    }
                    Section("Sort by") {
                        ForEach(SortMode.allCases, id: \.self) { mode in
                            Button {
                                sortMode = mode
                            } label: {
                                HStack {
                                    Text(mode.rawValue)
                                    if sortMode == mode { Image(systemName: "checkmark") }
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
                    ledgerIconButtonLabel(systemImage: "line.3.horizontal")
                }
                .accessibilityLabel("Filter and sort")
            }
        }
    }

    private func ledgerIconButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ledgerIconButtonLabel(systemImage: systemImage)
        }
        .buttonStyle(.plain)
    }

    private func ledgerIconButtonLabel(systemImage: String) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(BudgetVaultTheme.ledgerInk)
            .frame(width: 32, height: 32)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(BudgetVaultTheme.ledgerRule, lineWidth: 1)
            )
            // Visible size stays 32pt; hit area bumps to 44pt per WCAG 2.5.5.
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
    }

    // MARK: - Inline ledger search field (replaces .searchable, which
    //         can't render when the nav bar is hidden)

    @ViewBuilder
    private var ledgerSearchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(BudgetVaultTheme.ledgerInkStrong)
            TextField(
                "",
                text: $searchText,
                prompt: Text("Search notes or categories")
                    .foregroundStyle(BudgetVaultTheme.ledgerInkStrong)
            )
            .font(.system(size: 14))
            .foregroundStyle(BudgetVaultTheme.ledgerInk)
            .tint(BudgetVaultTheme.ledgerInk)
            .focused($searchFieldFocused)
            .submitLabel(.search)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(BudgetVaultTheme.ledgerInkStrong)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.6), in: RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(BudgetVaultTheme.ledgerRule, lineWidth: 1)
        )
    }

    // MARK: - Month navigator (chevron / month / chevron)

    @ViewBuilder
    private var monthNavigator: some View {
        HStack(spacing: 12) {
            Button {
                navigateMonth(-1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(BudgetVaultTheme.ledgerInk)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Previous month")

            Spacer(minLength: 0)

            VStack(spacing: 2) {
                Text(monthOnly)
                    .font(.system(size: 17, weight: .bold))
                    .tracking(-0.17)
                    .foregroundStyle(BudgetVaultTheme.ledgerInk)
                if !isCurrentPeriod {
                    Button {
                        jumpToCurrentPeriod()
                    } label: {
                        Text("Back to today")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(BudgetVaultTheme.ledgerInkStrong)
                            .underline()
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer(minLength: 0)

            Button {
                navigateMonth(1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(BudgetVaultTheme.ledgerInk.opacity(isCurrentPeriod ? 0.3 : 1))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .disabled(isCurrentPeriod)
            .accessibilityLabel("Next month")
        }
        .padding(.vertical, 4)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(BudgetVaultTheme.ledgerRule)
                .frame(height: 1)
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(BudgetVaultTheme.ledgerRule)
                .frame(height: 1)
        }
    }

    // Audit 2026-04-22 P2-10: hoisted from inside `monthOnly` so the
    // DateFormatter isn't reallocated on every body re-render.
    private static let monthNameFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM"
        return f
    }()

    private var monthOnly: String {
        let comps = DateComponents(year: viewingYear, month: viewingYear > 0 ? viewingMonth : 1)
        if let date = Calendar.current.date(from: comps) {
            return Self.monthNameFormatter.string(from: date)
        }
        return ""
    }

    private func jumpToCurrentPeriod() {
        let (m, y) = DateHelpers.currentBudgetPeriod(resetDay: resetDay)
        if reduceMotion {
            viewingMonth = m
            viewingYear = y
            displayLimit = 50
        } else {
            withAnimation(.easeInOut(duration: BudgetVaultTheme.animationStandard)) {
                viewingMonth = m
                viewingYear = y
                displayLimit = 50
            }
        }
    }

    // MARK: - Stats row — cream-tinted boxes

    @ViewBuilder
    private var statsRow: some View {
        HStack(spacing: 8) {
            ledgerStatBox(label: "SPENT", value: shortCurrency(totalSpent), valueColor: BudgetVaultTheme.ledgerInk)
            ledgerStatBox(label: "ENTRIES", value: "\(cachedFilteredTransactions.count)", valueColor: BudgetVaultTheme.ledgerInk)
            ledgerStatBox(label: "NO-SPEND", value: "\(noSpendDaysThisPeriod)", valueColor: Color(hex: "#059669"))
        }
    }

    private func ledgerStatBox(label: String, value: String, valueColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.8)
                .foregroundStyle(BudgetVaultTheme.ledgerInkStrong)
            Text(value)
                .font(.system(size: 17, weight: .medium, design: .monospaced))
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white.opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(Color(hex: "#C2AD81"), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }

    // Audit 2026-04-22 P2-10: hoisted so the NumberFormatter isn't
    // allocated once per stat-box render.
    private static let shortCurrencyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f
    }()

    /// Short currency — "$2,253" (no cents) for the stat boxes.
    private func shortCurrency(_ cents: Int64) -> String {
        let dollars = Int(cents / 100)
        let num = Self.shortCurrencyFormatter.string(from: NSNumber(value: dollars)) ?? "\(dollars)"
        return "$\(num)"
    }

    // MARK: - Ledger content (list of day groups or empty state)

    @ViewBuilder
    private var ledgerContent: some View {
        if cachedFilteredTransactions.isEmpty && searchText.isEmpty && filterMode == .all && selectedCategoryID == nil {
            ledgerEmptyState
                .padding(.horizontal, 28)
                .padding(.top, 40)
            Spacer()
        } else if cachedFilteredTransactions.isEmpty && !searchText.isEmpty {
            ContentUnavailableView.search(text: searchText)
                .foregroundStyle(BudgetVaultTheme.ledgerInk)
            Spacer()
        } else if cachedFilteredTransactions.isEmpty {
            EmptyStateView(
                icon: "line.3.horizontal.decrease",
                title: "No Matches",
                message: "No transactions match your current filters. Try changing your filters."
            )
            Spacer()
        } else {
            ledgerList
        }
    }

    @ViewBuilder
    private var ledgerEmptyState: some View {
        VStack(spacing: BudgetVaultTheme.spacingLG) {
            Image(systemName: "book.closed")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(BudgetVaultTheme.ledgerInkStrong)
            Text("Nothing logged yet")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(BudgetVaultTheme.ledgerInk)
            Text("Your transaction history will appear here.")
                .font(.system(size: 13))
                .foregroundStyle(BudgetVaultTheme.ledgerInkStrong)
                .multilineTextAlignment(.center)
            Button {
                NotificationCenter.default.post(name: .openTransactionEntry, object: nil)
            } label: {
                Text("Log expense")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(BudgetVaultTheme.ledgerInk, in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var ledgerList: some View {
        ScrollView {
            LazyVStack(spacing: 18) {
                // "Today" empty-state CTA if today has no transactions.
                if isCurrentPeriod && !hasTransactionToday {
                    todayCallout
                        .padding(.horizontal, 28)
                }

                ForEach(cachedGroupedByDay, id: \.date) { group in
                    dayGroupSection(for: group)
                        .padding(.horizontal, 28)
                }

                // No-spend day rows (inferred days with zero expenses in
                // the grouped list window).
                if isCurrentPeriod {
                    noSpendDayRows
                        .padding(.horizontal, 28)
                }

                if hasMoreTransactions {
                    Button {
                        displayLimit += 50
                    } label: {
                        HStack {
                            Spacer()
                            Text("Load more")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(BudgetVaultTheme.ledgerInk)
                            Spacer()
                        }
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.white.opacity(0.5))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(BudgetVaultTheme.ledgerRule, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 28)
                    .padding(.top, 8)
                }

                Spacer().frame(height: 40)
            }
            .padding(.top, 6)
        }
        .refreshable {
            recomputeFilteredTransactions()
        }
    }

    // MARK: - Day group (heading + cream card of entries)

    @ViewBuilder
    private func dayGroupSection(for group: (date: Date, transactions: [Transaction])) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            dayHeading(for: group.date, transactions: group.transactions)

            VStack(spacing: 0) {
                ForEach(Array(group.transactions.enumerated()), id: \.element.id) { index, transaction in
                    entryRow(transaction)
                        .contentShape(Rectangle())
                        .onTapGesture { editingTransaction = transaction }
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
                            .tint(BudgetVaultTheme.ledgerInk)

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
                            .tint(Color(hex: "#059669"))
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
                        Rectangle()
                            .fill(Color(hex: "#C2AD81"))
                            .frame(height: 1)
                            .opacity(0.5)
                            .padding(.horizontal, 14)
                            .mask(DashedLineMask())
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color(hex: "#C2AD81"), lineWidth: 1)
            )
        }
    }

    @ViewBuilder
    private func dayHeading(for date: Date, transactions: [Transaction]) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(dayHeadingLabel(for: date))
                .font(.system(size: 10, weight: .semibold))
                .tracking(2.0)
                .foregroundStyle(BudgetVaultTheme.ledgerInkStrong)
            Spacer()
            Text(daySubtotalLedger(transactions))
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(BudgetVaultTheme.ledgerInk)
        }
        .padding(.bottom, 4)
        .overlay(alignment: .bottom) {
            DashedLine()
                .stroke(BudgetVaultTheme.ledgerRule, style: StrokeStyle(lineWidth: 1, dash: [2, 3]))
                .frame(height: 1)
        }
    }

    private func dayHeadingLabel(for date: Date) -> String {
        let cal = Calendar.current
        let core = Self.dayFormatter.string(from: date)
        if cal.isDateInToday(date) { return "\(core.uppercased()) · TODAY" }
        if cal.isDateInYesterday(date) { return "\(core.uppercased()) · YESTERDAY" }
        return core.uppercased()
    }

    private func daySubtotalLedger(_ transactions: [Transaction]) -> String {
        let spent = transactions.filter { !$0.isIncome }.reduce(Int64(0)) { $0 + $1.amountCents }
        let earned = transactions.filter { $0.isIncome }.reduce(Int64(0)) { $0 + $1.amountCents }
        if earned > 0 && spent > 0 {
            return "−\(CurrencyFormatter.format(cents: spent)) / +\(CurrencyFormatter.format(cents: earned))"
        } else if earned > 0 {
            return "+\(CurrencyFormatter.format(cents: earned))"
        }
        return "−\(CurrencyFormatter.format(cents: spent))"
    }

    // MARK: - Entry row (30pt icon square + title + meta + amount)

    @ViewBuilder
    private func entryRow(_ transaction: Transaction) -> some View {
        let catColor = transactionCategoryColor(transaction)
        HStack(spacing: 12) {
            // 30pt colored icon square — category color at 15% fill, 40% border
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(catColor.opacity(0.15))
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(catColor.opacity(0.40), lineWidth: 1)
                Text(transactionEmoji(transaction))
                    .font(.system(size: 14))
            }
            .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(transactionTitle(transaction))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(BudgetVaultTheme.ledgerInk)
                    .lineLimit(1)
                Text(transactionMeta(transaction))
                    .font(.system(size: 10, weight: .medium))
                    .tracking(1.2)
                    .foregroundStyle(BudgetVaultTheme.ledgerInkStrong)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            VStack(alignment: .trailing, spacing: 2) {
                Text(transactionLedgerAmount(transaction))
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundStyle(BudgetVaultTheme.ledgerInk)
                if transaction.isReconciled {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(Color(hex: "#059669"))
                        .accessibilityLabel("Reviewed")
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(transactionTitle(transaction)), \(transactionLedgerAmount(transaction)), \(transaction.date.formatted(date: .abbreviated, time: .omitted))")
    }

    private func transactionMeta(_ transaction: Transaction) -> String {
        // "Category · 09:42" — 24-hour time (no "h" suffix), uppercase
        // tracked for engraved-label feel.
        let timeStr = Self.timeFormatter.string(from: transaction.date)
        let context = transaction.isIncome ? "Income" : (transaction.category?.name ?? "")
        return "\(context.uppercased()) · \(timeStr)"
    }

    private func transactionLedgerAmount(_ transaction: Transaction) -> String {
        let sign = transaction.isIncome ? "+" : "−"
        return "\(sign)\(CurrencyFormatter.format(cents: transaction.amountCents))"
    }

    // MARK: - No-spend day rows with WaxSeal

    @ViewBuilder
    private var noSpendDayRows: some View {
        let emptyDays = inferNoSpendDaysInWindow()
        if !emptyDays.isEmpty {
            VStack(spacing: 10) {
                ForEach(emptyDays, id: \.self) { date in
                    HStack {
                        Text("\(Self.dayFormatter.string(from: date).uppercased()) · NO-SPEND DAY")
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(2.0)
                            .foregroundStyle(BudgetVaultTheme.ledgerInkStrong)
                        Spacer()
                        WaxSeal()
                    }
                    .padding(.vertical, 6)
                    .overlay(alignment: .bottom) {
                        DashedLine()
                            .stroke(BudgetVaultTheme.ledgerRule, style: StrokeStyle(lineWidth: 1, dash: [2, 3]))
                            .frame(height: 1)
                    }
                }
            }
        }
    }

    /// Determine days in the current viewing period (up through today) that
    /// had zero expense transactions AND aren't already rendered as day
    /// groups above. We infer from the grouped list's date set.
    private func inferNoSpendDaysInWindow() -> [Date] {
        guard let budget = currentBudget, isCurrentPeriod else { return [] }
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let start = cal.startOfDay(for: budget.periodStart)
        guard today >= start else { return [] }

        let spendingDays = Set(cachedGroupedByDay.map { cal.startOfDay(for: $0.date) })

        // Only show last up to 5 empty days to avoid a wall of dashes.
        var results: [Date] = []
        var cursor = today
        while cursor >= start, results.count < 5 {
            if !spendingDays.contains(cursor) {
                results.append(cursor)
            }
            guard let prev = cal.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return results
    }

    // MARK: - Today callout

    private var hasTransactionToday: Bool {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return allTransactions.contains {
            !$0.isIncome && cal.isDate($0.date, inSameDayAs: today)
        }
    }

    @ViewBuilder
    private var todayCallout: some View {
        HStack(spacing: 12) {
            Image(systemName: "sun.max.fill")
                .font(.title3)
                .foregroundStyle(BudgetVaultTheme.ledgerInkStrong)
                .frame(width: 30, height: 30)
                .background(Color.white.opacity(0.5), in: RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(BudgetVaultTheme.ledgerRule, lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text("TODAY")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(2.0)
                    .foregroundStyle(BudgetVaultTheme.ledgerInkStrong)
                Text("Nothing logged yet")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(BudgetVaultTheme.ledgerInk)
            }
            Spacer()
            Button {
                NotificationCenter.default.post(name: .openTransactionEntry, object: nil)
            } label: {
                Text("Log")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(BudgetVaultTheme.ledgerInk, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(Color.white.opacity(0.5), in: RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(BudgetVaultTheme.ledgerRule, lineWidth: 1)
        )
        .accessibilityIdentifier("todayEmptyRow")
    }

    // MARK: - Existing helpers (preserved)

    private var deleteConfirmationTitle: String { "Delete this transaction?" }

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
        if transaction.isIncome { return Color(hex: "#059669") }
        guard let hex = transaction.category?.color else { return BudgetVaultTheme.ledgerRule }
        return Color(hex: hex)
    }

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
}

// MARK: - Corner bracket (bound-volume visual)

private struct CornerBracket: View {
    enum Corner { case topLeft, topRight, bottomLeft, bottomRight }
    let corner: Corner
    var size: CGFloat = 24

    var body: some View {
        CornerBracketShape(corner: corner)
            .stroke(BudgetVaultTheme.ledgerInk, lineWidth: 2)
            .frame(width: size, height: size)
    }
}

private struct CornerBracketShape: Shape {
    let corner: CornerBracket.Corner

    func path(in rect: CGRect) -> Path {
        var p = Path()
        switch corner {
        case .topLeft:
            p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        case .topRight:
            p.move(to: CGPoint(x: rect.minX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        case .bottomLeft:
            p.move(to: CGPoint(x: rect.minX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        case .bottomRight:
            p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        }
        return p
    }
}

// MARK: - Dashed line primitive (ledgerRule divider)

private struct DashedLine: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return p
    }
}

private struct DashedLineMask: View {
    var body: some View {
        DashedLine()
            .stroke(Color.black, style: StrokeStyle(lineWidth: 1, dash: [2, 3]))
    }
}
