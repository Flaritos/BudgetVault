# BudgetVault v3.0 Option C — Design-First Rebuild

## Design Philosophy

BudgetVault should feel like **opening a vault full of your money**. Every screen should reinforce: security, control, clarity. The navy-to-blue gradient IS the brand. The vault dial IS the icon. Envelopes ARE how you budget.

**Three words:** Premium. Private. Powerful.

---

## Color & Visual Language

### Hero Treatment
Every primary screen gets a **navy gradient header** that bleeds into the content. This is the single most recognizable visual element of BudgetVault.

```
┌──────────────────────────────────┐
│ ░░░░ Navy-to-Blue Gradient ░░░░ │ <- Brand presence
│ ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ │
│         Hero Content             │
│ ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ │
├──────────────────────────────────┤
│                                  │ <- Content on white/system bg
│   Cards, Lists, Details          │
│                                  │
└──────────────────────────────────┘
```

### Cards
All cards use:
- `BudgetVaultTheme.cardBackground` (adapts light/dark)
- `cornerRadius: radiusLG` (16pt)
- Shadow: `.shadow(color: .black.opacity(0.06), radius: 8, y: 4)`
- Internal padding: `spacingLG` (16pt)

### Amounts
All money amounts use `.rounded` design font. Period.

---

## Navigation: 3 Tabs (Not 5, Not Swipe)

```
[ Home ]  [ History ]  [ Settings ]
```

- **Home** — The hero. Daily allowance, spending dial (compact), envelope cards, insights
- **History** — Timeline + transaction list with search/filter
- **Settings** — Everything else (recurring, debt, net worth, theme, export, premium)

Why 3 tabs:
- 5 tabs was too many (v2.0)
- Swipe modes were undiscoverable (v3.0 first attempt)
- 3 tabs is the sweet spot: simple, discoverable, iOS-native

---

## Screen 1: Home (The Hero Screen)

This is 90% of the app experience. It must be stunning.

### Layout (top to bottom):

```
┌──────────────────────────────────┐
│ ░░░░░░░ NAVY GRADIENT ░░░░░░░░ │
│                                  │
│    $47.00/day                    │  <- Daily allowance HERO
│    $1,410 of $5,000 remaining   │
│                                  │
│    [═══════════░░░░░]  Day 20/31│  <- Progress bar
│                                  │
│    🔥 12 day streak     ⚙️      │
│ ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ │
├──────────────────────────────────┤
│                                  │
│  Envelopes                       │
│  ┌────────┐ ┌────────┐ ┌──────┐ │  <- Horizontal scroll
│  │🏠 Rent │ │🛒 Groc │ │🚗 Tr│ │     Colored cards
│  │$450 left│ │$200 lft│ │$80  │ │     with progress
│  │████░░░░│ │██████░░│ │█████│ │
│  └────────┘ └────────┘ └──────┘ │
│                                  │
│  Quick Insights                  │
│  ┌──────────────────────────────┐│
│  │ 📊 On track to save $200    ││
│  │    this month                ││
│  └──────────────────────────────┘│
│                                  │
│  Upcoming Bills                  │
│  ┌──────────────────────────────┐│
│  │ Netflix         $15.99  3d  ││
│  │ Phone Bill      $85.00  7d  ││
│  └──────────────────────────────┘│
│                                  │
│  Recent Transactions             │
│  ┌──────────────────────────────┐│
│  │ 🛒 Groceries    -$45.23     ││
│  │ ☕ Coffee        -$5.50      ││
│  │ 💰 Paycheck    +$2,500      ││
│  └──────────────────────────────┘│
│                                  │
│         [+ Add Expense]          │  <- FAB or bottom button
│                                  │
└──────────────────────────────────┘
```

### Hero Section Details
- **Background:** `BudgetVaultTheme.heroBrandGradient` (navy dark → bright blue)
- **All text white** on the gradient
- **Daily allowance** is the BIGGEST number (heroAmount font, 40pt+ bold rounded)
- **Remaining/total** below in subheadline
- **Progress bar** showing day-of-period progress (white track, white fill)
- **Streak badge** if active (fire emoji + count in a capsule)
- **VaultDialMark** as subtle watermark (20% opacity, 24pt, top-right)
- **Settings gear** in top-right (opens settings sheet, not a tab)
- No navigation title — the hero IS the title

### Envelope Cards
- Horizontal scroll below the hero
- Each card: ~140pt wide, ~100pt tall
- Category color as left border or top accent stripe
- Emoji + name + remaining amount + mini progress bar
- Tap → full category detail

### Quick Insights
- One-line insight cards from InsightsEngine
- Rotates or shows top 1-2 insights
- Tap → full insights view (sheet)

### Add Expense
- Large, prominent button at the bottom OR
- FAB in bottom-right with the vault-door-opening animation on tap
- Opens TransactionEntryView (the full one from v2.0, it works well)

---

## Screen 2: History

### Layout:

```
┌──────────────────────────────────┐
│ ░░░ NAVY GRADIENT (shorter) ░░░ │
│   March 2026        < Today >   │
│ ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ │
├──────────────────────────────────┤
│ [All] [Expenses] [Income]       │  <- Segmented control
│                                  │
│ 🏠🛒🚗🍽🎬💰  category chips    │
│                                  │
│ Today                    -$50.73│
│ ┌──────────────────────────────┐│
│ │ 🛒 Groceries    -$45.23     ││
│ │ ☕ Coffee        -$5.50      ││
│ └──────────────────────────────┘│
│                                  │
│ Yesterday                -$12.00│
│ ┌──────────────────────────────┐│
│ │ 🍽 Lunch         -$12.00     ││
│ └──────────────────────────────┘│
│                                  │
│ 🔍 Search notes                 │
└──────────────────────────────────┘
```

- **Short navy gradient header** with month/year and navigation
- **Grouped by day** with daily totals
- **Search at bottom** (iOS standard `.searchable`)
- **Swipe actions** on rows (delete, duplicate)
- This is basically the v2.0 HistoryView but with the gradient header

---

## Screen 3: Settings

Standard iOS settings list. No gradient needed here.
Contains: recurring expenses, debt tracking, net worth, insights (full view),
theme picker, notifications, export/import, premium, about.

---

## Onboarding: Chat Style (Keep from v3.0)

The chat onboarding was good. Keep it. But fix:
- Editable category names/emojis/percentages
- Category limit = 6
- Skip button that lands on empty Home state
- Navigation hint at the end

---

## Transaction Entry: Full Sheet (Keep v2.0's)

The v2.0 `TransactionEntryView` with number pad, category chips, note,
templates, quick amounts — it all works. Keep it as-is. Open via FAB.

---

## Key Principles

1. **Navy gradient = BudgetVault.** If a screen doesn't have it, it's not BudgetVault.
2. **Daily allowance is the hero metric.** Not remaining budget, not total spent. "How much can I spend TODAY?"
3. **Envelope cards with color = visual budget.** Users should SEE their money in categories.
4. **3 tabs maximum.** Home, History, Settings. That's it.
5. **White text on gradient, dark text on white.** Never reversed.
6. **Every card has shadow + radius.** Consistent depth.
7. **Rounded fonts for money. System fonts for labels.** Always.
