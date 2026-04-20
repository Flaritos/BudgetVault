import Foundation

/// Privacy-clean local counter store. NEVER sends data over the network.
/// Mirrors FeedbackService's on-device-only pattern. Counters surface only
/// when the user explicitly exports their FeedbackService payload.
///
/// Introduced in v3.3.0 (spec section 5.11) to give us funnel visibility
/// (`wrapped_share_taps`, `paywall_views`, `paywall_dismissals`,
/// `quick_add_uses`) without violating "Data Not Collected."
enum LocalMetricsService {

    enum Key: String, CaseIterable {
        case wrappedShareTaps = "wrapped_share_taps"
        case paywallViews = "paywall_views"
        case paywallDismissals = "paywall_dismissals"
        case quickAddUses = "quick_add_uses"
    }

    private static var fileURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("local-metrics.json")
    }

    static func value(for key: Key) -> Int {
        loadAll()[key.rawValue] ?? 0
    }

    static func increment(_ key: Key) {
        var all = loadAll()
        all[key.rawValue, default: 0] += 1
        write(all)
    }

    static func clearAll() {
        try? FileManager.default.removeItem(at: fileURL)
    }

    /// Renders all counters as a multi-line string suitable for inclusion
    /// in a FeedbackService support payload. Stable line ordering by key.
    static func payloadString() -> String {
        let all = loadAll()
        return Key.allCases
            .map { "\($0.rawValue): \(all[$0.rawValue] ?? 0)" }
            .joined(separator: "\n")
    }

    /// Test-only synchronization helper. Production calls already write
    /// atomically; this exists so tests can assert post-write reads.
    static func flushForTesting() { _ = loadAll() }

    // MARK: - Private

    private static func loadAll() -> [String: Int] {
        guard let data = try? Data(contentsOf: fileURL) else { return [:] }
        return (try? JSONDecoder().decode([String: Int].self, from: data)) ?? [:]
    }

    private static func write(_ dict: [String: Int]) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(dict) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}
