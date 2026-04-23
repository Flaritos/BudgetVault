# Wrapped Viral Loop Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a 1080×1920 IG-Story-dimensioned share artifact for Monthly Wrapped, an auto-presenting `ShareLink` with branded caption, an on-device-only metrics counter, and a full WCAG / 44pt accessibility pass on the existing Wrapped slides — turning Wrapped from a sheet-only screen into a viral loop without compromising "Data Not Collected."

**Architecture:** A new `MonthlyWrappedShareCard` SwiftUI view sized exactly 1080×1920 renders off the main thread via `ImageRenderer` on a background `Task`. Slide 5 of the existing `MonthlyWrappedView` auto-presents `ShareLink` once the image is ready. A new `LocalMetricsService` (modeled on `FeedbackService`) writes counters to a JSON file in `Documents/`. The accessibility pass is in-place edits to `MonthlyWrappedView.swift` — opacity floor at 0.7, 44×44 tap targets, `accessibilityAdjustableAction` on the pager, `accessibilityNotification(.announcement:)` paired with every `HapticManager` call, and `.dynamicTypeSize(...DynamicTypeSize.accessibility3)` cap.

**Tech Stack:** SwiftUI, `ImageRenderer` (iOS 17+), `ShareLink`, `CoreImage.CIQRCodeGenerator`, `XCTest` snapshot tests, `XCUITest` for VoiceOver/contrast verification.

**Estimated Effort:** 4.5 days

**Ship Target:** v3.3.0

---

## File Structure

### Created
- `/Users/zachgold/Claude/BudgetVault/BudgetVault/Views/Dashboard/MonthlyWrappedShareCard.swift` — 1080×1920 share-card view with five slide variants (Saved hero, Top Category, Personality, By the Numbers, Final CTA).
- `/Users/zachgold/Claude/BudgetVault/BudgetVault/Services/LocalMetricsService.swift` — On-device-only counter store (JSON in `Documents/local-metrics.json`).
- `/Users/zachgold/Claude/BudgetVault/BudgetVault/Utilities/QRCodeGenerator.swift` — `CIQRCodeGenerator` wrapper returning `UIImage`.
- `/Users/zachgold/Claude/BudgetVault/BudgetVault/Utilities/BragStatRotator.swift` — Deterministic rotation logic for the non-financial brag stat (streak / tx count / no-spend days).
- `/Users/zachgold/Claude/BudgetVault/BudgetVaultTests/LocalMetricsServiceTests.swift` — TDD tests for counter increment, persistence, payload export.
- `/Users/zachgold/Claude/BudgetVault/BudgetVaultTests/BragStatRotatorTests.swift` — TDD tests for slot rotation + edge cases (zero streak, no transactions).
- `/Users/zachgold/Claude/BudgetVault/BudgetVaultTests/MonthlyWrappedShareCardTests.swift` — Snapshot tests at 1080×1920 for each of the 5 variants.
- `/Users/zachgold/Claude/BudgetVault/BudgetVaultUITests/WrappedAccessibilityUITests.swift` — XCUITest verifying VoiceOver labels, 44×44 hit-targets, Dynamic Type cap.
- `/Users/zachgold/Claude/BudgetVault/scripts/audit-wrapped-contrast.swift` — Standalone Swift script computing WCAG contrast ratios for every text-on-background pair in the Wrapped surface.

### Modified
- `/Users/zachgold/Claude/BudgetVault/BudgetVault/Views/Dashboard/MonthlyWrappedView.swift:9-13` — Add state for `shareImage`, `shareImageGenerationStarted`, drop unused `renderedShareImage`/`ringAppeared` reuse.
- `/Users/zachgold/Claude/BudgetVault/BudgetVault/Views/Dashboard/MonthlyWrappedView.swift:222-263` — Wire `shareImage` task on appear; add `.accessibilityAdjustableAction` to `TabView`; cap with `.dynamicTypeSize(...DynamicTypeSize.accessibility3)`.
- `/Users/zachgold/Claude/BudgetVault/BudgetVault/Views/Dashboard/MonthlyWrappedView.swift:236-246` — Bump close button to 44×44, add label/hint.
- `/Users/zachgold/Claude/BudgetVault/BudgetVault/Views/Dashboard/MonthlyWrappedView.swift:267-283` — Bump page-dot tappable area to 44×44; add `accessibilityValue` and `accessibilityElement(children: .ignore)`.
- `/Users/zachgold/Claude/BudgetVault/BudgetVault/Views/Dashboard/MonthlyWrappedView.swift:300, 302, 337, 357, 392, 414, 470, 502` — Replace `.white.opacity(0.25–0.5)` with `0.7`.
- `/Users/zachgold/Claude/BudgetVault/BudgetVault/Views/Dashboard/MonthlyWrappedView.swift:650-725` — Replace `slide5ShareCard` with auto-presenting `ShareLink` driven by `MonthlyWrappedShareCard` render.
- `/Users/zachgold/Claude/BudgetVault/BudgetVault/Views/Dashboard/MonthlyWrappedView.swift:828-859` — Replace `saveImage()` to render from `MonthlyWrappedShareCard` instead of inline `shareCardContent`.
- `/Users/zachgold/Claude/BudgetVault/BudgetVault/Utilities/AppStorageKeys.swift:50` — Add `wrappedSharesAllTime` key (used to seed BragStat tie-breaks).
- `/Users/zachgold/Claude/BudgetVault/project.yml` — No changes required (new files live under `BudgetVault/`, picked up by glob).

### Tested
- `LocalMetricsServiceTests.swift` — 8 unit tests covering increment, idempotent file writes, payload export.
- `BragStatRotatorTests.swift` — 6 unit tests covering rotation determinism, fallback when one slot is empty.
- `MonthlyWrappedShareCardTests.swift` — 5 snapshot/render tests verifying 1080×1920 output, no transparent pixels.
- `WrappedAccessibilityUITests.swift` — 4 XCUITests covering pager VoiceOver value, close-button hit-rect, Dynamic Type cap, opacity floor.
- `audit-wrapped-contrast.swift` — manual run, fails on any text-on-bg pair < 4.5:1.

---

## Tasks

### Task 1 — Add `wrappedSharesAllTime` AppStorage key

**Files:** Modify `/Users/zachgold/Claude/BudgetVault/BudgetVault/Utilities/AppStorageKeys.swift:50`

- [ ] Open `AppStorageKeys.swift` and add new section after `Engagement & Retention`:
  ```swift
      // MARK: - Local Metrics (on-device-only counters, never sent over network)
      static let wrappedSharesAllTime = "wrappedSharesAllTime"
  ```
- [ ] Build with `xcodebuild -project BudgetVault.xcodeproj -scheme BudgetVault -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build` — expect green.
- [ ] Commit: `chore(wrapped): add wrappedSharesAllTime AppStorage key`

---

### Task 2 — Write failing tests for `LocalMetricsService`

**Files:** Create `/Users/zachgold/Claude/BudgetVault/BudgetVaultTests/LocalMetricsServiceTests.swift`

- [ ] Create the test file with the following content:
  ```swift
  import XCTest
  @testable import BudgetVault

  /// LocalMetricsService is the on-device-only counter store mirroring
  /// FeedbackService. NEVER sends data over the network — counters surface
  /// only via a user-initiated FeedbackService payload export.
  final class LocalMetricsServiceTests: XCTestCase {

      override func setUp() {
          super.setUp()
          LocalMetricsService.clearAll()
      }

      override func tearDown() {
          LocalMetricsService.clearAll()
          super.tearDown()
      }

      func testCounter_startsAtZero() {
          XCTAssertEqual(LocalMetricsService.value(for: .wrappedShareTaps), 0)
      }

      func testIncrement_addsOne() {
          LocalMetricsService.increment(.wrappedShareTaps)
          XCTAssertEqual(LocalMetricsService.value(for: .wrappedShareTaps), 1)
      }

      func testIncrement_isAdditive() {
          LocalMetricsService.increment(.wrappedShareTaps)
          LocalMetricsService.increment(.wrappedShareTaps)
          LocalMetricsService.increment(.wrappedShareTaps)
          XCTAssertEqual(LocalMetricsService.value(for: .wrappedShareTaps), 3)
      }

      func testCounters_isolatedPerKey() {
          LocalMetricsService.increment(.wrappedShareTaps)
          LocalMetricsService.increment(.paywallViews)
          LocalMetricsService.increment(.paywallViews)
          XCTAssertEqual(LocalMetricsService.value(for: .wrappedShareTaps), 1)
          XCTAssertEqual(LocalMetricsService.value(for: .paywallViews), 2)
      }

      func testCounters_persistAcrossLoad() {
          LocalMetricsService.increment(.quickAddUses)
          LocalMetricsService.increment(.quickAddUses)
          LocalMetricsService.flushForTesting()
          XCTAssertEqual(LocalMetricsService.value(for: .quickAddUses), 2)
      }

      func testPayloadString_includesAllCounters() {
          LocalMetricsService.increment(.wrappedShareTaps)
          LocalMetricsService.increment(.paywallViews)
          LocalMetricsService.increment(.paywallDismissals)
          LocalMetricsService.increment(.quickAddUses)
          let payload = LocalMetricsService.payloadString()
          XCTAssertTrue(payload.contains("wrapped_share_taps: 1"))
          XCTAssertTrue(payload.contains("paywall_views: 1"))
          XCTAssertTrue(payload.contains("paywall_dismissals: 1"))
          XCTAssertTrue(payload.contains("quick_add_uses: 1"))
      }

      func testClearAll_resetsCounters() {
          LocalMetricsService.increment(.wrappedShareTaps)
          LocalMetricsService.clearAll()
          XCTAssertEqual(LocalMetricsService.value(for: .wrappedShareTaps), 0)
      }

      func testKeyRawValues_matchSpec() {
          // Spec 5.11 names these counters explicitly; the raw values become
          // a public surface (visible in support emails) and must not drift.
          XCTAssertEqual(LocalMetricsService.Key.wrappedShareTaps.rawValue, "wrapped_share_taps")
          XCTAssertEqual(LocalMetricsService.Key.paywallViews.rawValue, "paywall_views")
          XCTAssertEqual(LocalMetricsService.Key.paywallDismissals.rawValue, "paywall_dismissals")
          XCTAssertEqual(LocalMetricsService.Key.quickAddUses.rawValue, "quick_add_uses")
      }
  }
  ```
