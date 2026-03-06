import Foundation
import CoreData

@Observable
final class CloudSyncService {

    var lastSyncDate: Date?
    var isSyncing = false
    var syncError: String?

    init() {
        NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleSyncEvent(notification)
        }

        // M13: SwiftData's CloudKit integration fires this notification reliably
        NotificationCenter.default.addObserver(
            forName: .NSPersistentStoreRemoteChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleRemoteChange()
        }
    }

    private func handleRemoteChange() {
        // Mark sync as completed when we receive remote changes
        lastSyncDate = Date()
        isSyncing = false
        syncError = nil
    }

    private func handleSyncEvent(_ notification: Notification) {
        guard let event = notification.userInfo?["event"] as? NSPersistentCloudKitContainer.Event else { return }

        switch event.type {
        case .setup:
            isSyncing = true
            syncError = nil
        case .import, .export:
            if event.endDate != nil {
                isSyncing = false
                if event.succeeded {
                    lastSyncDate = event.endDate
                    syncError = nil
                } else if let error = event.error {
                    syncError = error.localizedDescription
                }
            } else {
                isSyncing = true
            }
        @unknown default:
            break
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
