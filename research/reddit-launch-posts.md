# BudgetVault Reddit Launch Posts
## Ready to copy-paste. Post 1-2 per week, spread across 2-3 weeks.

---

## 1. r/ynab

**Title:** After 3 years with YNAB, I built my own envelope budgeting app -- one-time purchase, no subscription

**Body:**

Hey everyone. Long-time YNAB user here (since the YNAB4 days). I want to be upfront: I'm a developer and this is a thing I built, so tag this however mods see fit.

YNAB genuinely changed how I think about money. The envelope method clicked for me in a way nothing else did. But after the last price increase I started thinking about what I actually needed versus what I was paying for. I don't use the bank syncing. I don't need the web app. I just want to assign dollars to envelopes and track what I spend.

So I built BudgetVault. It's an iOS app that does envelope budgeting with a one-time $9.99 purchase (there's a free tier too). No subscription, no accounts, everything stays on your device.

A few things that might matter to people here:

- **YNAB CSV import** -- You can bring your existing data over. I spent a lot of time making sure this actually works with real YNAB exports, not just a theoretical CSV format.
- **Same core workflow** -- Create envelopes (categories), assign money, track spending, move money between envelopes when life happens.
- **On-device ML insights** -- The app learns your spending patterns and surfaces things like "you tend to overspend on dining out in the last week of the month." Nothing groundbreaking, but useful nudges.
- **No cloud accounts** -- iCloud sync if you want it across devices, but there's no BudgetVault account, no server storing your financial data.

What it does NOT do: bank syncing, goal timelines with the depth YNAB has, or the reporting that power users rely on. If you're deep into YNAB's ecosystem and use everything, this probably isn't for you. But if you've been looking for something simpler that doesn't cost $100/year, it might be worth a look.

Happy to answer questions about the import process or anything else. And genuinely, if YNAB works for you and the price is fine, stick with it -- it's a great product. I just wanted an alternative that fit my own use case.

budgetvault.io

---

## 2. r/privacy

**Title:** I built a budgeting app with zero analytics, zero tracking, and Apple's "Data Not Collected" privacy label -- here's how the architecture works

**Body:**

[Developer] I'm the developer of BudgetVault, an iOS budgeting app. I want to talk about the privacy architecture because I think it's relevant to this community, and I'd genuinely like feedback from people who think about this stuff more critically than I do.

**The core principle:** Your financial data never leaves your device. There is no BudgetVault server. There is no account creation. There are no analytics SDKs.

Here's what that means in practice:

- **No Firebase, no Amplitude, no Mixpanel, no anything.** I have zero telemetry on how people use the app. I don't know how many active users I have. I don't know which features get used. I find out what's broken when someone emails me.
- **No Meta SDK, no TikTok SDK, no ad attribution.** I can't even run paid app install campaigns on most platforms because they require their SDK in your app.
- **Data storage is SwiftData (Core Data) on-device.** If you enable iCloud sync, it goes through your personal iCloud via CloudKit, encrypted in transit and at rest by Apple. I have no CloudKit dashboard, no server-side access to your containers.
- **Apple's "Data Not Collected" privacy nutrition label.** This is the strictest tier. During App Store review, Apple verifies this claim. It means: no data linked to your identity, no data used to track you, no data collected period.
- **Face ID/Touch ID lock** with no fallback to a server-side auth. Biometric data is handled entirely by the Secure Enclave.
- **ML insights run on-device** using Apple's Accelerate framework. Your spending patterns are analyzed locally. No data is sent anywhere for processing.

**What I gave up:** I can't do server-side bank syncing (Plaid requires sending credentials through a server). I can't do collaborative budgets with non-Apple users. I can't do sophisticated crash analytics. I basically fly blind on product decisions.

**What I think is worth discussing:** Is the Apple ecosystem itself a privacy concern here? iCloud sync uses Apple's infrastructure. CloudKit encryption means Apple theoretically holds keys. I've been transparent about this -- if you don't trust Apple's infrastructure, you can use the app fully offline with no sync. But I'm curious what this community thinks about the tradeoff.

The app is at budgetvault.io if anyone wants to look at the privacy label on the App Store listing.

I'd rather get torn apart here and improve than assume I've gotten everything right.

---

## 3. r/iphone

**Title:** [Self-Promotion] I built an envelope budgeting app designed to feel like a native iOS app, not a web wrapper

**Body:**

Hey r/iphone -- developer here, tagging this appropriately.

I spent the last year building BudgetVault, a budgeting app built entirely in SwiftUI. My pet peeve has always been finance apps that feel like web views stuffed into an iOS shell, so I wanted to share what "iOS-native" means in practice for this app:

**Native iOS features:**

- **Widgets** -- See your remaining budget on your home screen without opening the app. Updates throughout the day as you log expenses.
- **Siri Shortcuts** -- "Hey Siri, log $12 for lunch" adds an expense without opening the app.
- **Face ID / Touch ID** -- App lock using the Secure Enclave. No PIN codes, no separate password.
- **iCloud Sync** -- Budget syncs across your devices through your personal iCloud. No account creation.
- **Dynamic Type & Dark Mode** -- Full support for accessibility text sizes. Dark mode that actually looks intentional.
- **Haptic feedback** -- Subtle taps when you complete actions. Small thing but it makes the app feel responsive.

**What it does:** Envelope budgeting. You set a monthly income, divide it into categories (rent, groceries, fun money, etc.), and track spending against those envelopes. The app has on-device ML that learns your patterns and gives you insights like daily spending allowances.

