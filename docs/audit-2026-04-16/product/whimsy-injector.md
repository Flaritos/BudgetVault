# Product: Whimsy Injector Findings

## TL;DR
BudgetVault has the bones of a delightful app (Wrapped, no-spend day, vault ring) but ships flat copy and generic SF Symbol pulses in 11+ empty/loading/end-state moments — every one a missed screenshot.

## Top 3 Opportunities (Ranked)

1. **Vault Ceremony Universe** (1 week, transformative) — The vault metaphor only appears in the hero ring close (DashboardView L78-80) and onboarding dial. Extend to every reward state: brushed-steel dial spin on milestone unlocks, opt-in tumbler-click on month close (caption "Vault sealed."), "combination accepted" flourish on first save. Reuses `VaultDialMark` + `ConfettiView`.

2. **Replace 11 dead empty/end states with character copy** (2 days, high impact) — `EmptyStateView` is a generic SF Symbol + pulse used everywhere. CSVImportView L197-216 says "Import Complete" — should be **"\(n) transactions decrypted and filed. Welcome to the vault."** with a lock-spin. InsightsView L239-244 "Start logging expenses to see insights" is the coldest copy in app. Replace with **"The vault is silent. Drop in a transaction and the AI starts listening."** + skeleton teaser.

3. **Reward Ladder beyond the 12 existing achievements** (1 week, retention) — AchievementService.swift fires a quiet banner. Add: **first $100 saved** ("Your first stack. Heavier than it looks."), **3-day no-spend** = "Triple Lock", **perfectly reconciled week** = "Cleanroom", **anniversary** ("365 days. Vault still standing."), **first sub-budget** ("New tumbler installed."). Each auto-generates a ShareCard with neon ring — designed for Reddit/TikTok.

## Top 3 Risks / Debt Items

1. **Achievement banner is invisible** — DashboardView L58 confirms "newAchievementBanner state removed with overlay banner". Achievements unlock but nobody sees them. Reward loop is broken. Re-add brief vault-dial spin + visible toast in `streakMilestone` flow.

2. **`EmptyStateView`'s `.symbolEffect(.pulse)`** (L17) is the same pulse on every empty state — looks like a loading bug. Replace with state-specific motion (vault-door swing for empty, dial-spin for loading).

3. **Generic loading copy** — "Importing..." (CSVImportView L40) breaks the metaphor. Use **"Cracking the combination..."** / **"Counting cents..."** / **"Decrypting..."**.

## Quick Wins (<1 day each)

- **HistoryView empty** (L522-530): **"Vault is empty. Log your first expense and watch the dial start turning."**
- **Today empty row** (L734-778): rotate by hour — pre-noon "Morning. Vault is quiet so far." / post-6pm "Evening check-in. Anything to log?" / post-10pm "Almost time to seal the day."
- **Recurring empty** (RecurringExpenseListView L33-39): **"No bills on the schedule. Add Netflix, rent, or that gym membership you forgot about."**
- **Search no-results** (HistoryView L163): replace `ContentUnavailableView.search` with **"No matches. Even the vault forgets sometimes."**
- **CSV select-file** (L60-83): vault-door icon + **"Bring your data home. YNAB, Mint, Monarch — all welcome."**
- **No-spend tap** (DashboardView L77): rotate 8 strings ("Vault sealed.", "Zero day banked.", "+1 to discipline.").
- **Reconciled-week toast**: "Books balanced. Auditor would weep."

## Long Bets (>2 weeks but transformative)

- **"After Hours" easter egg**: 7 taps on hero ring during vault-close unlocks a dark-on-dark theme variant with faint ticking-clock loop (visual + caption). The TikTok moment.
- **Annual Vault Report** (December): year-in-review Wrapped variant — top category, longest streak, total saved, "logged X times in Y locations."
- **Personalized cold-open**: first launch each day shows 1-second "vault unlocking" splash with line ("Welcome back. Day 47.") instead of static launch screen.

## What NOT to Do

- **No haptics-only confirmations** — every reward gets visible toast + caption (a11y).
- **No mascot** — dilutes vault metaphor, looks like Duolingo cosplay. The vault *is* the personality.
- **No sound by default** — opt-in in Settings only. Default-on tanks reviews from users in meetings.
- **No streak-shame copy** — antithetical to calm-money positioning. Streak-freeze exists; lean into forgiveness.
- **No XP/levels** — turns budgeting into a slot machine, conflicts with privacy-first brand.
