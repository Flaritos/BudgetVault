# BudgetVault Development Roadmap — Post v3.0 Launch

**Created:** 2026-03-26
**Source:** 5-agent analysis (Growth, Technical, Competitive, Revenue, Platform)

---

## Strategic Summary

BudgetVault v3.0 is live. The foundation is strong. The next moves determine whether this becomes a $20K/yr side project or a $200K/yr business. The data across all 5 analyses converges on clear priorities:

**The single most important insight:** The #1 reason manual-entry budgeting apps lose users is falling behind and feeling unable to catch up. Every high-impact feature below either prevents this (weekly pulse, quick-add, reconciliation) or recovers from it (catch-up mode).

---

## Priority Matrix (All 5 Agents Agree)

### TIER 1: Do This Month (Weeks 1-4)
*Quick wins that plug retention holes and set up revenue growth*

| # | Feature | Why | Effort | Impact |
|---|---------|-----|--------|--------|
| 1 | **Weekly Spending Pulse Notification** | Highest ROI per engineering hour. Re-engages lapsed users without being spammy. Copilot credits this as their #1 retention feature. | 3-5 days | Retention ⬆⬆⬆ |
| 2 | **Buffer Days Metric** | YNAB's most motivational metric. One computed property + one dashboard card. "Your budget could last 47 more days." | 1-2 days | Retention ⬆⬆ |
| 3 | **Smart Quick-Add Templates** | One-tap "Coffee $5.50" chips from historical patterns. Reduces transaction entry from 15s to 3s. | 1-2 weeks | Retention ⬆⬆⬆ |
| 4 | **Reconciliation Flow** | "What's your actual bank balance?" → auto-adjust. Prevents balance drift, the #1 long-term churn cause. Dealbreaker for YNAB switchers. | 3-5 days | Retention ⬆⬆⬆ |
| 5 | **Price Increase to $14.99** | $14.99 is still 85% cheaper than YNAB per year. Execute with 7-day countdown marketing. | 1 day | Revenue ⬆⬆⬆ |

### TIER 2: Do Next Month (Weeks 5-8)
*Revenue unlock + viral mechanics + platform expansion*

| # | Feature | Why | Effort | Impact |
|---|---------|-----|--------|--------|
| 6 | **iPad Support** | Change one line in project.yml, add NavigationSplitView for wide screens. Unlocks iPad + Mac (Designed for iPad) + visionOS compatibility for free. | 2-3 weeks | Acquisition ⬆⬆ |
| 7 | **Catch-Up Mode** | "Welcome back" flow for 3+ day absence. Shows auto-posted bills, suggests likely expenses, non-judgmental tone. Turns churn moments into re-engagement. | 1-2 weeks | Retention ⬆⬆⬆ |
| 8 | **Split Transactions** | $150 at Target = $80 groceries + $40 clothes + $30 home. Weekly friction point for everyone. YNAB parity gap. | 1 week | Retention ⬆⬆ |
| 9 | **Monthly Wrapped Share Optimization** | The viral loop. Optimize the share card for Instagram Stories size, add "Save to Photos" with proper permissions, track share events. | 3-5 days | Referral ⬆⬆⬆ |
| 10 | **Tip Jar Optimization** | Move prompt to post-Wrapped and post-30-day streak. Add 3 tiers with food labels ($1.99/$4.99/$9.99). | 2-3 days | Revenue ⬆ |

### TIER 3: Do Quarter 2 (Weeks 9-16)
*Competitive moat + higher price justification*

| # | Feature | Why | Effort | Impact |
|---|---------|-----|--------|--------|
| 11 | **Couple/Partner Sharing** | The feature that justifies $24.99. Unlocks 40-60% of the budgeting market. CKShare within Apple's privacy model. Doubles user base per acquisition. | 3-4 weeks | Revenue ⬆⬆⬆, Retention ⬆⬆⬆ |
| 12 | **Price Increase to $24.99** | After partner sharing ships, the value justifies the price. Execute with 14-day countdown. | 1 day | Revenue ⬆⬆⬆ |
| 13 | **Transaction Tags** | "vacation", "tax-deductible", "shared". Cross-category analysis. Matches Copilot's differentiator. | 1-2 weeks | Retention ⬆⬆ |
| 14 | **Cash Flow Forecasting** | "You'll have $X left by month end based on upcoming bills." Uses existing RecurringExpense data + ML engine. | 2 weeks | Retention ⬆⬆ |
| 15 | **Apple Watch Quick-Add** | Log expenses from your wrist in 3 seconds. Strongest differentiator vs web-based competitors. | 3-4 weeks | Retention ⬆⬆, Acquisition ⬆ |