**Cost:** Free to use with a $9.99 one-time purchase to unlock everything. No subscription.

It's at budgetvault.io -- happy to answer any questions about the build or the features.

---

## 4. r/personalfinance

**Title:** The envelope budgeting method helped me stop living paycheck-to-paycheck -- here's how it works and the tools I use

**Body:**

I want to share the budgeting method that actually stuck for me after years of trying spreadsheets, Mint, and just "being more careful."

**The envelope method in 60 seconds:**

Imagine you get paid and immediately divide your cash into physical envelopes -- one for rent, one for groceries, one for gas, one for fun. When an envelope is empty, you're done spending in that category until next payday. No borrowing from the grocery envelope to buy concert tickets.

That's it. That's the whole system.

**Why it works (at least for me):**

1. **It makes scarcity visible.** When you see $47 left in your dining out envelope on the 20th, you make different choices than when you see $2,400 in your checking account and think "I'm fine."
2. **It eliminates the "where did my money go?" problem.** Every dollar is assigned before you spend it. There's no mystery spending.
3. **It handles irregular expenses.** You create an envelope for car maintenance and put $50/month in it. When the $600 repair bill comes, the money is already there.
4. **It's flexible when life happens.** Overspent on groceries? Move money from clothing. The budget adapts to reality instead of making you feel like a failure.

**Tools for envelope budgeting:**

- **Physical envelopes.** Seriously. If you're just starting, use cash in actual envelopes for discretionary categories.
- **Spreadsheets.** A simple Google Sheet works fine. One column per envelope, subtract as you spend.
- **YNAB.** The gold standard app for this method. Subscription-based ($99/yr), great if you want bank syncing and deep reporting.
- **BudgetVault.** Full disclosure -- I built this one. It's an iOS app, one-time $9.99 purchase, everything stays on your device. I built it because I wanted YNAB's workflow without the recurring cost.
- **Goodbudget.** Another solid option, has a free tier.

The method matters more than the tool. If a notebook and pen gets you to assign every dollar a job, that's a win.

Happy to answer questions about how to set up envelopes for different income situations.

---

## 5. r/frugal

**Title:** I was paying $100/year for a budgeting app. Built my own for a one-time cost instead.

**Body:**

This might be the most r/frugal thing I've ever done.

I used YNAB (You Need A Budget) for years. Great app. Envelope budgeting method genuinely changed my finances. But every year when that $99 renewal hit, I thought about what I was actually getting: I don't use bank syncing, I manually enter everything, and the web app sits untouched.

I'm a developer, so I did the very frugal thing of spending hundreds of hours building my own budgeting app instead of just paying the $99. (Yes, I'm aware of the irony. My hourly rate on this project is approximately $0.03.)

The result is BudgetVault. It's on iOS, does envelope budgeting, and costs $9.99 one-time. No subscription. There's a free tier too.

**The frugal math that matters though:**

| Option | Year 1 | Year 3 | Year 5 |
|--------|--------|--------|--------|
| YNAB | $99 | $297 | $495 |
| BudgetVault | $9.99 | $9.99 | $9.99 |
| Spreadsheet | $0 | $0 | $0 |

I'll be honest -- a spreadsheet is the most frugal option and works fine. The app just makes it faster to log things on the go and gives you visual breakdowns without building your own charts.

No subscription ever. I'm not going to pull a bait-and-switch in two years. The business model is: you pay once, you own it. Updates are included.

budgetvault.io if anyone's interested. And if you have a spreadsheet system that works for you, genuinely, keep using it. The best budget is the one you actually stick with.

---

## 6. r/apple (Self-Promotion Saturday)

**Title:** [Self-Promotion Saturday] I'm a solo developer who spent a year building a budgeting app with SwiftUI + SwiftData -- lessons learned

**Body:**

Hey r/apple. I've been lurking here for years and wanted to share my experience building BudgetVault, an envelope budgeting app for iOS, as a solo developer.

**The tech stack:**

- **SwiftUI** for the entire UI. No UIKit bridging except for a couple of edge cases.
- **SwiftData** for persistence. This was a bet -- SwiftData was still maturing when I started.
- **CloudKit** for sync. No custom backend.
- **Accelerate framework** for on-device spending insights.
- **StoreKit 2** for in-app purchases.

**Honest lessons for anyone building with these frameworks:**

1. **SwiftData and Decimal don't mix.** SwiftData silently corrupts Decimal values. I store all monetary amounts as Int64 cents. Learned this the hard way after corrupted test data.

2. **The @Query macro is powerful but rigid.** You can't compose queries dynamically the way you could with NSFetchRequest. I ended up putting @Query in views and keeping ViewModels @Observable with no direct data access.

3. **StoreKit 2 has a naming collision.** `Transaction` exists in both SwiftUI and StoreKit. You need a typealias to disambiguate, or you'll get bizarre compiler errors.

4. **CloudKit sync via SwiftData "just works" until it doesn't.** No #Unique macro (breaks CloudKit sync). Conflict resolution is a black box. Testing sync requires two physical devices.

5. **Widgets are the best-kept secret for user retention.** My most-used feature isn't any screen in the app -- it's the home screen widget showing remaining budget.

**The app itself:** Envelope budgeting (assign every dollar to a category, track spending). $9.99 one-time IAP, no subscription. Zero analytics SDKs -- Apple's "Data Not Collected" privacy label.

Happy to answer technical questions about any of the above.

budgetvault.io
