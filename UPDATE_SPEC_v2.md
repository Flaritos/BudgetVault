# BudgetVault v2.0 Update Spec

**Created:** 2026-03-18
**Source:** 6-agent comprehensive audit (UX, Architecture, Growth, UI Design, Feature Inventory, Platform Capabilities)
**Total audit investment:** ~600K tokens of deep codebase analysis across 66 Swift files

---

## Executive Summary

BudgetVault v1.0.2 shipped a solid MVP with 50+ features. This spec defines the roadmap to v2.0 based on a full-stack audit covering UX, architecture, monetization, visual design, competitive gaps, and platform capabilities. The audit identified **7 critical**, **24 high**, and **35+ medium** severity findings across all dimensions.

**The three highest-ROI themes are:**
1. **Performance & Data Integrity** -- unbounded queries and O(N) computations will break at scale
2. **Monetization & Conversion** -- passive paywall, overly generous free tier, no trial
3. **Platform Depth** -- Lock Screen widgets, interactive widgets, Background App Refresh, accessibility

---

## Phase 0: Critical Fixes (Ship ASAP)

These are bugs or architectural issues that will cause real problems as data grows.

### 0.1 Bounded Queries (Performance)
**Problem:** Every tab loads ALL transactions via `@Query(sort: \Transaction.date)` with no `fetchLimit` or predicate. After 1 year of use (~1,500 transactions), every tab switch fetches the entire table. `Category.spentCents(in:)` is called O(N*M) times per view body render.

**Fix:**
- Add `fetchLimit` to Dashboard (5 recent), History (paginate at 50)
- Pre-compute `[Category.ID: Int64]` spent map once in `.task`, store in `@State`
- Move `currentBudget` resolution from linear scan to `FetchDescriptor` with predicate
- Move ML computations to `Task {}` blocks in `.task` modifiers (off main thread)

**Files:** `DashboardPlaceholderView.swift`, `HistoryPlaceholderView.swift`, `InsightsPlaceholderView.swift`, `BudgetPlaceholderView.swift`, `BudgetMLEngine.swift`
**Severity:** CRITICAL | **Effort:** Medium

### 0.2 Transaction Date Validation
**Problem:** Date picker allows selecting ANY date, but transaction is assigned to the current budget's category. A transaction dated Feb 15 while viewing March budget disappears from all views.

**Fix:** Clamp date picker to `budget.periodStart...budget.nextPeriodStart`, or resolve category to the correct budget period.

**File:** `TransactionEntryView.swift:277-295`
**Severity:** CRITICAL | **Effort:** Small

### 0.3 SafeSave Silent Failures
**Problem:** `SafeSave.save()` swallows errors. User thinks transaction is saved but it's not.

**Fix:** Return `Result`, show alert on failure in critical paths (transaction entry, month rollover).

**File:** `SafeSave.swift`
**Severity:** HIGH | **Effort:** Small

### 0.4 Budget Deduplication
**Problem:** No uniqueness enforcement on `Budget(month, year)`. iCloud sync could create duplicate budgets, splitting categories across two.

**Fix:** Add dedup check in `performMonthRollover` and on `NSPersistentStoreRemoteChange`.

**File:** `BudgetVaultApp.swift`, `CloudSyncService.swift`
**Severity:** HIGH | **Effort:** Medium

### 0.5 Delete All Data Completeness
**Problem:** `deleteAllData()` misses `lastCategoryAlert-*` and `underBudget_*_*` UserDefaults keys.

**Fix:** Enumerate all keys via `UserDefaults.standard.dictionaryRepresentation()` or use a dedicated suite.

**File:** `SettingsPlaceholderView.swift:569-596`
**Severity:** HIGH | **Effort:** Small

### 0.6 Hero Amount Animation
**Problem:** `.contentTransition(.numericText())` is declared but no `.animation` modifier triggers it.

**Fix:** Add `.animation(.default, value: remainingCents)` to the hero amount text.

**File:** `DashboardPlaceholderView.swift:326`
**Severity:** HIGH | **Effort:** Tiny

---

## Phase 1: UX Quick Wins (v1.1)

High-impact, low-effort UX improvements that address the most common friction points.

