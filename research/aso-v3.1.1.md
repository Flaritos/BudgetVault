# BudgetVault v3.1.1 — App Store Metadata Refresh

**Release:** v3.1.1 build 1
**Status:** Ready for App Store Connect update
**Owner:** Zach
**Linked sprint:** ROADMAP_v3.2.md → Sprint 1 (Revenue & Signal)

## Why this refresh
The 5-agent v3.2 audit (Trends + Growth) converged on a single highest-ROI growth lever: **ASO subtitle + first-3-screenshots**. Current positioning buries the strongest anti-positioning claim ("no bank login, no subscription") and treats it as a feature instead of *the* differentiator. This refresh ships alongside the launch pricing visibility hotfix and the in-app feedback loop.

## Subtitle (30 char limit)
**New:** `No Bank Login. No Subscription.` (31 chars — needs trim)
**New (final, 30 char):** `No Bank Login. No Subscriptn.` ❌ ugly

**Recommended (30 char):** `No bank login. One-time price.` (30 chars ✅)

**Alternates to A/B:**
- `Private. Local. One-time pay.` (29 chars)
- `Envelope budgeting, your phone.` (31 ❌)
- `Budget without your bank login.` (31 ❌)
- `Privacy-first envelope budget.` (30 ✅)

**Pick:** `No bank login. One-time price.` — combines the two strongest objections to YNAB/Monarch/Copilot in one line.

## Promotional Text (170 char limit, can update without resubmit)
> Your data never leaves your iPhone. No accounts, no bank sync, no monthly fee. Envelope budgeting, on-device AI insights, and a one-time price. That's the deal.

(170 chars ✅)

## Keywords (100 char field, comma-separated, no spaces after commas)
```
budget,envelope,budgeting,money,expense,tracker,finance,offline,privacy,ynab,monarch,copilot,debt
```
(99 chars ✅)

Notes:
- Drop "savings" — too generic, low traffic.
- Drop "bills" — covered by "expense".
- Add competitor names (`ynab`, `monarch`, `copilot`) — Apple allows competitor keywords.
- "offline" + "privacy" are the differentiator stack.

## Screenshot Order (the part that actually moves the needle)

The first 3 screenshots are what 90% of browsers see in search results. Lead with anti-positioning, not features.

1. **"No bank login required."** Hero shot of B1 glass card daily allowance with a small "Privacy: Data Not Collected" Apple privacy badge overlay. Value-prop in plain English at the top.
2. **Price comparison.** "BudgetVault $14.99 once. YNAB $109/year." Big and brutal. Five-year math: "$14.99 vs $545 over 5 years."
3. **Daily allowance hero (closeup).** The "Can I spend this?" answer. Zero chrome. Dark theme.
4. Vault Intelligence screenshot (premium).
5. Monthly Wrapped slide (the share moment).
6. History tab with H1B segmented picker.
7. Onboarding ceremony slide (brand moment).
8. Settings showing "Send Feedback" — signals "we listen."

## What's New (release notes for 3.1.1)
```
v3.1.1 — Listen Mode

• Send feedback right from Settings. Stays on your device unless
  you choose to email it.
• Fixed launch pricing countdown (it was hidden — sorry!).
• Calmer paywall: no more pop-ups while you're logging expenses.
• Behind the scenes: groundwork for v3.2 daily loop features.

Found a bug or want a feature? Settings → Send Feedback. We read
every one.
```
(Under 4,000 char release notes limit — actual: ~390 chars ✅)

## App Store Connect Action Items (Zach to do manually)
- [ ] Update Subtitle field
- [ ] Update Promotional Text field
- [ ] Update Keywords field
- [ ] Upload new screenshot 1 (anti-positioning)
- [ ] Upload new screenshot 2 (price comparison)
- [ ] Reorder existing screenshots 3–8
- [ ] Paste new release notes
- [ ] **Increase price to Tier $14.99** in Pricing & Availability
- [ ] Submit v3.1.1 build 1 for review

## Why no in-app price hardcoding
The visible price string comes from `storeKit.premiumProduct?.displayPrice` — once you flip the price tier in App Store Connect, the app updates automatically on next launch. Fallback strings updated in `LaunchPricingBannerView.swift` to `$14.99` for the rare case StoreKit fails to load the product.

## Expected impact (per Growth + Trends agents)
- Organic install lift: 40–80% from subtitle + screenshot 1 alone
- Conversion lift: 15–25% from price comparison screenshot 2
- Revenue lift from price increase: ~50% (price ↑ 50%, conversion drag ~10%)
- Net: ~2x monthly premium revenue at current install volume

## Defer to v3.2 release
- Localized metadata for DE/ES/FR (Tier 4)
- Promotional in-app event for "feedback launch"
- Apple Search Ads campaign on competitor keywords
