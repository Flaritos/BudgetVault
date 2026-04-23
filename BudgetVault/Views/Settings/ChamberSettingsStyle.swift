import SwiftUI

// Audit 2026-04-23 Settings redesign (Option A — Chamber Panels).
// Replaces stock iOS `Label` rendering inside Settings with a
// role-tinted icon tile + title pair, matching the mockup at
// `docs/settings-mockups/index.html`.
//
// Kept in a dedicated file so the 1000-line `SettingsView` stays
// focused on state + section composition. The style applies via
// `.labelStyle(ChamberLabelStyle())`, which hooks into existing
// `Label("Text", systemImage: "symbol")` call sites without
// rewriting each row.

enum ChamberRole {
    case standard
    case destructive
    case premium   // Paid-feature row — amber tile.
    case positive  // Safe, value-producing row (Export) — green tile.
    case info      // iCloud / diagnostics — electric blue.

    var tint: Color {
        switch self {
        case .standard:    return BudgetVaultTheme.accentSoft
        case .destructive: return BudgetVaultTheme.negative
        case .premium:     return BudgetVaultTheme.caution
        case .positive:    return BudgetVaultTheme.positive
        case .info:        return BudgetVaultTheme.electricBlue
        }
    }
}

struct ChamberLabelStyle: LabelStyle {
    var role: ChamberRole = .standard

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 12) {
            configuration.icon
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(role.tint)
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(role.tint.opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(role.tint.opacity(0.22), lineWidth: 1)
                )
            configuration.title
                .foregroundStyle(
                    role == .destructive
                        ? BudgetVaultTheme.negative
                        : BudgetVaultTheme.bodyOnDark
                )
        }
    }
}

extension View {
    /// Apply Chamber Panel styling to a Settings Form row (gradient
    /// background + role-tinted tile icon). Default role = `.standard`.
    func chamberSettingsRow(role: ChamberRole = .standard) -> some View {
        self
            .labelStyle(ChamberLabelStyle(role: role))
            .listRowBackground(BudgetVaultTheme.chamberRowGradient)
    }
}
