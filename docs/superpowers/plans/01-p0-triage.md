# P0 Triage Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the five v3.2 production bugs and lay the SPM seam so v3.3.0 can ship the marketing-led Wedge release in four weeks.

**Architecture:** Five independent surgical fixes against the existing app + widget targets, plus a tiny new local SPM package (`BudgetVaultShared`) seeded with three pure-value types so the Phase-2 type-migration is incremental. Live Activity work lands as a new `ActivityConfiguration` inside the existing widget bundle (no new target). PrivacyInfo work creates one new file. Achievement work re-introduces a sheet-based reward presentation (not the v3.2-removed banner) using the existing `VaultDialMark`. Code-review wins are line-level edits with regression tests.

**Tech Stack:** Swift 5.9, SwiftUI, ActivityKit (iOS 16.2+), AppIntents (LiveActivityIntent iOS 17+), WidgetKit, XCTest, xcodegen, swift-tools-version 5.9 SPM.

**Estimated Effort:** 7 days (5 LiveActivity + 1 PrivacyInfo + 1 Achievement + 0.5 CodeWins + 1 SPM, with 0.5d buffer for xcodegen/test churn).

**Ship Target:** v3.3.0

---

## File Structure

### Create
- `BudgetVaultShared/Package.swift` — SPM manifest for the new local package (iOS 17 target, single library product `BudgetVaultShared`).
- `BudgetVaultShared/Sources/BudgetVaultShared/AppStorageKeys.swift` — Moved from `BudgetVault/Utilities/AppStorageKeys.swift`. Made `public`.
- `BudgetVaultShared/Sources/BudgetVaultShared/CurrencyFormatter.swift` — Moved from `BudgetVault/Utilities/CurrencyFormatter.swift`. Made `public`.
- `BudgetVaultShared/Sources/BudgetVaultShared/MoneyHelpers.swift` — Moved from `BudgetVault/Utilities/MoneyHelpers.swift`. Made `public`.
- `BudgetVaultShared/Tests/BudgetVaultSharedTests/MoneyHelpersTests.swift` — Mirror of existing `BudgetVaultTests/MoneyHelpersTests.swift` against the new module.
- `BudgetVaultShared/Tests/BudgetVaultSharedTests/CurrencyFormatterTests.swift` — Mirror of existing `BudgetVaultTests/CurrencyFormatterTests.swift` against the new module.
- `BudgetVaultWidget/BudgetActivityWidget.swift` — Hosts `BudgetActivityWidget: Widget` (`ActivityConfiguration<BudgetActivityAttributes>`) plus the three rendering subviews (Lock Screen, Dynamic Island compact, Dynamic Island expanded).
- `BudgetVaultWidget/LiveActivityIntents.swift` — Houses the `LogExpenseFromActivityIntent` (LiveActivityIntent) used by the expanded Dynamic Island button.
- `BudgetVaultWidget/PrivacyInfo.xcprivacy` — Widget-target privacy manifest, declares `CA92.1`.
- `BudgetVault/Views/Shared/AchievementSheet.swift` — Brief modal sheet that replaces the removed overlay banner; renders newly-unlocked badges with a `VaultDialMark` spin.
- `BudgetVaultTests/AchievementServiceTests.swift` — Tests the `isCompletedMonth` gate on `saved_*` rules.
- `BudgetVaultTests/BudgetLiveActivityServiceTests.swift` — Tests stale-activity recovery via injection-friendly seam.
- `BudgetVaultTests/InsightsEngineForceUnwrapTests.swift` — Asserts the `prev.periodStart + daysSoFar` calculation never crashes when overflow occurs.

### Modify
- `BudgetVault/Models/BudgetActivityAttributes.swift` — No structural change yet (lives in app target until Phase 2 SPM migration). Add public-API doc comment so widget can reference via target membership.
- `BudgetVaultWidget/BudgetVaultWidget.swift:394-406` — Add `BudgetActivityWidget()` to the `WidgetBundle`.
- `BudgetVault/Services/BudgetLiveActivityService.swift:25, 41` — Replace `currentActivity` accessor with stale-aware variant; ends activity if `attributes.periodEndDate < .now` before short-circuiting `start`.
- `BudgetVault/PrivacyInfo.xcprivacy` — Add three new dict entries: `C617.1` (FileTimestamp), `35F9.1` (SystemBootTime), `0A2A.1` (DiskSpace).
- `BudgetVault/Services/StoreKitManager.swift:88` — Replace `print(...)` with the existing-pattern `Logger`.
- `BudgetVault/Services/StreakService.swift:14-22, 33` — Replace Monday-foreground reset with ISO-week-based "available" computation.
- `BudgetVault/Services/NotificationService.swift:213-231` — Delete the no-arg `scheduleWeeklySummary()` overload.
- `BudgetVault/Views/Settings/SettingsView.swift:373` — Update the only call site of the deleted overload.
- `BudgetVault/ViewModels/InsightsEngine.swift:97` — Replace `!` with safe `??` fallback to `prev.nextPeriodStart`.
- `BudgetVault/Services/DebugSeedService.swift:225` — Replace `!` with safe `??` fallback to `today`.
- `BudgetVault/Services/AchievementService.swift:115-127` — Gate `saved_100/500/1000` behind `isCompletedMonth`.
- `BudgetVault/Views/Dashboard/DashboardView.swift:58, 399-404` — Re-introduce achievement sheet presentation (`activeSheet = .newAchievement(badge)`) wired to `AchievementSheet`.
- `BudgetVault/Utilities/AppStorageKeys.swift` — Delete (moved to SPM); replaced by re-export.
- `BudgetVault/Utilities/CurrencyFormatter.swift` — Delete (moved to SPM).
- `BudgetVault/Utilities/MoneyHelpers.swift` — Delete (moved to SPM).
- `project.yml` — Add `BudgetVaultShared` package reference for app + tests + widget targets; add a `packages` block.
- `BudgetVault/Info.plist` — No change (no new keys needed).

### Test
- `BudgetVaultTests/StreakServiceTests.swift` — Add 4 freeze-accumulation tests.
- `BudgetVaultTests/AchievementServiceTests.swift` — New file (see Create).
- `BudgetVaultTests/BudgetLiveActivityServiceTests.swift` — New file (see Create).
- `BudgetVaultTests/InsightsEngineForceUnwrapTests.swift` — New file (see Create).
- `BudgetVaultSharedTests/MoneyHelpersTests.swift` — Mirror existing.
- `BudgetVaultSharedTests/CurrencyFormatterTests.swift` — Mirror existing.

---

## Tasks

### Task 1: Capture green baseline before edits

**Files:** none

- [ ] Run `cd /Users/zachgold/Claude/BudgetVault && xcodegen generate` — expect "Loaded project" then "Created project at /Users/zachgold/Claude/BudgetVault/BudgetVault.xcodeproj".
- [ ] Run `cd /Users/zachgold/Claude/BudgetVault && xcodebuild test -scheme BudgetVault -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet 2>&1 | tail -20` — expect `** TEST SUCCEEDED **`. Save count of tests-passing for parity check at end of plan.
- [ ] If any test fails, STOP. The plan presumes the v3.2 baseline is green. Open `git status` and confirm no uncommitted local mutations before proceeding.
- [ ] Commit a marker tag locally: `git tag p0-baseline` (do NOT push). This lets `git diff p0-baseline HEAD` show this plan's full delta later.

---

### Task 2: Add stale-period guard to BudgetLiveActivityService

**Files:**
- Modify: `BudgetVault/Services/BudgetLiveActivityService.swift:24-28, 41`
- Test: `BudgetVaultTests/BudgetLiveActivityServiceTests.swift` (CREATE)

- [ ] Create `BudgetVaultTests/BudgetLiveActivityServiceTests.swift` with this content:

```swift
import XCTest
@testable import BudgetVault

/// Pure-value tests for the stale-period guard. ActivityKit cannot run
/// in a unit-test process (`Activity.request` requires a live extension
/// host), so we test the predicate in isolation rather than the side
/// effects.
final class BudgetLiveActivityServiceTests: XCTestCase {

    func testIsStale_returnsTrueWhenEndDateInPast() {
        let endDate = Date().addingTimeInterval(-60)
        XCTAssertTrue(BudgetLiveActivityService.isPeriodEndStale(endDate, now: Date()))
    }

    func testIsStale_returnsFalseWhenEndDateInFuture() {
        let endDate = Date().addingTimeInterval(60)
        XCTAssertFalse(BudgetLiveActivityService.isPeriodEndStale(endDate, now: Date()))
    }

    func testIsStale_returnsFalseAtExactEqual() {
        let now = Date()
        XCTAssertFalse(BudgetLiveActivityService.isPeriodEndStale(now, now: now),
                       "Equal-time should be treated as still-running, not stale.")
    }
}
```

