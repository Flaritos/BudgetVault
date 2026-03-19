import Foundation
import SwiftData

struct CSVImportRow {
    let date: Date
    let category: String
    let note: String
    let amount: Double
    let isIncome: Bool
}

enum CSVFormat {
    case ynab
    case generic
    case unknown
}

enum CSVImporter {

    // MARK: - Format Detection

    static func detectFormat(header: String) -> CSVFormat {
        let lower = header.lowercased()
        if lower.contains("payee") && lower.contains("outflow") && lower.contains("inflow") {
            return .ynab
        }
        if lower.contains("date") && (lower.contains("amount") || lower.contains("category")) {
            return .generic
        }
        return .unknown
    }

    // MARK: - Parse

    static func parse(csv: String) -> (format: CSVFormat, rows: [CSVImportRow]) {
        let lines = csv.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard let header = lines.first else { return (.unknown, []) }

        let format = detectFormat(header: header)
        let dataLines = Array(lines.dropFirst())

        switch format {
        case .ynab:
            return (.ynab, parseYNAB(header: header, lines: dataLines))
        case .generic:
            return (.generic, parseGeneric(header: header, lines: dataLines))
        case .unknown:
            return (.unknown, [])
        }
    }

    // MARK: - YNAB Parse

    private static func parseYNAB(header: String, lines: [String]) -> [CSVImportRow] {
        let columns = parseCSVLine(header)
        let dateIdx = columns.firstIndex { $0.lowercased().contains("date") } ?? 0
        let categoryIdx = columns.firstIndex { $0.lowercased().contains("category") } ?? 3
        let memoIdx = columns.firstIndex { $0.lowercased().contains("memo") } ?? 4
        let outflowIdx = columns.firstIndex { $0.lowercased().contains("outflow") } ?? 5
        let inflowIdx = columns.firstIndex { $0.lowercased().contains("inflow") } ?? 6

        return lines.compactMap { line in
            let fields = parseCSVLine(line)
            guard fields.count > max(dateIdx, categoryIdx, memoIdx, outflowIdx, inflowIdx) else { return nil }
            guard let date = parseDate(fields[dateIdx]) else { return nil }

            let outflow = parseAmount(fields[outflowIdx])
            let inflow = parseAmount(fields[inflowIdx])
            let isIncome = inflow > 0 && outflow == 0
            let amount = isIncome ? inflow : outflow

            // YNAB category format: "Category Group/Category" — use the subcategory
            let rawCategory = fields[categoryIdx]
            let category = rawCategory.components(separatedBy: "/").last?.trimmingCharacters(in: .whitespaces) ?? rawCategory

            return CSVImportRow(date: date, category: category, note: fields[memoIdx], amount: amount, isIncome: isIncome)
        }
    }

    // MARK: - Generic Parse

    private static func parseGeneric(header: String, lines: [String]) -> [CSVImportRow] {
        let columns = parseCSVLine(header).map { $0.lowercased() }
        let dateIdx = columns.firstIndex { $0.contains("date") } ?? 0
        let categoryIdx = columns.firstIndex { $0.contains("category") }
        let noteIdx = columns.firstIndex { $0.contains("note") || $0.contains("memo") || $0.contains("description") }
        let amountIdx = columns.firstIndex { $0.contains("amount") } ?? 1
        let typeIdx = columns.firstIndex { $0.contains("type") }

        return lines.compactMap { line in
            let fields = parseCSVLine(line)
            guard fields.count > max(dateIdx, amountIdx) else { return nil }
            guard let date = parseDate(fields[dateIdx]) else { return nil }

            let amount = abs(parseAmount(fields[amountIdx]))
            let category = categoryIdx.flatMap { fields.count > $0 ? fields[$0] : nil } ?? "Other"
            let note = noteIdx.flatMap { fields.count > $0 ? fields[$0] : nil } ?? ""

            var isIncome = false
            if let ti = typeIdx, fields.count > ti {
                isIncome = fields[ti].lowercased().contains("income")
            } else {
                isIncome = parseAmount(fields[amountIdx]) > 0 && fields[amountIdx].contains("+")
            }

            return CSVImportRow(date: date, category: category, note: note, amount: amount, isIncome: isIncome)
        }
    }

