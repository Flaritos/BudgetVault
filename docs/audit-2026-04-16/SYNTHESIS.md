# BudgetVault v3.3 — Audit Synthesis & Plan Options
**Date:** 2026-04-16
**Inputs:** 18 specialist agents across Revenue (6) + Product (6) + Engineering (6)

---

## CROSS-CUTTING CONSENSUS (where multiple audits agree)

### 🔴 P0 — Production-Critical (must fix regardless of plan)

| Finding | Source(s) | Why P0 |
|---|---|---|
| **Live Activity is BROKEN in production** — `BudgetLiveActivityService.start()` calls `Activity.request<BudgetActivityAttributes>` but `BudgetVaultWidget.swift:395` `WidgetBundle` contains zero `ActivityConfiguration`. v3.2's marquee feature does not visibly render. | Mobile Platform, Code Review | The Live Activity is the headline feature of v3.2. It silently fails. |
| **`PrivacyInfo.xcprivacy` is incomplete** — missing 3 required-reason API declarations (`CSVExporter` atomic write, `FeedbackService` `utsname()`, Documents writes). Widget extension has **no manifest at all** despite reading App Group UserDefaults. | Security | Risk of App Review rejection invalidating "Data Not Collected" label — the entire wedge. |
| **Brand SERP hijacked by `budgetvault.app` squatter** — A free PWA on the .app TLD is winning every AI citation for "BudgetVault" brand queries. ChatGPT/Claude describe BudgetVault as "free, browser-based" (wrong on both counts). Compounds weekly. | AI Citation x2 | The brand confusion is actively crystallizing in AI training data. Every week we delay it gets harder to reverse. |
| **Achievement system silently broken** — banner removed in audit Round 8, never replaced. Achievements unlock invisibly. `AchievementService` rewards "saving" on day 1 of a budget month against in-progress totals. | Whimsy x2, Code Review | Reward loop broken — users earn things they never see, lowering retention. |
| **Unbounded `@Query` epidemic** — 7–8 views fetch ALL transactions with no predicate. Perf cliff at ~5K rows. Will be amplified by CKShare, split tx, tags. | Code Review, Performance, Database, Architecture (4 audits agree) | Already a known debt, but unanimous: must fix before next major feature lands. |

### 🟢 High-Leverage Strategic Plays (cross-audit consensus)

| Play | Source(s) | Effort | Impact |
|---|---|---|---|
| **Privacy reposition** — Incogni "60% of budget apps share your data" + EPIC v. Rocket Money CFPB complaint baked into App Store screenshot 1, website hero, "vs Rocket Money" page | Trend, Feedback x2, AI Citation | 1 day | Once-a-cycle 2026 zeitgeist window |
| **Wrapped → Viral Loop** — 1080×1920 share renderer, QR code, branded watermark, ShareLink auto-present, share counter | Growth, UI Design, Whimsy x2, Brand | 3–5 days | Only realistic viral loop a privacy-first app can have |
| **Couples / CKShare / $24.99 Households tier** — Monarch's Shared Views is the new gold-standard couples feature. Justifies price tier evolution. | Trend, Investment x2, Feedback | 3–4 wks (+ schema design) | Single highest revenue lever per Investment audit; ARCHITECTURALLY BLOCKED today |
| **Apple Intelligence + Foundation Models** — NLEmbedding for category suggestion (sub-50ms, 0MB cost), Foundation Models for Wrapped narration. First privacy-first app shipping it. | Trend, AI/ML | 1–2 wks | Counter-positions on AI fatigue; iOS 18 prereq |
| **iOS 18 migration + SchemaV2 + #Index + @Query refactor** — Unblocks indexes, dynamic predicates, Apple Intelligence, Foundation Models. Multiple audits gate their best ideas on this. | Database, Performance, Mobile Platform, AI/ML | 1 wk | Foundation for everything else |
| **App Store optimization triple play** — App Preview video (none exists), 3 Custom Product Pages (156% conversion lift), IAE for Wrapped (10–25% impression lift) | ASO x2 | 5 days | Compounds with privacy reposition |
| **Onboarding reorder** — Promote `skipOnboarding()`'s default budget; defer envelope tuning to Day 2 inline | UX, Whimsy | 3 days | Largest single pre-paywall funnel lift available |
| **Reclaim brand SERP** — Static-rendered budgetvault.io with schema, FAQ, 4 `/vs/` pages | AI Citation x2 | 5 days | Only way to fix AI citation gap |

### 🟡 Medium-impact improvements

