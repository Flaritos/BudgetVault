# BudgetVault — Privacy-First Budgeting App (Revised v4)

## Composite Score: 43/50 | Realistic Build: 7–9 Weeks (MVP: 3–4 Weeks)

**Tagline:** Your budget. Locked down. Private.
**Wraps/Improves:** YNAB ($99/yr), Monarch Money ($99/yr), Goodbudget
**Monetization:** One-time purchase — $14.99
**Minimum iOS:** 17.0

> **Revision Notes (v4):** Final polish from third review. Key v4 changes: periodEnd off-by-one fixed (use `date < nextPeriodStart` instead of `date <= periodEnd`), multi-month gap rollover cascades through intermediate months, resetDay sourced from @AppStorage with Budget.resetDay as frozen snapshot, streak documented as known multi-device limitation, launch pricing has hardcoded expiration date, "Savings" category replaced with "Other" to avoid transaction-type confusion, notification permission request defined, widget premium gating added, CSV import assigns to correct budgets, category archive/restore path added, recurring auto-posting batched with cap, privacy policy added to pre-launch checklist, StoreKit error states defined, income transactions handle nil category emoji.

---

## Architecture Overview

| Component | Technology | Rationale |
|-----------|-----------|-----------|
| Language | Swift 5.9+ | Native performance, latest concurrency features |
| UI Framework | SwiftUI | Declarative, rapid iteration, native feel |
| Data Persistence | SwiftData with VersionedSchema | On-device storage, no server needed. VersionedSchema from day 1 for safe migrations. |
| Cloud Sync | CloudKit (private database) | Free, Apple-native, end-to-end encrypted. **Added in Step 8, NOT in initial build** |
| Charts | Swift Charts | Native iOS 17+ charting framework |
| AI Insights | **On-device rule-based engine ONLY** | Spending pattern analysis. **NO external API calls. NO network requests for insights. Ever.** |
| Architecture Pattern | MVVM (Views own @Query, ViewModels own business logic) | Clean separation, testable |
| Monetization SDK | StoreKit 2 | One-time purchase IAP with Family Sharing enabled |
| Biometric Auth | LocalAuthentication (LAContext) | Optional Face ID / Touch ID app lock |

### Critical Architecture Decisions

1. **Money Storage: Int64 cents, NOT Decimal.** SwiftData stores Decimal as Double internally, causing silent floating-point rounding errors on financial data. All monetary values are stored as `Int64` representing cents (e.g., $14.50 = 1450). A computed property provides `Decimal` access for display. All arithmetic happens on Int64.

2. **@Query lives in Views, NOT ViewModels.** `@Query` is a SwiftUI property wrapper that only works inside `View` structs. ViewModels use `@Observable` and receive data from Views or use `ModelContext` directly for writes. Views pass queried data to ViewModels via methods/properties.

3. **AI Insights are 100% on-device.** The app's core brand is "no third-party servers." If financial data leaves the device for any reason, the privacy promise is destroyed. All insights use rule-based logic (thresholds, averages, comparisons). No Core ML model is required for MVP.

4. **CloudKit is deferred to Step 8.** Build local-only first. CloudKit + SwiftData has known fragility issues. Several model properties need to be optional or have defaults for CloudKit compatibility. This is a separate integration step, not baked into the initial build. **Marketing copy says "No third-party servers" NOT "No servers" — because iCloud IS a server.**

5. **RecurringExpense uses @Relationship, not raw UUID.** `categoryId: UUID` is replaced with a proper SwiftData `@Relationship` to `Category` for type safety and cascade behavior.

6. **VersionedSchema from Day 1.** All models are defined inside a `BudgetVaultSchemaV1` enum conforming to `VersionedSchema`. Any v1.1 model change uses `SchemaMigrationPlan` with a `MigrationStage`. Without this, model changes crash existing users.

7. **All @Query patterns MUST filter by parent Budget.** Categories and transactions are duplicated across monthly Budget objects. Every @Query for categories must include `budget == currentBudget` predicate. Every computed `spentCents` must filter transactions by the current budget period's date range, NOT sum all transactions ever.

8. **Accessibility is baked into every step, not deferred.** Each prompt includes accessibility requirements inline. Step 10 is the audit/polish pass, not the first time accessibility is considered.

9. **Do NOT use `#Unique` macro on any model property.** It breaks CloudKit compatibility silently.

10. **Date filtering uses half-open intervals.** `date >= periodStart && date < nextPeriodStart`. Never use `<= periodEnd` with a minus-1-second hack — it creates midnight boundary gaps.

11. **resetDay has a central source of truth:** `@AppStorage("resetDay")` in Settings. When a new Budget is created, it reads this value and freezes it as `Budget.resetDay`. Changing the setting takes effect on the NEXT budget period only.

12. **Multi-month gap rollover cascades through intermediate months.** If a user skips February entirely and opens the app in March, the rollover logic must create February's budget first (copying January + applying rollOverUnspent), THEN create March's budget (copying February). A `while` loop fills gaps, not just a single copy.

13. **Streak is a known multi-device limitation.** Streak data lives in `@AppStorage` (synced to widget via UserDefaults suite) but NOT in SwiftData/CloudKit. Users on multiple devices will have independent streaks. Document this as a known limitation; a StreakRecord model can be added in v1.1 if user demand warrants it.

14. **Recurring expense auto-posting is batched with a cap.** If a user hasn't opened the app in 6 months, auto-posting could create hundreds of transactions synchronously on launch. Cap at 50 transactions per launch; if more remain, show a banner: "Catching up on recurring expenses... {N} remaining" and continue on next foreground.

---

## Project Structure

