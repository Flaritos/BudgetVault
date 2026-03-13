# BudgetVault Marketing Plan

## Status
- App submitted for review (March 9, 2026)
- Website live at budgetvault.io
- Bundle ID: io.budgetvault.app
- Price: Free + $9.99 one-time IAP (launch pricing, planned increase to $19.99)

---

## Apple Search Ads Strategy

### Campaign Structure ($13-20/day)

**Campaign 1: Brand Defense ($2/day)**
- Keywords: "budgetvault", "budget vault"
- Match: Exact
- Purpose: Prevent competitors bidding on your name

**Campaign 2: Envelope Budgeting ($8/day)**
- Keywords (exact): "envelope budgeting", "envelope budget app", "zero based budget", "budget envelopes", "cash envelope system"
- Target CPA: $2-3

**Campaign 3: Competitor Conquest ($5/day) -- add after week 2**
- Keywords (exact): "ynab", "ynab alternative", "goodbudget", "every dollar app", "mint budget app", "monarch money alternative"
- Target CPA: $2.50-4

**Campaign 4: Privacy + Budget Discovery ($3/day)**
- Keywords (broad): "private budget app", "budget app no subscription", "offline budget app", "budget app no account"
- Target CPA: $1.50-2.50

**Campaign 5: Search Match Discovery ($2/day)**
- Search Match enabled, no keywords
- Review weekly, graduate winners to exact match

### Monthly Budget: $390-600

---

## Reddit Launch Posts (6 Drafts)

### 1. r/ynab
**Title:** After 3 years with YNAB, I built my own envelope budgeting app -- one-time purchase, no subscription

Key points: YNAB CSV import works, same core workflow, $9.99 one-time, no cloud accounts. Honest about what it doesn't do (no bank syncing, no deep goal timelines). Offer promo codes.

### 2. r/privacy
**Title:** I built a budgeting app with zero analytics, zero tracking, and Apple's "Data Not Collected" privacy label -- here's how the architecture works

Key points: No Firebase/Amplitude/Mixpanel, no Meta SDK, SwiftData on-device, CloudKit goes to user's iCloud only, Face ID via Secure Enclave, ML runs on-device. Ask for feedback on Apple ecosystem trust tradeoffs.

### 3. r/iphone
**Title:** [Self-Promotion] I built an envelope budgeting app designed to feel like a native iOS app, not a web wrapper

Key points: Widgets, Siri Shortcuts, Face ID, iCloud Sync, Dynamic Type, Dark Mode, haptic feedback. Built entirely in SwiftUI.

### 4. r/personalfinance
**Title:** The envelope budgeting method helped me stop living paycheck-to-paycheck -- here's how it works and the tools I use

Key points: Educational post about envelope method. Mentions multiple tools (physical envelopes, spreadsheets, YNAB, BudgetVault, Goodbudget). Disclose developer status. Method matters more than tool.

### 5. r/frugal
**Title:** I was paying $100/year for a budgeting app. Built my own for a one-time cost instead.

Key points: Cost comparison table (YNAB $495 over 5 years vs BudgetVault $9.99). Acknowledge spreadsheets are most frugal option. Self-deprecating humor about hourly rate building it.

### 6. r/apple
**Title:** [Self-Promotion Saturday] I'm a solo developer who spent a year building a budgeting app with SwiftUI + SwiftData -- lessons learned

Key points: Technical lessons (SwiftData + Decimal corruption, @Query rigidity, StoreKit Transaction collision, CloudKit sync quirks, widgets for retention).

### Reddit Rules
- Never post in more than 2 subreddits same day
- Spread across 2-3 weeks
- Always disclose developer status
- Respond to every comment for 48 hours
- Use personal account, not branded
- Start with r/personalfinance and r/privacy, then r/ynab and r/frugal, then r/iphone and r/apple

---

## Product Hunt Launch

**Timing:** Tuesday or Wednesday, 2-3 days AFTER App Store approval (get initial reviews first)
**Go live:** 12:01 AM PT

**Tagline (60 chars):** Envelope budgeting that never leaves your device

**Description:** BudgetVault is a privacy-first envelope budgeting app for iPhone. Every dollar gets a job, and every byte stays on your device. No accounts, no cloud sync required, no subscriptions. On-device ML learns your spending patterns without sending data anywhere. Free core features. One-time $9.99 premium unlock.

**Launch day:** Share PH link to email list + Twitter. Respond to every comment within 30 min for first 12 hours.

---

## Twitter/X Strategy

See launch-content-calendar.md for full 14-day calendar with ready-to-post tweets.

### Profile Setup
- Handle: @BudgetVaultApp
- Bio: "Privacy-first envelope budgeting. $9.99 once, not $100/year. No accounts, no servers, no data collection. budgetvault.io"
- Pinned: Launch announcement

### Content Themes (rotate)
1. Privacy contrast (provocative)
2. Anti-subscription (spicy)
3. Feature highlights (demos)
4. Social proof / milestones
5. Budgeting tips (educational)
6. Behind-the-scenes indie dev
7. Subtle comparisons

### Cadence
- Launch week: 3-4 posts/day
- Ongoing: 1 post/day, 3x/week minimum

---

## Content Marketing (budgetvault.io/blog)

### Pre-Launch
1. "Why Your Budget App Knows More About You Than Your Bank" (privacy expose, 1500 words)
2. "Envelope Budgeting in 2026: The Complete Guide" (evergreen SEO, 2500 words)

### Launch Week
3. "Why We Chose One-Time Pricing in a Subscription World" (share on HN, Twitter, Reddit)

### Post-Launch (monthly)
4. "How to Switch from YNAB to BudgetVault (With CSV Import)" (migration guide)
5. "On-Device ML for Personal Finance" (technical deep-dive for HN/r/privacy)
6. "The Real Cost of Free Budget Apps" (if it's free, you're the product)

---

## Monthly Budget Allocation ($500)

| Channel | Budget | Notes |
|---------|--------|-------|
| Apple Search Ads | $350 | Primary paid acquisition |
| Canva Pro | $13 | Social media graphics |
| Reserve | $137 | Scale what works |
| Reddit/Twitter/PH | $0 | Organic only |

---

## Price Increase Strategy

Use the $9.99 -> $19.99 increase as a marketing event:
1. Pre-launch: "Lock in $9.99 before it doubles"
2. App Store description: "Introductory pricing"
3. 30 days post-launch: Email "Price goes up in 7 days"
4. Website countdown banner 7 days before
5. After increase: "X people locked in $9.99" as social proof

---

## Key Metrics to Track

| Metric | Target | Tool |
|--------|--------|------|
| Daily downloads | 50+/day month 1 | App Store Connect |
| Free-to-premium conversion | 8-15% | App Store Connect |
| App Store conversion rate | 25-35% | App Store Connect |
| Average rating | 4.5+ stars | App Store Connect |
| ASA CPA | Under $3 | Search Ads |
| ASA tap-through rate | Above 8% | Search Ads |
| Keywords in top 10 | 10+ | Manual search |