- [ ] Run: `xcodebuild test -project BudgetVault.xcodeproj -scheme BudgetVault -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:BudgetVaultTests/LocalMetricsServiceTests` — expect failure (`Cannot find 'LocalMetricsService' in scope`).

---

### Task 3 — Implement `LocalMetricsService` to make tests pass

**Files:** Create `/Users/zachgold/Claude/BudgetVault/BudgetVault/Services/LocalMetricsService.swift`

- [ ] Create the file with this content:
  ```swift
  import Foundation

  /// Privacy-clean local counter store. NEVER sends data over the network.
  /// Mirrors FeedbackService's on-device-only pattern. Counters surface only
  /// when the user explicitly exports their FeedbackService payload.
  ///
  /// Introduced in v3.3.0 (spec section 5.11) to give us funnel visibility
  /// (`wrapped_share_taps`, `paywall_views`, `paywall_dismissals`,
  /// `quick_add_uses`) without violating "Data Not Collected."
  enum LocalMetricsService {

      enum Key: String, CaseIterable {
          case wrappedShareTaps = "wrapped_share_taps"
          case paywallViews = "paywall_views"
          case paywallDismissals = "paywall_dismissals"
          case quickAddUses = "quick_add_uses"
      }

      private static var fileURL: URL {
          let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
          return docs.appendingPathComponent("local-metrics.json")
      }

      static func value(for key: Key) -> Int {
          loadAll()[key.rawValue] ?? 0
      }

      static func increment(_ key: Key) {
          var all = loadAll()
          all[key.rawValue, default: 0] += 1
          write(all)
      }

      static func clearAll() {
          try? FileManager.default.removeItem(at: fileURL)
      }

      /// Renders all counters as a multi-line string suitable for inclusion
      /// in a FeedbackService support payload. Stable line ordering by key.
      static func payloadString() -> String {
          let all = loadAll()
          return Key.allCases
              .map { "\($0.rawValue): \(all[$0.rawValue] ?? 0)" }
              .joined(separator: "\n")
      }

      /// Test-only synchronization helper. Production calls already write
      /// atomically; this exists so tests can assert post-write reads.
      static func flushForTesting() { _ = loadAll() }

      // MARK: - Private

      private static func loadAll() -> [String: Int] {
          guard let data = try? Data(contentsOf: fileURL) else { return [:] }
          return (try? JSONDecoder().decode([String: Int].self, from: data)) ?? [:]
      }

      private static func write(_ dict: [String: Int]) {
          let encoder = JSONEncoder()
          encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
          if let data = try? encoder.encode(dict) {
              try? data.write(to: fileURL, options: .atomic)
          }
      }
  }
  ```
- [ ] Run `xcodegen generate` to refresh the project file with the new source.
- [ ] Re-run: `xcodebuild test -project BudgetVault.xcodeproj -scheme BudgetVault -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:BudgetVaultTests/LocalMetricsServiceTests` — expect 8 passes.
- [ ] Commit: `feat(metrics): add on-device LocalMetricsService for funnel counters`

---

### Task 4 — Surface `LocalMetricsService` payload via `FeedbackService`

**Files:** Modify `/Users/zachgold/Claude/BudgetVault/BudgetVault/Services/FeedbackService.swift:84-104`

- [ ] In `FeedbackService.mailtoURL(to:)`, change the `header` definition (line 86) from:
  ```swift
  let header = "BudgetVault Feedback Export\n" +
               "Generated: \(ISO8601DateFormatter().string(from: Date()))\n" +
               "Entries: \(entries.count)\n\n"
  ```
  to:
  ```swift
  let header = "BudgetVault Feedback Export\n" +
               "Generated: \(ISO8601DateFormatter().string(from: Date()))\n" +
               "Entries: \(entries.count)\n\n" +
               "--- On-device counters (no network) ---\n" +
               LocalMetricsService.payloadString() + "\n\n"
  ```
- [ ] Build: `xcodebuild build -project BudgetVault.xcodeproj -scheme BudgetVault -destination 'platform=iOS Simulator,name=iPhone 17 Pro'` — expect green.
- [ ] Commit: `feat(metrics): include LocalMetricsService payload in FeedbackService export`

---

### Task 5 — Write failing tests for `BragStatRotator`

**Files:** Create `/Users/zachgold/Claude/BudgetVault/BudgetVaultTests/BragStatRotatorTests.swift`

- [ ] Create the test file:
  ```swift
  import XCTest
  @testable import BudgetVault

  /// BragStatRotator picks ONE of three non-financial brag stats per Wrapped
  /// share so low-spend users still want to share. Spec 5.10 USER DECISION:
  /// "ALL THREE rotating (streak, tx count, no-spend days)."
  final class BragStatRotatorTests: XCTestCase {

      func testPick_streakSlot_rendersStreakLine() {
          let stat = BragStatRotator.pick(slot: 0, streakDays: 47, txCount: 182, zeroSpendDays: 12)
          XCTAssertEqual(stat, "47-day streak")
      }

      func testPick_txCountSlot_rendersTxLine() {
          let stat = BragStatRotator.pick(slot: 1, streakDays: 47, txCount: 182, zeroSpendDays: 12)
          XCTAssertEqual(stat, "182 logs")
      }

      func testPick_zeroSpendSlot_rendersZeroSpendLine() {
          let stat = BragStatRotator.pick(slot: 2, streakDays: 47, txCount: 182, zeroSpendDays: 12)
          XCTAssertEqual(stat, "12 no-spend days")
      }

      func testPick_streakZero_skipsToTxCountSlot() {
          let stat = BragStatRotator.pick(slot: 0, streakDays: 0, txCount: 182, zeroSpendDays: 12)
          XCTAssertEqual(stat, "182 logs", "Empty streak should fall through to next non-empty slot")
      }

      func testPick_allEmpty_returnsBudgetVaultBrand() {
          let stat = BragStatRotator.pick(slot: 0, streakDays: 0, txCount: 0, zeroSpendDays: 0)
          XCTAssertEqual(stat, "Privacy-first budgeting")
      }

      func testPick_slotWrapsModulo3() {
          let s0 = BragStatRotator.pick(slot: 3, streakDays: 47, txCount: 182, zeroSpendDays: 12)
          let s1 = BragStatRotator.pick(slot: 4, streakDays: 47, txCount: 182, zeroSpendDays: 12)
          let s2 = BragStatRotator.pick(slot: 5, streakDays: 47, txCount: 182, zeroSpendDays: 12)
          XCTAssertEqual(s0, "47-day streak")
          XCTAssertEqual(s1, "182 logs")
          XCTAssertEqual(s2, "12 no-spend days")
      }
  }
  ```
- [ ] Run: `xcodebuild test ... -only-testing:BudgetVaultTests/BragStatRotatorTests` — expect 6 failures (`Cannot find 'BragStatRotator'`).

---

### Task 6 — Implement `BragStatRotator`

**Files:** Create `/Users/zachgold/Claude/BudgetVault/BudgetVault/Utilities/BragStatRotator.swift`

- [ ] Create:
  ```swift
  import Foundation

  /// Picks ONE non-financial brag stat per Wrapped share. Per spec 5.10 user
  /// decision, all three slots rotate (streak / tx count / no-spend days)
  /// keyed by `wrappedSharesAllTime` so successive shares cycle naturally.
  /// Empty slots fall through to the next non-empty one; if all empty, the
  /// brand fallback ships ("Privacy-first budgeting").
  enum BragStatRotator {

      static func pick(slot: Int, streakDays: Int, txCount: Int, zeroSpendDays: Int) -> String {
          let candidates: [String?] = [
              streakDays > 0 ? "\(streakDays)-day streak" : nil,
              txCount > 0 ? "\(txCount) logs" : nil,
              zeroSpendDays > 0 ? "\(zeroSpendDays) no-spend days" : nil
          ]

          // Try the requested slot, then walk forward modulo 3.
          for offset in 0..<3 {
              let i = (slot + offset) % 3
              if let s = candidates[i] { return s }
          }
          return "Privacy-first budgeting"
      }

      /// Convenience that pulls the rotation slot from on-device share count.
      static func currentBragStat(streakDays: Int, txCount: Int, zeroSpendDays: Int) -> String {
          let slot = UserDefaults.standard.integer(forKey: AppStorageKeys.wrappedSharesAllTime)
          return pick(slot: slot, streakDays: streakDays, txCount: txCount, zeroSpendDays: zeroSpendDays)
      }
  }
  ```
- [ ] `xcodegen generate`
- [ ] Re-run: `xcodebuild test ... -only-testing:BudgetVaultTests/BragStatRotatorTests` — expect 6 passes.
- [ ] Commit: `feat(wrapped): add BragStatRotator for non-financial share brag`

---

### Task 7 — Implement `QRCodeGenerator` utility

**Files:** Create `/Users/zachgold/Claude/BudgetVault/BudgetVault/Utilities/QRCodeGenerator.swift`

- [ ] Create:
  ```swift
  import UIKit
  import CoreImage.CIFilterBuiltins

  /// Generates a high-contrast QR code suitable for embedding in the
  /// MonthlyWrappedShareCard. Renders at the requested point-size at 3x
  /// scale so it stays crisp inside the 1080×1920 ImageRenderer output.
  enum QRCodeGenerator {

      /// Returns a QR code as a UIImage. Falls back to a 1×1 transparent
      /// pixel if Core Image fails (never returns nil — caller doesn't
      /// branch).
      static func image(for string: String, size: CGFloat = 120) -> UIImage {
          let context = CIContext()
          let filter = CIFilter.qrCodeGenerator()
          filter.message = Data(string.utf8)
          filter.correctionLevel = "H"

          guard let output = filter.outputImage else { return Self.emptyPixel }

          // Scale up — CIQRCodeGenerator emits a tiny image; we want
          // pixel-perfect bars at the target point size.
          let scale = (size * 3) / output.extent.width  // 3x for retina
          let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

          guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else {
              return Self.emptyPixel
          }
          return UIImage(cgImage: cgImage, scale: 3, orientation: .up)
      }

      private static let emptyPixel: UIImage = {
          let r = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1))
          return r.image { _ in }
      }()
  }
  ```
