import SwiftUI
import SwiftData
import BudgetVaultShared

/// Move Money — VaultRevamp v2.1 Phase 8.3 §6.
///
/// Horizontal From/To rows using the `EnvelopeDepositBox` primitive so
/// the chips match Home visually. Amount in a FlipDigit chamber, quiet
/// keypad below, and a CTA that resolves its label from the selection
/// state ("Move $50.00 → Savings" when everything's picked, "Move money"
/// in titanium grey when anything's missing).
struct MoveMoneyView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let categories: [Category]
    var budget: Budget? = nil

    private var resolvedBudget: Budget? {
        budget ?? categories.first?.budget
    }

    @State private var fromCategory: Category?
    @State private var toCategory: Category?
    @State private var amountText = ""

    var body: some View {
        NavigationStack {
            ZStack {
                BudgetVaultTheme.navyDark.ignoresSafeArea()

                VStack(spacing: BudgetVaultTheme.spacingLG) {
                    envelopeSelectionStack
                        .padding(.horizontal, BudgetVaultTheme.spacingLG)

                    amountChamber
                        .padding(.horizontal, BudgetVaultTheme.spacingLG)

                    QuietKeypad(text: $amountText)
                        .padding(.horizontal, BudgetVaultTheme.spacingLG)

                    if exceedsAvailable {
                        Text("Exceeds remaining \(CurrencyFormatter.format(cents: fromRemainingCents))")
                            .font(.caption)
                            .foregroundStyle(BudgetVaultTheme.negative)
                    }

                    Spacer(minLength: 0)

                    ctaButton
                        .padding(.horizontal, BudgetVaultTheme.spacingLG)
                        .padding(.bottom, BudgetVaultTheme.spacingSM)
                }
                .padding(.top, BudgetVaultTheme.spacingMD)
            }
            .navigationTitle("Move Money")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(BudgetVaultTheme.navyDark, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .tint(BudgetVaultTheme.accentSoft)
                }
            }
        }
    }

    // MARK: - Envelope Selection

    @ViewBuilder
    private var envelopeSelectionStack: some View {
        VStack(alignment: .leading, spacing: BudgetVaultTheme.spacingSM) {
            EngravedSectionHeader(title: "From")
            envelopeRow(isFrom: true)

            HStack {
                Spacer()
                Image(systemName: "arrow.down")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(BudgetVaultTheme.titanium500)
                Spacer()
            }

            EngravedSectionHeader(title: "To")
            envelopeRow(isFrom: false)
        }
    }

    @ViewBuilder
    private func envelopeRow(isFrom: Bool) -> some View {
        // Phase 8.3 §6.1: 3-across HStack. Dynamic Type xxxLarge may
        // need horizontal scroll — wrap ScrollView when the row gets
        // too wide for the layout. We accept the intrinsic xxxLarge
        // compromise here; the envelope tiles self-truncate their
        // names.
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(categories, id: \.id) { cat in
                    envelopeTile(category: cat, isFrom: isFrom)
                        .frame(width: 108)
                }
            }
        }
    }

    @ViewBuilder
    private func envelopeTile(category: Category, isFrom: Bool) -> some View {
        let isSelected = isFrom
            ? fromCategory?.id == category.id
            : toCategory?.id == category.id
        let isOtherSelection = isFrom
            ? toCategory?.id == category.id
            : fromCategory?.id == category.id
        let shouldDim = !isSelected && (isFrom
            ? fromCategory != nil
            : toCategory != nil)

        Button {
            HapticManager.impact(.light)
            if isFrom {
                fromCategory = category
                if toCategory?.id == category.id { toCategory = nil }
            } else {
                toCategory = category
            }
        } label: {
            EnvelopeDepositBox(
                name: category.name,
                spent: Decimal(category.budgetedAmountCents) / 100,
                allocated: Decimal(
                    resolvedBudget.map { category.remainingCents(in: $0) } ?? category.budgetedAmountCents
                ) / 100,
                pipColor: Color(hex: category.color)
            )
            .overlay(
                RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusSM)
                    .strokeBorder(
                        isSelected ? BudgetVaultTheme.electricBlue : Color.clear,
                        lineWidth: 2
                    )
            )
            // Mockup §6 line 93: `box-shadow: 0 0 0 2px rgba(37,99,235,0.2)`
            // — a sharp 2pt outer ring, not a soft blur. Read as a
            // selection outline (like a focused text field) rather than
            // a glow halo.
            .overlay(
                RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusSM)
                    .strokeBorder(
                        isSelected ? BudgetVaultTheme.electricBlue.opacity(0.2) : Color.clear,
                        lineWidth: 4
                    )
                    .blur(radius: 0)
                    .padding(-2)
            )
            .opacity(isOtherSelection ? 0.35 : (shouldDim ? 0.55 : 1))
        }
        .buttonStyle(.plain)
        .disabled(isOtherSelection)
        .accessibilityLabel("\(isFrom ? "From" : "To") \(category.name)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Amount Chamber

    @ViewBuilder
    private var amountChamber: some View {
        ChamberCard(padding: 16) {
            VStack(spacing: 8) {
                Text("AMOUNT")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(2.6)
                    .foregroundStyle(BudgetVaultTheme.titanium400)

                FlipDigitDisplay(
                    amount: amountDecimal,
                    style: .large,
                    currencyCode: currencyCode,
                    contextLabel: "Amount entered"
                )
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var amountDecimal: Decimal {
        let cents = parsedCents
        return Decimal(cents) / 100
    }

    private var currencyCode: String {
        UserDefaults.standard.string(forKey: AppStorageKeys.selectedCurrency) ?? "USD"
    }

    // MARK: - CTA

    @ViewBuilder
    private var ctaButton: some View {
        Button {
            moveMoney()
        } label: {
            Text(ctaLabel)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(canMove ? .white : BudgetVaultTheme.titanium500)
                .frame(maxWidth: .infinity)
                .padding(17)
        }
        .background(
            Group {
                if canMove {
                    LinearGradient(
                        colors: [BudgetVaultTheme.brightBlue, BudgetVaultTheme.electricBlue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                } else {
                    BudgetVaultTheme.titanium700.opacity(0.35)
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(
            color: canMove ? BudgetVaultTheme.electricBlue.opacity(0.4) : .clear,
            radius: canMove ? 12 : 0,
            y: 4
        )
        .disabled(!canMove)
        .accessibilityLabel(ctaLabel)
    }

    private var ctaLabel: String {
        guard let from = fromCategory, let to = toCategory, parsedCents > 0 else {
            return "Move money"
        }
        guard from.id != to.id else { return "Move money" }
        return "Move \(CurrencyFormatter.format(cents: parsedCents)) \u{2192} \(to.name)"
    }

    // MARK: - Helpers

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
        guard SafeSave.save(modelContext) else {
            from.budgetedAmountCents += cents
            to.budgetedAmountCents -= cents
            modelContext.rollback()
            return
        }
        HapticManager.notification(.success)
        dismiss()
    }
}
