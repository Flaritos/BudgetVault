# BudgetVault v3.2.1 → v3.3 Strategic Audit Briefing
**Date:** 2026-04-16
**Goal:** Identify highest-leverage moves across Revenue, Product, and Engineering for the next major release.

## Project Snapshot

- **App:** BudgetVault — privacy-first iOS budgeting app
- **Live version:** v3.0 build 8 (App Store), v3.2.1 in submission
- **Repo:** `/Users/zachgold/Claude/BudgetVault` (private GitHub: Flaritos/BudgetVault)
- **Stack:** SwiftUI, SwiftData, iOS 17+, MVVM, Int64 cents for money
- **Files:** 82 Swift files
- **Bundle:** `io.budgetvault.app`, website budgetvault.io
- **Pricing:** Free + $14.99 one-time IAP (non-consumable premium, consumable tip)
- **Privacy label:** "Data Not Collected" — this is the marketing wedge
- **Architecture:** xcodegen, VersionedSchema, on-device AI insights

## What Shipped in v3.2 (2026-04-09)

- Daily loop: Live Activity (BudgetLiveActivityService), iOS 18 LogExpenseControl, scheduled evening close-vault notification, no-spend day button
- Reconciliation: `Transaction.isReconciled` + swipe action, comparative Weekly Pulse copy
- In-app FeedbackService (local-only feedback log)
- Quick-add MRU chips
- HistoryView Today sticky row
- Onboarding collapse 7→5 steps
- 80 tests passing, XCUITest infrastructure (AuditFixesUITests + DeepSmokeUITest with 45 screenshots + FullSmokeUITest)

## What's Deferred to v3.2.1 / v3.3

- @Query predicate refactor (currently unbounded fetches in views)
- SwiftData @Attribute(.index) for performance
- Full design-token sweep (M8/M9/M10 audit items)
- Split transactions (YNAB parity gap)
- iPad support
- Catch-up mode (3+ day absence flow)
- Partner sharing (CKShare) — would justify $24.99 price tier
- Apple Watch quick-add
- iOS 18 deployment target migration
- Localization (DE, ES, FR)
- CI/CD (GitHub Actions + Fastlane)
- Test coverage to 60%

## Hard Constraints (DO NOT propose)

- ❌ Subscription pricing (the marketing wedge is "$14.99 once")
- ❌ Android version (conflicts with Apple-privacy brand)
- ❌ Web app (server-side violates "data never leaves device")
- ❌ Bank sync via Plaid/Yodlee (Plaid complaints are why users leave YNAB/Monarch)
- ❌ Third-party analytics SDKs (would invalidate "Data Not Collected" privacy label)
- ❌ Lower price than $14.99

## Key Files for Audit

- `BudgetVault/` — app source
  - `Schema/` — SwiftData models
  - `Models/` — domain types
  - `ViewModels/` — @Observable VMs
  - `Views/{Dashboard,Budget,Transactions,Insights,Onboarding,Settings,Finance,RecurringExpenses,Shared}/`
  - `Services/` — including `StoreKitManager`, `BudgetLiveActivityService`, `FeedbackService`, `UITestSeedService`
  - `AppIntents/` — App Intents for Siri/Shortcuts
  - `Utilities/`
- `BudgetVaultWidget/` — widget extension
- `BudgetVaultTests/`, `BudgetVaultUITests/`
- `01_BudgetVault_Spec.md` — original product spec
- `ROADMAP_v3.1.md`, `ROADMAP_v3.2.md` — prior roadmaps
- `research/` — marketing, ASO, competitive analysis

## Output Format for Your Findings

Write to `docs/audit-2026-04-16/<dimension>/<your-agent-name>.md` with this structure:

```md
# <Dimension>: <Your Agent Role> Findings

## TL;DR
One sentence. The single most important thing you found.

## Top 3 Opportunities (Ranked)
1. **<Name>** — <why it matters, est effort, est impact>
2. ...
3. ...

## Top 3 Risks / Debt Items
1. ...
2. ...
3. ...

## Quick Wins (<1 day each)
- Bullet list

## Long Bets (>2 weeks but transformative)
- Bullet list

## What NOT to Do
- Things you considered but rejected, with reasoning
```

**Word budget: 600 words max per file.** Be specific, cite line numbers where relevant, no fluff.
