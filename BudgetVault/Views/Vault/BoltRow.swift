import SwiftUI

/// A row of vault-door bolts. Used for onboarding step progress and pledge
/// confirmations. Engaged bolts read as "secured" in electric blue; retracted
/// as titanium discs. Fully decorative — the step progress is elsewhere.
struct BoltRow: View {
    enum BoltSize {
        case small   // 10pt — inline
        case medium  // 18pt — standard
        case large   // 24pt — hero

        var dimension: CGFloat {
            switch self {
            case .small: return 10
            case .medium: return 18
            case .large: return 24
            }
        }

        var spacingRatio: CGFloat { 0.55 }
    }

    let count: Int
    let engaged: Int
    var size: BoltSize = .medium
    /// Audit 2026-04-23 Max Audit P1-34: pass a non-nil string when the
    /// BoltRow represents actual step progress (onboarding). Leave nil
    /// for decorative uses (Dashboard header) — the row becomes
    /// `.accessibilityHidden(true)` so VO doesn't announce phantom steps.
    var stepLabel: String? = nil

    @ScaledMetric(relativeTo: .body) private var scale: CGFloat = 1.0

    var body: some View {
        HStack(spacing: size.dimension * size.spacingRatio * scale) {
            ForEach(0..<count, id: \.self) { index in
                bolt(engaged: index < engaged)
            }
        }
        // Audit 2026-04-23 Max Audit P1-34: prior version hard-coded
        // "Step X of Y" + .updatesFrequently, so the decorative 3/3
        // BoltRow on Home hero announced "Step 3 of 3, updates
        // frequently" — onboarding semantics leaking onto Dashboard.
        // Now: default to hidden (decorative). Callers that DO mean
        // progress (onboarding) pass `stepLabel:` explicitly.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(stepLabel ?? "")
        .accessibilityHidden(stepLabel == nil)
        .accessibilityAddTraits(stepLabel != nil ? .updatesFrequently : [])
    }

    private func bolt(engaged: Bool) -> some View {
        let dim = size.dimension * scale
        return ZStack {
            Circle()
                .fill(
                    engaged
                    ? RadialGradient(
                        colors: [BudgetVaultTheme.electricBlue, BudgetVaultTheme.navyDark],
                        center: UnitPoint(x: 0.3, y: 0.3),
                        startRadius: 0,
                        endRadius: dim * 0.7
                    )
                    : RadialGradient(
                        colors: [BudgetVaultTheme.titanium100, BudgetVaultTheme.titanium700],
                        center: UnitPoint(x: 0.3, y: 0.3),
                        startRadius: 0,
                        endRadius: dim * 0.7
                    )
                )
                .overlay(
                    Circle()
                        .strokeBorder(
                            engaged ? BudgetVaultTheme.navyDark : BudgetVaultTheme.titanium800,
                            lineWidth: 1
                        )
                )
                .frame(width: dim, height: dim)

            // Drilled-hole inner ring (4pt inset creating the bolt look)
            Circle()
                .strokeBorder(.black.opacity(0.25), lineWidth: 1)
                .frame(width: dim - 4, height: dim - 4)
        }
    }
}

#Preview("BoltRow — sizes and engagement states") {
    VStack(spacing: 32) {
        Group {
            Text("Small · 4 of 4 engaged").font(.caption).foregroundStyle(.white.opacity(0.7))
            BoltRow(count: 4, engaged: 4, size: .small)

            Text("Medium · 2 of 4 engaged").font(.caption).foregroundStyle(.white.opacity(0.7))
            BoltRow(count: 4, engaged: 2, size: .medium)

            Text("Large · 0 of 4 engaged").font(.caption).foregroundStyle(.white.opacity(0.7))
            BoltRow(count: 4, engaged: 0, size: .large)

            Text("Medium · 6 of 7 engaged").font(.caption).foregroundStyle(.white.opacity(0.7))
            BoltRow(count: 7, engaged: 6, size: .medium)
        }
    }
    .padding()
    .background(BudgetVaultTheme.navyDark)
}