### 1.1 Swipe Actions on Transactions
Add `.swipeActions(edge: .trailing)` with destructive "Delete" and `.swipeActions(edge: .leading)` with "Duplicate" on transaction rows in History.

**File:** `HistoryPlaceholderView.swift`
**Impact:** HIGH | **Effort:** Small

### 1.2 Transaction Undo
Implement soft-delete with a 5-second undo toast (like iOS Mail) instead of immediate permanent deletion.

**Files:** `TransactionEditView.swift`, `HistoryPlaceholderView.swift`
**Impact:** HIGH | **Effort:** Medium

### 1.3 "Today" Button for Month Navigation
Add a "Today" button (or tappable month title) that resets to current period. Currently users must tap forward N times after navigating backwards.

**Files:** `HistoryPlaceholderView.swift`, `BudgetPlaceholderView.swift`
**Impact:** HIGH | **Effort:** Tiny

### 1.4 Preserve Category in "Save & Add Another"
Keep the selected category across batch entries. Most batch entries are in the same category.

**File:** `TransactionEntryView.swift:319`
**Impact:** HIGH | **Effort:** Tiny

### 1.5 Onboarding Skip Button
Add "Skip to Setup" link on pages 0-2 for power users who understand envelope budgeting.

**File:** `OnboardingView.swift`
**Impact:** HIGH | **Effort:** Tiny

### 1.6 Context Menus
Add `.contextMenu` to transaction rows and category cards with Edit, Delete, Duplicate, Move to Category actions.

**Files:** `TransactionRowView.swift`, `BudgetPlaceholderView.swift`
**Impact:** MEDIUM | **Effort:** Small

### 1.7 History Sorting Options
Add sort toggle (Date / Amount / Category) in History toolbar.

**File:** `HistoryPlaceholderView.swift`
**Impact:** MEDIUM | **Effort:** Small

### 1.8 Stronger Delete All Data Confirmation
Two-step: suggest exporting first, then require typing "DELETE" to confirm.

**File:** `SettingsPlaceholderView.swift`
**Impact:** HIGH | **Effort:** Small

### 1.9 Income Entry Guidance
Add helper text in onboarding: "Enter your monthly take-home pay (after taxes)".

**File:** `OnboardingView.swift`
**Impact:** MEDIUM | **Effort:** Tiny

### 1.10 Category Detail Navigation from Budget Tab
Make category rows in BudgetPlaceholderView tappable NavigationLinks to CategoryDetailView.

**File:** `BudgetPlaceholderView.swift`
**Impact:** MEDIUM | **Effort:** Small

---

## Phase 2: Monetization Overhaul (v1.1-1.2)

### 2.1 Proactive Paywall Triggers
Show paywall at high-intent moments instead of only when users tap locked features:
- After 5th transaction logged
- After first monthly summary viewed
- After 7-day streak milestone
- After 3 app opens on different days

**File:** `DashboardPlaceholderView.swift`
**Impact:** HIGH (3-5x conversion lift) | **Effort:** Small

### 2.2 7-Day Premium Trial
All new installs get 7 days of full premium. After expiry, features lock. Loss aversion converts 2-3x better than never having features.

**Files:** `StoreKitManager.swift`, `PaywallView.swift`
**Impact:** HIGH | **Effort:** Medium

### 2.3 Price Anchoring on Paywall
Add competitive comparison:
```
YNAB: $109/year
Monarch: $99/year
BudgetVault: $9.99 once (forever)
```

**File:** `PaywallView.swift`
**Impact:** HIGH | **Effort:** Tiny

### 2.4 Tighten Free Tier
Move behind premium gate:
- Monthly totals bar chart (multi-month historical analysis)
- Savings goals (long-term stickiness feature)
- Recurring expenses: limit to 3 for free (currently unlimited)

Increase free category limit from 4 to 6 (better day-1 experience, still motivates upgrade for power users).

**Files:** `InsightsPlaceholderView.swift`, `BudgetPlaceholderView.swift`, `RecurringExpenseListView.swift`, `OnboardingView.swift`
**Impact:** HIGH | **Effort:** Medium

### 2.5 Blurred Premium Preview (First 3 Days)
Show real premium content at 60% blur instead of skeleton placeholders for first 3 days. Users see what they'll lose.

