import SwiftUI

/// Quiet everyday keypad for fast expense entry. Deliberately lighter
/// visually than TitaniumKeypad so the user's focus stays on what they're
/// logging, not on the tool. Hairline titanium border on near-transparent
/// background, no inset highlights, no gradient fills.
///
/// API matches TitaniumKeypad so consumers can swap between them by type
/// only.
struct QuietKeypad: View {
    @Binding var text: String
    var allowDecimal: Bool = true
    var onBackspace: (() -> Void)? = nil

    @ScaledMetric(relativeTo: .title2) private var keyWidth: CGFloat = 104
    @ScaledMetric(relativeTo: .title2) private var keyHeight: CGFloat = 52

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
        if text == "0" { text = "" }
        text += digit
    }

    @ViewBuilder
    private func key(
        label: String,
        systemImage: String? = nil,
        enabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(BudgetVaultTheme.titanium300.opacity(0.06))
                Group {
                    if let systemImage {
                        Image(systemName: systemImage)
                            .font(.system(size: 20, weight: .medium))
                    } else {
                        Text(label)
                            .font(.system(size: 26, weight: .medium, design: .rounded))
                    }
                }
                .foregroundStyle(.white)
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

#Preview("QuietKeypad") {
    struct Host: View {
        @State var text = ""
        var body: some View {
            VStack(spacing: 20) {
                Text(text.isEmpty ? "0" : text)
                    .font(.system(size: 44, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white)
                QuietKeypad(text: $text)
            }
            .padding()
            .background(BudgetVaultTheme.navyDark)
        }
    }
    return Host()
}
