import SwiftUI

/// Full-weight titanium numeric keypad — used in the onboarding income
/// ceremony where the metal earns the visual weight. Everyday expense
/// entry uses QuietKeypad instead.
///
/// Binding pattern: appends digits/decimal to `text`, backspace trims
/// the last character. Enforces max one decimal point. Decorative chrome
/// is accessibility-hidden; only the 12 buttons are exposed with digit-
/// word labels ("One", "Two", etc.) for VoiceOver.
struct TitaniumKeypad: View {
    @Binding var text: String
    var allowDecimal: Bool = true
    var onBackspace: (() -> Void)? = nil

    @ScaledMetric(relativeTo: .title2) private var keyWidth: CGFloat = 104
    @ScaledMetric(relativeTo: .title2) private var keyHeight: CGFloat = 56
    // Audit 2026-04-22 P1-37: glyph sizes scale with Dynamic Type.
    @ScaledMetric(relativeTo: .title2) private var keypadIconSize: CGFloat = 22
    @ScaledMetric(relativeTo: .title2) private var keypadLabelSize: CGFloat = 28

    private let digits: [[String]] = [
        ["1", "2", "3"],
        ["4", "5", "6"],
        ["7", "8", "9"]
    ]

    var body: some View {
        VStack(spacing: 10) {
            ForEach(digits, id: \.self) { row in
                HStack(spacing: 10) {
                    ForEach(row, id: \.self) { digit in
                        key(label: digit) { append(digit) }
                    }
                }
            }
            HStack(spacing: 10) {
                key(label: ".", enabled: allowDecimal && !text.contains(".")) {
                    if !text.contains(".") {
                        if text.isEmpty { text = "0." } else { text += "." }
                    }
                }
                key(label: "0") { append("0") }
                key(label: "⌫", systemImage: "delete.backward") {
                    if !text.isEmpty {
                        text.removeLast()
                        onBackspace?()
                    }
                }
            }
        }
    }

    private func append(_ digit: String) {
        // Strip leading zero unless followed by a decimal
        if text == "0" { text = "" }
        text += digit
    }

    // MARK: - Key

    @ViewBuilder
    private func key(
        label: String,
        systemImage: String? = nil,
        enabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            ZStack {
                // Brushed titanium face
                RoundedRectangle(cornerRadius: 10)
                    .fill(BudgetVaultTheme.titaniumBrushed)
                // Inset top highlight
                RoundedRectangle(cornerRadius: 10)
                    .inset(by: 1)
                    .stroke(.white.opacity(0.25), lineWidth: 1)
                    .mask(
                        LinearGradient(
                            colors: [.white, .clear],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
                // Inset bottom shadow
                RoundedRectangle(cornerRadius: 10)
                    .inset(by: 1)
                    .stroke(.black.opacity(0.35), lineWidth: 1)
                    .mask(
                        LinearGradient(
                            colors: [.clear, .black],
                            startPoint: .center,
                            endPoint: .bottom
                        )
                    )
                // Audit 2026-04-22 P1-37: glyph sizes scale with Dynamic Type.
                Group {
                    if let systemImage {
                        Image(systemName: systemImage)
                            .font(.system(size: keypadIconSize, weight: .semibold))
                    } else {
                        Text(label)
                            .font(.system(size: keypadLabelSize, weight: .semibold, design: .rounded))
                    }
                }
                .foregroundStyle(BudgetVaultTheme.titanium800)
            }
        }
        .buttonStyle(.plain)
        .frame(width: keyWidth, height: keyHeight)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(BudgetVaultTheme.titanium700, lineWidth: 1)
        )
        .opacity(enabled ? 1 : 0.35)
        .disabled(!enabled)
        .accessibilityLabel(accessibilityLabel(for: label))
    }

    private func accessibilityLabel(for label: String) -> String {
        switch label {
        case "0": return "Zero"
        case "1": return "One"
        case "2": return "Two"
        case "3": return "Three"
        case "4": return "Four"
        case "5": return "Five"
        case "6": return "Six"
        case "7": return "Seven"
        case "8": return "Eight"
        case "9": return "Nine"
        case ".": return "Decimal point"
        case "⌫": return "Backspace"
        default: return label
        }
    }
}

#Preview("TitaniumKeypad") {
    struct Host: View {
        @State var text = ""
        var body: some View {
            VStack(spacing: 20) {
                Text(text.isEmpty ? "0" : text)
                    .font(.system(size: 44, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white)
                TitaniumKeypad(text: $text)
            }
            .padding()
            .background(BudgetVaultTheme.navyDark)
        }
    }
    return Host()
}
