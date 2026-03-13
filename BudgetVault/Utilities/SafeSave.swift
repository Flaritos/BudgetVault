import SwiftData
import os

enum SafeSave {
    private static let logger = Logger(subsystem: "io.budgetvault.app", category: "persistence")

    static func save(_ context: ModelContext) {
        do {
            try context.save()
        } catch {
            logger.error("SwiftData save failed: \(error.localizedDescription)")
        }
    }
}
