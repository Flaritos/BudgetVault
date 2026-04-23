import SwiftUI

/// Uppercase titanium section-header label with heavy letterspacing —
/// the stamped-metal equivalent of an iOS-default section header.
///
/// Phase 8.2 rationale: iOS-default `Form` section headers render as
/// small-caps secondary text. Under forced dark mode this reads as
/// generic system chrome and doesn't match the VaultRevamp language.
/// This primitive reskins the header without disturbing the `Form`
/// structure — users still get `Section { … } header: { … }` semantics
/// (accessibility, collapse behavior, spacing) but the text itself
/// looks like the engraved labels elsewhere in the app (Vault tab,
/// Onboarding, History month badges).
struct EngravedSectionHeader: View {
    let title: String

    // Audit 2026-04-22 P1-37: fixed 11pt + uppercase tracking wasn't
    // scaling under AX sizes — engraved plate labels stayed tiny even
    // when the rest of the screen grew. Anchor to .caption2 so the
    // engraved chrome keeps its hierarchy relative to body copy.
    @ScaledMetric(relativeTo: .caption2) private var headerFontSize: CGFloat = 11

    var body: some View {
        Text(title)
            .font(.system(size: headerFontSize, weight: .semibold))
            .textCase(.uppercase)
            .tracking(2.4)
            .foregroundStyle(BudgetVaultTheme.titanium300)
            .padding(.top, 20)
            .padding(.bottom, 8)
            .accessibilityAddTraits(.isHeader)
    }
}

#Preview("EngravedSectionHeader inside Form") {
    Form {
        Section {
            Text("Row content")
            Text("Another row")
        } header: {
            EngravedSectionHeader(title: "Security")
        }

        Section {
            Toggle("Daily Reminder", isOn: .constant(true))
                .tint(BudgetVaultTheme.electricBlue)
        } header: {
            EngravedSectionHeader(title: "Notifications")
        }
    }
    .scrollContentBackground(.hidden)
    .background(BudgetVaultTheme.navyDark)
    .preferredColorScheme(.dark)
}
