# BudgetVault 14-Agent Audit Fix Plan

**Created:** 2026-03-16
**Scope:** Fix all issues identified by 14 specialized audit agents
**Target:** iOS 17+ SwiftUI + SwiftData app

---

## Phase 0: Foundation — Constants, Keys, Theme Tokens
**Files:** New `AppStorageKeys.swift`, edit `BudgetVaultTheme.swift`, edit `CurrencyFormatter.swift`

### Tasks:
1. **Create `AppStorageKeys.swift`** — Centralize all 18 @AppStorage string keys into a single enum
2. **Add missing typography tokens** to `BudgetVaultTheme`:
   - `amountEntry` (48pt bold rounded), `sectionIcon` (64pt), `sectionTitle` (.title2.bold()), `buttonLabel` (.headline)
3. **Add missing radius tokens**: `radiusXS: 4`, `radiusButton: 14`, `radiusPad: 10`
4. **Add missing spacing tokens**: `spacingPage: 40`, `spacingSection: 32`
5. **Add dark mode color variants** using `Color(.init(dynamicProvider:))` for brand colors
6. **Add animation tokens**: `animationQuick: 0.15`, `animationStandard: 0.3`, `animationSlow: 0.6`
7. **Fix warning gradient contrast** — darken the warning gradient colors for WCAG AA compliance with white text
8. **Add surface/background color tokens** for cards and sections

### Verification:
- `grep -r "cornerRadius: 14" --include="*.swift"` returns 0 (all use `radiusButton`)
- Build succeeds
- Warning gradient passes WCAG AA contrast check (4.5:1 minimum)

---

## Phase 1: Critical Fixes — Crashes, Compliance, Security
**Files:** `BudgetVaultApp.swift`, `BiometricAuthService.swift`, `NotificationService.swift`, `StoreKitManager.swift`, `SettingsPlaceholderView.swift`, `BudgetRingView.swift`, `RecurringExpenseRowView.swift`

### Tasks:
1. **Fix notification delegate deallocation** — Make `notificationDelegate` a `static let` on BudgetVaultApp
2. **Add `@MainActor` to BiometricAuthService** class declaration
3. **Fix notifications scheduled before permission granted** — Sequence permission request, then schedule on grant callback
4. **Add background save** on `.background` scenePhase
5. **Fix BudgetRingView** — Replace raw `.green/.orange/.red` with `BudgetVaultTheme.positive/.caution/.negative`
6. **Fix RecurringExpenseRowView** — Replace raw `Color.red/orange/yellow` with theme semantic colors
7. **Fix `.tint(.blue)` in BudgetPlaceholderView** — Replace with `Color.accentColor`
8. **Add Restore Purchases to Settings** (already done in prior commit — verify still present)
9. **Fix accent color divergence** — MainTabView should use `Color.accentColor` not `BudgetVaultTheme.userAccentColor`

### Verification:
- Build succeeds
- `grep -rn "Color\.red\|Color\.orange\|\.tint(.blue)" --include="*.swift"` in Views/ returns 0
- Notification delegate is `static let`

---

## Phase 2: Architecture — Caching, ViewModel, Helpers
**Files:** New `BudgetSummaryCache.swift`, edit `DashboardViewModel.swift`, new `SharedHelpers.swift`, new `BudgetTemplates.swift`, edit `InsightsEngine.swift`

### Tasks:
1. **Create `BudgetSummaryCache`** — `@Observable` class caching spentCents per category, totalSpent, remaining. Invalidate on transaction insert/update/delete
2. **Populate `DashboardViewModel`** — Move date arithmetic (dayProgressFraction, daysRemainingInPeriod, budgetDayProgress, dailyAllowanceCents, spendingVelocity) from DashboardPlaceholderView
3. **Consolidate duplicated helpers**:
   - Move `formatCentsToString` → `CurrencyFormatter.formatRaw(cents:)`
   - Move `displayAmount` → `CurrencyFormatter.displayAmount(text:)`
   - Move `navigateMonth` → `DateHelpers.navigateMonth(from:year:delta:)`
4. **Extract `BudgetTemplates.swift`** — Single source for Single/Couple/Family/Custom templates, used by both OnboardingView and BudgetTemplateSheetView
5. **Add typed enum wrappers** for string-typed schema fields (goalType, accountType)
6. **Replace magic UserDefaults keys** — Use `AppStorageKeys` enum everywhere
7. **Replace `DispatchQueue.main.asyncAfter`** with `Task.sleep` in ContentView, BudgetPlaceholderView, OnboardingView, PaywallView
8. **Replace `UIApplication.sendAction(resignFirstResponder)`** with `@FocusState` in all views that use it

### Verification:
- `grep -r "formatCentsToString" --include="*.swift"` returns only `CurrencyFormatter.swift`
- `grep -r "DispatchQueue.main.asyncAfter" --include="*.swift"` returns 0
- `grep -r "UIApplication.shared.sendAction" --include="*.swift"` returns 0
- Build succeeds

---

