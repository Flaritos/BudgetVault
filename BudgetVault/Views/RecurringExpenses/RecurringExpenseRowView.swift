import SwiftUI

struct RecurringExpenseRowView: View {
    let expense: RecurringExpense

    var body: some View {
        HStack(spacing: 12) {
            Text(expense.category?.emoji ?? "📦")
                .font(.title2)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(expense.name.isEmpty ? "Unnamed" : expense.name)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text(expense.frequencyEnum.displayName)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.15), in: Capsule())
                    Text(dueText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(CurrencyFormatter.format(cents: expense.amountCents))
                .font(.subheadline.weight(.semibold))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(expense.name), \(CurrencyFormatter.format(cents: expense.amountCents)), \(expense.frequencyEnum.displayName), \(dueText)")
    }

    private var dueText: String {
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: Calendar.current.startOfDay(for: expense.nextDueDate)).day ?? 0
        if days < 0 { return "overdue" }
        if days == 0 { return "due today" }
        if days == 1 { return "due tomorrow" }
        return "due in \(days) days"
    }
}
