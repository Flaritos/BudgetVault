import Foundation
import SwiftData

enum CSVExporter {

    static func export(context: ModelContext, premiumOnly: Bool, resetDay: Int) -> URL? {
        let descriptor = FetchDescriptor<Transaction>(sortBy: [SortDescriptor(\Transaction.date)])
        guard let allTransactions = try? context.fetch(descriptor) else { return nil }

        var transactions = allTransactions

        // Free: last 30 days only
        if !premiumOnly {
            let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
            transactions = transactions.filter { $0.date >= cutoff }
        }

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withFullDate]

        var lines = ["Date,Category,Emoji,Note,Amount,Type"]
        for tx in transactions {
            let dateStr = isoFormatter.string(from: tx.date)
            let cat = tx.category?.name ?? ""
            let emoji = tx.category?.emoji ?? (tx.isIncome ? "💵" : "")
            let note = tx.note.replacingOccurrences(of: "\"", with: "\"\"")
            let amount = String(format: "%.2f", Double(tx.amountCents) / 100.0)
            let type = tx.isIncome ? "Income" : "Expense"
            lines.append("\(dateStr),\"\(cat)\",\"\(emoji)\",\"\(note)\",\(amount),\(type)")
        }

        let csv = lines.joined(separator: "\n")
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("BudgetVault_Export.csv")
        try? csv.write(to: tempURL, atomically: true, encoding: .utf8)
        return tempURL
    }
}