**File:** `InsightsPlaceholderView.swift`
**Impact:** HIGH | **Effort:** Medium

### 2.6 Post-Purchase Welcome Experience
After purchase: dedicated "Welcome to Premium" screen listing unlocked features with direct links + "Share the news" button.

**File:** `PaywallView.swift`
**Impact:** MEDIUM | **Effort:** Small

### 2.7 Contextual Tip Jar
Move tip from buried Settings to emotional moments:
- After Monthly Wrapped completion
- After 30-day streak
- Copy: "Built by an indie developer. Your tip keeps BudgetVault independent."

**Files:** `MonthlyWrappedView.swift`, `DashboardPlaceholderView.swift`
**Impact:** LOW-MEDIUM | **Effort:** Small

### 2.8 Subscription Tier (Future)
**BudgetVault Plus** ($2.99/mo or $24.99/yr): Partner sharing, advanced forecasts, bill calendar, custom widget themes, early access. Preserves "no subscription required" positioning (Premium is still one-time).

**Impact:** HIGH (3-5x LTV) | **Effort:** High

---

## Phase 3: Design System & Polish (v1.2)

### 3.1 Dynamic Type Support
**CRITICAL:** Zero `@ScaledMetric` usage. All custom fonts use fixed `.system(size:)`. This is an accessibility compliance failure and App Store review risk.

**Fix:**
- Add `@ScaledMetric` for frame sizes (envelope cards, icon frames)
- Use `.dynamicTypeSize(...(.accessibility3))` range limits on hero text
- Add `.minimumScaleFactor(0.5)` to large amounts
- Test at all Dynamic Type sizes

**Impact:** CRITICAL | **Effort:** Medium (systematic pass)

### 3.2 Design Token Adoption
123 hardcoded padding values, 52 hardcoded corner radii, 35+ hardcoded font sizes should reference `BudgetVaultTheme` tokens. Add missing tokens:
```swift
static let priceDisplay = Font.system(size: 36, weight: .bold, design: .rounded)
static let brandTitle = Font.system(size: 32, weight: .bold, design: .rounded)
static let spacingHero: CGFloat = 40  // CTA button areas
```

**File:** `BudgetVaultTheme.swift` + all views
**Impact:** HIGH (maintainability) | **Effort:** Medium

### 3.3 Extract Shared Components
6 missing reusable components (currently copy-pasted across 15+ files):
- `SectionHeaderView` -- section headers with icon
- `CategoryChipView` -- emoji category picker circles
- `MetricCardView` -- dashboard metrics
- `StatusBadge` -- recurring due badges, streak badge
- `SecondaryButtonStyle` -- "Save & Add Another" style
- `GradientCardView` -- hero card, summary headers

**Impact:** MEDIUM | **Effort:** Medium

### 3.4 Dashboard Entrance Animations
Add staggered slide-up animations to dashboard sections. Currently everything appears at once.

**File:** `DashboardPlaceholderView.swift`
**Impact:** MEDIUM | **Effort:** Small

### 3.5 Premium Lock Consistency
Unify premium lock indicators (currently uses star, lock, and material overlay inconsistently).

**Impact:** LOW | **Effort:** Small

### 3.6 Dark Mode Polish
- Increase category tint opacity from 0.08 to 0.15 in dark mode
- Add shimmer to premium skeleton placeholders
- Fix danger gradient contrast against dark backgrounds

**Impact:** MEDIUM | **Effort:** Small

### 3.7 Color-Blind Accessibility
Progress bars use color alone (green/yellow/red). Add secondary indicators: icons or text labels ("Under"/"Over") alongside color.

**Files:** `BudgetPlaceholderView.swift`, `TransactionRowView.swift`
**Impact:** MEDIUM | **Effort:** Small

---

## Phase 4: Platform Depth (v1.2-1.3)

### 4.1 Lock Screen Widgets
Add `.accessoryCircular` (budget ring) and `.accessoryInline` ("$1,234 remaining") widget families. The existing ring UI can be reused directly.

**File:** `BudgetVaultWidget.swift`
**Impact:** HIGH | **Effort:** Easy

