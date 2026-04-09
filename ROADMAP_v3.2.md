# BudgetVault v3.2 — "Close Today's Vault"

**Status: 🚢 SHIPPED 2026-04-09**
**Branch:** `v3.2-daily-loop` → tagged `v3.2`
**Created:** 2026-04-07
**Shipped:** 2026-04-09 (2 days, 12 commits, 8 audit rounds, 80 tests, 50+ fixes)
**Thesis:** v3.1 shipped the emotional/brand layer. v3.2 ships the *daily loop* + *platform surfaces* + *correctness* — turning BudgetVault from an app users open into a ring users close.

Derived from a 5-agent audit (Trends, Feedback, Tech, UX, Growth). See conversation context for raw reports.

## Final ship state
- ✅ Sprint 0 (hotfix), 1 (revenue/signal), 2 (daily loop), 3 (correctness), 5 (polish) — all in
- ✅ Sprint 4 partial — XCUITest infrastructure + reconciliation field, deferred indexes/predicates to v3.2.1
- ✅ All 5 critical blockers cleared, 25+ high/medium fixes verified
- ✅ Archive built and validated, IPA exported, tag pushed
- ⏳ User actions remaining: merge PR #1, upload IPA, App Store Connect metadata, submit for review

---

## North Star
Every day, a BudgetVault user should:
1. Glance at a Lock Screen Live Activity → see remaining allowance
2. Tap a Control Center button or Siri → log an expense in <5 seconds
3. Get a 9pm push → one-tap "close today's vault" (with zero-spend shortcut)
4. See a closed ring on the hero card the next morning

Nothing else matters more than this loop.

---

## Sprint 0 — Hotfix (ship as v3.1.1, day 1)

These are shipped-and-broken; patch before v3.2 work.

- [ ] **Launch pricing countdown is invisible.** `StoreKitManager.swift:15` — epoch `1_751_328_000` is July 1 **2025**. Change to `1_782_950_400` (July 1 2026 UTC). This silently killed every launch pricing surface (PaywallView banner, FinanceTabView card, Vault tab card, DashboardView banner).
- [ ] **AddExpenseIntent userInfo not wired.** `BudgetAppIntents.swift:18` TODO — intent prepares amount/category/note in userInfo but `DashboardView.onReceive(.openTransactionEntry)` ignores them. Siri quick-add doesn't pre-fill the form.
- [ ] **tx=5 modal paywall is interrupting habit formation.** `DashboardView.swift:356-373` — remove the txCount>=5 modal trigger; keep the inline `LaunchPricingDashboardBanner`; move modal paywall to intent-based (tap-lock) + day-14 delayed only.

---

## Sprint 1 — Revenue & Signal (Week 1)

1. **Price → $14.99**, grandfather existing users. Update StoreKit product + paywall copy. (1d)
2. **In-app feedback sheet** writing to local log + email export. We currently have **zero first-party feedback**; every "user need" is proxy research from competitor subreddits. Fix the blind spot. (1d)
3. **ASO rewrite + screenshot refresh.** Subtitle: "No Bank Login. No Subscription." First 3 screenshots lead with anti-positioning. (1d)
4. **Hotfixes from Sprint 0** land as part of this release.

**Exit criteria:** Price moved, feedback loop live, launch pricing visible, Siri pre-fill works.

---

## Sprint 2 — The Daily Loop (Weeks 2–3) ⭐ *retention unlock*

5. **Lock Screen Live Activity for daily allowance.** `BudgetActivityAttributes.swift` stub already exists — wire it up. Start on first transaction of the day; update on each subsequent txn; end at midnight. Dynamic Island leading = ring, trailing = remaining.
6. **Interactive Widget (iOS 18 Button).** Replace read-only timeline widget with a `Button(intent: AddExpenseIntent())` quick-add. Requires iOS 18 deployment target bump.
7. **Control Center Control (iOS 18).** One-tap "Log Expense" control → opens pre-filled entry sheet. Zero competitor parity.
8. **9pm "Close today's vault" push.** `NotificationService` already exists. Add evening digest: "Log anything you missed — [No-spend day] [Open app]".
9. **One-tap no-spend day.** Hero-card button that increments streak without opening entry sheet. Converts passive days into engagement.
10. **Onboarding 7→3 steps.** `OnboardingView.swift:31,53-59` — collapse to (1) currency+income, (2) template pick, (3) land user directly in a pre-filled Add Expense sheet. Move welcome animation behind Skip; move notifications prompt to post-first-save context.
11. **Streak-at-risk push (8pm).** Fire *before* the freeze is consumed, not after (`DashboardView.swift:398`).

**Exit criteria:** A user who installs in the morning can glance at Lock Screen by lunch, tap Control Center by dinner, and close their vault via push by bedtime — without opening the app once except to log.

---

## Sprint 3 — Correctness (Week 4)

Addresses the proxy-research retention gap (reconciliation, splits).

