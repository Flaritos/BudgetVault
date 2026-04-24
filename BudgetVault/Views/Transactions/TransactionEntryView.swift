import SwiftUI
import SwiftData
import BudgetVaultShared

struct TransactionEntryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let budget: Budget
    let categories: [Category]
    var prefillAmount: Double?
    var prefillCategoryName: String?
    var prefillNote: String?

    // Audit 2026-04-22 P0-7: bounded to last 90 days. Used only for
    // category learning + note suggestions — recent patterns are what
    // matter, stale history just inflates memory.
    @Query private var allRecentTransactions: [Transaction]

    init(budget: Budget, categories: [Category], prefillAmount: Double? = nil, prefillCategoryName: String? = nil, prefillNote: String? = nil) {
        self.budget = budget
        self.categories = categories
        self.prefillAmount = prefillAmount
        self.prefillCategoryName = prefillCategoryName
        self.prefillNote = prefillNote
        let cutoff = Calendar.current.date(byAdding: .day, value: -90, to: Date()) ?? .distantPast
        _allRecentTransactions = Query(
            filter: #Predicate<Transaction> { $0.date >= cutoff },
            sort: [SortDescriptor(\Transaction.date, order: .reverse)]
        )
    }

    @AppStorage(AppStorageKeys.selectedCurrency) private var selectedCurrency = "USD"

    @State private var amountText = ""
    @State private var isIncome = false
    @State private var selectedCategory: Category?
    @State private var date = Date()
    @State private var note = ""
    // Audit 2026-04-23 Perf P0: cached note suggestions + debounce task.
    @State private var cachedNoteSuggestions: [String] = []
    @State private var noteSuggestionsDebounceTask: Task<Void, Never>?
    @State private var showSavedBanner = false
    @State private var manualCategorySelection = false
    @State private var showNoteSuggestions = false
    @State private var showSaveError = false
    @State private var lastSavedCategory: String?
    @State private var lastSavedAmount: String = ""
    @State private var didApplyIntentPrefill = false
    @State private var categoryAutoSelected = false
    @State private var categoryConfidence: Double = 0  // 0.0–1.0
    @FocusState private var noteFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let categoryLearning = CategoryLearningService()

    /// Limit recent transactions to last 200 for performance
    private var recentTransactions: [Transaction] {
        Array(allRecentTransactions.prefix(200))
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                BudgetVaultTheme.navyDark.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Titanium hairline at the top — the "deposit box lid"
                    // seam on the bottom sheet. Visible right under the
                    // system drag handle.
                    Rectangle()
                        .fill(BudgetVaultTheme.titanium300.opacity(0.55))
                        .frame(height: 1)

                    formContent
                }
            }
            .navigationTitle(isIncome ? "New income" : "New expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(BudgetVaultTheme.navyDark, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .onAppear { applyIntentPrefillIfNeeded() }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .tint(BudgetVaultTheme.accentSoft)
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
    }

    @ViewBuilder
    private var formContent: some View {
        VStack(spacing: 0) {
            // Scrollable interior — date chips, flip amount, auto-sorted
            // badge, deposit-box categories, note chamber.
            ScrollView {
                VStack(spacing: BudgetVaultTheme.spacingLG) {
                    typeToggle
                    dateChipRow
                    amountDisplay
                    // Audit 2026-04-23 Smoke-3: quick-amount chips
                    // moved here (immediately under the amount display)
                    // from below noteChamber. Prior position sat at
                    // y≈551 — behind the pinned keypad at y=503–720 —
                    // so taps landed on keypad digits. Chips belong
                    // with the amount input anyway; they read
                    // naturally as "quick presets" between entering
                    // the number and the rest of the form.
                    if !isIncome { quickAmountChips }
                    budgetContextHint
                    suggestedAmountButton
                    autoSortedBadge
                    if !isIncome {
                        depositBoxCategoryRow
                    } else {
                        incomeHint
                    }
                    noteChamber
                    if showNoteSuggestions && !noteSuggestions.isEmpty {
                        noteSuggestionStrip
                    }
                }
                .padding(.horizontal, BudgetVaultTheme.spacingLG)
                .padding(.top, BudgetVaultTheme.spacingMD)
                .padding(.bottom, BudgetVaultTheme.spacingSM)
            }

            // Pinned bottom: QuietKeypad + Save CTA. Log is a fast
            // recurring task — no ceremony, no titanium keys.
            VStack(spacing: BudgetVaultTheme.spacingSM) {
                QuietKeypad(text: $amountText)
                savedBanner
                saveHelperText
                saveCTA
                saveAndAddAnotherLink
            }
            .padding(.horizontal, BudgetVaultTheme.spacingLG)
            .padding(.bottom, BudgetVaultTheme.spacingMD)
        }
    }

    // MARK: - Type toggle (Expense ⇄ Income)

    private var typeToggle: some View {
        Picker("Type", selection: $isIncome) {
            Text("Expense").tag(false)
            Text("Income").tag(true)
        }
        .pickerStyle(.segmented)
        .onChange(of: isIncome) { _, newValue in
            if newValue {
                selectedCategory = nil
                categoryAutoSelected = false
            }
        }
    }

    // MARK: - Date chip row (Today / Yesterday / 2 days ago / picker)

    private var dateChipRow: some View {
        HStack(spacing: 6) {
            dateChip(offset: 0, label: "Today")
            dateChip(offset: -1, label: "Yesterday")
            dateChip(offset: -2, label: "2 days ago")
            datePickerChip
            Spacer(minLength: 0)
        }
    }

    private func dateChip(offset: Int, label: String) -> some View {
        let targetDate = Calendar.current.date(byAdding: .day, value: offset, to: Calendar.current.startOfDay(for: Date())) ?? Date()
        let isSelected = Calendar.current.isDate(date, inSameDayAs: targetDate)
        return Button {
            date = targetDate
            HapticManager.selection()
        } label: {
            Text(label)
                .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                .foregroundStyle(isSelected ? .white : BudgetVaultTheme.titanium200)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isSelected ? BudgetVaultTheme.accentSoft : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(
                            isSelected ? BudgetVaultTheme.accentSoft : BudgetVaultTheme.titanium700,
                            lineWidth: 1
                        )
                )
                // Expand tap target to 44pt per WCAG 2.5.5 / Apple HIG
                // without inflating the visible pill.
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private static let pickerChipDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale.current
        f.setLocalizedDateFormatFromTemplate("MMMd")
        return f
    }()

    private var datePickerChip: some View {
        let previousPeriodStart = Calendar.current.date(byAdding: .month, value: -1, to: budget.periodStart) ?? budget.periodStart
        let isCustomDate = ![0, -1, -2].contains { offset in
            let target = Calendar.current.date(byAdding: .day, value: offset, to: Calendar.current.startOfDay(for: Date())) ?? Date()
            return Calendar.current.isDate(date, inSameDayAs: target)
        }
        // Audit 2026-04-23 Smoke-7: the prior design embedded a scaled,
        // clipped `DatePicker` inside the chip so a sliver of the iOS
        // date pill ("A...") always peeked out to the right of the
        // calendar icon, which looked broken and also pushed the row
        // into horizontal overflow. Now the chip shows a clean icon
        // (no custom date) or a full short-date label (custom date),
        // and taps are caught by an invisible `.blendMode(.destinationOver)`
        // DatePicker overlay that surfaces the native iOS popover.
        return HStack(spacing: 4) {
            Image(systemName: "calendar")
                .font(.caption)
            if isCustomDate {
                Text(Self.pickerChipDateFormatter.string(from: date))
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
            }
        }
        .foregroundStyle(isCustomDate ? .white : BudgetVaultTheme.titanium300)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .overlay(
            DatePicker("Date",
                       selection: $date,
                       in: previousPeriodStart...budget.nextPeriodStart.addingTimeInterval(-1),
                       displayedComponents: .date)
                .labelsHidden()
                .datePickerStyle(.compact)
                .tint(BudgetVaultTheme.accentSoft)
                .blendMode(.destinationOver)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(
                    isCustomDate ? BudgetVaultTheme.accentSoft : BudgetVaultTheme.titanium700,
                    lineWidth: 1
                )
        )
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityLabel("Pick a date")
    }

    // MARK: - Flip-digit amount display (replaces plain Text)

    @ViewBuilder
    private var amountDisplay: some View {
        let cents = MoneyHelpers.parseCurrencyString(amountText) ?? 0
        let amount = Decimal(cents) / 100
        FlipDigitDisplay(
            amount: amount,
            style: .display,
            currencyCode: selectedCurrency,
            contextLabel: amountText.isEmpty ? "Amount — no value entered" : "Amount entered"
        )
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
                    .foregroundStyle(BudgetVaultTheme.titanium300)
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
                    .foregroundStyle(BudgetVaultTheme.accentSoft)
                    .padding(.horizontal, BudgetVaultTheme.spacingMD)
                    .padding(.vertical, BudgetVaultTheme.spacingXS)
                    .background(BudgetVaultTheme.accentSoft.opacity(0.12), in: Capsule())
            }
        }
    }

    // MARK: - Auto-sorted badge (spec §7.8: "Auto-sorted · 94% CONFIDENT")

    @ViewBuilder
    private var autoSortedBadge: some View {
        if !isIncome && categoryAutoSelected && selectedCategory != nil && categoryConfidence >= 0.80 {
            let pct = Int((categoryConfidence * 100).rounded())
            HStack(spacing: 8) {
                Text("Auto-sorted")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(BudgetVaultTheme.titanium300)
                Text("\(pct)% CONFIDENT")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(BudgetVaultTheme.accentSoft)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 3)
                            .fill(BudgetVaultTheme.accentSoft.opacity(0.15))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 3)
                            .strokeBorder(BudgetVaultTheme.accentSoft.opacity(0.4), lineWidth: 1)
                    )
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Auto-sorted, \(pct) percent confident")
        }
    }

    // MARK: - Category row — mini deposit-box cards (spec §7.8)

    @ViewBuilder
    private var depositBoxCategoryRow: some View {
        if categories.isEmpty {
            // Audit 2026-04-23 Max Audit P1-32: non-interactive text
            // required the user to cancel the sheet, find Settings,
            // create a category, and return. Dismiss button completes
            // half of that path in one tap.
            VStack(alignment: .leading, spacing: 8) {
                Text("You have no categories yet.")
                    .font(.subheadline)
                    .foregroundStyle(BudgetVaultTheme.titanium200)
                Text("Create one from Settings to start logging expenses.")
                    .font(.caption)
                    .foregroundStyle(BudgetVaultTheme.titanium300)
                Button {
                    dismiss()
                } label: {
                    Text("Close — you can add one from Settings")
                        .font(.caption.bold())
                        .foregroundStyle(BudgetVaultTheme.accentSoft)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            let visible = Array(categories.prefix(4))
            let overflow = categories.count > 4
            VStack(spacing: BudgetVaultTheme.spacingSM) {
                HStack(spacing: 6) {
                    ForEach(visible, id: \.id) { category in
                        depositBoxCard(for: category)
                    }
                }
                if overflow {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(categories.dropFirst(4), id: \.id) { category in
                                depositBoxCard(for: category)
                                    .frame(width: 88)
                            }
                        }
                    }
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
        }
    }

    private func depositBoxCard(for category: Category) -> some View {
        let isSelected = selectedCategory?.id == category.id
        let pipColor = Color(hex: category.color)
        return Button {
            selectedCategory = category
            manualCategorySelection = true
            categoryAutoSelected = false
            categoryConfidence = 0
            HapticManager.selection()
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                // Titanium top lid — 3pt when selected, 3pt titanium600 when not
                Rectangle()
                    .fill(isSelected ? BudgetVaultTheme.titanium300 : BudgetVaultTheme.titanium700)
                    .frame(height: 3)

                VStack(spacing: 4) {
                    HStack {
                        Spacer()
                        Circle()
                            .fill(pipColor)
                            .frame(width: 5, height: 5)
                    }
                    HStack(spacing: 3) {
                        Text(category.emoji)
                            .font(.system(size: 13))
                        Text(category.name)
                            .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                            .foregroundStyle(isSelected ? .white : BudgetVaultTheme.titanium300)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
            }
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        LinearGradient(
                            colors: isSelected
                                ? [Color(hex: "#1a2744"), Color(hex: "#0F1B33")]
                                : [Color.clear, Color.clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(
                        isSelected ? BudgetVaultTheme.accentSoft : BudgetVaultTheme.titanium700,
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .opacity(isSelected ? 1.0 : 0.55)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(categoryAutoSelected && selectedCategory?.id == category.id ? "Suggested: \(category.name)" : category.name)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private var incomeHint: some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.down.circle.fill")
                .foregroundStyle(BudgetVaultTheme.positive)
            Text("Income goes into your monthly budget pool.")
                .font(.caption)
                .foregroundStyle(BudgetVaultTheme.titanium300)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Note chamber (wraps TextField in ChamberCard)

    private var noteChamber: some View {
        ChamberCard(padding: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("NOTE")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(BudgetVaultTheme.titanium300)
                TextField(
                    "",
                    text: $note,
                    // Audit 2026-04-23 Smoke-7: expense-flavored placeholder
                    // ("Lunch · Sushi place") rendered verbatim on the
                    // Income screen, which reads nonsensically. Swap by
                    // intent.
                    prompt: Text(isIncome
                                 ? "e.g. Paycheck · Monthly salary"
                                 : "e.g. Lunch · Sushi place downtown")
                        .foregroundStyle(BudgetVaultTheme.titanium400)
                )
                .font(.system(size: 13))
                .foregroundStyle(.white)
                .tint(BudgetVaultTheme.accentSoft)
                .focused($noteFocused)
                .submitLabel(.done)
                .onSubmit { noteFocused = false }
                .onChange(of: note) { _, newValue in
                    // Audit 2026-04-23 Perf P0: debounce 200ms so rapid
                    // typing doesn't refilter recentTransactions on
                    // every keystroke.
                    noteSuggestionsDebounceTask?.cancel()
                    noteSuggestionsDebounceTask = Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(200))
                        guard !Task.isCancelled else { return }
                        cachedNoteSuggestions = computeNoteSuggestions(for: newValue)
                        showNoteSuggestions = newValue.count >= 2 && !cachedNoteSuggestions.isEmpty
                    }
                    showNoteSuggestions = newValue.count >= 2 && !noteSuggestions.isEmpty
                    if !manualCategorySelection {
                        // Audit 2026-04-22 P1-31: case-insensitive match
                        // so a stored learning entry for "Food" still
                        // auto-selects if the user later renamed the
                        // category to "food".
                        if let suggestion = categoryLearning.suggestCategory(for: newValue),
                           let match = categories.first(where: { $0.name.caseInsensitiveCompare(suggestion.categoryName) == .orderedSame }) {
                            selectedCategory = match
                            categoryAutoSelected = true
                            categoryConfidence = suggestion.confidence
                        } else if let suggested = suggestedCategory {
                            selectedCategory = suggested
                            categoryAutoSelected = true
                            categoryConfidence = 0.80
                        } else {
                            categoryAutoSelected = false
                            categoryConfidence = 0
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var noteSuggestionStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(noteSuggestions, id: \.self) { suggestion in
                    Button {
                        note = suggestion
                        showNoteSuggestions = false
                        noteFocused = false
                        if !manualCategorySelection {
                            // Audit 2026-04-22 P1-31: case-insensitive.
                            if let learned = categoryLearning.suggestCategory(for: suggestion),
                               let match = categories.first(where: { $0.name.caseInsensitiveCompare(learned.categoryName) == .orderedSame }) {
                                selectedCategory = match
                                categoryAutoSelected = true
                                categoryConfidence = learned.confidence
                            } else if let suggested = suggestedCategory {
                                selectedCategory = suggested
                                categoryAutoSelected = true
                                categoryConfidence = 0.80
                            }
                        }
                    } label: {
                        Text(suggestion)
                            .font(.caption)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(BudgetVaultTheme.titanium300.opacity(0.12), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(height: 28)
    }

    // MARK: - Quick-amount chips (kept; restyled as quiet pills)

    private static let zeroDecimalCurrencies: Set<String> = ["JPY", "KRW", "VND", "CLP", "ISK", "UGX"]

    private var quickAmounts: [Int64] {
        if Self.zeroDecimalCurrencies.contains(selectedCurrency) {
            return [50_000, 100_000, 200_000, 500_000]
        }
        return [500, 1000, 2000, 5000]
    }

    @ViewBuilder
    private var quickAmountChips: some View {
        let symbol = CurrencyFormatter.currencySymbol(for: selectedCurrency)
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(quickAmounts, id: \.self) { cents in
                    let dollars = cents / 100
                    let isActive = amountText == "\(dollars)"
                    Button {
                        amountText = "\(dollars)"
                        HapticManager.selection()
                        if selectedCategory == nil, let mru = mostRecentlyUsedCategory {
                            selectedCategory = mru
                            manualCategorySelection = true
                            categoryAutoSelected = true
                            categoryConfidence = 0.80
                        }
                    } label: {
                        Text("\(symbol)\(dollars)")
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundStyle(isActive ? .white : BudgetVaultTheme.titanium300)
                            // Audit 2026-04-23 A11y P1: 32pt chip height
                            // failed WCAG 2.5.5 and MobAI tap-imprecision
                            // hit adjacent chips during smoke. Bump to 44pt
                            // with transparent hit area around the visible
                            // 32pt pill so the surface doesn't grow visibly.
                            .frame(minWidth: 56, minHeight: 32)
                            .padding(.horizontal, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(isActive ? BudgetVaultTheme.accentSoft.opacity(0.15) : Color.clear)
                            )
                            .contentShape(Rectangle())
                            .frame(minHeight: 44)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(
                                        isActive ? BudgetVaultTheme.accentSoft : BudgetVaultTheme.titanium700,
                                        lineWidth: 1
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                    // Audit 2026-04-23 Max Audit P1-35: selection state
                    // was visual-only. Siblings (date chips) expose
                    // .isSelected — mirror that.
                    .accessibilityAddTraits(isActive ? .isSelected : [])
                }
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: - Save helpers + CTAs

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
                    .foregroundStyle(BudgetVaultTheme.titanium300)
                    .frame(maxWidth: .infinity)
                    .transition(.opacity)
            }
        }
    }

    private var saveCTA: some View {
        Button {
            HapticManager.notification(.success)
            saveTransaction()
        } label: {
            HStack {
                if showSavedBanner {
                    Image(systemName: "checkmark")
                        .font(.title3.weight(.bold))
                        .transition(.scale.combined(with: .opacity))
                } else {
                    Text(saveCTALabel)
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PrimaryButtonStyle(isEnabled: canSave))
        .disabled(!canSave)
        .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.75), value: showSavedBanner)
    }

    private var saveCTALabel: String {
        guard let cents = MoneyHelpers.parseCurrencyString(amountText), cents > 0 else {
            return "Save"
        }
        return "Save · \(CurrencyFormatter.format(cents: cents, currencyCode: selectedCurrency))"
    }

    private var saveAndAddAnotherLink: some View {
        Button {
            saveAndAddAnother()
        } label: {
            Text("Save & add another")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(canSave ? BudgetVaultTheme.accentSoft : BudgetVaultTheme.titanium700)
        }
        .buttonStyle(.plain)
        .disabled(!canSave)
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
                        Text("\(lastSavedAmount) · \(cat)")
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

    // MARK: - Intent prefill

    private func applyIntentPrefillIfNeeded() {
        guard !didApplyIntentPrefill else { return }
        didApplyIntentPrefill = true
        if let amount = prefillAmount, amount > 0 {
            // Audit fix: `Int64(amount * 100)` truncates (no rounding).
            // `19.99` through Double arithmetic is `1998.999999...` which
            // truncates to `1998` cents = $19.98. Route through Decimal
            // with banker's rounding to match the CSV import + manual
            // entry paths.
            let decimalCents = (Decimal(amount) * 100 as NSDecimalNumber)
                .rounding(accordingToBehavior: NSDecimalNumberHandler(
                    roundingMode: .bankers, scale: 0,
                    raiseOnExactness: false, raiseOnOverflow: false,
                    raiseOnUnderflow: false, raiseOnDivideByZero: false
                ))
            let cents = Int64(truncating: decimalCents)
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

    // Audit 2026-04-23 Perf P0: prior implementation ran the full
    // recentTransactions filter + lowercased() × N on EVERY keystroke
    // in the note field (no debounce). Typing "groceries" burned ~10k
    // string allocations. Now cached + debounced 200ms via the
    // onChange handler below (mirrors HistoryView P2-13 debounce).
    private func computeNoteSuggestions(for query: String) -> [String] {
        guard query.count >= 2 else { return [] }
        let lowered = query.lowercased()
        let allNotes = recentTransactions
            .filter { !$0.note.isEmpty && $0.note.lowercased().hasPrefix(lowered) && $0.note.lowercased() != lowered }
            .map { $0.note }
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

    // Cached view of noteSuggestions — refreshed only via debounced
    // onChange(of: note) below. Replaces the per-keystroke recompute
    // that the original computed property performed.
    private var noteSuggestions: [String] { cachedNoteSuggestions }

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

        if !isIncome, let category = selectedCategory {
            categoryLearning.recordMapping(note: note, categoryName: category.name)
        }

        HapticManager.notification(.success)
        StreakService.recordLogEntry()
        WidgetDataService.update(from: modelContext, resetDay: UserDefaults.standard.integer(forKey: AppStorageKeys.resetDay))
        UserDefaults.standard.set(true, forKey: AppStorageKeys.hasLoggedFirstTransaction)
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

        lastSavedAmount = CurrencyFormatter.format(cents: cents)
        lastSavedCategory = isIncome ? "Income" : selectedCategory?.name

        amountText = ""
        note = ""
        categoryAutoSelected = false
        categoryConfidence = 0
        withAnimation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.7)) { showSavedBanner = true }
    }
}
