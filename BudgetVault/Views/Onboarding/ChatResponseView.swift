import SwiftUI

// MARK: - Currency Chip Picker

struct CurrencyChipPicker: View {
    let onSelect: (String) -> Void
    @State private var showFullPicker = false

    private let quickCurrencies: [(code: String, flag: String)] = [
        ("USD", "\u{1F1FA}\u{1F1F8}"),
        ("EUR", "\u{1F1EA}\u{1F1FA}"),
        ("GBP", "\u{1F1EC}\u{1F1E7}"),
        ("CAD", "\u{1F1E8}\u{1F1E6}"),
        ("AUD", "\u{1F1E6}\u{1F1FA}"),
        ("JPY", "\u{1F1EF}\u{1F1F5}"),
    ]

    var body: some View {
        VStack(spacing: BudgetVaultTheme.spacingMD) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(quickCurrencies, id: \.code) { currency in
                        Button {
                            onSelect(currency.code)
                        } label: {
                            HStack(spacing: 6) {
                                Text(currency.flag)
                                    .font(.title3)
                                Text(currency.code)
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.white)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.12), in: Capsule())
                        }
                    }

                    Button {
                        showFullPicker = true
                    } label: {
                        Text("More...")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.06), in: Capsule())
                    }
                }
                .padding(.horizontal, BudgetVaultTheme.spacingLG)
            }
        }
        .sheet(isPresented: $showFullPicker) {
            NavigationStack {
                FullCurrencyPickerSheet(onSelect: onSelect)
            }
        }
    }
}

// MARK: - Full Currency Picker Sheet

private struct FullCurrencyPickerSheet: View {
    let onSelect: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var tempSelection = "USD"

    var body: some View {
        CurrencyPickerView(selectedCurrency: $tempSelection)
            .navigationTitle("Select Currency")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onSelect(tempSelection)
                        dismiss()
                    }
                }
            }
    }
}

// MARK: - Number Pad View

struct ChatNumberPadView: View {
    @Binding var text: String
    let currencySymbol: String

    private let keys: [[String]] = [
        ["1", "2", "3"],
        ["4", "5", "6"],
        ["7", "8", "9"],
        [".", "0", "\u{232B}"],
    ]

    var body: some View {
        VStack(spacing: BudgetVaultTheme.spacingMD) {
            // Display
            Text(CurrencyFormatter.displayAmount(text: text))
                .font(BudgetVaultTheme.amountEntry)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.bottom, BudgetVaultTheme.spacingSM)

            Text("Monthly take-home pay")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))

            // Pad
            VStack(spacing: BudgetVaultTheme.spacingSM) {
                ForEach(keys, id: \.self) { row in
                    HStack(spacing: BudgetVaultTheme.spacingSM) {
                        ForEach(row, id: \.self) { key in
                            Button {
                                handleKey(key)
                            } label: {
                                Text(key)
                                    .font(.title2.bold())
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 52)
                                    .background {
            RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusMD)
                .fill(Color.white.opacity(0.08))
        }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, BudgetVaultTheme.spacingXL)
        }
    }

    private func handleKey(_ key: String) {
        if key == "\u{232B}" {
            if !text.isEmpty {
                text.removeLast()
            }
        } else if key == "." {
            if !text.contains(".") {
                text += text.isEmpty ? "0." : "."
            }
        } else {
            // Limit decimal places to 2
            if let dotIndex = text.firstIndex(of: ".") {
                let decimals = text[text.index(after: dotIndex)...]
                if decimals.count >= 2 { return }
            }
            // Limit total length
            if text.count < 10 {
                text += key
            }
        }
    }
}

// MARK: - Template Picker Cards

