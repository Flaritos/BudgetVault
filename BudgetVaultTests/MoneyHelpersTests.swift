import XCTest
@testable import BudgetVault

final class MoneyHelpersTests: XCTestCase {

    // MARK: - parseCurrencyString

    func testNormalAmount() {
        XCTAssertEqual(MoneyHelpers.parseCurrencyString("123.45"), 12345)
    }

    func testNoDecimal() {
        XCTAssertEqual(MoneyHelpers.parseCurrencyString("100"), 10000)
    }

    func testEmptyString() {
        XCTAssertNil(MoneyHelpers.parseCurrencyString(""))
    }

    func testWhitespaceOnlyString() {
        XCTAssertNil(MoneyHelpers.parseCurrencyString("   "))
    }

    func testZero() {
        XCTAssertEqual(MoneyHelpers.parseCurrencyString("0"), 0)
    }

    func testZeroPointZero() {
        XCTAssertEqual(MoneyHelpers.parseCurrencyString("0.00"), 0)
    }

    func testLargeAmount() {
        XCTAssertEqual(MoneyHelpers.parseCurrencyString("99999.99"), 9999999)
    }

    func testSingleDecimalPlace() {
        XCTAssertEqual(MoneyHelpers.parseCurrencyString("5.5"), 550)
    }

    func testTwoDecimalPlaces() {
        XCTAssertEqual(MoneyHelpers.parseCurrencyString("5.50"), 550)
    }

    func testSmallAmount() {
        XCTAssertEqual(MoneyHelpers.parseCurrencyString("0.01"), 1)
    }

    func testInvalidString() {
        XCTAssertNil(MoneyHelpers.parseCurrencyString("abc"))
    }

    func testLeadingTrailingWhitespace() {
        XCTAssertEqual(MoneyHelpers.parseCurrencyString("  42.50  "), 4250)
    }

    // MARK: - centsToDollars

    func testCentsToDollarsNormal() {
        XCTAssertEqual(MoneyHelpers.centsToDollars(1450), Decimal(string: "14.50"))
    }

    func testCentsToDollarsZero() {
        XCTAssertEqual(MoneyHelpers.centsToDollars(0), 0)
    }

    // MARK: - dollarsToCents

    func testDollarsToCentsNormal() {
        XCTAssertEqual(MoneyHelpers.dollarsToCents(Decimal(string: "14.50")!), 1450)
    }

    func testDollarsToCentsZero() {
        XCTAssertEqual(MoneyHelpers.dollarsToCents(0), 0)
    }
}
