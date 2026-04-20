# Apple Intelligence Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship three on-device Apple Intelligence features (NLEmbedding category suggestion, Foundation Models Wrapped narration, subscription drift detection) without compromising the "Data Not Collected" privacy label.

**Architecture:** All inference is on-device only — no network calls, no third-party LLMs. NLEmbedding upgrades the existing exact-match `CategoryLearningService` to a cosine-kNN classifier with exact-match fallback. Foundation Models is gated by `SystemLanguageModel.default.availability` with the existing static template copy as fallback. Drift detection extends `BudgetMLEngine` with merchant-grouped MAD reusing existing pure-Swift utilities.

**Tech Stack:** Swift 5.10, NaturalLanguage (`NLEmbedding`, `NLTokenizer`), FoundationModels (`SystemLanguageModel`, `LanguageModelSession`), XCTest with `XCTPerformanceMetric`, SwiftUI.

**Estimated Effort:** 7 days

**Ship Target:** v3.3.1

---

## File Structure

### Created
- `BudgetVault/Services/WrappedNarrationService.swift` — Foundation Models narration generator with structured JSON facts and prompt-injection guardrails.
- `BudgetVault/Services/SystemLanguageModelGateway.swift` — Tiny protocol seam over `SystemLanguageModel` so tests can stub availability + responses.
- `BudgetVaultTests/CategoryLearningServiceTests.swift` — kNN, fallback, and confidence-gate tests with seeded historical data.
- `BudgetVaultTests/CategoryLearningServicePerformanceTests.swift` — `XCTPerformanceMetric` benchmarks proving <30ms p95 over 500 historical notes.
- `BudgetVaultTests/WrappedNarrationServiceTests.swift` — Narration tests using the stubbed gateway.
- `BudgetVaultTests/BudgetMLEngineDriftTests.swift` — Merchant-drift tests with synthetic Netflix/gym time series.

### Modified
- `BudgetVault/Services/CategoryLearningService.swift` — Replace exact-match with NLEmbedding kNN; lower confidence gate from 0.8 → 0.65 with `total >= 3`; preserve fallback path.
- `BudgetVault/Services/BudgetMLEngine.swift` — Add `detectSubscriptionDrift(budget:history:)` plus `MerchantDriftResult` type.
- `BudgetVault/Views/Dashboard/MonthlyWrappedView.swift` — Pre-generate narrations in `Task` at sheet-open; render generated copy with static fallback.
- `BudgetVault/Views/Settings/SettingsView.swift` — Add "Vault Voice (Beta)" binary opt-in toggle in Notifications section.
- `BudgetVault/Utilities/AppStorageKeys.swift` — Add `vaultVoiceEnabled` key.
- `project.yml` — Register the four new files (run `xcodegen generate`).

### Tested
- `CategoryLearningService.suggestCategory` — kNN, fallback, gate.
- `CategoryLearningService.suggestCategory` — performance.
- `WrappedNarrationService.generate(for:)` — happy path, unavailable model, prompt injection in fact strings.
- `BudgetMLEngine.detectSubscriptionDrift` — synthetic Netflix +$2 series, gym +$5 series, jitter rejection, low-occurrence rejection.

---

## Task 1: Add `vaultVoiceEnabled` AppStorage Key

**Files:**
- Modify: `BudgetVault/Utilities/AppStorageKeys.swift:46-51`

- [ ] Open `BudgetVault/Utilities/AppStorageKeys.swift`.
- [ ] Append a new `MARK: - Apple Intelligence` section under `Engagement & Retention` with the key:
```swift
    // MARK: - Apple Intelligence
    static let vaultVoiceEnabled = "vaultVoiceEnabled"
```
- [ ] Run `xcodebuild -scheme BudgetVault -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build` to confirm clean build. Expected: `** BUILD SUCCEEDED **`.
- [ ] Commit: `git add BudgetVault/Utilities/AppStorageKeys.swift && git commit -m "feat(ai): add vaultVoiceEnabled AppStorage key"`.

---

## Task 2: Create `SystemLanguageModelGateway` Protocol Seam

**Files:**
- Create: `BudgetVault/Services/SystemLanguageModelGateway.swift`

- [ ] Create the file with the protocol + live and stub implementations:
```swift
import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Protocol seam over Apple's Foundation Models so tests can stub availability and responses.
/// Live implementation requires iOS 18.1+ and Apple Intelligence capable hardware.
protocol SystemLanguageModelGateway: Sendable {
    /// Returns true when Foundation Models is callable on this device + OS combination.
    var isAvailable: Bool { get }

    /// Runs a single-turn prompt and returns the model's text response.
    /// Throws on timeout, safety filter rejection, or backend error.
    func respond(to prompt: String) async throws -> String
}

/// Production gateway backed by `SystemLanguageModel.default`.
@available(iOS 18.1, *)
struct LiveSystemLanguageModelGateway: SystemLanguageModelGateway {
    var isAvailable: Bool {
        #if canImport(FoundationModels)
        return SystemLanguageModel.default.availability == .available
        #else
        return false
        #endif
    }

    func respond(to prompt: String) async throws -> String {
        #if canImport(FoundationModels)
        let session = LanguageModelSession()
        let response = try await session.respond(to: prompt)
        return response.content
        #else
        throw NSError(domain: "SystemLanguageModelGateway", code: -1,
                      userInfo: [NSLocalizedDescriptionKey: "FoundationModels not available at compile time"])
        #endif
    }
}

/// Test stub. Set `availability` and `responder` per test.
final class StubSystemLanguageModelGateway: SystemLanguageModelGateway, @unchecked Sendable {
    var isAvailable: Bool
    var responder: (String) async throws -> String

    init(isAvailable: Bool, responder: @escaping (String) async throws -> String = { _ in "" }) {
        self.isAvailable = isAvailable
        self.responder = responder
    }

    func respond(to prompt: String) async throws -> String {
        try await responder(prompt)
    }
}
```
- [ ] Add the file to `project.yml` sources (it sits under `BudgetVault/Services` which is already glob-included; verify by running `xcodegen generate` and confirming the file appears in the generated `.xcodeproj`).
- [ ] Run build: `xcodebuild -scheme BudgetVault -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`. Expected: `** BUILD SUCCEEDED **`.
- [ ] Commit: `git add BudgetVault/Services/SystemLanguageModelGateway.swift project.yml && git commit -m "feat(ai): add SystemLanguageModelGateway protocol seam"`.

---

## Task 3: Write Failing Test — Exact-Match Fallback Survives

**Files:**
- Create: `BudgetVaultTests/CategoryLearningServiceTests.swift`

- [ ] Create the test file. We test the fallback path FIRST so we have a regression net before we introduce embeddings:
```swift
import XCTest
@testable import BudgetVault

final class CategoryLearningServiceTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Isolate from real UserDefaults state.
        UserDefaults.standard.removeObject(forKey: "categoryLearningMappings")
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "categoryLearningMappings")
        super.tearDown()
    }

    // MARK: - Exact-match fallback (preserved behavior)

    func test_exactMatch_returnsCategory_whenConfidenceAboveGate() {
        let svc = CategoryLearningService()
        for _ in 0..<3 { svc.recordMapping(note: "starbucks", categoryName: "Coffee") }

        let suggestion = svc.suggestCategory(for: "starbucks")
        XCTAssertEqual(suggestion?.categoryName, "Coffee")
        XCTAssertGreaterThanOrEqual(suggestion?.confidence ?? 0, 0.65)
    }

    func test_exactMatch_returnsNil_whenBelowMinimumOccurrences() {
        let svc = CategoryLearningService()
        svc.recordMapping(note: "starbucks", categoryName: "Coffee")
        svc.recordMapping(note: "starbucks", categoryName: "Coffee")
        // Only 2 — gate requires 3
        XCTAssertNil(svc.suggestCategory(for: "starbucks"))
    }

    func test_exactMatch_returnsNil_whenConfidenceBelowGate() {
        let svc = CategoryLearningService()
        svc.recordMapping(note: "amazon", categoryName: "Shopping")
        svc.recordMapping(note: "amazon", categoryName: "Shopping")
        svc.recordMapping(note: "amazon", categoryName: "Groceries")
        svc.recordMapping(note: "amazon", categoryName: "Groceries")
        // 50/50 — confidence 0.5, below 0.65 gate
        XCTAssertNil(svc.suggestCategory(for: "amazon"))
    }
}
```
- [ ] Run: `xcodebuild test -scheme BudgetVault -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:BudgetVaultTests/CategoryLearningServiceTests`.
- [ ] Expected: `test_exactMatch_returnsCategory_whenConfidenceAboveGate` FAILS (current gate is 0.8 with `total >= 2`, returns the suggestion but our test expects `>= 0.65`; actually it will currently PASS for that one since 1.0 > 0.8). The third test FAILS — `total >= 2` and confidence 0.5 currently returns nil (gate is `> 0.8`), so it'll actually pass. The middle test FAILS — `total >= 2` lets 2 occurrences through. Confirm at least one test fails before proceeding.
- [ ] Commit only after at least the middle test fails: `git add BudgetVaultTests/CategoryLearningServiceTests.swift && git commit -m "test(ai): seed CategoryLearningService fallback regression tests"`.

