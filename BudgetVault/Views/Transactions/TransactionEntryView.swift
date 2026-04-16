import SwiftUI
import SwiftData
import BudgetVaultShared

struct TransactionEntryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @ScaledMetric(relativeTo: .body) private var chipSize: CGFloat = 44
    @ScaledMetric(relativeTo: .body) private var chipWidth: CGFloat = 56

    let budget: Budget
    let categories: [Category]
    var prefillAmount: Double?
    var prefillCategoryName: String?
    var prefillNote: String?

    // TODO: iOS 18 - Add @Query predicate for budget filtering to avoid loading all records
    @Query(sort: \Transaction.date, order: .reverse) private var allRecentTransactions: [Transaction]

    @AppStorage(AppStorageKeys.selectedCurrency) private var selectedCurrency = "USD"

    @State private var amountText = ""
    @State private var isIncome = false
    @State private var selectedCategory: Category?
    @State private var date = Date()
    @State private var note = ""
    @State private var showSavedBanner = false
    @State private var manualCategorySelection = false
    @State private var showNoteSuggestions = false
    @State private var showSaveError = false
    @State private var lastSavedCategory: String?
    @State private var lastSavedAmount: String = ""
    @State private var didApplyIntentPrefill = false
    @State private var categoryAutoSelected = false
    @FocusState private var isInputFocused: Bool

    private let categoryLearning = CategoryLearningService()

    /// Limit recent transactions to last 200 for performance
    private var recentTransactions: [Transaction] {
        Array(allRecentTransactions.prefix(200))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Brand accent stripe
                LinearGradient(
                    colors: [Color.accentColor.opacity(0.8), Color.accentColor],
                    startPoint: .leading, endPoint: .trailing
                )
                .frame(height: 4)

                formContent
            } // end outer VStack
            // v3.2 audit M16: was "Add Expense"/"Add Income", duplicating
            // the segmented picker. Neutral title lets the picker drive.
            .navigationTitle("New Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { applyIntentPrefillIfNeeded() }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    /// Extracted to keep `body` under the Swift 6 type-checker timeout.
    /// Was previously a single 280-line ViewBuilder that timed out under iOS 18 SDK.
    @ViewBuilder
    private var formContent: some View {
            VStack(spacing: BudgetVaultTheme.spacingLG) {
                typePicker
                // Scrollable middle section for small phone support
                ScrollView {
                    VStack(spacing: BudgetVaultTheme.spacingLG) {
                        amountDisplay
                        budgetContextHint
                        suggestedAmountButton
                        if !isIncome {
                            quickAmountChips
                            quickAddTemplatesRow
                            categoryPickerSection
                        } else {
                            // Round 7 H12: Income mode previously left a ~180pt
                            // empty gap where expense categories used to be.
                            // Now shows a calm caption instead.
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.down.circle.fill")
                                    .foregroundStyle(BudgetVaultTheme.positive)
                                Text("Income goes into your monthly budget pool.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal)
                        }
                        dateAndNoteSection
                    }
                }
                // Pinned bottom: number pad + save actions
                NumberPadView(text: $amountText)
                    .padding(.horizontal, BudgetVaultTheme.spacingXL)
                savedBanner
                // v3.2 audit K3: inline hint so users know WHY Save is
                // disabled. Previously the button just sat grey silently
                // and blocked the 5-second log loop for first-time users.
                saveHelperText
                // v3.2 whimsy: button briefly collapses to a check before dismiss.
                Button {
                    HapticManager.notification(.success)
                    saveTransaction()
                } label: {
                    if showSavedBanner {
                        Image(systemName: "checkmark")
                            .font(.title3.weight(.bold))
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        Text("Save")
                            .transition(.opacity)
                    }
                }
                .buttonStyle(PrimaryButtonStyle(isEnabled: canSave))
                .disabled(!canSave)
                .padding(.horizontal)
                .animation(.spring(response: 0.35, dampingFraction: 0.75), value: showSavedBanner)

                // Round 7 R5: was a second filled blue button competing
                // with Save. Now a quiet text link so there's exactly ONE
                // primary CTA in the sheet.
                Button {
                    saveAndAddAnother()
                } label: {
                    Text("Save & Add Another")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(canSave ? Color.accentColor : Color.secondary)
                }
                .disabled(!canSave)
                .padding(.horizontal)
                .padding(.bottom, BudgetVaultTheme.spacingSM)
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { isInputFocused = false }
                }
            }
            .alert("Save Failed", isPresented: $showSaveError) {
                Button("OK") {}
            } message: {
                Text("Your transaction could not be saved. Please try again.")
            }
            .onChange(of: showSavedBanner) { _, showing in
                if showing {
                    UIAccessibility.post(notification: .announcement, argument: "Transaction saved")
                }
            }
    }

    private var typePicker: some View {
        Picker("Type", selection: $isIncome) {
            Text("Expense").tag(false)
            Text("Income").tag(true)
        }
        .pickerStyle(.segmented)
        .tint(BudgetVaultTheme.navyDark)
        .padding(.horizontal)
    }

    @ViewBuilder
    private var amountDisplay: some View {
        let foreground: Color = amountText.isEmpty
            ? Color.secondary
            : (isIncome ? BudgetVaultTheme.positive : .primary)
        ZStack {
            if let suggestedAmount = suggestedAmountText, amountText.isEmpty {
                Text(CurrencyFormatter.displayAmount(text: suggestedAmount))
                    .font(BudgetVaultTheme.amountEntry)
                    .foregroundStyle(Color.secondary.opacity(0.3))
            }

            Text(CurrencyFormatter.displayAmount(text: amountText))
                .font(BudgetVaultTheme.amountEntry)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .foregroundStyle(foreground)
                .dynamicTypeSize(...DynamicTypeSize.accessibility3)
        }
        .accessibilityValue(amountText.isEmpty ? "No amount entered" : "\(CurrencyFormatter.currencySymbol()) \(amountText)")
        .padding(.top, BudgetVaultTheme.spacingSM)
    }

    @ViewBuilder
    private var budgetContextHint: some View {
        if !isIncome, let cat = selectedCategory {
            let remaining = cat.budgetedAmountCents - cat.spentCents(in: budget)
            HStack(spacing: 4) {
                Text(CurrencyFormatter.format(cents: max(remaining, 0)))
                    .fontWeight(.semibold)
                    .foregroundStyle(remaining > 0 ? BudgetVaultTheme.positive : BudgetVaultTheme.negative)
                Text(remaining > 0 ? "left in \(cat.name)" : "over in \(cat.name)")
                    .foregroundStyle(.secondary)
            }
            .font(.caption)
        }
    }

    @ViewBuilder
    private var suggestedAmountButton: some View {
        if let suggestedAmount = suggestedAmountText, amountText.isEmpty {
            Button {
                amountText = suggestedAmount
                HapticManager.selection()
            } label: {
                Text("Use suggested amount")
                    .font(.caption)
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, BudgetVaultTheme.spacingMD)
                    .padding(.vertical, BudgetVaultTheme.spacingXS)
                    .background(Color.accentColor.opacity(0.1), in: Capsule())
            }
        }
    }

    @ViewBuilder
    private var quickAddTemplatesRow: some View {
        if !frequentTemplates.isEmpty && !isIncome {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: BudgetVaultTheme.spacingSM) {
                    ForEach(Array(frequentTemplates.enumerated()), id: \.offset) { _, template in
                        Button {
                            note = template.note
                            selectedCategory = template.category
                            amountText = CurrencyFormatter.formatRaw(cents: template.amountCents)
                            manualCategorySelection = true
                        } label: {
                            HStack(spacing: BudgetVaultTheme.spacingXS) {
                                Text(template.category?.emoji ?? "")
                                Text(template.note).lineLimit(1)
                            }
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.accentColor.opacity(0.1), in: Capsule())
                        }
                        .tint(.primary)
                        .accessibilityLabel("Quick add: \(template.category?.emoji ?? "") \(template.note), \(CurrencyFormatter.format(cents: template.amountCents))")
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    @ViewBuilder
    private var categoryPickerSection: some View {
        if !isIncome && categories.isEmpty {
            Text("Create a category in Settings first.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
        } else if !isIncome {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: BudgetVaultTheme.spacingMD) {
                    ForEach(categories, id: \.id) { category in
                        Button {
                            selectedCategory = category
                            manualCategorySelection = true
                            categoryAutoSelected = false
                            HapticManager.selection()
                        } label: {
                            let isAutoSuggested = categoryAutoSelected && selectedCategory?.id == category.id
                            VStack(spacing: 2) {
                                ZStack(alignment: .topTrailing) {
                                    CategoryChipView(
                                        emoji: category.emoji,
                                        name: category.name,
                                        isSelected: selectedCategory?.id == category.id,
                                        chipSize: chipSize,
                                        chipWidth: chipWidth
                                    )
                                    if isAutoSuggested {
                                        Image(systemName: "sparkle")
                                            .font(.system(size: 10))
                                            .foregroundStyle(Color.accentColor)
                                            .offset(x: 2, y: -2)
                                    }
                                }
                                if isAutoSuggested {
                                    Text("Suggested")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .tint(.primary) // v3.2 M3: prevent button tint bleed into chip label
                        .accessibilityLabel(categoryAutoSelected && selectedCategory?.id == category.id ? "Suggested: \(category.name)" : category.name)
                        .accessibilityAddTraits(selectedCategory?.id == category.id ? .isSelected : [])
                    }
                }
                .padding(.horizontal)
            }
            // v3.2 audit H4: right-edge fade mask so horizontal overflow
            // is discoverable instead of silently cut off.
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .black, location: 0.0),
                        .init(color: .black, location: 0.9),
                        .init(color: .clear, location: 1.0)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
        }
    }

    @ViewBuilder
    private var dateAndNoteSection: some View {
        VStack(spacing: BudgetVaultTheme.spacingXS) {
            let previousPeriodStart = Calendar.current.date(byAdding: .month, value: -1, to: budget.periodStart) ?? budget.periodStart
            HStack {
                // v3.2 audit L5: added a calendar glyph so the date pill
                // reads as a picker, not a category chip.
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    DatePicker("Date", selection: $date,
                               in: previousPeriodStart...budget.nextPeriodStart.addingTimeInterval(-1),
                               displayedComponents: .date)
                        .labelsHidden()
                }
                TextField("Add a note", text: $note)
                    .textFieldStyle(.roundedBorder)
                    .focused($isInputFocused)
                    .onChange(of: note) { _, newValue in
                        showNoteSuggestions = newValue.count >= 2 && !noteSuggestions.isEmpty
                        if !manualCategorySelection {
                            if let suggestion = categoryLearning.suggestCategory(for: newValue),
                               let match = categories.first(where: { $0.name == suggestion.categoryName }) {
                                selectedCategory = match
                                categoryAutoSelected = true
                            } else if let suggested = suggestedCategory {
                                selectedCategory = suggested
                                categoryAutoSelected = true
                            } else {
                                categoryAutoSelected = false
                            }
                        }
                    }
            }
            .padding(.horizontal)

            if date < budget.periodStart {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundStyle(BudgetVaultTheme.caution)
                    Text("This date is in last month's budget period")
                        .font(.caption)
                        .foregroundStyle(BudgetVaultTheme.caution)
                }
                .padding(.horizontal)
            }

            if showNoteSuggestions && !noteSuggestions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(noteSuggestions, id: \.self) { suggestion in
                            Button {
                                note = suggestion
                                showNoteSuggestions = false
                                if !manualCategorySelection {
                                    if let learned = categoryLearning.suggestCategory(for: suggestion),
                                       let match = categories.first(where: { $0.name == learned.categoryName }) {
                                        selectedCategory = match
                                        categoryAutoSelected = true
                                    } else if let suggested = suggestedCategory {
                                        selectedCategory = suggested
                                        categoryAutoSelected = true
                                    }
                                }
                            } label: {
                                Text(suggestion)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.secondary.opacity(0.12), in: Capsule())
                            }
                            .tint(.primary)
                        }
                    }
                    .padding(.horizontal)
                }
                .frame(height: 28)
            }
        }
    }

    /// Audit K3: tells the user exactly why Save is disabled, if it is.
    @ViewBuilder
    private var saveHelperText: some View {
        if !canSave {
            let msg: String = {
                if (MoneyHelpers.parseCurrencyString(amountText) ?? 0) == 0 {
                    return "Enter an amount to continue"
                }
                if !isIncome && selectedCategory == nil {
                    return "Pick a category to save"
                }
                return ""
            }()
            if !msg.isEmpty {
                Text(msg)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 4)
                    .transition(.opacity)
            }
        }
    }

    @ViewBuilder
    private var savedBanner: some View {
        if showSavedBanner {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Saved!")
                        .font(.subheadline.bold())
                    if let cat = lastSavedCategory {
                        Text("\(lastSavedAmount) \u{00B7} \(cat)")
                            .font(.caption)
                            .opacity(0.85)
                    }
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                LinearGradient(
                    colors: [BudgetVaultTheme.positive, BudgetVaultTheme.positive.opacity(0.7)],
                    startPoint: .leading, endPoint: .trailing
                ),
                in: RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusLG)
            )
            .shadow(color: BudgetVaultTheme.positive.opacity(0.4), radius: 8, y: 4)
            .transition(.scale.combined(with: .opacity))
            .task {
                try? await Task.sleep(for: .seconds(2.5))
                withAnimation { showSavedBanner = false }
            }
        }
    }

    private func applyIntentPrefillIfNeeded() {
        guard !didApplyIntentPrefill else { return }
        didApplyIntentPrefill = true
        if let amount = prefillAmount, amount > 0 {
            let cents = Int64(amount * 100)
            amountText = CurrencyFormatter.formatRaw(cents: cents)
        }
        if let catName = prefillCategoryName {
            let lowered = catName.lowercased()
            if let match = categories.first(where: { $0.name.lowercased() == lowered }) {
                selectedCategory = match
                manualCategorySelection = true
            }
        }
        if let prefillNote, !prefillNote.isEmpty {
            note = prefillNote
        }
    }

    // MARK: - Quick Amount Chips

    /// Zero-decimal currencies store 1 yen = 100 internal cents,
    /// so quick-amount chips need 100x larger cent values to show
    /// sensible round numbers (500, 1000, 2000, 5000 yen).
    private static let zeroDecimalCurrencies: Set<String> = ["JPY", "KRW", "VND", "CLP", "ISK", "UGX"]

    private var quickAmounts: [Int64] {
        if Self.zeroDecimalCurrencies.contains(selectedCurrency) {
            return [50_000, 100_000, 200_000, 500_000] // 500, 1000, 2000, 5000 in whole units
        }
        return [500, 1000, 2000, 5000] // $5, $10, $20, $50 in cents
    }

    @ViewBuilder
    private var quickAmountChips: some View {
        let symbol = CurrencyFormatter.currencySymbol(for: selectedCurrency)

        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: BudgetVaultTheme.spacingSM) {
                ForEach(quickAmounts, id: \.self) { cents in
                    let dollars = cents / 100
                    Button {
                        amountText = "\(dollars)"
                        HapticManager.selection()
                        // Round 7 R4: auto-pick the most-recently-used
                        // category when a quick chip is tapped so Save
                        // isn't stuck waiting for a second tap.
                        if selectedCategory == nil, let mru = mostRecentlyUsedCategory {
                            selectedCategory = mru
                            manualCategorySelection = true
                            categoryAutoSelected = true
                        }
                    } label: {
                        // v3.2 audit H7: bumped to 44pt min tap target (WCAG).
                        Text("\(symbol)\(dollars)")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(amountText == "\(dollars)" ? Color.accentColor : Color.primary)
                            .frame(minWidth: 56, minHeight: 44)
                            .padding(.horizontal, 4)
                            .background(
                                RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusMD)
                                    .fill(Color.accentColor.opacity(amountText == "\(dollars)" ? 0.15 : 0.07))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusMD)
                                    .strokeBorder(amountText == "\(dollars)" ? Color.accentColor : Color.clear, lineWidth: 1.5)
                            )
                    }
                    .tint(.primary)
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Amount Auto-Suggest

    /// When note matches a previous transaction's note exactly, show the last amount as ghost text.
    private var suggestedAmountText: String? {
        guard !note.isEmpty else { return nil }
        let lowered = note.lowercased()
        guard let match = recentTransactions.first(where: {
            !$0.isIncome && $0.note.lowercased() == lowered && $0.amountCents > 0
        }) else { return nil }
        return CurrencyFormatter.formatRaw(cents: match.amountCents)
    }

    // MARK: - Computed

    /// Most-recently-used expense category. Falls back to the first
    /// visible category if there's no history yet.
    private var mostRecentlyUsedCategory: Category? {
        let mru = recentTransactions.first(where: { !$0.isIncome })?.category
        return mru ?? categories.first
    }

    private var canSave: Bool {
        guard let cents = MoneyHelpers.parseCurrencyString(amountText), cents > 0 else { return false }
        if !isIncome && selectedCategory == nil { return false }
        return true
    }

    // MARK: - Category Auto-Suggestion

    private var suggestedCategory: Category? {
        guard note.count >= 2 else { return nil }
        let lowered = note.lowercased()
        let matches = recentTransactions.filter {
            !$0.isIncome && $0.note.lowercased().hasPrefix(lowered) && $0.category != nil
        }
        let grouped = Dictionary(grouping: matches) { $0.category?.id }
        return grouped.max(by: { $0.value.count < $1.value.count })?.value.first?.category
    }

    // MARK: - Note Autocomplete

    private var noteSuggestions: [String] {
        guard note.count >= 2 else { return [] }
        let lowered = note.lowercased()
        let allNotes = recentTransactions
            .filter { !$0.note.isEmpty && $0.note.lowercased().hasPrefix(lowered) && $0.note.lowercased() != lowered }
            .map { $0.note }
        // Unique, preserving order
        var seen = Set<String>()
        var unique: [String] = []
        for n in allNotes {
            let key = n.lowercased()
            if !seen.contains(key) {
                seen.insert(key)
                unique.append(n)
            }
            if unique.count >= 5 { break }
        }
        return unique
    }

    // MARK: - Frequent Templates

    private var frequentTemplates: [(note: String, category: Category?, amountCents: Int64)] {
        let expenses = recentTransactions.filter { !$0.isIncome && !$0.note.isEmpty }
        let grouped = Dictionary(grouping: expenses) { "\($0.note.lowercased())|\($0.category?.id.uuidString ?? "")" }
        return grouped
            .filter { $0.value.count >= 2 }
            .sorted { $0.value.count > $1.value.count }
            .prefix(5)
            .compactMap { (_, txs) -> (String, Category?, Int64)? in
                guard let first = txs.first else { return nil }
                return (first.note, first.category, first.amountCents)
            }
    }

    // MARK: - Actions

    /// Shared save logic: creates transaction, persists, records learning,
    /// updates streak/widget/notifications. Returns the saved cents on
    /// success, or nil on failure.
    @discardableResult
    private func performSave() -> Int64? {
        guard let cents = MoneyHelpers.parseCurrencyString(amountText), cents > 0 else { return nil }

        let transaction = Transaction(
            amountCents: cents,
            note: note,
            date: date,
            isIncome: isIncome,
            category: isIncome ? nil : selectedCategory
        )
        modelContext.insert(transaction)
        guard SafeSave.save(modelContext) else {
            modelContext.rollback()
            showSaveError = true
            return nil
        }

        // Record category learning
        if !isIncome, let category = selectedCategory {
            categoryLearning.recordMapping(note: note, categoryName: category.name)
        }

        HapticManager.notification(.success)
        StreakService.recordLogEntry()
        WidgetDataService.update(from: modelContext, resetDay: UserDefaults.standard.integer(forKey: AppStorageKeys.resetDay))
        UserDefaults.standard.set(true, forKey: AppStorageKeys.hasLoggedFirstTransaction)

        // Update last active date and reschedule re-engagement notifications
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: AppStorageKeys.lastActiveDate)
        NotificationService.scheduleReengagementNotifications()

        return cents
    }

    private func saveTransaction() {
        guard performSave() != nil else { return }
        dismiss()
    }

    private func saveAndAddAnother() {
        guard let cents = performSave() else { return }

        // Capture saved info for banner display
        lastSavedAmount = CurrencyFormatter.format(cents: cents)
        lastSavedCategory = isIncome ? "Income" : selectedCategory?.name

        // Reset form but preserve selected category
        amountText = ""
        note = ""
        categoryAutoSelected = false
        // Keep selectedCategory and manualCategorySelection as-is
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { showSavedBanner = true }
    }
}
