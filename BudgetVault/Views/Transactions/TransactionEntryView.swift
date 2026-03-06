import SwiftUI
import SwiftData

struct TransactionEntryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let budget: Budget
    let categories: [Category]

    @Query(sort: \Transaction.date, order: .reverse) private var allRecentTransactions: [Transaction]

    @State private var amountText = ""
    @State private var isIncome = false
    @State private var selectedCategory: Category?
    @State private var date = Date()
    @State private var note = ""
    @State private var showSavedBanner = false
    @State private var manualCategorySelection = false
    @State private var showNoteSuggestions = false

    /// Limit recent transactions to last 200 for performance
    private var recentTransactions: [Transaction] {
        Array(allRecentTransactions.prefix(200))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // Expense / Income toggle
                Picker("Type", selection: $isIncome) {
                    Text("Expense").tag(false)
                    Text("Income").tag(true)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                // Amount display
                Text(displayAmount)
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(amountText.isEmpty ? .secondary : (isIncome ? BudgetVaultTheme.positive : BudgetVaultTheme.electricBlue))
                    .accessibilityValue(amountText.isEmpty ? "No amount entered" : "\(CurrencyFormatter.currencySymbol()) \(amountText)")
                    .padding(.top, 8)

                // Quick Add templates
                if !frequentTemplates.isEmpty && !isIncome {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(frequentTemplates.enumerated()), id: \.offset) { _, template in
                                Button {
                                    note = template.note
                                    selectedCategory = template.category
                                    amountText = formatCentsToString(template.amountCents)
                                    manualCategorySelection = true
                                } label: {
                                    HStack(spacing: 4) {
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
                        HStack(spacing: 12) {
                            ForEach(categories, id: \.id) { category in
                                Button {
                                    selectedCategory = category
                                    manualCategorySelection = true
                                    HapticManager.selection()
                                } label: {
                                    VStack(spacing: 4) {
                                        Text(category.emoji)
                                            .font(.title2)
                                            .frame(width: 44, height: 44)
                                            .background(
                                                Circle()
                                                    .strokeBorder(selectedCategory?.id == category.id ? Color.accentColor : Color.clear, lineWidth: 3)
                                            )
                                        Text(category.name)
                                            .font(.caption2)
                                            .lineLimit(1)
                                            .foregroundStyle(.secondary)
                                    }
                                    .frame(width: 56)
                                }
                                .accessibilityLabel(category.name)
                                .accessibilityAddTraits(selectedCategory?.id == category.id ? .isSelected : [])
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                // Date and note
                VStack(spacing: 4) {
                    HStack {
                        DatePicker("Date", selection: $date, displayedComponents: .date)
                            .labelsHidden()
                        TextField("Add a note", text: $note)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: note) { _, newValue in
                                showNoteSuggestions = newValue.count >= 2 && !noteSuggestions.isEmpty
                                // Auto-suggest category when user hasn't manually picked one
                                if !manualCategorySelection, let suggested = suggestedCategory {
                                    selectedCategory = suggested
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
                                        if !manualCategorySelection, let suggested = suggestedCategory {
                                            selectedCategory = suggested
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
                    .padding(.horizontal, 24)

                // Saved banner
                if showSavedBanner {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
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
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                        .padding(10)
                        .background(canSave ? Color.accentColor.opacity(0.15) : Color.gray.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(canSave ? Color.accentColor : .gray)
                }
                .disabled(!canSave)
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            .navigationTitle(isIncome ? "Add Income" : "Add Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    // MARK: - Computed

    private var displayAmount: String {
        let symbol = CurrencyFormatter.currencySymbol()
        if amountText.isEmpty { return "\(symbol)0" }
        return "\(symbol)\(amountText)"
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

    // MARK: - Helpers

    private func formatCentsToString(_ cents: Int64) -> String {
        let dollars = cents / 100
        let remainder = cents % 100
        if remainder == 0 { return "\(dollars)" }
        return String(format: "%d.%02d", dollars, remainder)
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
        SafeSave.save(modelContext)

        HapticManager.notification(.success)
        StreakService.recordLogEntry()
        WidgetDataService.update(from: modelContext, resetDay: UserDefaults.standard.integer(forKey: "resetDay"))
        UserDefaults.standard.set(true, forKey: "hasLoggedFirstTransaction")

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
        SafeSave.save(modelContext)

        HapticManager.notification(.success)
        StreakService.recordLogEntry()
        WidgetDataService.update(from: modelContext, resetDay: UserDefaults.standard.integer(forKey: "resetDay"))
        UserDefaults.standard.set(true, forKey: "hasLoggedFirstTransaction")

        // Reset form but keep category
        amountText = ""
        note = ""
        manualCategorySelection = false
        withAnimation { showSavedBanner = true }
    }
}
