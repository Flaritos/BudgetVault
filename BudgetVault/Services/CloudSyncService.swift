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
    private var iCloudAccountObserver: Any?

    init() {
        // SwiftData's CloudKit integration fires this notification on remote changes
        remoteChangeObserver = NotificationCenter.default.addObserver(
            forName: .NSPersistentStoreRemoteChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleRemoteChange()
        }

        // Audit 2026-04-22 P0-14: re-check iCloud account status when the
        // user signs in/out of iCloud while the app is running.
        iCloudAccountObserver = NotificationCenter.default.addObserver(
            forName: .NSUbiquityIdentityDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshAvailability()
        }
    }

    deinit {
        if let observer = remoteChangeObserver { NotificationCenter.default.removeObserver(observer) }
        if let observer = iCloudAccountObserver { NotificationCenter.default.removeObserver(observer) }
    }

    /// Audit 2026-04-22 P0-14: surface the "iCloud toggled on but no
    /// iCloud account signed in" case. Previously the Settings UI showed
    /// a cheerful "Last Sync: Never" with no explanation — sync was
    /// silently impossible. Call this on toggle-on and when the account
    /// identity changes.
    func refreshAvailability() {
        if FileManager.default.ubiquityIdentityToken == nil {
            syncError = "Sign in to iCloud in iOS Settings to enable sync."
        } else if syncError == "Sign in to iCloud in iOS Settings to enable sync." {
            // Only clear our own message — preserve any CloudKit error
            // surfaced elsewhere in the app.
            syncError = nil
        }
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

    /// Removes duplicate budgets for the same month/year, merging
    /// categories into the oldest one.
    ///
    /// Audit fix: the prior version reassigned `cat.budget = existing`
    /// for non-duplicate-named categories, but `context.delete(budget)`
    /// still cascade-deleted the *duplicate-named* categories — and
    /// their transactions with them. Users importing the same CSV
    /// twice via iCloud sync could silently lose transactions. Now we
    /// reassign ALL transactions from the doomed budget's categories
    /// to their name-matching categories on the keeper (or absorb the
    /// category wholesale if no name match) before the delete.
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
                let existingByName = Dictionary(
                    (existing.categories ?? []).map { ($0.name.lowercased(), $0) },
                    uniquingKeysWith: { old, _ in old }
                )
                for cat in budget.categories ?? [] {
                    if let keeper = existingByName[cat.name.lowercased()] {
                        // Name match: move every transaction from the
                        // doomed category to the keeper, then let
                        // cascade-delete take the empty category.
                        for tx in cat.transactions ?? [] {
                            tx.category = keeper
                        }
                    } else {
                        // No name match: absorb the whole category
                        // (including its transactions via the inverse)
                        // onto the keeper budget.
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
            if !SafeSave.save(context) { context.rollback() }
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