## Phase 3: UX Fixes — Navigation, Empty States, Interactions
**Files:** `DashboardPlaceholderView.swift`, `MoveMoneyView.swift`, `InsightsPlaceholderView.swift`, `BudgetPlaceholderView.swift`, `HistoryPlaceholderView.swift`, `TransactionEntryView.swift`, `TransactionEditView.swift`, `OnboardingView.swift`, `MonthlyWrappedView.swift`, `AchievementBadgeView.swift`

### Tasks:
1. **Fix "No Budget" dead end** — Add "Create Budget" action button that triggers month rollover or re-onboarding
2. **Fix Move Money** — Show remaining (budgeted - spent) instead of budgeted amount, validate against remaining
3. **Reorder Insights tab** — Show free content first, consolidate premium teasers to 1-2 instead of 7
4. **Remove permanent edit mode** on Budget tab — Use toolbar Edit button instead
5. **Fix CSV export** — Use `ShareLink` directly in toolbar, remove intermediate sheet
6. **Add category confirmation** to TransactionEntryView — Show selected category name + remaining above Save
7. **Add percentage editing** to onboarding template page — +/- stepper on each category
8. **Add transaction deletion undo** — Soft-delete with 5-second undo toast before committing
9. **Convert Monthly Wrapped** from ScrollView to paged TabView with reveal animations
10. **Improve achievement unlock** — Add haptic, scale animation, show all unlocked (not just first)
11. **Hide Debt Tracking and Net Worth** entry points in Settings (comment out buttons)

### Verification:
- Build succeeds
- Each flow tested in simulator

---

## Phase 4: Brand & Copy — Privacy, Vault Metaphor, Microcopy
**Files:** `PaywallView.swift`, `DashboardPlaceholderView.swift`, `EmptyStateView.swift`, `SettingsPlaceholderView.swift`, `BiometricLockView.swift`, `TransactionEntryView.swift`

### Tasks:
1. **Add privacy messaging to PaywallView** — "All data stays on your device. Always." below features
2. **Add VaultDialMark to Dashboard** hero card header (small 24px mark)
3. **Add privacy line to Settings About** — "Your data never leaves this device" above Privacy Policy link
4. **Rewrite paywall feature descriptions** — Value-forward instead of terse ("vs 4 free" → "Organize with unlimited categories")
5. **Add vault language to copy**:
   - Purchase success: "Vault Unlocked" instead of "Welcome to Premium!"
   - Settings premium upsell: "Open the full vault" instead of "Unlock all features"
   - Empty states: "Your vault is empty" / "Your vault is ready"
   - Biometric lock: "Authenticate to open your vault"
6. **Differentiate lock icon** — Use `star.fill` or `crown.fill` for premium gating, keep `lock.fill` for security only
7. **Rename "ML Forecast"** to "Smart Forecast" in MLInsightsView

### Verification:
- `grep -rn "Unlock all features\|Welcome to Premium\|ML Forecast" --include="*.swift"` returns 0
- Privacy messaging visible on PaywallView, Settings About, and Dashboard

---

## Phase 5: ML & Insights Fixes
**Files:** `BudgetMLEngine.swift`, `InsightsEngine.swift`

### Tasks:
1. **Fix R-squared confidence** — Compute residuals on daily (non-cumulative) series instead
2. **Remove dead `.decelerating` branch** — Cumulative series slope can't be negative
3. **Fix pattern classification priority bias** — Score all patterns and return highest-confidence
4. **Normalize confidence values** — Put all on 0-1 scale with comparable semantics
5. **Replace hardcoded English category names** — Use category `isHidden` flag and spending variance to detect recurring vs discretionary
6. **Fix zero-fill underestimation** — Use weekly aggregation for sparse categories (< 3 txns/week)
7. **Fix DST bug in InsightsEngine** — Replace `86400 * daysSoFar` with `Calendar.date(byAdding: .day, ...)`
8. **Fix "Best Day to Shop"** — Divide by unique day count, not transaction count
9. **Add minimum transaction guard** to `forecastCategories` — Require 3+ transactions per category

### Verification:
- Build succeeds
- `grep -rn "86400" --include="*.swift"` returns 0 in InsightsEngine
- `grep -rn '"Rent"\|"Housing"\|"Mortgage"' InsightsEngine.swift` returns 0

---

## Phase 6: DevOps & Infrastructure
**Files:** `project.yml`, both `Info.plist` files, `.gitignore`

### Tasks:
1. **Deduplicate version numbers** — Use `$(MARKETING_VERSION)` and `$(CURRENT_PROJECT_VERSION)` in Info.plist files, define only in project.yml build settings
2. **Add `.gitignore` entries** for `*.ipa`, `*.xcarchive`, `*.dSYM`, `*.mobileprovision`
3. **Add widget data deduplication** — Only call `updateWidgetData()` after actual data changes, not on every foreground
4. **Stop widget over-refresh** — Remove `WidgetCenter.shared.reloadAllTimelines()` from every foreground, only call after transaction save and month rollover

### Verification:
- `grep -rn "1.0.2" project.yml` shows version defined only in settings.base
- Build succeeds after changes
- `xcodegen generate` does not break versions

---

## Phase 7: Final Verification
1. Full clean build: `xcodebuild clean build`
2. Run on iPhone 17 Pro simulator
3. Test all flows: onboarding, transaction entry, budget management, insights, settings
4. Verify dark mode appearance
5. Commit and push all changes
