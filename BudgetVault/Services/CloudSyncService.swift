import Foundation
import CoreData

@Observable
final class CloudSyncService {

    var lastSyncDate: Date?
    var isSyncing = false
    var syncError: String?

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
