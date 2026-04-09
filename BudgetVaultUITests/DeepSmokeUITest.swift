import XCTest

/// Deep smoke test — exhaustively captures every surface a first-time
/// user encounters after onboarding, with extended interactions (scroll,
/// taps, state changes). Produces ~30 screenshots for pixel-level audit.
///
/// Uses `-uitest` baseline fixture so we skip onboarding and land on
/// a pre-populated dashboard with a seeded budget, categories, and
/// transactions (one today, one reconciled, one older).
final class DeepSmokeUITest: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchArguments = ["-uitest"]
        app.launch()
        sleep(3) // let launch screen dismiss + dashboard render
    }

    func testDeepAppAudit() throws {
        // ========== HOME / DASHBOARD ==========
        snap("A01-dashboard-top")

        // Scroll down to expose streak, envelopes, insights, tips
        app.swipeUp()
        sleep(1)
        snap("A02-dashboard-mid-scroll")
        app.swipeUp()
        sleep(1)
        snap("A03-dashboard-bottom-scroll")

        // Scroll back to top
        app.swipeDown()
        app.swipeDown()
        sleep(1)
        snap("A04-dashboard-top-again")

        // Tap the buffer stat to trigger the info alert
        if app.staticTexts.matching(identifier: "bufferStat").firstMatch.waitForExistence(timeout: 2) {
            app.staticTexts.matching(identifier: "bufferStat").firstMatch.tap()
            sleep(1)
            snap("A05-buffer-info-alert")
            // Dismiss
            if app.buttons["Got it"].waitForExistence(timeout: 1) {
                app.buttons["Got it"].tap()
                sleep(1)
            }
        }

        // Tap the no-spend moon to trigger the toast
        let moon = app.buttons["noSpendButton"]
        if moon.waitForExistence(timeout: 2) && moon.isEnabled {
            moon.tap()
            sleep(1)
            snap("A06-no-spend-toast")
            sleep(2)
            snap("A07-no-spend-toast-after")
        }

        // ========== TRANSACTION ENTRY (fresh sheet) ==========
        let logExpense = app.buttons["Log expense"].firstMatch
        if logExpense.waitForExistence(timeout: 3) {
            logExpense.tap()
            sleep(1)
            snap("B01-entry-sheet-empty")

            // Amount: 12.50
            tapNum("One"); tapNum("Two"); tapNum("Decimal point"); tapNum("Five"); tapNum("Zero")
            sleep(1)
            snap("B02-entry-amount-entered")

            // Try a quick-amount chip
            if app.buttons["$10"].firstMatch.waitForExistence(timeout: 1) {
                app.buttons["$10"].firstMatch.tap()
                sleep(1)
                snap("B03-entry-quick-chip")
            }

            // Tap Groceries category
            if app.buttons["Groceries"].firstMatch.waitForExistence(timeout: 1) {
                app.buttons["Groceries"].firstMatch.tap()
                sleep(1)
                snap("B04-entry-category-selected")
            }

            // Toggle to Income mode to see that state
            if app.buttons["Income"].firstMatch.waitForExistence(timeout: 1) {
                app.buttons["Income"].firstMatch.tap()
                sleep(1)
                snap("B05-entry-income-mode")
                // Toggle back
                app.buttons["Expense"].firstMatch.tap()
                sleep(1)
            }

            // Cancel out
            if app.buttons["Cancel"].firstMatch.waitForExistence(timeout: 1) {
                app.buttons["Cancel"].firstMatch.tap()
            }
        }
        sleep(1)

        // ========== HISTORY TAB ==========
        app.tabBars.buttons["History"].tap()
        sleep(2)
        snap("C01-history-list")

        // Swipe left on first transaction to reveal reconcile + delete
        let firstCell = app.cells.firstMatch
        if firstCell.waitForExistence(timeout: 2) {
            firstCell.swipeLeft()
            sleep(1)
            snap("C02-history-swipe-actions")
            // Tap elsewhere to close swipe
            app.tap()
            sleep(1)
        }

        // Scroll history
        app.swipeUp()
        sleep(1)
        snap("C03-history-scrolled")
        app.swipeDown()
        sleep(1)

        // ========== VAULT (paywall) TAB ==========
        app.tabBars.buttons["Vault"].tap()
        sleep(2)
        snap("D01-vault-teaser")
        app.swipeUp()
        sleep(1)
        snap("D02-vault-scrolled")
        app.swipeDown()
        sleep(1)

        // Tap "Unlock Now" to open the full paywall
        let unlockNow = app.buttons["Unlock Now"].firstMatch
        let seePremium = app.buttons["See Premium Features"].firstMatch
        if unlockNow.waitForExistence(timeout: 1) {
            unlockNow.tap()
        } else if seePremium.waitForExistence(timeout: 1) {
            seePremium.tap()
        }
        sleep(2)
        snap("D03-paywall-top")
        app.swipeUp()
        sleep(1)
        snap("D04-paywall-mid")
        app.swipeUp()
        sleep(1)
        snap("D05-paywall-bottom")
        // Close paywall
        if app.buttons["Close"].firstMatch.waitForExistence(timeout: 1) {
            app.buttons["Close"].firstMatch.tap()
        } else if app.navigationBars.buttons.firstMatch.waitForExistence(timeout: 1) {
            app.navigationBars.buttons.firstMatch.tap()
        }
        sleep(1)

        // ========== SETTINGS TAB ==========
        app.tabBars.buttons["Settings"].tap()
        sleep(2)
        snap("E01-settings-top")
        app.swipeUp()
        sleep(1)
        snap("E02-settings-mid")
        app.swipeUp()
        sleep(1)
        snap("E03-settings-mid2")
        app.swipeUp()
        sleep(1)
        snap("E04-settings-bottom")

        // Tap Send Feedback
        let feedback = app.buttons["Send Feedback"].firstMatch
        if feedback.waitForExistence(timeout: 2) {
            feedback.tap()
            sleep(1)
            snap("E05-feedback-sheet-empty")

            // Type into message
            let editor = app.textViews.firstMatch
            if editor.waitForExistence(timeout: 1) {
                editor.tap()
                editor.typeText("The app is great, I love it.")
                sleep(1)
                snap("E06-feedback-sheet-typed")
            }

            // Cancel
            if app.buttons["Cancel"].firstMatch.waitForExistence(timeout: 1) {
                app.buttons["Cancel"].firstMatch.tap()
            }
        }
        sleep(1)

        // Tap Accent Color to reveal the premium lock state
        if app.buttons["Accent Color"].firstMatch.waitForExistence(timeout: 1) {
            app.buttons["Accent Color"].firstMatch.tap()
            sleep(2)
            snap("E07-accent-picker-or-paywall")
            // Close whatever opened
            if app.buttons["Close"].firstMatch.waitForExistence(timeout: 1) {
                app.buttons["Close"].firstMatch.tap()
            } else if app.buttons["Cancel"].firstMatch.waitForExistence(timeout: 1) {
                app.buttons["Cancel"].firstMatch.tap()
            }
            sleep(1)
        }

        // ========== BACK TO HOME ==========
        app.tabBars.buttons["Home"].tap()
        sleep(1)
        snap("Z01-home-final")
    }

    // MARK: - Helpers

    private func tapNum(_ label: String) {
        let key = app.buttons[label].firstMatch
        if key.waitForExistence(timeout: 1) { key.tap() }
    }

    private func snap(_ name: String) {
        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
