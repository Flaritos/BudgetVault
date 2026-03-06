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
    @State private var showDuplicateWarning = false

    private let emojiOptions = ["📦", "🏠", "🛒", "🚗", "🎬", "💊", "📚", "🎮", "👕", "🐾", "✈️", "🍕", "☕", "🎵", "💇", "🏋️", "🎁", "📱", "🔧", "💡"]

    private let colorOptions = ["#007AFF", "#34C759", "#FF9500", "#FF2D55", "#5856D6", "#AF52DE", "#FF3B30", "#5AC8FA", "#FFCC00", "#8E8E93"]

    private let colorNames: [String: String] = [
        "#007AFF": "Blue",
        "#34C759": "Green",
        "#FF9500": "Orange",
        "#FF2D55": "Pink",
        "#5856D6": "Purple",
        "#AF52DE": "Lavender",
        "#FF3B30": "Red",
        "#5AC8FA": "Teal",
        "#FFCC00": "Yellow",
        "#8E8E93": "Gray"
    ]

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
                            .accessibilityLabel(colorNames[hex] ?? "Color")
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
                        let trimmed = name.trimmingCharacters(in: .whitespaces)
                        let duplicate = budget.categories.contains { $0.name.lowercased() == trimmed.lowercased() }
                        if duplicate {
                            showDuplicateWarning = true
                        } else {
                            addCategory()
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .alert("Duplicate Category", isPresented: $showDuplicateWarning) {
            Button("Add Anyway") { addCategory() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("A category named \"\(name.trimmingCharacters(in: .whitespaces))\" already exists in this budget.")
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
        SafeSave.save(modelContext)
        HapticManager.notification(.success)
        dismiss()
    }
}