- [ ] `xcodegen generate`
- [ ] Build: `xcodebuild build ...` — expect green.
- [ ] Commit: `feat(wrapped): add QRCodeGenerator for share-card App Store link`

---

### Task 8 — Write failing snapshot tests for `MonthlyWrappedShareCard`

**Files:** Create `/Users/zachgold/Claude/BudgetVault/BudgetVaultTests/MonthlyWrappedShareCardTests.swift`

- [ ] Create:
  ```swift
  import XCTest
  import SwiftUI
  @testable import BudgetVault

  /// Verifies the share card renders at the spec-required 1080×1920
  /// dimensions with no transparent gaps. The 5 variants must each fill
  /// the full canvas in brand navy regardless of user accentColor.
  @MainActor
  final class MonthlyWrappedShareCardTests: XCTestCase {

      private let target = CGSize(width: 1080, height: 1920)

      private func render(_ variant: MonthlyWrappedShareCard.Variant) -> UIImage? {
          // Force a non-brand accent to verify the card overrides it.
          // Superseded 2026-04-22: theme picker retired in v3.3.1 — accentColorHex no longer exists. Test no longer needed.
          UserDefaults.standard.set("#F43F5E", forKey: AppStorageKeys.accentColorHex)

          let card = MonthlyWrappedShareCard(
              variant: variant,
              monthName: "MARCH",
              monthYear: "March 2026",
              savedCents: 75_000,
              savedPercent: 32,
              spentPercent: 68,
              totalIncomeCents: 500_000,
              totalSpentCents: 425_000,
              topCategoryName: "Groceries",
              topCategoryEmoji: "\u{1F37D}\u{FE0F}",
              topCategoryCents: 120_000,
              topCategoryPercent: 28,
              transactionCount: 182,
              avgDailyCents: 13_700,
              zeroSpendDays: 12,
              streakDays: 47,
              personalityName: "Smart Saver",
              personalityEmoji: "\u{1F48E}",
              bragStat: "47-day streak"
          )
          .frame(width: target.width, height: target.height)

          let renderer = ImageRenderer(content: card)
          renderer.scale = 1
          renderer.proposedSize = .init(target)
          return renderer.uiImage
      }

      func testSavedHero_rendersAt1080x1920() {
          let img = render(.savedHero)
          XCTAssertNotNil(img)
          XCTAssertEqual(img?.size, target)
      }

      func testTopCategory_rendersAt1080x1920() {
          XCTAssertEqual(render(.topCategory)?.size, target)
      }

      func testPersonality_rendersAt1080x1920() {
          XCTAssertEqual(render(.personality)?.size, target)
      }

      func testByTheNumbers_rendersAt1080x1920() {
          XCTAssertEqual(render(.byTheNumbers)?.size, target)
      }

      func testFinalCTA_rendersAt1080x1920() {
          XCTAssertEqual(render(.finalCTA)?.size, target)
      }

      func testCard_isOpaque_noAlphaChannel() {
          // Sample the top-left pixel of every variant — must be brand navy
          // (R≈15 G≈27 B≈51 from #0F1B33), never transparent.
          for variant in MonthlyWrappedShareCard.Variant.allCases {
              guard let img = render(variant), let cg = img.cgImage else {
                  XCTFail("Render failed for \(variant)"); continue
              }
              let data = CFDataGetBytePtr(cg.dataProvider!.data!)!
              let alpha = data[3]
              XCTAssertEqual(alpha, 255, "Variant \(variant) has transparent top-left pixel")
          }
      }
  }
  ```
- [ ] Run: `xcodebuild test ... -only-testing:BudgetVaultTests/MonthlyWrappedShareCardTests` — expect 6 failures (type missing).

---

### Task 9 — Implement `MonthlyWrappedShareCard` view (full code)

**Files:** Create `/Users/zachgold/Claude/BudgetVault/BudgetVault/Views/Dashboard/MonthlyWrappedShareCard.swift`

