import SwiftUI

struct NumberPadKeyStyle: ButtonStyle {
    var isDelete: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                Color.secondary.opacity(isDelete ? 0.12 : 0.08),
                in: RoundedRectangle(cornerRadius: 10)
            )
            .scaleEffect(configuration.isPressed ? 0.93 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct NumberPadView: View {
    @Binding var text: String

    private let buttons: [[String]] = [
        ["1", "2", "3"],
        ["4", "5", "6"],
        ["7", "8", "9"],
        [".", "0", "delete.backward"],
    ]

    var body: some View {
        Grid(horizontalSpacing: 16, verticalSpacing: 12) {
            ForEach(buttons, id: \.self) { row in
                GridRow {
                    ForEach(row, id: \.self) { key in
                        Button {
                            handleTap(key)
                        } label: {
                            if key == "delete.backward" {
                                Image(systemName: "delete.backward")
                                    .font(.title2)
                                    .frame(maxWidth: .infinity, minHeight: 52)
                            } else {
                                Text(key)
                                    .font(.title.bold())
                                    .frame(maxWidth: .infinity, minHeight: 52)
                            }
                        }
                        .buttonStyle(NumberPadKeyStyle(isDelete: key == "delete.backward"))
                        .foregroundStyle(.primary)
                        .accessibilityLabel(accessibilityLabel(for: key))
                    }
                }
            }
        }
    }

    private func handleTap(_ key: String) {
        HapticManager.impact(.light)

        if key == "delete.backward" {
            if !text.isEmpty { text.removeLast() }
            return
        }

        if key == "." {
            if text.contains(".") { return }
            if text.isEmpty { text = "0" }
            text.append(".")
            return
        }

        // Max 2 decimal places
        if let dotIndex = text.firstIndex(of: ".") {
            let decimals = text[text.index(after: dotIndex)...]
            if decimals.count >= 2 { return }
        }

        // Prevent leading zeros (except "0.")
        if text == "0" && key != "." {
            text = key
            return
        }

        text.append(key)
    }

    private func accessibilityLabel(for key: String) -> String {
        switch key {
        case "delete.backward": "Backspace"
        case ".": "Decimal point"
        case "0": "Zero"
        case "1": "One"
        case "2": "Two"
        case "3": "Three"
        case "4": "Four"
        case "5": "Five"
        case "6": "Six"
        case "7": "Seven"
        case "8": "Eight"
        case "9": "Nine"
        default: key
        }
    }
}
