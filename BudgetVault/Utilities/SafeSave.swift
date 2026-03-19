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
            logger.error("SwiftData save failed: \(error.localizedDescription)")
            return false
        }
    }
}