- [ ] Create the file with this complete content:
  ```swift
  import SwiftUI

  /// Story-dimensioned (1080×1920) share artifact for Monthly Wrapped.
  /// Per spec 5.9, this view ALWAYS renders in brand navy regardless of
  /// the user's accent color, so shared images are recognizably BudgetVault
  /// in social feeds. Composition: VaultDialMark watermark (top-left) +
  /// content + "budgetvault.io" wordmark + App Store QR (bottom).
  struct MonthlyWrappedShareCard: View {

      enum Variant: String, CaseIterable {
          case savedHero
          case topCategory
          case personality
          case byTheNumbers
          case finalCTA
      }

      let variant: Variant
      let monthName: String          // "MARCH"
      let monthYear: String          // "March 2026"
      let savedCents: Int64
      let savedPercent: Double
      let spentPercent: Double
      let totalIncomeCents: Int64
      let totalSpentCents: Int64
      let topCategoryName: String
      let topCategoryEmoji: String
      let topCategoryCents: Int64
      let topCategoryPercent: Double
      let transactionCount: Int
      let avgDailyCents: Int64
      let zeroSpendDays: Int
      let streakDays: Int
      let personalityName: String
      let personalityEmoji: String
      let bragStat: String           // "47-day streak" / "182 logs" / etc.

      // Brand-locked colors — DO NOT honor user accentColor here (spec 5.9).
      private let navyDark = BudgetVaultTheme.navyDark
      private let navyMid = BudgetVaultTheme.navyMid
      private let neonGreen = BudgetVaultTheme.neonGreen
      private let neonPurple = BudgetVaultTheme.neonPurple
      private let neonRed = BudgetVaultTheme.negative

      var body: some View {
          ZStack {
              background
              VStack(spacing: 0) {
                  watermark
                      .padding(.top, 80)
                      .padding(.leading, 80)
                      .frame(maxWidth: .infinity, alignment: .leading)

                  Spacer(minLength: 0)
                  content
                  Spacer(minLength: 0)

                  footer
                      .padding(.bottom, 100)
                      .padding(.horizontal, 80)
              }
          }
          .frame(width: 1080, height: 1920)
          .environment(\.colorScheme, .dark)
      }

      // MARK: - Background

      private var background: some View {
          LinearGradient(
              colors: [navyDark, navyMid, navyDark],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
          )
      }

      // MARK: - Watermark

      private var watermark: some View {
          HStack(spacing: 16) {
              VaultDialMark(size: 60, color: .white)
              Text("BUDGETVAULT")
                  .font(.system(size: 26, weight: .bold, design: .rounded))
                  .tracking(4)
                  .foregroundStyle(.white.opacity(0.85))
          }
      }

      // MARK: - Footer

      private var footer: some View {
          HStack(alignment: .bottom) {
              VStack(alignment: .leading, spacing: 8) {
                  Text("budgetvault.io")
                      .font(.system(size: 36, weight: .semibold, design: .rounded))
                      .foregroundStyle(.white)
                  Text("$14.99 once. No bank login. Ever.")
                      .font(.system(size: 22, weight: .medium))
                      .foregroundStyle(.white.opacity(0.7))
              }
              Spacer()
              qrBlock
          }
      }

      private var qrBlock: some View {
          VStack(spacing: 8) {
              Image(uiImage: QRCodeGenerator.image(for: "https://budgetvault.io", size: 160))
                  .interpolation(.none)
                  .resizable()
                  .frame(width: 160, height: 160)
                  .padding(12)
                  .background(.white, in: RoundedRectangle(cornerRadius: 16))
              Text("Scan to install")
                  .font(.system(size: 18, weight: .medium))
                  .foregroundStyle(.white.opacity(0.7))
          }
      }

      // MARK: - Content (per variant)

      @ViewBuilder
      private var content: some View {
          switch variant {
          case .savedHero: savedHeroContent
          case .topCategory: topCategoryContent
          case .personality: personalityContent
          case .byTheNumbers: byTheNumbersContent
          case .finalCTA: finalCTAContent
          }
      }

      // Slide 1 — saved-amount donut hero
      private var savedHeroContent: some View {
          VStack(spacing: 56) {
              Text("YOUR \(monthName) STORY")
                  .font(.system(size: 28, weight: .bold))
                  .tracking(8)
                  .foregroundStyle(.white.opacity(0.7))

              ZStack {
                  Circle()
                      .stroke(.white.opacity(0.08), lineWidth: 36)
                      .frame(width: 560, height: 560)
                  Circle()
                      .trim(from: 0, to: max(min(savedPercent / 100.0, 1.0), 0.001))
                      .stroke(neonGreen, style: StrokeStyle(lineWidth: 36, lineCap: .round))
                      .rotationEffect(.degrees(-90))
                      .frame(width: 560, height: 560)
                      .shadow(color: neonGreen.opacity(0.5), radius: 24)

                  VStack(spacing: 12) {
                      Text("SAVED")
                          .font(.system(size: 26, weight: .semibold))
                          .tracking(6)
                          .foregroundStyle(.white.opacity(0.7))
                      Text(CurrencyFormatter.format(cents: savedCents))
                          .font(.system(size: 110, weight: .bold, design: .rounded))
                          .foregroundStyle(.white)
                          .minimumScaleFactor(0.5)
                          .lineLimit(1)
                          .padding(.horizontal, 40)
                      Text(String(format: "%.0f%% of income", savedPercent))
                          .font(.system(size: 32, weight: .semibold, design: .rounded))
                          .foregroundStyle(neonGreen)
                  }
              }

              Text(bragStat)
                  .font(.system(size: 28, weight: .semibold, design: .rounded))
                  .foregroundStyle(.white.opacity(0.85))
                  .padding(.horizontal, 40)
                  .padding(.vertical, 14)
                  .background(.white.opacity(0.10), in: Capsule())
          }
          .padding(.horizontal, 80)
      }

      // Slide 2 — top spending category
      private var topCategoryContent: some View {
          VStack(spacing: 48) {
              Text("WHERE IT WENT")
                  .font(.system(size: 28, weight: .bold))
                  .tracking(8)
                  .foregroundStyle(.white.opacity(0.7))

              Text(topCategoryEmoji)
                  .font(.system(size: 240))

              Text(topCategoryName)
                  .font(.system(size: 96, weight: .bold, design: .rounded))
                  .foregroundStyle(.white)
                  .multilineTextAlignment(.center)
                  .minimumScaleFactor(0.5)
                  .lineLimit(2)
                  .padding(.horizontal, 80)

              Text(CurrencyFormatter.format(cents: topCategoryCents))
                  .font(.system(size: 64, weight: .bold, design: .rounded))
                  .foregroundStyle(neonPurple)

              Text(String(format: "%.0f%% of total spend", topCategoryPercent))
                  .font(.system(size: 32, weight: .semibold))
                  .foregroundStyle(.white.opacity(0.7))
          }
          .padding(.horizontal, 80)
      }

      // Slide 3 — spending personality
      private var personalityContent: some View {
          VStack(spacing: 48) {
              Text("YOUR SPENDING TYPE")
                  .font(.system(size: 28, weight: .bold))
                  .tracking(8)
                  .foregroundStyle(.white.opacity(0.7))

              Text(personalityEmoji)
                  .font(.system(size: 280))
                  .shadow(color: neonPurple.opacity(0.5), radius: 32)

              Text(personalityName)
                  .font(.system(size: 88, weight: .bold, design: .rounded))
                  .foregroundStyle(
                      LinearGradient(
                          colors: [neonGreen, neonPurple],
                          startPoint: .leading,
                          endPoint: .trailing
                      )
                  )
                  .multilineTextAlignment(.center)
                  .minimumScaleFactor(0.5)
                  .lineLimit(2)
                  .padding(.horizontal, 40)

              Text(bragStat)
                  .font(.system(size: 28, weight: .semibold, design: .rounded))
                  .foregroundStyle(.white.opacity(0.85))
                  .padding(.horizontal, 40)
                  .padding(.vertical, 14)
                  .background(.white.opacity(0.10), in: Capsule())
          }
          .padding(.horizontal, 80)
      }

      // Slide 4 — stats grid
      private var byTheNumbersContent: some View {
          VStack(spacing: 56) {
              Text("BY THE NUMBERS")
                  .font(.system(size: 28, weight: .bold))
                  .tracking(8)
                  .foregroundStyle(.white.opacity(0.7))

              VStack(spacing: 40) {
                  numberRow(value: "\(transactionCount)", label: "transactions logged")
                  numberRow(value: CurrencyFormatter.format(cents: avgDailyCents), label: "average daily spend")
                  numberRow(value: "\(zeroSpendDays)", label: "zero-spend days")
                  numberRow(value: "\(streakDays)", label: "day streak")
              }
              .padding(.horizontal, 60)
          }
          .padding(.horizontal, 80)
      }

      private func numberRow(value: String, label: String) -> some View {
          HStack(alignment: .firstTextBaseline) {
              Text(value)
                  .font(.system(size: 80, weight: .bold, design: .rounded))
                  .foregroundStyle(.white)
                  .frame(width: 380, alignment: .trailing)
                  .lineLimit(1)
                  .minimumScaleFactor(0.5)
              Text(label)
                  .font(.system(size: 32, weight: .semibold))
                  .foregroundStyle(.white.opacity(0.85))
                  .padding(.leading, 32)
                  .frame(maxWidth: .infinity, alignment: .leading)
          }
      }

      // Slide 5 — final CTA / share-driver
      private var finalCTAContent: some View {
          VStack(spacing: 56) {
              Text(monthYear.uppercased())
                  .font(.system(size: 28, weight: .bold))
                  .tracking(8)
                  .foregroundStyle(.white.opacity(0.7))

              Text(CurrencyFormatter.format(cents: savedCents))
                  .font(.system(size: 140, weight: .bold, design: .rounded))
                  .foregroundStyle(.white)
                  .minimumScaleFactor(0.4)
                  .lineLimit(1)
                  .padding(.horizontal, 40)

              Text("saved this month")
                  .font(.system(size: 36, weight: .semibold))
                  .foregroundStyle(.white.opacity(0.85))

              VStack(spacing: 16) {
                  badgeStat(value: personalityName, label: "personality", color: neonPurple)
                  badgeStat(value: bragStat, label: "this month", color: neonGreen)
                  badgeStat(value: "Privacy-first", label: "no bank login", color: .white)
              }
              .padding(.horizontal, 80)
          }
          .padding(.horizontal, 80)
      }

      private func badgeStat(value: String, label: String, color: Color) -> some View {
          HStack {
              Text(value)
                  .font(.system(size: 32, weight: .bold, design: .rounded))
                  .foregroundStyle(color)
              Spacer()
              Text(label)
                  .font(.system(size: 26, weight: .medium))
                  .foregroundStyle(.white.opacity(0.7))
          }
          .padding(.horizontal, 32)
          .padding(.vertical, 22)
          .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 20))
          .overlay(
              RoundedRectangle(cornerRadius: 20)
                  .strokeBorder(.white.opacity(0.12), lineWidth: 1)
          )
      }
  }

  #Preview("Saved Hero", traits: .sizeThatFitsLayout) {
      MonthlyWrappedShareCard(
          variant: .savedHero,
          monthName: "MARCH", monthYear: "March 2026",
          savedCents: 75_000, savedPercent: 32, spentPercent: 68,
          totalIncomeCents: 500_000, totalSpentCents: 425_000,
          topCategoryName: "Groceries", topCategoryEmoji: "\u{1F37D}\u{FE0F}",
          topCategoryCents: 120_000, topCategoryPercent: 28,
          transactionCount: 182, avgDailyCents: 13_700, zeroSpendDays: 12,
          streakDays: 47, personalityName: "Smart Saver",
          personalityEmoji: "\u{1F48E}", bragStat: "47-day streak"
      ).scaleEffect(0.25)
  }

  #Preview("Final CTA", traits: .sizeThatFitsLayout) {
      MonthlyWrappedShareCard(
          variant: .finalCTA,
          monthName: "MARCH", monthYear: "March 2026",
          savedCents: 75_000, savedPercent: 32, spentPercent: 68,
          totalIncomeCents: 500_000, totalSpentCents: 425_000,
          topCategoryName: "Groceries", topCategoryEmoji: "\u{1F37D}\u{FE0F}",
          topCategoryCents: 120_000, topCategoryPercent: 28,
          transactionCount: 182, avgDailyCents: 13_700, zeroSpendDays: 12,
          streakDays: 47, personalityName: "Smart Saver",
          personalityEmoji: "\u{1F48E}", bragStat: "47-day streak"
      ).scaleEffect(0.25)
  }
  ```
- [ ] `xcodegen generate`
- [ ] Re-run snapshot tests: `xcodebuild test ... -only-testing:BudgetVaultTests/MonthlyWrappedShareCardTests` — expect 6 passes.
- [ ] Open `MonthlyWrappedShareCard.swift` in Xcode → use Canvas Preview to visually verify both `Saved Hero` and `Final CTA` previews render with brand navy + neon green ring + QR + watermark.
- [ ] Commit: `feat(wrapped): add 1080x1920 MonthlyWrappedShareCard with 5 variants`

---

### Task 10 — Add async render helper to `MonthlyWrappedView` (off-main-thread)

**Files:** Modify `/Users/zachgold/Claude/BudgetVault/BudgetVault/Views/Dashboard/MonthlyWrappedView.swift:9-13` (state) and add a new private method.

- [ ] At the top of `MonthlyWrappedView`, change the state block (lines 9-13):
  ```swift
      @State private var currentPage = 0
      @State private var showSaveSuccess = false
      @State private var showPhotoPermissionDenied = false
      @State private var renderedShareImage: Image?
      @State private var ringAppeared = false
  ```
  to:
  ```swift
      @State private var currentPage = 0
      @State private var showSaveSuccess = false
      @State private var showPhotoPermissionDenied = false
      @State private var ringAppeared = false
      @State private var shareImage: Image?
      @State private var sharePNGData: Data?
      @State private var shareImageGenerationStarted = false
  ```