```
BudgetVault/
├── BudgetVaultApp.swift              # App entry, ModelContainer, scene phase handling
├── ContentView.swift                 # Tab navigation + onboarding gate + biometric lock
├── Schema/
│   └── BudgetVaultSchemaV1.swift     # VersionedSchema with all models
├── Models/
│   ├── Budget.swift                  # Budget period model (Int64 cents)
│   ├── Category.swift                # Spending category
│   ├── Transaction.swift             # Individual transaction
│   └── RecurringExpense.swift        # Recurring bills/subscriptions
├── ViewModels/
│   ├── DashboardViewModel.swift      # Dashboard business logic (receives data from View)
│   ├── BudgetViewModel.swift         # Budget allocation logic
│   ├── TransactionViewModel.swift    # Transaction create + edit logic
│   ├── RecurringExpenseViewModel.swift # Recurring expense management + auto-posting
│   ├── InsightsEngine.swift          # Rule-based spending insights (NOT a ViewModel)
│   └── SettingsViewModel.swift       # App settings & IAP
├── Views/
│   ├── Dashboard/
│   │   ├── DashboardView.swift       # Main overview screen
│   │   ├── BudgetRingView.swift      # Circular budget progress
│   │   └── QuickEntryView.swift      # Floating action button entry
│   ├── Budget/
│   │   ├── BudgetSetupView.swift     # Monthly budget allocation
│   │   ├── CategoryListView.swift    # All categories with amounts
│   │   └── CategoryDetailView.swift  # Transactions in a category
│   ├── Transactions/
│   │   ├── TransactionEntryView.swift   # Add new transaction
│   │   ├── TransactionEditView.swift    # Edit existing transaction
│   │   ├── TransactionListView.swift    # Full transaction history
│   │   └── TransactionRowView.swift     # Single transaction row
│   ├── RecurringExpenses/
│   │   ├── RecurringExpenseListView.swift  # All recurring expenses
│   │   ├── RecurringExpenseFormView.swift  # Add/edit recurring expense
│   │   └── RecurringExpenseRowView.swift   # Single row
│   ├── Insights/
│   │   ├── InsightsView.swift        # Spending insights
│   │   ├── TrendChartView.swift      # Monthly trend charts
│   │   ├── CategoryPieView.swift     # Category breakdown pie chart
│   │   └── MonthlySummaryView.swift  # End-of-month review
│   ├── Settings/
│   │   ├── SettingsView.swift        # App settings
│   │   ├── ExportView.swift          # CSV export
│   │   ├── ImportMappingView.swift   # CSV import field mapping
│   │   ├── PaywallView.swift         # One-time purchase screen
│   │   └── BiometricLockView.swift   # Face ID/Touch ID setup
│   ├── Onboarding/
│   │   ├── OnboardingView.swift      # First-launch setup (3 screens)
│   │   └── CurrencyPickerView.swift  # Currency selection
│   └── Shared/
│       ├── EmptyStateView.swift      # Reusable empty state component
│       ├── NumberPadView.swift       # Reusable custom number pad
│       └── PaywallStubView.swift     # Minimal stub used before Step 7a builds real paywall
├── Services/
│   ├── PersistenceController.swift   # SwiftData container (local-only initially)
│   ├── CloudSyncService.swift        # CloudKit sync (Step 8 only)
│   ├── StoreKitManager.swift         # IAP management
│   ├── BiometricAuthService.swift    # Face ID / Touch ID
│   ├── RecurringExpenseScheduler.swift # Auto-posts recurring transactions
│   ├── CSVExporter.swift             # Data export
│   ├── CSVImporter.swift             # Data import with YNAB format support
│   └── NotificationService.swift     # Bill reminders, streak reminders, weekly summary
└── Utilities/
    ├── CurrencyFormatter.swift       # Locale-aware formatting (converts Int64 cents → display)
    ├── MoneyHelpers.swift            # Int64 cents ↔ Decimal conversion utilities
    ├── DateHelpers.swift             # Date range utilities, budget period calculation
    └── HapticManager.swift           # Haptic feedback
```

---

## Data Model

> **CRITICAL:** All monetary values are stored as `Int64` representing cents. All models live inside `BudgetVaultSchemaV1: VersionedSchema`. Do NOT use `#Unique` on any property — it breaks CloudKit.

### Budget
| Property | Type | Description | CloudKit Note |
|----------|------|-------------|---------------|
| id | UUID | Unique identifier (default UUID()) | |
| month | Int | Month number (1-12) | |
| year | Int | Year (e.g., 2026) | |
| totalIncomeCents | Int64 | Total monthly income in cents (default 0) | |
| resetDay | Int | Day of month budget resets (1-28, default 1). Budget period = resetDay of this month to resetDay-1 of next month | |
| categories | [Category] | @Relationship(deleteRule: .cascade) (default []) | |
| createdAt | Date | Creation timestamp (default Date.now) | |
| isAutoCreated | Bool | True if auto-created by month rollover (default false) | |

**Computed properties:**
```swift
var totalIncome: Decimal { Decimal(totalIncomeCents) / 100 }

/// Budget period start date (accounts for resetDay)
var periodStart: Date {
    Calendar.current.date(from: DateComponents(year: year, month: month, day: resetDay)) ?? Date()
}
/// Next period start — used for exclusive upper bound (avoids off-by-one at midnight)
var nextPeriodStart: Date {
    Calendar.current.date(byAdding: .month, value: 1, to: periodStart) ?? Date()
}
```

> **CRITICAL: Date filtering uses half-open intervals.** Always filter as `date >= periodStart && date < nextPeriodStart`. Do NOT use `date <= periodEnd` with a minus-1-second hack — it creates a 1-second gap at midnight boundaries that silently drops transactions.

### Category
| Property | Type | Description | CloudKit Note |
|----------|------|-------------|---------------|
| id | UUID | Unique identifier (default UUID()) | |
| name | String | Category name (default "") | default "" for CloudKit |
| emoji | String | Display emoji icon (default "📦") | default "📦" for CloudKit |
| budgetedAmountCents | Int64 | Allocated budget in cents (default 0) | |
| color | String | Hex color for charts (default "#007AFF") | default for CloudKit |
| sortOrder | Int | Display order (default 0) | |
| isHidden | Bool | Soft delete / archive (default false) | |
| rollOverUnspent | Bool | Carry unspent to next month (default false) | |
| transactions | [Transaction] | @Relationship(deleteRule: .cascade) (default []) | |
| budget | Budget? | @Relationship(inverse: \Budget.categories) | |
| recurringExpenses | [RecurringExpense] | @Relationship(deleteRule: .nullify) (default []) | |

**Computed properties (DATE-FILTERED — requires budget reference):**
```swift
var budgetedAmount: Decimal { Decimal(budgetedAmountCents) / 100 }

/// CRITICAL: Half-open interval — date >= start AND date < nextStart (NOT <=)
func spentCents(in budget: Budget) -> Int64 {
    transactions
        .filter { !$0.isIncome && $0.date >= budget.periodStart && $0.date < budget.nextPeriodStart }
        .reduce(0) { $0 + $1.amountCents }
}
func spent(in budget: Budget) -> Decimal { Decimal(spentCents(in: budget)) / 100 }
func remainingCents(in budget: Budget) -> Int64 { budgetedAmountCents - spentCents(in: budget) }
```

### Transaction
| Property | Type | Description | CloudKit Note |
|----------|------|-------------|---------------|
| id | UUID | Unique identifier (default UUID()) | |
| amountCents | Int64 | Transaction amount in cents, always positive (default 0) | |
| note | String | User-entered description (default "") | default "" for CloudKit |
| date | Date | Transaction date (default Date.now) | |
| isIncome | Bool | True if income, false if expense (default false) | |
| category | Category? | @Relationship(inverse: \Category.transactions) | |
| isRecurring | Bool | Flag for auto-posted recurring transactions (default false) | |
| recurringExpense | RecurringExpense? | @Relationship(inverse: \RecurringExpense.generatedTransactions) | |
| createdAt | Date | Entry timestamp (default Date.now) | |

**Computed property:**
```swift
var amount: Decimal { Decimal(amountCents) / 100 }
```

### RecurringExpense
| Property | Type | Description | CloudKit Note |
|----------|------|-------------|---------------|
| id | UUID | Unique identifier (default UUID()) | |
| name | String | Expense name (default "") | default "" for CloudKit |
| amountCents | Int64 | Recurring amount in cents (default 0) | |
| frequency | String | "weekly"/"biweekly"/"monthly"/"yearly" (default "monthly") | String for CloudKit compat |
| nextDueDate | Date | Next expected charge date (default Date.now) | |
| category | Category? | @Relationship(inverse: \Category.recurringExpenses) | |
| isActive | Bool | Whether still active (default true) | |
| generatedTransactions | [Transaction] | @Relationship(deleteRule: .nullify) (default []) | Inverse of Transaction.recurringExpense |

**Computed properties:**
```swift
var amount: Decimal { Decimal(amountCents) / 100 }
var frequencyEnum: Frequency { Frequency(rawValue: frequency) ?? .monthly }
enum Frequency: String, CaseIterable { case weekly, biweekly, monthly, yearly }
```

### Recurring Expense Auto-Posting Mechanism

