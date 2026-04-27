import Foundation

/// Privacy-clean local feedback log. No analytics, no network. Writes to a
/// JSON file in the app's Documents directory and offers an email-export
/// path so the user can choose to share it manually.
///
/// Introduced in v3.1.1 to fix the "zero first-party feedback" blind spot
/// flagged in the v3.2 audit — every prior "user need" was proxy research.
enum FeedbackService {

    struct Entry: Codable, Identifiable {
        var id: UUID = UUID()
        let createdAt: Date
        let category: Category
        let message: String
        let appVersion: String
        let osVersion: String
        let deviceModel: String
    }

    enum Category: String, Codable, CaseIterable, Identifiable {
        case bug = "Bug"
        case featureRequest = "Feature Request"
        case loveIt = "Love It"
        case other = "Other"

        var id: String { rawValue }

        var symbol: String {
            switch self {
            case .bug: return "ladybug.fill"
            case .featureRequest: return "lightbulb.fill"
            case .loveIt: return "heart.fill"
            case .other: return "ellipsis.bubble.fill"
            }
        }
    }

    private static var fileURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("feedback-log.json")
    }

    static func append(category: Category, message: String) {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let entry = Entry(
            createdAt: Date(),
            category: category,
            message: trimmed,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?",
            osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            deviceModel: deviceModelIdentifier()
        )

        var entries = loadAll()
        entries.append(entry)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(entries) {
            // Audit 2026-04-23 Max Audit P1-19: stamp .complete file
            // protection on Documents/ writes. iOS default is
            // completeUntilFirstUserAuthentication — user-typed bug-
            // report text may contain PII and would otherwise be
            // readable while the device is locked post-first-unlock.
            try? data.write(to: fileURL, options: [.atomic, .completeFileProtection])
            // Audit 2026-04-27 L-6: exclude the feedback log from iCloud
            // Backup. Documents/ is included by default; the user-typed
            // bug-report text is the most free-form on-disk content the
            // app produces and may contain PII the user wouldn't want
            // crossing to Apple's backup servers. Setting the resource
            // value is idempotent — safe to set on every write.
            var url = fileURL
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try? url.setResourceValues(values)
        }
    }

    static func loadAll() -> [Entry] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([Entry].self, from: data)) ?? []
    }

    static func count() -> Int { loadAll().count }

    static func clearAll() {
        try? FileManager.default.removeItem(at: fileURL)
    }

    /// Builds a mailto: URL the user can tap to send their entire feedback
    /// log to support. The user explicitly chooses to send — nothing leaves
    /// the device automatically.
    static func mailtoURL(to recipient: String = "feedback@budgetvault.io") -> URL? {
        let entries = loadAll()
        let header = "BudgetVault Feedback Export\n" +
                     "Generated: \(ISO8601DateFormatter().string(from: Date()))\n" +
                     "Entries: \(entries.count)\n\n" +
                     "--- On-device counters (no network) ---\n" +
                     LocalMetricsService.payloadString() + "\n\n"

        let body = header + entries.map { entry in
            "[\(ISO8601DateFormatter().string(from: entry.createdAt))] \(entry.category.rawValue)\n" +
            "App: \(entry.appVersion) | OS: \(entry.osVersion) | Device: \(entry.deviceModel)\n" +
            "\(entry.message)\n"
        }.joined(separator: "\n---\n\n")

        var components = URLComponents()
        components.scheme = "mailto"
        components.path = recipient
        components.queryItems = [
            URLQueryItem(name: "subject", value: "BudgetVault Feedback"),
            URLQueryItem(name: "body", value: body)
        ]
        return components.url
    }

    private static func deviceModelIdentifier() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let mirror = Mirror(reflecting: systemInfo.machine)
        return mirror.children.compactMap { element in
            guard let value = element.value as? Int8, value != 0 else { return nil }
            return String(UnicodeScalar(UInt8(value)))
        }.joined()
    }
}
