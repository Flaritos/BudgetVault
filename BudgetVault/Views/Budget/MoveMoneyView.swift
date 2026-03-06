import SwiftUI
import SwiftData

struct MoveMoneyView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let categories: [Category]

    @State private var fromCategory: Category?
    @State private var toCategory: Category?
    @State private var amountText = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Move Money")
                    .font(.title2.bold())
                    .padding(.top, 16)

                // From picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("From")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(categories, id: \.id) { cat in
                                Button {
                                    fromCategory = cat
                                    // Clear toCategory if it matches
                                    if toCategory?.id == cat.id {
                                        toCategory = nil
                                    }
                                } label: {
                                    VStack(spacing: 4) {
                                        Text(cat.emoji)
                                            .font(.title3)
                                        Text(cat.name)
                                            .font(.caption2)
                                            .lineLimit(1)
                                    }
                                    .frame(width: 64, height: 64)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(fromCategory?.id == cat.id ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.08))
                                    )
                                }
                                .tint(.primary)
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                Image(systemName: "arrow.down")
                    .font(.title3)
                    .foregroundStyle(.secondary)

                // To picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("To")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(categories.filter { $0.id != fromCategory?.id }, id: \.id) { cat in
                                Button {
                                    toCategory = cat
                                } label: {
                                    VStack(spacing: 4) {
                                        Text(cat.emoji)
                                            .font(.title3)
                                        Text(cat.name)
                                            .font(.caption2)
                                            .lineLimit(1)
                                    }
                                    .frame(width: 64, height: 64)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(toCategory?.id == cat.id ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.08))
                                    )
                                }
                                .tint(.primary)
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                // Amount
                Text(displayAmount)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .padding(.top, 8)

                NumberPadView(text: $amountText)
                    .padding(.horizontal, 24)

                Spacer()

                Button {
                    moveMoney()
                } label: {
                    Text("Move Money")
                }
                .buttonStyle(PrimaryButtonStyle(isEnabled: canMove))
                .disabled(!canMove)
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private var displayAmount: String {
        let symbol = CurrencyFormatter.currencySymbol()
        if amountText.isEmpty { return "\(symbol)0" }
        return "\(symbol)\(amountText)"
    }

    private var canMove: Bool {
        guard let _ = fromCategory, let _ = toCategory else { return false }
        guard fromCategory?.id != toCategory?.id else { return false }
        guard let cents = MoneyHelpers.parseCurrencyString(amountText), cents > 0 else { return false }
        return true
    }

    private func moveMoney() {
        guard let from = fromCategory, let to = toCategory else { return }
        guard let cents = MoneyHelpers.parseCurrencyString(amountText), cents > 0 else { return }

        from.budgetedAmountCents -= cents
        to.budgetedAmountCents += cents
        SafeSave.save(modelContext)
        HapticManager.notification(.success)
        dismiss()
    }
}