### 4.2 Interactive Widget Buttons
Add "Quick Add" `Button` to medium widget using `AppIntent`-backed action. Users can start expense entry from home screen.

**File:** `BudgetVaultWidget.swift`
**Impact:** HIGH | **Effort:** Medium

### 4.3 Background App Refresh
Register `BGAppRefreshTask` to process recurring expenses, perform month rollover, and update widget data even when app isn't opened.

**Files:** `BudgetVaultApp.swift`, `project.yml` (add capability)
**Impact:** HIGH | **Effort:** Medium

### 4.4 Fix AddExpenseIntent Parameter Passing
The TODO in `BudgetAppIntents.swift` notes that parameters aren't actually pre-populated. Fix to enable "Add $20 for coffee" via Siri.

**File:** `BudgetAppIntents.swift`
**Impact:** HIGH | **Effort:** Easy

### 4.5 Notification Actions
Add `UNNotificationAction` "Log Expense" button directly on daily reminder notifications. One tap from notification to expense entry.

**File:** `NotificationService.swift`
**Impact:** HIGH | **Effort:** Easy

### 4.6 TipKit Contextual Tips
Progressive feature discovery after onboarding:
- "Swipe left to delete transactions"
- "Tap here to move money between envelopes"
- "Try asking Siri: How much budget is left?"
- "Set up recurring expenses to auto-track bills"

**Impact:** HIGH | **Effort:** Easy

### 4.7 Wire Up Bill Due Reminders
`scheduleBillDueReminder` exists in NotificationService but is never called. Connect it to recurring expense creation/editing.

**File:** `NotificationService.swift`, `RecurringExpenseFormView.swift`
**Impact:** MEDIUM | **Effort:** Easy

### 4.8 Control Center Widget (iOS 18)
Minimalist remaining budget display + quick-add action in Control Center.

**Impact:** HIGH | **Effort:** Medium

### 4.9 AppEntity for Category (Conversational Siri)
Enable "Add $50 to Groceries" with structured entity resolution.

**File:** `BudgetAppIntents.swift`, `BudgetVaultSchemaV1.swift`
**Impact:** HIGH | **Effort:** Medium

### 4.10 Spotlight Indexing
Index transactions and categories via `CSSearchableItem`. Users can search "groceries" in Spotlight and see spending data.

**Impact:** HIGH | **Effort:** Medium

### 4.11 NSUbiquitousKeyValueStore for Settings Sync
The entitlement exists but isn't used. Sync currency, reset day, theme, and streak across devices trivially.

**Impact:** MEDIUM | **Effort:** Easy

### 4.12 StandBy Mode
Existing small widget ring design is perfect for StandBy. Add supported families.

**Impact:** MEDIUM | **Effort:** Easy

---

## Phase 5: Retention & Engagement (v1.3)

### 5.1 Personalized Notifications
Replace generic weekly summary ("Your weekly spending summary is ready") with actual data: "You spent $423 this week across 12 transactions. $1,077 remaining."

**File:** `NotificationService.swift`
**Impact:** HIGH (2-4x open rates) | **Effort:** Medium

### 5.2 Lapsed User Re-engagement
Schedule notifications after inactivity:
- 3 days: "You haven't logged expenses in 3 days. Quick catch-up?"
- 7 days: "Your budget period is X% over. Tap to see where you stand."
- On app reopen after 3+ days: "Welcome Back" card with auto-posted recurring summary.

**Impact:** HIGH | **Effort:** Medium

### 5.3 Morning Briefing Notification
Optional second daily notification: "Good morning! You can spend $47/day for the next 12 days. 2 bills coming this week."

**Impact:** MEDIUM | **Effort:** Low

### 5.4 End-of-Month Engagement
Notification 3 days before budget reset: "3 days left. You have $X remaining. Can you make it?"
Reset day: "New month, fresh start! Your budget has reset."

**Impact:** MEDIUM | **Effort:** Low

### 5.5 Shareable Moment Cards
Auto-prompt sharing at emotional peaks:
- First month under budget (achievement card)
- 30-day streak (streak badge image)
- Monthly Wrapped completion (spending highlights card)
- Savings goal reached (celebration card)

Each includes subtle BudgetVault branding + App Store link.

