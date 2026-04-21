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

                // Envelope selection scrolls if it exceeds available
                // space (large Dynamic Type or unusually tall tiles).
                // The amount chamber + keypad + CTA live in a pinned
                // bottom stack so they're always visible — nothing
                // silently clips.
                ScrollView {
                    envelopeSelectionStack
                        .padding(.horizontal, BudgetVaultTheme.spacingLG)
                        .padding(.top, BudgetVaultTheme.spacingMD)
                        .padding(.bottom, BudgetVaultTheme.spacingSM)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: BudgetVaultTheme.spacingSM) {
                    amountChamber
                        .padding(.horizontal, BudgetVaultTheme.spacingLG)

                    QuietKeypad(text: $amountText)
                        .padding(.horizontal, BudgetVaultTheme.spacingLG)

                    if exceedsAvailable {
                        Text("Exceeds remaining \(CurrencyFormatter.format(cents: fromRemainingCents))")
                            .font(.caption)
                            .foregroundStyle(BudgetVaultTheme.negative)
                    }

                    ctaButton
                        .padding(.horizontal, BudgetVaultTheme.spacingLG)
                        .padding(.bottom, BudgetVaultTheme.spacingSM)
                }
                .padding(.top, BudgetVaultTheme.spacingSM)
                .background(BudgetVaultTheme.navyDark)
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
        // Mockup §6 line 75–78: `.envelope-row { display: flex; gap: 6px;
        // margin-bottom: 24px }` with each .envelope at `flex: 1`. Equal-
        // width 3-up grid, not a horizontal scroll. Compact tile
        // geometry keeps the screen from overflowing.
        HStack(spacing: 6) {
            ForEach(categories.prefix(3), id: \.id) { cat in
                envelopeTile(category: cat, isFrom: isFrom)
                    .frame(maxWidth: .infinity)
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

        let pipColor = Color(hex: category.color)
        let remainingCents: Int64 = {
            if let b = resolvedBudget {
                return category.remainingCents(in: b)
            }
            return category.budgetedAmountCents
        }()
        let budgetedCents = category.budgetedAmountCents
        let progress: Double = {
            guard budgetedCents > 0 else { return 0 }
            let spent = max(0, budgetedCents - remainingCents)
            return min(1.0, Double(spent) / Double(budgetedCents))
        }()

        Button {
            HapticManager.impact(.light)
            if isFrom {
                fromCategory = category
                if toCategory?.id == category.id { toCategory = nil }
            } else {
                toCategory = category
            }
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .topTrailing) {
                    // Mockup line 98–101: 6pt colored pip in top-right
                    // corner; absolute-positioned in CSS, realized here
                    // as an overlay on the ZStack.
                    VStack(alignment: .leading, spacing: 3) {
                        Text(category.name)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .padding(.top, 4)

                        Text(CurrencyFormatter.format(cents: remainingCents))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.42))
                            .lineLimit(1)

                        // Mockup line 110–114: 2pt fill bar with 8pt
                        // top margin; 18%-pip bg + pip-fill showing
                        // spent ratio.
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(pipColor.opacity(0.18))
                                    .frame(height: 2)
                                Capsule()
                                    .fill(pipColor)
                                    .frame(width: max(0, geo.size.width * progress), height: 2)
                            }
                        }
                        .frame(height: 2)
                        .padding(.top, 6)
                    }
                    .padding(10)

                    Circle()
                        .fill(pipColor)
                        .frame(width: 6, height: 6)
                        .padding(8)
                }
            }
            .background(
                LinearGradient(
                    colors: [Color(hex: "#1A2744"), BudgetVaultTheme.navyDark],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(alignment: .top) {
                // Mockup line 83: 3pt titanium top border — the
                // "deposit box lid." Selected state brightens to
                // titanium100 (line 92).
                Rectangle()
                    .fill(isSelected ? BudgetVaultTheme.titanium100 : BudgetVaultTheme.titanium300)
                    .frame(height: 3)
            }
            .overlay(
                // Mockup line 82: ti-700 stroke on unselected,
                // replaced by 2pt blue stroke on selected (line 91).
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(
                        isSelected ? BudgetVaultTheme.electricBlue : BudgetVaultTheme.titanium700,
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 6))
            // Mockup line 93: `box-shadow: 0 0 0 2px rgba(37,99,235,0.2)`
            // — sharp 2pt outer ring on selected. Simulated with a
            // wider stroke outside the clip shape.
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(
                        isSelected ? BudgetVaultTheme.electricBlue.opacity(0.2) : .clear,
                        lineWidth: 2
                    )
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