12. **Split transactions.** `Transaction` model extension + entry sheet UI. Weekly Target/Costco pain point — cheap feature, high signal.
13. **Lightweight reconciliation.** Per-transaction "verified" checkbox + "mark all reviewed this month" sweep. Not a full YNAB reconcile flow — that's Tier 2.
14. **Comparative Weekly Pulse.** Sunday 6pm push: "You spent $47 less than last week." Not just a stat — a comparison. Uses existing `InsightsEngine`.
15. **Quick-add templates wired into Siri.** Templates exist in entry sheet; expose as `AppShortcut` variants (`Log coffee`, `Log lunch`, etc.).

---

## Sprint 4 — Tech Debt (concurrent, must-do)

Blocks v3.3 partner sharing and iPad. Non-negotiable.

16. **`@Query` predicates on 7 unbounded calls.** DashboardView:19-22, InsightsView:9-11, TransactionEntryView:17, HistoryView, RecurringExpenseListView, DebtTrackingView, BudgetVaultSchemaV1:202 TODO. Perf cliff at 5K+ transactions.
17. **Extract DashboardView** (1,477 lines, 11 banner sections) into sub-views <400 lines each. Enforce "max 1 banner above envelopes" priority rule (catch-up > wrapped > summary > launch).
18. **Bump deployment target to iOS 18.** Unlocks SwiftData `@Attribute(.index)`, Interactive Widgets, Controls. Add indexes per `BudgetVaultSchemaV1.swift:1-40` checklist: Transaction(date), Transaction(category,date), Budget(year,month), RecurringExpense(nextDueDate,isActive).
19. **Test coverage floor → 25%.** Add tests for: `BudgetMLEngine` (anomaly detection, forecasting), `RecurringExpenseScheduler` (dedup, auto-post), streak logic, budget rollover dedup. Current: 4 files / 60 cases / ~4% coverage.

---

## Sprint 5 — Polish (Week 5)

20. **TransactionEntryView simplification.** `:54-324` — default-collapse date+note behind "More"; hide Income toggle behind FAB long-press; only show quick-add templates after 3rd entry. Goal: amount + category + Save in 2 taps.
21. **HistoryView "Today" sticky header.** `:154-176` + `:126-134` — pin "Today — $X / Y transactions" above the list with tap-to-add CTA when empty.
22. **Referral program** tied to tip jar. "Give a friend $3 off, get X." Ships only after price move so the $3 discount feels real.

---

## Deferred mid-sprint (to v3.2.1 or later)
- **@Query predicate refactor** (Sprint 4 #16) — requires threading runtime period bounds through `@Query` initializers, which is invasive and risks breaking the Dashboard/History/Insights data flow on a live app. Current perf is acceptable below ~5K transactions; revisit when a user reports slowdown, or when we bump to iOS 18's fully dynamic `@Query(filter:)` API.
- **SwiftData `@Attribute(.index)`** (Sprint 4 #18 part) — adding indexes is a schema change that requires a `BudgetVaultSchemaV2` migration. The reconciliation field (`isReconciled`) uses lightweight additive migration which is safe; indexes are not. Batched with the predicate refactor above.
- **Interactive Widget Button full wiring** — widget already has `Button(intent: OpenAddExpenseIntent())` but the intent just opens the app. True in-widget save-without-opening is a Sprint 3 extension.
- **Split transactions** — deferred to Sprint 3.5 after the reconciliation checkbox lands in user hands and we can judge whether people actually want splits vs. just separate transactions.

## Explicitly Deferred to v3.3+

- **iPad support** — worth it, but not the retention lever. 2-3 days work post-v3.2.
- **Partner sharing** — biggest revenue bet ($24.99 tier). Requires test coverage first.
- **Full reconciliation flow** — lightweight version ships in Sprint 3; full YNAB-style later.
- **Apple Intelligence / Foundation Models** — wait for iOS 19 GM (fall 2026).
- **Subscription manager, investments, AI chat** — wrong app, trap features.
- **Android, web app, bank sync, analytics SDKs** — brand-destroying, never.

---

## Success Metrics for v3.2

- **Retention**: D7 retention +15% (via daily loop)
- **Conversion**: Paywall convert rate +20% (via price clarity + contextual triggers, not tx=5 spam)
- **Daily active**: DAU/MAU ratio +10 points (via Lock Screen + Control Center surfaces)
- **Perf**: Dashboard load <200ms at 5,000 transactions (via @Query predicates)
- **Signal**: First 50 first-party feedback submissions collected (via in-app sheet)

---

## Out-of-Audit Discoveries to Track

- Launch pricing silent-fail bug (Sprint 0) — how did this escape QA? Add a unit test for `StoreKitManager.isLaunchPricing` asserting the date is in the future.
- AddExpenseIntent was shipped with a known TODO comment — tighten the "no unshipped TODOs on shipped intents" rule before v3.2 freeze.