```
RecurringExpenseScheduler runs on TWO triggers:
1. App enters .active (scenePhase handler in BudgetVaultApp.swift)
2. When a new Budget period is created (month rollover)

Logic (runs on main actor, BATCHED with cap):
  var transactionsCreated = 0
  let MAX_PER_LAUNCH = 50

  for each active RecurringExpense where nextDueDate <= today:
    while nextDueDate <= today AND transactionsCreated < MAX_PER_LAUNCH:
      1. Find or create the Budget for the period containing nextDueDate
      2. Create a Transaction:
         - amountCents = recurringExpense.amountCents
         - note = recurringExpense.name
         - date = recurringExpense.nextDueDate
         - isIncome = false
         - isRecurring = true
         - recurringExpense = the RecurringExpense
         - category = recurringExpense.category
      3. Advance nextDueDate by frequency interval
      4. transactionsCreated += 1

  Save modelContext

  if transactionsCreated == MAX_PER_LAUNCH AND more remain:
    Show Dashboard banner: "Catching up on recurring expenses... open again to continue"
    (Remaining will process on next foreground)
```

> **Why the cap:** A user who hasn't opened the app in 6 months with 10 weekly recurring expenses = 260 transactions created synchronously on launch. This hangs the main thread. The 50-transaction cap prevents launch freezes while still catching up across multiple app opens.

---

## Free Tier vs Premium Limits

| Feature | Free | Premium ($19.99 one-time, Family Sharing enabled) |
|---------|------|---------------------------------------------------|
| Categories | 6 max (onboarding creates 4, leaving 2 free slots) | Unlimited |
| Transaction entry | Unlimited | Unlimited |
| Budget setup | Full | Full |
| Transaction history | Full | Full |
| CSV Export | Last 30 days | Full history |
| CSV Import | ❌ | ✅ (auto-creates categories, respecting no limit) |
| Charts (trend + pie) | Current month only | Full history + comparison |
| AI Insights | ❌ (blurred preview with real user data) | ✅ |
| Custom app icons | ❌ | ✅ |
| Widgets | Basic (remaining $) | Full (categories + ring) |
| Recurring Expenses | 3 max | Unlimited |
| Streak Freeze | ❌ | 1 per week (preserves streak on missed day) |
| Biometric Lock | ✅ (free for all) | ✅ |

> **Onboarding creates 4 default categories** (not 6), leaving free users 2 slots to customize before hitting the paywall. This avoids the bait-and-switch feeling of filling the entire quota on first launch.

> **CSV Import + Free Tier:** If a YNAB import contains >6 categories, the importer shows a mapping screen: "Your import has 12 categories. Free accounts support 6. Please select which categories to keep, or merge similar ones. Upgrade to Premium for unlimited categories."

---

## Screen-by-Screen UI Specification

### Screen 1: Onboarding (3 screens — streamlined)

> v2 had 4 screens with redundant privacy messaging. Consolidated to 3.

- **Page 1 (Welcome + Privacy Pitch):** Large shield icon + "BudgetVault" title. Headline: "Your money is nobody's business." Subtext: "No bank connections. No third-party servers. No subscriptions. Just a private, powerful budget on your device." CTA: "Get Started →"
- **Page 2 (Currency):** CurrencyPickerView with searchable List of currencies showing flag + name + symbol. Save to `@AppStorage("selectedCurrency")`. CTA: "Next →"
- **Page 3 (Quick Budget Setup):** Income TextField (.decimalPad). **4 default categories** (🏠 Rent 30%, 🛒 Groceries 20%, 🚗 Transport 10%, 📦 Other 20%) with amounts auto-calculated. Remaining 20% shown as "Unallocated — add your own categories later!" "Start Budgeting" button creates Budget + Categories in SwiftData.

> **Why no "Savings" default:** A savings category creates a conceptual mismatch — budgeting 20% to Savings means it shows 0% "spent" forever since there's no savings transaction type. Users who want to track savings should create a "Savings Transfer" category and log transfers as expenses. This can be explained in an optional onboarding tooltip.
- Uses `TabView(.page)` with progress dots. Stores completion in `@AppStorage("hasCompletedOnboarding")`.
- **Accessibility:** All pages support Dynamic Type. Progress dots have accessibilityLabel "Step X of 3". Buttons have accessibilityHint.

### Screen 2: Tab Navigation (always visible after onboarding)
- **Tab 1:** "Dashboard" (`house.fill`) → DashboardView
- **Tab 2:** "Budget" (`creditcard.fill`) → BudgetSetupView
- **Tab 3:** "History" (`clock.fill`) → TransactionListView
- **Tab 4:** "Insights" (`chart.pie.fill`) → InsightsView
- **Tab 5:** "Settings" (`gearshape.fill`) → SettingsView

> Tab navigation is built in Step 2, NOT deferred.

### Screen 3: Dashboard (Tab 1)
- **Top:** Current month name + remaining budget as large number with color (green >50%, yellow 25-50%, red <25%). Calculate as: totalIncomeCents − sum of all non-income transaction amountCents **for the current budget period** (filtered by periodStart..<nextPeriodStart). **Color indicator also has a text label** ("On Track" / "Watch It" / "Over Budget") for accessibility — do not rely on color alone.
- **Streak badge:** Small flame emoji + streak count near header (e.g., "🔥 14 days").
- **Middle:** Horizontal ScrollView of category "envelope" cards (~120pt wide). Each card shows: emoji, name, mini progress bar, dollar amounts. **Tapping a card navigates to CategoryDetailView** for that category.
- **Bottom:** Recent transactions list (last 5). Tapping any row opens TransactionEditView. **Income transactions have no category** — display a "💵" fallback emoji for TransactionRowView when `transaction.category == nil`.
- **Floating "+" button** (56pt circle, bottom trailing, accent color) opens TransactionEntryView as sheet.
- Pull-to-refresh.
- **Empty state:** "Tap + to log your first expense."
- **Accessibility:** Envelope cards have accessibilityLabel: "{emoji} {name}: spent {amount} of {budget}, {percent}%". Remaining budget has accessibilityValue.

### Screen 4: Transaction Entry (Half-sheet modal)
- Toggle: Expense / Income (SegmentedControl, defaults Expense)
- **Custom number pad with defined decimal behavior:**
  - Grid: [1][2][3] / [4][5][6] / [7][8][9] / [.][0][⌫]
  - Amount built as **string**. "." triggers decimal mode (max 2 places after).
  - Examples: 1→4→.→5→0 = "$14.50". 1→5 = "$15.00" on save.
  - Backspace removes last character.
  - Display: 32pt bold, locale currency symbol.
  - On save: parse string → Decimal → ×100 → Int64 cents.
- Category emoji buttons (expenses only). 44pt circles, selected has accent ring.
- DatePicker (.compact, defaults today)
- Note TextField with autocomplete from previous distinct notes
- "Save" button: validates amountCents > 0 AND category selected (for expense), triggers haptic, saves, dismisses.
- **Accessibility:** Number pad buttons have accessibilityLabel ("one", "two", "decimal point"). Amount display has accessibilityValue with currency spoken naturally.

### Screen 5: Transaction Edit (Full-sheet modal)
- **Same layout as Entry** but pre-populated with existing Transaction.
- "Save Changes" updates existing transaction.
- "Delete Transaction" red button at bottom with `.confirmationDialog`.
- Accessible from: tapping any transaction in Dashboard, Category Detail, or History.

