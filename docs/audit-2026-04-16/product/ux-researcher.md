# Product: UX Researcher Findings

## TL;DR
Onboarding extracts a fully-allocated budget (currency + income + 6 envelopes + biometric toggle) before the user has felt a single moment of value, and recovery from the most common real-world failures (missed days, wrong category, wrong amount) requires 4+ taps each — that gap between front-loaded commitment and back-loaded forgiveness is the v3.3 funnel leak.

## Top 3 Opportunities (Ranked)

1. **Reorder onboarding so value precedes commitment.** `ChatOnboardingView.swift` asks for currency → income (12-key pad) → 6 envelope percentages with stepper math → Face ID toggle before any transaction is logged. That is ~9–14 micro-decisions in the first 60 seconds. The `skipOnboarding()` path (line 871) already produces a working "General" envelope budget — promote that to the default. Ship users to Dashboard with a soft "Set income to unlock daily allowance" prompt and surface envelope tuning later as an inline "Split into categories" affordance. Effort: ~3 days. Impact: largest single funnel lift available pre-paywall.

2. **Make missed-day recovery a first-class daily-loop affordance.** `TransactionEntryView` only exposes the date via a small `DatePicker` pill (line 330) and Dashboard's catch-up card requires `daysSinceLastActive >= 3` (DashboardView.swift:138). The 1–2 day miss — the *modal* user behavior — has no shortcut. Add "Yesterday / 2 days ago" chips above the number pad and a "Mark yesterday as no-spend" action when the app opens after midnight. Effort: ~2 days. Impact: directly preserves week-2 streaks where retention historically collapses.

3. **Tie premium discovery to the felt pain, not a brochure.** PaywallView is invoked from 8 separate views, each with its own private `@State showPaywall` (Budget, Categories, Finance, Recurring, Settings, Insights, etc.) — all open the same generic "Unlock the Full Vault" sheet. The user blocked at "add 7th category" sees Vault Intelligence + Debt Tracker + Wrapped, none of which solved their need. Introduce a `PaywallTrigger` enum so the hero line adapts ("Add unlimited envelopes — $14.99 once") and so the team can reason about which trigger converts without third-party analytics. Effort: 1 day. Impact: meaningful conversion lift; current paywall is identical regardless of intent.

## Top 3 Risks / Debt Items

1. **Three competing "vault" metaphors.** Onboarding now says "Start Budgeting" (line 793) precisely because "Open My Vault" collided with PaywallView's "Unlock the Full Vault." But lock/unlock still signals (a) privacy, (b) the no-spend "close the vault" hero gesture, and (c) the premium tab icon (`MainTabView.swift:25`). New users cannot distinguish a privacy lock from a paywall lock from a streak ritual.

2. **Bottom-of-screen cognitive density on Home.** Adjacent No-Spend pill + Log Expense pill + disabled checkmark state + ring-draw animation + toast (DashboardView.swift:194–264) reads as one ambiguous control bar on first viewport. Consider showing No-Spend only after 6pm or collapsing it into the FAB's long-press menu.

3. **Saved transactions have no inline undo.** After Save in `TransactionEntryView`, the sheet dismisses (line 654). Wrong category requires Home → History → tap row → Edit → Save (5 taps). Add an in-toast "Undo" within the green saved-banner (line 427) — keep the transaction reference for ~6 seconds.

## Quick Wins (<1 day each)

- Promote `welcomeSkipButton` (line 244) visually equal to "Begin Setup"; today the silent majority is shamed into the long path.
- Add "Why we ask" disclosure on the income step — privacy-first apps benefit disproportionately from over-explaining.
- Surface a Wrapped teaser at 50% of the period instead of 80% (DashboardView.swift:118) to seed the share habit before month-end.
- Add a long-press on a category chip in `TransactionEntryView` to "Make default for amount $X" — turns the auto-suggest into a discoverable feature.

## Long Bets (>2 weeks but transformative)

- **7-day guided arc** replacing front-loaded onboarding: one contextual nudge per day ("try logging a coffee," "set one bill") delivered via the Live Activity + LogExpenseControl shipped in v3.2. Duolingo-style; matches the daily-loop brand.
- **Confidence-tagged auto-categorization** — surface "we guessed 3 categories — confirm?" instead of writing silently via `CategoryLearningService` (TransactionEntryView.swift:341). Builds trust into the ML.

## What NOT to Do

- No tutorial overlay on Dashboard — coachmarks on a 5-card hero feel patronizing for a "$14.99 once" brand.
- Don't gate the no-spend button behind onboarding completion — discoverability is its v3.2 hero job.
- Don't A/B test price (BRIEFING constraint).
