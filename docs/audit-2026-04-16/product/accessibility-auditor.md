# Product: Accessibility Auditor Findings

## TL;DR
BudgetVault is the rare iOS app that *tries* (Reduce Motion, ScaledMetric, word-pad labels) — but the dark/neon Wrapped + Vault aesthetic relies on `.white.opacity(0.25)` text and 32–36pt tap targets that fail WCAG AA contrast and Apple's HIG 44pt minimum, locking out low-vision and motor-impaired users from the app's most "premium" surfaces.

## Top 3 Opportunities (Ranked)

1. **Wrapped slides accessibility pass (1.4.3 + 2.5.5)** — `MonthlyWrappedView.swift:300, 302, 337, 357, 392, 414, 470, 502` use `.white.opacity(0.25)–0.5` for tracking/captions on navy. Even .opacity(0.5) white on `#0F1B33` is ~3.8:1, failing AA body text. Critical balance numbers (line 340 `42pt heavy`) hit AAA, but the labels around them fail. Close button at line 241 is 32×32 — fails 2.5.5 Target Size (AAA) and HIG. Effort: 1 day. Impact: Wrapped is the share-worthy moment; making it accessible unlocks deaf/HoH users (no audio narration) and shareable alt text.

2. **Dashboard hero VoiceOver semantics are good — extend the pattern** — `DashboardView.swift:880-881` correctly combines + uses `accessibilityValue` for the daily-allowance ring, and lines 1129-1130 on envelope cards are exemplary. But the `BudgetRingView` (the *actual* spending ring) has no `accessibilityElement(children: .combine)` wrapper around the ZStack — VoiceOver reads each arc layer separately. Effort: 2 hrs. Impact: blind users currently can't get the single most important number (% remaining) in one swipe.

3. **Dynamic Type accessibility5 cliff** — Only `MoveMoneyView:139`, `BudgetView:603/649`, `TransactionEntryView:187`, `TransactionEditView:85` cap at `.accessibility3`. Onboarding (`ChatOnboardingView:387` `min(size, 64)`), Dashboard hero (`@ScaledMetric heroAmountSize: 36`), and all of Wrapped use raw `.font(.system(size: 42))` with no scaling cap *or* relativeTo anchor — at AX5 these collide with safe areas or get truncated. Effort: 1 day to audit + add `.dynamicTypeSize(...DynamicTypeSize.accessibility3)` and convert hardcoded sizes to `@ScaledMetric`.

## Top 3 Risks / Debt Items

1. **Reduce Transparency unsupported anywhere.** Zero matches for `accessibilityReduceTransparency` across the codebase. The hero glass card, FAB shadow, page-dots overlay, and Wrapped gradients all violate Apple's Reduce Transparency setting — users who enable it for vestibular/cognitive reasons get *no* fallback. WCAG 1.4.11 Non-Text Contrast risk.

2. **Category color = sole information channel (1.4.1 Use of Color).** `HistoryView.swift:786` (3pt color bar), `MonthlyWrappedView.swift:451` (category bar fills), `TransactionRowView` amount color (positive=green, expense=primary). Color-blind users (deuteranopia: 5% of males) cannot distinguish income from expense in the row. No icon/pattern fallback.

3. **Onboarding number pad has no accessibilityLabel.** `ChatOnboardingView.swift:422-447` reimplements the pad inline using `\u{232B}` glyph — line 447 labels "Delete" but digits 0-9 fall through to `.accessibilityLabel(key)` which is the literal digit string, not the word ("Two"). This *contradicts* `NumberPadView.swift:89-104` which does it right. VoiceOver users hear "one one one" instead of "one hundred eleven dollars" during the first-run income entry — likely abandonment.

## Quick Wins (<1 day each)
- Bump Wrapped close button (line 241) and pageDots (line 277) to 44×44 minimum.
- Replace `.white.opacity(0.25)` tracking labels with `0.6` (passes AA at 4.6:1).
- Add `accessibilityHidden(true)` to the BudgetRingView arc layers and a single `accessibilityElement` wrapper with combined value.
- Add `accessibilityLabel(for:)` switch to `ChatOnboardingView` onboardingNumberPad — copy from `NumberPadView.swift:89-104`.
- Add SF Symbol (`arrow.up.right` / `arrow.down.left`) next to income vs expense amounts in `TransactionRowView`.
- Wrap haptic-only confirmations (`HapticManager.impact` calls in DashboardView) with a paired `accessibilityNotification(.announcement:)` — currently deaf users get zero feedback on no-spend tap.

## Long Bets (>2 weeks but transformative)
- **Full Reduce Transparency mode**: design a flat-token variant of Vault/Wrapped that swaps gradients for solid `BudgetVaultTheme.cardBackground`. Same brand, accessible.
- **VoiceOver rotor for HistoryView**: custom rotor categories ("Today's transactions", "Reconciled", "Over budget") — would make the privacy-first pitch land hard with the blind community (a meaningful underserved segment for finance apps).
- **Switch Control / AssistiveTouch certification pass**: end-to-end smoke test of all 5 onboarding steps + log-expense flow with Switch Control on. The dial-rotation ceremony (line 815, 864) is likely a dead end for switch users.

## What NOT to Do
- Don't ship a "high contrast theme" toggle as the answer — the *default* needs to pass AA. Toggles fragment QA and most users never find them.
- Don't auto-disable animations for everyone — Reduce Motion is already wired (8 sites). The ringDrawnIn/vaultClosingAnimation whimsy is good UX for the 95%.
- Don't add audio narration to Wrapped — it would force a Microphone/Audio privacy disclosure and dilute the "Data Not Collected" wedge. VoiceOver labels are sufficient.
