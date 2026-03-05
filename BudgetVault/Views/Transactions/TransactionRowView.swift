import SwiftUI

struct TransactionRowView: View {
    let transaction: Transaction

    var body: some View {
        HStack(spacing: 12) {
            Text(emoji)
                .font(.title2)
                .frame(width: 36)

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
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(transaction.isIncome ? .green : .primary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(emoji) \(transaction.note.isEmpty ? (transaction.isIncome ? "Income" : "Expense") : transaction.note), \(formattedAmount), \(transaction.date.formatted(date: .abbreviated, time: .omitted))")
    }

    private var emoji: String {
        if transaction.isIncome { return "💵" }
        return transaction.category?.emoji ?? "📦"
    }

    private var formattedAmount: String {
        let sign = transaction.isIncome ? "+" : "-"
        return "\(sign)\(CurrencyFormatter.format(cents: transaction.amountCents))"
    }
}