**Impact:** HIGH | **Effort:** Medium

### 5.6 More Review Prompt Triggers
Also trigger at: first month under budget, savings goal completion, after Monthly Wrapped "done", 10th transaction in a month. Keep existing caps.

**File:** `ReviewPromptService.swift`
**Impact:** MEDIUM | **Effort:** Small

### 5.7 Savings Goal Empty State
Dashboard hides goals section when empty. Show prompt: "Set a savings goal for any category" with link to budget tab.

**File:** `DashboardPlaceholderView.swift`
**Impact:** LOW | **Effort:** Tiny

---

## Phase 6: Competitive Feature Gaps (v1.3-2.0)

### 6.1 Buffer Days / Age of Money Metric
`(Total unspent) / (Average daily spend)` = days of financial buffer. YNAB's #1 motivational metric. One computed property + dashboard card.

**Impact:** HIGH | **Effort:** Tiny

### 6.2 Smart Category Learning
Remember note-to-category mappings with confidence threshold. "Starbucks" typed -> auto-select Coffee if >80% historical match.

**Files:** `TransactionEntryView.swift`, new `CategoryLearningService.swift`
**Impact:** HIGH | **Effort:** Medium

### 6.3 Reconciliation Flow
Compare tracked balance to actual account balance, auto-create adjustment transaction. Critical for long-term accuracy of manual-entry apps.

**Impact:** HIGH | **Effort:** Medium (new view + service)

### 6.4 Bill Calendar View
Monthly grid with dots on bill due dates. EveryDollar's most praised feature.

**Impact:** HIGH | **Effort:** Medium-Large

### 6.5 Amount Auto-Suggest
Show last matching transaction amount as ghost text in number pad when a note is entered.

**File:** `TransactionEntryView.swift`
**Impact:** MEDIUM | **Effort:** Small

### 6.6 Receipt Photo Attachment
Optional photo on transactions, stored locally (on-device, consistent with privacy brand).

**Impact:** MEDIUM | **Effort:** Medium

### 6.7 Quick Amount Chips
Row of configurable amount shortcuts ($5, $10, $20, $50) above number pad.

**File:** `NumberPadView.swift`
**Impact:** MEDIUM | **Effort:** Small

### 6.8 Catch-Up Mode for Lapsed Users
"Welcome back" flow for 3+ day absence: summary of auto-posted expenses, quick-add prompt, no judgment.

**Impact:** HIGH | **Effort:** Medium

### 6.9 YNAB/Mint CSV Import Wizard
Expand CSV import to auto-detect and map columns from YNAB export, Mint export, and common bank formats. Lower switching costs.

**Impact:** MEDIUM | **Effort:** Medium

### 6.10 Partner/Couple Sharing (Premium Plus)
CloudKit CKShare for shared budgets with partner attribution. Monarch's strongest feature.

**Impact:** HIGH | **Effort:** Hard

---

## Phase 7: Architecture & Quality (Ongoing)

### 7.1 Test Target
Add unit test target to `project.yml`. Priority test targets:
1. `DateHelpers` -- boundary conditions around reset day, month/year wraparound
2. `MoneyHelpers` -- edge cases (empty, negative, overflow, locale decimals)
3. `CSVImporter.parse` -- YNAB format, generic format, malformed input
4. `InsightsEngine` -- requires dependency injection first
5. Month rollover logic

**Impact:** CRITICAL | **Effort:** Medium

### 7.2 MVVM Cleanup
Move business logic from `DashboardPlaceholderView` (677 lines) into `DashboardViewModel`. Extract `currentBudget` resolution, `visibleCategories` filtering, achievement checking, date helpers.

**Impact:** MEDIUM | **Effort:** Medium

### 7.3 InsightsEngine Dependency Injection
Replace direct `UserDefaults.standard` access with injected parameters. Return structured data, let views format currency.

**File:** `InsightsEngine.swift`
**Impact:** MEDIUM | **Effort:** Small

### 7.4 CSV Import Deduplication
Check for existing transactions with matching date+amount+note before inserting.

**File:** `CSVImporter.swift`
**Impact:** MEDIUM | **Effort:** Small

