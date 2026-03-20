import SwiftUI
import SwiftData

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
            VStack(spacing: BudgetVaultTheme.spacingLG) {
                // Expense / Income toggle
                Picker("Type", selection: $isIncome) {
                    Text("Expense").tag(false)
                    Text("Income").tag(true)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                // Amount display with ghost text for suggested amount
                ZStack {
                    if let suggestedAmount = suggestedAmountText, amountText.isEmpty {
                        Text(CurrencyFormatter.displayAmount(text: suggestedAmount))
                            .font(BudgetVaultTheme.amountEntry)
                            .foregroundStyle(.secondary.opacity(0.3))
                    }

                    Text(CurrencyFormatter.displayAmount(text: amountText))
                        .font(BudgetVaultTheme.amountEntry)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .foregroundStyle(amountText.isEmpty ? .secondary : (isIncome ? BudgetVaultTheme.positive : BudgetVaultTheme.electricBlue))
                        .dynamicTypeSize(...DynamicTypeSize.accessibility3)
                }
                .accessibilityValue(amountText.isEmpty ? "No amount entered" : "\(CurrencyFormatter.currencySymbol()) \(amountText)")
                .padding(.top, BudgetVaultTheme.spacingSM)

                // Suggested amount tap target
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

                // Quick amount chips
                if !isIncome {
                    quickAmountChips
                }

                // Quick Add templates
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
                                        Text(template.note)
                                            .lineLimit(1)
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

                // Category picker (expense only)
                if !isIncome && categories.isEmpty {
                    Text("Create a category in the Budget tab first.")
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
                                    ZStack(alignment: .topTrailing) {
                                        CategoryChipView(
                                            emoji: category.emoji,
                                            name: category.name,
                                            isSelected: selectedCategory?.id == category.id,
                                            chipSize: chipSize,
                                            chipWidth: chipWidth
                                        )

                                        // Smart category auto-select indicator
                                        if categoryAutoSelected && selectedCategory?.id == category.id {
                                            Image(systemName: "sparkle")
                                                .font(.system(size: 10))
                                                .foregroundStyle(Color.accentColor)
                                                .offset(x: 2, y: -2)
                                        }
                                    }
                                }
                                .accessibilityLabel(category.name)
                                .accessibilityAddTraits(selectedCategory?.id == category.id ? .isSelected : [])
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                // Date and note
                VStack(spacing: BudgetVaultTheme.spacingXS) {
                    HStack {
                        DatePicker("Date", selection: $date,
                                   in: budget.periodStart...budget.nextPeriodStart.addingTimeInterval(-1),
                                   displayedComponents: .date)
                            .labelsHidden()
                        TextField("Add a note", text: $note)
                            .textFieldStyle(.roundedBorder)
                            .focused($isInputFocused)
                            .onChange(of: note) { _, newValue in
                                showNoteSuggestions = newValue.count >= 2 && !noteSuggestions.isEmpty

                                // Auto-suggest category from learning service
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

                    // Note autocomplete suggestions
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

                Spacer()

                // Number pad
                NumberPadView(text: $amountText)
                    .padding(.horizontal, BudgetVaultTheme.spacingXL)

                // Saved banner
                if showSavedBanner {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(BudgetVaultTheme.positive)
                        Text("Saved!")
                            .font(.subheadline.bold())
                    }
                    .transition(.opacity)
                    .task {
                        try? await Task.sleep(for: .seconds(1.5))
                        withAnimation { showSavedBanner = false }
                    }
                }

                // Save button
                Button {
                    saveTransaction()
                } label: {
                    Text("Save")
                }
                .buttonStyle(PrimaryButtonStyle(isEnabled: canSave))
                .disabled(!canSave)
                .padding(.horizontal)

                // Save & Add Another button
                Button {
                    saveAndAddAnother()
                } label: {
                    Text("Save & Add Another")
                }
                .buttonStyle(SecondaryButtonStyle(isEnabled: canSave))
                .disabled(!canSave)
                .padding(.horizontal)
                .padding(.bottom, BudgetVaultTheme.spacingSM)
            }
            .navigationTitle(isIncome ? "Add Income" : "Add Expense")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if !didApplyIntentPrefill {
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
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { isInputFocused = false }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Save Failed", isPresented: $showSaveError) {
                Button("OK") {}
            } message: {
                Text("Your transaction could not be saved. Please try again.")
            }
        }
    }

    // MARK: - Quick Amount Chips

    @ViewBuilder
    private var quickAmountChips: some View {
        let symbol = CurrencyFormatter.currencySymbol(for: selectedCurrency)
        let amounts: [Int64] = [500, 1000, 2000, 5000] // $5, $10, $20, $50 in cents

        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: BudgetVaultTheme.spacingSM) {
                ForEach(amounts, id: \.self) { cents in
                    let dollars = cents / 100
                    Button {
                        amountText = "\(dollars)"
                        HapticManager.selection()
                    } label: {
                        Text("\(symbol)\(dollars)")
                            .font(.caption.bold())
                            .padding(.horizontal, BudgetVaultTheme.spacingMD)
                            .padding(.vertical, BudgetVaultTheme.spacingSM)
                            .background(
                                RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusSM)
                                    .fill(Color.accentColor.opacity(amountText == "\(dollars)" ? 0.2 : 0.08))
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

    private func saveTransaction() {
        guard let cents = MoneyHelpers.parseCurrencyString(amountText), cents > 0 else { return }

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
            return
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

        dismiss()
    }

    private func saveAndAddAnother() {
        guard let cents = MoneyHelpers.parseCurrencyString(amountText), cents > 0 else { return }

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
            return
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

        // Reset form but preserve selected category
        amountText = ""
        note = ""
        categoryAutoSelected = false
        // Keep selectedCategory and manualCategorySelection as-is
        withAnimation { showSavedBanner = true }
    }
}
