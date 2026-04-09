import SwiftUI

/// Secondary button style used for "Save & Add Another" and similar secondary actions.
/// Displays a tinted background with accent-colored text.
struct SecondaryButtonStyle: ButtonStyle {
    var isEnabled: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline)
            .frame(maxWidth: .infinity)
            .padding(10)
            .background(
                isEnabled ? Color.accentColor.opacity(0.15) : Color.gray.opacity(0.1),
                in: RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusButton)
            )
            .foregroundStyle(isEnabled ? Color.accentColor : .gray)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}
