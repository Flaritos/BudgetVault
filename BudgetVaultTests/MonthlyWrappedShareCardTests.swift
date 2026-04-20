import XCTest
import SwiftUI
import BudgetVaultShared
@testable import BudgetVault

/// Verifies the share card renders at the spec-required 1080×1920
/// dimensions with no transparent gaps. The 5 variants must each fill
/// the full canvas in brand navy regardless of user accentColor.
@MainActor
final class MonthlyWrappedShareCardTests: XCTestCase {

    private let target = CGSize(width: 1080, height: 1920)

    private func render(_ variant: MonthlyWrappedShareCard.Variant) -> UIImage? {
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
        // Adaptation: ImageRenderer on iOS 17+ returns an IOSurface-backed
        // CGImage whose dataProvider.data is nil (GPU-resident). We redraw
        // into a CPU bitmap context so we can read the top-left pixel.
        for variant in MonthlyWrappedShareCard.Variant.allCases {
            guard let img = render(variant), let cg = img.cgImage else {
                XCTFail("Render failed for \(variant)"); continue
            }
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            var pixel: [UInt8] = [0, 0, 0, 0]
            guard let ctx = CGContext(
                data: &pixel,
                width: 1, height: 1,
                bitsPerComponent: 8,
                bytesPerRow: 4,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else {
                XCTFail("Failed to create bitmap context for \(variant)"); continue
            }
            ctx.draw(cg, in: CGRect(x: 0, y: -Int(cg.height - 1), width: cg.width, height: cg.height))
            let alpha = pixel[3]
            XCTAssertEqual(alpha, 255, "Variant \(variant) has transparent top-left pixel")
        }
    }
}
