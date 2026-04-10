# BudgetVault v3.2 Comprehensive Audit Report

**Date:** 2026-04-10
**Auditors:** 5 specialized agents (Accessibility, UI Design, UX Research, Brand Guardian, Code Review)
**Scope:** Full app — Dashboard, History, Settings, Vault, Transaction Entry, Onboarding, Wrapped

---

## Executive Summary

**Total unique findings: 68** (after deduplication across agents)

| Category | Critical | Major/High | Medium | Minor/Low |
|----------|----------|------------|--------|-----------|
| Accessibility | 5 | 12 | — | 11 |
| UI/Visual Design | 4 | 6 | — | 6 |
| UX/Usability | 3 | 7 | 10 | 7 |
| Brand Consistency | 2 | 3 | 3 | 2 |
| Code Quality | 2 | 4 | — | 6 |

**Top 10 "fix now" issues** (cross-agent consensus, ordered by impact):

| # | Issue | Agents | Severity | Effort |
|---|-------|--------|----------|--------|
| 1 | No-spend button: opaque green blob + undiscoverable | UI, UX, Brand, A11y | Critical | Small |
| 2 | Fixed font sizes bypass Dynamic Type throughout | A11y | Critical | Medium |
| 3 | SafeSave return values silently discarded (~50% of save paths) | Code | Critical | Medium |
| 4 | Streak dots: off-brand amber + zero a11y info | UI, Brand, A11y | Critical | Small |
| 5 | Small tap targets: quick actions, Log button, catch-up dismiss, onboarding steppers | A11y, UX | Critical | Small |
| 6 | Toast/banner not announced to screen readers | A11y | Critical | Small |
| 7 | navyDark text invisible in dark mode (History + Paywall) | UI | High | Tiny |
| 8 | "Set income in Budget tab" — no Budget tab exists | UX | Critical | Tiny |
| 9 | FAB background bar: ineffective 0.5 blur | UI | High | Small |
| 10 | `try? modelContext.save()` bypasses SafeSave in 3 places | Code | Critical | Small |

---

## 1. NO-SPEND BUTTON (the green moon)

**Flagged by:** All 5 agents
**Files:** `DashboardView.swift:208-224, 444-458, 710-730`

### What's wrong

The `moon.zzz.fill` button uses raw `Color.green.opacity(0.85)` as a solid opaque circle — the only place in the app that uses system `Color.green` instead of `BudgetVaultTheme.positive`. It creates a flat green blob that breaks the neon/glass aesthetic. Additionally:

- **No text label** — sleeping moon icon has no finance convention; users don't know what it does
- **Toast not announced** to VoiceOver after tap (a11y violation 4.1.3)
- **Raw Color.green** instead of theme token (brand violation)
- **700ms delay** before toast creates doubt the tap registered

### Recommended fix

```swift
// Replace solid green circle with glass treatment
Image(systemName: todayClosed ? "checkmark" : "moon.zzz.fill")
    .font(.body.weight(.bold))
    .foregroundStyle(todayClosed ? BudgetVaultTheme.positive : .white)
    .frame(width: 48, height: 48)
    .background(
        Circle()
            .fill(BudgetVaultTheme.positive.opacity(todayClosed ? 0.2 : 0.15))
            .overlay(Circle().strokeBorder(BudgetVaultTheme.positive, lineWidth: 1.5))
    )
    .shadow(color: BudgetVaultTheme.positive.opacity(0.4), radius: 8, y: 4)

// Add text label below
Text(todayClosed ? "Closed" : "No Spend")
    .font(.system(size: 9, weight: .medium))
```

Also: replace all `Color.green` with `BudgetVaultTheme.positive` on lines 215-219, 455-456, 722, 727.

---

## 2. ACCESSIBILITY — Fixed Font Sizes

**Flagged by:** Accessibility Auditor
**Files:** `DashboardView.swift`, `HistoryView.swift`, `BudgetVaultTheme.swift`

### What's wrong

The app uses `@ScaledMetric` for layout dimensions (good!) but hardcodes text sizes with `.font(.system(size: N))` throughout. Users with Dynamic Type settings see no change in hero stats, labels, chip names, or theme typography tokens. **ALL 10 `BudgetVaultTheme` typography tokens use fixed sizes.**

### Key locations

- Hero: `size: 36` (amount), `size: 10` (labels), `size: 9` (stats), `size: 8` ("used")
- History summary: `size: 10` (labels), `size: 17` (amounts)
- Category chips: `size: 9` (names)
- Theme tokens: `heroAmount(54)`, `amountEntry(48)`, `wrappedHero(44)` — all fixed

### Fix approach

Convert to `@ScaledMetric` or semantic font styles. For display text needing specific sizes:
```swift
@ScaledMetric(relativeTo: .caption2) private var labelSize: CGFloat = 10
// Or use semantic: .font(.caption2.weight(.bold))
```

---

## 3. CODE — SafeSave Return Values Discarded

