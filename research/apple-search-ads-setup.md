# Apple Search Ads Setup Guide for BudgetVault

Step-by-step walkthrough for setting up Apple Search Ads campaigns. Written for someone who has never used the platform before.

---

## Part 1: Account Setup

### Step 1: Create Your Search Ads Account

1. Go to https://searchads.apple.com
2. Click "Start Now" or "Sign In"
3. Sign in with the same Apple ID used for your Apple Developer account
4. You will land on the "Welcome to Apple Search Ads" page
5. Select "Apple Search Ads Advanced" (not Basic -- Basic does not allow campaign-level control)

### Step 2: Complete Account Details

1. On the Account Information screen, fill in:
   - **Account Name**: BudgetVault
   - **Country or Region**: United States (you can add more later)
   - **Currency**: USD
   - **Time Zone**: Your local time zone (this affects when daily budgets reset)
2. Agree to the Apple Search Ads Terms of Service
3. Click "Save"

### Step 3: Add Payment Method

1. In the top-right menu, click your account name, then "Settings"
2. Click "Billing" in the left sidebar
3. Click "Add Payment Method"
4. Enter your credit card details (Apple also accepts Apple Pay in some regions)
5. Click "Save"
6. Set a **Monthly Budget Cap** of $600 (this is your safety net -- it pauses all campaigns if total spend hits this number in a calendar month)

### Step 4: Link Your App

1. When creating your first campaign (next section), you will search for your app
2. Search for "BudgetVault" or your bundle ID `io.budgetvault.app`
3. Your app must be live on the App Store (or at least approved and scheduled) before it appears in Search Ads
4. If your app is not yet live, stop here and return after App Store approval

---

## Part 2: Campaign Setup

Total daily budget across all campaigns: $20/day ($600/month).

Create campaigns in this exact order. Each campaign has a single ad group.

---

### Campaign 1: Brand Defense

**Purpose:** Prevent competitors from stealing people searching for your app by name. This campaign should run from day one.

#### Create the Campaign

1. Click "Create Campaign" from the dashboard
2. **Search results** campaign type (not Today tab or Search tab)
3. Select your app: BudgetVault
4. Fill in these fields:

| Field | Value |
|-------|-------|
| Campaign Name | `Brand Defense` |
| Countries or Regions | United States |
| Daily Budget | `$2.00` |
| Campaign Negative Keywords | (leave empty for now) |

5. Click "Continue to Create Ad Group"

#### Create the Ad Group

| Field | Value |
|-------|-------|
| Ad Group Name | `Brand Terms - Exact` |
| Default Max CPT Bid | `$0.50` |
| CPA Goal | (leave blank -- brand terms are cheap, no need to constrain) |
| Automatic Ad | On (let Apple generate the ad from your App Store listing) |

#### Audience Settings (within the Ad Group)

| Field | Value |
|-------|-------|
| Customer Type | All Users |
| Demographics - Age | All |
| Demographics - Gender | All |
| Device | iPhone |
| Locations | United States |

#### Add Keywords

Click "Add Keywords" and enter each keyword below. Set every keyword to **Exact** match.

| Keyword | Match Type |
|---------|-----------|
| `budgetvault` | Exact |
| `budget vault` | Exact |
| `budget vault app` | Exact |
| `budgetvault app` | Exact |
| `budgetvault budget` | Exact |
| `budget vault envelope` | Exact |

To set match type: after typing each keyword, click the dropdown next to it and select "Exact Match" (the icon looks like `[keyword]` with brackets).

#### Search Match Setting

- **Search Match**: Off (you only want exact brand terms here)

Click "Create" to save the campaign and ad group.

---

### Campaign 2: Envelope Budgeting

**Purpose:** Capture people actively searching for envelope budgeting solutions. This is your highest-intent, highest-volume campaign.

#### Create the Campaign

1. Click "Create Campaign"
2. Select your app: BudgetVault

| Field | Value |
|-------|-------|
| Campaign Name | `Envelope Budgeting` |
| Countries or Regions | United States |
| Daily Budget | `$8.00` |

3. Click "Continue to Create Ad Group"

#### Create the Ad Group

| Field | Value |
|-------|-------|
| Ad Group Name | `Envelope Terms - Exact` |
| Default Max CPT Bid | `$1.50` |
| CPA Goal | `$2.50` |

#### Audience Settings

| Field | Value |
|-------|-------|
| Customer Type | All Users |
| Demographics - Age | All |
| Demographics - Gender | All |
| Device | iPhone |
| Locations | United States |

#### Add Keywords (all Exact match)

