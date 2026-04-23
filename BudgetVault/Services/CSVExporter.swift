import Foundation
import SwiftData

enum CSVExporter {

    enum ExportError: LocalizedError {
        case fetchFailed
        case writeFailed

        var errorDescription: String? {
            switch self {
            case .fetchFailed: "Could not read transactions from the database."
            case .writeFailed: "Could not write the CSV file."
            }
        }
    }

    /// Audit 2026-04-23 Compliance (D2): GDPR Article 20 data
    /// portability + CCPA §1798.130 require unrestricted raw-data
    /// export regardless of subscription tier. The prior 30-day cap
    /// for free users violated this — even though the data lives
    /// on-device, it's still the user's personal data being processed.
    /// `premiumOnly` parameter kept for source compat but ignored;
    /// full history exported for everyone.
    static func export(context: ModelContext, premiumOnly: Bool = true, resetDay: Int) throws -> URL {
        _ = premiumOnly // silence unused-parameter warning; retained for call-site stability
        let descriptor = FetchDescriptor<Transaction>(sortBy: [SortDescriptor(\Transaction.date)])
        guard let transactions = try? context.fetch(descriptor) else {
            throw ExportError.fetchFailed
        }

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withFullDate]

        // Audit fix: use `en_US_POSIX` for consistent `.` decimal
        // separator. Without this, German/Spanish/etc. locales emit
        // "1234,56" which YNAB/Excel mis-parse.
        let amountFormatter = NumberFormatter()
        amountFormatter.locale = Locale(identifier: "en_US_POSIX")
        amountFormatter.minimumFractionDigits = 2
        amountFormatter.maximumFractionDigits = 2
        amountFormatter.decimalSeparator = "."
        amountFormatter.usesGroupingSeparator = false

        var lines = ["Date,Category,Emoji,Note,Amount,Type"]
        for tx in transactions {
            let dateStr = isoFormatter.string(from: tx.date)
            let cat = Self.escapeCSVField(tx.category?.name ?? "")
            let emoji = Self.escapeCSVField(tx.category?.emoji ?? (tx.isIncome ? "\u{1F4B5}" : ""))
            let note = Self.escapeCSVField(tx.note)
            let amount = amountFormatter.string(from: NSNumber(value: Double(tx.amountCents) / 100.0)) ?? "0.00"
            let type = tx.isIncome ? "Income" : "Expense"
            lines.append("\(dateStr),\"\(cat)\",\"\(emoji)\",\"\(note)\",\(amount),\(type)")
        }

        let csv = lines.joined(separator: "\n")
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("BudgetVault_Export.csv")
        do {
            try csv.write(to: tempURL, atomically: true, encoding: .utf8)
            // Audit 2026-04-22 P2-7: `temporaryDirectory` inherits
            // weaker default protection than Application Support. A CSV
            // export contains every transaction + note — encrypt at
            // rest so a locked device doesn't reveal the file to an
            // attacker who can read NSFileProtection class files.
            try? FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.complete],
                ofItemAtPath: tempURL.path
            )
        } catch {
            throw ExportError.writeFailed
        }
        return tempURL
    }

    /// CSV-injection safe field escape.
    ///
    /// Audit fix: a transaction note starting with `=`, `+`, `-`, `@`,
    /// `\t`, or `\r` is interpreted as a formula by Excel/Numbers.
    /// Prefix any such cell with a single quote (industry-standard
    /// mitigation). Also double-escape embedded quotes.
    private static func escapeCSVField(_ value: String) -> String {
        guard let first = value.first else { return "" }
        let formulaPrefixes: Set<Character> = ["=", "+", "-", "@", "\t", "\r"]
        let needsPrefix = formulaPrefixes.contains(first)
        let quoteEscaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return needsPrefix ? "'" + quoteEscaped : quoteEscaped
    }
}