**Flagged by:** Code Reviewer
**Severity:** Critical — silently loses user data

### What's wrong

~50% of `SafeSave.save()` call sites ignore the `Bool` return without rollback or error UI. When save fails, dirty objects stay in the model context and are never persisted. Three call sites bypass SafeSave entirely with `try? modelContext.save()`.

### Unprotected save paths

- `HistoryView.swift:569` — duplicate transaction
- `MoveMoneyView.swift:187`
- `BudgetView.swift:475, 609, 687, 725`
- `AddCategoryView.swift:137`
- `DebtDetailView.swift:319, 335, 452`
- `NetWorthView.swift:325, 333, 340, 431`
- `SettingsView.swift:744`

### Raw save bypasses

- `HistoryView.swift:646` — reconcile toggle
- `SettingsView.swift:614` — deleteAllData (dangerous!)
- `SettingsView.swift:744` — applyTemplate

### Fix

Add `guard SafeSave.save(modelContext) else { modelContext.rollback(); return }` to every call site. Replace `try? modelContext.save()` with `SafeSave.save()`.

---

## 4. VISUAL — Off-Brand Amber Streak Dots

**Flagged by:** UI Designer, Brand Guardian, Accessibility Auditor
**File:** `DashboardView.swift:1367, 1386`

### What's wrong

Streak dots use `Color(hex: "#FBBF24")` (amber/yellow) — the only warm accent in the entire app. Also in `FinanceTabView.swift` as `neonYellow`. The dots have **zero accessibility information** — VoiceOver users cannot tell which days are logged, frozen, or empty.

### Fix

Replace amber with `BudgetVaultTheme.positive` (green) for logged days. Add accessibility labels:
```swift
ForEach(0..<7, id: \.self) { i in
    Circle()
        .fill(weekDots[i] == .logged ? BudgetVaultTheme.positive : ...)
        .accessibilityLabel("\(dayNames[i]): \(weekDots[i].description)")
}
```

---

## 5. ACCESSIBILITY — Small Tap Targets

**Flagged by:** Accessibility Auditor, UX Researcher
**Multiple files**

| Element | File:Line | Current Size | Fix |
|---------|-----------|-------------|-----|
| Quick action chips | `DashboardView.swift:1436-1448` | ~20pt tall | Add `.frame(minHeight: 44)` |
| "Log" button (empty today) | `HistoryView.swift:757-767` | ~24pt tall | Add `.frame(minHeight: 44)` |
| Catch-up dismiss X | `DashboardView.swift:1461-1469` | ~16pt | Add `.frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())` |
| Onboarding +/- steppers | `ChatOnboardingView.swift:649-665` | ~17pt | Same |
| Buffer info icon | `DashboardView.swift:910` | 9pt | Increase to 12pt + 44pt tap target |

---

## 6. ACCESSIBILITY — Toast/Banner Announcements

**Flagged by:** Accessibility Auditor
**Files:** `DashboardView.swift:444-480`, `TransactionEntryView.swift:408-441`

No-spend toast, freeze toast, and "Saved!" banner are not announced to VoiceOver. Fix:
```swift
.onChange(of: showNoSpendToast) { _, showing in
    if showing {
        UIAccessibility.post(notification: .announcement,
                           argument: "Today's vault is closed. Streak saved.")
    }
}
```

---

## 7. VISUAL — navyDark Text Invisible in Dark Mode

**Flagged by:** UI Designer
**Files:** `HistoryView.swift:402`, `PaywallView.swift:84`

