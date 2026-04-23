import SwiftUI
import BudgetVaultShared

/// Stacked deposit-box envelope used on the Home dashboard (Needs, Wants,
/// Savings row). Navy gradient body, titanium top edge (the "deposit box
/// lid"), colored pip in the top-right, mono amount row, and a thin fill
/// bar at the bottom showing spent/allocated progress.
struct EnvelopeDepositBox: View {
    let name: String
    let spent: Decimal
    let allocated: Decimal
    let pipColor: Color

    @ScaledMetric(relativeTo: .body) private var scale: CGFloat = 1.0

    private var progressFraction: Double {
        guard allocated > 0 else { return 0 }
        let ratio = NSDecimalNumber(decimal: spent / allocated).doubleValue
        return max(0, min(ratio, 1.0))
    }

    private var spentCents: Int64 {
        Int64(truncating: (spent * 100) as NSDecimalNumber)
    }

    private var allocatedCents: Int64 {
        Int64(truncating: (allocated * 100) as NSDecimalNumber)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Titanium top lid (3pt)
            Rectangle()
                .fill(BudgetVaultTheme.titanium300)
                .frame(height: 3)

            VStack(alignment: .leading, spacing: 8 * scale) {
                HStack {
                    // Audit 2026-04-23 A11y P1: name + sublabel ignored
                    // Dynamic Type; scale with the rest of the envelope.
                    Text(name)
                        .font(.system(size: 11 * scale, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                    Spacer()
                    Circle()
                        .fill(pipColor)
                        .frame(width: 6, height: 6)
                        .accessibilityHidden(true)
                }

                Spacer(minLength: 4)

                Text(CurrencyFormatter.format(cents: spentCents))
                    .font(BudgetVaultTheme.flipDigitFont(size: 22 * scale))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                // Audit 2026-04-22 P1-37: was 10pt @ 0.55 opacity (3.9:1
                // on navy — fails WCAG body-text contrast). Raise opacity
                // to 0.75 so the ratio clears 4.5:1.
                // Audit 2026-04-23 A11y P1: also scale with Dynamic Type.
                Text("of \(CurrencyFormatter.format(cents: allocatedCents))")
                    .font(.system(size: 10 * scale, weight: .medium))
                    .foregroundStyle(.white.opacity(0.75))

                // Progress bar — 2pt, pipColor fill over pipColor @ 18% bg
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(pipColor.opacity(0.18))
                        .frame(height: 2)
                    GeometryReader { geo in
                        Capsule()
                            .fill(pipColor)
                            .frame(width: geo.size.width * progressFraction, height: 2)
                    }
                    .frame(height: 2)
                }
            }
            .padding(12 * scale)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(
            LinearGradient(
                colors: [BudgetVaultTheme.navyMid, BudgetVaultTheme.navyDark],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .overlay(
            Rectangle()
                .strokeBorder(BudgetVaultTheme.titanium700.opacity(0.4), lineWidth: 1)
        )
        .frame(height: 130 * scale)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name): \(CurrencyFormatter.format(cents: spentCents)) spent of \(CurrencyFormatter.format(cents: allocatedCents))")
    }
}

#Preview("EnvelopeDepositBox — three-up row") {
    HStack(spacing: 10) {
        EnvelopeDepositBox(
            name: "Needs",
            spent: 1240,
            allocated: 2000,
            pipColor: BudgetVaultTheme.accentSoft
        )
        EnvelopeDepositBox(
            name: "Wants",
            spent: 480,
            allocated: 600,
            pipColor: BudgetVaultTheme.neonOrange
        )
        EnvelopeDepositBox(
            name: "Savings",
            spent: 0,
            allocated: 800,
            pipColor: BudgetVaultTheme.neonGreen
        )
    }
    .padding()
    .background(BudgetVaultTheme.navyDark)
}
