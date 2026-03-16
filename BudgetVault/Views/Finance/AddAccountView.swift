import SwiftUI
import SwiftData

struct AddAccountView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var emoji = "🏦"
    @State private var balanceText = ""
    @State private var accountType = "asset"

    private let assetEmojis = ["🏦", "💰", "📈", "🏠", "🚗", "💎", "🪙", "💵"]
    private let liabilityEmojis = ["💳", "🏦", "🏠", "🚗", "🎓", "🏥", "📱", "💍"]

    private var emojiOptions: [String] {
        accountType == "asset" ? assetEmojis : liabilityEmojis
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Account Type") {
                    Picker("Type", selection: $accountType) {
                        Text("Asset").tag("asset")
                        Text("Liability").tag("liability")
                    }
                    .pickerStyle(.segmented)

                    Text(accountType == "asset"
                         ? "Bank accounts, investments, property, etc."
                         : "Credit cards, loans, mortgages, etc.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Name") {
                    TextField(accountType == "asset" ? "e.g. Savings Account, 401k" : "e.g. Mortgage, Student Loan", text: $name)
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
            }
            .navigationTitle("Add Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addAccount()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || MoneyHelpers.parseCurrencyString(balanceText) == nil)
                }
            }
            .onChange(of: accountType) { _, _ in
                // Reset emoji when switching type
                emoji = emojiOptions.first ?? "🏦"
            }
        }
    }

    private func addAccount() {
        guard let balanceCents = MoneyHelpers.parseCurrencyString(balanceText) else { return }

        let account = NetWorthAccount(
            name: name.trimmingCharacters(in: .whitespaces),
            emoji: emoji,
            balanceCents: balanceCents,
            accountType: accountType
        )
        modelContext.insert(account)
        SafeSave.save(modelContext)
        HapticManager.notification(.success)
        dismiss()
    }
}
