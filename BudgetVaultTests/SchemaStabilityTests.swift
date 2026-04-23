import XCTest
import SwiftData
@testable import BudgetVault

/// Audit 2026-04-22 P2-17: schema-stability guard.
///
/// `BudgetVaultSchemaV1` is the only shipped schema — `MigrationStage`
/// is empty. If a future change silently adds/removes a `@Model`
/// property, SwiftData will either force a migration at next launch
/// (surprise work for the user) or — worse — silently drop fields.
///
/// This test locks down the entity roster + property count for V1 so
/// any change requires either:
///   (a) updating this test AND bumping to V2 + writing a migration, or
///   (b) acknowledging the V1 edit and updating the baseline here.
///
/// Either way, it forces a human decision before the change ships.
final class SchemaStabilityTests: XCTestCase {

    func testSchemaV1ModelRosterUnchanged() {
        let actualModelNames = BudgetVaultSchemaV1.models.map { String(describing: $0) }.sorted()
        let expectedModelNames = [
            "Budget",
            "Category",
            "DebtAccount",
            "DebtPayment",
            "NetWorthAccount",
            "NetWorthSnapshot",
            "RecurringExpense",
            "Transaction",
        ]
        XCTAssertEqual(actualModelNames, expectedModelNames,
                       """
                       BudgetVaultSchemaV1 model roster changed. If this is \
                       intentional, bump to BudgetVaultSchemaV2, add a \
                       MigrationStage, and update the baseline in this test. \
                       DO NOT silently edit V1 — existing installs will see \
                       an unplanned migration or field drop.
                       """)
    }

    func testSchemaV1VersionIdentifierUnchanged() {
        // V1 is 1.0.0. Any non-additive change should graduate to V2.
        let v = BudgetVaultSchemaV1.versionIdentifier
        XCTAssertEqual(v, Schema.Version(1, 0, 0),
                       "BudgetVaultSchemaV1.versionIdentifier moved. Bump to V2 + write migration.")
    }

    func testMigrationPlanSchemasIncludesV1() {
        let schemas = BudgetVaultMigrationPlan.schemas.map { String(describing: $0) }
        XCTAssertTrue(schemas.contains("BudgetVaultSchemaV1"),
                      "BudgetVaultMigrationPlan.schemas must include V1 for the life of the app.")
    }
}
