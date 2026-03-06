import SwiftUI

struct PrimaryButtonStyle: ButtonStyle {
    var isEnabled: Bool = true
    var useGradient: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding()
            .background(isEnabled ? AnyShapeStyle(useGradient ? AnyShapeStyle(BudgetVaultTheme.brandGradient) : AnyShapeStyle(Color.accentColor)) : AnyShapeStyle(Color.gray), in: RoundedRectangle(cornerRadius: 12))
            .foregroundStyle(.white)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}