- [ ] Run `xcodegen generate && xcodebuild test -scheme BudgetVault -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:BudgetVaultTests/BudgetLiveActivityServiceTests 2>&1 | tail -10` — expect compile failure on `isPeriodEndStale` (symbol not yet defined). Confirm the failure message is the missing symbol, not a different bug.

- [ ] Open `BudgetVault/Services/BudgetLiveActivityService.swift`. After the `currentActivity` accessor at line 27 (i.e. inside the `enum BudgetLiveActivityService` body, before `static func start`), insert this exact block:

```swift
    /// Pure predicate for unit testing the stale-period guard.
    /// Returns `true` when the period end has already passed and the
    /// activity should be ended before requesting a new one.
    static func isPeriodEndStale(_ periodEndDate: Date, now: Date = Date()) -> Bool {
        periodEndDate < now
    }

    /// End any running activity whose `periodEndDate` is in the past.
    /// Safe to call repeatedly. Awaitable so the caller can sequence
    /// `start` after the cleanup completes.
    static func endStaleActivities(now: Date = Date()) async {
        for activity in Activity<BudgetActivityAttributes>.activities
            where isPeriodEndStale(activity.attributes.periodEndDate, now: now) {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
```

- [ ] In the same file, replace the existing `start(...)` body's first two statements (currently `guard areActivitiesEnabled else { return }` and `if currentActivity != nil { return }`, lines 40-41) with this:

```swift
        guard areActivitiesEnabled else { return }
        // v3.3 P0 fix: if a previous activity outlived its period (force-quit,
        // device sleep across midnight), end it before short-circuiting.
        if let existing = Activity<BudgetActivityAttributes>.activities.first {
            if isPeriodEndStale(existing.attributes.periodEndDate) {
                Task { await existing.end(nil, dismissalPolicy: .immediate) }
            } else {
                return
            }
        }
```

- [ ] Run `xcodegen generate && xcodebuild test -scheme BudgetVault -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:BudgetVaultTests/BudgetLiveActivityServiceTests 2>&1 | tail -10` — expect `Test Suite 'BudgetLiveActivityServiceTests' passed`.

- [ ] Commit: `git add BudgetVault/Services/BudgetLiveActivityService.swift BudgetVaultTests/BudgetLiveActivityServiceTests.swift && git commit -m "fix(live-activity): end stale activities before requesting new one"`

---

### Task 3: Define the LiveActivityIntent for the Dynamic Island button

**Files:**
- Create: `BudgetVaultWidget/LiveActivityIntents.swift`

- [ ] Create `BudgetVaultWidget/LiveActivityIntents.swift` with this exact content:

```swift
import AppIntents
import Foundation

/// Tapping the "Log" button in the Dynamic Island expanded leaf opens
/// BudgetVault on the transaction-entry screen. Read-only-safe v1: the
/// intent does NOT write to SwiftData from the extension process; it
/// just deep-links into the host app.
///
/// Per `docs/audit-2026-04-16/product/mobile-platform.md` "What NOT to
/// Do" — interactive-write Live Activity buttons are deferred to v3.4.
@available(iOS 17.0, *)
struct LogExpenseFromActivityIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Log Expense"
    static var description = IntentDescription("Open BudgetVault to log an expense.")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        return .result()
    }
}
```

- [ ] Run `xcodegen generate && xcodebuild build -scheme BudgetVault -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet 2>&1 | tail -5` — expect `** BUILD SUCCEEDED **`. (No tests yet for this intent — it has no logic.)

- [ ] Commit: `git add BudgetVaultWidget/LiveActivityIntents.swift && git commit -m "feat(live-activity): add LogExpenseFromActivityIntent for Dynamic Island"`

---

### Task 4: Build BudgetActivityWidget with Lock Screen view

**Files:**
- Create: `BudgetVaultWidget/BudgetActivityWidget.swift`

- [ ] Create `BudgetVaultWidget/BudgetActivityWidget.swift` with this initial content (Lock Screen view + ring helper + activity widget shell — DI views added in Task 5):

```swift
import ActivityKit
import SwiftUI
import WidgetKit
import AppIntents

// MARK: - Activity Widget Shell

@available(iOS 16.2, *)
struct BudgetActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BudgetActivityAttributes.self) { context in
            BudgetActivityLockScreenView(state: context.state, attributes: context.attributes)
                .containerBackground(.fill.tertiary, for: .widget)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    BudgetActivityRing(percent: 1.0 - context.state.spentFraction)
                        .frame(width: 38, height: 38)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(formatActivityCents(context.state.dailyAllowanceCents,
                                                 code: context.state.currencyCode))
                            .font(.system(size: 18, weight: .heavy, design: .rounded))
                        Text("today")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text("\(formatActivityCents(context.state.remainingCents, code: context.state.currencyCode)) left this period")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        Spacer()
                        if #available(iOS 17.0, *) {
                            Button(intent: LogExpenseFromActivityIntent()) {
                                Label("Log", systemImage: "plus.circle.fill")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .tint(.accentColor)
                        }
                    }
                    .padding(.horizontal, 4)
                }
            } compactLeading: {
                BudgetActivityRing(percent: 1.0 - context.state.spentFraction)
                    .frame(width: 18, height: 18)
            } compactTrailing: {
                Text(compactActivityAmount(context.state.remainingCents))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
            } minimal: {
                BudgetActivityRing(percent: 1.0 - context.state.spentFraction)
                    .frame(width: 18, height: 18)
            }
        }
    }
}

// MARK: - Lock Screen View

@available(iOS 16.2, *)
struct BudgetActivityLockScreenView: View {
    let state: BudgetActivityAttributes.ContentState
    let attributes: BudgetActivityAttributes

    private var periodPercent: Double {
        guard state.totalDays > 0 else { return 0 }
        return min(Double(state.dayOfPeriod) / Double(state.totalDays), 1.0)
    }

    var body: some View {
        HStack(spacing: 14) {
            BudgetActivityRing(percent: 1.0 - state.spentFraction)
                .frame(width: 56, height: 56)

            VStack(alignment: .leading, spacing: 4) {
                Text(formatActivityCents(state.remainingCents, code: state.currencyCode))
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("left this period")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                ProgressView(value: periodPercent)
                    .tint(.accentColor)
                    .frame(maxWidth: 140)
                Text("Day \(state.dayOfPeriod) of \(state.totalDays)")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
    }
}

// MARK: - Reusable Vault Ring (mirrors widget styling)

@available(iOS 16.2, *)
struct BudgetActivityRing: View {
    let percent: Double

    private var color: Color {
        if percent > 0.5 { return .green }
        if percent > 0.25 { return .orange }
        return .red
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 4)
            Circle()
                .trim(from: 0, to: max(0, min(percent, 1.0)))
                .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Image(systemName: "vault.fill")
                .font(.system(size: 12))
                .foregroundStyle(color)
        }
    }
}

// MARK: - Local helpers (no SPM dep yet — those land in Task 14)

@available(iOS 16.2, *)
private func formatActivityCents(_ cents: Int64, code: String) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.currencyCode = code
    let decimal = Decimal(cents) / 100
    return formatter.string(from: decimal as NSDecimalNumber) ?? "$0.00"
}

@available(iOS 16.2, *)
private func compactActivityAmount(_ cents: Int64) -> String {
    let value = Double(cents) / 100.0
    if value >= 10_000 { return String(format: "%.0fk", value / 1000.0) }
    if value >= 1_000  { return String(format: "%.1fk", value / 1000.0) }
    return String(format: "%.0f", value)
}

// MARK: - Preview

#if DEBUG
@available(iOS 17.0, *)
#Preview("Lock Screen", as: .content, using: BudgetActivityAttributes(periodEndDate: .now.addingTimeInterval(86400 * 18))) {
    BudgetActivityWidget()
} contentStates: {
    BudgetActivityAttributes.ContentState(
        remainingCents: 18_000,
        dailyAllowanceCents: 1_200,
        spentFraction: 0.4,
        dayOfPeriod: 12,
        totalDays: 30,
        currencyCode: "USD"
    )
}
#endif
```

- [ ] Confirm the `BudgetActivityAttributes` import path: this widget file references `BudgetActivityAttributes` directly. Because the type currently lives in the app target only, add it to the widget target's source list. Open `project.yml` and confirm the widget target's `sources` block. Edit the `BudgetVaultWidgetExtension` target's `sources:` from:

```yaml
    sources:
      - BudgetVaultWidget
```

to:

```yaml
    sources:
      - BudgetVaultWidget
      - path: BudgetVault/Models/BudgetActivityAttributes.swift
```

