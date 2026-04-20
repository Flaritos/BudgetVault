# Product: UI Designer Findings

## TL;DR
The brand voice (navy + neon vault) is genuinely distinctive, but the underlying design system is half-built — `BudgetVaultTheme.swift` defines tokens that views routinely bypass with magic numbers, and the app is still on iOS 17 idioms while iOS 18's Liquid Glass / TabView APIs are reshaping the "premium" bar.

## Top 3 Opportunities (Ranked)

1. **Finish the design-token sweep deferred from M8/M9/M10** — High impact, ~3 days. `BudgetVaultTheme` already centralizes spacing, radii, type, and color, but views still drop magic numbers everywhere: `DashboardView.swift:714` (`ringSize: CGFloat = 100`), `:822` (`size: 11`), `:825` (`size: 12, weight: .bold`), `:1097` (`cornerRadius: 2.5`), `:1365` (`cornerRadius: 10`); `FinanceTabView.swift:234` (`cornerRadius: 10`), `:346` (`size: 10`); `MonthlyWrappedView.swift:340` (`size: 42`), `:404` (`size: 48`). `grep` finds **50 inline `cornerRadius:` literals**, **38 inline `.shadow(...)` calls**, and **72 `.font(.system(size:...))` calls** under `Views/`. Add `Theme.iconChip = 10`, `Theme.heroRing = 100`, `Theme.shadowCard()` view modifier, and a `.bvShadow(.card)` extension; sweep with a single PR. Result: redesigns become hours, not days.

2. **Adopt iOS 18 Liquid Glass + `TabView` minimize behavior on Hero/Vault** — Medium effort (~4 days), large perceived-quality lift. Zero hits for `tabBarMinimizeBehavior`, `glassEffect`, `MeshGradient`, or `TabRole` across the codebase. The Vault tab (`FinanceTabView.swift:103-149`) and Hero glass card (`DashboardView.swift:833-840`, `.fill(.white.opacity(0.07))`) hand-roll glass with hex alphas — exactly what `.glassEffect(.regular, in: .rect(cornerRadius: ...))` and `MeshGradient` were built for in iOS 18. Migrating the Vault tab background to a slow-drifting MeshGradient + true Liquid Glass cards would close the visual gap with Things 4, Mela, and Reeder 5.

3. **Extract a shared `BVCard`, `BVChip`, `BVSectionHeader` component layer** — 2 days. The "white card with `radius 8 y:4` shadow" pattern is duplicated in `DashboardView.swift:1115-1121, 1167-1168, 1219-1220, 1261-1262, 1324-1325`, `HistoryView.swift:430-431`, `PaywallView:222`, `AchievementBadgeView:222`. Same for the all-caps tracked section header (`FinanceTabView.swift:345-348` vs `:394-397` — drift: `neonBlue.opacity(0.6)` vs `.white.opacity(0.35)`). One `BVCard { ... }` wrapper kills ~80 lines of duplication and guarantees future shadow/radius tweaks land everywhere.

## Top 3 Risks / Debt Items

1. **Hero hierarchy is split-brain.** B1 glass card forces the eye to choose between the 100pt neon ring (`DashboardView.swift:714`) and the 36pt daily-allowance number (`:804`). Premium money apps (Copilot, Monarch) put the *number* at 56–72pt and demote the ring to a side-pill. Today the ring wins the F-pattern but the *number* is the actionable insight.
2. **Wrapped slides aren't Story-dimensioned.** `MonthlyWrappedView` renders inside a sheet with `.tabViewStyle(.page)` (line 231) — there's no 9:16 export path, no per-slide `ImageRenderer` like `ShareCardView.swift:53`. Spotify Wrapped's whole virality engine is the 1080×1920 PNG; we ship none.
3. **5 surface tokens collapse to 2 colors.** `surfaceCardPrimary`, `surfaceCardSecondary`, `surfaceCardDark`, `surfaceCardAccent` (`BudgetVaultTheme.swift:137-143`) all alias to two underlying colors — they look like a system but provide no actual differentiation. Either give them real elevation/tint variance or delete the aliases.

## Quick Wins (<1 day each)
- Promote daily allowance to ~56pt; shrink ring to 80pt and move under the number.
- Replace `.font(.system(size: 9-12...))` micro-text with `.caption2`/`.caption` Dynamic Type tokens (currently breaks at XL accessibility sizes).
- Add `Theme.shadowCard` modifier — replaces 14+ duplicated `.shadow(color: .black.opacity(0.06), radius: 8, y: 4)` calls.
- Fix `TabView` icon: `lock.open.fill` (line 25) reads as "unlocked = locked" to non-premium users; use `crown.fill` for premium tab.
- Unify Vault section headers to one `BVEyebrow` component (`FinanceTabView.swift:345, 394` drift today).

## Long Bets (>2 weeks but transformative)
- iOS 18 deployment migration + full Liquid Glass restyle of Hero/Vault/Wrapped (closes the perceived-quality gap with 2026's premium tier).
- Wrapped → 1080×1920 share renderer with per-slide PNG export (drives organic distribution; Spotify's playbook).
- Build a Storybook-style `DesignSystemPreview.swift` view (gated behind a Settings dev toggle) — every component, every state, every Dynamic Type size on one screen. Pays for itself in audit round 2.

## What NOT to Do
- Don't add a third theme (light/dark is enough; custom accent already covers personality).
- Don't chase neumorphism or skeuomorphic vault textures — the flat neon-on-navy is on-brand and ages better.
- Don't introduce a third-party design-token library (Style Dictionary, etc.) — `BudgetVaultTheme.swift` is 180 lines and works; just *use* it.