`BudgetVaultTheme.navyDark` (#0F1B33) is used for text foreground — nearly invisible against dark backgrounds. Replace with `.primary` for automatic light/dark adaptation.

---

## 8. UX — "Budget Tab" Reference Doesn't Exist

**Flagged by:** UX Researcher
**File:** `DashboardView.swift:149-154`

Empty state says "Set your monthly income in the Budget tab" but there is no Budget tab. Tabs are Home/History/Vault/Settings.

Fix: Change copy to "Set your monthly income to get started" with an action button that navigates directly to budget setup.

---

## 9-10. VISUAL + CODE — FAB Blur + SafeSave Bypasses

See sections 1 (FAB) and 3 (SafeSave) above.

---

## Additional High-Priority Findings by Category

### UI/Visual Design

| # | Issue | File | Lines |
|---|-------|------|-------|
| 11 | Envelope fade mask too aggressive (20% hidden) | DashboardView.swift | 994-1004 |
| 12 | Inconsistent card shadows (3 different specs) | Multiple | — |
| 13 | `.borderedProminent` system buttons in EmptyState, CSV, Insights | EmptyStateView.swift:26, etc. | — |
| 14 | Two different transaction row designs (circle vs rounded-rect emoji bg) | TransactionRowView vs HistoryView | — |
| 15 | Paywall gradient mismatch (brandGradient vs 3-stop navy) | PaywallView.swift:194 | — |
| 16 | Hardcoded hex colors in onboarding bypass theme | ChatOnboardingView.swift | 34,217,291+ |

### UX/Usability

| # | Issue | File | Lines |
|---|-------|------|-------|
| 17 | Transaction entry layout exceeds viewport on small phones | TransactionEntryView.swift | 72-136 |
| 18 | Dashboard cognitive overload: 8+ competing sections | DashboardView.swift | 502-658 |
| 19 | Quick amount chips hardcoded USD ($5/$10/$20/$50) | TransactionEntryView.swift | 467-505 |
| 20 | Category auto-selection sparkle icon unexplained | TransactionEntryView.swift | 270-276 |
| 21 | Delete All Data: export failure silently falls through to deletion | SettingsView.swift | 124-150 |
| 22 | History empty state has no "Log" shortcut | HistoryView.swift | 522-539 |
| 23 | Vault tab duplicates paywall instead of previewing features | FinanceTabView.swift | 147-218 |

### Brand Consistency

| # | Issue | File | Lines |
|---|-------|------|-------|
| 24 | Net Worth files still exist despite being "REMOVED" from brand | NetWorthView.swift, AddAccountView.swift | entire files |
| 25 | Dead `competitorRow` function in paywall | PaywallView.swift | 246-257 |
| 26 | Stale $9.99 pricing in all marketing materials | research/*.md, scripts/*.json | — |
| 27 | Raw `.blue` in InsightsView instead of theme token | InsightsView.swift | 563 |
| 28 | Hardcoded neon colors in FinanceTabView bypass theme | FinanceTabView.swift | 20-29 |

### Code Quality

| # | Issue | File | Lines |
|---|-------|------|-------|
| 29 | DashboardView: 30+ @State properties, should consolidate | DashboardView.swift | 8-76 |
| 30 | @Query loads ALL transactions with no predicate | DashboardView.swift:21, HistoryView.swift:11 | — |
| 31 | Duplicated save logic in saveTransaction() vs saveAndAddAnother() | TransactionEntryView.swift | 585-660 |
| 32 | Computed properties re-evaluated on every body pass | HistoryView.swift | 66-72 |
| 33 | DashboardViewModel is empty — should be static enum | DashboardViewModel.swift | — |
| 34 | Magic string AppStorage keys not using AppStorageKeys enum | DashboardView.swift | 56-57 |

### Accessibility (remaining)

| # | Issue | File | Lines |
|---|-------|------|-------|
| 35 | Hero ring conveys status through color alone | DashboardView.swift | 710-730 |
| 36 | Envelope progress bars: color-only spending indicator | DashboardView.swift | 1052-1062 |
| 37 | PaywallView unlockRow items not combined for VoiceOver | PaywallView.swift | 371-382 |
| 38 | History summary card: 6 VoiceOver swipes for 3 stats | HistoryView.swift | 392-436 |
| 39 | Settings accent color circle has no a11y label | SettingsView.swift | 244-246 |
| 40 | Envelope scroll has no VoiceOver scroll hint | DashboardView.swift | 976-1005 |

---

## What's Working Well

All 5 agents noted these strengths:

- **Vault metaphor** is excellent and consistent (lock icons, "vault" language, dial marks)
- **Privacy messaging** is well-placed (hero chip, onboarding, paywall, settings)
- **Premium copy** is cohesive ("Unlock the Full Vault" / "Open the full vault")
- **`@ScaledMetric`** used for layout dimensions (rare for indie apps)
- **`reduceMotion`** respected consistently for animations
- **VoiceOver labels** on most interactive elements (hero, numpad, category chips, transaction rows)
- **SafeSave pattern** is good (just needs consistent usage)
- **View decomposition** is strong — DashboardView body is clean despite 1600+ lines
- **Caching strategy** (cachedFilteredTransactions, cachedInsights) shows performance awareness
- **Architecture rules** are all followed (Int64 cents, @Query in views, half-open dates, no #Unique)

---

## Recommended Fix Order

### Phase 1: Critical fixes (before next release)
1. No-spend button redesign (glass treatment + text label)
2. SafeSave audit (add rollback to all unprotected paths)
3. Replace `try? modelContext.save()` with SafeSave
4. Fix "Budget tab" empty state copy
5. Toast/banner VoiceOver announcements
6. Minimum 44pt tap targets on 5 undersized elements
7. navyDark text -> `.primary` for dark mode

### Phase 2: High-priority polish (next sprint)
8. Streak dots: replace amber with green + add a11y labels
9. Dynamic Type: convert theme typography tokens to scaled metrics
10. `.borderedProminent` -> `PrimaryButtonStyle()` everywhere
11. Onboarding: replace hardcoded hex colors with theme tokens
12. Delete dead code (NetWorthView, competitorRow)
13. Fix delete-all-data export failure fallthrough

### Phase 3: Ongoing improvements
14. Consolidate card shadows to single theme token
15. Unify transaction row designs
16. Scale quick amounts by currency
17. Add scroll hints and combined a11y elements
18. Predicated @Query for transaction loading