struct ChatTemplatePicker: View {
    let onSelect: (BudgetTemplates.OnboardingTemplate) -> Void

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: BudgetVaultTheme.spacingMD) {
            ForEach(BudgetTemplates.OnboardingTemplate.allCases, id: \.rawValue) { template in
                Button {
                    onSelect(template)
                } label: {
                    VStack(spacing: BudgetVaultTheme.spacingSM) {
                        Image(systemName: template.icon)
                            .font(.title2)
                            .foregroundStyle(.white)

                        Text(template.rawValue)
                            .font(.subheadline.bold())
                            .foregroundStyle(.white)

                        if !template.categories.isEmpty {
                            Text("\(template.categories.count) categories")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.6))
                        } else {
                            Text("Start blank")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, BudgetVaultTheme.spacingLG)
                    .background(Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusLG))
                    .overlay(
                        RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusLG)
                            .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                    )
                }
            }
        }
        .padding(.horizontal, BudgetVaultTheme.spacingLG)
    }
}

// MARK: - Category Editor

struct ChatCategoryEditor: View {
    @Binding var categories: [(name: String, emoji: String, color: String, pct: Double)]
    let categoryLimit: Int
    @State private var editingIndex: Int?

    var body: some View {
        VStack(spacing: BudgetVaultTheme.spacingSM) {
            ForEach(Array(categories.enumerated()), id: \.offset) { index, _ in
                categoryRow(index: index)
            }

            if categories.count < categoryLimit {
                Button {
                    withAnimation(.easeOut(duration: 0.25)) {
                        categories.append(("New Category", "\u{1F4E6}", "#8E8E93", 0.05))
                    }
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Category")
                        Spacer()
                        Text("\(categories.count)/\(categoryLimit)")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(BudgetVaultTheme.spacingMD)
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusMD))
                }
            }
        }
        .padding(.horizontal, BudgetVaultTheme.spacingLG)
    }

    @ViewBuilder
    private func categoryRow(index: Int) -> some View {
        HStack(spacing: 10) {
            // Color dot
            Circle()
                .fill(Color(hex: categories[index].color))
                .frame(width: 10, height: 10)

            // Emoji
            Text(categories[index].emoji)
                .font(.title3)

            // Editable name
            TextField("Name", text: Binding(
                get: { categories[index].name },
                set: { categories[index].name = $0 }
            ))
            .font(.subheadline)
            .foregroundStyle(.white)
            .textFieldStyle(.plain)

            Spacer()

            // Percentage stepper
            HStack(spacing: 4) {
                Button {
                    if categories[index].pct > 0.05 {
                        categories[index].pct -= 0.05
                    }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.5))
                }

                Text("\(Int(categories[index].pct * 100))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.8))
                    .frame(width: 36)

                Button {
                    if categories[index].pct < 0.95 {
                        categories[index].pct += 0.05
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.5))
                }
            }

            // Delete
            Button {
                withAnimation(.easeOut(duration: 0.2)) {
                    let _ = categories.remove(at: index)
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.3))
            }
        }
        .padding(BudgetVaultTheme.spacingMD)
        .background {
            RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusMD)
                .fill(Color.white.opacity(0.08))
        }
    }
}

// MARK: - Yes/No Buttons

struct ChatYesNoButtons: View {
    let onYes: () -> Void
    let onNo: () -> Void

    var body: some View {
        HStack(spacing: BudgetVaultTheme.spacingMD) {
            Button {
                onYes()
            } label: {
                Text("Yes, remind me")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(BudgetVaultTheme.electricBlue, in: RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusMD))
            }

            Button {
                onNo()
            } label: {
                Text("Not now")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background {
            RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusMD)
                .fill(Color.white.opacity(0.08))
        }
            }
        }
        .padding(.horizontal, BudgetVaultTheme.spacingLG)
    }
}

// MARK: - Completion Button

struct ChatCompletionButton: View {
    let onComplete: () -> Void

    var body: some View {
        Button {
            onComplete()
        } label: {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                Text("Let's go!")
            }
            .font(.headline)
            .foregroundStyle(BudgetVaultTheme.navyDark)
            .frame(maxWidth: .infinity)
            .padding(.vertical, BudgetVaultTheme.spacingLG)
            .background(.white, in: RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusButton))
        }
        .padding(.horizontal, BudgetVaultTheme.spacingXL)
    }
}
