# Brand: Brand Guardian Findings

## TL;DR
The vault metaphor is the strongest brand asset BudgetVault owns, but it's applied inconsistently — paywall and onboarding lean into it hard, while widgets, notifications, and Wrapped revert to generic finance-app voice ("Good Morning!", "Fresh Start!", "Weekly Summary"), diluting the differentiator that actually justifies $14.99.

## Top 3 Opportunities (Ranked)
1. **Codify "Vault Voice" as a writing system, then sweep all surfaces** — Voice rules ("calm, private, premium; no exclamation marks; no time-pressure; vault verbs over generic finance verbs") + a single `BrandStrings.swift` registry. ~3 days. Cleans up ~40 inconsistent strings across notifications, widgets, paywall, onboarding. Impact: every surface starts compounding the differentiator.
2. **Promote Vault Intelligence and Monthly Wrapped as named sub-brands** — Both are premium-only signature features but receive zero brand chrome outside the paywall. Give Vault Intelligence a fixed lockup (icon + wordmark + tagline "On-device. Always.") used in InsightsView, share cards, and ASO screenshot 4. Give Wrapped a stable visual signature (vault-door reveal already mocked in `wrapped-mockups.html` slide 1) used as the share-out image. ~1 week. Generates organic growth from shared Wrapped cards (Spotify-style share loop).
3. **Resolve the iCloud privacy contradiction copy** — `SettingsView.swift:523` says `"Data stays on Apple's servers only. No third-party servers."` while `SettingsView.swift:563` says `"Your data never leaves this device."` These are mutually exclusive when sync is on. Single rewrite: "Synced via your private iCloud. Apple-encrypted, never touches our servers." Half-day. Removes the only place the brand contradicts itself.

## Top 3 Risks / Debt Items
1. **Notification voice is off-brand** — `NotificationService.swift:32-40` daily messages ("Don't forget to log today's expenses!", "Keep your streak alive!", "Quick check: anything to log?") are Duolingo-tone with exclamation marks. Compare to the on-brand `closeVault` line (L124): `"Close today's vault"` / `"Log anything you missed — or tap 'No spending today.'"` That's the voice. Also `"Good Morning!"` (L309), `"Fresh Start!"` (L359), `"3 Days Left"` (L345) — all generic. Every push notification is a brand touchpoint with 100% open visibility.
2. **"Vault Unlocked!" + exclamation pattern** — `PaywallView.swift:302` (`"Vault Unlocked!"`), `:323` (`"Welcome to the Full Vault!"`) and the welcome view break the calm-premium positioning the rest of the paywall establishes ("Once. Yours forever." L85 is perfect). A premium one-time-purchase brand shouldn't shout. Strip exclamation marks from all premium-confirmation copy.
3. **Widget brand chrome is afterthought** — `BudgetVaultWidget.swift:153,242,303` uses `vault.fill` SF Symbol at 8pt opacity 0.5 as a "watermark." That's hiding the brand on the highest-frequency surface (home screen). The accessory rectangular widget says "BudgetVault" (L306) which is right; small/medium should too. Also widget display names "Budget Remaining" / "Budget Overview" / "Budget at a Glance" (L341, 354, 387) drop the brand entirely — should be "Vault Remaining" / "Vault Overview" / etc.

## Quick Wins (<1 day each)
- Rewrite the 7 daily-reminder messages in vault voice (no exclamation marks, vault verbs).
- Replace `"Good Morning!"` / `"Fresh Start!"` / `"Weekly Summary"` titles with `"Today's vault"` / `"New month, new vault"` / `"Weekly Pulse"` (Weekly Pulse already used at L182 — standardize).
- `SettingsView.swift:177`: `"Open the full vault"` is good — propagate that exact phrase to paywall hero instead of `"Unlock the Full Vault"` (mixed metaphor: open vs. unlock).
- Pick one: "envelope" (used in PaywallView L50, ASO docs) or "category" (used everywhere else). Currently both. The brand asset is "envelope" — it's the YNAB-refugee search term.
- Reengagement copy at `NotificationService.swift:252,263,274,284` — replace "BudgetVault" generic title with vault-themed lines ("Your vault is quiet" / "The vault has been waiting").

## Long Bets (>2 weeks but transformative)
- **Brand identity guidelines doc** committed to repo (`docs/brand/`) covering voice rules, color tokens, vault-metaphor lexicon, "do/don't" examples, and the Vault Intelligence + Wrapped sub-brand lockups. Required reading before shipping any new copy or surface.
- **Wrapped-as-acquisition-channel** — design Wrapped slides as share-optimized 9:16 with watermarked vault ring + "Made with BudgetVault" lockup; this is the only realistic viral loop a privacy-first app can have (no referrals, no social graph).

## What NOT to Do
- Don't rebrand. The vault metaphor + "data never leaves device" + neon-on-dark is working. The problem is application discipline, not concept.
- Don't add a second brand color. `BudgetVaultTheme.electricBlue` + navy + neon orange (streak) is already at the limit; adding more dilutes the premium feel.
- Don't name-and-shame competitors in copy — `PaywallView.swift:76-79` correctly removed the YNAB/Monarch shamefile. Keep it removed; ASO keywords are fine, on-screen comparison is not on-brand.