### 7.5 SchemaV2 Migration
When raising minimum to iOS 18:
- Add `#Index<Transaction>([\.date])` and `#Index<Transaction>([\.category, \.date])`
- Add `SchemaV2` with proper migration plan

**Impact:** MEDIUM | **Effort:** Medium

### 7.6 Accessibility Systematic Pass
Only 15 accessibility annotations across 26+ view files. VoiceOver users would find the app nearly unusable.
- `accessibilityLabel` on all interactive elements
- `accessibilityValue` on progress rings, charts
- `accessibilityChartDescriptor` on spending charts
- Reduced motion support (`@Environment(\.accessibilityReduceMotion)`)

**Impact:** CRITICAL | **Effort:** Medium-Large

### 7.7 Data Protection
Set `NSFileProtectionComplete` on the SwiftData store directory. Financial data should have strongest encryption.

**Impact:** MEDIUM | **Effort:** Easy

### 7.8 Keychain for Premium Status
Migrate `isPremium` from UserDefaults to Keychain. Prevents jailbreak bypass.

**Impact:** MEDIUM | **Effort:** Medium

### 7.9 Rename "Placeholder" Views
`DashboardPlaceholderView` -> `DashboardView`, etc. Dev-facing cleanup.

**Impact:** LOW | **Effort:** Small

---

## Phase 8: ASO & Market Expansion (Ongoing)

### 8.1 App Store Subtitle
Change from "Smart Budgeting" (generic) to "Private Envelope Budget" or "Budget Without Big Brother".

**Impact:** MEDIUM | **Effort:** Tiny (metadata change)

### 8.2 Keyword Optimization
Priority keywords: `envelope budgeting, ynab alternative, budget no subscription, private budget, cash envelope, zero based budget, budget planner, spending tracker, offline budget, budget app no login`

**Impact:** HIGH | **Effort:** Tiny

### 8.3 Privacy Label Amplification
- "Privacy Promise" dismissable card on dashboard
- Apple privacy label badge in App Store screenshots
- "Data Not Collected" as first line of App Store description

**Impact:** MEDIUM | **Effort:** Small

### 8.4 Localization (German, Spanish, French)
Envelope budgeting is popular in Germany. Privacy resonates in EU (GDPR). Opens 3 highest-value non-English markets.

**Impact:** MEDIUM | **Effort:** High

### 8.5 iPad Support
Large addressable market. SwiftUI makes it feasible. iOS 18 Tab bar with sidebar morphing handles navigation. Main work: adaptive layouts for dashboard, reports, transaction list.

**Impact:** HIGH | **Effort:** Hard

---

## Release Roadmap

| Version | Phases | Timeline | Theme |
|---------|--------|----------|-------|
| **v1.0.3** | Phase 0 (Critical Fixes) | Immediate | Stability & data integrity |
| **v1.1** | Phase 1 + 2 (UX + Monetization) | 2-3 weeks | Conversion & daily experience |
| **v1.2** | Phase 3 + 4 (Design + Platform) | 4-6 weeks | Polish & platform depth |
| **v1.3** | Phase 5 + 6 (Retention + Features) | 6-8 weeks | Growth & competitive parity |
| **v2.0** | Phase 7 + 8 (Quality + Expansion) | 10-12 weeks | Scale & new markets |

---

## Scoring Summary

| Dimension | Current Grade | Target (v2.0) |
|-----------|--------------|----------------|
| Performance | C | A |
| Data Integrity | B- | A |
| UX & Navigation | B+ | A |
| Monetization | C+ | A- |
| Design System | B | A |
| Accessibility | D | B+ |
| Platform Depth | C+ | A- |
| Test Coverage | F | B |
| Retention Hooks | B | A |
| Competitive Position | B | A- |

---

## Audit Sources

- **UX Researcher** -- 27 findings across 10 heuristic categories
- **Backend Architect** -- 28 findings: 4 critical, 8 high, 14 medium, 2 low
- **Growth Hacker** -- 31 recommendations across monetization, retention, and growth
- **UI Designer** -- Design system audit: token coverage, visual hierarchy, motion, dark mode
- **Feature Explorer** -- Complete inventory: 50+ implemented features, 25+ competitive gaps
- **Mobile App Builder** -- 15 priority platform opportunities across 14 capability areas
