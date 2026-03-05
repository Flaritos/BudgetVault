import SwiftUI
import SwiftData

struct AddCategoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let budget: Budget

    @State private var name = ""
    @State private var emoji = "📦"
    @State private var color = "#007AFF"
    @State private var amountText = ""

    private let emojiOptions = ["📦", "🏠", "🛒", "🚗", "🎬", "💊", "📚", "🎮", "👕", "🐾", "✈️", "🍕", "☕", "🎵", "💇", "🏋️", "🎁", "📱", "🔧", "💡"]

    private let colorOptions = ["#007AFF", "#34C759", "#FF9500", "#FF2D55", "#5856D6", "#AF52DE", "#FF3B30", "#5AC8FA", "#FFCC00", "#8E8E93"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Category name", text: $name)
                }

                Section("Icon") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                        ForEach(emojiOptions, id: \.self) { e in
                            Button {
                                emoji = e
                                HapticManager.selection()
                            } label: {
                                Text(e)
                                    .font(.title2)
                                    .frame(width: 44, height: 44)
                                    .background(
                                        Circle()
                                            .strokeBorder(emoji == e ? Color.accentColor : Color.clear, lineWidth: 3)
                                    )
                            }
                            .accessibilityLabel(e)
                            .accessibilityAddTraits(emoji == e ? .isSelected : [])
                        }
                    }
                }

                Section("Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                        ForEach(colorOptions, id: \.self) { hex in
                            Button {
                                color = hex
                            } label: {
                                Circle()
                                    .fill(Color(hex: hex))
                                    .frame(width: 36, height: 36)
                                    .overlay(
                                        Circle()
                                            .strokeBorder(color == hex ? Color.primary : Color.clear, lineWidth: 3)
                                    )
                            }
                            .accessibilityLabel("Color \(hex)")
                            .accessibilityAddTraits(color == hex ? .isSelected : [])
                        }
                    }
                }

                Section("Monthly Budget") {
                    HStack {
                        Text(CurrencyFormatter.currencySymbol())
                            .foregroundStyle(.secondary)
                        TextField("0", text: $amountText)
                            .keyboardType(.decimalPad)
                            .font(.title3.bold())
                    }
                }
            }
            .navigationTitle("New Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addCategory()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func addCategory() {
        let cents = MoneyHelpers.parseCurrencyString(amountText) ?? 0
        let sortOrder = budget.categories.filter { !$0.isHidden }.count
        let category = Category(
            name: name.trimmingCharacters(in: .whitespaces),
            emoji: emoji,
            budgetedAmountCents: cents,
            color: color,
            sortOrder: sortOrder
        )
        category.budget = budget
        try? modelContext.save()
        HapticManager.notification(.success)
        dismiss()
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255.0
        let g = Double((int >> 8) & 0xFF) / 255.0
        let b = Double(int & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
