import SwiftUI

/// Tappable button styled as a `VaultDial` with a custom center glyph.
/// Used for the pair of primary Dashboard actions — new transaction
/// entry and "close today's vault" (no-spend day).
///
/// The button renders a `VaultDial(.medium, .locked)` (no numerals) and
/// overlays the caller-supplied `centerContent` at the boss position.
/// The dial bezel, ticks, and pointer are shared with the rest of the
/// app's vault chrome — two dial-buttons side-by-side read as a matched
/// pair rather than as two unrelated controls.
///
/// Phase 8.1 rationale: the old `TitaniumPlusFAB` private struct
/// re-implemented ~90% of `VaultDial`'s rendering inline with raw hex
/// values, which drifted from the primitive and duplicated the
/// titanium/tick/pointer logic. This primitive composes the existing
/// `VaultDial` so any future change to the dial propagates here.
struct VaultDialButton<CenterContent: View>: View {
    let action: () -> Void
    var size: VaultDial.Size = .medium
    var showGlow: Bool = false
    @ViewBuilder let centerContent: () -> CenterContent

    var body: some View {
        Button(action: action) {
            ZStack {
                VaultDial(
                    size: size,
                    state: .locked,
                    showNumerals: false,
                    showGlow: showGlow
                )
                centerContent()
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview("VaultDialButton — glyph variants") {
    VStack(spacing: 40) {
        // Plus — Dashboard FAB glyph
        VaultDialButton(action: {}) {
            ZStack {
                Capsule()
                    .fill(BudgetVaultTheme.electricBlue)
                    .frame(width: 3, height: 22)
                Capsule()
                    .fill(BudgetVaultTheme.electricBlue)
                    .frame(width: 22, height: 3)
            }
        }

        // Moon — no-spend idle
        VaultDialButton(action: {}) {
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(BudgetVaultTheme.titanium200)
        }

        // Checkmark — no-spend closed (with glow)
        VaultDialButton(action: {}, showGlow: true) {
            Image(systemName: "checkmark")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(BudgetVaultTheme.positive)
        }
    }
    .padding(40)
    .background(BudgetVaultTheme.navyDark)
}