- [ ] In the same file, find the existing `renderShareCardImage()` method (lines 803-826). Replace its body with a delegating implementation, and append a new `generateShareArtifactIfNeeded()` async method. Replace lines 803-826 with:
  ```swift
      @MainActor
      private func renderShareCardImage() -> Image {
          // Legacy synchronous path retained for in-sheet preview only;
          // off-screen 1080x1920 render is in generateShareArtifactIfNeeded().
          let card = MonthlyWrappedShareCard(
              variant: .finalCTA,
              monthName: monthName, monthYear: monthYearString,
              savedCents: savedCents, savedPercent: savedPercent, spentPercent: spentPercent,
              totalIncomeCents: budget.totalIncomeCents, totalSpentCents: totalSpentCents,
              topCategoryName: topCategory?.name ?? "—",
              topCategoryEmoji: topCategory?.emoji ?? "\u{1F4B0}",
              topCategoryCents: topCategorySpent, topCategoryPercent: topCategoryPercent,
              transactionCount: periodTransactions.count,
              avgDailyCents: averageDailySpendCents,
              zeroSpendDays: zeroSpendDays,
              streakDays: currentStreak,
              personalityName: personalityType.name,
              personalityEmoji: personalityType.emoji,
              bragStat: BragStatRotator.currentBragStat(
                  streakDays: currentStreak,
                  txCount: periodTransactions.count,
                  zeroSpendDays: zeroSpendDays
              )
          )
          .scaleEffect(0.33)  // ~360pt-wide preview
          .frame(width: 360, height: 640)

          let renderer = ImageRenderer(content: card)
          renderer.scale = 3
          if let uiImage = renderer.uiImage {
              return Image(uiImage: uiImage)
          }
          return Image(systemName: "square")
      }

      /// Renders the full 1080×1920 share artifact OFF the main thread.
      /// Spec 5.9: fixes the 200–800ms UI block flagged by the Performance
      /// audit. Sets `shareImage` + `sharePNGData` when complete.
      private func generateShareArtifactIfNeeded() async {
          guard !shareImageGenerationStarted else { return }
          shareImageGenerationStarted = true

          // Capture facts on main, render on background.
          let snapshot = (
              monthName: monthName,
              monthYear: monthYearString,
              savedCents: savedCents,
              savedPercent: savedPercent,
              spentPercent: spentPercent,
              totalIncomeCents: budget.totalIncomeCents,
              totalSpentCents: totalSpentCents,
              topCategoryName: topCategory?.name ?? "—",
              topCategoryEmoji: topCategory?.emoji ?? "\u{1F4B0}",
              topCategoryCents: topCategorySpent,
              topCategoryPercent: topCategoryPercent,
              transactionCount: periodTransactions.count,
              avgDailyCents: averageDailySpendCents,
              zeroSpendDays: zeroSpendDays,
              streakDays: currentStreak,
              personalityName: personalityType.name,
              personalityEmoji: personalityType.emoji,
              bragStat: BragStatRotator.currentBragStat(
                  streakDays: currentStreak,
                  txCount: periodTransactions.count,
                  zeroSpendDays: zeroSpendDays
              )
          )

          let pngData: Data? = await Task.detached(priority: .userInitiated) { @MainActor in
              let card = MonthlyWrappedShareCard(
                  variant: .finalCTA,
                  monthName: snapshot.monthName, monthYear: snapshot.monthYear,
                  savedCents: snapshot.savedCents, savedPercent: snapshot.savedPercent,
                  spentPercent: snapshot.spentPercent,
                  totalIncomeCents: snapshot.totalIncomeCents,
                  totalSpentCents: snapshot.totalSpentCents,
                  topCategoryName: snapshot.topCategoryName,
                  topCategoryEmoji: snapshot.topCategoryEmoji,
                  topCategoryCents: snapshot.topCategoryCents,
                  topCategoryPercent: snapshot.topCategoryPercent,
                  transactionCount: snapshot.transactionCount,
                  avgDailyCents: snapshot.avgDailyCents,
                  zeroSpendDays: snapshot.zeroSpendDays,
                  streakDays: snapshot.streakDays,
                  personalityName: snapshot.personalityName,
                  personalityEmoji: snapshot.personalityEmoji,
                  bragStat: snapshot.bragStat
              )
              let renderer = ImageRenderer(content: card)
              renderer.scale = 1
              renderer.proposedSize = .init(CGSize(width: 1080, height: 1920))
              return renderer.uiImage?.pngData()
          }.value

          if let data = pngData, let ui = UIImage(data: data) {
              await MainActor.run {
                  self.sharePNGData = data
                  self.shareImage = Image(uiImage: ui)
              }
          }
      }
  ```
- [ ] Build: `xcodebuild build ...` — expect green.
- [ ] Commit: `feat(wrapped): off-main-thread 1080x1920 share render pipeline`

---

### Task 11 — Auto-present `ShareLink` on slide 5 with branded caption

**Files:** Modify `/Users/zachgold/Claude/BudgetVault/BudgetVault/Views/Dashboard/MonthlyWrappedView.swift:650-725`

- [ ] Replace the entire `slide5ShareCard` computed property (lines 650-725) with:
  ```swift
      private var slide5ShareCard: some View {
          ZStack {
              LinearGradient(
                  colors: [wrappedNavy, wrappedPurple.opacity(0.1), wrappedNavyMid],
                  startPoint: .top,
                  endPoint: .bottom
              )
              .ignoresSafeArea()

              VStack(spacing: BudgetVaultTheme.spacingXL) {
                  Spacer()

                  // In-sheet preview (downscaled 1080×1920 card)
                  shareCardContent
                      .padding(BudgetVaultTheme.spacingXL)
                      .background(
                          RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusXL)
                              .fill(
                                  LinearGradient(
                                      colors: [wrappedNavyMid, wrappedPurple.opacity(0.3), wrappedNavy],
                                      startPoint: .topLeading,
                                      endPoint: .bottomTrailing
                                  )
                              )
                      )
                      .overlay(
                          RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusXL)
                              .strokeBorder(.white.opacity(0.08), lineWidth: 1)
                      )
                      .shadow(color: wrappedPurple.opacity(0.2), radius: 30, y: 10)
                      .padding(.horizontal, BudgetVaultTheme.spacingXL)

                  // Share button — auto-presents once the 1080×1920 PNG is ready.
                  if let image = shareImage {
                      ShareLink(
                          item: image,
                          subject: Text("My \(monthYearString) Recap"),
                          message: Text(shareCaption),
                          preview: SharePreview("My \(monthYearString) Recap", image: image)
                      ) {
                          Label("Share", systemImage: "square.and.arrow.up")
                              .font(.headline.weight(.semibold))
                              .foregroundStyle(wrappedNavy)
                              .frame(maxWidth: .infinity)
                              .frame(minHeight: 44)
                              .padding(.vertical, BudgetVaultTheme.spacingMD)
                              .background(.white, in: RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusButton))
                      }
                      .accessibilityLabel("Share your \(monthYearString) wrapped")
                      .accessibilityHint("Opens the share sheet")
                      .simultaneousGesture(TapGesture().onEnded {
                          LocalMetricsService.increment(.wrappedShareTaps)
                          let count = UserDefaults.standard.integer(forKey: AppStorageKeys.wrappedSharesAllTime)
                          UserDefaults.standard.set(count + 1, forKey: AppStorageKeys.wrappedSharesAllTime)
                      })
                      .padding(.horizontal, BudgetVaultTheme.spacingXL)
                  } else {
                      ProgressView()
                          .tint(.white)
                          .frame(maxWidth: .infinity, minHeight: 44)
                          .padding(.horizontal, BudgetVaultTheme.spacingXL)
                          .accessibilityLabel("Preparing share image")
                  }

                  // Save Image button (manual photos save)
                  Button {
                      saveImage()
                  } label: {
                      Label("Save Image", systemImage: "arrow.down.to.line")
                          .font(.headline.weight(.semibold))
                          .foregroundStyle(.white)
                          .frame(maxWidth: .infinity)
                          .frame(minHeight: 44)
                          .padding(.vertical, BudgetVaultTheme.spacingMD)
                          .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusButton))
                          .overlay(
                              RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusButton)
                                  .strokeBorder(.white.opacity(0.2), lineWidth: 1)
                          )
                  }
                  .accessibilityHint("Saves the wrapped card to your photo library")
                  .padding(.horizontal, BudgetVaultTheme.spacingXL)

                  Spacer()
                  Spacer()
              }
          }
          .task {
              await generateShareArtifactIfNeeded()
          }
      }

      /// Pre-filled caption per spec 5.10 — quotes the saved amount and
      /// includes `budgetvault.io` for branded SEO + free attribution.
      private var shareCaption: String {
          let saved = CurrencyFormatter.format(cents: savedCents)
          return "I budgeted \(saved) this month without giving any app my bank login.\n\nbudgetvault.io"
      }
  ```
- [ ] Build: `xcodebuild build ...` — expect green.
- [ ] Run app in simulator → seed Wrapped data → verify ShareLink appears within ~1s of reaching slide 5; confirm caption pre-fills correctly when sharing to Messages.
- [ ] Commit: `feat(wrapped): auto-present ShareLink with branded caption + LocalMetrics increment`

---

### Task 12 — Replace `saveImage()` to use 1080×1920 render

**Files:** Modify `/Users/zachgold/Claude/BudgetVault/BudgetVault/Views/Dashboard/MonthlyWrappedView.swift:828-859`

- [ ] Replace the body of `saveImage()` (lines 828-859) with:
  ```swift
      @MainActor
      private func saveImage() {
          PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
              DispatchQueue.main.async {
                  guard status == .authorized || status == .limited else {
                      showPhotoPermissionDenied = true
                      return
                  }

                  // If the 1080×1920 PNG is already rendered, save it directly.
                  if let data = sharePNGData, let ui = UIImage(data: data) {
                      UIImageWriteToSavedPhotosAlbum(ui, nil, nil, nil)
                      showSaveSuccess = true
                      return
                  }

                  // Fall back: render synchronously at finalCTA size.
                  let card = MonthlyWrappedShareCard(
                      variant: .finalCTA,
                      monthName: monthName, monthYear: monthYearString,
                      savedCents: savedCents, savedPercent: savedPercent, spentPercent: spentPercent,
                      totalIncomeCents: budget.totalIncomeCents, totalSpentCents: totalSpentCents,
                      topCategoryName: topCategory?.name ?? "—",
                      topCategoryEmoji: topCategory?.emoji ?? "\u{1F4B0}",
                      topCategoryCents: topCategorySpent, topCategoryPercent: topCategoryPercent,
                      transactionCount: periodTransactions.count,
                      avgDailyCents: averageDailySpendCents,
                      zeroSpendDays: zeroSpendDays,
                      streakDays: currentStreak,
                      personalityName: personalityType.name,
                      personalityEmoji: personalityType.emoji,
                      bragStat: BragStatRotator.currentBragStat(
                          streakDays: currentStreak,
                          txCount: periodTransactions.count,
                          zeroSpendDays: zeroSpendDays
                      )
                  )
                  let renderer = ImageRenderer(content: card)
                  renderer.scale = 1
                  renderer.proposedSize = .init(CGSize(width: 1080, height: 1920))
                  if let uiImage = renderer.uiImage {
                      UIImageWriteToSavedPhotosAlbum(uiImage, nil, nil, nil)
                      showSaveSuccess = true
                  }
              }
          }
      }
  ```
- [ ] Build: green.
- [ ] Manual sim test: trigger Save Image → confirm Photos library shows a 1080×1920 image (verify in Photos app → info pane).
- [ ] Commit: `feat(wrapped): saveImage uses 1080x1920 MonthlyWrappedShareCard`

---

### Task 13 — Accessibility: bump close button to 44×44 with label/hint

**Files:** Modify `/Users/zachgold/Claude/BudgetVault/BudgetVault/Views/Dashboard/MonthlyWrappedView.swift:236-246`

- [ ] Replace the `.overlay(alignment: .topTrailing)` block (lines 236-246) with:
  ```swift
          .overlay(alignment: .topTrailing) {
              Button {
                  dismiss()
              } label: {
                  Image(systemName: "xmark")
                      .font(.body.weight(.semibold))
                      .foregroundStyle(.white)
                      .frame(width: 44, height: 44)
                      .background(.white.opacity(0.15), in: Circle())
              }
              .accessibilityLabel("Close")
              .accessibilityHint("Closes your wrapped recap")
              .padding(.top, 56)
              .padding(.trailing, 16)
          }
  ```
