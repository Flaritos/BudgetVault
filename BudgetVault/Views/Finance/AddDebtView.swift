import SwiftUI
import SwiftData

struct AddDebtView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var emoji = "💳"
    @State private var balanceText = ""
    @State private var interestRateText = ""
    @State private var minimumPaymentText = ""
    @State private var dueDay = 1

    private let emojiOptions = ["💳", "🏦", "🏠", "🚗", "🎓", "💰", "📱", "🏥", "💍", "🛍️"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("e.g. Chase Visa, Car Loan", text: $name)
                }

                Section("Icon") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                        ForEach(emojiOptions, id: \.self) { e in
                            Button {
                                emoji = e
                                HapticManager.selection()
                            } label: {
                                Text(e)
                                    .font(.title2)
                                    .frame(width: 44, height: 44)
                                    .background(
                                        Circle()
                                            .strokeBorder(emoji == e ? Color.accentColor : Color.clear, lineWidth: 3)
                                    )
                            }
                            .accessibilityLabel(e)
                            .accessibilityAddTraits(emoji == e ? .isSelected : [])
                        }
                    }
                }

                Section("Current Balance") {
                    HStack {
                        Text(CurrencyFormatter.currencySymbol())
                            .foregroundStyle(.secondary)
                        TextField("0", text: $balanceText)
                            .keyboardType(.decimalPad)
                            .font(.title3.bold())
                    }
                }

                Section("Interest Rate (APR %)") {
                    TextField("e.g. 19.99", text: $interestRateText)
                        .keyboardType(.decimalPad)
                }

                Section("Minimum Monthly Payment") {
                    HStack {
                        Text(CurrencyFormatter.currencySymbol())
                            .foregroundStyle(.secondary)
                        TextField("0", text: $minimumPaymentText)
                            .keyboardType(.decimalPad)
                    }
                }

                Section("Due Day of Month") {
                    Picker("Due Day", selection: $dueDay) {
                        ForEach(1...28, id: \.self) { day in
                            Text("\(day)").tag(day)
                        }
                    }
                }
            }
            .navigationTitle("Add Debt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addDebt()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || MoneyHelpers.parseCurrencyString(balanceText) == nil)
                }
            }
        }
    }

    private func addDebt() {
        guard let balanceCents = MoneyHelpers.parseCurrencyString(balanceText) else { return }

        let debt = DebtAccount(
            name: name.trimmingCharacters(in: .whitespaces),
            emoji: emoji,
            originalBalanceCents: balanceCents,
            currentBalanceCents: balanceCents,
            interestRate: Double(interestRateText) ?? 0,
            minimumPaymentCents: MoneyHelpers.parseCurrencyString(minimumPaymentText) ?? 0,
            dueDay: dueDay
        )
        modelContext.insert(debt)
        SafeSave.save(modelContext)
        HapticManager.notification(.success)
        dismiss()
    }
}
