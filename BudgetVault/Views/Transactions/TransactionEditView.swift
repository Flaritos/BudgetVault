import SwiftUI
import SwiftData

struct TransactionEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let transaction: Transaction
    let budget: Budget
    let categories: [Category]

    @State private var amountText: String
    @State private var isIncome: Bool
    @State private var selectedCategory: Category?
    @State private var date: Date
    @State private var note: String
    @State private var showDeleteConfirmation = false

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

                Text(displayAmount)
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(amountText.isEmpty ? .secondary : .primary)
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

                HStack {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                        .labelsHidden()
                    TextField("Add a note", text: $note)
                        .textFieldStyle(.roundedBorder)
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
