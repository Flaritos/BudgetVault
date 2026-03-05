import SwiftUI
import SwiftData

struct TransactionEntryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let budget: Budget
    let categories: [Category]

    @State private var amountText = ""
    @State private var isIncome = false
    @State private var selectedCategory: Category?
    @State private var date = Date()
    @State private var note = ""

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
                    .foregroundStyle(amountText.isEmpty ? .secondary : .primary)
                    .accessibilityValue(amountText.isEmpty ? "No amount entered" : "\(CurrencyFormatter.currencySymbol()) \(amountText)")
                    .padding(.top, 8)

                // Category picker (expense only)
                if !isIncome {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(categories, id: \.id) { category in
                                Button {
                                    selectedCategory = category
                                    HapticManager.selection()
                                } label: {
                                    Text(category.emoji)
                                        .font(.title2)
                                        .frame(width: 44, height: 44)
                                        .background(
                                            Circle()
                                                .strokeBorder(selectedCategory?.id == category.id ? Color.accentColor : Color.clear, lineWidth: 3)
                                        )
                                }
                                .accessibilityLabel(category.name)
                                .accessibilityAddTraits(selectedCategory?.id == category.id ? .isSelected : [])
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                // Date and note
                HStack {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                        .labelsHidden()
                    TextField("Add a note", text: $note)
                        .textFieldStyle(.roundedBorder)
                }
                .padding(.horizontal)

                Spacer()

                // Number pad
                NumberPadView(text: $amountText)
                    .padding(.horizontal, 24)

                // Save button
                Button {
                    saveTransaction()
                } label: {
                    Text("Save")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(canSave ? Color.accentColor : Color.gray, in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.white)
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
        try? modelContext.save()

        HapticManager.notification(.success)
        DashboardViewModel().updateStreak()
        WidgetDataService.update(from: modelContext, resetDay: UserDefaults.standard.integer(forKey: "resetDay"))

        dismiss()
    }
}
