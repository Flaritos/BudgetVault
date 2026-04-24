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
        let isoTimestampFormatter = ISO8601DateFormatter()
        isoTimestampFormatter.formatOptions = [.withInternetDateTime]

        // Audit fix: use `en_US_POSIX` for consistent `.` decimal
        // separator. Without this, German/Spanish/etc. locales emit
        // "1234,56" which YNAB/Excel mis-parse.
        let amountFormatter = NumberFormatter()
        amountFormatter.locale = Locale(identifier: "en_US_POSIX")
        amountFormatter.minimumFractionDigits = 2
        amountFormatter.maximumFractionDigits = 2
        amountFormatter.decimalSeparator = "."
        amountFormatter.usesGroupingSeparator = false

        // Audit 2026-04-23 Max Audit P1-20: GDPR Article 20 export
        // must include ALL user data, not just Transactions. Added
        // section-delimited blocks for Budgets, Categories,
        // RecurringExpenses, DebtAccounts, and DebtPayments so the
        // export is a complete on-device data snapshot. YNAB-style
        // third-party parsers can read the first "Transactions"
        // block and ignore the rest; DSAR reviewers see everything.
        var lines: [String] = []
        lines.append("# BudgetVault GDPR Export")
        lines.append("# Generated: \(isoTimestampFormatter.string(from: Date()))")
        lines.append("")
        lines.append("### Transactions")
        lines.append("Date,Category,Emoji,Note,Amount,Type")
        for tx in transactions {
            let dateStr = isoFormatter.string(from: tx.date)
            let cat = Self.escapeCSVField(tx.category?.name ?? "")
            let emoji = Self.escapeCSVField(tx.category?.emoji ?? (tx.isIncome ? "\u{1F4B5}" : ""))
            let note = Self.escapeCSVField(tx.note)
            let amount = amountFormatter.string(from: NSNumber(value: Double(tx.amountCents) / 100.0)) ?? "0.00"
            let type = tx.isIncome ? "Income" : "Expense"
            lines.append("\(dateStr),\"\(cat)\",\"\(emoji)\",\"\(note)\",\(amount),\(type)")
        }

        // Budgets
        let budgetDescriptor = FetchDescriptor<Budget>(sortBy: [SortDescriptor(\Budget.year), SortDescriptor(\Budget.month)])
        if let budgets = try? context.fetch(budgetDescriptor), !budgets.isEmpty {
            lines.append("")
            lines.append("### Budgets")
            lines.append("Year,Month,TotalIncomeCents,ResetDay,IsAutoCreated")
            for b in budgets {
                lines.append("\(b.year),\(b.month),\(b.totalIncomeCents),\(b.resetDay),\(b.isAutoCreated)")
            }
        }

        // Categories
        let catDescriptor = FetchDescriptor<Category>(sortBy: [SortDescriptor(\Category.sortOrder)])
        if let categories = try? context.fetch(catDescriptor), !categories.isEmpty {
            lines.append("")
            lines.append("### Categories")
            lines.append("BudgetYear,BudgetMonth,Name,Emoji,BudgetedCents,Color,SortOrder,IsHidden,RollOverUnspent,GoalCents,GoalType")
            for c in categories {
                let byr = c.budget?.year ?? 0
                let bmo = c.budget?.month ?? 0
                let name = Self.escapeCSVField(c.name)
                let emoji = Self.escapeCSVField(c.emoji)
                let goal = c.goalAmountCents.map(String.init) ?? ""
                let goalType = Self.escapeCSVField(c.goalType ?? "")
                lines.append("\(byr),\(bmo),\"\(name)\",\"\(emoji)\",\(c.budgetedAmountCents),\(c.color),\(c.sortOrder),\(c.isHidden),\(c.rollOverUnspent),\(goal),\"\(goalType)\"")
            }
        }

        // Recurring expenses
        let recDescriptor = FetchDescriptor<RecurringExpense>(sortBy: [SortDescriptor(\RecurringExpense.nextDueDate)])
        if let recurring = try? context.fetch(recDescriptor), !recurring.isEmpty {
            lines.append("")
            lines.append("### RecurringExpenses")
            lines.append("Name,AmountCents,Frequency,NextDueDate,IsActive,CategoryName,NeedsReassignment")
            for r in recurring {
                let name = Self.escapeCSVField(r.name)
                let dateStr = isoFormatter.string(from: r.nextDueDate)
                let catName = Self.escapeCSVField(r.category?.name ?? "")
                lines.append("\"\(name)\",\(r.amountCents),\(r.frequency),\(dateStr),\(r.isActive),\"\(catName)\",\(r.needsReassignment)")
            }
        }

        // Debt accounts + payments
        let debtDescriptor = FetchDescriptor<DebtAccount>(sortBy: [SortDescriptor(\DebtAccount.createdAt)])
        if let debts = try? context.fetch(debtDescriptor), !debts.isEmpty {
            lines.append("")
            lines.append("### DebtAccounts")
            lines.append("Name,Emoji,OriginalBalanceCents,CurrentBalanceCents,InterestRate,MinPaymentCents,DueDay,IsActive,CreatedAt")
            for d in debts {
                let name = Self.escapeCSVField(d.name)
                let emoji = Self.escapeCSVField(d.emoji)
                let created = isoTimestampFormatter.string(from: d.createdAt)
                lines.append("\"\(name)\",\"\(emoji)\",\(d.originalBalanceCents),\(d.currentBalanceCents),\(d.interestRate),\(d.minimumPaymentCents),\(d.dueDay),\(d.isActive),\(created)")
            }

            let paymentDescriptor = FetchDescriptor<DebtPayment>(sortBy: [SortDescriptor(\DebtPayment.date)])
            if let payments = try? context.fetch(paymentDescriptor), !payments.isEmpty {
                lines.append("")
                lines.append("### DebtPayments")
                lines.append("DebtAccountName,AmountCents,Date,Note")
                for p in payments {
                    let accName = Self.escapeCSVField(p.debtAccount?.name ?? "")
                    let dateStr = isoFormatter.string(from: p.date)
                    let note = Self.escapeCSVField(p.note)
                    lines.append("\"\(accName)\",\(p.amountCents),\(dateStr),\"\(note)\"")
                }
            }
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