    // MARK: - Import into SwiftData

    static func importRows(_ rows: [CSVImportRow], categoryMap: [String: String], context: ModelContext, resetDay: Int) -> (transactions: Int, months: Int) {
        var monthsCreated: Set<String> = []
        var txCount = 0

        for row in rows {
            let mappedCategory = categoryMap[row.category] ?? row.category
            let (month, year) = DateHelpers.budgetPeriod(containing: row.date, resetDay: resetDay)
            let budgetKey = "\(year)-\(month)"

            // Find or create budget
            let m = month
            let y = year
            let budgetDescriptor = FetchDescriptor<Budget>(
                predicate: #Predicate<Budget> { $0.month == m && $0.year == y }
            )
            let budget: Budget
            if let existing = try? context.fetch(budgetDescriptor).first {
                budget = existing
            } else {
                budget = Budget(month: month, year: year, totalIncomeCents: 0, resetDay: resetDay, isAutoCreated: true)
                context.insert(budget)
                monthsCreated.insert(budgetKey)
            }

            // Find or create category in this budget
            let category: Category?
            if row.isIncome {
                category = nil
            } else if let existing = (budget.categories ?? []).first(where: { $0.name == mappedCategory }) {
                category = existing
            } else {
                let newCat = Category(name: mappedCategory, emoji: "📦", sortOrder: (budget.categories ?? []).count)
                newCat.budget = budget
                category = newCat
            }

            let cents = Int64((row.amount * 100).rounded())

            // Deduplication: skip if a transaction with the same date, amount, and note already exists in this budget
            let txDate = row.date
            let txNote = row.note
            let txCents = cents
            let budgetStart = budget.periodStart
            let budgetEnd = budget.nextPeriodStart
            let dupDescriptor = FetchDescriptor<Transaction>(
                predicate: #Predicate<Transaction> {
                    $0.amountCents == txCents &&
                    $0.note == txNote &&
                    $0.date >= budgetStart &&
                    $0.date < budgetEnd &&
                    $0.date == txDate
                }
            )
            if let existingCount = try? context.fetchCount(dupDescriptor), existingCount > 0 {
                continue
            }

            let tx = Transaction(amountCents: cents, note: row.note, date: row.date, isIncome: row.isIncome, category: category)
            context.insert(tx)
            txCount += 1
        }

        SafeSave.save(context)
        return (txCount, monthsCreated.count)
    }

    // MARK: - CSV Parsing Helpers

    static func parseCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false

        for char in line {
            if char == "\"" {
                inQuotes.toggle()
            } else if char == "," && !inQuotes {
                fields.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
            } else {
                current.append(char)
            }
        }
        fields.append(current.trimmingCharacters(in: .whitespaces))
        return fields
    }

    private static func parseDate(_ string: String) -> Date? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        let formatters: [DateFormatter] = {
            let formats = ["yyyy-MM-dd", "MM/dd/yyyy", "dd/MM/yyyy", "M/d/yyyy", "yyyy-MM-dd'T'HH:mm:ss"]
            return formats.map { fmt in
                let f = DateFormatter()
                f.dateFormat = fmt
                f.locale = Locale(identifier: "en_US_POSIX")
                return f
            }
        }()

        // Try ISO 8601 first
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withFullDate]
        if let date = iso.date(from: trimmed) { return date }

        for formatter in formatters {
            if let date = formatter.date(from: trimmed) { return date }
        }
        return nil
    }

    private static func parseAmount(_ string: String) -> Double {
        let cleaned = string
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespaces)
        return Double(cleaned) ?? 0
    }
}
