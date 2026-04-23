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
        let key = Self.normalizeKey(note)
        guard !key.isEmpty else { return }

        var counts = mappings[key] ?? [:]
        counts[categoryName, default: 0] += 1
        mappings[key] = counts
        saveMappings()
    }

    /// Suggest a category for a given note based on historical patterns.
    /// Returns nil if no strong match exists (confidence must exceed 0.8).
    func suggestCategory(for note: String) -> (categoryName: String, confidence: Double)? {
        let key = Self.normalizeKey(note)
        guard !key.isEmpty, let counts = mappings[key] else { return nil }

        let total = counts.values.reduce(0, +)
        guard total >= 2 else { return nil } // Need at least 2 data points

        guard let best = counts.max(by: { $0.value < $1.value }) else { return nil }
        let confidence = Double(best.value) / Double(total)

        guard confidence > 0.8 else { return nil }
        return (categoryName: best.key, confidence: confidence)
    }

    /// Audit 2026-04-23 AI P1: undo a wrong suggestion. Call when
    /// the user corrects an auto-selected category in the entry form.
    /// Decrements the wrong mapping and increments the correct one
    /// so the next recompute tips toward the user's correction.
    func correctMapping(note: String, wrongCategory: String, correctCategory: String) {
        guard !note.isEmpty, !wrongCategory.isEmpty, !correctCategory.isEmpty,
              wrongCategory != correctCategory else { return }
        let key = Self.normalizeKey(note)
        guard !key.isEmpty else { return }

        var counts = mappings[key] ?? [:]
        if let current = counts[wrongCategory], current > 0 {
            counts[wrongCategory] = current - 1
            if counts[wrongCategory] == 0 { counts.removeValue(forKey: wrongCategory) }
        }
        counts[correctCategory, default: 0] += 1
        mappings[key] = counts
        saveMappings()
    }

    /// Audit 2026-04-23 AI P1: normalize note text before hashing.
    /// Prior implementation used raw `.lowercased().trimming(...)`,
    /// which meant "Starbucks #1234" and "starbucks #5678" produced
    /// distinct keys — mapping table exploded with merchant-id
    /// variants, confidence never climbed. Now also:
    ///   - pinned en_US_POSIX for Turkish-I safety
    ///   - strips trailing receipt/merchant digit IDs
    ///   - collapses whitespace runs
    ///   - drops common punctuation
    private static func normalizeKey(_ note: String) -> String {
        let lowered = note.lowercased(with: Locale(identifier: "en_US_POSIX"))
        let trimmed = lowered.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        // Remove trailing digit runs like "#1234" or " 5678" — those
        // are typically merchant/receipt IDs that defeat matching.
        var stripped = trimmed
        while let last = stripped.unicodeScalars.last,
              CharacterSet.decimalDigits.contains(last) || last == "#" || last == " " {
            stripped.removeLast()
        }

        // Collapse whitespace runs + drop basic punctuation.
        let dropSet = CharacterSet(charactersIn: ",.;:!?()[]{}\"'`")
        let cleaned = stripped.unicodeScalars
            .filter { !dropSet.contains($0) }
            .reduce(into: "") { $0.append(Character($1)) }
        return cleaned.split(separator: " ").joined(separator: " ")
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