### Screen 6: Budget Setup (Tab 2)
- Income field at top (tappable → NumberPad sheet).
- "Unallocated" = totalIncomeCents − sum(budgetedAmountCents). Red if negative, green if zero.
- Category list: @Query filtered by `budget == currentBudget AND isHidden == false`, sorted by sortOrder.
- `.onMove` for reorder. Trailing swipe to archive.
- "Add Category" button:
  - Free users with 6+ categories → **PaywallStubView** (before Step 7a) or PaywallView (after).
  - Otherwise → emoji picker, name, color, amount sheet.
- "Roll Over Unspent" toggle per category (reads/writes `rollOverUnspent` Bool on Category model). **rollOverUnspent with overspent categories:** If a category is overspent, the deficit does NOT carry forward — next month starts fresh at budgetedAmountCents. Only surpluses roll over.
- **"Show Archived" toggle** at bottom of category list. When enabled, shows archived (isHidden=true) categories in gray with a trailing swipe action: "Restore" (sets isHidden=false). This is the only way to un-archive categories.
- **Month navigation:** < > arrows. Past months read-only.
- **Accessibility:** Unallocated has accessibilityLabel that includes the amount and whether it's negative.

### Screen 7: Category Detail
- Header: name, emoji, spent vs budgeted ring.
- Transactions for this category **within current budget period** (date-filtered).
- **Tap to edit** → TransactionEditView.
- Swipe to delete with confirmation.
- Sort: by date / by amount.
- **Empty state:** "No expenses in {category} this month."

### Screen 8: Transaction History (Tab 3)
- Search bar (note text), filter chips (date range, category, income/expense).
- Grouped by day with subtotals.
- **Tap any row → TransactionEditView.**
- Export button via ShareLink.
- **Empty state:** "No transactions yet. Start logging!"

### Screen 9: Recurring Expenses Management
- Accessible from Settings AND a toolbar button on Budget tab.
- **Upcoming section:** Active expenses sorted by nextDueDate. Shows name, category emoji, amount, frequency badge, "due in X days".
- **Recently Posted:** Last 5 auto-posted transactions from recurring expenses with timestamps.
- **Inactive section:** Togglable, grayed out.
- Add: name, amount (NumberPad), frequency, category, start date. **Free users with 3+ → PaywallStubView/PaywallView.**
- Tap to edit. Swipe to deactivate.
- **Empty state:** "No recurring expenses. Add bills like Netflix or rent."

### Screen 10: Insights (Tab 4 — Partially Premium)
- **Free:** Monthly spending trend LineMark (current month only).
- **Free:** Category breakdown SectorMark donut (current month only).
- **Premium:** "vs. Last Month" comparison cards. **Previous month query:** `@Query` with predicate `(year == previousYear AND month == previousMonth)` — handle December→January year wraparound: if current month is 1, previous is month 12 of year-1.
- **Premium:** Rule-based insights via InsightsEngine (see architecture).
- **Premium:** Top 3 highest-spending days.
- **Free users:** Premium sections use `.blur(radius: 8)` overlay with **real user data behind the blur** (not placeholders) + "Unlock Premium Insights" button → PaywallView. **Accessibility:** Blurred sections have accessibilityLabel "Premium feature. Tap to learn about upgrading." so VoiceOver users aren't confused by invisible content.

### Screen 11: Monthly Summary (End-of-Month Review)

> **Conflict resolution:** This screen is surfaced **only** as a navigation destination (not auto-modal). When a new budget period auto-creates on .active, a banner appears on the Dashboard: "Your {previous month} summary is ready! Tap to review." The "Start New Month" button is removed — months always auto-create.

- Total income vs total spent with delta.
- Category-by-category over/under indicators.
- "You stayed under budget in X/Y categories" celebration.
- Shareable achievement card (ImageRenderer): "I stayed under budget in 5/6 categories!" + BudgetVault logo + **App Store short URL**. No dollar amounts in share.
- Share cards also available at streak milestones (7, 14, 30, 60, 90 days).

### Screen 12: Settings
- **Security:** Face ID / Touch ID toggle (uses `LAContext.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics)`). When enabled, app requires biometric on every launch. **An app called "Vault" without a lock undermines the brand.**
- **Profile:** Name, currency picker, budget reset day picker (1-28). **Note:** Changing reset day mid-month does NOT retroactively change the current period — takes effect next month.
- **Data:** Export CSV, Import CSV (premium), Recurring Expenses link.
- **Sync:** iCloud toggle — **HIDDEN until Step 8.** When visible, shows last sync timestamp.
- **Appearance:** App icon picker (3 alternatives, premium only), accent color picker.
- **Premium:** Purchase status or "Upgrade" button.
- **Notifications:** Daily reminder toggle + time picker, weekly summary toggle, bill-due reminders toggle. **First toggle flip triggers `UNUserNotificationCenter.requestAuthorization(options: [.alert, .sound, .badge])`**. If permission denied, show Settings deep-link.
- **About:** Version, privacy policy SafariView, tip jar.
- **Review prompt logic:** Triggered after under-budget month or 14+ day streak (not 7 — too early). Suppressed for 48 hours after a paywall decline. Max 3 per year per Apple policy. Uses `SKStoreReviewController.requestReview(in:)`.

### Screen 13: Paywall

> **CRITICAL:** Do NOT include competitor names. App Store reviewers may reject for trademark usage, and competitors could file complaints.

- App icon centered.
- "Unlock BudgetVault Premium" heading.
- Feature highlights with SF Symbol checkmarks: AI Insights, Unlimited Categories (vs 6 free), Unlimited Recurring Expenses (vs 3), Full CSV Import/Export, Custom App Icons, Historical Charts, Streak Freeze.
- **Price:** "$19.99" large + "one-time" beneath. Below: "Compare to leading budget apps at $99/year" (generic, no brand names).
- Price is $14.99 one-time (no launch pricing banner needed — launch pricing period is over).
- Full-width "Purchase" button. **States:** idle → loading (ProgressView) → success (checkmark + dismiss) → error (alert with retry). Handle `Product.PurchaseResult.pending`, `.userCancelled`, and `StoreKitError` cases explicitly.
- "Restore Purchases" text button.
- "Family Sharing included — one purchase covers your whole family." footer.
- "No subscription. No recurring charges. Ever." second footer.

### PaywallStubView (used in Steps 2-6 before real Paywall exists)

```swift
/// Minimal stub to prevent compile errors before Step 7a
struct PaywallStubView: View {
    @Environment(\.dismiss) var dismiss
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.fill")
                .font(.largeTitle)
            Text("Premium Feature")
                .font(.title2)
            Text("This feature will be available with BudgetVault Premium.")
            Button("OK") { dismiss() }
        }
        .padding()
    }
}
```

---

## Claude Code Prompt Sequence (Revised: 11 Steps)

> Feed these prompts in order. **Test after each step before proceeding.** Every prompt includes inline accessibility requirements — do NOT defer to Step 10.

### Prompt 1: Models + Local SwiftData + VersionedSchema

