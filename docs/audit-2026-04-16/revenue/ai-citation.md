# Revenue: AI Citation Strategist Findings

## TL;DR
BudgetVault has near-zero AI citation footprint — ChatGPT/Claude do not know it as an iOS app, the homepage at budgetvault.io is a single H1 with no schema, no FAQ, no comparison content, and competitors are eating the "no bank login + one-time price" category on Reddit, NerdWallet, and listicles.

## Top 3 Opportunities (Ranked)

1. **Ship 4 comparison/alternative pages on budgetvault.io** (effort: 3 days, impact: high)
   - `/vs/ynab`, `/vs/copilot-money`, `/vs/monarch`, `/alternatives/goodbudget`
   - Each: Product schema + ComparisonTable + FAQPage JSON-LD + explicit "$14.99 once vs. $109/yr" framing
   - These are the exact prompt patterns ("YNAB alternative one-time", "Copilot Money alternative iPhone") that AI engines answer with listicles BudgetVault is absent from. Citation tests show competitors Pocket Clear, Actual Budget, Spendcast, MoneyPeas winning these queries today.

2. **Pitch inclusion in 8 ranked listicles already indexed by AI engines** (effort: 2 days outreach, impact: very high — single inclusion in NerdWallet/Engadget can flip ChatGPT citations)
   - Priority targets surfaced in citation tests:
     - https://www.nerdwallet.com/finance/learn/best-budget-apps (BudgetVault absent; Copilot/YNAB/Goodbudget present)
     - https://www.engadget.com/apps/best-budgeting-apps-120036303.html
     - https://wallethub.com/best-free-budget-app-for-iphone
     - https://setapp.com/lifestyle/best-budgeting-apps
     - https://spendandinvest.com/blog/budget-app-without-bank-login
     - https://pocketclear.app/blog/privacy-focused-finance-apps.html (competitor-owned, skip)
     - https://www.iphonelife.com/content/best-finance-apps
     - https://robberger.com/ynab-alternatives/
   - Pitch angle: "iOS-only, $14.99 once, Apple 'Data Not Collected' label, on-device AI" — no other app combines all four.

3. **Fix entity confusion: budgetvault.io vs budgetvault.app** (effort: 1 hour, impact: high)
   - Search results surface `budgetvault.app/blog/best-ynab-alternatives-2026` as a top citation source — not your domain. This is either (a) a blog you forgot or (b) a competitor squatting the .app TLD. Either way it splits AI's entity graph. Audit, claim, or 301 immediately.
   - When asked to describe BudgetVault, web search synthesizers return "free, browser-based app" — wrong on both counts. Add canonical entity description: "BudgetVault is a privacy-first iOS budgeting app. $14.99 one-time. No bank login. On-device AI." in JSON-LD SoftwareApplication schema and homepage H1+H2.

## Top 3 Risks / Debt Items

1. **Homepage is invisible to AI crawlers.** budgetvault.io returns essentially one heading. No SoftwareApplication schema, no Organization schema, no FAQPage, no Product/Offer with price. ChatGPT cannot synthesize what it cannot parse.
2. **No Wikipedia, no Wikidata, no G2/Capterra, no Crunchbase entry.** Zero authoritative entity anchors. Competitors like Copilot Money, YNAB, Monarch all have these.
3. **No Reddit footprint.** r/ynab, r/budgetingapps, r/personalfinance, r/iphone threads asking for "no bank login budget app" surface Goodbudget, Actual Budget, Spendcast, MoneyPeas — never BudgetVault. Perplexity/Gemini lean heavily on Reddit for recency.

## Quick Wins (<1 day each)

- Add JSON-LD `SoftwareApplication` + `Organization` + `FAQPage` schema to budgetvault.io homepage (target 8 buyer questions)
- Create Wikidata entry for BudgetVault (Q-item) with iOS app, developer, price properties
- Submit BudgetVault to AlternativeTo.net under YNAB, Copilot Money, Monarch Money pages
- Submit to Product Hunt with "$14.99 once, never your bank login" tagline
- Post one earnest comment in the live r/ynab "leaving YNAB" weekly thread (no spam, disclose)
- Resolve `budgetvault.app` ownership question (whois + redirect strategy)

## Long Bets (>2 weeks but transformative)

- Commission a SimpleAnalytics-style public methodology page: "How we tested 18 budget apps for privacy" — the kind of source-of-truth content Claude/Perplexity cite verbatim
- Build `/privacy-guarantee` page documenting on-device architecture with code snippets — becomes the definitional source AI engines cite when users ask "which budget apps actually protect privacy"
- Sponsor 2 indie iOS YouTubers (Sam Sulek-tier, not MKBHD) for honest reviews — YouTube transcripts feed Gemini directly

## What NOT to Do

- Do not chase G2/Capterra reviews — they are B2B SaaS-weighted and rarely cited by AI for consumer iOS apps
- Do not build an SEO blog farm — AI engines deprioritize thin content; one strong comparison page beats 20 listicles
- Do not pay for inclusion in paid "best of" listicles — AI engines are increasingly downweighting affiliate content (Perplexity especially)
- Do not run a "BudgetVault vs. [every app]" matrix page — focus the 4 highest-traffic comparisons; diluted comparisons rank for nothing