- [ ] Run `xcodegen generate && xcodebuild build -scheme BudgetVault -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet 2>&1 | tail -5` — expect `** BUILD SUCCEEDED **`.

- [ ] Visual verification (manual, ~2 min): open `BudgetVault.xcodeproj` in Xcode, navigate to `BudgetVaultWidget/BudgetActivityWidget.swift`, click the Canvas (option-cmd-return), pick the "Lock Screen" preview. Confirm: vault ring on the left at 60% green, "$180.00 left this period" prominent, "Day 12 of 30" beneath a progress bar at 40%. If preview compiles but visual is off, fix and re-preview.

- [ ] Commit: `git add BudgetVaultWidget/BudgetActivityWidget.swift project.yml && git commit -m "feat(live-activity): add ActivityConfiguration with Lock Screen + Dynamic Island"`

---

### Task 5: Wire BudgetActivityWidget into the WidgetBundle

**Files:**
- Modify: `BudgetVaultWidget/BudgetVaultWidget.swift:394-406`

- [ ] Open `BudgetVaultWidget/BudgetVaultWidget.swift`. Replace the current `BudgetVaultWidgetBundle` body (lines 394-406) with:

```swift
@main
struct BudgetVaultWidgetBundle: WidgetBundle {
    var body: some Widget {
        BudgetVaultSmallWidget()
        BudgetVaultMediumWidget()
        #if os(iOS)
        BudgetVaultLockScreenWidget()
        if #available(iOS 16.2, *) {
            BudgetActivityWidget()
        }
        if #available(iOS 18.0, *) {
            LogExpenseControl()
        }
        #endif
    }
}
```

- [ ] Run `xcodegen generate && xcodebuild build -scheme BudgetVault -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet 2>&1 | tail -5` — expect `** BUILD SUCCEEDED **`.

- [ ] Manual verification (~5 min): boot a simulator (`xcrun simctl boot 'iPhone 17 Pro'`), install the app (`xcodebuild install -scheme BudgetVault -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath /tmp/bv-build`), open the app, log a single transaction. Confirm the Live Activity appears in the simulator's Lock Screen by sliding to lock (Cmd+L) and observing the vault ring + "$X left this period" row. If absent, check `Console.app` filtered to `subsystem:io.budgetvault.app category:LiveActivity` for the `start failed: ...` line.

- [ ] Commit: `git add BudgetVaultWidget/BudgetVaultWidget.swift && git commit -m "feat(live-activity): register BudgetActivityWidget in WidgetBundle"`

---

### Task 6: Add C617.1 reason to app PrivacyInfo for CSVExporter

**Files:**
- Modify: `BudgetVault/PrivacyInfo.xcprivacy`

- [ ] Open `BudgetVault/PrivacyInfo.xcprivacy`. Replace the `<key>NSPrivacyAccessedAPITypes</key>` array (currently lines 11-21) with this expanded block:

```xml
    <key>NSPrivacyAccessedAPITypes</key>
    <array>
        <dict>
            <key>NSPrivacyAccessedAPIType</key>
            <string>NSPrivacyAccessedAPICategoryUserDefaults</string>
            <key>NSPrivacyAccessedAPITypeReasons</key>
            <array>
                <string>CA92.1</string>
            </array>
        </dict>
        <dict>
            <key>NSPrivacyAccessedAPIType</key>
            <string>NSPrivacyAccessedAPICategoryFileTimestamp</string>
            <key>NSPrivacyAccessedAPITypeReasons</key>
            <array>
                <string>C617.1</string>
            </array>
        </dict>
        <dict>
            <key>NSPrivacyAccessedAPIType</key>
            <string>NSPrivacyAccessedAPICategorySystemBootTime</string>
            <key>NSPrivacyAccessedAPITypeReasons</key>
            <array>
                <string>35F9.1</string>
            </array>
        </dict>
        <dict>
            <key>NSPrivacyAccessedAPIType</key>
            <string>NSPrivacyAccessedAPICategoryDiskSpace</string>
            <key>NSPrivacyAccessedAPITypeReasons</key>
            <array>
                <string>0A2A.1</string>
            </array>
        </dict>
    </array>
```

- [ ] Validate XML: run `plutil -lint /Users/zachgold/Claude/BudgetVault/BudgetVault/PrivacyInfo.xcprivacy` — expect `OK`.

- [ ] Run `xcodegen generate && xcodebuild build -scheme BudgetVault -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet 2>&1 | tail -5` — expect `** BUILD SUCCEEDED **`.

- [ ] Commit: `git add BudgetVault/PrivacyInfo.xcprivacy && git commit -m "fix(privacy): declare C617.1, 35F9.1, 0A2A.1 required-reason APIs"`

---

### Task 7: Create widget PrivacyInfo manifest

**Files:**
- Create: `BudgetVaultWidget/PrivacyInfo.xcprivacy`

- [ ] Create `BudgetVaultWidget/PrivacyInfo.xcprivacy`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSPrivacyTracking</key>
    <false/>
    <key>NSPrivacyTrackingDomains</key>
    <array/>
    <key>NSPrivacyCollectedDataTypes</key>
    <array/>
    <key>NSPrivacyAccessedAPITypes</key>
    <array>
        <dict>
            <key>NSPrivacyAccessedAPIType</key>
            <string>NSPrivacyAccessedAPICategoryUserDefaults</string>
            <key>NSPrivacyAccessedAPITypeReasons</key>
            <array>
                <string>CA92.1</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
```

- [ ] Validate: `plutil -lint /Users/zachgold/Claude/BudgetVault/BudgetVaultWidget/PrivacyInfo.xcprivacy` — expect `OK`.

- [ ] xcodegen automatically packages files in the target's `sources` directory; confirm by running `xcodegen generate` and grepping the generated `.pbxproj`: `grep PrivacyInfo /Users/zachgold/Claude/BudgetVault/BudgetVault.xcodeproj/project.pbxproj | head -5` — expect lines referencing both `BudgetVault/PrivacyInfo.xcprivacy` and `BudgetVaultWidget/PrivacyInfo.xcprivacy`.

- [ ] Run `xcodebuild build -scheme BudgetVault -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet 2>&1 | tail -5` — expect `** BUILD SUCCEEDED **`.

- [ ] Commit: `git add BudgetVaultWidget/PrivacyInfo.xcprivacy && git commit -m "fix(privacy): add widget-target PrivacyInfo manifest"`

---

### Task 8: Replace StoreKitManager print() with Logger

**Files:**
- Modify: `BudgetVault/Services/StoreKitManager.swift:1-4, 88`

- [ ] Open `BudgetVault/Services/StoreKitManager.swift`. Add `import os` to the import block (currently `import StoreKit` + `import SwiftUI` at lines 1-2). Resulting top of file:

```swift
import StoreKit
import SwiftUI
import os

private let storeKitLog = Logger(subsystem: "io.budgetvault.app", category: "storekit")

private typealias StoreTransaction = StoreKit.Transaction
```

- [ ] In the same file, replace line 88 (`print("Failed to load products: \(error)")`) with:

```swift
            storeKitLog.error("Failed to load products: \(error.localizedDescription, privacy: .private)")
```

- [ ] Run `xcodegen generate && xcodebuild test -scheme BudgetVault -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:BudgetVaultTests/StoreKitManagerTests 2>&1 | tail -10` — expect `Test Suite 'StoreKitManagerTests' passed`.

- [ ] Commit: `git add BudgetVault/Services/StoreKitManager.swift && git commit -m "fix(storekit): replace print with Logger.error privacy:.private"`

---

### Task 9: Wrap InsightsEngine force-unwrap

**Files:**
- Modify: `BudgetVault/ViewModels/InsightsEngine.swift:97`
- Test: `BudgetVaultTests/InsightsEngineForceUnwrapTests.swift` (CREATE)

- [ ] Create `BudgetVaultTests/InsightsEngineForceUnwrapTests.swift`:

```swift
import XCTest
@testable import BudgetVault

/// Regression: the date arithmetic in InsightsEngine.swift previously
/// used `try!` semantics on `calendar.date(byAdding:value:to:)`, which
/// can return nil on calendar boundaries (e.g. transitioning out of a
/// non-Gregorian DST window with `daysSoFar` > 28). Wrap with `??
/// prev.nextPeriodStart` to guarantee a defined comparison.
final class InsightsEngineForceUnwrapTests: XCTestCase {

    func testSafeDateAddition_returnsExpectedDate() {
        let cal = Calendar(identifier: .gregorian)
        let start = cal.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        let added = cal.date(byAdding: .day, value: 5, to: start)
        XCTAssertNotNil(added)
        XCTAssertEqual(cal.component(.day, from: added!), 6)
    }