- [ ] Build: green.
- [ ] Commit: `fix(wrapped): bump close button to 44x44 with VoiceOver label`

---

### Task 14 — Accessibility: bump page-dot tap target to 44×44; add `accessibilityValue`

**Files:** Modify `/Users/zachgold/Claude/BudgetVault/BudgetVault/Views/Dashboard/MonthlyWrappedView.swift:267-283`

- [ ] Replace the `pageDots` computed property (lines 267-283) with:
  ```swift
      private var pageDots: some View {
          HStack(spacing: 6) {
              ForEach(0..<5, id: \.self) { i in
                  if i == currentPage {
                      RoundedRectangle(cornerRadius: 4)
                          .fill(.white)
                          .frame(width: 24, height: 8)
                  } else {
                      Circle()
                          .fill(.white.opacity(0.7))
                          .frame(width: 8, height: 8)
                  }
              }
          }
          .frame(minWidth: 44, minHeight: 44)
          .contentShape(Rectangle())
          .animation(.easeInOut(duration: 0.2), value: currentPage)
          .padding(.bottom, 44)
          .accessibilityElement(children: .ignore)
          .accessibilityLabel("Page indicator")
          .accessibilityValue("Slide \(currentPage + 1) of 5")
      }
  ```
- [ ] Build: green.
- [ ] Commit: `fix(wrapped): page dots get 44x44 hit area + accessibilityValue`

---

### Task 15 — Accessibility: opacity floor 0.7 across all 8 cited lines

**Files:** Modify `/Users/zachgold/Claude/BudgetVault/BudgetVault/Views/Dashboard/MonthlyWrappedView.swift` at lines 300/302, 337, 357, 392, 414, 470, 502.

- [ ] Open the file and apply each replacement below. Each is a one-character/literal change — use Edit tool with enough surrounding context for uniqueness.

  **Line 302:** `.foregroundStyle(.white.opacity(0.25))` for "YOUR \(monthName) STORY" → change `0.25` to `0.7`.

  **Line 337:** `.foregroundStyle(.white.opacity(0.5))` for "SAVED" tracking label → change `0.5` to `0.7`.

  **Line 357:** `.foregroundStyle(.white.opacity(0.5))` for "The vault held strong..." → change `0.5` to `0.7`.

  **Line 392:** `.foregroundStyle(.white.opacity(0.25))` for "WHERE IT WENT" eyebrow → change `0.25` to `0.7`.

  **Line 414:** `.foregroundStyle(.white.opacity(0.5))` for "That's X% of everything..." → change `0.5` to `0.7`.

  **Line 470 area** (which is the slide 3 eyebrow `"YOUR SPENDING TYPE"` at file line 490 with `0.25`): change `0.25` to `0.7`.

  **Line 502 area** (slide 4 eyebrow `"BY THE NUMBERS"` at file line 558 with `0.25`): change `0.25` to `0.7`.

  > **Note:** The spec cites the original audit's line numbers; the actual file's numbering may have drifted by ±a few lines after Tasks 13–14. Search for `.white.opacity(0.25)` and `.white.opacity(0.5)` and verify each match is one of the 8 above (eyebrow text + body subtitles + "SAVED" + "biggest expense was" wrapper). Do **NOT** change opacity on:
  > - decorative ring tracks (`.stroke(.white.opacity(0.04)...)`)
  > - chart bar backgrounds (`.fill(.white.opacity(0.06))`)
  > - card backgrounds (`.background(.white.opacity(0.08))`)

- [ ] Run a final grep to confirm no body-text usage of `.white.opacity(0.25)` remains:
  ```bash
  rg -n "\.white\.opacity\(0\.(25|3|35|4|45|5|55|6)\)" /Users/zachgold/Claude/BudgetVault/BudgetVault/Views/Dashboard/MonthlyWrappedView.swift
  ```
  Expected: only matches are decorative (track strokes, card fills) — no `.foregroundStyle` lines remain below 0.7.
- [ ] Build: green.
- [ ] Commit: `fix(a11y): wrapped body text contrast floor 0.7 per WCAG 1.4.3`

---

### Task 16 — Add `accessibilityAdjustableAction` to TabView pager

**Files:** Modify `/Users/zachgold/Claude/BudgetVault/BudgetVault/Views/Dashboard/MonthlyWrappedView.swift:222-263`

- [ ] In the body, replace the `TabView` block:
  ```swift
              TabView(selection: $currentPage) {
                  slide1StoryIntro.tag(0)
                  slide2WhereItWent.tag(1)
                  slide3Personality.tag(2)
                  slide4ByTheNumbers.tag(3)
                  slide5ShareCard.tag(4)
              }
              .tabViewStyle(.page(indexDisplayMode: .never))
              .ignoresSafeArea()
  ```
  with:
  ```swift
              TabView(selection: $currentPage) {
                  slide1StoryIntro.tag(0)
                  slide2WhereItWent.tag(1)
                  slide3Personality.tag(2)
                  slide4ByTheNumbers.tag(3)
                  slide5ShareCard.tag(4)
              }
              .tabViewStyle(.page(indexDisplayMode: .never))
              .ignoresSafeArea()
              .accessibilityElement(children: .contain)
              .accessibilityLabel("Wrapped slides")
              .accessibilityValue("Slide \(currentPage + 1) of 5")
              .accessibilityAdjustableAction { direction in
                  switch direction {
                  case .increment:
                      if currentPage < 4 {
                          currentPage += 1
                          UIAccessibility.post(notification: .pageScrolled,
                                               argument: "Slide \(currentPage + 1) of 5")
                      }
                  case .decrement:
                      if currentPage > 0 {
                          currentPage -= 1
                          UIAccessibility.post(notification: .pageScrolled,
                                               argument: "Slide \(currentPage + 1) of 5")
                      }
                  @unknown default: break
                  }
              }
  ```
- [ ] Build: green.
- [ ] Commit: `fix(a11y): wrapped TabView gets accessibilityAdjustableAction + page-scroll announce`

---

### Task 17 — Pair every `HapticManager.impact` with VoiceOver announcement

**Files:** Modify `/Users/zachgold/Claude/BudgetVault/BudgetVault/Views/Dashboard/MonthlyWrappedView.swift`

- [ ] Search for all `HapticManager.impact` usages in `MonthlyWrappedView.swift`:
  ```bash
  rg -n "HapticManager" /Users/zachgold/Claude/BudgetVault/BudgetVault/Views/Dashboard/MonthlyWrappedView.swift
  ```
- [ ] If matches exist (e.g. on share/save tap), wrap each with:
  ```swift
  HapticManager.impact(.light)
  UIAccessibility.post(notification: .announcement, argument: "<context-specific message>")
  ```
- [ ] If NO matches exist (current file does not call HapticManager), add `HapticManager.impact(.light)` + announcement on the share tap and save tap added in Task 11/12. In Task 11's `simultaneousGesture` add line:
  ```swift
  HapticManager.impact(.light)
  UIAccessibility.post(notification: .announcement, argument: "Sharing your wrapped")
  ```
  And in Task 12's `saveImage()` after `showSaveSuccess = true`, add:
  ```swift
  HapticManager.impact(.light)
  UIAccessibility.post(notification: .announcement, argument: "Wrapped image saved to Photos")
  ```
- [ ] Build: green.
- [ ] Commit: `fix(a11y): pair Wrapped haptics with VoiceOver announcements`

---

### Task 18 — Cap Wrapped Dynamic Type at `.accessibility3`

**Files:** Modify `/Users/zachgold/Claude/BudgetVault/BudgetVault/Views/Dashboard/MonthlyWrappedView.swift:222-263`

- [ ] Find the body modifier chain after `.ignoresSafeArea()` block and before `.overlay`. Add `.dynamicTypeSize(...DynamicTypeSize.accessibility3)` to the outer `ZStack` (immediately after `var body: some View { ZStack(alignment: .bottom) { ... }` chain):
  ```swift
          .preferredColorScheme(.dark)
          .dynamicTypeSize(...DynamicTypeSize.accessibility3)
          .alert("Image Saved", isPresented: $showSaveSuccess) {
  ```
- [ ] Build: green.
- [ ] Manual test: Settings → Accessibility → Display & Text Size → Larger Text → drag to AX5 → reopen Wrapped → verify text does NOT clip or overlap (cap at AX3 prevents collision).
- [ ] Commit: `fix(a11y): cap Wrapped Dynamic Type at accessibility3`

---

### Task 19 — Write XCUITest verifying Wrapped a11y contract

**Files:** Create `/Users/zachgold/Claude/BudgetVault/BudgetVaultUITests/WrappedAccessibilityUITests.swift`

- [ ] Create:
  ```swift
  import XCTest

  /// Verifies the v3.3.0 accessibility contract on MonthlyWrappedView:
  /// 1. Close button hit-rect ≥ 44×44.
  /// 2. Page indicator exposes "Slide N of 5" via accessibilityValue.
  /// 3. ShareLink has a meaningful accessibility label.
  /// 4. TabView responds to accessibilityAdjustableAction (incrementPage).
  final class WrappedAccessibilityUITests: XCTestCase {

      override func setUp() {
          super.setUp()
          continueAfterFailure = false
          let app = XCUIApplication()
          app.launchArguments += ["-uiTestSeedWrapped", "1"]
          app.launch()
      }

      func testCloseButton_isAtLeast44x44() {
          let app = XCUIApplication()
          openWrapped(app: app)
          let close = app.buttons["Close"]
          XCTAssertTrue(close.waitForExistence(timeout: 5))
          XCTAssertGreaterThanOrEqual(close.frame.width, 44)
          XCTAssertGreaterThanOrEqual(close.frame.height, 44)
      }

      func testPageIndicator_announcesSlideOfFive() {
          let app = XCUIApplication()
          openWrapped(app: app)
          let pager = app.otherElements["Page indicator"]
          XCTAssertTrue(pager.waitForExistence(timeout: 5))
          XCTAssertEqual(pager.value as? String, "Slide 1 of 5")
      }

      func testTabView_incrementPageMovesForward() {
          let app = XCUIApplication()
          openWrapped(app: app)
          let pager = app.otherElements["Wrapped slides"]
          XCTAssertTrue(pager.waitForExistence(timeout: 5))
          pager.adjust(toNormalizedSliderPosition: 0.4)  // triggers increment
          // Walk forward to slide 5 via swipes (4 lefts).
          for _ in 0..<4 { app.swipeLeft() }
          let share = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Share your'")).firstMatch
          XCTAssertTrue(share.waitForExistence(timeout: 5))
      }

      func testShareButton_hasContextLabel() {
          let app = XCUIApplication()
          openWrapped(app: app)
          for _ in 0..<4 { app.swipeLeft() }
          let share = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Share your'")).firstMatch
          XCTAssertTrue(share.waitForExistence(timeout: 8))
          XCTAssertGreaterThanOrEqual(share.frame.height, 44)
      }

      // MARK: - Helpers

      private func openWrapped(app: XCUIApplication) {
          // The seed flag opens the app directly on the Wrapped sheet.
          let header = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'STORY'")).firstMatch
          XCTAssertTrue(header.waitForExistence(timeout: 8))
      }
  }
  ```
