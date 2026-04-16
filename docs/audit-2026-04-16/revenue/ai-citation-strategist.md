# Revenue: AI Citation Strategist Findings

## TL;DR
A PWA competitor at **budgetvault.app** is winning every AI citation for the BudgetVault brand name itself — and the native iOS app at budgetvault.io is a client-rendered React shell with zero crawlable content, invisible to ChatGPT, Claude, Gemini, and Perplexity across all 8 high-intent prompts I tested.

## Top 3 Opportunities (Ranked)

1. **Reclaim brand SERP / fix budgetvault.io rendering (P0, 3 days, +30-50% citation rate)** — budgetvault.io currently returns a near-empty HTML body (SPA without SSR). When AI engines crawl it, they find a title and nothing else. Meanwhile budgetvault.app (a free PWA squatting on our name) ranks for `"BudgetVault" iOS app privacy budget`, `best YNAB alternatives 2026`, `5 budget apps that never touch your bank data`, and `budget app without account` — all queries we should own. Fix: ship a static-rendered marketing page (Next.js export, Astro, or plain HTML) with H1 "BudgetVault — the iPhone budgeting app that never asks for your bank login," meta description, OpenGraph, JSON-LD `MobileApplication` + `Organization` + `FAQPage` schema, and an explicit "iOS app" callout above the fold so AI distinguishes us from the PWA imposter.

2. **Ship 4 targeted comparison pages (P1, 5 days, +15-25% citation rate on comparison queries)** — Citation winners across all 4 AI engines are dedicated `vs` pages with tables. Build: `/vs/ynab`, `/vs/monarch`, `/vs/copilot`, `/vs/goodbudget`. Each ~600 words, Product schema with offers, side-by-side table (price model, bank sync, data location, platform). These are the literal pages AI engines extract and cite. Hard constraint respected — these are 4 focused pages, not a content farm.

3. **Seed Reddit + Hacker News review velocity (P1, ongoing, compounds quarterly)** — Perplexity and ChatGPT both pull recency signals from r/personalfinance, r/ynab, r/iphone, r/privacy, HN, and Indie Hackers. BudgetVault has zero discoverable mentions in any of these. We already have `research/reddit-launch-posts.md` drafted — they're unposted. Posting 6 drafts over 3 weeks (one per subreddit, organic tone, respond to commenters) is the cheapest 30-day citation lift available.

## Top 3 Risks / Debt Items

1. **Brand confusion is actively compounding** — Every week budgetvault.app gets indexed for "BudgetVault" content, our trademark ambiguity worsens. AI engines will crystallize "BudgetVault = free PWA, no iOS app" in their training data.
2. **Zero structured data anywhere** — No `MobileApplication`, no `FAQPage`, no `Review` schema. AI engines have no machine-readable hooks to cite us correctly.
3. **No `vs` pages, no FAQ page, no comparison content** — These are the exact content shapes AI engines preferentially cite. We have none.

## Quick Wins (<1 day each)
- Add `<meta description>` and OpenGraph tags to budgetvault.io
- Publish App Store URL prominently in budgetvault.io `<head>` and as `sameAs` in Organization schema
- Submit App Store listing to AlternativeTo, Product Hunt (re-launch as v3.2), and AppAdvice
- Add a `/faq` route answering 8 prompts: "Does BudgetVault connect to my bank?", "Is it really one-time pricing?", "Is my data shared?", "Does it work offline?", etc. — verbatim prompt patterns AI engines match against
- File trademark (USPTO) for BudgetVault in Class 9 to enable .app domain dispute
- Create Wikidata entry for BudgetVault iOS app with developer, platform, pricing properties

## Long Bets (>2 weeks but transformative)
- Pitch one tier-1 reviewer (MacStories, The Sweet Setup, 9to5Mac, AppAdvice) — a single review on these domains becomes a permanent AI citation source for years
- Build a public "Privacy Manifesto" page anchored to the "Data Not Collected" App Store label with screenshot proof — this is the wedge no competitor can copy and the exact content Claude/Perplexity preferentially cite for privacy queries
- Quarterly "State of Budget App Privacy" report with original data (e.g., audit 20 budget apps' privacy labels) — original research is the highest-citation content format on every AI platform

## What NOT to Do
- Do not build a content farm — the brief is correct, 4 comparison pages + 1 FAQ + 1 manifesto is the ceiling. More dilutes brand.
- Do not chase Google SEO rankings as the goal — AEO ≠ SEO. Optimize for entity clarity and schema, not keyword density.
- Do not trash competitors in `/vs` pages — Claude and Perplexity downrank adversarial framing. Use neutral feature tables.
- Do not promise citation outcomes to stakeholders — AI responses are non-deterministic; commit to signal improvement and 14/30-day rechecks, not guaranteed appearances.
