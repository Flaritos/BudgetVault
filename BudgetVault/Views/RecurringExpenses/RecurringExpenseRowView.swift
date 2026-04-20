import SwiftUI
import BudgetVaultShared

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
                    dueBadge
                }
            }

            Spacer()

            Text(CurrencyFormatter.format(cents: expense.amountCents))
                .font(BudgetVaultTheme.rowAmount)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(expense.name), \(CurrencyFormatter.format(cents: expense.amountCents)), \(expense.frequencyEnum.displayName), \(dueText)")
    }

    @ViewBuilder
    private var dueBadge: some View {
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: Calendar.current.startOfDay(for: expense.nextDueDate)).day ?? 0
        if days < 0 {
            Text("Overdue")
                .font(.caption.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(BudgetVaultTheme.negative, in: Capsule())
        } else if days == 0 {
            Text("Due today")
                .font(.caption.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(BudgetVaultTheme.caution, in: Capsule())
        } else if days == 1 {
            Text("Due tomorrow")
                .font(.caption)
                .foregroundStyle(.primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(BudgetVaultTheme.caution.opacity(0.3), in: Capsule())
        } else {
            Text(dueText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var dueText: String {
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: Calendar.current.startOfDay(for: expense.nextDueDate)).day ?? 0
        if days < 0 { return "overdue" }
        if days == 0 { return "due today" }
        if days == 1 { return "due tomorrow" }
        return "due in \(days) days"
    }
}
