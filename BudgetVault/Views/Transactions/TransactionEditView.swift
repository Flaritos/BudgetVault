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
    @FocusState private var isInputFocused: Bool

    init(transaction: Transaction, budget: Budget, categories: [Category]) {
        self.transaction = transaction
        self.budget = budget
        self.categories = categories
        let dollars = transaction.amountCents / 100
        let remainder = transaction.amountCents % 100
        _amountText = State(initialValue: remainder == 0 ? "\(dollars)" : String(format: "%d.%02d", dollars, remainder))
        _isIncome = State(initialValue: transaction.isIncome)
        _selectedCategory = State(initialValue: transaction.category)
        _date = State(initialValue: transaction.date)
        _note = State(initialValue: transaction.note)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
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
                    .foregroundStyle(amountText.isEmpty ? .secondary : .primary)
                    .dynamicTypeSize(...DynamicTypeSize.accessibility3)
                    .padding(.top, 8)

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
                }

                HStack {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                        .labelsHidden()
                    TextField("Add a note", text: $note)
                        .textFieldStyle(.roundedBorder)
                        .focused($isInputFocused)
                }
                .padding(.horizontal)

                Spacer()

                NumberPadView(text: $amountText)
                    .padding(.horizontal, 24)

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
                .padding(.bottom, 8)
            }
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
                    modelContext.delete(transaction)
                    SafeSave.save(modelContext)
                    HapticManager.notification(.warning)
                    dismiss()
                }
            }
        }
    }

    private var canSave: Bool {
        guard let cents = MoneyHelpers.parseCurrencyString(amountText), cents > 0 else { return false }
        if !isIncome && selectedCategory == nil { return false }
        return true
    }

    private func saveChanges() {
        guard let cents = MoneyHelpers.parseCurrencyString(amountText), cents > 0 else { return }
        transaction.amountCents = cents
        transaction.isIncome = isIncome
        transaction.category = isIncome ? nil : selectedCategory
        transaction.date = date
        transaction.note = note
        SafeSave.save(modelContext)
        HapticManager.notification(.success)
        dismiss()
    }

}