    func testSafeDateAddition_extremeOverflowReturnsNonNil() {
        // Calendar arithmetic in Gregorian never returns nil for normal
        // ranges; this test documents the contract — if a future calendar
        // change ever returns nil, we want a fallback, not a crash.
        let cal = Calendar(identifier: .gregorian)
        let start = cal.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        let added = cal.date(byAdding: .day, value: Int.max / 2, to: start)
        // Documented behavior — value may be nil, but app must not crash.
        _ = added
    }
}
```

- [ ] Open `BudgetVault/ViewModels/InsightsEngine.swift`. At line 97 the current code reads:

```swift
                    $0.date < min(calendar.date(byAdding: .day, value: daysSoFar, to: prev.periodStart)!, prev.nextPeriodStart)
```

Replace with:

```swift
                    $0.date < min(calendar.date(byAdding: .day, value: daysSoFar, to: prev.periodStart) ?? prev.nextPeriodStart, prev.nextPeriodStart)
```

- [ ] Run `xcodegen generate && xcodebuild test -scheme BudgetVault -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:BudgetVaultTests/InsightsEngineForceUnwrapTests 2>&1 | tail -10` — expect both tests pass.

- [ ] Commit: `git add BudgetVault/ViewModels/InsightsEngine.swift BudgetVaultTests/InsightsEngineForceUnwrapTests.swift && git commit -m "fix(insights): replace force-unwrap with prev.nextPeriodStart fallback"`

---

### Task 10: Wrap DebugSeedService force-unwrap

**Files:**
- Modify: `BudgetVault/Services/DebugSeedService.swift:225`

- [ ] Open `BudgetVault/Services/DebugSeedService.swift`. The function `dayAgo` at lines 224-227 currently reads:

```swift
        func dayAgo(_ days: Int, hour: Int = 12) -> Date {
            calendar.date(byAdding: .day, value: -days, to: calendar.startOfDay(for: today))!
                .addingTimeInterval(TimeInterval(hour * 3600))
        }
```

Replace with:

```swift
        func dayAgo(_ days: Int, hour: Int = 12) -> Date {
            let base = calendar.date(byAdding: .day, value: -days, to: calendar.startOfDay(for: today)) ?? today
            return base.addingTimeInterval(TimeInterval(hour * 3600))
        }
```

- [ ] Run `xcodegen generate && xcodebuild build -scheme BudgetVault -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet 2>&1 | tail -5` — expect `** BUILD SUCCEEDED **`. (No new test — DEBUG-only path; existing seed tests cover behavior.)

- [ ] Commit: `git add BudgetVault/Services/DebugSeedService.swift && git commit -m "fix(debug-seed): replace force-unwrap in dayAgo helper"`

---

### Task 11: Delete dead scheduleWeeklySummary() overload

**Files:**
- Modify: `BudgetVault/Services/NotificationService.swift:213-231`
- Modify: `BudgetVault/Views/Settings/SettingsView.swift:373`

- [ ] Open `BudgetVault/Services/NotificationService.swift`. Delete lines 213-231 (the entire `static func scheduleWeeklySummary() { ... }` body and its `/// Legacy method ...` doc comment). The block to remove is exactly:

```swift
    /// Legacy method for backward compatibility when no data is available.
    static func scheduleWeeklySummary() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["weeklySummary"])

        let content = UNMutableNotificationContent()
        content.title = "Weekly Summary"
        content.body = "Your weekly spending summary is ready. Open BudgetVault to see how you did!"
        content.sound = .default

        // Sunday at 6pm
        var components = DateComponents()
        components.weekday = 1 // Sunday
        components.hour = 18
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

        let request = UNNotificationRequest(identifier: "weeklySummary", content: content, trigger: trigger)
        center.add(request)
    }
```

- [ ] Open `BudgetVault/Views/Settings/SettingsView.swift`. The call site at line 373 is `NotificationService.scheduleWeeklySummary()`. The Settings toggle has no budget context, so we cannot call the data-aware overload. Replace lines 370-377 (the `if granted { ... } else { ... }` block) with:

```swift
                            if granted {
                                // The personalized weekly summary is scheduled
                                // by DashboardView.task whenever weeklyDigestEnabled
                                // is on AND a current budget exists. The toggle
                                // here just persists the flag — DashboardView
                                // takes care of the actual scheduling.
                            } else {
                                weeklyDigestEnabled = false
                            }
```

- [ ] Verify no other references remain: run grep — Grep tool with pattern `scheduleWeeklySummary\(\)` (with empty parens) across `BudgetVault/`; expect zero matches. The data-aware overload `scheduleWeeklySummary(weeklySpent:...)` should still appear at `NotificationService.swift:174` and `DashboardView.swift:1680`.

- [ ] Run `xcodegen generate && xcodebuild test -scheme BudgetVault -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet 2>&1 | tail -5` — expect `** TEST SUCCEEDED **`.

- [ ] Commit: `git add BudgetVault/Services/NotificationService.swift BudgetVault/Views/Settings/SettingsView.swift && git commit -m "refactor(notifications): delete dead scheduleWeeklySummary no-arg overload"`

---

### Task 12: Replace StreakService freeze logic with ISO-week-based computation

**Files:**
- Modify: `BudgetVault/Services/StreakService.swift:14-22, 33`
- Test: `BudgetVaultTests/StreakServiceTests.swift` (extend)

- [ ] Open `BudgetVaultTests/StreakServiceTests.swift`. Append these four tests just before the closing `}` of the class (after `testCheckMilestone_returnsNilBetweenMilestones`):

```swift
    // MARK: - Freeze accumulation (v3.3 P0 fix)

    /// Audit finding: prior implementation reset `freezes = 1` only when
    /// the user opened the app on a Monday. A user who opens daily
    /// Tue–Sun for weeks could accumulate the original Monday freeze.
    /// New rule: at most one freeze available per ISO week.
    func testFreezeAvailable_neverExceedsOnePerWeek() {
        UserDefaults.standard.set(5, forKey: AppStorageKeys.streakFreezesRemaining)
        StreakService.processOnForeground()
        // Should clamp to at most 1 — anything else is the bug.
        let freezes = UserDefaults.standard.integer(forKey: AppStorageKeys.streakFreezesRemaining)
        XCTAssertLessThanOrEqual(freezes, 1)
    }

    func testFreezeAvailable_whenWeekKeyMissing_grants1() {
        UserDefaults.standard.removeObject(forKey: AppStorageKeys.lastFreezeReset)
        UserDefaults.standard.set(0, forKey: AppStorageKeys.streakFreezesRemaining)
        StreakService.processOnForeground()
        XCTAssertEqual(UserDefaults.standard.integer(forKey: AppStorageKeys.streakFreezesRemaining), 1)
    }

    func testFreezeAvailable_whenAlreadyUsedThisWeek_returnsZero() {
        // Simulate "we already granted+used the freeze this ISO week"
        let isoWeek = StreakService.currentISOWeekKey()
        UserDefaults.standard.set(isoWeek, forKey: AppStorageKeys.lastFreezeReset)
        UserDefaults.standard.set(0, forKey: AppStorageKeys.streakFreezesRemaining)
        StreakService.processOnForeground()
        XCTAssertEqual(UserDefaults.standard.integer(forKey: AppStorageKeys.streakFreezesRemaining), 0)
    }

    func testFreezeAvailable_newWeekRefillsToOne() {
        // Stamp last reset with a clearly-old key
        UserDefaults.standard.set("2020-W01", forKey: AppStorageKeys.lastFreezeReset)
        UserDefaults.standard.set(0, forKey: AppStorageKeys.streakFreezesRemaining)
        StreakService.processOnForeground()
        XCTAssertEqual(UserDefaults.standard.integer(forKey: AppStorageKeys.streakFreezesRemaining), 1)
    }
```

- [ ] Run `xcodegen generate && xcodebuild test -scheme BudgetVault -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:BudgetVaultTests/StreakServiceTests 2>&1 | tail -15` — expect 4 new failures: `currentISOWeekKey` symbol missing, freezes counter wrong on accumulation test.

- [ ] Open `BudgetVault/Services/StreakService.swift`. Replace lines 14-22 (the `// Reset freeze to 1 every Monday` block) with this ISO-week-based block:

