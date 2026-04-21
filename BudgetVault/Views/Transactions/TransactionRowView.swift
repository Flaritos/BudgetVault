import SwiftUI
import BudgetVaultShared

struct TransactionRowView: View {
    let transaction: Transaction
    var showReconciled: Bool = false

    @ScaledMetric(relativeTo: .body) private var emojiSize: CGFloat = 36

    var body: some View {
        HStack(spacing: BudgetVaultTheme.spacingMD) {
            // Category color indicator (thin vertical bar)
            RoundedRectangle(cornerRadius: 2)
                .fill(categoryColor)
                .frame(width: 3, height: 36)

            // Emoji in tinted rounded-rect (unified with HistoryView)
            Text(emoji)
                .font(.title3)
                .frame(width: emojiSize, height: emojiSize)
                .background(categoryColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))

            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(displayTitle)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)

                HStack(spacing: BudgetVaultTheme.spacingXS) {
                    Text(transaction.category?.name ?? "Income")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\u{00B7}")
                        .foregroundStyle(.tertiary)
                    Text(transaction.date, style: .time)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            // Amount + optional reconciled indicator
            VStack(alignment: .trailing, spacing: 2) {
                Text(formattedAmount)
                    .font(BudgetVaultTheme.rowAmount)
                    .foregroundStyle(transaction.isIncome ? BudgetVaultTheme.positive : .primary)
                if showReconciled && transaction.isReconciled {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.caption2)
                        .foregroundStyle(BudgetVaultTheme.positive.opacity(0.7))
                        .accessibilityLabel("Reviewed")
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(emoji) \(displayTitle), \(formattedAmount), \(transaction.date.formatted(date: .abbreviated, time: .omitted))")
    }

    private var displayTitle: String {
        if !transaction.note.isEmpty {
            return transaction.note
        }
        return transaction.isIncome ? "Income" : (transaction.category?.name ?? "Expense")
    }

    private var emoji: String {
        if transaction.isIncome { return "\u{1F4B5}" }
        return transaction.category?.emoji ?? "\u{1F4E6}"
    }

    private var categoryColor: Color {
        if transaction.isIncome { return BudgetVaultTheme.positive }
        guard let hex = transaction.category?.color else { return BudgetVaultTheme.titanium500 }
        return Color(hex: hex)
    }

    private var formattedAmount: String {
        let sign = transaction.isIncome ? "+" : "-"
        return "\(sign)\(CurrencyFormatter.format(cents: transaction.amountCents))"
    }
}
