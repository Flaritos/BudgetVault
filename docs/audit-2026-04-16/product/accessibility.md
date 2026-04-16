# Product: Accessibility Auditor Findings

## TL;DR
Coverage is strong (Reduce Motion, Dynamic Type, combined hero element, no-spend/FAB labels) but V5A Vault + MonthlyWrapped slides ship white-at-25-50% opacity body text on navy that fails WCAG 1.4.3, and several custom controls (Wrapped pager, hero ring, onboarding number pad, Dynamic Island) lack labels to be operable with VoiceOver.

## Top 3 Opportunities (Ranked)
1. **Contrast pass on V5A + Wrapped** — `MonthlyWrappedView.swift:302,337,357,398,626,631`, `DashboardView.swift:800,814,950,954`, `FinanceTabView.swift:396` use `white.opacity(0.25-0.55)` on navy for body copy ("DAILY ALLOWANCE", "per day", "BUFFER", "TOOLS", verdict subtitles). Sub-3:1. Token swap to `0.7` floor for non-decorative text. Half-day, fixes the only category failing objective WCAG.
2. **MonthlyWrapped pager invisible to VoiceOver** — `MonthlyWrappedView.swift:222-232` uses `TabView(.page(indexDisplayMode: .never))` with decorative dots (267-283). No "page X of 5" announcement, no rotor action. Add `.accessibilityValue("Slide \(currentPage+1) of 5")` + `.accessibilityAdjustableAction` + `UIAccessibility.post(.screenChanged, ...)` on page change. Half-day; today the premium retention surface stops at slide 1.
3. **Hero ring breaks at AccessibilityXXL** — `DashboardView.swift:714` hardcodes `ringSize = 100` while amount uses `@ScaledMetric` (line 18). Ring + inner percent text (787-792) don't scale. Combined `.accessibilityValue` (line 881) speaks amount but never `spentPercentLabel` or status "On Track/Watch It/Over Budget" (824-826). Scale ring with `@ScaledMetric(relativeTo: .title)`, extend value string. Low effort, fixes the centerpiece for low-vision + VoiceOver.

## Top 3 Risks / Debt Items
1. **Onboarding pad announces digits, not words** — `ChatOnboardingView.swift:447` falls back to `accessibilityLabel(key)` ("1", "2"), inconsistent with `NumberPadView.swift:89-105` which spells "One", "Two". Two implementations of the same control = drift. Reuse the helper.
2. **Live Activity / Dynamic Island / Control Widget have no a11y labels** — `Services/BudgetLiveActivityService.swift` (zero labels), `BudgetVaultWidget/BudgetVaultControl.swift:11-16` (defaults). Only home-screen widgets labeled (`BudgetVaultWidget.swift:162,248`). Daily-loop VoiceOver users hear raw numbers on the lock screen.
3. **Inconsistent tap affordance in hero stats** — `DashboardView.swift:946-959` BUFFER has 44×44; neighbors at 863-871 look identical but aren't tappable. Either make all stats tappable or visibly demote them.

## Quick Wins (<1 day each)
- Add `.accessibilityHidden(true)` on decorative `VaultDialMark` usage at `FinanceTabView.swift:289` (already done in the Shared file)
- Add `.accessibilityValue` with percent + status to hero combined element (`DashboardView.swift:880`)
- Replace `white.opacity(0.25-0.55)` body text with `0.7` floor across MonthlyWrappedView + FinanceTabView + DashboardView hero
- Add `.accessibilityAddTraits(.isHeader)` to "INTELLIGENCE", "TOOLS", "WHERE IT WENT", "BY THE NUMBERS"
- Add `.accessibilityLabel("Close")` + `.accessibilityHint("Closes recap")` to `MonthlyWrappedView.swift:237` close X
- Replace `accessibilityLabel(key)` at `ChatOnboardingView.swift:447` with the word-mapped helper from `NumberPadView`
- `streakBadgeView` in DashboardView has no a11y label — combine streak count + freeze state
- Add labels to Live Activity compact + expanded states and `LogExpenseControl`

## Long Bets (>2 weeks but transformative)
- **Full VoiceOver rotor + custom actions across Vault + Wrapped**: jump between Insights / Envelopes / Slides without linear swiping. Real differentiator vs YNAB/Copilot.
- **AccessibilityXXL design pass**: every view caps at `.accessibility3` (`BudgetView.swift:603,649`, `MoveMoneyView.swift:139`, `TransactionEntryView.swift:187`). Capping is a punt — re-flow hero, envelope cards, Wrapped slides to actually work at AX5. Required for App Store accessibility nutrition label and EAA (June 2025).
- **Audio Graphs / Charts a11y**: `Views/Insights/CategoryBreakdownChart.swift`, `TrendChartView.swift`, `SpendingHeatmapView.swift` ship Charts with no `.accessibilityChartDescriptor`. Adding makes BudgetVault one of <5 finance apps with sonified data.

## What NOT to Do
- Don't ship a "high contrast" theme toggle — duplicates iOS Increase Contrast / Smart Invert; fix token opacities.
- Don't label every decorative `Image(systemName:)` — paired-with-text icons would double-read. Current selectivity is correct.
- Don't rebuild the Wrapped TabView — fix `.page` via `accessibilityValue` + `screenChanged` posts.
- Don't tighten the `.accessibility3` cap. The cap is a floor — fix is layout, not a smaller clamp.