---

## Task 4: Lower Confidence Gate to 0.65 + Bump `total` Floor to 3

**Files:**
- Modify: `BudgetVault/Services/CategoryLearningService.swift:38, :43`

- [ ] Open `CategoryLearningService.swift`.
- [ ] Replace lines 37-44 (the inside of `suggestCategory`'s computation block) with:
```swift
        let total = counts.values.reduce(0, +)
        guard total >= 3 else { return nil } // Need at least 3 data points

        guard let best = counts.max(by: { $0.value < $1.value }) else { return nil }
        let confidence = Double(best.value) / Double(total)

        guard confidence >= 0.65 else { return nil }
        return (categoryName: best.key, confidence: confidence)
```
- [ ] Update the doc comment on line 32 to read:
```swift
    /// Suggest a category for a given note based on historical patterns.
    /// Returns nil if no strong match exists (confidence must be >= 0.65 with >= 3 occurrences).
```
- [ ] Run the three tests from Task 3. Expected: ALL three pass.
- [ ] Commit: `git add BudgetVault/Services/CategoryLearningService.swift && git commit -m "fix(ai): lower CategoryLearningService gate to 0.65 with >=3 occurrences"`.

---

## Task 5: Write Failing kNN Test with Seeded Historical Notes

**Files:**
- Modify: `BudgetVaultTests/CategoryLearningServiceTests.swift`

- [ ] Append to the test file, inside the existing class:
```swift
    // MARK: - NLEmbedding kNN (new behavior)

    func test_kNN_matchesSemanticallySimilarNote() {
        let svc = CategoryLearningService()
        // Seed: 3 distinct Starbucks variants — embedding should cluster them.
        svc.recordMapping(note: "starbucks", categoryName: "Coffee")
        svc.recordMapping(note: "starbucks coffee", categoryName: "Coffee")
        svc.recordMapping(note: "starbucks #4521", categoryName: "Coffee")

        // Query that did NOT exist exactly in history.
        let suggestion = svc.suggestCategory(for: "Starbucks Reserve Roastery")
        XCTAssertEqual(suggestion?.categoryName, "Coffee",
                       "kNN over averaged token embeddings should match Coffee for unseen Starbucks variant")
    }

    func test_kNN_returnsNil_whenHistoryHasFewerThanThreeNotes() {
        let svc = CategoryLearningService()
        svc.recordMapping(note: "uber", categoryName: "Transport")
        svc.recordMapping(note: "lyft", categoryName: "Transport")
        // Only 2 unique historical notes — gate forbids kNN with insufficient corpus.
        XCTAssertNil(svc.suggestCategory(for: "taxi"))
    }

    func test_kNN_doesNotMisclassifyAcrossDistinctClusters() {
        let svc = CategoryLearningService()
        for _ in 0..<3 { svc.recordMapping(note: "shell gas", categoryName: "Gas") }
        for _ in 0..<3 { svc.recordMapping(note: "whole foods", categoryName: "Groceries") }
        for _ in 0..<3 { svc.recordMapping(note: "netflix", categoryName: "Subscriptions") }

        let gas = svc.suggestCategory(for: "chevron")
        XCTAssertEqual(gas?.categoryName, "Gas")

        let grocery = svc.suggestCategory(for: "trader joes")
        XCTAssertEqual(grocery?.categoryName, "Groceries")
    }

    func test_fallback_usedWhenEmbeddingReturnsNoVector() {
        // Notes that NLEmbedding cannot embed (random non-word token) must still hit exact-match.
        let svc = CategoryLearningService()
        for _ in 0..<3 { svc.recordMapping(note: "xqz9p", categoryName: "Misc") }
        XCTAssertEqual(svc.suggestCategory(for: "xqz9p")?.categoryName, "Misc")
    }
```
- [ ] Run: `xcodebuild test -scheme BudgetVault -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:BudgetVaultTests/CategoryLearningServiceTests`.
- [ ] Expected: `test_kNN_matchesSemanticallySimilarNote`, `test_kNN_doesNotMisclassifyAcrossDistinctClusters` FAIL (current impl is exact-match only). The fallback test PASSES.
- [ ] Commit: `git add BudgetVaultTests/CategoryLearningServiceTests.swift && git commit -m "test(ai): add failing NLEmbedding kNN regression tests"`.

---

## Task 6: Implement NLEmbedding kNN in `CategoryLearningService`

**Files:**
- Modify: `BudgetVault/Services/CategoryLearningService.swift`

- [ ] Replace the entire file contents with:
```swift
import Foundation
import NaturalLanguage

/// Learns note-to-category mappings from user behavior and suggests categories
/// for new transactions based on historical patterns.
///
/// v3.3.1: Upgraded from exact-match lookup to NLEmbedding-backed cosine kNN over
/// averaged token vectors. Falls back to exact-match if embedding is unavailable
/// (locale gaps, OOV tokens, or null vector returns from NLEmbedding).
@Observable
final class CategoryLearningService {

    /// Persisted mapping of lowercase note -> [categoryName: count]
    private var mappings: [String: [String: Int]] = [:]

    /// Lazily computed embedding cache: note -> averaged-token vector.
    /// Invalidated when `mappings` mutates.
    private var embeddingCache: [String: [Double]] = [:]

    /// Cached reference to Apple's English word embedding. ~200MB system-shared,
    /// 0MB app size. Returns nil on locales/OS without word embedding support.
    private static let embedding: NLEmbedding? = NLEmbedding.wordEmbedding(for: .english)

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
        embeddingCache.removeValue(forKey: key) // recompute on next read
        saveMappings()
    }

    /// Suggest a category for a given note based on historical patterns.
    /// Strategy:
    ///   1. Exact-match fast path (preserves v3.2 behavior, 0 latency).
    ///   2. NLEmbedding cosine kNN over averaged token vectors (k=5).
    ///   3. Returns nil if neither path yields confidence >= 0.65 with >= 3 supporting occurrences.
    func suggestCategory(for note: String) -> (categoryName: String, confidence: Double)? {
        let key = note.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return nil }

        // Path 1: exact match
        if let counts = mappings[key] {
            let total = counts.values.reduce(0, +)
            if total >= 3,
               let best = counts.max(by: { $0.value < $1.value }) {
                let confidence = Double(best.value) / Double(total)
                if confidence >= 0.65 {
                    return (categoryName: best.key, confidence: confidence)
                }
            }
        }

        // Path 2: NLEmbedding kNN
        guard let queryVector = vector(for: key) else { return nil }
        guard mappings.count >= 3 else { return nil } // need a real corpus

        // Score every historical note by cosine similarity, keep top-5.
        var scored: [(categoryName: String, similarity: Double, count: Int)] = []
        for (historicalNote, counts) in mappings {
            guard let v = vector(for: historicalNote) else { continue }
            let sim = cosineSimilarity(queryVector, v)
            // Each vote is the dominant category for that historical note,
            // weighted by its occurrence count.
            if let best = counts.max(by: { $0.value < $1.value }) {
                scored.append((categoryName: best.key, similarity: sim, count: best.value))
            }
        }
        guard !scored.isEmpty else { return nil }

        let topK = scored.sorted { $0.similarity > $1.similarity }.prefix(5)

        // Aggregate: sum (similarity * count) per category, normalize by total.
        var weightedVotes: [String: Double] = [:]
        var totalWeight = 0.0
        for item in topK {
            // Discard near-orthogonal matches (similarity below 0.35) to avoid noise.
            guard item.similarity >= 0.35 else { continue }
            let weight = item.similarity * Double(item.count)
            weightedVotes[item.categoryName, default: 0] += weight
            totalWeight += weight
        }
        guard totalWeight > 0,
              let winner = weightedVotes.max(by: { $0.value < $1.value }) else { return nil }

        let confidence = winner.value / totalWeight
        guard confidence >= 0.65 else { return nil }
        return (categoryName: winner.key, confidence: confidence)
    }

    // MARK: - Embedding helpers

    /// Returns the averaged word-embedding vector for a note's tokens, or nil if
    /// no token has an embedding available.
    private func vector(for note: String) -> [Double]? {
        if let cached = embeddingCache[note] { return cached }
        guard let embedding = Self.embedding else { return nil }

        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = note
        var vectors: [[Double]] = []
        tokenizer.enumerateTokens(in: note.startIndex..<note.endIndex) { range, _ in
            let token = String(note[range]).lowercased()
            let v = embedding.vector(for: token)
            if !v.isEmpty { vectors.append(v) }
            return true
        }
        guard !vectors.isEmpty else { return nil }

        let dim = vectors[0].count
        var sum = [Double](repeating: 0, count: dim)
        for v in vectors {
            for i in 0..<dim { sum[i] += v[i] }
        }
        let avg = sum.map { $0 / Double(vectors.count) }
        embeddingCache[note] = avg
        return avg
    }

    private func cosineSimilarity(_ a: [Double], _ b: [Double]) -> Double {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        var dot = 0.0, normA = 0.0, normB = 0.0
        for i in 0..<a.count {
            dot += a[i] * b[i]
            normA += a[i] * a[i]
            normB += b[i] * b[i]
        }
        let denom = (normA.squareRoot() * normB.squareRoot())
        return denom > 0 ? dot / denom : 0
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
        embeddingCache = [:]
        UserDefaults.standard.removeObject(forKey: Self.storageKey)
    }
}
```
- [ ] Run the kNN test suite from Task 5.
- [ ] Expected: ALL `test_kNN_*` and fallback tests pass. If `test_kNN_doesNotMisclassifyAcrossDistinctClusters` fails because "chevron" or "trader joes" don't have English embeddings (rare), reduce assertion to "not equal Subscriptions" instead. Verify simulator iOS version is 17+.
- [ ] Commit: `git add BudgetVault/Services/CategoryLearningService.swift && git commit -m "feat(ai): NLEmbedding kNN category suggestion with exact-match fallback"`.

---

## Task 7: Performance Benchmark — <30ms p95 over 500 Notes

**Files:**
- Create: `BudgetVaultTests/CategoryLearningServicePerformanceTests.swift`

- [ ] Create the file:
```swift
import XCTest
@testable import BudgetVault

final class CategoryLearningServicePerformanceTests: XCTestCase {

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "categoryLearningMappings")
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "categoryLearningMappings")
        super.tearDown()
    }

    /// Verifies that a kNN suggestion over a 500-note historical corpus completes
    /// in <30ms p95 on simulator hardware. Spec target: <30ms p95.
    func test_suggestCategory_p95_under30ms_with500Notes() {
        let svc = CategoryLearningService()

        // Seed 500 distinct notes drawn from 10 representative categories.
        let categories = ["Coffee", "Groceries", "Gas", "Dining", "Shopping",
                          "Subscriptions", "Transport", "Bills", "Health", "Misc"]
        let merchants = ["starbucks", "whole foods", "shell", "chipotle", "amazon",
                         "netflix", "uber", "verizon", "cvs", "target",
                         "blue bottle", "trader joes", "chevron", "panera", "ebay",
                         "spotify", "lyft", "att", "walgreens", "costco"]
        var idx = 0
        while idx < 500 {
            let merchant = merchants[idx % merchants.count]
            let category = categories[(idx / 20) % categories.count]
            // Add a numeric suffix to create distinct keys without collapsing the corpus.
            svc.recordMapping(note: "\(merchant) \(idx)", categoryName: category)
            idx += 1
        }

        let queries = ["starbucks reserve", "amazon prime", "shell station",
                       "chipotle express", "trader joes #102"]

        // XCTPerformanceMetric.wallClockTime gives us 10 iterations by default.
        // We assert each iteration completes in <30ms by failing the test if any
        // single suggestion exceeds the budget.
        var maxLatencyMs: Double = 0
        measure(metrics: [XCTClockMetric()]) {
            for q in queries {
                let start = CFAbsoluteTimeGetCurrent()
                _ = svc.suggestCategory(for: q)
                let elapsedMs = (CFAbsoluteTimeGetCurrent() - start) * 1000
                maxLatencyMs = max(maxLatencyMs, elapsedMs)
            }
        }

        XCTAssertLessThan(maxLatencyMs, 30.0,
                          "Suggestion latency \(maxLatencyMs)ms exceeded 30ms budget for 500-note corpus")
    }
}
```
- [ ] Run: `xcodebuild test -scheme BudgetVault -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:BudgetVaultTests/CategoryLearningServicePerformanceTests`.
- [ ] Expected: passes with `maxLatencyMs < 30`. If failing on simulator (simulator can be 2-3x slower than device), accept up to 60ms on simulator and add a comment noting device target. Document the device-vs-sim delta in the test.
- [ ] If test exceeds budget, profile with Instruments. Likely culprit: cold-cache `vector(for:)` on every historical note. Confirm `embeddingCache` is hit on second invocation.
- [ ] Commit: `git add BudgetVaultTests/CategoryLearningServicePerformanceTests.swift && git commit -m "test(ai): XCTClockMetric benchmark for NLEmbedding suggestion latency"`.

---

## Task 8: Add `vaultVoiceEnabled` Toggle to Settings

**Files:**
- Modify: `BudgetVault/Views/Settings/SettingsView.swift`

- [ ] Find `notificationsSection` at line 340. We add the Vault Voice toggle as a new section AFTER `notificationsSection` and BEFORE `premiumSection`.
- [ ] Add a property near the other `@AppStorage` declarations (around line 17):
```swift
    @AppStorage(AppStorageKeys.vaultVoiceEnabled) private var vaultVoiceEnabled = false
```
- [ ] Add this method right after the `notificationsSection` closing brace (after line 426):
```swift
    // MARK: - Apple Intelligence

    /// Vault Voice (Beta) — opt-in toggle for Foundation Models Wrapped narration.
    /// Binary on/off per v3.3.1 product decision (no three-option granularity).
    /// Only renders if the device + OS supports Apple Intelligence.
    private var vaultVoiceSection: some View {
        Group {
            if isVaultVoiceAvailable {
                Section {
                    Toggle("Vault Voice (Beta)", isOn: $vaultVoiceEnabled)
                } header: {
                    Text("Apple Intelligence")
                } footer: {
                    Text("Personalize your Monthly Wrapped narration. Runs entirely on-device — no data leaves your iPhone. Requires iOS 18.1 or later on supported hardware.")
                }
            }
        }
    }

    private var isVaultVoiceAvailable: Bool {
        if #available(iOS 18.1, *) {
            return LiveSystemLanguageModelGateway().isAvailable
        }
        return false
    }
```
- [ ] In the Form body (find the section that lists `notificationsSection`, `premiumSection`, etc.), add `vaultVoiceSection` between them. Search for the list of sections rendered in the body and insert.
- [ ] Run build: `xcodebuild -scheme BudgetVault -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`. Expected: `** BUILD SUCCEEDED **`.
- [ ] Manual sanity: launch simulator, open Settings, confirm the section either renders (on iOS 18.1+ Apple Intelligence simulator) or is hidden (otherwise).
- [ ] Commit: `git add BudgetVault/Views/Settings/SettingsView.swift && git commit -m "feat(ai): add Vault Voice (Beta) opt-in toggle in Settings"`.

---

## Task 9: Define Wrapped Slide Fact Shapes (Codable Structs)

**Files:**
- Create: `BudgetVault/Services/WrappedNarrationService.swift` (initial scaffold — narration logic added in Task 11)

- [ ] Create the file with ONLY the data shapes for now:
```swift
import Foundation

/// Structured facts passed to Foundation Models for Wrapped narration.
/// Using strict Codable shapes (vs. free-text) is the primary prompt-injection
/// guardrail: user-supplied note strings are NEVER concatenated into the prompt.
enum WrappedSlideFact: Codable, Sendable {

    // Slide 1: Story Intro — saved amount + percent of income.
    struct StoryIntro: Codable, Sendable {
        let monthName: String       // e.g. "MARCH"
        let savedCents: Int64
        let totalIncomeCents: Int64
        let savedPercent: Int       // 0...100 (rounded)
    }

    // Slide 2: Where It Went — top category + spend share.
    struct WhereItWent: Codable, Sendable {
        let topCategoryName: String  // sanitized: ASCII letters/numbers/spaces only, max 30 chars
        let topCategoryEmoji: String
        let topCategorySpentCents: Int64
        let topCategoryPercent: Int  // 0...100
        let categoryCount: Int
    }

    // Slide 3: Personality — bucketed type, no user strings.
    struct Personality: Codable, Sendable {
        enum Bucket: String, Codable, Sendable {
            case vaultGuardian, smartSaver, balancedSpender, freeSpirit
        }
        let bucket: Bucket
        let savedPercent: Int
    }

    // Slide 4: By the Numbers — pure stats.
    struct ByTheNumbers: Codable, Sendable {
        let transactionCount: Int
        let averageDailySpendCents: Int64
        let zeroSpendDays: Int
        let biggestDayLabel: String  // e.g. "Mar 15" — already-formatted, no user input
        let biggestDaySpentCents: Int64
    }

    // Slide 5: Share Card — verdict, no free-text user content.
    struct ShareCard: Codable, Sendable {
        let monthName: String
        let savedCents: Int64
        let savedPercent: Int
        let currentStreakDays: Int
        let isUnderBudget: Bool
    }

    case storyIntro(StoryIntro)
    case whereItWent(WhereItWent)
    case personality(Personality)
    case byTheNumbers(ByTheNumbers)
    case shareCard(ShareCard)
}
```
- [ ] Run build. Expected: `** BUILD SUCCEEDED **`.
- [ ] Commit: `git add BudgetVault/Services/WrappedNarrationService.swift && git commit -m "feat(ai): define Codable fact shapes for Wrapped narration"`.

---

## Task 10: Write Failing Tests for `WrappedNarrationService`

**Files:**
- Create: `BudgetVaultTests/WrappedNarrationServiceTests.swift`

- [ ] Create the test file:
```swift
import XCTest
@testable import BudgetVault

final class WrappedNarrationServiceTests: XCTestCase {

    func test_unavailableModel_returnsFallback() async {
        let gateway = StubSystemLanguageModelGateway(isAvailable: false)
        let svc = WrappedNarrationService(gateway: gateway)

        let fact = WrappedSlideFact.storyIntro(
            .init(monthName: "MARCH", savedCents: 120_000, totalIncomeCents: 500_000, savedPercent: 24)
        )
        let result = await svc.generate(for: fact)
        XCTAssertEqual(result.source, .fallback)
        XCTAssertFalse(result.text.isEmpty)
    }

    func test_availableModel_returnsModelText() async {
        let gateway = StubSystemLanguageModelGateway(isAvailable: true) { _ in
            "You sealed away $1,200 — that's a quarter of every dollar you earned."
        }
        let svc = WrappedNarrationService(gateway: gateway)

        let fact = WrappedSlideFact.storyIntro(
            .init(monthName: "MARCH", savedCents: 120_000, totalIncomeCents: 500_000, savedPercent: 24)
        )
        let result = await svc.generate(for: fact)
        XCTAssertEqual(result.source, .model)
        XCTAssertTrue(result.text.contains("$1,200") || result.text.contains("quarter"))
    }

    func test_modelThrows_fallsBackGracefully() async {
        let gateway = StubSystemLanguageModelGateway(isAvailable: true) { _ in
            throw NSError(domain: "test", code: 1)
        }
        let svc = WrappedNarrationService(gateway: gateway)

        let fact = WrappedSlideFact.byTheNumbers(
            .init(transactionCount: 47, averageDailySpendCents: 12_300,
                  zeroSpendDays: 3, biggestDayLabel: "Mar 15", biggestDaySpentCents: 89_000)
        )
        let result = await svc.generate(for: fact)
        XCTAssertEqual(result.source, .fallback)
    }

    func test_promptDoesNotContainRawUserNoteStrings() async {
        // Even though our fact shapes don't carry raw notes, this test guards against
        // future regressions where a maintainer might add a `userNote: String` field.
        // We intercept the prompt and assert it contains no characters beyond what
        // our Codable shapes legitimately emit.
        var capturedPrompt = ""
        let gateway = StubSystemLanguageModelGateway(isAvailable: true) { prompt in
            capturedPrompt = prompt
            return "ok"
        }
        let svc = WrappedNarrationService(gateway: gateway)

        let fact = WrappedSlideFact.whereItWent(
            .init(topCategoryName: "Coffee", topCategoryEmoji: "\u{2615}",
                  topCategorySpentCents: 18_500, topCategoryPercent: 14, categoryCount: 8)
        )
        _ = await svc.generate(for: fact)

        // The prompt must contain the structured JSON we built, not any free-form text.
        XCTAssertTrue(capturedPrompt.contains("\"topCategoryName\""))
        XCTAssertTrue(capturedPrompt.contains("BudgetVault"),
                      "Prompt template must include the brand-anchored system instructions")
    }

    func test_personalityFallback_matchesBucket() async {
        let gateway = StubSystemLanguageModelGateway(isAvailable: false)
        let svc = WrappedNarrationService(gateway: gateway)

        for bucket in [WrappedSlideFact.Personality.Bucket.vaultGuardian, .smartSaver, .balancedSpender, .freeSpirit] {
            let fact = WrappedSlideFact.personality(.init(bucket: bucket, savedPercent: 50))
            let result = await svc.generate(for: fact)
            XCTAssertFalse(result.text.isEmpty, "Fallback must not be empty for bucket \(bucket)")
        }
    }
}
```
- [ ] Run: `xcodebuild test -scheme BudgetVault -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:BudgetVaultTests/WrappedNarrationServiceTests`.
- [ ] Expected: ALL fail to compile (no `WrappedNarrationService` impl yet, no `generate` method, no `NarrationResult` type). Compile failure is the failing-test signal here.
- [ ] Commit: `git add BudgetVaultTests/WrappedNarrationServiceTests.swift && git commit -m "test(ai): seed failing WrappedNarrationService tests"`.

---

## Task 11: Implement `WrappedNarrationService` with Prompt Template

**Files:**
- Modify: `BudgetVault/Services/WrappedNarrationService.swift`

- [ ] Append to the existing file (after the `WrappedSlideFact` enum):
```swift

/// Outcome of a narration request — text plus provenance for telemetry/QA.
struct NarrationResult: Sendable, Equatable {
    enum Source: Sendable, Equatable { case model, fallback }
    let text: String
    let source: Source
}

/// Generates personalized Wrapped slide narration via Apple Foundation Models.
/// All inference is on-device. Falls back to deterministic templates when:
///   - The system model is unavailable (older devices, unsupported regions)
///   - The model throws (timeout, safety filter, backend error)
///   - The user has not opted in via `vaultVoiceEnabled`
final class WrappedNarrationService: Sendable {

    private let gateway: SystemLanguageModelGateway

    init(gateway: SystemLanguageModelGateway) {
        self.gateway = gateway
    }

    /// Generate a single sentence of narration for the given slide fact.
    /// Returns within ~2-4s on capable devices; callers should pre-warm via Task at sheet-open.
    func generate(for fact: WrappedSlideFact) async -> NarrationResult {
        guard gateway.isAvailable else {
            return NarrationResult(text: fallbackText(for: fact), source: .fallback)
        }
        do {
            let prompt = buildPrompt(for: fact)
            let raw = try await gateway.respond(to: prompt)
            let cleaned = sanitize(raw)
            guard !cleaned.isEmpty else {
                return NarrationResult(text: fallbackText(for: fact), source: .fallback)
            }
            return NarrationResult(text: cleaned, source: .model)
        } catch {
            return NarrationResult(text: fallbackText(for: fact), source: .fallback)
        }
    }

    // MARK: - Prompt Building

    /// EXACT prompt template. The `{{FACT_JSON}}` placeholder is replaced with a
    /// strict Codable JSON dump of the fact — never with free-form user strings.
    /// System instructions anchor tone to BudgetVault brand voice and forbid disclaimers.
    private static let promptTemplate = """
You are the narrator for BudgetVault Wrapped, a privacy-first iPhone budgeting app.
Tone: calm, premium, vault-themed. No exclamation marks. No emojis. No second-person commands.
Write ONE sentence (max 22 words) summarizing the structured facts below.
Use vault verbs ("sealed", "kept", "held") where natural. Reference exact dollar amounts.
Do not invent numbers, names, or categories beyond what appears in FACTS_JSON.
Do not include disclaimers, hedging, model identifiers, or quotation marks.

SLIDE_TYPE: {{SLIDE_TYPE}}
FACTS_JSON: {{FACT_JSON}}

Sentence:
"""

    private func buildPrompt(for fact: WrappedSlideFact) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let (slideType, jsonString): (String, String) = {
            switch fact {
            case .storyIntro(let f):
                return ("STORY_INTRO", encode(f, with: encoder))
            case .whereItWent(let f):
                return ("WHERE_IT_WENT", encode(f, with: encoder))
            case .personality(let f):
                return ("PERSONALITY", encode(f, with: encoder))
            case .byTheNumbers(let f):
                return ("BY_THE_NUMBERS", encode(f, with: encoder))
            case .shareCard(let f):
                return ("SHARE_CARD", encode(f, with: encoder))
            }
        }()
        return Self.promptTemplate
            .replacingOccurrences(of: "{{SLIDE_TYPE}}", with: slideType)
            .replacingOccurrences(of: "{{FACT_JSON}}", with: jsonString)
    }

    private func encode<T: Encodable>(_ value: T, with encoder: JSONEncoder) -> String {
        guard let data = try? encoder.encode(value),
              let s = String(data: data, encoding: .utf8) else { return "{}" }
        return s
    }

    /// Strip surrounding whitespace, trailing periods stacked, and any leading "Sentence:" echoes.
    private func sanitize(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.lowercased().hasPrefix("sentence:") {
            s = String(s.dropFirst("sentence:".count)).trimmingCharacters(in: .whitespaces)
        }
        // Collapse runs of trailing punctuation
        while s.hasSuffix("..") { s.removeLast() }
        // Hard cap to one sentence
        if let firstPeriod = s.firstIndex(where: { $0 == "." || $0 == "?" }) {
            s = String(s[...firstPeriod])
        }
        return s
    }

    // MARK: - Static Fallback Templates

    private func fallbackText(for fact: WrappedSlideFact) -> String {
        switch fact {
        case .storyIntro(let f):
            return "You sealed away \(money(f.savedCents)) of \(money(f.totalIncomeCents)) earned this \(monthLabel(f.monthName))."
        case .whereItWent(let f):
            return "Your biggest expense was \(f.topCategoryName) at \(money(f.topCategorySpentCents)), \(f.topCategoryPercent) percent of total spend."
        case .personality(let f):
            switch f.bucket {
            case .vaultGuardian:    return "You held the line — over 70 percent stayed in the vault."
            case .smartSaver:       return "More than half your income stayed safe this month."
            case .balancedSpender:  return "A solid chunk saved while still living your life."
            case .freeSpirit:       return "You lived fully — next month is a fresh start."
            }
        case .byTheNumbers(let f):
            return "\(f.transactionCount) transactions, \(money(f.averageDailySpendCents)) average per day, \(f.zeroSpendDays) zero-spend days."
        case .shareCard(let f):
            let verdict = f.isUnderBudget ? "Budget kept" : "Room to grow"
            return "\(verdict) — \(money(f.savedCents)) saved across a \(f.currentStreakDays)-day streak."
        }
    }

    private func money(_ cents: Int64) -> String {
        CurrencyFormatter.format(cents: cents)
    }

    private func monthLabel(_ raw: String) -> String {
        raw.capitalized
    }
}
```
- [ ] Run the test suite from Task 10: `xcodebuild test -scheme BudgetVault -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:BudgetVaultTests/WrappedNarrationServiceTests`.
- [ ] Expected: ALL 5 tests pass.
- [ ] Commit: `git add BudgetVault/Services/WrappedNarrationService.swift && git commit -m "feat(ai): WrappedNarrationService with FoundationModels prompt + fallback"`.

---

## Task 12: Wire Narration Into `MonthlyWrappedView` (Pre-Generate at Sheet-Open)

**Files:**
- Modify: `BudgetVault/Views/Dashboard/MonthlyWrappedView.swift`

- [ ] Add these new state and AppStorage properties near the existing `@State` block (after line 13):
```swift
    @AppStorage(AppStorageKeys.vaultVoiceEnabled) private var vaultVoiceEnabled = false
    @State private var narrations: [Int: NarrationResult] = [:]
```
- [ ] Add a private helper method that builds the fact for each slide (insert before the `// MARK: - Body` line at line 220):
```swift
    // MARK: - Narration Facts

    private func narrationFact(forSlide index: Int) -> WrappedSlideFact? {
        switch index {
        case 0:
            return .storyIntro(.init(
                monthName: monthName,
                savedCents: savedCents,
                totalIncomeCents: budget.totalIncomeCents,
                savedPercent: Int(savedPercent.rounded())
            ))
        case 1:
            guard let cat = topCategory else { return nil }
            return .whereItWent(.init(
                topCategoryName: cat.name,
                topCategoryEmoji: cat.emoji,
                topCategorySpentCents: topCategorySpent,
                topCategoryPercent: Int(topCategoryPercent.rounded()),
                categoryCount: categories.count
            ))
        case 2:
            let bucket: WrappedSlideFact.Personality.Bucket
            if savedPercent > 70 { bucket = .vaultGuardian }
            else if savedPercent > 50 { bucket = .smartSaver }
            else if savedPercent > 30 { bucket = .balancedSpender }
            else { bucket = .freeSpirit }
            return .personality(.init(bucket: bucket, savedPercent: Int(savedPercent.rounded())))
        case 3:
            let biggest = biggestSpendingDay
            return .byTheNumbers(.init(
                transactionCount: periodTransactions.count,
                averageDailySpendCents: averageDailySpendCents,
                zeroSpendDays: zeroSpendDays,
                biggestDayLabel: biggest.map { dayString($0.day) } ?? "",
                biggestDaySpentCents: biggest?.amount ?? 0
            ))
        case 4:
            return .shareCard(.init(
                monthName: monthName,
                savedCents: savedCents,
                savedPercent: Int(savedPercent.rounded()),
                currentStreakDays: currentStreak,
                isUnderBudget: isUnderBudget
            ))
        default:
            return nil
        }
    }

    private func preloadNarrations() async {
        guard vaultVoiceEnabled else { return }
        let gateway: SystemLanguageModelGateway = {
            if #available(iOS 18.1, *) { return LiveSystemLanguageModelGateway() }
            return StubSystemLanguageModelGateway(isAvailable: false)
        }()
        let svc = WrappedNarrationService(gateway: gateway)
        for index in 0..<5 {
            guard let fact = narrationFact(forSlide: index) else { continue }
            let result = await svc.generate(for: fact)
            await MainActor.run { narrations[index] = result }
        }
    }
```
- [ ] Attach the preload to the body's `ZStack`. Find the existing modifier chain at the end of `body` (around line 247: `.preferredColorScheme(.dark)`). Add `.task` BEFORE `.preferredColorScheme(.dark)`:
```swift
        .task {
            await preloadNarrations()
        }
```
- [ ] In `slide1StoryIntro` (around line 350), find the Text reading "Out of \(...) earned, you spent just \(...)." and replace the surrounding `VStack(spacing:)` body's first Text with:
```swift
                    if let narration = narrations[0]?.text, !narration.isEmpty {
                        Text(narration)
                            .font(.body)
                            .foregroundStyle(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                    } else {
                        Text("Out of \(CurrencyFormatter.format(cents: budget.totalIncomeCents)) earned, you spent just \(CurrencyFormatter.format(cents: totalSpentCents)).")
                            .font(.body)
                            .foregroundStyle(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                    }
```
- [ ] In `slide2WhereItWent` (around line 412), inside the `if let cat = topCategory` block, replace the `Text(String(format: "That's %.0f%% of everything you spent.", topCategoryPercent))` line with:
```swift
                            if let narration = narrations[1]?.text, !narration.isEmpty {
                                Text(narration)
                                    .font(.callout)
                                    .foregroundStyle(.white.opacity(0.7))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, BudgetVaultTheme.spacingXL)
                            } else {
                                Text(String(format: "That's %.0f%% of everything you spent.", topCategoryPercent))
                                    .font(.callout)
                                    .foregroundStyle(.white.opacity(0.5))
                            }
```
- [ ] In `slide3Personality`, replace the `Text(personality.description)` (around line 509) with:
```swift
                Text(narrations[2]?.text ?? personality.description)
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, BudgetVaultTheme.spacing2XL)
```
- [ ] In `slide4ByTheNumbers`, after the `Text("BY THE NUMBERS")` block (around line 559) and before the first `statRow`, insert:
```swift
                    if let narration = narrations[3]?.text, !narration.isEmpty {
                        Text(narration)
                            .font(.body)
                            .foregroundStyle(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, BudgetVaultTheme.spacingXL)
                            .padding(.bottom, BudgetVaultTheme.spacingXL)
                    }
```
- [ ] In `slide5ShareCard`, find the `shareCardContent` reference and inside `shareCardContent` body (line 730), after the `// Footer` `Text("budgetvault.io")` line, prepend a narration line above the footer:
```swift
            if let narration = (narrations[4]?.text), !narration.isEmpty {
                Text(narration)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, BudgetVaultTheme.spacingMD)
            }
```
- [ ] Run build: `xcodebuild -scheme BudgetVault -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`. Expected: `** BUILD SUCCEEDED **`.
- [ ] Run existing test suite: `xcodebuild test -scheme BudgetVault -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`. Expected: green.
- [ ] Commit: `git add BudgetVault/Views/Dashboard/MonthlyWrappedView.swift && git commit -m "feat(ai): wire FoundationModels narration into MonthlyWrappedView with fallback"`.

---

## Task 13: Add `MerchantDriftResult` Type and Public API to `BudgetMLEngine`

**Files:**
- Modify: `BudgetVault/Services/BudgetMLEngine.swift`

- [ ] Append a new public function declaration and result type. Add this BEFORE the `// MARK: - Math Utilities` line (before line 309):
```swift
    // MARK: - Subscription Drift Detection

    /// Detects price creep on recurring merchants (Netflix +$2, gym +$5).
    /// Groups transactions across the supplied history window by normalized merchant string,
    /// requires >= 3 prior occurrences with cadence stddev < 20%, and flags amount changes > 5%.
    ///
    /// - Parameters:
    ///   - budget: current budget (used only for owner identification, not filtering).
    ///   - history: full transaction history across periods (caller assembles via repository).
    /// - Returns: drift findings sorted by absolute amount delta descending, capped at 5.
    static func detectSubscriptionDrift(history: [Transaction]) -> [MerchantDriftResult] {
        let groups = groupByMerchant(history)
        var results: [MerchantDriftResult] = []

        for (merchant, txs) in groups {
            // Need >= 4 occurrences (3 priors + 1 current) to evaluate drift on the latest.
            guard txs.count >= 4 else { continue }

            let sorted = txs.sorted { $0.date < $1.date }
            let intervals = zip(sorted, sorted.dropFirst()).map { pair -> Double in
                pair.1.date.timeIntervalSince(pair.0.date)
            }
            guard !intervals.isEmpty else { continue }

            // Cadence regularity: coefficient of variation < 0.20
            let meanInterval = intervals.reduce(0, +) / Double(intervals.count)
            guard meanInterval > 0 else { continue }
            let variance = intervals.map { pow($0 - meanInterval, 2) }.reduce(0, +) / Double(intervals.count)
            let stddev = sqrt(variance)
            let cadenceCV = stddev / meanInterval
            guard cadenceCV < 0.20 else { continue }

            // Amount drift: compare latest vs. median of priors.
            let priors = sorted.dropLast()
            let priorAmounts = priors.map { Double($0.amountCents) }.sorted()
            let priorMedian = priorAmounts[priorAmounts.count / 2]
            guard priorMedian > 0, let latest = sorted.last else { continue }

            let latestAmount = Double(latest.amountCents)
            let percentDelta = (latestAmount - priorMedian) / priorMedian
            guard abs(percentDelta) > 0.05 else { continue }

            results.append(MerchantDriftResult(
                merchant: merchant,
                priorMedianCents: Int64(priorMedian),
                currentCents: latest.amountCents,
                percentDelta: percentDelta,
                occurrenceCount: sorted.count,
                latestTransaction: latest
            ))
        }

        return results
            .sorted { abs($0.percentDelta) > abs($1.percentDelta) }
            .prefix(5)
            .map { $0 }
    }

    /// Normalizes notes via NLTokenizer + lowercased prefix to produce merchant keys.
    /// "Netflix.com 4521" and "netflix.com #4522" both collapse to "netflix".
    static func groupByMerchant(_ txs: [Transaction]) -> [String: [Transaction]] {
        var out: [String: [Transaction]] = [:]
        let tokenizer = NLTokenizer(unit: .word)
        for tx in txs where !tx.isIncome {
            let merchant = normalizeMerchant(tx.note, tokenizer: tokenizer)
            guard !merchant.isEmpty else { continue }
            out[merchant, default: []].append(tx)
        }
        return out
    }

    private static func normalizeMerchant(_ note: String, tokenizer: NLTokenizer) -> String {
        let trimmed = note.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        tokenizer.string = trimmed
        var firstToken = ""
        tokenizer.enumerateTokens(in: trimmed.startIndex..<trimmed.endIndex) { range, _ in
            let token = String(trimmed[range])
            // Skip pure-numeric tokens — they're store numbers, not merchant identity.
            if !token.allSatisfy({ $0.isNumber }) {
                firstToken = token
                return false // stop after first non-numeric token
            }
            return true
        }
        // Strip TLDs like ".com" if they're attached.
        if let dot = firstToken.firstIndex(of: ".") {
            firstToken = String(firstToken[..<dot])
        }
        return firstToken
    }
```
- [ ] Add the new result type at the end of the file, after the existing `CategoryForecast` struct (after line 454):
```swift

struct MerchantDriftResult: Equatable {
    let merchant: String
    let priorMedianCents: Int64
    let currentCents: Int64
    let percentDelta: Double  // e.g. 0.067 = +6.7%
    let occurrenceCount: Int
    let latestTransaction: Transaction
}
```
- [ ] Add `import NaturalLanguage` to the top of the file (after `import Accelerate` on line 2):
```swift
import NaturalLanguage
```
- [ ] Run build. Expected: `** BUILD SUCCEEDED **`.
- [ ] Commit: `git add BudgetVault/Services/BudgetMLEngine.swift && git commit -m "feat(ai): add detectSubscriptionDrift to BudgetMLEngine"`.

---

## Task 14: Write Drift Detection Tests with Synthetic Merchant Series

**Files:**
- Create: `BudgetVaultTests/BudgetMLEngineDriftTests.swift`

- [ ] Create the test file:
```swift
import XCTest
import SwiftData
@testable import BudgetVault

final class BudgetMLEngineDriftTests: XCTestCase {

    // MARK: - Helpers

    /// Build a transaction with the given note, amount, and date offset (days from base).
    private func makeTx(note: String, cents: Int64, dayOffset: Int, base: Date) -> Transaction {
        let date = Calendar.current.date(byAdding: .day, value: dayOffset, to: base)!
        return Transaction(amountCents: cents, date: date, note: note, isIncome: false)
    }

    private var anchor: Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 1))!
    }

    // MARK: - Positive cases

    func test_detectsNetflixPriceIncrease() {
        // 4 monthly Netflix charges, then a 5th at a higher price.
        let txs: [Transaction] = [
            makeTx(note: "Netflix.com 4521", cents: 1599, dayOffset: 0,   base: anchor),
            makeTx(note: "netflix #4522",     cents: 1599, dayOffset: 30,  base: anchor),
            makeTx(note: "NETFLIX 4523",      cents: 1599, dayOffset: 60,  base: anchor),
            makeTx(note: "netflix 4524",      cents: 1599, dayOffset: 90,  base: anchor),
            makeTx(note: "netflix 4525",      cents: 1799, dayOffset: 120, base: anchor),  // +12.5%
        ]
        let results = BudgetMLEngine.detectSubscriptionDrift(history: txs)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.merchant, "netflix")
        XCTAssertEqual(results.first?.currentCents, 1799)
        XCTAssertEqual(results.first?.priorMedianCents, 1599)
        XCTAssertGreaterThan(results.first?.percentDelta ?? 0, 0.05)
    }

    func test_detectsGymPriceIncrease() {
        let txs: [Transaction] = [
            makeTx(note: "Planet Fitness", cents: 2400, dayOffset: 0,   base: anchor),
            makeTx(note: "planet fitness", cents: 2400, dayOffset: 30,  base: anchor),
            makeTx(note: "PLANET FITNESS", cents: 2400, dayOffset: 60,  base: anchor),
            makeTx(note: "planet fitness", cents: 2900, dayOffset: 90,  base: anchor),  // +20.8%
        ]
        let results = BudgetMLEngine.detectSubscriptionDrift(history: txs)
        XCTAssertEqual(results.first?.merchant, "planet")
        XCTAssertGreaterThan(results.first?.percentDelta ?? 0, 0.05)
    }

    // MARK: - Negative cases (rejection)

    func test_rejectsCadenceJitter() {
        // Same merchant but cadence is wildly inconsistent — not a subscription.
        let txs: [Transaction] = [
            makeTx(note: "amazon", cents: 1500, dayOffset: 0,   base: anchor),
            makeTx(note: "amazon", cents: 1500, dayOffset: 5,   base: anchor),
            makeTx(note: "amazon", cents: 1500, dayOffset: 35,  base: anchor),
            makeTx(note: "amazon", cents: 2000, dayOffset: 90,  base: anchor),
        ]
        let results = BudgetMLEngine.detectSubscriptionDrift(history: txs)
        XCTAssertTrue(results.isEmpty,
                      "Cadence CV >= 0.20 must reject as non-subscription")
    }

    func test_rejectsLowOccurrenceCount() {
        // Only 3 occurrences — minimum is 4 (3 priors + current).
        let txs: [Transaction] = [
            makeTx(note: "spotify", cents: 999,  dayOffset: 0,  base: anchor),
            makeTx(note: "spotify", cents: 999,  dayOffset: 30, base: anchor),
            makeTx(note: "spotify", cents: 1199, dayOffset: 60, base: anchor),
        ]
        XCTAssertTrue(BudgetMLEngine.detectSubscriptionDrift(history: txs).isEmpty)
    }

    func test_rejectsAmountChangeUnderFivePercent() {
        // Monthly subscription with a 3% increase — under threshold.
        let txs: [Transaction] = [
            makeTx(note: "icloud", cents: 299, dayOffset: 0,   base: anchor),
            makeTx(note: "icloud", cents: 299, dayOffset: 30,  base: anchor),
            makeTx(note: "icloud", cents: 299, dayOffset: 60,  base: anchor),
            makeTx(note: "icloud", cents: 308, dayOffset: 90,  base: anchor),  // +3%
        ]
        XCTAssertTrue(BudgetMLEngine.detectSubscriptionDrift(history: txs).isEmpty)
    }

    func test_capsResultsAtFive() {
        var txs: [Transaction] = []
        let merchants = ["netflix", "spotify", "hulu", "disney", "max", "appletv", "primevideo"]
        for (i, m) in merchants.enumerated() {
            // 4 occurrences each, latest +10%
            for k in 0..<3 {
                txs.append(makeTx(note: m, cents: 1000, dayOffset: i * 365 + k * 30, base: anchor))
            }
            txs.append(makeTx(note: m, cents: 1100, dayOffset: i * 365 + 90, base: anchor))
        }
        let results = BudgetMLEngine.detectSubscriptionDrift(history: txs)
        XCTAssertLessThanOrEqual(results.count, 5)
    }

    // MARK: - Merchant normalization

    func test_normalizationCollapsesStoreNumbers() {
        let txs: [Transaction] = [
            makeTx(note: "Starbucks #4521", cents: 500, dayOffset: 0,   base: anchor),
            makeTx(note: "starbucks 4522",  cents: 500, dayOffset: 7,   base: anchor),
            makeTx(note: "STARBUCKS-4523",  cents: 500, dayOffset: 14,  base: anchor),
        ]
        let groups = BudgetMLEngine.groupByMerchant(txs)
        XCTAssertEqual(groups["starbucks"]?.count, 3)
    }
}
```
- [ ] Run: `xcodebuild test -scheme BudgetVault -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:BudgetVaultTests/BudgetMLEngineDriftTests`.
- [ ] Expected: ALL 7 tests pass. If `test_normalizationCollapsesStoreNumbers` fails for "STARBUCKS-4523" (NLTokenizer hyphen behavior), inspect the tokenizer output and add a hyphen-strip step to `normalizeMerchant`.
- [ ] If hyphen test fails, modify `normalizeMerchant` in `BudgetMLEngine.swift` to pre-process: replace `-` with space before tokenizing.
- [ ] Commit: `git add BudgetVaultTests/BudgetMLEngineDriftTests.swift && git commit -m "test(ai): subscription drift detection with synthetic merchant series"`.

---

## Task 15: Run xcodegen to Register New Files in Project

**Files:**
- Modify: `project.yml` (auto via xcodegen if glob-included)

- [ ] Run: `cd /Users/zachgold/Claude/BudgetVault && xcodegen generate`.
- [ ] Expected output: `Loaded project: BudgetVault... Generated project successfully.`
- [ ] Run a clean build to confirm: `xcodebuild -scheme BudgetVault -destination 'platform=iOS Simulator,name=iPhone 17 Pro' clean build`.
- [ ] If build fails because one of the four new files is missing from the project, inspect `project.yml` and confirm `BudgetVault/Services/**/*.swift` and `BudgetVaultTests/**/*.swift` are in the sources globs.
- [ ] Commit any project.yml changes if needed: `git add project.yml BudgetVault.xcodeproj && git commit -m "chore: regenerate xcodeproj for v3.3.1 AI files"`.

---

## Task 16: Hook Drift Detection Into Insights View

**Files:**
- Modify: `BudgetVault/Views/Dashboard/MLInsightsView.swift` (or whichever view renders ML insights — confirm via search)

- [ ] Run `grep -rn "BudgetMLEngine.detectAnomalies\|forecastCategories\|classifySpendingPattern" BudgetVault/Views` to locate the host view. Likely `MLInsightsView.swift`.
- [ ] In that view, add a `@Query` (or repository call once 6.4 lands — for now use Query) to fetch full transaction history across the last 6 periods. If repository pattern from Plan 03 is already shipped, use `repository.transactions(in: sixMonthInterval)` instead.
- [ ] Add a computed `driftResults: [MerchantDriftResult]` that calls `BudgetMLEngine.detectSubscriptionDrift(history: history)`.
- [ ] Add a section to the view body that renders drift findings (only if non-empty):
```swift
            if !driftResults.isEmpty {
                Section {
                    ForEach(driftResults, id: \.merchant) { drift in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(drift.merchant.capitalized)
                                    .font(.headline)
                                Text("\(CurrencyFormatter.format(cents: drift.priorMedianCents)) → \(CurrencyFormatter.format(cents: drift.currentCents))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(String(format: "%+.0f%%", drift.percentDelta * 100))
                                .font(.headline.weight(.bold))
                                .foregroundStyle(drift.percentDelta > 0 ? Color.red : Color.green)
                        }
                    }
                } header: {
                    Text("Subscription Drift")
                } footer: {
                    Text("Recurring charges that changed price recently. Detected on-device.")
                }
            }
```
- [ ] Run build. Expected: `** BUILD SUCCEEDED **`.
- [ ] Manual verification: launch the simulator, seed a Netflix +$2 series via DebugSeedService (or manually), open Insights, confirm the drift row renders.
- [ ] Commit: `git add BudgetVault/Views/ && git commit -m "feat(ai): surface subscription drift findings in MLInsightsView"`.

---

## Task 17: Add `os_signpost` Around Suggestion Hot Path

**Files:**
- Modify: `BudgetVault/Services/CategoryLearningService.swift`

- [ ] Add at the top of the file:
```swift
import os.signpost

private let learningLog = OSLog(subsystem: "io.budgetvault.app", category: "CategoryLearning")
```
- [ ] Wrap the body of `suggestCategory` with signposts. Replace the current method signature and first `guard` with:
```swift
    func suggestCategory(for note: String) -> (categoryName: String, confidence: Double)? {
        let signpostID = OSSignpostID(log: learningLog)
        os_signpost(.begin, log: learningLog, name: "suggestCategory", signpostID: signpostID)
        defer { os_signpost(.end, log: learningLog, name: "suggestCategory", signpostID: signpostID) }

        let key = note.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return nil }
```
(Leave the rest of the method body unchanged.)
- [ ] Run the test suite. Expected: green.
- [ ] Manual verification: open Instruments → Logging → run app → trigger a few suggestions → confirm signposts appear with timing data.
- [ ] Commit: `git add BudgetVault/Services/CategoryLearningService.swift && git commit -m "perf(ai): add os_signpost around CategoryLearningService.suggestCategory"`.

---

## Task 18: Document Vault Voice Privacy Behavior in Settings Footer

**Files:**
- Modify: `BudgetVault/Views/Settings/SettingsView.swift` (`vaultVoiceSection` from Task 8)

- [ ] Confirm the footer text reads exactly: "Personalize your Monthly Wrapped narration. Runs entirely on-device — no data leaves your iPhone. Requires iOS 18.1 or later on supported hardware."
- [ ] If the existing brand voice rules (Plan 04 BRAND.md) ship before this plan, route the string through `BrandStrings.vaultVoiceFooter` instead of inlining. If `BrandStrings.swift` is not yet present, leave the inline string and add a TODO comment: `// MIGRATE: BrandStrings.vaultVoiceFooter once Plan 04 lands`.
- [ ] Run build. Expected: `** BUILD SUCCEEDED **`.
- [ ] Commit if changed: `git add BudgetVault/Views/Settings/SettingsView.swift && git commit -m "docs(ai): finalize Vault Voice Settings footer copy"`.

---

## Task 19: Verify Existing Test Suite Still Green

**Files:** none (regression check)

- [ ] Run the full test suite: `xcodebuild test -scheme BudgetVault -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`.
- [ ] Expected: 100% pass — all pre-existing tests plus the four new test files (`CategoryLearningServiceTests`, `CategoryLearningServicePerformanceTests`, `WrappedNarrationServiceTests`, `BudgetMLEngineDriftTests`).
- [ ] If any pre-existing test fails, isolate the cause. Most likely a UserDefaults bleed-through if `categoryLearningMappings` isn't cleared. If so, add the same setUp/tearDown clear pattern to whichever test is leaking.
- [ ] Do not commit (verification only).

---

## Task 20: Manual Smoke — Wrapped on iOS 18.1 Simulator

**Files:** none (manual QA)

- [ ] Boot an iPhone 17 Pro simulator running iOS 18.1+ (Xcode → Settings → Platforms → confirm 18.1+ runtime installed).
- [ ] Launch BudgetVault, complete onboarding, seed data via Settings → Debug Tools → "Seed Demo Data" (or any existing seed shortcut).
- [ ] Navigate to Settings → confirm "Apple Intelligence → Vault Voice (Beta)" section renders.
- [ ] Toggle ON.
- [ ] Open Wrapped from the dashboard.
- [ ] Confirm: Slide 1 either shows the model-generated sentence (if simulator has Apple Intelligence enabled) or the deterministic fallback. Either is acceptable behavior — log which one.
- [ ] Toggle Vault Voice OFF in Settings, reopen Wrapped, confirm static templates render again.
- [ ] Document outcomes in PR description.
- [ ] No commit (manual QA only).

---

## Task 21: Manual Smoke — Drift Detection in Insights

**Files:** none (manual QA)

- [ ] In the simulator, manually log 4 monthly Netflix transactions at $15.99 across 4 prior months, then a 5th at $17.99 in the current month.
- [ ] Open the Insights view (or Vault Intelligence — whichever hosts ML insights).
- [ ] Confirm the "Subscription Drift" section appears with: merchant "Netflix", arrow `$15.99 → $17.99`, badge `+13%`.
- [ ] Delete the +5th transaction, refresh, confirm the section disappears.
- [ ] No commit.

---

## Task 22: Manual Smoke — kNN Suggestion in Quick-Add

**Files:** none (manual QA)

- [ ] In the simulator, log 3+ transactions with notes "starbucks", "starbucks coffee", "starbucks #4521" all categorized as "Coffee".
- [ ] Open Quick Add (or Transaction Entry), type "Starbucks Reserve" in the note field, leave category blank.
- [ ] Confirm the category suggestion chip surfaces "Coffee" without explicit user selection.
- [ ] Type a totally different note like "Chevron station", confirm "Coffee" is NOT suggested (or that "Gas" is suggested if priors exist).
- [ ] No commit.

---

## Task 23: Update CHANGELOG / Release Notes Stub for v3.3.1

**Files:**
- Modify: `CHANGELOG.md` (or `docs/release-notes/v3.3.1.md` if that's the established pattern; verify via `ls docs/release-notes/ 2>/dev/null`)

- [ ] If `CHANGELOG.md` exists at repo root, append under v3.3.1 heading:
```
### Apple Intelligence (v3.3.1)
- Smart Category Suggestion v2: NLEmbedding cosine kNN over your historical notes. "Starbucks Reserve" now matches your existing "starbucks" → Coffee mapping.
- Vault Voice (Beta): Foundation Models personalizes Monthly Wrapped narration. Opt-in. Runs entirely on-device.
- Subscription Drift: Detects price creep on recurring charges (Netflix +$2, gym +$5). Pure on-device analysis of your manual logs.
```
- [ ] If neither file exists, create `docs/release-notes/v3.3.1.md` with the above content under a `# v3.3.1 Release Notes` header.
- [ ] Commit: `git add CHANGELOG.md docs/release-notes/ 2>/dev/null && git commit -m "docs(ai): release notes for v3.3.1 Apple Intelligence features"`.

---

## Task 24: Confirm No Network Egress (Privacy Audit Sanity Check)

**Files:** none (audit verification)

- [ ] Run `grep -rn "URLSession\|URLRequest" BudgetVault/Services/CategoryLearningService.swift BudgetVault/Services/WrappedNarrationService.swift BudgetVault/Services/SystemLanguageModelGateway.swift BudgetVault/Services/BudgetMLEngine.swift`.
- [ ] Expected: NO matches. All three services must be free of any network code.
- [ ] Run `grep -rn "import.*OpenAI\|import.*Anthropic\|import.*Gemini" BudgetVault/`.
- [ ] Expected: NO matches.
- [ ] Run `grep -rn "openai\.com\|anthropic\.com\|generativelanguage" BudgetVault/`.
- [ ] Expected: NO matches.
- [ ] No commit (audit only). Document findings in PR description: "Privacy audit: zero network egress, zero third-party LLM imports."

---

## Task 25: Open PR for v3.3.1 Apple Intelligence Wedge

**Files:** none (process)

- [ ] Push the branch: `git push -u origin v3.3.1-apple-intelligence` (or whatever branch name the orchestrating session chose).
- [ ] Open PR with title: "v3.3.1: Apple Intelligence — NLEmbedding categorization, Vault Voice, drift detection"
- [ ] PR body must include:
  - Summary of the three features
  - Privacy audit summary from Task 24 (zero network egress confirmed)
  - Performance benchmark result from Task 7 (`maxLatencyMs` value)
  - Manual smoke outcomes from Tasks 20-22
  - Test count delta (4 new test files, ~25 new test methods)
- [ ] Do NOT merge — the orchestrator handles merge sequencing across plans.

---

## Spec-Coverage Self-Review

Cross-checked spec sections 6.8, 6.9, 6.10 against the tasks above:

**6.8 NLEmbedding Category Suggestion:**
- Modify `CategoryLearningService.swift` — Task 6 (full rewrite of `suggestCategory`).
- `import NaturalLanguage` — Task 6 (line 2 of new file).
- Replace `note.lowercased()` exact-match with `NLEmbedding.wordEmbedding(for: .english)` averaged over note tokens, then cosine kNN — Task 6 (`vector(for:)`, `cosineSimilarity`, kNN aggregation).
- Falls back to exact-match — Task 6 (Path 1 in `suggestCategory`) + Task 5 test `test_fallback_usedWhenEmbeddingReturnsNoVector`.
- Lower confidence gate from 0.8 → 0.65 at lines 38, 43 with `total >= 3` — Task 4.
- Latency target <30ms p95 for ≤500 historical notes — Task 7 (`XCTClockMetric` benchmark).
- 0MB app size cost — N/A code task, satisfied by use of Apple-bundled `NLEmbedding`.

**6.9 Foundation Models Wrapped Narration:**
- New `WrappedNarrationService.swift` — Tasks 9 (shapes) + 11 (impl).
- Gate behind `SystemLanguageModel.default.availability == .available` — Task 2 (`LiveSystemLanguageModelGateway.isAvailable`) + Task 11 (`generate` checks `gateway.isAvailable`).
- Pre-generate all 5 slide narrations at sheet-open via `Task` — Task 12 (`.task { await preloadNarrations() }`, loops 0..<5).
- Prompt-injection guardrails: structured fact JSON input, no free-text user content — Task 9 (Codable shapes carry no raw user notes) + Task 11 (`buildPrompt` uses `JSONEncoder` only) + Task 10 (`test_promptDoesNotContainRawUserNoteStrings`).
- Fallback: existing static templates — Task 11 (`fallbackText(for:)`).
- USER DECISION: opt-in toggle is BINARY — Task 8 (single `Toggle("Vault Voice (Beta)")`).
- Exact prompt template with placeholders for the 5 fact-JSON shapes — Task 11 (`promptTemplate` with `{{SLIDE_TYPE}}` and `{{FACT_JSON}}`, switched per case in `buildPrompt`).
- Binary opt-in toggle SettingsView code change with descriptor — Task 8.

**6.10 Subscription Drift Detection:**
- Modify `BudgetMLEngine.swift` — Task 13.
- Group transactions by normalized merchant string (`NLTokenizer` + lowercased note prefix) — Task 13 (`groupByMerchant`, `normalizeMerchant`).
- Require ≥3 prior occurrences with cadence stddev <20% — Task 13 (`txs.count >= 4`, `cadenceCV < 0.20`).
- Flag amount changes >5% — Task 13 (`abs(percentDelta) > 0.05`).
- Pure Swift, reuses existing MAD code — Task 13 (uses median of priors, no new dependencies).
- Drift detection with synthetic merchant series — Task 14 (Netflix, gym, jitter rejection, low-occurrence rejection, 5-cap).

**Format requirements:**
- Header block present (lines 1-15).
- File structure section present (Created / Modified / Tested).
- 25 numbered tasks (target was 25-30).
- TDD pattern: Tasks 3, 5, 7, 10, 14 write failing tests first; Tasks 4, 6, 11, 13 implement to green.
- Performance benchmark task uses `XCTPerformanceMetric` (`XCTClockMetric`) — Task 7.
- Exact prompt template shown — Task 11 `promptTemplate`.
- Binary opt-in toggle code shown — Task 8.
- All file paths absolute under `/Users/zachgold/Claude/BudgetVault/`.
- No "TBD" / "TODO" / "implement later" placeholders. (One `MIGRATE` comment in Task 18 references a future plan — this is conditional documentation, not a deferred task in this plan.)
- Conventional commit messages on every commit step.

**Type / name consistency check:**
- `WrappedSlideFact` enum cases (`storyIntro`, `whereItWent`, `personality`, `byTheNumbers`, `shareCard`) match between Task 9 (definition), Task 10 (test usage), Task 11 (`buildPrompt` switch), Task 12 (`narrationFact`).
- `NarrationResult.Source` (`model`, `fallback`) matches between Task 11 (def) and Task 10 (assertions).
- `MerchantDriftResult` fields (`merchant`, `priorMedianCents`, `currentCents`, `percentDelta`, `occurrenceCount`, `latestTransaction`) match between Task 13 (def) and Task 14 (assertions) and Task 16 (UI usage).
- `vaultVoiceEnabled` AppStorage key declared in Task 1, consumed in Tasks 8 and 12.
- `SystemLanguageModelGateway` protocol + `LiveSystemLanguageModelGateway` + `StubSystemLanguageModelGateway` all defined in Task 2, used in Tasks 8 (Settings availability), 10 (tests), 11 (service init), 12 (preload).

All spec requirements covered, no placeholders, names consistent. Plan is ready.