- **Design token sweep** (UI Design, Brand) — 67 hardcoded hex literals, 50 inline cornerRadius, 38 inline shadows. M8/M9/M10 deferred.
- **Brand voice codification** (Brand x2) — Ship `docs/BRAND.md` + `BrandStrings.swift` registry. 4 different phrasings of "data never leaves device" across the app.
- **PaywallTrigger enum** (UX, Architecture) — 8 separate `showPaywall` states open generic sheet; contextual paywall = conversion lift.
- **Vault Motion Language** (Whimsy x2) — Reuse VaultDialMark + ConfettiView across all reward states.
- **Wrapped + Vault accessibility pass** (Accessibility x2) — white@0.25 opacity body text fails WCAG. Wrapped pager invisible to VoiceOver.
- **CI/CD + MetricKit** (DevOps) — Zero automation today. Fastlane + GitHub Actions on self-hosted Mac. MetricKit for crash reporting (privacy-safe).
- **iPad support** (Mobile Platform, Investment) — Project.yml one-line + NavigationSplitView. CloudKit already wired.
- **Smart Review Prompt re-timing** (Growth, ASO) — Move to Wrapped completion + first reconciled month + 30-day streak. Apple caps at 3/year.
- **Apple Offer Codes referral** (Growth) — Only privacy-clean referral mechanic. 3 free codes per premium buyer.

### 🔵 Long bets

- **Shared SPM Package** (Architecture) — `BudgetVaultShared` unblocks Watch, prevents codec drift.
- **PremiumGate enum** (Architecture) — Centralize 16-file premium-tier matrix.
- **BudgetRepository protocol** (Architecture) — Test seam, iPad split-view enabler, CKShare prep.
- **Apple Watch quick-add** (Mobile Platform, Investment) — No Watch target today. Quick-add complication preserves streaks.
- **DE localization metadata-only** (ASO, Investment) — Haushaltsbuch keyword arbitrage. Privacy resonates in EU.
- **Vault Stories** (Growth) — Weekly mini-Wrapped = 52× viral surface vs annual.

### Constraints reaffirmed (multi-audit)

❌ No subscription • ❌ No bank sync • ❌ No Android • ❌ No web app • ❌ No third-party analytics • ❌ No cloud LLM APIs • ❌ No Sentry/Bugsnag • ❌ No price drop • ❌ No mascot • ❌ No XP/levels

---

## THREE STRATEGIC OPTIONS

### Option A — "FORTRESS" (6–8 weeks)
**Theme:** Fix what's broken, harden the architecture, prepare for everything.

**Scope:**
- Live Activity production fix (P0)
- Privacy manifest completion (P0)
- Achievement system re-wire (P0)
- Brand SERP reclaim (P0)
- iOS 18 deployment migration
- SchemaV2 + #Index + dynamic @Query refactor across 7 views
- BudgetRepository protocol + Shared SPM package
- PremiumGate enum
- CI/CD pipeline (Fastlane + GitHub Actions self-hosted) + MetricKit
- Branch protection + cleanup of 17 stale worktree branches
- BRAND.md + design token sweep
- Wrapped + Vault accessibility pass

**Pros:** Every future feature ships 2× faster after this. Eliminates founder-bus-factor risk for acquisition. Removes the perf cliff before user counts grow.
**Cons:** Few user-visible wins. Feels like "v3.2.5" not v3.3. No acquisition lift.

---

### Option B — "THE WEDGE" (5–7 weeks)
**Theme:** Ride the 2026 zeitgeist (privacy backlash + AI fatigue) for maximum acquisition.

**Scope:**
- Live Activity production fix (P0)
- Privacy manifest completion (P0)
- Achievement system re-wire (P0)
- iOS 18 deployment migration (prereq for Apple Intelligence)
- Privacy reposition: App Store + website + "vs Rocket Money" page (Incogni stat)
- Reclaim brand SERP: budgetvault.io static render + schema + FAQ + 4 `/vs/` pages
- Wrapped → viral loop: 1080×1920 renderer + QR + watermark + ShareLink
- Apple Intelligence integration: NLEmbedding category suggestion + Foundation Models Wrapped narration
- ASO triple play: Preview video + 3 CPPs + IAE for Wrapped + DE localization metadata
- Apple Offer Codes referral mechanic
- Smart Review Prompt re-timing
- Vault Motion Language + 11 empty-state rewrites + brand voice codification

**Pros:** Maximum 2026 zeitgeist alignment. Biggest acquisition lift. "AI without sending data" is a genuine differentiator. Wrapped becomes a content engine.
**Cons:** Architecture debt persists. CI/CD, BudgetRepository, CKShare prep all deferred to v3.4+.

---

### Option C — "HOUSEHOLDS" (8–10 weeks)
**Theme:** Ship the $24.99 Households tier — single highest revenue lever in the entire audit.

**Scope:**
- Live Activity production fix (P0)
- Privacy manifest completion (P0)
- Achievement system re-wire (P0)
- iOS 18 deployment migration (prereq)
- SchemaV2 with sharing-root model + zone partitioning (CKShare prep)
- BudgetRepository protocol + Shared SPM (architecture for sharing)
- @Query predicate refactor + #Index
- CKShare partner sharing implementation
- $24.99 Households non-consumable IAP tier + PremiumGate enum
- Onboarding reorder (value-before-commitment) + catch-up mode + missed-day chips
- Split transactions (YNAB parity dealbreaker)
- Reconciliation peak-moment review prompts
- iPad support (NavigationSplitView) — CloudKit already wired
- BRAND.md + voice codification for shared-budget UX

