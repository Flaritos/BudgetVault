import SwiftUI

struct TransactionRowView: View {
    let transaction: Transaction

    var body: some View {
        HStack(spacing: BudgetVaultTheme.spacingMD) {
            Text(emoji)
                .font(.title3)
                .frame(width: 40, height: 40)
                .background(Circle().fill(categoryColor.opacity(0.12)))

            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.note.isEmpty ? (transaction.isIncome ? "Income" : "Expense") : transaction.note)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Text(transaction.date, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(formattedAmount)
                .font(BudgetVaultTheme.rowAmount)
                .foregroundStyle(transaction.isIncome ? BudgetVaultTheme.positive : BudgetVaultTheme.negative)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(emoji) \(transaction.note.isEmpty ? (transaction.isIncome ? "Income" : "Expense") : transaction.note), \(formattedAmount), \(transaction.date.formatted(date: .abbreviated, time: .omitted))")
    }

    private var emoji: String {
        if transaction.isIncome { return "\u{1F4B5}" }
        return transaction.category?.emoji ?? "\u{1F4E6}"
    }

    private var categoryColor: Color {
        if transaction.isIncome { return BudgetVaultTheme.positive }
        guard let hex = transaction.category?.color else { return .gray }
        return Color(hex: hex)
    }

    private var formattedAmount: String {
        let sign = transaction.isIncome ? "+" : "-"
        return "\(sign)\(CurrencyFormatter.format(cents: transaction.amountCents))"
    }
}
