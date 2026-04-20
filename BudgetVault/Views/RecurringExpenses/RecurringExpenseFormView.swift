import SwiftUI
import SwiftData
import BudgetVaultShared

struct RecurringExpenseFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @ScaledMetric(relativeTo: .body) private var chipSize: CGFloat = 44
    @ScaledMetric(relativeTo: .body) private var chipWidth: CGFloat = 56

    @Query(sort: [SortDescriptor(\Budget.year, order: .reverse), SortDescriptor(\Budget.month, order: .reverse)]) private var allBudgets: [Budget]

    let expense: RecurringExpense?

    @State private var name: String
    @State private var amountText: String
    @State private var frequency: RecurringExpense.Frequency
    @State private var selectedCategory: Category?
    @State private var startDate: Date
    @State private var showDeleteConfirmation = false
    @FocusState private var isInputFocused: Bool

    private var isEditing: Bool { expense != nil }

    @AppStorage(AppStorageKeys.resetDay) private var resetDay = 1

    private var currentBudget: Budget? {
        let (m, y) = DateHelpers.currentBudgetPeriod(resetDay: max(resetDay, 1))
        return allBudgets.first { $0.month == m && $0.year == y }
    }

    private var categories: [Category] {
        (currentBudget?.categories ?? []).filter { !$0.isHidden }.sorted { $0.sortOrder < $1.sortOrder }
    }

    init(expense: RecurringExpense?) {
        self.expense = expense
        _name = State(initialValue: expense?.name ?? "")
        _amountText = State(initialValue: expense.map { CurrencyFormatter.formatRaw(cents: $0.amountCents) } ?? "")
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
                            .focused($isInputFocused)
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
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { isInputFocused = false }
                }
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
                    guard SafeSave.save(modelContext) else {
                        modelContext.rollback()
                        return
                    }
                    dismiss()
                }
            }
        }
    }

    private func save() {
        let cents = MoneyHelpers.parseCurrencyString(amountText) ?? 0
        let trimmedName = name.trimmingCharacters(in: .whitespaces)

        let expenseToSchedule: RecurringExpense

        if let expense {
            expense.name = trimmedName
            expense.amountCents = cents
            expense.frequency = frequency.rawValue
            expense.category = selectedCategory
            expense.nextDueDate = startDate
            expenseToSchedule = expense
        } else {
            let newExpense = RecurringExpense(
                name: trimmedName,
                amountCents: cents,
                frequency: frequency,
                nextDueDate: startDate,
                category: selectedCategory
            )
            modelContext.insert(newExpense)
            expenseToSchedule = newExpense
        }
        guard SafeSave.save(modelContext) else {
            modelContext.rollback()
            return
        }

        // Schedule bill due reminder if enabled
        if UserDefaults.standard.bool(forKey: AppStorageKeys.billDueReminders) {
            NotificationService.scheduleBillDueReminder(
                expenseName: trimmedName,
                dueDate: expenseToSchedule.nextDueDate,
                id: expenseToSchedule.id.uuidString
            )
        }

        HapticManager.notification(.success)
        dismiss()
    }

}
