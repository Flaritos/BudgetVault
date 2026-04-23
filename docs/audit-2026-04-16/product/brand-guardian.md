# Product: Brand Guardian Findings

## TL;DR
The Vault metaphor is genuinely owned in 3 surfaces (VaultDialMark, navy+neon Vault tab, lock-toggle tab icon) but evaporates the moment you leave them — and there is no written brand guideline anywhere in the repo, so every new screen is a coin flip.

## Top 3 Opportunities (Ranked)

1. **Ship `BRAND.md` as the single source of truth** — `BudgetVaultTheme.swift` is the de-facto brand system (navy `#0F1B33`, electric `#2563EB`, 5 neons, 7 radii, typography ramp), but no document explains *when* to use neon vs. accent vs. semantic, or what the voice rules are. A 1-page `docs/BRAND.md` codifying palette tiers, the lock-only iconography rule, and voice ("on-device", "no bank login", "$14.99 once — never a subscription") makes the next 10 features ship on-brand without an audit. *Effort: 1 day. Impact: compounding.*

2. **Promote VaultDialMark to the master brand mark** — it appears in 13 places (LaunchScreen, Paywall, BiometricLock, Settings, Wrapped, ShareCard, Hero ring overlay) and is the *only* asset Apple cannot ship in iOS 19 "Wallet Budget." But `BrandMark.imageset` is a separate PNG, and `AppIcon` does not visibly use the dial. Re-cut AppIcon + BrandMark from the same SwiftUI dial geometry so the icon on the home screen telegraphs the same shape that opens every screen. *Effort: 2-3 days incl. App Store icon resizes. Impact: defensive moat + recognition.*

3. **Lock-as-status-affordance across the app** — `MainTabView.swift:25` already swaps `lock.fill` → `lock.open.fill` on premium unlock, which is brilliant brand storytelling. Extend the pattern: locked premium rows in Settings, locked Wrapped slides, locked categories beyond the free 6 should all use the same lock glyph + neon-blue unlock animation. Today they use mixed `Image(systemName:)` calls and "Premium" pill labels (`FinanceTabView.swift:259-268`) — visually inconsistent. *Effort: 2 days. Impact: every paywall touchpoint reinforces the metaphor.*

## Top 3 Risks / Debt Items

1. **Voice slippage outside the hero** — DashboardView puts the wedge in a 10pt chip ("On-device · No bank login", `DashboardView.swift:849`), Settings uses "Your data never leaves this device", PaywallView says "never leaves your phone", ShareLink says "private, on-device, and no subscription". Four phrasings of the same promise. Pick one canonical line and replace.
2. **`accentColorOptions` (10 user-pickable hex values, `BudgetVaultTheme.swift:155`) lets users repaint the brand** — Slate, Crimson, Amber chips can override the electric-blue identity that the marketing site, App Store hero shot, and Vault ring all depend on. Acceptable as accessibility, but Wrapped/ShareCard/AppIcon must be locked to brand blue regardless of user accent. _(Superseded 2026-04-22: theme picker retired in v3.3.1; `accentColorOptions` no longer exists.)_
3. **Generic finance UI bleeds through in History, Insights, Add-Transaction, Onboarding chat bubbles** — these read like any SwiftUI Forms app. No vault metaphor, no neon, default SF Pro at default sizes. The Vault tab feels like a different app than the History tab.

## Quick Wins (<1 day each)
- Standardize one privacy line: "On-device. No bank login. Ever." Replace the 4 variants.
- Add a 1-line `// BRAND` comment header to `BudgetVaultTheme.swift` linking to `docs/BRAND.md`.
- Audit the 67 hardcoded `"#XXXXXX"` literals in Views and replace with `BudgetVaultTheme` tokens.
- Replace the "Premium" pill on locked rows with a neon-outlined `lock.fill` chip (matches MainTabView).
- Ensure ShareCard and Wrapped always render in brand navy regardless of `userAccentColor`.

## Long Bets (>2 weeks but transformative)
- **Custom typeface for the wordmark and `heroAmount`** — every competitor uses SF Pro Rounded. A licensed display face (or a hand-drawn wordmark) is uncopyable by Apple.
- **Sound + haptic brand signature** on vault unlock (paywall purchase, biometric unlock, monthly close). Sonic logo = brand asset Apple won't ship.
- **"Unlocked" lifecycle UX** — once premium, every paywall lock animates open once and stays open across app launches. Turns a one-time purchase into a recurring brand moment.

## What NOT to Do
- Don't add a second brand color family (e.g. teal/gold for "pro"). Premium differentiation is already carried by *darkness + neon density* in the Vault tab — adding a color tier would dilute the navy/electric system.
- Don't redesign the AppIcon to chase trends; the dial-mark direction is the moat. Refine, don't replace.
- Don't drop "vault" language for something softer ("safe", "wallet"). The metaphor is the differentiator vs. Copilot/Monarch/YNAB and is what Apple cannot trademark-clone.
- Don't localize the wordmark "BudgetVault" — keep it as a proper noun in DE/ES/FR. Translate the tagline only.