| Keyword | Match Type |
|---------|-----------|
| `envelope budgeting` | Exact |
| `envelope budgeting app` | Exact |
| `envelope budget` | Exact |
| `envelope budget app` | Exact |
| `budget envelopes` | Exact |
| `cash envelope system` | Exact |
| `cash envelope app` | Exact |
| `cash envelope budgeting` | Exact |
| `digital envelope system` | Exact |
| `digital envelope budget` | Exact |
| `virtual envelope budgeting` | Exact |
| `zero based budget` | Exact |
| `zero based budget app` | Exact |
| `zero based budgeting` | Exact |
| `zero based budgeting app` | Exact |
| `every dollar gets a job` | Exact |
| `give every dollar a job` | Exact |
| `assign every dollar` | Exact |
| `envelope method budget` | Exact |
| `budget categories app` | Exact |

#### Search Match Setting

- **Search Match**: Off

Click "Create."

---

### Campaign 3: Competitor Conquest

**Purpose:** Show your ad when people search for competitor apps. Do NOT launch this on day one. Wait until you have at least 2 weeks of data and some App Store reviews.

**When to launch:** 2 weeks after your app goes live.

#### Create the Campaign

| Field | Value |
|-------|-------|
| Campaign Name | `Competitor Conquest` |
| Countries or Regions | United States |
| Daily Budget | `$5.00` |

#### Create the Ad Group

| Field | Value |
|-------|-------|
| Ad Group Name | `Competitor Names - Exact` |
| Default Max CPT Bid | `$2.00` |
| CPA Goal | `$3.00` |

#### Audience Settings

| Field | Value |
|-------|-------|
| Customer Type | All Users |
| Demographics - Age | All |
| Demographics - Gender | All |
| Device | iPhone |
| Locations | United States |

#### Add Keywords (all Exact match)

| Keyword | Match Type |
|---------|-----------|
| `ynab` | Exact |
| `ynab app` | Exact |
| `ynab alternative` | Exact |
| `ynab replacement` | Exact |
| `you need a budget` | Exact |
| `you need a budget alternative` | Exact |
| `goodbudget` | Exact |
| `goodbudget alternative` | Exact |
| `goodbudget app` | Exact |
| `every dollar` | Exact |
| `every dollar app` | Exact |
| `everydollar` | Exact |
| `everydollar app` | Exact |
| `everydollar alternative` | Exact |
| `mint budget` | Exact |
| `mint budget app` | Exact |
| `mint alternative` | Exact |
| `monarch money` | Exact |
| `monarch money alternative` | Exact |
| `copilot money alternative` | Exact |
| `simplifi alternative` | Exact |
| `pocketguard alternative` | Exact |
| `budget app like ynab` | Exact |
| `cheaper than ynab` | Exact |
| `ynab too expensive` | Exact |
| `budget app no subscription` | Exact |

#### Search Match Setting

- **Search Match**: Off

Click "Create."

---

### Campaign 4: Privacy + Budget Discovery

**Purpose:** Reach people searching for privacy-focused or no-subscription budget apps. These are broad match keywords, so Apple will match related searches too.

#### Create the Campaign

| Field | Value |
|-------|-------|
| Campaign Name | `Privacy + Budget Discovery` |
| Countries or Regions | United States |
| Daily Budget | `$3.00` |

#### Create the Ad Group

| Field | Value |
|-------|-------|
| Ad Group Name | `Privacy Budget - Broad` |
| Default Max CPT Bid | `$1.50` |
| CPA Goal | `$2.00` |

#### Audience Settings

| Field | Value |
|-------|-------|
| Customer Type | All Users |
| Demographics - Age | All |
| Demographics - Gender | All |
| Device | iPhone |
| Locations | United States |

#### Add Keywords (all Broad match)

| Keyword | Match Type |
|---------|-----------|
| `private budget app` | Broad |
| `budget app no subscription` | Broad |
| `offline budget app` | Broad |
| `budget app no account` | Broad |
| `budget app privacy` | Broad |
| `budget app no tracking` | Broad |
| `budget app one time purchase` | Broad |
| `budgeting app buy once` | Broad |
| `secure budget app` | Broad |
| `budget app no login` | Broad |
| `simple budget app iphone` | Broad |
| `personal budget tracker` | Broad |
| `spending tracker private` | Broad |
| `money tracker no ads` | Broad |

To set Broad match: after typing each keyword, click the dropdown and select "Broad Match."

#### Search Match Setting

- **Search Match**: Off (the broad keywords already provide discovery)

Click "Create."

---

### Campaign 5: Search Match Discovery

**Purpose:** Let Apple find search terms you have not thought of. This campaign has no manual keywords. Apple matches your ad to searches it thinks are relevant based on your App Store metadata.