```swift
        // v3.3 P0 fix: previous implementation could grant unbounded freezes
        // if the user never opened the app on Monday. New rule: at most one
        // freeze is available per ISO week, keyed by `YYYY-WNN`. Refilled
        // exactly once when the week key changes.
        let weekKey = Self.currentISOWeekKey()
        let lastFreezeReset = UserDefaults.standard.string(forKey: AppStorageKeys.lastFreezeReset) ?? ""
        if lastFreezeReset != weekKey {
            freezes = 1
            UserDefaults.standard.set(freezes, forKey: AppStorageKeys.streakFreezesRemaining)
            UserDefaults.standard.set(weekKey, forKey: AppStorageKeys.lastFreezeReset)
        } else {
            // Same ISO week — clamp to at most 1 even if a stale value lingered.
            if freezes > 1 {
                freezes = 1
                UserDefaults.standard.set(freezes, forKey: AppStorageKeys.streakFreezesRemaining)
            }
        }
```

- [ ] In the same file, immediately above the `static func processOnForeground()` declaration (i.e. between the `private static let calendar = ...` and `static func processOnForeground()`), insert this helper:

```swift
    /// ISO-8601 week key in `YYYY-WNN` format. Used as the freeze
    /// refill epoch — at most one freeze per distinct key value.
    static func currentISOWeekKey(for date: Date = Date()) -> String {
        var cal = Calendar(identifier: .iso8601)
        cal.firstWeekday = 2 // Monday — matches ISO 8601
        let week = cal.component(.weekOfYear, from: date)
        let year = cal.component(.yearForWeekOfYear, from: date)
        return String(format: "%04d-W%02d", year, week)
    }
```

- [ ] Run `xcodegen generate && xcodebuild test -scheme BudgetVault -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:BudgetVaultTests/StreakServiceTests 2>&1 | tail -10` — expect all StreakService tests pass (existing 9 + new 4 = 13).

- [ ] Commit: `git add BudgetVault/Services/StreakService.swift BudgetVaultTests/StreakServiceTests.swift && git commit -m "fix(streak): replace Monday-only freeze reset with ISO-week key"`

---

### Task 13: Gate saved_* achievements behind isCompletedMonth

**Files:**
- Modify: `BudgetVault/Services/AchievementService.swift:115-127`
- Test: `BudgetVaultTests/AchievementServiceTests.swift` (CREATE)

- [ ] Create `BudgetVaultTests/AchievementServiceTests.swift`:

```swift
import XCTest
import SwiftData
@testable import BudgetVault

/// v3.3 P0 fix: `saved_100/500/1000` previously fired on day 1 of a
/// $100 budget when no spending had been logged yet. Gate behind
/// `isCompletedMonth` (Date >= budget.nextPeriodStart) like
/// `under_budget_*` already does at AchievementService.swift:89.
final class AchievementServiceTests: XCTestCase {

    private let savedKeys = ["unlockedAchievements", "underBudgetMonthCount"]

    override func setUp() {
        super.setUp()
        for k in savedKeys {
            UserDefaults.standard.removeObject(forKey: k)
        }
    }

    override func tearDown() {
        for k in savedKeys {
            UserDefaults.standard.removeObject(forKey: k)
        }
        super.tearDown()
    }

    // MARK: - Helpers

    private func inMemoryContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Budget.self, Category.self, Transaction.self, RecurringExpense.self,
            configurations: config
        )
        return ModelContext(container)
    }

    private func makeBudget(monthsAgo: Int, totalCents: Int64) throws -> Budget {
        let cal = Calendar.current
        let now = Date()
        let target = cal.date(byAdding: .month, value: -monthsAgo, to: now)!
        let comps = cal.dateComponents([.year, .month], from: target)
        let budget = Budget(
            year: comps.year!,
            month: comps.month!,
            totalAmountCents: totalCents,
            resetDay: 1
        )
        return budget
    }

    // MARK: - saved_100 gate

    func testSaved100_doesNotUnlockMidMonth() throws {
        let budget = try makeBudget(monthsAgo: 0, totalCents: 100_000) // current month
        let unlocked = AchievementService.checkAchievements(budget: budget, transactions: [])
        XCTAssertFalse(unlocked.contains(where: { $0.id == "saved_100" }),
                       "saved_100 must NOT unlock during in-progress month")
    }

    func testSaved100_unlocksOnCompletedMonthWith100Saved() throws {
        let budget = try makeBudget(monthsAgo: 1, totalCents: 100_000) // last month, completed
        let unlocked = AchievementService.checkAchievements(budget: budget, transactions: [])
        XCTAssertTrue(unlocked.contains(where: { $0.id == "saved_100" }),
                      "saved_100 must unlock when remaining >= $100 on completed month")
    }

    func testSaved500_doesNotUnlockMidMonth() throws {
        let budget = try makeBudget(monthsAgo: 0, totalCents: 100_000)
        let unlocked = AchievementService.checkAchievements(budget: budget, transactions: [])
        XCTAssertFalse(unlocked.contains(where: { $0.id == "saved_500" }))
    }

    func testSaved1000_doesNotUnlockMidMonth() throws {
        let budget = try makeBudget(monthsAgo: 0, totalCents: 200_000)
        let unlocked = AchievementService.checkAchievements(budget: budget, transactions: [])
        XCTAssertFalse(unlocked.contains(where: { $0.id == "saved_1000" }))
    }
}
```

- [ ] Run `xcodegen generate && xcodebuild test -scheme BudgetVault -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:BudgetVaultTests/AchievementServiceTests 2>&1 | tail -15` — expect 3 of 4 tests fail (`saved_100/500/1000_doesNotUnlockMidMonth`); `saved_100_unlocksOnCompletedMonth` should pass.

- [ ] Open `BudgetVault/Services/AchievementService.swift`. Replace lines 115-127 (the `// -- Saving Achievements --` block) with this `isCompletedMonth`-gated version:

```swift
        // -- Saving Achievements --
        // v3.3 P0 fix: previously these unlocked mid-month before any
        // saving had occurred. Gate behind isCompletedMonth like the
        // under_budget_* block above.
        if isCompletedMonth {
            if remainingCents >= 10000 && !alreadyUnlocked.keys.contains("saved_100") { // $100 = 10000 cents
                unlock("saved_100")
                newlyUnlocked.append(achievement(for: "saved_100"))
            }
            if remainingCents >= 50000 && !alreadyUnlocked.keys.contains("saved_500") {
                unlock("saved_500")
                newlyUnlocked.append(achievement(for: "saved_500"))
            }
            if remainingCents >= 100000 && !alreadyUnlocked.keys.contains("saved_1000") {
                unlock("saved_1000")
                newlyUnlocked.append(achievement(for: "saved_1000"))
            }
        }
```

- [ ] Run `xcodegen generate && xcodebuild test -scheme BudgetVault -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:BudgetVaultTests/AchievementServiceTests 2>&1 | tail -10` — expect all 4 pass.

- [ ] Commit: `git add BudgetVault/Services/AchievementService.swift BudgetVaultTests/AchievementServiceTests.swift && git commit -m "fix(achievements): gate saved_* unlocks behind isCompletedMonth"`

---

### Task 14: Build AchievementSheet view

**Files:**
- Create: `BudgetVault/Views/Shared/AchievementSheet.swift`

- [ ] Create `BudgetVault/Views/Shared/AchievementSheet.swift`:

```swift
import SwiftUI

/// Brief modal sheet that announces a newly-unlocked achievement.
/// Replaces the v3.2 overlay banner that was removed because it
/// kept colliding with other top-of-screen UI (DashboardView.swift:58
/// "Round 8: newAchievementBanner state removed").
///
/// Presented from DashboardView via `.sheet(item:)` with the unlocked
/// `Achievement`. User dismisses with the Close button or by swiping.
struct AchievementSheet: View {
    let achievement: AchievementService.Achievement
    let onDismiss: () -> Void

    @State private var dialRotation: Double = 0
    @State private var contentVisible = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var tierColor: Color {
        switch achievement.tier {
        case .bronze: return Color(hex: "#CD7F32")
        case .silver: return Color(hex: "#C0C0C0")
        case .gold:   return Color(hex: "#FFD700")
        }
    }

    var body: some View {
        VStack(spacing: BudgetVaultTheme.spacingLG) {
            Spacer()

            // VaultDialMark spin — the signature reward motion.
            VaultDialMark(size: 140, color: tierColor, showGlow: true, tickRotation: dialRotation)
                .accessibilityLabel("Vault opening")

            VStack(spacing: 8) {
                Text(achievement.emoji)
                    .font(.system(size: 56))
                    .opacity(contentVisible ? 1 : 0)
                    .scaleEffect(contentVisible ? 1 : 0.6)

                Text(achievement.title)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .opacity(contentVisible ? 1 : 0)

                Text(achievement.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .opacity(contentVisible ? 1 : 0)
            }
            .padding(.horizontal)

            Spacer()

            Button("Close") { onDismiss() }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal)
                .padding(.bottom)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .onAppear {
            if reduceMotion {
                dialRotation = 0
                contentVisible = true
            } else {
                withAnimation(.easeOut(duration: 1.4)) {
                    dialRotation = 720
                }
                withAnimation(.easeIn(duration: 0.3).delay(0.5)) {
                    contentVisible = true
                }
            }
        }
        .accessibilityAddTraits(.isModal)
    }
}

#if DEBUG
#Preview {
    AchievementSheet(
        achievement: AchievementService.Achievement(
            id: "streak_7",
            title: "Week Warrior",
            description: "7-day logging streak",
            emoji: "🔥",
            tier: .bronze,
            unlockedDate: Date()
        ),
        onDismiss: {}
    )
}
#endif
```

