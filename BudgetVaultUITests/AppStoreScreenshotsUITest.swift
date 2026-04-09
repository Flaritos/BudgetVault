import XCTest

/// Captures a curated set of App Store screenshots at iPhone 17 Pro Max
/// resolution (1320 × 2868). Run this against the Pro Max simulator to
/// produce shots ready for App Store Connect upload.
///
/// Apple now accepts a single 6.9" iPhone Pro Max set; smaller devices
/// auto-scale.
///
/// Run:
///   xcodebuild ... -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
///       test -only-testing:BudgetVaultUITests/AppStoreScreenshotsUITest
final class AppStoreScreenshotsUITest: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = true
        app = XCUIApplication()
        // Use the seeded baseline so the dashboard has a budget + transactions.
        app.launchArguments = ["-uitest"]
        app.launch()
        sleep(3)
    }

    func test01_HomeHero() throws {
        // Dashboard with daily allowance ring + privacy chip + envelopes
        snap("AppStore_01_Home")
    }

    func test02_LogExpense() throws {
        // Transaction entry sheet
        let logExpense = app.buttons["Log expense"].firstMatch
        if logExpense.waitForExistence(timeout: 5) {
            logExpense.tap()
            sleep(2)
            // Tap a quick chip to show populated state with auto-picked category
            if app.buttons["$10"].firstMatch.waitForExistence(timeout: 2) {
                app.buttons["$10"].firstMatch.tap()
                sleep(1)
            }
            snap("AppStore_02_LogExpense")
        }
    }

    func test03_History() throws {
        app.tabBars.buttons["History"].tap()
        sleep(2)
        snap("AppStore_03_History")
    }

    func test04_Vault() throws {
        app.tabBars.buttons["Vault"].tap()
        sleep(2)
        snap("AppStore_04_Vault")
    }

    func test05_Paywall() throws {
        app.tabBars.buttons["Vault"].tap()
        sleep(2)
        let unlockNow = app.buttons["Unlock Now"].firstMatch
        let seePremium = app.buttons["See Premium Features"].firstMatch
        if unlockNow.waitForExistence(timeout: 1) {
            unlockNow.tap()
        } else if seePremium.waitForExistence(timeout: 1) {
            seePremium.tap()
        }
        sleep(2)
        snap("AppStore_05_Paywall")
    }

    func test06_Settings() throws {
        app.tabBars.buttons["Settings"].tap()
        sleep(2)
        snap("AppStore_06_Settings")
    }

    private func snap(_ name: String) {
        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
