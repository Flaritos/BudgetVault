import SwiftUI
import SwiftData

struct MoveMoneyView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @ScaledMetric(relativeTo: .body) private var pickerSize: CGFloat = 64

    let categories: [Category]
    var budget: Budget? = nil

    /// Resolve budget: use explicit parameter or derive from first category's relationship
    private var resolvedBudget: Budget? {
        budget ?? categories.first?.budget
    }

    @State private var fromCategory: Category?
    @State private var toCategory: Category?
    @State private var amountText = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Move Money")
                    .font(.title2.bold())
                    .padding(.top, 16)

                fromPicker
                Image(systemName: "arrow.down")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                toPicker
                amountSection

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

    // MARK: - Sub-views

    private var fromPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("From")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(categories, id: \.id) { cat in
                        let isSelected = fromCategory?.id == cat.id
                        Button {
                            fromCategory = cat
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
                            .frame(width: pickerSize, height: pickerSize)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.08))
                            )
                        }
                        .tint(.primary)
                        .accessibilityLabel("From \(cat.name), \(CurrencyFormatter.format(cents: resolvedBudget.map { cat.remainingCents(in: $0) } ?? cat.budgetedAmountCents)) remaining")
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var toPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("To")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(categories.filter { $0.id != fromCategory?.id }, id: \.id) { cat in
                        let isSelected = toCategory?.id == cat.id
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
                            .frame(width: pickerSize, height: pickerSize)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.08))
                            )
                        }
                        .tint(.primary)
                        .accessibilityLabel("To \(cat.name)")
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    @ViewBuilder
    private var amountSection: some View {
        Text(displayAmount)
            .font(BudgetVaultTheme.priceDisplay)
            .minimumScaleFactor(0.7)
            .lineLimit(1)
            .dynamicTypeSize(...DynamicTypeSize.accessibility3)
            .padding(.top, 8)

        NumberPadView(text: $amountText)
            .padding(.horizontal, 24)

        if exceedsAvailable {
            Text("Exceeds remaining \(CurrencyFormatter.format(cents: fromRemainingCents))")
                .font(.caption)
                .foregroundStyle(BudgetVaultTheme.negative)
        }
    }

    private var displayAmount: String {
        let symbol = CurrencyFormatter.currencySymbol()
        if amountText.isEmpty { return "\(symbol)0" }
        return "\(symbol)\(amountText)"
    }

    private var parsedCents: Int64 {
        MoneyHelpers.parseCurrencyString(amountText) ?? 0
    }

    private var fromRemainingCents: Int64 {
        guard let from = fromCategory else { return 0 }
        guard let b = resolvedBudget else { return from.budgetedAmountCents }
        return from.remainingCents(in: b)
    }

    private var exceedsAvailable: Bool {
        guard fromCategory != nil else { return false }
        return parsedCents > fromRemainingCents
    }

    private var canMove: Bool {
        guard let _ = fromCategory, let _ = toCategory else { return false }
        guard fromCategory?.id != toCategory?.id else { return false }
        guard parsedCents > 0 else { return false }
        guard !exceedsAvailable else { return false }
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
