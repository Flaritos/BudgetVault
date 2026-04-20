# Revenue: App Store Optimizer Findings

## TL;DR
The v3.1.1 ASO refresh shipped the right subtitle and screenshots, but BudgetVault still has zero app preview video, zero localized listings, and a price-comparison screenshot that violates Apple's competitor-naming guideline — fixing those three unlocks an estimated 40-60% organic install lift in 4 weeks at near-zero engineering cost.

## Top 3 Opportunities (Ranked)

1. **App Preview Video (15-25s, portrait)** — We ship none. Apps with previews convert 15-30% better, and budget apps gain more than average because the daily-allowance loop is motion-native (number ticks down as you log). Effort: 1 day with Xcode simulator capture + iMovie. Impact: +15-25% conversion on every impression. Single highest-leverage missing asset.

2. **DE/ES/FR metadata-only localization** — Roadmap defers to "Q3" but App Store Connect lets us ship localized title/subtitle/keywords/description/screenshots without a code change or new build. German "Haushaltsbuch" + "Datenschutz" angles are *perfectly* aligned with our privacy wedge — Germany is the highest-paying privacy market on iOS. Effort: 2 days (DeepL + native review). Impact: 2-3x impressions in those markets, which currently produce <5% of revenue.

3. **Custom Product Pages for Reddit/Twitter funnels** — We have organic reach (`research/reddit-launch-posts.md`, 14-day Twitter calendar) but every link goes to the default page. A "YNAB Refugee" CPP (CSV import + price-comparison + envelope screenshots) and a "Privacy-First" CPP (Data Not Collected label hero) would let `marketing-plan.md` channels measure conversion per-channel and lift Reddit→install by ~30%. Effort: 4 hours in App Store Connect. Impact: meaningful attribution + conversion lift on existing traffic.

## Top 3 Risks / Debt Items

1. **Screenshot 2 likely violates Apple guideline 1.2** — `aso-v3.1.1.md` line 49 specifies screenshot 2 as "BudgetVault $14.99 once. **YNAB $109/year**." Naming a competitor in a screenshot (vs. keyword field) has triggered rejections. Reword to "Other budget apps: $109/year. BudgetVault: $14.99 once." with a generic chart — preserves the punch, removes the rejection risk.

2. **Review prompt is event-deaf to the v3.2 daily loop** — `ReviewPromptService.swift` only fires on (a) first under-budget month, (b) 10th transaction, (c) 14-day streak (line 114 of StreakService), (d) MonthlySummary view. v3.2 shipped Live Activity, no-spend day button, reconciliation — none trigger review. The "first 7-day no-spend streak" and "first reconciled month" are peak-satisfaction moments being wasted. Add two triggers; current cap of 3/year/Apple-policy still respected.

3. **Keyword field over-indexes on competitor names, under-indexes on intent** — Current: `budget,envelope,budgeting,money,expense,tracker,finance,offline,privacy,ynab,monarch,copilot,debt` (99 chars). "budgeting" is redundant with "budget" (Apple stems). "money" + "expense" + "tracker" all duplicate subtitle. Recommend swap to: `envelope,offline,private,nosub,onetime,planner,ynab,monarch,copilot,debt,allowance,daily,vault` — picks up "no subscription" (high-intent), "daily allowance" (our v3.0 hero language), and frees stemmed slots.

## Quick Wins (<1 day each)

- Add `requestIfAppropriate()` to no-spend-day button success and to first reconciled-month detection.
- Rotate Promotional Text now (April = tax season): "Your financial data should stay private. No bank login. No subscription." (uses the seasonal frame from `ASO_Audit_BudgetVault.md` line 442).
- Reword screenshot 2 to remove "YNAB" string before next App Store Connect upload.
- Submit to Apple Editorial via App Store Connect — "Data Not Collected" + envelope budgeting + one-time price is a tailor-made "Apps We Love" pitch we've never sent.
- Pin "What's New" line: "$14.99 once. Forever." — most users skim only line 1.

## Long Bets (>2 weeks but transformative)

- Apple Search Ads on `ynab alternative`, `budget no subscription`, `envelope budget app` — `research/apple-search-ads-setup.md` exists; activate it. Budget cap $20/day for 30 days = $600 test, expected CPI <$3 in this niche.
- Full UI localization (not just metadata) for German market — `Haushaltsbuch` is a category Apple features editorially each January.
- A/B test (App Store Connect Product Page Optimization) icon variations — current vault icon vs. envelope-with-lock variant. Need 2k impressions/variant minimum.

## What NOT to Do

- Do not name YNAB/Monarch/Copilot inside screenshot images (rejection risk). Keyword field is fine — that's what `ASO_Audit_BudgetVault.md` line 210 already established.
- Do not lower price to chase rank. The $14.99 once positioning *is* the differentiator. Discounting trains users that premium isn't premium.
- Do not add a soft-ask custom dialog before SKStoreReviewController. Apple HIG explicitly discourages it and recent reviews suggest they're enforcing.
- Do not localize to Japanese yet — full UI translation cost (~$2k) exceeds 12-month projected JP revenue.

---

**Files referenced:**
- `/Users/zachgold/Claude/BudgetVault/research/aso-v3.1.1.md`
- `/Users/zachgold/Claude/BudgetVault/ASO_Audit_BudgetVault.md`
- `/Users/zachgold/Claude/BudgetVault/BudgetVault/Services/ReviewPromptService.swift`
- `/Users/zachgold/Claude/BudgetVault/BudgetVault/Services/StreakService.swift:114`
- `/Users/zachgold/Claude/BudgetVault/research/apple-search-ads-setup.md`