```
Create a new SwiftUI iOS app called BudgetVault targeting iOS 17+. Set up SwiftData with LOCAL storage only (no CloudKit yet).

CRITICAL RULES:
- All monetary values stored as Int64 cents. NOT Decimal (SwiftData silently corrupts Decimal→Double).
- All models defined inside BudgetVaultSchemaV1: VersionedSchema.
- Do NOT use #Unique on any property (breaks CloudKit compatibility).
- All String properties must have default values (required for future CloudKit).
- All computed spentCents must filter by budget period dates, NOT sum all-time.

Create Schema/BudgetVaultSchemaV1.swift conforming to VersionedSchema with versionIdentifier "v1" containing these @Model classes:

1. Budget:
   - id: UUID (default UUID())
   - month: Int, year: Int
   - totalIncomeCents: Int64 (default 0)
   - resetDay: Int (default 1) — day of month the budget period starts (1-28)
   - createdAt: Date (default Date.now)
   - isAutoCreated: Bool (default false)
   - @Relationship(deleteRule: .cascade) categories: [Category] (default [])
   - Computed: totalIncome, periodStart (Date using resetDay), nextPeriodStart (Date, 1 month after periodStart — used as exclusive upper bound, NO minus-1-second hack)

2. Category:
   - id: UUID (default UUID())
   - name: String (default ""), emoji: String (default "📦")
   - budgetedAmountCents: Int64 (default 0)
   - color: String (default "#007AFF"), sortOrder: Int (default 0)
   - isHidden: Bool (default false)
   - rollOverUnspent: Bool (default false)
   - @Relationship(deleteRule: .cascade) transactions: [Transaction] (default [])
   - @Relationship(inverse: \Budget.categories) budget: Budget?
   - @Relationship(deleteRule: .nullify) recurringExpenses: [RecurringExpense] (default [])
   - Computed: budgetedAmount: Decimal
   - func spentCents(in budget: Budget) -> Int64 — filters transactions where !isIncome AND date >= budget.periodStart AND date < budget.nextPeriodStart (half-open interval, NO <= with minus-1-second)
   - func spent(in budget: Budget) -> Decimal
   - func remainingCents(in budget: Budget) -> Int64

3. Transaction:
   - id: UUID (default UUID())
   - amountCents: Int64 (default 0), note: String (default "")
   - date: Date (default Date.now), isIncome: Bool (default false)
   - isRecurring: Bool (default false), createdAt: Date (default Date.now)
   - @Relationship(inverse: \Category.transactions) category: Category?
   - @Relationship(inverse: \RecurringExpense.generatedTransactions) recurringExpense: RecurringExpense?
   - Computed: amount: Decimal

4. RecurringExpense:
   - id: UUID (default UUID()), name: String (default "")
   - amountCents: Int64 (default 0), frequency: String (default "monthly")
   - nextDueDate: Date (default Date.now), isActive: Bool (default true)
   - @Relationship(inverse: \Category.recurringExpenses) category: Category?
   - @Relationship(deleteRule: .nullify) generatedTransactions: [Transaction] (default [])
   - Computed: amount, frequencyEnum (Frequency enum with weekly/biweekly/monthly/yearly)

Create a SchemaMigrationPlan (BudgetVaultMigrationPlan) with currentVersion = BudgetVaultSchemaV1.self and empty stages array (ready for v2 additions).

Create MoneyHelpers.swift: centsToDollars, dollarsToCents, parseCurrencyString.
Create CurrencyFormatter.swift: formats Int64 cents as locale-aware string using @AppStorage("selectedCurrency").
Create DateHelpers.swift: budgetPeriod(for month: Int, year: Int, resetDay: Int) -> (start: Date, end: Date).

Configure ModelContainer in BudgetVaultApp with schema: BudgetVaultSchemaV1.self, migrationPlan: BudgetVaultMigrationPlan.self.

Create PaywallStubView.swift — minimal view with lock icon, "Premium Feature" text, and dismiss button. This is used as placeholder until Step 7a.

Create a test view that: creates a Budget for March 2026 with resetDay=1, adds 2 categories, adds 3 transactions (2 in-period, 1 outside), verifies spentCents(in:) only counts in-period transactions.

ACCESSIBILITY (inline): All text uses .body/.title/.headline — no fixed font sizes. Test with Dynamic Type at largest setting.
```

**Verification:** Models compile, VersionedSchema works, Int64 cents math correct, date-filtered spentCents excludes out-of-period transactions, CurrencyFormatter outputs "$14.50" for 1450 cents.

---

### Prompt 2: Onboarding + Tab Navigation + Month Rollover

```
Create the onboarding flow, tab navigation, biometric lock, and month rollover for BudgetVault.

IMPORTANT: @Query ONLY works inside View structs. Do NOT put @Query inside @Observable classes.

1. ContentView:
   - If @AppStorage("hasCompletedOnboarding") is false → show OnboardingView
   - Else if @AppStorage("biometricLockEnabled") is true AND not yet authenticated → show BiometricLockView
   - Else → show MainTabView

2. BiometricLockView:
   - Uses LAContext.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics)
   - Shows app icon + "Unlock BudgetVault" + Face ID/Touch ID button
   - On success, sets a @State authenticated flag
   - Fallback to device passcode if biometric fails

3. OnboardingView using TabView(.page) with 3 pages:
   - Page 1: Large shield.fill, "Your money is nobody's business." Subtext about no banks, no third-party servers, no subscriptions. "Get Started →"
   - Page 2: CurrencyPickerView with searchable currencies. Save to @AppStorage("selectedCurrency"). "Next →"
   - Page 3: Income TextField + 4 default categories (🏠 Rent 30%, 🛒 Groceries 20%, 🚗 Transport 10%, 📦 Other 20%). Show "20% unallocated — add your own categories later!" "Start Budgeting" creates Budget + 4 Categories.
   Store completion in @AppStorage("hasCompletedOnboarding").

4. MainTabView with 5 tabs:
   - Dashboard (house.fill), Budget (creditcard.fill), History (clock.fill), Insights (chart.pie.fill), Settings (gearshape.fill)
   - Use placeholder views for tabs not yet built

5. Month Rollover in BudgetVaultApp.swift scenePhase handler (.active):
   - Read resetDay from @AppStorage("resetDay") (default 1). This is the central source of truth.
   - Determine the current budget period (month/year) based on today and resetDay.
   - Check if Budget exists for that period.
   - If not: CASCADING ROLLOVER — fill ALL missing months between the last existing Budget and the current period:
     ```
     var previousBudget = mostRecentExistingBudget
     while no budget exists for currentPeriod:
       nextMonth = previousBudget.month + 1 (handle year wrap)
       create newBudget for nextMonth by copying previousBudget's categories
       if rollOverUnspent AND remainingCents > 0: add to new category's budgetedAmountCents
       // Deficit does NOT carry — overspent categories reset to original budgetedAmountCents
       newBudget.isAutoCreated = true
       newBudget.resetDay = @AppStorage("resetDay") // frozen snapshot
       previousBudget = newBudget
     ```
   - This handles users who skip entire months (e.g., skip Feb, open in March → creates Feb first, then March).
   - Runs synchronously. No background task.

6. RecurringExpenseScheduler:
   - Runs in the SAME scenePhase .active handler, AFTER month rollover
   - For each active RecurringExpense where nextDueDate <= today:
     a. Create Transaction (amountCents, note=name, date=nextDueDate, isRecurring=true, recurringExpense link, category link)
     b. Advance nextDueDate by frequency interval
     c. Loop if still past due (catch up missed periods)
   - Save modelContext once after all processing

ACCESSIBILITY: Progress dots have accessibilityLabel "Step X of 3". All buttons have accessibilityHint. Dynamic Type everywhere.
```

**Verification:** Onboarding creates 4 categories (not 6). Tab bar visible. Month rollover works. Recurring auto-posting creates transactions. Biometric lock prompts on relaunch. Killing app and relaunching skips onboarding.

---

### Prompt 3: Dashboard