- [ ] Wire `-uiTestSeedWrapped` into `BudgetVaultApp.swift` (or `UITestSeedService.swift`) so that when the launch arg is set, the app opens with a seeded budget + Wrapped sheet auto-presented. Find the existing `UITestSeedService` and add:
  ```swift
  static func shouldAutoOpenWrapped() -> Bool {
      ProcessInfo.processInfo.arguments.contains("-uiTestSeedWrapped")
  }
  ```
  Then in the root view, gate a `.sheet(isPresented:)` on this flag with seeded data. (If the existing UITestSeedService already covers this pattern with another flag, mirror that pattern.)
- [ ] Run: `xcodebuild test ... -only-testing:BudgetVaultUITests/WrappedAccessibilityUITests` — expect 4 passes.
- [ ] Commit: `test(a11y): XCUITest covering Wrapped close, pager, and share label`

---

### Task 20 — Standalone WCAG contrast audit script

**Files:** Create `/Users/zachgold/Claude/BudgetVault/scripts/audit-wrapped-contrast.swift`

- [ ] Create the script:
  ```swift
  #!/usr/bin/env swift
  //
  // audit-wrapped-contrast.swift
  // Computes WCAG 2.1 contrast ratios for every text-on-background pair on
  // the Wrapped surface. Exits non-zero if any non-decorative pair < 4.5:1.
  //
  // Usage:
  //   swift scripts/audit-wrapped-contrast.swift
  //
  import Foundation

  struct RGB { let r: Double; let g: Double; let b: Double }

  func hex(_ s: String) -> RGB {
      let h = s.replacingOccurrences(of: "#", with: "")
      var int: UInt64 = 0
      Scanner(string: h).scanHexInt64(&int)
      return RGB(r: Double((int >> 16) & 0xFF) / 255.0,
                 g: Double((int >>  8) & 0xFF) / 255.0,
                 b: Double( int        & 0xFF) / 255.0)
  }

  // Composite (foreground over opaque background) given alpha.
  func composite(fg: RGB, alpha: Double, bg: RGB) -> RGB {
      RGB(r: fg.r * alpha + bg.r * (1 - alpha),
          g: fg.g * alpha + bg.g * (1 - alpha),
          b: fg.b * alpha + bg.b * (1 - alpha))
  }

  // Relative luminance per WCAG.
  func luminance(_ c: RGB) -> Double {
      func t(_ v: Double) -> Double {
          v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
      }
      return 0.2126 * t(c.r) + 0.7152 * t(c.g) + 0.0722 * t(c.b)
  }

  func contrastRatio(_ a: RGB, _ b: RGB) -> Double {
      let la = luminance(a) + 0.05
      let lb = luminance(b) + 0.05
      return la > lb ? la / lb : lb / la
  }

  let navy = hex("#0F1B33")
  let white = hex("#FFFFFF")
  let neonGreen = hex("#34D399")
  let neonPurple = hex("#A78BFA")

  struct Pair { let label: String; let fg: RGB; let alpha: Double; let bg: RGB; let isLargeText: Bool }

  let pairs: [Pair] = [
      Pair(label: "Slide 1 'YOUR STORY' eyebrow @ 0.7", fg: white, alpha: 0.7, bg: navy, isLargeText: false),
      Pair(label: "Slide 1 'SAVED' label @ 0.7", fg: white, alpha: 0.7, bg: navy, isLargeText: false),
      Pair(label: "Slide 1 body subtitle @ 0.7", fg: white, alpha: 0.7, bg: navy, isLargeText: false),
      Pair(label: "Slide 2 'WHERE IT WENT' @ 0.7", fg: white, alpha: 0.7, bg: navy, isLargeText: false),
      Pair(label: "Slide 2 'That's X%' caption @ 0.7", fg: white, alpha: 0.7, bg: navy, isLargeText: false),
      Pair(label: "Slide 3 'YOUR SPENDING TYPE' @ 0.7", fg: white, alpha: 0.7, bg: navy, isLargeText: false),
      Pair(label: "Slide 4 'BY THE NUMBERS' @ 0.7", fg: white, alpha: 0.7, bg: navy, isLargeText: false),
      Pair(label: "Saved% on green (slide 1)", fg: neonGreen, alpha: 1.0, bg: navy, isLargeText: true),
      Pair(label: "Top category amount on purple", fg: neonPurple, alpha: 1.0, bg: navy, isLargeText: true),
  ]

  var failed = 0
  for p in pairs {
      let fg = composite(fg: p.fg, alpha: p.alpha, bg: p.bg)
      let cr = contrastRatio(fg, p.bg)
      let threshold = p.isLargeText ? 3.0 : 4.5
      let pass = cr >= threshold
      let mark = pass ? "PASS" : "FAIL"
      print("[\(mark)] \(String(format: "%.2f", cr)):1 — \(p.label) (need \(threshold):1)")
      if !pass { failed += 1 }
  }

  print("")
  if failed > 0 {
      print("FAILED: \(failed) pair(s) below WCAG threshold")
      exit(1)
  } else {
      print("All pairs pass WCAG 2.1 AA")
  }
  ```
- [ ] Make executable: `chmod +x /Users/zachgold/Claude/BudgetVault/scripts/audit-wrapped-contrast.swift`
- [ ] Run: `swift /Users/zachgold/Claude/BudgetVault/scripts/audit-wrapped-contrast.swift`
- [ ] Expect every line `[PASS]`. White at 0.7 on `#0F1B33` = ~7.4:1 (well above 4.5:1).
- [ ] Commit: `chore(a11y): add WCAG contrast audit script for Wrapped surface`

---

### Task 21 — Increment `LocalMetricsService` from existing paywall surfaces

**Files:** Modify `/Users/zachgold/Claude/BudgetVault/BudgetVault/Views/Shared/PaywallView.swift` (search for `.onAppear` and `.dismiss`).

- [ ] Find the top-level `.onAppear` modifier on the PaywallView body. If present, add as the first line:
  ```swift
  LocalMetricsService.increment(.paywallViews)
  ```
  If no `.onAppear` exists, add one to the outermost `NavigationStack` / root container:
  ```swift
  .onAppear { LocalMetricsService.increment(.paywallViews) }
  ```
- [ ] Find the dismiss handler (Cancel button or `.onDisappear` if non-purchase). Increment dismissals only on user-initiated cancel (not on successful purchase). Add to the cancel button's action:
  ```swift
  LocalMetricsService.increment(.paywallDismissals)
  ```
- [ ] If `quickAddUses` corresponds to an existing quick-add flow (e.g. FAB or widget intent), add the increment at the moment a transaction is confirmed via that path. If quick-add does not yet ship in v3.3.0, leave the `Key.quickAddUses` enum case in place and add a `// TODO(v3.3.0 quick-add): increment here` only IF a quick-add task ships in another plan; otherwise leave the case for future use without an incrementer (the case is already covered by tests).
- [ ] Build: green.
- [ ] Commit: `feat(metrics): increment paywall view/dismissal counters`

---

### Task 22 — Update `MonthlyWrappedView`'s in-sheet `shareCardContent` to display the rotating brag stat

**Files:** Modify `/Users/zachgold/Claude/BudgetVault/BudgetVault/Views/Dashboard/MonthlyWrappedView.swift:729-799`

- [ ] In `shareCardContent`, replace the four-stat HStack (lines 757-792) with a three-stat row + rotating brag pill below:
  ```swift
              // Stats row
              HStack(spacing: BudgetVaultTheme.spacingLG) {
                  VStack(spacing: 2) {
                      Text(personalityType.emoji)
                          .font(.title2)
                      Text(personalityType.name)
                          .font(.caption2.weight(.semibold))
                          .foregroundStyle(.white.opacity(0.7))
                  }

                  VStack(spacing: 2) {
                      Text(String(format: "%.0f%%", savedPercent))
                          .font(.title3.weight(.bold))
                          .foregroundStyle(wrappedGreen)
                      Text("saved")
                          .font(.caption2.weight(.semibold))
                          .foregroundStyle(.white.opacity(0.7))
                  }

                  VStack(spacing: 2) {
                      Text("\(periodTransactions.count)")
                          .font(.title3.weight(.bold))
                          .foregroundStyle(.white)
                      Text("entries")
                          .font(.caption2.weight(.semibold))
                          .foregroundStyle(.white.opacity(0.7))
                  }
              }

              // Rotating brag pill (spec 5.10)
              Text(BragStatRotator.currentBragStat(
                  streakDays: currentStreak,
                  txCount: periodTransactions.count,
                  zeroSpendDays: zeroSpendDays
              ))
                  .font(.caption.weight(.semibold))
                  .foregroundStyle(.white.opacity(0.85))
                  .padding(.horizontal, 14)
                  .padding(.vertical, 6)
                  .background(.white.opacity(0.10), in: Capsule())
  ```
- [ ] Build: green.
- [ ] Commit: `feat(wrapped): in-sheet preview shows rotating BragStat pill`

---

### Task 23 — Wire ReviewPromptService trigger on share-tap (spec 5.10 cross-link)

