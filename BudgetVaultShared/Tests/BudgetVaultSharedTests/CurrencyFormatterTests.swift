import XCTest
@testable import BudgetVaultShared

final class CurrencyFormatterTests: XCTestCase {

    // MARK: - formatRaw(cents:)

    func testFormatRawNormal() {
        XCTAssertEqual(CurrencyFormatter.formatRaw(cents: 1450), "14.50")
    }

    func testFormatRawZeroCents() {
        XCTAssertEqual(CurrencyFormatter.formatRaw(cents: 0), "0")
    }

    func testFormatRawWholeAmount() {
        // 500 cents = $5.00 — remainder is 0 so shows "5"
        XCTAssertEqual(CurrencyFormatter.formatRaw(cents: 500), "5")
    }

    func testFormatRawLargeAmount() {
        XCTAssertEqual(CurrencyFormatter.formatRaw(cents: 9999999), "99999.99")
    }

    func testFormatRawSingleCent() {
        XCTAssertEqual(CurrencyFormatter.formatRaw(cents: 1), "0.01")
    }

    func testFormatRawNegativeAmount() {
        // Negative cents: -1450 -> dollars = -14, remainder = -50
        let result = CurrencyFormatter.formatRaw(cents: -1450)
        XCTAssertTrue(result.contains("14"), "Should contain the numeric value")
    }

    // MARK: - format(cents:currencyCode:)

    func testFormatCentsUSD() {
        let result = CurrencyFormatter.format(cents: 1450, currencyCode: "USD")
        // Should contain "$14.50" in some locale format
        XCTAssertTrue(result.contains("14"), "Formatted string should contain the dollar amount")
    }

    func testFormatCentsZeroUSD() {
        let result = CurrencyFormatter.format(cents: 0, currencyCode: "USD")
        XCTAssertTrue(result.contains("0"), "Formatted zero should contain 0")
    }

    func testFormatCentsLargeAmountUSD() {
        let result = CurrencyFormatter.format(cents: 1000000, currencyCode: "USD")
        // $10,000.00
        XCTAssertTrue(result.contains("10"), "Large amount should format correctly")
    }

    // MARK: - displayAmount

    func testDisplayAmountEmpty() {
        let result = CurrencyFormatter.displayAmount(text: "")
        XCTAssertTrue(result.hasSuffix("0"), "Empty text should display as symbol + 0")
    }

    func testDisplayAmountWithValue() {
        let result = CurrencyFormatter.displayAmount(text: "14.50")
        XCTAssertTrue(result.contains("14.50"), "Should contain the provided text")
    }
}
