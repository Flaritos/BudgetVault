import SwiftUI

/// Brushed titanium name-plate for the onboarding "Name your vault" screen.
/// Simulates a stamped metal surface with corner notches and engraved
/// (shadowed) typography. Information-carrying — exposes the typed name
/// via accessibilityLabel; character counter decorative.
struct EngravingPlate: View {
    let text: String
    var characterLimit: Int = 24
    var showCounter: Bool = true

    @ScaledMetric(relativeTo: .title) private var scale: CGFloat = 1.0

    var body: some View {
        VStack(spacing: 10 * scale) {
            plateBody
            if showCounter { counter }
        }
    }

    private var plateBody: some View {
        ZStack {
            // Brushed titanium background
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [BudgetVaultTheme.titanium200, BudgetVaultTheme.titanium400],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            // Subtle vertical brush texture (1px lines at 5% white every 3px)
            BrushTexture()
                .foregroundStyle(.white.opacity(0.05))
                .blendMode(.plusLighter)

            // Corner notches (L-shaped brackets)
            CornerNotches()
                .stroke(BudgetVaultTheme.titanium700, lineWidth: 1)

            // Engraved text
            Text(text.isEmpty ? " " : text)
                .font(.system(size: 24 * scale, weight: .bold))
                .foregroundStyle(BudgetVaultTheme.titanium800)
                .shadow(color: .black.opacity(0.20), radius: 0, x: 0, y: -1)
                .accessibilityLabel(text.isEmpty ? "Empty vault name plate" : "Vault name: \(text)")
                .padding(.horizontal, 24 * scale)
                .padding(.vertical, 18 * scale)
        }
        .frame(minHeight: 64 * scale)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(BudgetVaultTheme.titanium700, lineWidth: 1)
        )
    }

    private var counter: some View {
        Text("\(text.count) / \(characterLimit)")
            .font(BudgetVaultTheme.flipDigitFont(size: 12 * scale))
            .foregroundStyle(BudgetVaultTheme.titanium600.opacity(0.75))
            .accessibilityHidden(true)
    }
}

// MARK: - Brush texture (vertical hair-lines, very low opacity)

private struct BrushTexture: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        var x: CGFloat = 0
        while x < rect.width {
            p.move(to: CGPoint(x: x, y: rect.minY))
            p.addLine(to: CGPoint(x: x, y: rect.maxY))
            x += 3
        }
        return p.strokedPath(StrokeStyle(lineWidth: 1))
    }
}

// MARK: - Corner notches (L-shaped brackets, 8pt leg, inset 6pt)

private struct CornerNotches: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let inset: CGFloat = 6
        let leg: CGFloat = 8

        // Top-left
        p.move(to: CGPoint(x: rect.minX + inset, y: rect.minY + inset + leg))
        p.addLine(to: CGPoint(x: rect.minX + inset, y: rect.minY + inset))
        p.addLine(to: CGPoint(x: rect.minX + inset + leg, y: rect.minY + inset))

        // Top-right
        p.move(to: CGPoint(x: rect.maxX - inset - leg, y: rect.minY + inset))
        p.addLine(to: CGPoint(x: rect.maxX - inset, y: rect.minY + inset))
        p.addLine(to: CGPoint(x: rect.maxX - inset, y: rect.minY + inset + leg))

        // Bottom-left
        p.move(to: CGPoint(x: rect.minX + inset, y: rect.maxY - inset - leg))
        p.addLine(to: CGPoint(x: rect.minX + inset, y: rect.maxY - inset))
        p.addLine(to: CGPoint(x: rect.minX + inset + leg, y: rect.maxY - inset))

        // Bottom-right
        p.move(to: CGPoint(x: rect.maxX - inset - leg, y: rect.maxY - inset))
        p.addLine(to: CGPoint(x: rect.maxX - inset, y: rect.maxY - inset))
        p.addLine(to: CGPoint(x: rect.maxX - inset, y: rect.maxY - inset - leg))

        return p
    }
}

#Preview("EngravingPlate — variants") {
    VStack(spacing: 24) {
        EngravingPlate(text: "")
        EngravingPlate(text: "Emma's Vault")
        EngravingPlate(text: "The Household")
        EngravingPlate(text: "Savings", showCounter: false)
    }
    .padding()
    .background(BudgetVaultTheme.navyDark)
}
