import SwiftUI

struct PrimaryButtonStyle: ButtonStyle {
    var isEnabled: Bool = true
    var useGradient: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding()
            // v3.2 audit M4: disabled state was flat Color.gray which felt
            // Android/system-default. Navy at reduced opacity keeps the
            // brand feel through the disabled state.
            .background(
                isEnabled
                    ? AnyShapeStyle(useGradient ? AnyShapeStyle(BudgetVaultTheme.brandGradient) : AnyShapeStyle(Color.accentColor))
                    : AnyShapeStyle(BudgetVaultTheme.navyDark.opacity(0.35)),
                in: RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusButton)
            )
            .foregroundStyle(.white.opacity(isEnabled ? 1.0 : 0.7))
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}
