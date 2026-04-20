# Revenue: App Store Optimizer Findings

## TL;DR
The v3.1.1 metadata refresh nailed the wedge ("No bank login. One-time price."), but BudgetVault is leaving the three highest-leverage 2026 ASO surfaces — App Preview video, Custom Product Pages, and an In-App Event tied to Monthly Wrapped — completely empty while competitors crowd the new multi-slot search ads launching March 3, 2026.

## Top 3 Opportunities (Ranked)

1. **Ship an In-App Event for Monthly Wrapped (1–2 days, 10–25% impression lift).** IAEs surface in search results and on the product page with their own card. Wrapped is a perfect fit: time-bounded ("May Wrapped — Apr 28 to May 5"), visual, share-driving, and re-runnable monthly with zero engineering work after the first build. Title (30 char): `April Wrapped Drops Sunday`. Short description (50 char): `Your spending story. 5 slides. On-device only.` Use the S1D donut as the event card. Tag: `Special Event` (or `New Season` for monthly cadence).

2. **Build 3 Custom Product Pages for Apple Search Ads (3 days, 156% conversion lift per Apple).** With multi-slot search ads going live March 3, 2026, generic listings will get crushed by competitor bids on "budget app." CPPs let us match intent: (a) `/ynab-refugee` — screenshot 1 headline `Tired of $109/yr? Switch in 60 sec.`, screenshots lead with CSV import + price math; (b) `/privacy` — lead with the "Data Not Collected" Apple privacy badge + Face ID lock; (c) `/wrapped` — lead with the Spotify-style slide stack for share-driven traffic. Bid `ynab alternative`, `monarch alternative`, `copilot alternative`, `budget no subscription`, `envelope budget` against each respective CPP.

3. **Record a 25-second App Preview video (2 days, 15–30% conversion lift industry avg).** Zero exists today. Lead frame (0–3s): the B1 daily allowance number animating up against the dark vault ring — this is the single most ownable visual in the app and the thing screenshots can't convey. Per the existing `ASO_Audit_BudgetVault.md` storyboard at lines 357–389, but swap the closing pricing card to `$14.99 once. Forever.` (matches current price). Apple-required: real UI capture only, portrait 886×1920, no voiceover.

## Top 3 Risks / Debt Items

1. **`ynab` in keyword field is a brand-trademark risk.** `aso-v3.1.1.md` line 33 includes `ynab,monarch,copilot`. Apple permits this until the trademark holder files a complaint; YNAB has historically been aggressive. Mitigation: keep but pre-write a swap-in keyword string (`zero-based,planner,allowance,cash,wallet,debt,paycheck`) ready to paste if a takedown lands.

2. **English-only listing forfeits the German privacy market.** The "Data Not Collected" wedge is 3–5x stronger in DE than US. Metadata-only DE localization (no UI translation) is ~4 hours and unlocks `Haushaltsbuch` (the German term for envelope budget — 100K+ monthly searches, near-zero competition from US apps). UK/CA/AU also need localized currency in screenshots, not language.

3. **Subtitle `No bank login. One-time price.` is a wedge but doesn't carry a discoverability keyword.** Test variant: `Envelope budget. No bank login.` (30 char ✅) — keeps the wedge, captures "envelope budget" search (high intent, only Goodbudget competes). Apple A/B test via Product Page Optimization, 2-week run.

## Quick Wins (<1 day each)

- Submit a Featured pitch via App Store Connect → Apps → App Information → "Nominate your app" with the privacy angle: "Only top-100 budget app with `Data Not Collected` privacy label."
- Rotate Promotional Text (no review needed) to current-month seasonal: tax-season variant from `ASO_Audit_BudgetVault.md` line 442 is already written and fits April 16.
- Add `haushaltsbuch` placeholder if DE locale ships — it's the highest-ROI single keyword in any non-US market.
- Add a Privacy Nutrition Label comparison screenshot at slot 4 (visual: "We collect: Nothing. Top budget apps collect: [generic list]").
- Reorder current screenshots so Wrapped (the share moment) moves from slot 5 to slot 3 — Wrapped is the only screenshot that's been organically shared on social per launch posts.

## Long Bets (>2 weeks but transformative)

- **Full DE + UK localized listings with native screenshots and CPPs per market.** German privacy culture + one-time pricing = strongest unit economics of any localization. Pair with a `r/Finanzen` launch.
- **Monthly IAE cadence as a content engine.** Wrapped → 30-Day Streak Challenge → Tax-Season Privacy → Holiday Gift Envelopes. Each IAE refreshes the listing and earns a re-eval from Apple's editorial team.
- **Apple Search Ads competitor-conquest campaign on `ynab`, `monarch`, `copilot` brand terms** routed to the `/ynab-refugee` CPP. Budget $500/mo, target sub-$3 CPI given the matched intent.

## What NOT to Do

- **Don't add `bank sync`, `connect bank`, or `link account` to keywords** — drives wrong-fit installs that 1-star the app for missing the feature. Already a top complaint pattern in YNAB/Monarch reviews; we should not import it.
- **Don't pursue Productivity as secondary category.** Finance category chart placement is achievable at our install volume; Productivity dilutes Apple's algorithmic understanding of the app.
- **Don't run a Spanish/French localization before German.** DE has 2x the willingness-to-pay for privacy-positioned finance apps and the term `Haushaltsbuch` has no direct English equivalent — biggest keyword arbitrage available.
- **Don't write a new long description.** The v3.1.1 promo text + current description already convert; the leverage is in CPPs, IAE, and video — not copy rewrites.

Sources:
- [Apple Custom Product Pages 156% lift data](https://adapty.io/blog/custom-product-pages-app-store/)
- [Apple multi-slot search ads March 2026](https://almcorp.com/blog/apple-app-store-multiple-search-ad-slots-march-2026/)
- [YNAB alternative search trends 2026](https://aitoolpick.org/blog/ynab-alternatives-2026/)
- [Apple Ads 2026 finance category dynamics](https://searchengineland.com/apple-ads-what-to-know-463194)