```
Build DashboardView for BudgetVault's first tab.

ARCHITECTURE: @Query in the View. Pass data to DashboardViewModel (@Observable) for computed values. ViewModel has NO @Query.

CRITICAL: All category queries must filter by budget == currentBudget. All spentCents calls must pass the current Budget object for date filtering.

1. @Query: Fetch Budget for current month/year. @Query categories WHERE budget == currentBudget AND isHidden == false, sorted by sortOrder. @Query last 5 transactions WHERE date >= currentBudget.periodStart AND date < currentBudget.nextPeriodStart, sorted by date desc.

2. Header: Month name + year. Remaining budget = totalIncomeCents − sum of non-income transaction amountCents in period.
   - Color + text label: green "On Track" (>50%), yellow "Watch It" (25-50%), red "Over Budget" (<25%)
   - DO NOT rely on color alone for status

3. Streak badge: "🔥 14" near header. Query consecutive days with ≥1 transaction. Store in @AppStorage("currentStreak") and @AppStorage("lastLogDate").

4. Envelope cards: Horizontal ScrollView, ~120pt wide. Emoji, name, progress bar, amounts via CurrencyFormatter.
   - **Tapping a card navigates to CategoryDetailView** (NavigationLink or .navigationDestination)

5. Recent transactions (last 5): emoji, note, amount (red/green), relative date.
   - **Tapping opens TransactionEditView** as sheet

6. Floating "+" button (56pt) → TransactionEntryView sheet.

7. Empty state: EmptyStateView with "Tap + to log your first expense."

ACCESSIBILITY: Envelope cards: accessibilityLabel "{emoji} {name}: spent {amount} of {budget}". Remaining budget: accessibilityValue with spoken dollar amount. Status text + color combined.
```

**Verification:** Dashboard renders with period-filtered data, envelope cards navigate to detail, transactions tap to edit, streak count shows, empty state renders when no data.

---

### Prompt 4: Transaction Entry + Edit + History

```
Build transaction entry, edit, and history for BudgetVault.

1. NumberPadView (reusable, @Binding<String>):
   - [1][2][3] / [4][5][6] / [7][8][9] / [.][0][⌫]
   - "." only once, max 2 decimal digits after. Backspace removes last char.
   - Display: 32pt bold, locale currency symbol prefix.
   - On save: String → Decimal → ×100 → Int64.

2. TransactionEntryView (.sheet):
   - Expense/Income toggle. NumberPadView. Category emoji scroll (expense only, 44pt, accent ring).
   - DatePicker (.compact, today). Note TextField with autocomplete.
   - "Save": validate amountCents > 0 AND category selected (expense). Haptic. Save. Dismiss.
   - After save: update @AppStorage("lastLogDate") and "currentStreak".

3. TransactionEditView (.sheet):
   - Same as Entry but accepts existing Transaction. Pre-populates all fields.
   - "Save Changes" updates existing. "Delete" with confirmationDialog.

4. TransactionListView (Tab 3):
   - @Query transactions sorted by date desc. Search by note. Filter: All/Expenses/Income + category emoji chips.
   - Grouped by day with subtotals. Tap → TransactionEditView.
   - Export toolbar button (ShareLink). Empty state.

ACCESSIBILITY: NumberPad buttons labeled "one", "two", etc. Amount has accessibilityValue. Transaction rows have accessibilityLabel combining all fields.
```

**Verification:** Create, edit, delete transactions. "14.50" saves as 1450 cents. History groups by day, search works, tap-to-edit works. Streak updates on save.

---

### Prompt 5: Budget Setup + Recurring Expenses

```
Build BudgetSetupView and RecurringExpenses for BudgetVault.

CRITICAL: @Query categories WHERE budget == currentBudget AND isHidden == false.

1. BudgetSetupView (Tab 2):
   - Income field (tappable → NumberPad sheet).
   - "Unallocated" = totalIncomeCents − sum(budgetedAmountCents). Red/green.
   - Category list sorted by sortOrder. Each: emoji, name, tappable amount (NumberPad).
   - .onMove for reorder. Swipe to archive.
   - "Add Category": if free AND count >= 6 → present PaywallStubView. Else → emoji picker, name, color, amount.
   - rollOverUnspent toggle per category.
   - Month navigation (< >) — past months read-only.

2. RecurringExpenseListView:
   - Accessible from Settings AND Budget tab toolbar.
   - Upcoming + Recently Posted + Inactive sections.
   - Add: if free AND count >= 3 → PaywallStubView. Else → form.
   - Tap to edit. Swipe to deactivate.
   - Empty state.

3. RecurringExpenseFormView:
   - Name, NumberPad amount, frequency picker, category picker, start date.
   - Edit mode: pre-populate + Delete button.

NOTE: Use PaywallStubView (already created in Step 1) for premium gates. It will be replaced with real PaywallView in Step 7a.

ACCESSIBILITY: Unallocated amount announced with sign. Reorder accessible via accessibility actions.
```

**Verification:** Budget allocation works. Unallocated reaches $0. Free limits enforced (6 categories, 3 recurring). rollOverUnspent toggle persists. Month nav shows past budgets read-only.

---

### Prompt 6: Charts & Insights

```
Build InsightsView for BudgetVault Tab 4 using Swift Charts (import Charts).

NO EXTERNAL API CALLS. All insights on-device.

1. Monthly Trend (FREE): LineMark, daily cumulative spending for current budget period. Filter transactions by periodStart..<nextPeriodStart (half-open interval).

2. Category Breakdown (FREE, current month): SectorMark donut. Category hex colors, percentage labels. Only categories with spentCents > 0.

3. PREMIUM: "vs. Last Month" comparison:
   - Previous month query: month == (currentMonth == 1 ? 12 : currentMonth - 1), year == (currentMonth == 1 ? currentYear - 1 : currentYear)
   - LazyVGrid cards: emoji, name, current total, previous total, delta with ↑↓ arrows
   - Handle case where previous month has no data gracefully

4. PREMIUM: InsightsEngine class — generateInsights(budget: Budget, previousBudget: Budget?) -> [Insight]:
   - Category >90% budget → warning
   - Spending velocity × remaining days > remaining budget → warning
   - Transaction > 2× category average → info
   - Spent less than previous month at same point → success
   - Logging streak count → success
   - Streak at risk (logged yesterday but not today and it's after 6pm) → nudge

5. PREMIUM: Top 3 highest-spending days.

6. Premium gating:
   - Use @AppStorage("isPremium") as TEMPORARY check.
   - NOTE FOR STEP 7a: This @AppStorage flag must be replaced with StoreKit entitlement verification. The flag alone is bypassable by users editing UserDefaults. Add a TODO comment in code: "// TODO: Step 7a — replace @AppStorage check with StoreKit entitlement"
   - Blur uses real user data (not placeholders). accessibilityLabel on blurred sections: "Premium feature. Tap to learn about upgrading."

ACCESSIBILITY: Chart elements have accessibilityLabel with data values. Insight cards announced with severity.
```

**Verification:** Charts render with real data. Insights detect patterns. Previous-month works across year boundary. Premium blur shows real data. No network calls.

---

### Prompt 7a: StoreKit IAP + PaywallView + Settings