#### Create the Campaign

| Field | Value |
|-------|-------|
| Campaign Name | `Search Match Discovery` |
| Countries or Regions | United States |
| Daily Budget | `$2.00` |

#### Create the Ad Group

| Field | Value |
|-------|-------|
| Ad Group Name | `Search Match - Auto` |
| Default Max CPT Bid | `$1.00` |
| CPA Goal | `$2.50` |

#### Audience Settings

| Field | Value |
|-------|-------|
| Customer Type | All Users |
| Demographics - Age | All |
| Demographics - Gender | All |
| Device | iPhone |
| Locations | United States |

#### Keywords

- Do NOT add any manual keywords
- This campaign relies entirely on Search Match

#### Search Match Setting

- **Search Match**: On

#### Negative Keywords for This Campaign

Add all keywords from Campaigns 1-4 as **negative keywords** in this campaign. This prevents Search Match from bidding on terms you are already targeting in other campaigns.

To add negative keywords:
1. In the ad group, click "Negative Keywords"
2. Click "Add Negative Keywords"
3. Paste in all keywords from Campaigns 1-4 (set all to Exact match)

This ensures Search Match only finds genuinely new search terms.

Click "Create."

---

## Part 3: Negative Keywords (All Campaigns)

Add these as **campaign-level negative keywords** to every campaign (1 through 5). They prevent your ad from showing on irrelevant searches.

To add campaign-level negative keywords:
1. Click on a campaign name
2. In the left sidebar, click "Negative Keywords"
3. Click the "Campaign Negative Keywords" tab (not Ad Group)
4. Click "Add Negative Keywords"
5. Add each keyword below as **Exact** match

### Negative Keywords List

**Platform irrelevant:**
- `android`
- `android budget app`
- `samsung budget app`
- `google play`

**Price mismatch:**
- `free budget app`
- `free budgeting app`
- `free money tracker`
- `free expense tracker`
- `completely free budget`

**Wrong product category:**
- `business budget`
- `business budgeting software`
- `enterprise budget`
- `corporate budget`
- `construction budget`
- `wedding budget`
- `wedding budget planner`
- `event budget`
- `project budget`
- `movie budget`
- `film budget`
- `government budget`
- `federal budget`
- `school budget`
- `college budget calculator`

**Banking/investing (not what the app does):**
- `bank account`
- `checking account`
- `savings account app`
- `investing app`
- `stock trading`
- `crypto budget`
- `loan calculator`
- `mortgage calculator`
- `credit score`
- `credit card app`
- `debt payoff calculator`

**Irrelevant intent:**
- `budget spreadsheet`
- `budget template excel`
- `budget google sheets`
- `budget printable`
- `budget planner notebook`
- `budget binder`
- `cash stuffing binder`

**Games and unrelated:**
- `budget game`
- `money game`
- `cash game`

Repeat the process of adding these negative keywords for each of the 5 campaigns. This takes about 10 minutes total.

---

## Part 4: Weekly Optimization Checklist

Do this every Monday morning. It takes 15-20 minutes once you are used to it.

### Step 1: Check Top-Level Numbers (2 minutes)

Go to the All Campaigns dashboard. For the past 7 days, check:

| Metric | Healthy Range | Action if Outside Range |
|--------|--------------|------------------------|
| Total Spend | Under $140/week | If overspending, lower bids on worst-performing campaign |
| Average CPA | Under $3.00 | If above $3, review keyword-level CPA below |
| Average TTR (Tap-Through Rate) | Above 5% | If below 5%, your App Store listing needs work (screenshots, description) |
| Conversion Rate | Above 40% | If below 40%, your product page is not convincing tappers |

### Step 2: Review Each Campaign (5 minutes)

Click into each campaign. Sort keywords by **Spend** (highest first). For each keyword:

| Keyword Situation | Action |
|-------------------|--------|
| Spent more than $10, zero installs | Pause the keyword |
| CPA above 2x your target | Lower the bid by 25% |
| CPA below target with good volume | Raise the bid by 15-20% to get more impressions |
| High impressions, low TTR (below 3%) | Your ad is not compelling for this term -- consider pausing |
| High TTR, low conversion | The App Store page is not converting for this audience -- not a keyword problem |

### Step 3: Mine Search Match Discovery (5 minutes)

1. Click into the "Search Match Discovery" campaign
2. Click on the ad group "Search Match - Auto"
3. Click "Search Terms" in the top navigation
4. Set date range to "Last 7 Days"
5. Sort by "Installs" (highest first)

For each search term:

| Situation | Action |
|-----------|--------|
| 2+ installs and CPA under $3 | Graduate it: Add as Exact match keyword in the appropriate campaign (2 or 4), then add it as a negative keyword in the Search Match campaign |
| Impressions but no taps | Ignore unless it has been showing for 2+ weeks, then add as negative keyword |
| Taps but no installs, spent over $5 | Add as negative keyword |
| Irrelevant term (wrong intent) | Add as negative keyword immediately |

### Step 4: Mine Broad Match Discovery (3 minutes)

1. Click into "Privacy + Budget Discovery" campaign
2. Click on the ad group
3. Click "Search Terms"
4. Same process as above: graduate winners to Exact in Campaign 2 or 4, add losers as negatives

### Step 5: Check Competitor Campaign (2 minutes, starting week 3)

Competitor keywords tend to have higher CPAs. This is normal. Review:
- If a competitor keyword CPA is above $5 for two consecutive weeks, pause it
- If a competitor keyword is converting under $2.50, raise the bid to capture more volume

### Step 6: Update Your Tracking Sheet

Keep a simple spreadsheet (Google Sheets is fine) with these columns:

| Date | Campaign | Spend | Installs | CPA | TTR | Conv Rate | Notes |
|------|----------|-------|----------|-----|-----|-----------|-------|

Fill in weekly totals for each campaign. After a month you will see clear trends.

---

## Part 5: Graduation and Scaling Rules

These rules help you decide when to change campaign budgets.

### Week 1-2 (Learning Phase)
- Do NOT change bids or budgets
- Apple's algorithm needs data to optimize
- Just add negative keywords for obviously bad search terms
- Only Campaigns 1, 2, 4, and 5 should be running

### Week 3 (Add Competitor Campaign)
- Launch Campaign 3: Competitor Conquest
- Review Search Match and Broad match discoveries from weeks 1-2
- Graduate any winning search terms to exact match campaigns

### Week 4+ (Optimize)
- Pause keywords with CPA above 2x target after $15+ spend
- Increase daily budget on campaigns with CPA below target (in $2 increments)
- Decrease daily budget on campaigns with CPA above target
- If total CPA across all campaigns is under $2, increase total daily budget by $5

### Monthly Budget Scaling Guide

| Total Monthly CPA | Action |
|--------------------|--------|
| Under $1.50 | Increase daily budget by 50% -- you are underinvesting |
| $1.50 - $2.50 | Healthy. Increase budget by 20% |
| $2.50 - $3.50 | Acceptable. Hold budgets, optimize keywords |
| $3.50 - $5.00 | Too high. Pause worst keywords, lower bids |
| Above $5.00 | Pause Competitor campaign. Review all keywords. Fix App Store listing |

---

## Part 6: Common Mistakes to Avoid

1. **Running only one campaign with all keywords mixed together.** Different keyword types need different bids and budgets. Always separate brand, category, competitor, and discovery.

2. **Not adding negative keywords to the Search Match campaign.** Without negatives, Search Match will bid on terms your other campaigns already cover, and you will pay twice.

3. **Changing bids daily.** The algorithm needs 3-5 days of data to stabilize. Make bid changes weekly, not daily.

4. **Ignoring the Search Terms report.** This is where you find what people actually searched for. Check it every week.

5. **Setting CPA goals too low on day one.** If your CPA goal is too aggressive, Apple will not show your ad at all. Start with the values in this guide and tighten after 2-4 weeks of data.

6. **Not fixing your App Store listing when TTR or conversion is low.** Search Ads drives traffic to your listing. If the listing does not convert, no amount of bid optimization will help. Fix screenshots and the first 3 lines of your description first.

7. **Forgetting to pause the Competitor campaign during slow weeks.** Competitor keywords are expensive. If you need to cut budget, this is the first campaign to pause.

---

## Quick Reference: All Campaigns Summary

| # | Campaign Name | Daily Budget | Max CPT Bid | CPA Goal | Match Type | Search Match | Launch |
|---|--------------|-------------|-------------|----------|-----------|-------------|--------|
| 1 | Brand Defense | $2.00 | $0.50 | -- | Exact | Off | Day 1 |
| 2 | Envelope Budgeting | $8.00 | $1.50 | $2.50 | Exact | Off | Day 1 |
| 3 | Competitor Conquest | $5.00 | $2.00 | $3.00 | Exact | Off | Week 3 |
| 4 | Privacy + Budget Discovery | $3.00 | $1.50 | $2.00 | Broad | Off | Day 1 |
| 5 | Search Match Discovery | $2.00 | $1.00 | $2.50 | -- | On | Day 1 |
| **Total** | | **$20.00** | | | | | |
