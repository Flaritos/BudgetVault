import Foundation
import CoreData
import SwiftData

@Observable
final class CloudSyncService {

    var lastSyncDate: Date?
    var isSyncing = false
    var syncError: String?

    /// Set this to the app's ModelContainer so dedup can run on remote changes
    var modelContainer: ModelContainer?

    private var remoteChangeObserver: Any?

    init() {
        // SwiftData's CloudKit integration fires this notification on remote changes
        remoteChangeObserver = NotificationCenter.default.addObserver(
            forName: .NSPersistentStoreRemoteChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleRemoteChange()
        }
    }

    deinit {
        if let observer = remoteChangeObserver { NotificationCenter.default.removeObserver(observer) }
    }

    private func handleRemoteChange() {
        lastSyncDate = Date()
        isSyncing = false
        syncError = nil

        // Run budget dedup after remote sync (0.4)
        if let container = modelContainer {
            Task { @MainActor in
                deduplicateBudgets(context: container.mainContext)
            }
        }
    }

    /// Removes duplicate budgets for the same month/year, merging categories into the oldest one.
    private func deduplicateBudgets(context: ModelContext) {
        let descriptor = FetchDescriptor<Budget>(
            sortBy: [SortDescriptor(\Budget.year), SortDescriptor(\Budget.month)]
        )
        guard let allBudgets = try? context.fetch(descriptor) else { return }

        var seen: [String: Budget] = [:]
        var didMerge = false
        for budget in allBudgets {
            let key = "\(budget.year)-\(budget.month)"
            if let existing = seen[key] {
                for cat in budget.categories ?? [] {
                    let existingNames = Set((existing.categories ?? []).map { $0.name.lowercased() })
                    if !existingNames.contains(cat.name.lowercased()) {
                        cat.budget = existing
                    }
                }
                context.delete(budget)
                didMerge = true
            } else {
                seen[key] = budget
            }
        }
        if didMerge {
            SafeSave.save(context)
        }
    }

    private static let relativeDateFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    var lastSyncText: String {
        guard let date = lastSyncDate else { return "Never" }
        return Self.relativeDateFormatter.localizedString(for: date, relativeTo: Date())
    }
}