```
Build StoreKit 2 IAP, the real PaywallView, and SettingsView for BudgetVault. This replaces PaywallStubView references throughout the app.

1. StoreKitManager (@Observable):
   - Products: "com.budgetvault.premium" (non-consumable), "com.budgetvault.tip" (consumable)
   - On init: Product.products(for:), start Transaction.updates listener
   - purchase(_ product:) async throws
   - var isPremium: Bool — check Transaction.currentEntitlements for premium product
   - Cache in @AppStorage("isPremium") for instant UI, but ALWAYS verify with entitlement on launch. The @AppStorage is a cache, not the source of truth.
   - restorePurchases()
   - Enable Family Sharing on the premium product in App Store Connect config

2. PaywallView (replaces PaywallStubView):
   - App icon, "Unlock BudgetVault Premium"
   - Feature list with SF Symbol checks: AI Insights, Unlimited Categories (vs 6), Unlimited Recurring (vs 3), Full CSV, Custom Icons, Historical Charts, Streak Freeze
   - "$19.99 one-time" large. "Compare to leading budget apps at $99/year" (NO competitor brand names)
   - Price is $14.99 one-time (launch pricing period is over)
   - "Family Sharing included" footer
   - "No subscription. No recurring charges. Ever."
   - Full-width Purchase button, Restore link

3. Find-and-replace ALL PaywallStubView references with PaywallView across the codebase.

4. SettingsView with Form:
   - Security: Face ID / Touch ID toggle (reads/writes @AppStorage("biometricLockEnabled"))
   - Profile: Name, currency picker, reset day (1-28) with note "Takes effect next month"
   - Data: Export CSV button, "Recurring Expenses" link
   - Notifications: Daily reminder toggle + time, weekly summary toggle, bill-due toggle
   - Appearance: App icon picker (premium), accent color
   - Premium: status or upgrade
   - About: version, privacy policy, tip jar
   - iCloud: HIDDEN (placeholder comment for Step 8)

5. Review Prompt: After under-budget month OR 14+ day streak. Suppress 48hrs after paywall decline. Max 3/year. Track in @AppStorage("reviewPromptCount") and @AppStorage("lastPaywallDecline").

ACCESSIBILITY: PaywallView fully accessible. Settings form labels clear.
```

**Verification:** StoreKit sandbox purchase works. PaywallStubView fully replaced. isPremium gates work everywhere. Settings persist. Review prompt fires correctly. Biometric toggle works.

---

### Prompt 7b: CSV Export + Import

```
Build CSV export and import for BudgetVault.

1. CSVExporter:
   - Columns: Date (ISO 8601), Category, Emoji, Note, Amount (dollars, 2 decimal), Type (Income/Expense)
   - Free: last 30 days. Premium: full history.
   - Returns temp file URL. Present via ShareLink.

2. CSVImporter:
   - Accept .csv via fileImporter (.csv UTType). Premium only — free users → PaywallView.
   - Auto-detect YNAB format: columns "Date, Payee, Category Group/Category, Memo, Outflow, Inflow"
   - Auto-detect generic format: Date, Category, Amount (or similar headers)

3. ImportMappingView:
   - Show preview of first 5 rows
   - If YNAB detected: auto-map columns, show confirmation
   - If generic: let user map columns via pickers

4. FREE TIER CATEGORY HANDLING:
   - Count unique categories in import file
   - If free user AND import categories > 6:
     → Show category selection screen: "Your import has {N} categories. Free accounts support 6. Select which to keep, or merge similar ones."
     → User picks 6 categories, remaining transactions get assigned to "📦 Other" (auto-created if needed)
     → Show "Upgrade to Premium for all {N} categories" button
   - Premium users: auto-create all categories

5. BUDGET ASSIGNMENT for imported transactions:
   - Group imported transactions by their date
   - For each date, find the Budget whose period contains that date (periodStart <= date < nextPeriodStart)
   - If no Budget exists for that period, auto-create one (with the same category structure as the nearest existing budget)
   - Assign the transaction's category to the matching category in that Budget
   - Show import summary: "Imported {N} transactions across {M} months"

6. Add "Import CSV" button to Settings Data section.

ACCESSIBILITY: Import mapping table accessible. Category selection checkboxes labeled.
```

**Verification:** CSV export produces valid file (open in Excel/Numbers). YNAB import auto-detects and maps correctly. Free tier category limit enforced with selection UI. Generic CSV maps with user guidance.

---

### Prompt 8: CloudKit Sync

```
Enable CloudKit sync for BudgetVault.

1. Update ModelContainer: CloudKit-enabled with cloudKitDatabase: .private("iCloud.com.budgetvault.app")

2. Verify all model defaults (already done in v3 — double-check):
   - Every String has default "", every Bool has default, every Int64 has default 0

3. CloudSyncService (@Observable):
   - Monitor NSPersistentCloudKitContainer.eventNotification
   - Properties: lastSyncDate, isSyncing, syncError
   - Display in Settings

4. iCloud toggle in Settings:
   - @AppStorage("iCloudSyncEnabled")
   - IMPORTANT: Cannot hot-swap ModelContainer at runtime. Instead:
     - On toggle change, show alert: "Enabling/disabling iCloud sync requires restarting the app."
     - Set the flag, then prompt user to quit and relaunch
     - On app launch, BudgetVaultApp reads the flag and configures the appropriate ModelContainer
   - This avoids invalidating all @Query by rebuilding at launch time only.

5. Fix marketing copy everywhere: "No third-party servers" NOT "No servers" (because iCloud IS a server).

6. Sync conflict: last-writer-wins (SwiftData/CloudKit default). No custom conflict UI for MVP.

WARNING: If sync causes crashes or data loss, disable and ship local-only.
```

**Verification:** Syncs between devices. Toggle requires restart (not hot-swap). No crashes. Local data preserved when iCloud off.

---

### Prompt 9: Widgets + App Intents

```
Add WidgetKit widgets and App Shortcuts to BudgetVault.

1. Widget Extension with App Group "group.com.budgetvault.shared":
   - Main app writes JSON summary to UserDefaults(suiteName:) on every transaction save and on foreground:
     { remainingBudgetCents, totalBudgetCents, percentRemaining, topCategories: [{emoji, name, spentCents, budgetedCents}] }
   - Include small BudgetVault logo in widget face for passive brand awareness

2. Small Widget (FREE): Progress ring + remaining amount + color. Logo watermark.
3. Medium Widget (PREMIUM ONLY): Ring + remaining (left). Top 3 categories with mini bars (right). Logo.
   - Widget data pipeline must check isPremium flag in the UserDefaults suite
   - Free users who add the medium widget see: ring + remaining + "Upgrade for category breakdown"
   - The JSON summary should include an `isPremium: Bool` field so the widget can gate itself

4. App Shortcuts (AppIntents):
   - "Add expense to BudgetVault" → deep link to TransactionEntryView
   - "How much budget is left?" → spoken remaining amount

5. WidgetCenter.shared.reloadAllTimelines() on transaction save and foreground.

ACCESSIBILITY: Widget accessibilityLabel includes remaining budget spoken naturally.
```

**Verification:** Widgets display correct data, update on save, Siri works.

---

### Prompt 10: Monthly Summary + Streak Mechanics + Notifications

