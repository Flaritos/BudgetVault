import SwiftData
import os

enum SafeSave {
    private static let logger = Logger(subsystem: "io.budgetvault.app", category: "persistence")

    @discardableResult
    static func save(_ context: ModelContext) -> Bool {
        do {
            try context.save()
            return true
        } catch {
            // Audit 2026-04-27 L-3: explicit `privacy: .private` on the
            // user-data-bearing string. Swift's os.Logger defaults
            // strings to .private in release, but pinning it removes
            // any concern about future default changes.
            logger.error("SwiftData save failed: \(error.localizedDescription, privacy: .private)")
            return false
        }
    }
}
