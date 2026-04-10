import SwiftUI
import SwiftData

struct TransactionEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @ScaledMetric(relativeTo: .body) private var chipSize: CGFloat = 44
    @ScaledMetric(relativeTo: .body) private var chipWidth: CGFloat = 56

    let transaction: Transaction
    let budget: Budget
    let categories: [Category]

    @State private var amountText: String
    @State private var isIncome: Bool
    @State private var selectedCategory: Category?
    @State private var date: Date
    @State private var note: String
    @State private var showDeleteConfirmation = false
    @State private var showSaveError = false
    @FocusState private var isInputFocused: Bool

    init(transaction: Transaction, budget: Budget, categories: [Category]) {
        self.transaction = transaction
        self.budget = budget
        self.categories = categories
        let dollars = transaction.amountCents / 100
        let remainder = transaction.amountCents % 100
        _amountText = State(initialValue: remainder == 0 ? "\(dollars)" : String(format: "%lld.%02lld", dollars, remainder))
        _isIncome = State(initialValue: transaction.isIncome)
        _selectedCategory = State(initialValue: transaction.category)
        _date = State(initialValue: transaction.date)
        _note = State(initialValue: transaction.note)
    }

    var body: some View {
        NavigationStack {
            editFormContent
                .navigationTitle("Edit Transaction")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") { isInputFocused = false }
                    }
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                }
                .confirmationDialog("Delete this transaction?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                    Button("Delete", role: .destructive) {
                        deleteTransaction()
                    }
                } message: {
                    Text(deleteConfirmationMessage)
                }
                .alert("Save Failed", isPresented: $showSaveError) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text("Your changes could not be saved. Please try again.")
                }
        }
    }

    private var deleteConfirmationMessage: String {
        "\(CurrencyFormatter.format(cents: transaction.amountCents)) \u{2022} \(transaction.note.isEmpty ? "No note" : transaction.note)\n\(transaction.date.formatted(date: .abbreviated, time: .omitted))\n\(transaction.category?.name ?? "Income")"
    }

    @ViewBuilder
    private var editFormContent: some View {
        VStack(spacing: BudgetVaultTheme.spacingLG) {
            Picker("Type", selection: $isIncome) {
                Text("Expense").tag(false)
                Text("Income").tag(true)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            Text(CurrencyFormatter.displayAmount(text: amountText))
                .font(BudgetVaultTheme.amountEntry)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .foregroundStyle(amountText.isEmpty ? .secondary : (isIncome ? BudgetVaultTheme.positive : BudgetVaultTheme.electricBlue))
                .dynamicTypeSize(...DynamicTypeSize.accessibility3)
                .padding(.top, BudgetVaultTheme.spacingSM)
                .accessibilityValue(amountText.isEmpty ? "No amount entered" : "\(CurrencyFormatter.currencySymbol()) \(amountText)")

            categorySection

            HStack {
                DatePicker("Date", selection: $date, in: budget.periodStart...budget.nextPeriodStart.addingTimeInterval(-1), displayedComponents: .date)
                    .labelsHidden()
                TextField("Add a note", text: $note)
                    .textFieldStyle(.roundedBorder)
                    .focused($isInputFocused)
            }
            .padding(.horizontal)

            Spacer()

            NumberPadView(text: $amountText)
                .padding(.horizontal, BudgetVaultTheme.spacingXL)

            saveHelperText

            Button {
                saveChanges()
            } label: {
                Text("Save Changes")
            }
            .buttonStyle(PrimaryButtonStyle(isEnabled: canSave))
            .disabled(!canSave)
            .padding(.horizontal)

            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Text("Delete Transaction")
                    .font(.subheadline)
            }
            .padding(.bottom, BudgetVaultTheme.spacingSM)
        }
    }

    @ViewBuilder
    private var categorySection: some View {
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
                            HapticManager.selection()
                        } label: {
                            CategoryChipView(
                                emoji: category.emoji,
                                name: category.name,
                                isSelected: selectedCategory?.id == category.id,
                                chipSize: chipSize,
                                chipWidth: chipWidth
                            )
                        }
                        .accessibilityLabel(category.name)
                        .accessibilityAddTraits(selectedCategory?.id == category.id ? .isSelected : [])
                    }
                }
                .padding(.horizontal)
            }
            // Match TransactionEntryView: right-edge fade mask so horizontal
            // overflow is discoverable instead of silently cut off.
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

    /// Tells the user exactly why Save is disabled, matching TransactionEntryView.
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

    private var canSave: Bool {
        guard let cents = MoneyHelpers.parseCurrencyString(amountText), cents > 0 else { return false }
        if !isIncome && selectedCategory == nil { return false }
        return true
    }

    private func deleteTransaction() {
        modelContext.delete(transaction)
        guard SafeSave.save(modelContext) else {
            modelContext.rollback()
            showSaveError = true
            return
        }
        HapticManager.notification(.warning)
        dismiss()
    }

    private func saveChanges() {
        guard let cents = MoneyHelpers.parseCurrencyString(amountText), cents > 0 else { return }
        transaction.amountCents = cents
        transaction.isIncome = isIncome
        transaction.category = isIncome ? nil : selectedCategory
        transaction.date = date
        transaction.note = note
        guard SafeSave.save(modelContext) else {
            modelContext.rollback()
            showSaveError = true
            return
        }
        HapticManager.notification(.success)
        dismiss()
    }

}