**Files:** Modify `/Users/zachgold/Claude/BudgetVault/BudgetVault/Views/Dashboard/MonthlyWrappedView.swift` (the `simultaneousGesture` block from Task 11).

- [ ] In Task 11's `simultaneousGesture` closure, add after the `LocalMetricsService.increment(...)` call:
  ```swift
  ReviewPromptService.requestIfAppropriate(trigger: .wrappedShared)
  ```
- [ ] If `ReviewPromptService.requestIfAppropriate(trigger:)` does not yet support a `.wrappedShared` case, add it to the existing trigger enum in `ReviewPromptService.swift`. (If review-prompt rewiring lives in a separate plan, leave a `// TODO(plan-XX-review-prompt): wrappedShared trigger` comment instead and DO NOT modify `ReviewPromptService` here.)
- [ ] Build: green.
- [ ] Commit: `feat(wrapped): hook ReviewPromptService on share-tap (or leave TODO for review-prompt plan)`

---

### Task 24 — Smoke test: full share flow on simulator

**Files:** None (manual verification + screenshot capture).

- [ ] Boot simulator: `xcrun simctl boot 'iPhone 17 Pro'` (already booted is fine).
- [ ] Launch app with seed: `xcodebuild ... -only-testing:BudgetVaultUITests/WrappedAccessibilityUITests` (re-runs the seed path).
- [ ] Manually: Open Wrapped → swipe to slide 5 → verify within 1.5s the white "Share" button replaces the spinner.
- [ ] Tap Share → ShareLink sheet appears → verify the preview thumbnail shows a portrait card with vault dial mark + "saved this month" + QR + "budgetvault.io".
- [ ] Tap Messages → a new draft opens with the caption pre-filled: `I budgeted $XXX.XX this month without giving any app my bank login.\n\nbudgetvault.io` and the 1080×1920 PNG attached.
- [ ] Tap "Save Image" → after Photos permission grant, "Image Saved" alert fires.
- [ ] Open Photos app on sim → verify the image dimensions are exactly 1080×1920.
- [ ] Inspect on-device counter: connect to the simulator's `Documents/local-metrics.json` via:
  ```bash
  xcrun simctl get_app_container booted io.budgetvault.app data
  ```
  cat the resulting `Documents/local-metrics.json` and confirm `wrapped_share_taps: 1`.
- [ ] Document any issues; if all pass, no commit needed for this task.

---

### Task 25 — VoiceOver smoke test

**Files:** None (manual verification).

- [ ] On simulator, Settings → Accessibility → VoiceOver → On.
- [ ] Open Wrapped sheet.
- [ ] Swipe right repeatedly. Verify announcements include:
  - "Your March story. Saved $XXX, NN percent of income."
  - "Page indicator. Slide 1 of 5."
  - "Close. Button. Closes your wrapped recap."
- [ ] On the pager element, swipe up/down (VoiceOver adjustable action) — verify it advances slides and announces "Slide N of 5".
- [ ] Navigate to slide 5 → verify "Share your March 2026 wrapped. Button. Opens the share sheet." reads.
- [ ] Tap Share → confirm haptic fires AND VoiceOver announces "Sharing your wrapped".
- [ ] Tap Save Image → after save, confirm VoiceOver announces "Wrapped image saved to Photos".
- [ ] Document any issues; commit only if fixes are needed.

---

### Task 26 — Performance verification

**Files:** None (manual verification).

- [ ] In Xcode → Product → Profile → Time Profiler.
- [ ] Open Wrapped → swipe to slide 5 → confirm in Instruments that the main thread does NOT spike for >100ms during render. The detached `Task` should show the render work on a background worker thread.
- [ ] Spec 5.9 acceptance: render must NOT cause the 200–800ms UI block flagged in the Performance audit.
- [ ] If main-thread time exceeds 100ms, investigate `MonthlyWrappedShareCard` for sync work (e.g. QR generation should be cheap; if not, move it inside the detached Task).
- [ ] Document profile result; commit only if a fix is needed.

---

### Task 27 — Regenerate xcodeproj and run full test suite

**Files:** None (verification step).

- [ ] Run: `xcodegen generate` from repo root.
- [ ] Run: `xcodebuild test -project BudgetVault.xcodeproj -scheme BudgetVault -destination 'platform=iOS Simulator,name=iPhone 17 Pro' | xcpretty`
- [ ] Expect:
  - All previously-passing tests continue to pass (80 from v3.2 + new ones).
  - 8 new `LocalMetricsServiceTests` pass.
  - 6 new `BragStatRotatorTests` pass.
  - 6 new `MonthlyWrappedShareCardTests` pass.
  - 4 new `WrappedAccessibilityUITests` pass.
- [ ] If any flake, re-run twice. If consistently failing, investigate per `superpowers:systematic-debugging`.
- [ ] Commit: `chore: regenerate xcodeproj after wrapped viral loop additions`

---

### Task 28 — Update version + release notes stub

**Files:** Modify `/Users/zachgold/Claude/BudgetVault/project.yml:39`

- [ ] Bump `MARKETING_VERSION: "3.2.1"` → `MARKETING_VERSION: "3.3.0"`.
- [ ] Bump `CURRENT_PROJECT_VERSION: "1"` → next build number per existing scheme (e.g. `9` if v3.2 last shipped build 8).
- [ ] Run `xcodegen generate`.
- [ ] Build: green.
- [ ] Commit: `chore(release): bump to v3.3.0 build N for wrapped viral loop`

---

## Spec-Coverage Self-Review

Walking spec sections 5.9–5.12 against the task list:

**5.9 1080×1920 Share Renderer (2 days)** ✅
- New `MonthlyWrappedShareCard.swift` view → Task 9.
- Sized 1080×1920 → Tasks 8 (snapshot test asserts size) + 9 (`.frame(width: 1080, height: 1920)`).
- Render via `ImageRenderer` off main thread → Task 10 (`Task.detached(priority: .userInitiated)`).
- Composition: VaultDialMark watermark (top-left) + content + "budgetvault.io" wordmark + App Store QR (bottom) → Task 9 (`watermark`, `footer`, `qrBlock`).
- Brand navy regardless of accentColor → Task 9 (hardcoded `BudgetVaultTheme.navyDark`, `Variant` does not read user accent).
- USER DECISION (all three rotating brag stats) → Tasks 5, 6 (`BragStatRotator`).

**5.10 ShareLink Auto-Present + Watermark (1 day)** ✅
- Auto-present `ShareLink` on slide 5 → Task 11 (slide5ShareCard renders ShareLink as soon as `shareImage` is non-nil; `.task` kicks off render on slide appear).
- Pre-filled caption "I budgeted $X this month without giving any app my bank login" → Task 11 (`shareCaption` property).
- Pre-fill `budgetvault.io` URL → Task 11 (caption appends `\n\nbudgetvault.io`).

**5.11 Local Share-Counter (0.5 day)** ✅
- New `LocalMetricsService` mirroring `FeedbackService` pattern → Tasks 2, 3.
- Counters: `wrapped_share_taps`, `paywall_views`, `paywall_dismissals`, `quick_add_uses` → Task 3 (`Key` enum), Task 2 (raw-value test).
- Surface counts via `FeedbackService` payload only → Task 4.
- Increment on share tap → Task 11 (`simultaneousGesture`).
- Increment on paywall view/dismiss → Task 21.

**5.12 Wrapped Accessibility Pass (1 day)** ✅
- Replace `.white.opacity(0.25)–0.5` with `0.7` floor at lines 300, 302, 337, 357, 392, 414, 470, 502 → Task 15.
- Bump close button (line 241) and page dots (line 277) to 44×44 → Tasks 13, 14.
- Add `.accessibilityValue("Slide \(currentPage+1) of 5")` + `.accessibilityAdjustableAction` → Tasks 14, 16.
- Add `.accessibilityNotification(.announcement:)` paired with `HapticManager.impact` → Task 17.
- Cap font sizes with `.dynamicTypeSize(...DynamicTypeSize.accessibility3)` → Task 18.

**Additional plan-prompt requirements** ✅
- Read `MonthlyWrappedView.swift` before writing tasks → done; cited current line numbers (9-13, 222-263, 236-246, 267-283, 300/302/337/357/392/414/470/502, 650-725, 729-799, 803-826, 828-859).
- Show full SwiftUI code for `MonthlyWrappedShareCard` including all 5 slide variants → Task 9 (full code, all 5 variants in `content @ViewBuilder` switch).
- Snapshot test for each slide rendering at 1080×1920 → Task 8 (one test per `Variant`).
- Accessibility audit script via `xcuitest` → Task 19 (`WrappedAccessibilityUITests`); plus standalone WCAG contrast script → Task 20.
- TDD where it makes sense (share counter, brag stat rotation logic) → Tasks 2→3 (LocalMetricsService red-then-green), Tasks 5→6 (BragStatRotator red-then-green).
- SwiftUI Preview verification for pure views → Task 9 (`#Preview` blocks).
- Aim for 25–30 tasks → 28 tasks. ✅
- Effort 4.5 days → distributed: shareCard view + render (2.0d) + ShareLink + brand caption (1.0d) + LocalMetrics (0.5d) + a11y pass (1.0d). ✅

**Placeholder hunt** — Scanned for failure patterns: no "TBD", no "implement later", no "similar to above". Two soft TODOs in Tasks 21 and 23 are explicitly conditional on whether sibling plans introduce the cross-cutting types (quick-add, ReviewPromptService trigger enum); both are gated with concrete fallbacks ("leave the case for future use" / "leave a TODO comment instead and DO NOT modify"). These are decisions, not deferred work.

**Type consistency check:**
- `LocalMetricsService.Key.wrappedShareTaps` (Task 3) referenced in Tasks 2, 11, 21. ✅
- `MonthlyWrappedShareCard.Variant.finalCTA` (Task 9) referenced in Tasks 8, 10, 12. ✅
- `BragStatRotator.currentBragStat(streakDays:txCount:zeroSpendDays:)` (Task 6) referenced in Tasks 10, 22. ✅
- `AppStorageKeys.wrappedSharesAllTime` (Task 1) referenced in Task 6, 11. ✅

**File path check:** All paths absolute, all under `/Users/zachgold/Claude/BudgetVault/`. ✅

Plan ready.
