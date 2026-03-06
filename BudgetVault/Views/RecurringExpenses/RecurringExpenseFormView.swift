import SwiftUI
import SwiftData

struct RecurringExpenseFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Budget.year, order: .reverse) private var allBudgets: [Budget]

    let expense: RecurringExpense?

    @State private var name: String
    @State private var amountText: String
    @State private var frequency: RecurringExpense.Frequency
    @State private var selectedCategory: Category?
    @State private var startDate: Date
    @State private var showDeleteConfirmation = false

    private var isEditing: Bool { expense != nil }

    private var categories: [Category] {
        (allBudgets.first?.categories ?? []).filter { !$0.isHidden }.sorted { $0.sortOrder < $1.sortOrder }
    }

    init(expense: RecurringExpense?) {
        self.expense = expense
        _name = State(initialValue: expense?.name ?? "")
        _amountText = State(initialValue: expense.map { Self.formatCents($0.amountCents) } ?? "")
        _frequency = State(initialValue: expense?.frequencyEnum ?? .monthly)
        _selectedCategory = State(initialValue: expense?.category)
        _startDate = State(initialValue: expense?.nextDueDate ?? Date())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Name (e.g. Netflix)", text: $name)
                    HStack {
                        Text(CurrencyFormatter.currencySymbol())
                            .foregroundStyle(.secondary)
                        TextField("0", text: $amountText)
                            .keyboardType(.decimalPad)
                    }
                }

                Section("Frequency") {
                    Picker("Frequency", selection: $frequency) {
                        ForEach(RecurringExpense.Frequency.allCases) { freq in
                            Text(freq.displayName).tag(freq)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Category") {
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
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .accessibilityLabel(category.name)
                                .accessibilityAddTraits(selectedCategory?.id == category.id ? .isSelected : [])
                            }
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                }

                Section("Start Date") {
                    DatePicker("Next due date", selection: $startDate, displayedComponents: .date)
                }

                if isEditing {
                    Section {
                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            HStack {
                                Spacer()
                                Text("Delete Recurring Expense")
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Recurring" : "New Recurring")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || (MoneyHelpers.parseCurrencyString(amountText) ?? 0) <= 0)
                }
            }
            .confirmationDialog("Delete this recurring expense?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if let expense { modelContext.delete(expense) }
                    SafeSave.save(modelContext)
                    dismiss()
                }
            }
        }
    }

    private func save() {
        let cents = MoneyHelpers.parseCurrencyString(amountText) ?? 0
        let trimmedName = name.trimmingCharacters(in: .whitespaces)

        if let expense {
            expense.name = trimmedName
            expense.amountCents = cents
            expense.frequency = frequency.rawValue
            expense.category = selectedCategory
            expense.nextDueDate = startDate
        } else {
            let newExpense = RecurringExpense(
                name: trimmedName,
                amountCents: cents,
                frequency: frequency,
                nextDueDate: startDate,
                category: selectedCategory
            )
            modelContext.insert(newExpense)
        }
        SafeSave.save(modelContext)
        HapticManager.notification(.success)
        dismiss()
    }

    private static func formatCents(_ cents: Int64) -> String {
        let dollars = cents / 100
        let remainder = cents % 100
        if remainder == 0 { return "\(dollars)" }
        return String(format: "%d.%02d", dollars, remainder)
    }
}