### TIER 4: Do Quarter 3 (Weeks 17-24)
*Scale and mature*

| # | Feature | Why | Effort | Impact |
|---|---------|-----|--------|--------|
| 16 | **iOS 18 Migration** | Bump deployment target. Unlock #Index for performance, dynamic @Query predicates, App Intents expansion. | 2-3 weeks | Performance ⬆⬆⬆ |
| 17 | **Referral System** | Shareable promo codes for premium trial. Highest-quality user acquisition channel. | 1-2 weeks | Acquisition ⬆⬆ |
| 18 | **Localization** (DE, ES, FR) | Envelope budgeting popular in Germany. Privacy resonates in EU (GDPR). Three highest-value non-English markets. | 3-4 weeks | Acquisition ⬆⬆ |
| 19 | **CI/CD Pipeline** | GitHub Actions for build/test on PR. Fastlane for TestFlight automation. Screenshot generation. | 1 week | Velocity ⬆⬆ |
| 20 | **Test Coverage to 60%** | Model tests, scheduler tests, ML engine tests. Prevents regressions as codebase grows. | 2-3 weeks | Quality ⬆⬆ |

---

## What NOT to Do

All 5 agents independently agreed on these:

| Don't | Why |
|-------|-----|
| **Don't add a subscription** | "No subscription" is the marketing wedge. Don't dilute it. |
| **Don't build for Android** | Conflicts with "built for Apple's privacy platform" brand. 12-24 weeks for lower per-user revenue. |
| **Don't build a web app** | Server-side anything violates "data never leaves device." |
| **Don't add bank sync** | Plaid/Yodlee complaints are the #1 reason users leave Monarch/YNAB. Your weakness is their weakness. |
| **Don't add third-party analytics** | Invalidates "Data Not Collected" privacy label — the biggest differentiator. |
| **Don't lower the price** | $14.99 is already undervalued. Move UP, not down. |

---

## Revenue Projections

| Scenario | Downloads/Day | Conversion | Price | Monthly Net | Annual Net |
|----------|--------------|-----------|-------|-------------|------------|
| Current | 50 | 8% | $14.99 | $1,528 | $18,340 |
| After Tier 1 | 100 | 10% | $14.99 | $3,822 | $45,869 |
| After Tier 2+3 | 150 | 12% | $24.99 | $10,769 | $129,228 |
| Optimistic | 200 | 12% | $24.99 | $15,294 | $183,527 |

**Path to $10K/month:** Ship Tier 1+2 features, raise price to $24.99 after partner sharing, scale Apple Search Ads to $3K/month.

---

## Positioning Evolution

| Phase | Message |
|-------|---------|
| **Now** | "The budget app that works without your bank login. $14.99. Once." |
| **After partner sharing** | "Budget together, privately. $24.99 for your whole family." |
| **At scale** | "The vault for your money. Zero tracking. Zero subscriptions. Just budgeting." |

---

## Technical Priorities (Parallel Track)

Run alongside feature work:

1. **Fix unbounded @Query** — Replace with FetchDescriptor in .task for all views (performance)
2. **Consolidate budget dedup** — Single shared function instead of duplicated in 2 files
3. **Add Keychain access control** — `kSecAttrAccessibleAfterFirstUnlock` on premium status
4. **Set up GitHub Actions** — Build + test on PR, Fastlane for TestFlight
5. **Schema V2 prep** — Document migration plan for iOS 18 target bump

---

## Next Immediate Action

Start with item #1: **Weekly Spending Pulse Notification**. It's 3-5 days of work, uses existing infrastructure, and is the single highest-ROI feature for retention. Ship it as v3.0.1 this week.
