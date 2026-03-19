import Foundation

/// Learns note-to-category mappings from user behavior and suggests categories
/// for new transactions based on historical patterns.
@Observable
final class CategoryLearningService {

    /// Persisted mapping of lowercase note -> [categoryName: count]
    private var mappings: [String: [String: Int]] = [:]

    private static let storageKey = "categoryLearningMappings"

    init() {
        loadMappings()
    }

    // MARK: - Public API

    /// Record that a note was assigned to a category. Call after saving a transaction.
    func recordMapping(note: String, categoryName: String) {
        guard !note.isEmpty, !categoryName.isEmpty else { return }
        let key = note.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }

        var counts = mappings[key] ?? [:]
        counts[categoryName, default: 0] += 1
        mappings[key] = counts
        saveMappings()
    }

    /// Suggest a category for a given note based on historical patterns.
    /// Returns nil if no strong match exists (confidence must exceed 0.8).
    func suggestCategory(for note: String) -> (categoryName: String, confidence: Double)? {
        let key = note.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty, let counts = mappings[key] else { return nil }

        let total = counts.values.reduce(0, +)
        guard total >= 2 else { return nil } // Need at least 2 data points

        guard let best = counts.max(by: { $0.value < $1.value }) else { return nil }
        let confidence = Double(best.value) / Double(total)

        guard confidence > 0.8 else { return nil }
        return (categoryName: best.key, confidence: confidence)
    }

    // MARK: - Persistence

    private func loadMappings() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey),
              let decoded = try? JSONDecoder().decode([String: [String: Int]].self, from: data) else {
            return
        }
        mappings = decoded
    }

    private func saveMappings() {
        if let data = try? JSONEncoder().encode(mappings) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    /// Clear all learned mappings. Used by "Delete All Data".
    func clearAll() {
        mappings = [:]
        UserDefaults.standard.removeObject(forKey: Self.storageKey)
    }
}