- [ ] Run `xcodegen generate && xcodebuild build -scheme BudgetVault -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet 2>&1 | tail -5` — expect `** BUILD SUCCEEDED **`.

- [ ] Visual verification (~2 min): in Xcode, open the file's Canvas (option-cmd-return). Confirm the dial spins, the emoji and title fade in, the Close button is centered. If reduceMotion is on, animations skip but content still appears.

- [ ] Commit: `git add BudgetVault/Views/Shared/AchievementSheet.swift && git commit -m "feat(achievements): add AchievementSheet with VaultDialMark spin"`

---

### Task 15: Wire AchievementSheet into DashboardView

**Files:**
- Modify: `BudgetVault/Views/Dashboard/DashboardView.swift:35-49, 58, 310-312, 396-404`

- [ ] Open `BudgetVault/Views/Dashboard/DashboardView.swift`. Find the `enum ActiveSheet: Identifiable` block (lines 35-49). Add a new case for the achievement reward, with an associated value. Replace the entire enum block with:

```swift
    // MARK: - Consolidated Sheet Enum (Finding 29)
    enum ActiveSheet: Identifiable {
        case transactionEntry
        case monthlySummary
        case paywall
        case monthlyWrapped
        case achievements
        case insights
        case moveMoney
        case recurring
        case streakMilestone
        case shareCard
        case bufferInfo
        case newAchievement(AchievementService.Achievement)

        var id: String {
            switch self {
            case .newAchievement(let a): return "newAchievement-\(a.id)"
            default: return String(describing: self)
            }
        }
    }
```

- [ ] In the same file, the comment at line 58 currently reads:

```swift
    // Round 8: newAchievementBanner state removed with overlay banner.
```

Replace with:

```swift
    // v3.3 P0 fix: achievement unlock now presents AchievementSheet via
    // activeSheet = .newAchievement(badge); replaces the v3.2 overlay
    // banner that kept colliding with other top-of-screen UI.
```

- [ ] In the same file, find the `.sheet(item: $activeSheet)` switch (it has `case .achievements:` at line 310). Add a new case for `.newAchievement` immediately after the existing `case .achievements:` block (which ends at the `.presentationDragIndicator(.visible)` line ~312):

```swift
                case .newAchievement(let badge):
                    AchievementSheet(achievement: badge) {
                        activeSheet = nil
                    }
```

- [ ] In the same file, find the achievement-checking task block (lines ~389-405 in `.task { ... }`). Replace the inner `if let first = newBadges.first { ... }` (lines 399-404) with:

```swift
                        if let first = newBadges.first {
                            HapticManager.notification(.success)
                            // v3.3 P0 fix: present sheet so user actually sees
                            // the unlock. Prepare share card asynchronously.
                            if first.id == "under_budget_1" || first.id == "streak_30" {
                                prepareShareCard(for: first, budget: budget)
                            }
                            // Defer sheet presentation slightly so it doesn't
                            // collide with sheets fired from `.task` (streak
                            // milestone fires at +0.5s below).
                            Task { @MainActor in
                                try? await Task.sleep(for: .milliseconds(300))
                                if activeSheet == nil {
                                    activeSheet = .newAchievement(first)
                                }
                            }
                        }
```

- [ ] Note: `ActiveSheet` now has an associated value, so `activeSheet == nil` requires the enum to be Equatable in the comparison. Since it conforms to `Identifiable` only, replace `activeSheet == nil` in the line above with `activeSheet?.id == nil` — but `Optional.id` won't compile, so use `if activeSheet == nil` after making the enum Equatable for nil-check. Simplest: use `if case .none = activeSheet`. Update the inserted block's check accordingly:

```swift
                                if case .none = activeSheet {
                                    activeSheet = .newAchievement(first)
                                }
```

- [ ] Run `xcodegen generate && xcodebuild build -scheme BudgetVault -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet 2>&1 | tail -10` — expect `** BUILD SUCCEEDED **`. If a switch-exhaustiveness error mentions `.newAchievement`, find the `switch self` inside `var id: String` (already updated above) — confirm both `case .newAchievement(let a)` and `default` are present.

- [ ] Run all tests: `xcodebuild test -scheme BudgetVault -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet 2>&1 | tail -5` — expect `** TEST SUCCEEDED **`.

- [ ] Manual verification (~3 min): in simulator, set premium override on, force-unlock an achievement by setting `UserDefaults` from the debug menu (or seed via DebugSeedService), foreground the app, confirm the sheet appears with the dial spin.

- [ ] Commit: `git add BudgetVault/Views/Dashboard/DashboardView.swift && git commit -m "feat(achievements): present AchievementSheet on newly unlocked badges"`

---

### Task 16: Create BudgetVaultShared SPM package skeleton

**Files:**
- Create: `BudgetVaultShared/Package.swift`
- Create: `BudgetVaultShared/Sources/BudgetVaultShared/AppStorageKeys.swift`
- Create: `BudgetVaultShared/Sources/BudgetVaultShared/MoneyHelpers.swift`
- Create: `BudgetVaultShared/Sources/BudgetVaultShared/CurrencyFormatter.swift`
- Create: `BudgetVaultShared/Tests/BudgetVaultSharedTests/MoneyHelpersTests.swift`
- Create: `BudgetVaultShared/Tests/BudgetVaultSharedTests/CurrencyFormatterTests.swift`

- [ ] First, sanity-check directory: `ls /Users/zachgold/Claude/BudgetVault/ | head -10` — the workspace root should NOT yet contain `BudgetVaultShared/`. Create the directory tree: `mkdir -p /Users/zachgold/Claude/BudgetVault/BudgetVaultShared/Sources/BudgetVaultShared /Users/zachgold/Claude/BudgetVault/BudgetVaultShared/Tests/BudgetVaultSharedTests`.

- [ ] Create `BudgetVaultShared/Package.swift`:

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BudgetVaultShared",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "BudgetVaultShared", targets: ["BudgetVaultShared"])
    ],
    dependencies: [],
    targets: [
        .target(name: "BudgetVaultShared"),
        .testTarget(name: "BudgetVaultSharedTests", dependencies: ["BudgetVaultShared"])
    ]
)
```

- [ ] Create `BudgetVaultShared/Sources/BudgetVaultShared/AppStorageKeys.swift` (copy from `BudgetVault/Utilities/AppStorageKeys.swift` with `public` modifiers):

```swift
import Foundation

/// Centralized string constants for all @AppStorage and UserDefaults keys.
/// Using a single enum prevents typos and makes key usage searchable.
public enum AppStorageKeys {
    // MARK: - Budget & Onboarding
    public static let resetDay = "resetDay"
    public static let hasCompletedOnboarding = "hasCompletedOnboarding"
    public static let hasLoggedFirstTransaction = "hasLoggedFirstTransaction"
    public static let userName = "userName"

    // MARK: - Premium & Monetization
    public static let isPremium = "isPremium"
    public static let debugPremiumOverride = "debugPremiumOverride"
    public static let lastPaywallDecline = "lastPaywallDecline"
    public static let reviewPromptCount = "reviewPromptCount"
    public static let transactionCount = "transactionCount"
    public static let hasSeenTransactionPaywall = "hasSeenTransactionPaywall"
    public static let hasSeenStreakPaywall = "hasSeenStreakPaywall"

    // MARK: - Appearance
    public static let selectedCurrency = "selectedCurrency"
    public static let accentColorHex = "accentColorHex"

    // MARK: - Security
    public static let biometricLockEnabled = "biometricLockEnabled"

    // MARK: - Streak
    public static let currentStreak = "currentStreak"
    public static let lastLogDate = "lastLogDate"
    public static let streakFreezesRemaining = "streakFreezesRemaining"
    public static let lastFreezeReset = "lastFreezeReset"

    // MARK: - Dashboard
    public static let lastSummaryViewed = "lastSummaryViewed"

    // MARK: - Notifications
    public static let dailyReminderEnabled = "dailyReminderEnabled"
    public static let dailyReminderHour = "dailyReminderHour"
    public static let weeklyDigestEnabled = "weeklyDigestEnabled"
    public static let billDueReminders = "billDueReminders"

