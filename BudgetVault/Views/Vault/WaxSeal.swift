import SwiftUI

/// Circular wax seal used on no-spend day rows in the History screen.
/// Reads as pressed-wax with molten-red gradient + lock glyph.
/// Information-carrying — exposes "No-spend day" to VoiceOver.
struct WaxSeal: View {
    @ScaledMetric(relativeTo: .body) private var size: CGFloat = 26

    var body: some View {
        ZStack {
            // Molten radial gradient: highlight top-left → red mid → shadow edge
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            BudgetVaultTheme.waxSealHighlight,
                            BudgetVaultTheme.waxSealRed,
                            BudgetVaultTheme.waxSealShadow
                        ],
                        center: UnitPoint(x: 0.35, y: 0.35),
                        startRadius: 0,
                        endRadius: size * 0.7
                    )
                )
                .overlay(
                    Circle()
                        .strokeBorder(BudgetVaultTheme.waxSealShadow, lineWidth: 1)
                )
                // Subtle molten-inner highlight
                .overlay(
                    Circle()
                        .inset(by: 2)
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.20), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .frame(width: size, height: size)

            Image(systemName: "lock.fill")
                .font(.system(size: size * 0.42, weight: .bold))
                .foregroundStyle(.white.opacity(0.9))
        }
        .accessibilityElement()
        .accessibilityLabel("No-spend day")
    }
}

#Preview("WaxSeal — sizes via Dynamic Type") {
    VStack(spacing: 20) {
        WaxSeal()
        WaxSeal().dynamicTypeSize(.accessibility3)
        WaxSeal().dynamicTypeSize(.accessibility5)
    }
    .padding()
    .background(BudgetVaultTheme.ledgerPaperLight)
}
