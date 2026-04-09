import XCTest

/// End-to-end smoke test that walks the real onboarding flow, then
/// exercises each tab + each primary feature. Captures a screenshot at
/// every step via XCTAttachment so the xcresult bundle contains a
/// visual record that can be audited for glitches and regressions.
///
/// Run:
///   xcodebuild ... test -only-testing:BudgetVaultUITests/FullSmokeUITest
///
/// Extract screenshots from the xcresult bundle with `xcresulttool get`.
final class FullSmokeUITest: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = true // keep going so we collect screenshots for every step
        app = XCUIApplication()
        app.launchArguments = ["-uitest", "-uitest-wipe-only"]
        app.launch()
    }

    // MARK: - The Walk

    func testFullAppWalkthrough() throws {
        // 00 — welcome (fresh onboarding after wipe)
        snap("00-welcome")

        // 01 — tap Begin Setup → currency step
        waitAndTap("Begin Setup")
        sleep(1) // let transition settle
        snap("01-currency")

        // 02 — currency: default USD selected; tap Continue
        waitAndTap("Continue")
        sleep(1)
        snap("02-income-empty")

        // 03 — income: type 5000 via onboarding number pad (raw digit labels)
        for digit in ["5", "0", "0", "0"] {
            waitAndTap(digit)
        }
        snap("03-income-filled")

        // 04 — continue to envelope step
        waitAndTap("Continue")
        sleep(1)
        snap("04-envelopes")

        // 05 — tap "Looks Good" to create the budget
        waitAndTap("Looks Good")
        sleep(1)
        snap("05-unlocked")

        // 06 — enter app (v3.2 audit L6: renamed from "Open My Vault" to
        // "Start Budgeting" to avoid collision with the Vault paywall tab).
        waitAndTap("Start Budgeting")
        sleep(3) // dashboard + live activity lifecycle needs breathing room
        snap("06-dashboard-fresh")

        // 07 — tap "Log Expense" FAB to open transaction entry sheet
        let logExpense = app.buttons["Log expense"].firstMatch
        XCTAssertTrue(logExpense.waitForExistence(timeout: 5), "Log Expense FAB missing on dashboard")
        logExpense.tap()
        sleep(1)
        snap("07-entry-sheet")

        // 08 — enter "2" then "5" — NumberPadView uses word accessibility labels
        waitAndTap("Two")
        waitAndTap("Five")
        snap("08-entry-with-amount")

        // Pick a category so Save becomes enabled
        let rentChip = app.buttons["Rent"].firstMatch
        if rentChip.waitForExistence(timeout: 2) {
            rentChip.tap()
        }
        sleep(1)

        // 09 — tap Save (scoped to the sheet to avoid tabBar collisions)
        let save = app.buttons["Save"].firstMatch
        if save.waitForExistence(timeout: 2) && save.isEnabled {
            save.tap()
        } else {
            // Fallback: dismiss the sheet so we don't get stuck for the rest of the walk
            app.buttons["Cancel"].firstMatch.tap()
        }
        sleep(2)
        snap("09-dashboard-after-save")

        // 10 — tap the no-spend moon button
        let noSpend = app.buttons["noSpendButton"]
        if noSpend.waitForExistence(timeout: 3) {
            noSpend.tap()
        }
        sleep(1)
        snap("10-no-spend-tapped")

        // 11 — History tab
        app.tabBars.buttons["History"].tap()
        sleep(2)
        snap("11-history")

        // 12 — swipe left on the first cell to reveal reconcile action
        let firstCell = app.cells.firstMatch
        if firstCell.waitForExistence(timeout: 2) {
            firstCell.swipeLeft()
            sleep(1)
            snap("12-history-swiped")
        }

        // 13 — Vault tab (premium gate for non-premium)
        app.tabBars.buttons["Vault"].tap()
        sleep(2)
        snap("13-vault")

        // 14 — Settings tab
        app.tabBars.buttons["Settings"].tap()
        sleep(2)
        snap("14-settings-top")

        // 15 — scroll settings to the About section
        app.swipeUp()
        app.swipeUp()
        app.swipeUp()
        sleep(1)
        snap("15-settings-about")

        // 16 — tap Send Feedback
        let feedback = app.buttons["Send Feedback"].firstMatch
        if feedback.waitForExistence(timeout: 2) {
            feedback.tap()
            sleep(1)
            snap("16-feedback-sheet")

            if app.buttons["Cancel"].waitForExistence(timeout: 1) {
                app.buttons["Cancel"].firstMatch.tap()
            }
        }

        // 17 — back to Home
        app.tabBars.buttons["Home"].tap()
        sleep(1)
        snap("17-home-final")
    }

    /// Tap a button by label, waiting for it to exist first. Fails loudly
    /// so we know exactly which step of the walkthrough broke.
    private func waitAndTap(_ label: String, timeout: TimeInterval = 5) {
        let button = app.buttons[label].firstMatch
        if button.waitForExistence(timeout: timeout) {
            button.tap()
        } else {
            XCTFail("Could not find button '\(label)' at expected step")
        }
    }

    // MARK: - Screenshot helper

    private func snap(_ name: String) {
        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
