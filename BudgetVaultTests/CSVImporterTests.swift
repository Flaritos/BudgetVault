import XCTest
@testable import BudgetVault

final class CSVImporterTests: XCTestCase {

    // MARK: - Format Detection

    func testDetectYNABFormat() {
        let header = "Date,Payee,Category Group/Category,Memo,Outflow,Inflow"
        XCTAssertEqual(CSVImporter.detectFormat(header: header), .ynab)
    }

    func testDetectGenericFormat() {
        let header = "Date,Category,Amount,Note"
        XCTAssertEqual(CSVImporter.detectFormat(header: header), .generic)
    }

    func testDetectUnknownFormat() {
        let header = "foo,bar,baz"
        XCTAssertEqual(CSVImporter.detectFormat(header: header), .unknown)
    }

    // MARK: - Parse YNAB CSV

    func testParseYNABCSV() {
        let csv = """
        Date,Payee,Category Group,Category,Memo,Outflow,Inflow
        2026-01-15,Grocery Store,Food,Groceries,Weekly shop,50.00,0
        2026-01-16,Employer,Income,Salary,January pay,0,3000.00
        """
        let (format, rows) = CSVImporter.parse(csv: csv)
        XCTAssertEqual(format, .ynab)
        XCTAssertEqual(rows.count, 2)

        // First row: expense
        XCTAssertEqual(rows[0].amount, 50.0)
        XCTAssertFalse(rows[0].isIncome)
        XCTAssertEqual(rows[0].note, "Weekly shop")

        // Second row: income
        XCTAssertEqual(rows[1].amount, 3000.0)
        XCTAssertTrue(rows[1].isIncome)
    }

    // MARK: - Parse Generic CSV

    func testParseGenericCSV() {
        let csv = """
        Date,Category,Amount,Note
        2026-01-15,Groceries,-50.00,Weekly shop
        2026-01-16,Other,100.00,Refund
        """
        let (format, rows) = CSVImporter.parse(csv: csv)
        XCTAssertEqual(format, .generic)
        XCTAssertEqual(rows.count, 2)

        XCTAssertEqual(rows[0].amount, 50.0)
        XCTAssertEqual(rows[0].category, "Groceries")
        XCTAssertEqual(rows[0].note, "Weekly shop")
    }

    // MARK: - Empty CSV

    func testParseEmptyCSV() {
        let csv = ""
        let (format, rows) = CSVImporter.parse(csv: csv)
        XCTAssertEqual(format, .unknown)
        XCTAssertTrue(rows.isEmpty)
    }

    func testParseHeaderOnly() {
        let csv = "Date,Category,Amount,Note"
        let (format, rows) = CSVImporter.parse(csv: csv)
        XCTAssertEqual(format, .generic)
        XCTAssertTrue(rows.isEmpty)
    }

    // MARK: - Malformed Rows

    func testParseMalformedRows() {
        let csv = """
        Date,Category,Amount,Note
        2026-01-15,Groceries,50.00,Shopping
        bad-row
        2026-01-16,Food,25.00,Lunch
        """
        let (_, rows) = CSVImporter.parse(csv: csv)
        // "bad-row" should be skipped (no valid date or insufficient fields)
        XCTAssertEqual(rows.count, 2)
    }

    // MARK: - CSV Line Parsing

    func testParseCSVLineSimple() {
        let fields = CSVImporter.parseCSVLine("a,b,c")
        XCTAssertEqual(fields, ["a", "b", "c"])
    }

    func testParseCSVLineWithQuotes() {
        let fields = CSVImporter.parseCSVLine("\"hello, world\",b,c")
        XCTAssertEqual(fields, ["hello, world", "b", "c"])
    }

    func testParseCSVLineWithWhitespace() {
        let fields = CSVImporter.parseCSVLine(" a , b , c ")
        XCTAssertEqual(fields, ["a", "b", "c"])
    }

    func testParseCSVLineSingleField() {
        let fields = CSVImporter.parseCSVLine("alone")
        XCTAssertEqual(fields, ["alone"])
    }

    func testParseCSVLineEmpty() {
        let fields = CSVImporter.parseCSVLine("")
        XCTAssertEqual(fields, [""])
    }
}