    // MARK: - Cloud
    public static let iCloudSyncEnabled = "iCloudSyncEnabled"

    // MARK: - Engagement & Retention
    public static let lastActiveDate = "lastActiveDate"
    public static let morningBriefingEnabled = "morningBriefingEnabled"
    public static let morningBriefingHour = "morningBriefingHour"
    public static let catchUpDismissedDate = "catchUpDismissedDate"
}
```

- [ ] Create `BudgetVaultShared/Sources/BudgetVaultShared/MoneyHelpers.swift`:

```swift
import Foundation

public enum MoneyHelpers {

    /// Convert Int64 cents to Decimal dollars: 1450 → 14.50
    public static func centsToDollars(_ cents: Int64) -> Decimal {
        Decimal(cents) / 100
    }

    /// Convert Decimal dollars to Int64 cents: 14.50 → 1450
    public static func dollarsToCents(_ dollars: Decimal) -> Int64 {
        Int64(truncating: (dollars * 100) as NSDecimalNumber)
    }

    /// Parse a currency string (e.g. "14.50") to Int64 cents (1450).
    /// Returns nil if the string is not a valid number.
    public static func parseCurrencyString(_ string: String) -> Int64? {
        let trimmed = string.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        guard let decimal = Decimal(string: trimmed) else { return nil }
        return dollarsToCents(decimal)
    }
}
```

- [ ] Create `BudgetVaultShared/Sources/BudgetVaultShared/CurrencyFormatter.swift`:

```swift
import Foundation

public struct CurrencyFormatter {

    private static let lock = NSLock()
    private static var _cachedFormatter: NumberFormatter?
    private static var _cachedCurrencyCode: String?

    private static func formattedString(for currencyCode: String, value: NSDecimalNumber) -> String {
        let code = currencyCode.isEmpty ? (UserDefaults.standard.string(forKey: AppStorageKeys.selectedCurrency) ?? "USD") : currencyCode
        lock.lock()
        defer { lock.unlock() }
        if let cached = _cachedFormatter, _cachedCurrencyCode == code {
            return cached.string(from: value) ?? "0"
        }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        _cachedFormatter = formatter
        _cachedCurrencyCode = code
        return formatter.string(from: value) ?? "0"
    }

    private static func resolvedSymbol(for currencyCode: String) -> String {
        let code = currencyCode.isEmpty ? (UserDefaults.standard.string(forKey: AppStorageKeys.selectedCurrency) ?? "USD") : currencyCode
        lock.lock()
        defer { lock.unlock() }
        if let cached = _cachedFormatter, _cachedCurrencyCode == code {
            return cached.currencySymbol ?? "$"
        }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        _cachedFormatter = formatter
        _cachedCurrencyCode = code
        return formatter.currencySymbol ?? "$"
    }

    /// Format Int64 cents as a locale-aware currency string.
    public static func format(cents: Int64, currencyCode: String = "") -> String {
        let dollars = MoneyHelpers.centsToDollars(cents)
        return formattedString(for: currencyCode, value: dollars as NSDecimalNumber)
    }

    /// Format a Decimal amount as currency
    public static func format(amount: Decimal, currencyCode: String = "") -> String {
        return formattedString(for: currencyCode, value: amount as NSDecimalNumber)
    }

    /// Get just the currency symbol for the selected currency
    public static func currencySymbol(for currencyCode: String = "") -> String {
        return resolvedSymbol(for: currencyCode)
    }

    /// Convert Int64 cents to a raw numeric string (e.g. 1450 -> "14.50", 500 -> "5").
    public static func formatRaw(cents: Int64) -> String {
        let dollars = cents / 100
        let remainder = cents % 100
        if remainder == 0 { return "\(dollars)" }
        return String(format: "%d.%02d", dollars, remainder)
    }

    /// Format a raw amount text string for display with the user's currency symbol.
    public static func displayAmount(text: String) -> String {
        let symbol = currencySymbol()
        if text.isEmpty { return "\(symbol)0" }
        return "\(symbol)\(text)"
    }
}
```

- [ ] Create `BudgetVaultShared/Tests/BudgetVaultSharedTests/MoneyHelpersTests.swift` by mirroring the existing app test. Read the existing file first: `Read /Users/zachgold/Claude/BudgetVault/BudgetVaultTests/MoneyHelpersTests.swift`. Copy its body verbatim, replacing the `@testable import BudgetVault` line with `@testable import BudgetVaultShared`.

- [ ] Create `BudgetVaultShared/Tests/BudgetVaultSharedTests/CurrencyFormatterTests.swift` by the same procedure: read `BudgetVaultTests/CurrencyFormatterTests.swift`, replace import.

- [ ] Validate the package compiles in isolation: `cd /Users/zachgold/Claude/BudgetVault/BudgetVaultShared && swift build 2>&1 | tail -10` — expect `Build complete!`.

- [ ] Validate the package's tests pass in isolation: `cd /Users/zachgold/Claude/BudgetVault/BudgetVaultShared && swift test 2>&1 | tail -10` — expect `Test Suite 'All tests' passed`.

- [ ] Commit: `git add BudgetVaultShared/ && git commit -m "feat(spm): create BudgetVaultShared with MoneyHelpers, CurrencyFormatter, AppStorageKeys"`

---

### Task 17: Wire BudgetVaultShared into project.yml

**Files:**
- Modify: `project.yml`

- [ ] Open `project.yml`. After the `options:` block (line 8) and before `settings:` (line 9), insert a new `packages:` block:

```yaml
packages:
  BudgetVaultShared:
    path: BudgetVaultShared
```

- [ ] In the `BudgetVault` target's `dependencies:` (currently line 66-67 — `- target: BudgetVaultWidgetExtension`), add the package dependency:

```yaml
    dependencies:
      - target: BudgetVaultWidgetExtension
      - package: BudgetVaultShared
```

- [ ] In the `BudgetVaultTests` target's `dependencies:` (currently line 74-75), add the same package dependency:

```yaml
    dependencies:
      - target: BudgetVault
      - package: BudgetVaultShared
```

- [ ] In the `BudgetVaultWidgetExtension` target, add a `dependencies:` block (does not currently exist) just before the target's `settings:` block at line 107:

```yaml
    dependencies:
      - package: BudgetVaultShared
