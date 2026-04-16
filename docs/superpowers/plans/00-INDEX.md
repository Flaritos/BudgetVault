# BudgetVault v3.3 — Implementation Plan Index
**Date:** 2026-04-16
**Spec:** `docs/superpowers/specs/2026-04-16-v3.3-wedge-and-foundation-design.md`
**Audit:** `docs/audit-2026-04-16/`

## How to Use This Index

7 plans in execution order. Each plan is self-contained and shippable as its own internal milestone. Execute one plan at a time using either:

- **superpowers:subagent-driven-development** (recommended): fresh subagent per task, two-stage review between tasks
- **superpowers:executing-plans**: inline batch execution with checkpoints

Begin Plan 1, finish, ship to TestFlight, then move to Plan 2. Or chain Plans 1–4 into a single v3.3.0 release before shipping.

## Phase 1 — v3.3.0 "The Wedge" (~4 weeks)

Marketing-led release. Captures the 2026 privacy/AI-fatigue zeitgeist.

| # | Plan | File | Tasks | Effort | Notes |
|---|---|---|---|---|---|
| 01 | **P0 Triage** | `01-p0-triage.md` | 19 | 7 days | Live Activity fix, Privacy manifest, Achievement rewire, code review wins, BudgetVaultShared SPM skeleton. **Shippable alone as v3.2.2 hotfix if needed.** |
| 02 | **Brand Reclaim** | `02-brand-reclaim.md` | 27 | 5.5 days | budgetvault.io static rebuild (Astro), 4 `/vs/` pages with full content, USPTO Class 9 trademark, UDRP complaint template. **Sibling repo at `~/Claude/budgetvault-io/`.** |
| 03 | **Wrapped Viral Loop** | `03-wrapped-viral-loop.md` | 28 | 4.5 days | 1080×1920 share renderer (5 variants), ShareLink auto-present, branded watermark + QR, brag stat rotator, accessibility pass. |
| 04 | **ASO Acquisition** | `04-aso-acquisition.md` | 23 | 8 days | Privacy reposition, App Preview video, 3 Custom Product Pages, IAE for Wrapped, DE metadata localization, Apple Offer Codes referral, smart Review Prompt. |

**Total Phase 1:** 97 tasks, ~25 days. Ship target: late May 2026.

## Phase 2 — v3.3.1 "The Foundation" (~3–5 weeks)

Engineering-led release. Lands the architecture for v3.4 Households tier.

| # | Plan | File | Tasks | Effort | Notes |
|---|---|---|---|---|---|
| 05 | **iOS 18 + Schema + Architecture** | `05-ios18-schema-architecture.md` | 49 | 9.5 days | iOS 18 deployment migration, SchemaV2 with #Index, dynamic @Query refactor across 8 views, BudgetRepository protocol, PremiumGate enum, PaywallTrigger enum, complete Shared SPM. **Largest plan.** |
| 06 | **Apple Intelligence** | `06-apple-intelligence.md` | 25 | 7 days | NLEmbedding kNN category suggestion (<30ms p95), Foundation Models Wrapped narration (binary opt-in), subscription drift detection. |
| 07 | **DevOps + Brand** | `07-devops-and-brand.md` | 38 | 7 days | Fastlane + GitHub Actions self-hosted runner, MetricKit, BRAND.md, BrandStrings sweep, Vault Motion Language, branch protection, CKShare design doc, 8-round audit pass, App Store submission. |

**Total Phase 2:** 112 tasks, ~24 days. Ship target: early July 2026.

## Combined

- **209 bite-sized tasks** across 7 plans
- **~49 days** of focused engineering work (~7–9 weeks calendar with normal life)
- **~12,400 lines** of plan documentation

## Execution Flow Per Plan

Each plan follows this rhythm:
1. Read the plan header to confirm goal + ship target
2. Read the File Structure section to understand scope
3. Use **subagent-driven-development** skill to execute task-by-task
4. After each task: review the diff, run tests, commit
5. After each plan: tag release, run XCUITest smoke, ship to TestFlight if applicable

## Cross-Plan Dependencies

- Plan 01 creates the `BudgetVaultShared` SPM skeleton with 3 types. Plan 05 expands it.
- Plan 03 (`LocalMetricsService`) inspires Plan 06 telemetry patterns.
- Plan 04 (`OfferCodeService`) requires `firstPremiumPurchaseDate` capture in `StoreKitManager` — Plan 04 adds it; Plan 06 reads it.
- Plan 05 (PaywallTrigger enum) is consumed by Plan 04's review prompt re-timing.
- Plan 07 (BrandStrings) consolidates strings written by Plans 01–06.

If executing in parallel branches, sequence: 01 → 02 (independent) || 03 (independent) || 04 → 05 → 06 → 07.

If executing sequentially: 01 → 02 → 03 → 04 → SHIP v3.3.0 → 05 → 06 → 07 → SHIP v3.3.1.

## What Comes After v3.3

Per spec Section 2 "Non-Goals", v3.4 ships:
- CKShare partner sharing implementation
- $24.99 Households non-consumable IAP tier
- Split transactions
- Catch-up mode
- iPad UI layouts
- Foundation laid by Plans 05 + 07 makes v3.4 an additive feature release, not a foundational rebuild.

## Files of Record

```
docs/
├── audit-2026-04-16/                          ← 18-agent audit findings
│   ├── BRIEFING.md
│   ├── SYNTHESIS.md
│   ├── revenue/  (10 files)
│   ├── product/  (9 files)
│   └── engineering/  (7 files)
└── superpowers/
    ├── specs/
    │   └── 2026-04-16-v3.3-wedge-and-foundation-design.md
    └── plans/
        ├── 00-INDEX.md  ← you are here
        ├── PLAN_BRIEF.md  ← agent format brief
        ├── 01-p0-triage.md
        ├── 02-brand-reclaim.md
        ├── 03-wrapped-viral-loop.md
        ├── 04-aso-acquisition.md
        ├── 05-ios18-schema-architecture.md
        ├── 06-apple-intelligence.md
        └── 07-devops-and-brand.md
```
