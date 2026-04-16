# Engineering: AI/ML Engineer Findings

## TL;DR
BudgetVault already ships a respectable on-device statistical engine (`BudgetMLEngine.swift`, 455 LOC: weighted regression, MAD z-score anomalies, exponential smoothing, 5-feature pattern classification) plus an exact-match `CategoryLearningService` — the high-leverage v3.3 move is a tiny on-device NL categorizer (NLEmbedding + the existing learning corpus) that turns the current 0.8-confidence exact-match suggester into a real classifier with sub-50ms latency and zero new data exposure.

## Top 3 Opportunities (Ranked)

1. **Smart Category Suggestion v2 (NLEmbedding + kNN)** — Today `CategoryLearningService.suggestCategory` (line 33) only fires on exact normalized-string match; "Starbucks" never matches "starbucks coffee #4521". Replace with `NLEmbedding.wordEmbedding(for: .english)` (Apple-bundled, ~200MB system-shared, 0MB app size) averaged over note tokens, then cosine-kNN over historical note→category pairs. Falls back to exact-match if embedding unavailable (iOS<17 locale gaps). **Latency:** <30ms p95 for ≤500 historical notes (linear scan). **Effort:** 2 days. **Impact:** every quick-add gets a one-tap suggestion vs. today's silent miss; converts `CategoryLearningService` from "memory" to "intelligence" and is the single biggest reduction in friction for the daily loop shipped in v3.2.

2. **Subscription / Recurring-Spend Drift Detection** — `BudgetMLEngine.detectAnomalies` (line 96) operates per-category but misses the highest-value anomaly class: *price creep on recurring charges* (Netflix +$2, gym +$5). Group transactions by normalized merchant string (NLTokenizer + lowercased note prefix), require ≥3 prior occurrences with cadence stddev <20%, flag amount changes >5%. Pure Swift; reuses existing MAD code. **Latency:** O(n log n) on grouped sets, <100ms for 1k tx. **Effort:** 3 days. **Impact:** premium-justifying feature that competitors (YNAB, Copilot) only get via Plaid — BudgetVault gets it from manual logs without violating the privacy wedge.

3. **Apple Intelligence Wrapped Narration (iOS 18.1+, opt-in)** — `MonthlyWrappedView` slide copy is hardcoded ("Top category", "Biggest day"). Use Foundation Models framework (3B on-device LLM, ~free RAM, gated by device support) to generate one personalized sentence per slide from a structured fact JSON. **Model:** Apple's bundled FM, no app size cost. **Latency:** ~2–4s per slide → pre-generate all 5 at sheet-open with a `Task`. **Fallback:** existing static templates if `SystemLanguageModel.default.availability != .available` (covers iPhone 15 and older, iPad pre-M1). **Effort:** 4 days incl. prompt-injection guardrails. **Impact:** keeps the "Data Not Collected" label intact (Apple FM is on-device) and is the only AI feature here a marketing post can credibly call "AI."

## Top 3 Risks / Debt Items

1. **`InsightsEngine` rule explosion (422 LOC, 16 rules)** — single function, no scoring/ranking, no dedup; users see redundant insights ("On pace to overspend" + "Fastest draining category" + "Category >90%"). Refactor to a `[InsightRule]` array with a `score: Double` and top-N selection. Otherwise v3.3 will add rules 17–20 and the noise/signal ratio crosses zero.
2. **`CategoryLearningService` writes to UserDefaults on every save** (line 28) — JSON-encodes the entire mapping dict synchronously in `recordMapping`. Will block main thread once a power user crosses ~2k unique notes. Move to SwiftData entity or batched async writes.
3. **No model versioning / A/B harness** — `BudgetMLEngine`'s thresholds (z=3.0, alpha=0.3, frontRatio=0.5) are magic numbers with no telemetry to validate. The "Data Not Collected" stance precludes server-side tuning, so ship a hidden Settings toggle to log local accuracy of suggestions/forecasts and let TestFlight users opt-in to a local CSV diagnostic export.

## Quick Wins (<1 day each)

- Add `import NaturalLanguage` and replace `note.lowercased()` key with `NLTokenizer.tokens(for:)` joined by space — kills the "Starbucks Coffee #4521" miss without any model change.
- Lower `CategoryLearningService` confidence gate from 0.8 → 0.65 with `total >= 3` (line 38, 43) — current 0.8 is too strict; user must teach the same exact note twice with zero conflicts to ever see a suggestion.
- Cap `BudgetMLEngine.detectAnomalies` output at top-3 per period — current return is unbounded and noisy.
- Pre-compute `gatherExpenses(budget:)` once in `MLInsightsView` and pass into all four ML calls — currently each function re-walks `budget.categories.flatMap` (line 379).
- Add `os_signpost` around `BudgetMLEngine.predictMonthEndSpending` and `forecastCategories` to prove <50ms budget on real devices before adding embeddings.

## Long Bets (>2 weeks but transformative)

- **Bundled CoreML merchant→category seed model** (~2–5MB, trained offline on public US merchant lists). Ships as cold-start prior so first-week users get suggestions before `CategoryLearningService` has data. Personalization via on-device fine-tune is overkill; a static prior + per-user kNN delta is the right architecture for a $14.99 one-time app.
- **Cash-flow forecasting for recurring expenses** (Tier 3 roadmap item) — feasible on-device by combining `RecurringExpenseScheduler` future-occurrence dates with `BudgetMLEngine`'s discretionary-spend regression to project next-30-day balance. Pure arithmetic, no model needed; the hard part is UX, not ML.
- **Foundation Models conversational query** ("how much on coffee last month?") — only viable post iOS 18 deployment-target migration (already deferred). Punt to v3.5.

## What NOT to Do

- **No third-party LLM APIs (OpenAI, Anthropic, Gemini).** Would invalidate the "Data Not Collected" privacy label that is the entire marketing wedge. Non-negotiable.
- **No CoreML model >10MB.** App is currently small; a 50MB transformer for categorization would dominate download size for marginal accuracy over NLEmbedding.
- **No federated learning or differential-privacy server.** Requires a backend, contradicts "data never leaves device."
- **No on-device LLM via llama.cpp / MLX.** 1–4B model = 1–3GB download, breaks App Store size norms, drains battery, and Apple Intelligence already covers the legitimate use case for free.
- **No "AI categorization" marketing claim until Opportunity 1 ships.** Today's exact-match suggester is not AI and calling it that erodes trust.
- **Don't replace `BudgetMLEngine` regression with CoreML.** Statistical methods are correct, fast, explainable, and the deltas wouldn't be perceptible at the user's typical N=30–200 transactions/month. CoreML adds bundle weight without measurable accuracy gain at this sample size.