**Pros:** Highest direct revenue impact. Defensive parity vs Monarch. Justifies price tier evolution to $24.99. Unlocks the 40–60% couples segment.
**Cons:** Longest timeline. Schema migration risk highest. Misses the 2026 zeitgeist window. AI Intelligence + ASO viral plays deferred.

---

## RECOMMENDED — Option D — "WEDGE + FOUNDATION" (two-phase, 7–9 weeks total)

**Theme:** Ship the zeitgeist plays NOW (4 weeks); land the foundation for v3.4 Households (3–5 weeks).

### Phase 1 (Sprint 1–4, ~4 weeks): The Wedge
1. **Week 1 — P0 Triage**
   - Fix Live Activity production rendering (1 wk)
   - Complete PrivacyInfo.xcprivacy for app + widget (1 day)
   - Re-wire achievement banner with Vault dial spin (1 day)
   - Strip release `print()` from StoreKitManager, fix StreakService freeze logic (0.5 day)
   - Promote `BudgetVaultShared` SPM package (skeleton only, 1 day)
2. **Week 2 — Brand Reclaim**
   - Static-render budgetvault.io with SoftwareApplication + FAQ + Organization schema (3 days)
   - Ship 4 `/vs/` comparison pages (`/vs/ynab`, `/vs/copilot-money`, `/vs/monarch`, `/vs/goodbudget`) (2 days)
   - Resolve `budgetvault.app` squatter situation (whois + UDRP / 301 strategy) (0.5 day)
3. **Week 3 — Wrapped Viral Loop**
   - 1080×1920 `MonthlyWrappedShareCard` ImageRenderer (2 days)
   - Branded watermark + QR to App Store + ShareLink auto-present on slide 5 (1 day)
   - Local share-counter via FeedbackService pattern (0.5 day)
   - Wrapped accessibility pass (contrast + tap targets + VoiceOver pager) (1 day)
4. **Week 4 — ASO Acquisition Push**
   - Privacy reposition: App Store screenshot 1 + website hero + "vs Rocket Money" page (Incogni stat) (1 day)
   - 25-second App Preview video (2 days)
   - 3 Custom Product Pages: `/ynab-refugee`, `/privacy`, `/wrapped` (1 day)
   - In-App Event for May Wrapped (1 day)
   - DE localization metadata-only via App Store Connect (1 day)
   - Apple Offer Codes referral row in Settings (1 day)
   - Smart Review Prompt re-timing (1 day)

**Ship as v3.3.0** — "The Wedge" — ~4 weeks. Marketing window: late May 2026.

### Phase 2 (Sprint 5–8, ~3–5 weeks): The Foundation (set up for v3.4)
5. **Week 5–6 — iOS 18 + Schema + Architecture**
   - iOS 18 deployment target migration (1 day)
   - SchemaV2 with `#Index` annotations (1 day)
   - Dynamic `@Query(filter:)` predicate refactor across 7 views (2 days)
   - `BudgetRepository` protocol + period-scoped ViewModels (3 days)
   - `PremiumGate` enum centralization (1 day)
   - `BudgetActivityAttributes` + `WidgetData` move to Shared SPM (1 day)
6. **Week 7 — Apple Intelligence**
   - NLEmbedding-based category suggestion in `CategoryLearningService` (2 days)
   - Foundation Models Wrapped narration (opt-in, with static fallback) (3 days)
   - Subscription drift detection in `BudgetMLEngine` (2 days, if time)
7. **Week 8 — DevOps + Brand**
   - Fastlane + GitHub Actions self-hosted runner (2 days)
   - MetricKit integration (0.5 day)
   - BRAND.md + `BrandStrings.swift` registry + Vault voice sweep (2 days)
   - Vault Motion Language: `VaultCelebration` modifier + 11 empty-state rewrites (2 days)
   - Branch protection + worktree cleanup (0.5 day)
8. **Week 9 — Buffer**
   - CKShare schema design doc (sharing-root model + zone partitioning plan)
   - 8 audit-pass rounds (per v3.2 playbook)
   - TestFlight + App Store submission

**Ship as v3.3.1** — "The Foundation" — ~3–5 weeks after v3.3.0. Marketing window: early July 2026.

### v3.4 (Q3 2026, ~6–8 weeks) — "Households"
With Foundation in place, ship CKShare partner sharing, $24.99 tier, iPad split view, split transactions, catch-up mode. Now an additive feature release, not a foundational rebuild.

---

## DEFAULT IF YOU SAY "GO"
Option D, two-phase. Hits zeitgeist window AND lands the architecture for the bigger v3.4 revenue bet without trying to do both at once.