```
Build the monthly summary, streak system, and notification service for BudgetVault.

1. MonthlySummaryView:
   - Not auto-modal. Dashboard shows banner "Your {month} summary is ready!" when previous month exists and hasn't been viewed (track with @AppStorage("lastSummaryViewed"))
   - Income vs spent with delta. Category over/under. "Under budget in X/Y" celebration.
   - Shareable ImageRenderer card: "I stayed under budget in 5/6 categories!" + logo + App Store URL. NO dollar amounts. **During dev/TestFlight:** Use placeholder URL "https://budgetvault.com" until App Store URL is assigned.

2. Streak System:
   - Storage: @AppStorage("currentStreak") Int, @AppStorage("lastLogDate") String (ISO date), @AppStorage("streakFreezesRemaining") Int (default 0, reset to 1 every Monday for premium). Also write to UserDefaults suite for widget access.
   - Known limitation: streak is per-device, NOT synced via CloudKit. Multi-device users will have independent streaks. (Acceptable for v1 — can add StreakRecord model in v1.1 if demand warrants.)
   - Streak freeze (premium): @AppStorage("streakFreezesRemaining") starts at 1, resets to 1 every Monday (check in scenePhase .active). If no log yesterday AND freeze > 0 → preserve streak, set freezes to 0.
   - "Streak at risk" notification if 8pm and no log today.
   - Celebration haptic + animation at 7, 14, 30, 60, 90 milestones.
   - Share cards at milestones.

3. NotificationService:
   - Daily reminder: configurable time, only if no transaction logged today. Rotate copy: "Don't forget to log today's expenses!" / "Quick check: anything to log?" / "Keep your streak alive! 🔥"
   - Bill-due reminder: 1 day before recurring expense nextDueDate
   - Weekly summary push: Sunday evening, "This week you spent $X across Y categories"
   - Streak-at-risk: 8pm if no log, "Your {N}-day streak is at risk!"

ACCESSIBILITY: Summary card alt text describes content for screen readers.
```

**Verification:** Summary banner appears, share card renders, streak tracks correctly, freeze works, notifications fire at correct times with correct conditions.

---

### Prompt 11: Accessibility Audit + Final Polish

```
Final comprehensive audit of BudgetVault.

1. Accessibility Audit (verify, fix gaps):
   - Every interactive element has accessibilityLabel
   - Every value display has accessibilityValue
   - No fixed font sizes — all Dynamic Type
   - No color-only indicators — all have text labels too
   - Blurred premium content has meaningful accessibilityLabel
   - VoiceOver navigation order makes sense on every screen
   - Tab bar items have accessibilityLabel
   - Test at largest Dynamic Type and smallest

2. Haptic Consolidation:
   - .medium impact on transaction save
   - selection feedback on category pick, tab change
   - .warning notification when category >100%
   - .success on under-budget month, streak milestones
   - Ensure all haptics work with system haptic setting

3. Performance:
   - App opens < 1 second. Dashboard renders immediately.
   - Lazy load InsightsView charts (compute on tab select, not on app launch).
   - Profile with Instruments: no excessive @Query re-fetches.

4. Edge Cases:
   - 0 income: show "Set your income in Budget tab" instead of divide-by-zero
   - First-ever month: no previous budget for comparison → hide comparison sections gracefully
   - Locale change: CurrencyFormatter reactive to @AppStorage currency
   - 28 → 31 day months: budget period handles gracefully via Calendar
   - No categories: cannot add transaction → show "Create a category in Budget tab first"
   - resetDay edge: resetDay = 31 but month has 30 days → use last day of month

5. Code Quality:
   - Remove all TODO comments (they should all be resolved by now)
   - Ensure PaywallStubView is fully replaced
   - Verify @AppStorage("isPremium") is always backed by StoreKit entitlement check on launch
   - Run SwiftLint if available
```

**Verification:** VoiceOver through every screen. Dynamic Type at largest. All edge cases handled. No TODOs remaining. No crashes on fresh install.

---

## Milestone Checklist (Revised)

| Step | Milestone | Verification |
|------|-----------|-------------|
| 1 | Models + VersionedSchema | Int64 math works, date-filtered spentCents correct, PaywallStubView exists |
| 2 | Onboarding + Tabs + Rollover | 4 categories created (not 6), tabs visible, rollover works, recurring auto-posts, biometric lock works |
| 3 | Dashboard | Period-filtered data, envelope tap → detail, transaction tap → edit, streak shows |
| 4 | Transactions | Create/edit/delete, "14.50" → 1450, history groups, search, streak updates |
| 5 | Budget + Recurring | Allocation, reorder, free limits (6 cats/3 recurring), rollOverUnspent persists |
| 6 | Charts & Insights | Charts render, year-boundary previous month works, blur shows real data, no network |
| 7a | StoreKit + Settings | Sandbox purchase, PaywallStub replaced, isPremium entitlement-backed, review prompt, biometric toggle |
| 7b | CSV Export/Import | Export valid, YNAB import works, free tier category selection UI works |
| 8 | CloudKit | Syncs, toggle requires restart (no hot-swap crash), "no third-party servers" copy |
| 9 | Widgets + Intents | Correct data, update on save, Siri responds, logo on widget |
| 10 | Summary + Streaks + Notifications | Summary banner, share cards, streak freeze, notification rotation |
| 11 | Accessibility + Polish | VoiceOver complete, Dynamic Type, edge cases, no TODOs, <1s launch |

**MVP Cut (3-4 weeks):** Steps 1-5 + 7a (StoreKit/Settings only). Ship budgeting without charts (6), CSV import (7b), sync (8), widgets (9). Add in v1.1.

---

## App Store Optimization (Revised)

- **App Name:** BudgetVault
- **Subtitle:** Private Budgeting, No Subscription
- **Keywords:** budget, budgeting, expense tracker, no bank, privacy, envelope, YNAB alternative, money, finance, spending
- **Category:** Finance
- **Price:** Free (with $14.99 one-time IAP, Family Sharing enabled)
- **Screenshot Strategy:**
  1. Privacy hero: Shield + "Your money is nobody's business."
  2. **Price comparison: "$14.99 once vs $99/year"** (slot 2 — this sells)
  3. Dashboard with envelope cards
  4. Quick entry number pad
  5. Charts & insights
  6. "No bank connection. No third-party servers. Ever."
- **Default Category Color Palette** (accessible, WCAG AA contrast on white): #007AFF (blue), #34C759 (green), #FF9500 (orange), #FF3B30 (red), #AF52DE (purple), #00C7BE (teal), #FF2D55 (pink), #5856D6 (indigo), #8E8E93 (gray), #FFD60A (yellow). These should be the default options in the color picker.
- **App Icon Direction:** A vault/lock metaphor in a modern gradient. Primary concept: a rounded rectangle (like a safe door) with a circular lock dial, using navy (#1a2744) to accent blue (#2563eb) gradient. Clean, minimal, recognizable at small widget size.
- **Description opening:** "BudgetVault is the budgeting app that respects your privacy. No bank connections, no third-party servers, no subscriptions. Just a beautiful, powerful budget that lives entirely on your device."

---

## Pre-Launch Checklist

- [ ] Create and host a privacy policy at budgetvault.com/privacy (required by Apple at submission)
- [ ] Verify "BudgetVault" is still available on App Store before submission
- [ ] File trademark application for "BudgetVault"
- [ ] Register budgetvault.com domain
- [ ] Claim @budgetvault on Twitter/X, Instagram, TikTok, Reddit
- [ ] Create landing page at budgetvault.com with email signup + App Store short URL
- [ ] Support YNAB CSV export format — mention in marketing
- [ ] Prepare comparison blog post: "Why I Switched from [leading budget app] to BudgetVault" (competitor names OK in blog/SEO — the no-names rule is only for in-app paywall)
- [ ] Submit to r/ynab, r/personalfinance, r/frugal when live
- [ ] Apply for Apple "Apps We Love" featuring
- [ ] Enable Family Sharing for IAP in App Store Connect
- [x] Price set to $14.99 one-time
- [ ] Prepare TestFlight beta with 50-100 users for reviews velocity on launch day