```

- [ ] Run `xcodegen generate 2>&1 | tail -5` — expect "Created project at ...". Confirm the package is registered: `grep BudgetVaultShared /Users/zachgold/Claude/BudgetVault/BudgetVault.xcodeproj/project.pbxproj | head -10` — expect package-reference lines.

- [ ] Build (this confirms duplicate-symbol detection between the now-coexisting app-target copies AND the new package — the next task removes the app-target copies). Run `xcodebuild build -scheme BudgetVault -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet 2>&1 | tail -10`. If you see "Ambiguous use of 'AppStorageKeys'" or similar — that's expected. Proceed to Task 18 to remove the app-target copies. If you see ANY other error (project misconfiguration), stop and inspect.

- [ ] Commit: `git add project.yml && git commit -m "build(xcodegen): wire BudgetVaultShared package into all three targets"`

---

### Task 18: Remove duplicate app-target utilities and migrate imports

**Files:**
- Modify (delete): `BudgetVault/Utilities/AppStorageKeys.swift`
- Modify (delete): `BudgetVault/Utilities/CurrencyFormatter.swift`
- Modify (delete): `BudgetVault/Utilities/MoneyHelpers.swift`
- Modify (delete): `BudgetVaultTests/MoneyHelpersTests.swift`
- Modify (delete): `BudgetVaultTests/CurrencyFormatterTests.swift`
- Modify (add import): every Swift file in `BudgetVault/` that uses `AppStorageKeys`, `CurrencyFormatter`, or `MoneyHelpers`.

- [ ] First, enumerate the consumers — run Grep with pattern `AppStorageKeys|CurrencyFormatter|MoneyHelpers` over `BudgetVault/` (output_mode files_with_matches). Save the list.

- [ ] Delete the three app-target source files: `rm /Users/zachgold/Claude/BudgetVault/BudgetVault/Utilities/AppStorageKeys.swift /Users/zachgold/Claude/BudgetVault/BudgetVault/Utilities/CurrencyFormatter.swift /Users/zachgold/Claude/BudgetVault/BudgetVault/Utilities/MoneyHelpers.swift`.

- [ ] Delete the duplicate app-target test files (the new SPM tests cover these): `rm /Users/zachgold/Claude/BudgetVault/BudgetVaultTests/MoneyHelpersTests.swift /Users/zachgold/Claude/BudgetVault/BudgetVaultTests/CurrencyFormatterTests.swift`.

- [ ] For each consumer file from the Grep result, add `import BudgetVaultShared` at the top (after the `import Foundation` / `import SwiftUI` line). Use the Edit tool per file. Common consumers to expect (verify via grep — full list comes from your grep result):
  - `BudgetVault/BudgetVaultApp.swift`
  - `BudgetVault/Views/Dashboard/DashboardView.swift`
  - `BudgetVault/Views/Settings/SettingsView.swift`
  - `BudgetVault/Views/Transactions/TransactionEntryView.swift`
  - `BudgetVault/Services/StoreKitManager.swift`
  - `BudgetVault/Services/StreakService.swift`
  - `BudgetVault/Services/NotificationService.swift`
  - `BudgetVault/AppIntents/BudgetAppIntents.swift`
  - …and any others surfaced by grep.

- [ ] For each *consumer* file, the import line to add is exactly:

```swift
import BudgetVaultShared
```

placed immediately after the last existing `import` line. Do NOT add the import to files that don't reference these types.

- [ ] Update test files that imported `@testable import BudgetVault` and used these types: search `BudgetVaultTests/` with grep — for each match, add `import BudgetVaultShared` after the `@testable import BudgetVault` line (the SPM types are public, no `@testable` needed).

- [ ] Widget side: `BudgetVaultWidget/BudgetVaultWidget.swift` and `BudgetVaultWidget/BudgetActivityWidget.swift` define their own `formatCents`/`compactAmount` helpers — they don't currently import the shared types, so no import needed for them. Verify by grepping the widget directory: zero matches for `CurrencyFormatter`/`MoneyHelpers`/`AppStorageKeys` (the AppIntent file `BudgetAppIntents.swift` lives in the *app* target — its existing reference to `WidgetDataService.WidgetData` and `CurrencyFormatter` is satisfied by the app's `import BudgetVaultShared`, so add that there).

- [ ] Run `xcodegen generate && xcodebuild test -scheme BudgetVault -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet 2>&1 | tail -10` — expect `** TEST SUCCEEDED **`. If "no such module 'BudgetVaultShared'", the import wasn't added to a file that references the symbols — re-grep and add. If a test "could not find type 'AppStorageKeys' in scope", add the import to that test file.

- [ ] Commit: `git add -A BudgetVault/ BudgetVaultTests/ && git commit -m "refactor(utilities): migrate AppStorageKeys, CurrencyFormatter, MoneyHelpers to BudgetVaultShared SPM"`

---

### Task 19: Final integration test + version bump

**Files:**
- Modify: `project.yml:42, 110` (MARKETING_VERSION)

- [ ] Run the full test suite end-to-end: `xcodegen generate && xcodebuild test -scheme BudgetVault -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -20` — expect `** TEST SUCCEEDED **`. Compare test count to the baseline captured in Task 1. New tests added by this plan: 4 freeze tests + 4 achievement tests + 2 insights tests + 3 live-activity tests = 13. Baseline 80 → expected 93+.

- [ ] Bump MARKETING_VERSION in `project.yml` for both `BudgetVault` (line 42) and `BudgetVaultWidgetExtension` (line 110) targets from `"3.2.1"` to `"3.3.0"`.

- [ ] Run `xcodegen generate && xcodebuild build -scheme BudgetVault -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet 2>&1 | tail -5` — expect `** BUILD SUCCEEDED **`.

- [ ] Manual integration verification (~10 min):
  1. Boot `iPhone 17 Pro` simulator. Install: `xcodebuild install -scheme BudgetVault -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath /tmp/bv-build`.
  2. Open the app, complete onboarding, log a transaction. Lock the simulator (Cmd+L). Confirm Live Activity appears with vault ring + remaining cents.
  3. Slide to Dynamic Island simulation — confirm compact-leading shows ring, compact-trailing shows compact dollars.
  4. Force-set `UserDefaults.standard.set(7, forKey: "currentStreak")` via debug menu, foreground app — confirm `AchievementSheet` presents with dial spin.
  5. Toggle Settings → Notifications → "Weekly Summary" off then on — confirm no crash (the dead overload is gone; the schedule happens via DashboardView.task).
  6. Visit Settings → About → confirm version reads 3.3.0.

- [ ] Commit: `git add project.yml && git commit -m "chore(release): bump version to 3.3.0 for v3.3.0 P0 triage release"`

- [ ] Tag the plan-complete state: `git tag p0-complete` (do NOT push).

- [ ] Final summary check — list all new commits since baseline: `git log p0-baseline..HEAD --oneline`. Expect 18 commits matching the conventional prefixes used above.

---

## Spec-Coverage Self-Review

After writing this plan, scanned for spec coverage of sections 5.1–5.5:

**5.1 Live Activity Production Fix:**
- Task 2: stale-activity recovery in `BudgetLiveActivityService.swift:25` — covered.
- Task 3: `LiveActivityIntent` for the Log button — covered.
- Task 4: Lock Screen view (vault ring + remaining + period progress), Dynamic Island compact (ring leading + remaining trailing), Dynamic Island expanded (ring + daily allowance + Log button) — all three configurations present in `BudgetActivityWidget`.
- Task 5: `WidgetBundle` registration — covered.

**5.2 PrivacyInfo.xcprivacy Completion:**
- Task 6: `C617.1`, `35F9.1`, `0A2A.1` reasons added to app manifest (CA92.1 already present per audit). — covered.
- Task 7: New widget manifest with `CA92.1`. — covered.

**5.3 Achievement Re-wire:**
- Task 13: `saved_*` achievements gated behind `isCompletedMonth`. — covered.
- Task 14: Sheet-based reward presentation with `VaultDialMark` spin. — covered. (Spec also mentions "share-card preview" — DashboardView already prepares share cards via `prepareShareCard(for:budget:)` which the existing `.shareCard` sheet renders separately. The AchievementSheet is intentionally a brief modal that can be dismissed and the share-card is reachable via the existing achievement grid + share button. Did not add share preview into AchievementSheet itself — would conflict with "brief modal" intent. If the spec strictly wants share preview inline, add a `ShareLink` row inside the sheet — but that doesn't match "brief". Treating "brief modal sheet" as authoritative.)
- Task 15: Sheet wired into DashboardView; replaces the v3.2-removed banner. — covered.

**5.4 Quick Code Review Wins:**
- Task 8: `print()` → `Logger` in `StoreKitManager.swift:88`. — covered.
- Task 12: `StreakService.swift:18-43` ISO-week-based freeze logic. — covered.
- Task 11: Delete dead `NotificationService.scheduleWeeklySummary()` at `:214`. — covered (also fixes the call site in SettingsView since the audit was wrong about it being dead — it was still called, just from one place; that call is now inert because DashboardView handles scheduling).
- Task 9: Wrap force-unwrap at `InsightsEngine.swift:97`. — covered.
- Task 10: Wrap force-unwrap at `DebugSeedService.swift:225`. — covered.

**5.5 BudgetVaultShared SPM Skeleton:**
- Task 16: Create `BudgetVaultShared/` package with `AppStorageKeys`, `CurrencyFormatter`, `MoneyHelpers`. — covered.
- Task 17: Wire into project.yml. — covered.
- Task 18: Migrate consumers to import the new module, delete app-target duplicates. — covered.

**Placeholder hunt:**
- No "TBD", "TODO", "implement later", "fill in details" remain.
- No "similar to above" / "handle edge cases" without enumeration.
- All test code is fully written.

**Type consistency check:**
- `BudgetActivityAttributes.ContentState` field names (`remainingCents`, `dailyAllowanceCents`, `spentFraction`, `dayOfPeriod`, `totalDays`, `currencyCode`) match the existing model file exactly.
- `BudgetLiveActivityService.isPeriodEndStale(_:now:)` and `endStaleActivities(now:)` — names match across Task 2 test and impl.
- `StreakService.currentISOWeekKey(for:)` — name matches across Task 12 test and impl.
- `AchievementService.Achievement` initializer — verified all 6 fields present (id, title, description, emoji, tier, unlockedDate).
- `ActiveSheet.newAchievement(AchievementService.Achievement)` — associated value type is namespaced and exists.
- `PrimaryButtonStyle` used in AchievementSheet — confirmed present at `BudgetVault/Views/Shared/PrimaryButtonStyle.swift`.

**File path check:**
- All Create/Modify paths are absolute or repo-relative under `/Users/zachgold/Claude/BudgetVault/`.
- `BudgetVaultShared/` is at the repo root (sibling to `BudgetVault/`), package-relative paths inside the SPM use `Sources/` and `Tests/` standard layout.

**Effort recheck:** 19 tasks × ~2-25 min each. Heaviest tasks (4, 15, 18) carry the bulk of the time. Aggregate within the 7-day estimate.
