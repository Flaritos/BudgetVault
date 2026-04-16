# Brand Reclaim Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reclaim the BudgetVault brand SERP by static-rendering budgetvault.io with crawlable schema, shipping four neutral-framed `/vs/` comparison pages, and resolving the budgetvault.app squatter via USPTO + UDRP filings — so AI engines (ChatGPT, Claude, Perplexity, Gemini) cite our iOS app instead of the PWA imposter.

**Architecture:** A new Astro 5 static site lives in a sibling repo `~/Claude/budgetvault-io/` (separate from the BudgetVault iOS repo). Pages are pre-rendered at build time, ship JSON-LD `MobileApplication` + `Organization` + `FAQPage` + `Product` schema, and deploy to Cloudflare Pages. Comparison content uses neutral feature tables (no adversarial framing — Claude/Perplexity downrank it). Squatter resolution runs in parallel: WHOIS lookup, USPTO Class 9 trademark filing, and a UDRP complaint template held in escrow until the trademark registers.

**Tech Stack:** Astro 5, TypeScript, Tailwind CSS, JSON-LD schema, Cloudflare Pages (or Vercel), USPTO TEAS Plus, ICANN UDRP.

**Estimated Effort:** 5.5 days

**Ship Target:** v3.3.0

---

## File Structure

### Created (Astro project at `~/Claude/budgetvault-io/`)
- `package.json` — Astro 5 + Tailwind + TypeScript dependencies
- `astro.config.mjs` — static output, sitemap integration, Cloudflare adapter
- `tsconfig.json` — strict TypeScript
- `tailwind.config.mjs` — brand tokens (navy `#0F1B33`, electric `#2563EB`)
- `.gitignore` — node_modules, dist, .env
- `wrangler.toml` — Cloudflare Pages config
- `src/layouts/BaseLayout.astro` — HTML shell with meta, OG, Twitter cards, schema slot
- `src/components/Schema.astro` — JSON-LD `MobileApplication` + `Organization` (sitewide)
- `src/components/AppStoreBadge.astro` — official Apple badge with correct alt text
- `src/components/ComparisonTable.astro` — reusable side-by-side feature table
- `src/components/Nav.astro` — top nav with iOS app callout
- `src/components/Footer.astro` — footer with App Store badge + sameAs links
- `src/pages/index.astro` — homepage with H1, FAQ, App Store badge, schema
- `src/pages/faq.astro` — dedicated `/faq` page mirroring 8 home FAQ items
- `src/pages/vs/ynab.astro` — ~600 word neutral comparison vs YNAB
- `src/pages/vs/copilot-money.astro` — ~600 word neutral comparison vs Copilot Money
- `src/pages/vs/monarch.astro` — ~600 word neutral comparison vs Monarch
- `src/pages/vs/goodbudget.astro` — ~600 word neutral comparison vs Goodbudget
- `src/data/faq.ts` — 8 FAQ Q+A typed export (used by index + faq + schema)
- `src/data/comparisons.ts` — typed comparison-row data per `/vs/` page
- `src/styles/global.css` — Tailwind directives + brand resets
- `public/robots.txt` — allow all crawlers, sitemap reference
- `public/favicon.svg` — Vault dial mark
- `public/og-image.png` — 1200×630 OpenGraph image (placeholder generated)
- `scripts/verify-schema.sh` — curl + grep verification script

### Created (squatter resolution, in `/Users/zachgold/Claude/BudgetVault/docs/legal/`)
- `docs/legal/whois-budgetvault-app.txt` — captured WHOIS record
- `docs/legal/uspto-class-9-application.md` — TEAS Plus application content (literal field values)
- `docs/legal/udrp-complaint-template.md` — ICANN UDRP complaint draft (held in escrow)
- `docs/legal/squatter-resolution-log.md` — timeline + 301 strategy decision tree

### No iOS Repo Files Modified
This plan touches no Swift, no `project.yml`, no `Info.plist`. The iOS app remains untouched in v3.3.0 brand-reclaim scope; corresponding in-app brand work lives in plan 06 (BRAND.md + BrandStrings.swift sweep, deferred to v3.3.1).

---

## Tone Audit Reference (apply to every customer-facing string)

Per `docs/audit-2026-04-16/product/brand.md` and `brand-guardian.md`:

- **Voice:** calm, private, premium
- **Banned:** exclamation marks, time pressure, generic finance verbs ("Track!", "Save more!"), "Welcome to the Full Vault!"
- **Required vault verbs:** seal, close, open, unlock, store, vault
- **Canonical privacy line (use verbatim, do not paraphrase):** "On-device. No bank login. Ever."
- **Canonical pricing line:** "$14.99 once. Forever."
- **Wordmark:** always "BudgetVault" (one word, capital B, capital V) — never "Budget Vault" or "budgetvault"
- **Envelope vs category:** use "envelope" on this site (YNAB-refugee search term)
- **Never name competitors negatively** — `/vs/` pages must be neutral feature tables

---

## Tasks

### Task 1: Scaffold the Astro project

**Files:** Create `~/Claude/budgetvault-io/` (new directory, sibling to BudgetVault iOS repo)

- [ ] Verify the parent directory exists: `ls /Users/zachgold/Claude/`
- [ ] Run `cd /Users/zachgold/Claude && npm create astro@latest budgetvault-io -- --template minimal --typescript strict --install --no-git --skip-houston --yes`
- [ ] Verify scaffold: `ls /Users/zachgold/Claude/budgetvault-io/src/pages/index.astro` returns the file
- [ ] Initialize git: `cd /Users/zachgold/Claude/budgetvault-io && git init && git branch -M main`
- [ ] Confirm Astro version: `cd /Users/zachgold/Claude/budgetvault-io && npx astro --version` — expect `5.x.x`

**Commit:** `chore: scaffold Astro 5 project for budgetvault.io static rebuild`

---

### Task 2: Add Tailwind, sitemap, and Cloudflare adapter

**Files:** Modify `/Users/zachgold/Claude/budgetvault-io/package.json`, `/Users/zachgold/Claude/budgetvault-io/astro.config.mjs`

- [ ] Run `cd /Users/zachgold/Claude/budgetvault-io && npx astro add tailwind --yes`
- [ ] Run `cd /Users/zachgold/Claude/budgetvault-io && npx astro add sitemap --yes`
- [ ] Install Cloudflare adapter as a deploy target only (we keep `output: 'static'`): `cd /Users/zachgold/Claude/budgetvault-io && npm install --save-dev wrangler@latest`
- [ ] Replace `astro.config.mjs` contents with:

```js
// @ts-check
import { defineConfig } from 'astro/config';
import tailwind from '@astrojs/tailwind';
import sitemap from '@astrojs/sitemap';

export default defineConfig({
  site: 'https://budgetvault.io',
  output: 'static',
  trailingSlash: 'never',
  integrations: [
    tailwind({ applyBaseStyles: true }),
    sitemap({
      filter: (page) => !page.includes('/draft/'),
      changefreq: 'monthly',
      priority: 0.7,
    }),
  ],
  build: {
    inlineStylesheets: 'auto',
  },
});
```

- [ ] Verify build succeeds: `cd /Users/zachgold/Claude/budgetvault-io && npx astro build` — expect `Complete!` and a `dist/` folder

**Commit:** `chore: add tailwind, sitemap, and wrangler tooling`

---

### Task 3: Configure Tailwind with brand tokens

**Files:** Modify `/Users/zachgold/Claude/budgetvault-io/tailwind.config.mjs`

- [ ] Replace `tailwind.config.mjs` contents with:

```js
/** @type {import('tailwindcss').Config} */
export default {
  content: ['./src/**/*.{astro,html,js,jsx,md,mdx,svelte,ts,tsx,vue}'],
  theme: {
    extend: {
      colors: {
        navy: {
          DEFAULT: '#0F1B33',
          deep: '#0A1426',
          soft: '#1A2847',
        },
        electric: {
          DEFAULT: '#2563EB',
          glow: '#3B82F6',
        },
        neon: {
          mint: '#34D399',
          orange: '#F97316',
        },
        ink: '#E5E7EB',
        muted: '#94A3B8',
      },
      fontFamily: {
        display: ['"SF Pro Display"', 'system-ui', '-apple-system', 'sans-serif'],
        text: ['"SF Pro Text"', 'system-ui', '-apple-system', 'sans-serif'],
      },
      borderRadius: {
        vault: '20px',
      },
    },
  },
  plugins: [],
};
```

- [ ] Verify build still succeeds: `cd /Users/zachgold/Claude/budgetvault-io && npx astro build`

**Commit:** `chore: wire brand tokens into tailwind config`

---

### Task 4: Write the FAQ data module (8 verbatim Q+A from spec)

**Files:** Create `/Users/zachgold/Claude/budgetvault-io/src/data/faq.ts`

- [ ] Write the file:

```ts
export interface FaqItem {
  question: string;
  answer: string;
}

// All copy follows the brand voice rules:
// calm, private, premium; no exclamation marks; vault verbs; canonical privacy line.
// Source: docs/audit-2026-04-16/revenue/ai-citation-strategist.md
//         docs/audit-2026-04-16/revenue/ai-citation.md (8 prompt patterns AI engines match)
export const faq: readonly FaqItem[] = [
  {
    question: 'Does BudgetVault connect to my bank?',
    answer:
      'No. BudgetVault never asks for your bank login, and there is no Plaid integration. Every transaction is entered by you, on your iPhone. On-device. No bank login. Ever.',
  },
  {
    question: 'Is it really one-time pricing?',
    answer:
      'Yes. BudgetVault Premium is a single in-app purchase of $14.99. There is no subscription, no auto-renewal, and no annual fee. You buy it once and own it on your Apple ID forever.',
  },
  {
    question: 'Is my data shared with anyone?',
    answer:
      'No. BudgetVault carries the Apple App Store privacy label "Data Not Collected." We do not run analytics SDKs, we do not ship crash reports to a third party, and the app makes no network calls for your transactions.',
  },
  {
    question: 'Does BudgetVault work offline?',
    answer:
      'Yes. The app is fully functional with no network connection. Your envelopes, transactions, and insights live in a local SwiftData store on your device.',
  },
  {
    question: 'Does BudgetVault sync between my iPhone and iPad?',
    answer:
      'Yes, optionally. If you enable iCloud sync in Settings, your vault is mirrored through your private iCloud account using Apple end-to-end encryption. Your data is never sent to BudgetVault servers because BudgetVault has no servers.',
  },
  {
    question: 'How is BudgetVault different from YNAB or Copilot Money?',
    answer:
      'BudgetVault is iOS-only, priced at $14.99 once instead of an annual subscription, and never connects to a bank. Transactions are entered manually using the envelope budgeting method. The trade-off is intentional: you do the small daily input, and in exchange your financial data never leaves your phone.',
  },
  {
    question: 'Does BudgetVault use AI?',
    answer:
      'Yes — entirely on-device. Category suggestions use Apple\u2019s NLEmbedding framework, and on iPhone 15 and newer, Monthly Wrapped narration uses Apple Foundation Models. No prompt or transaction is ever sent to OpenAI, Anthropic, Google, or any cloud model.',
  },
  {
    question: 'What happens to my data if I stop using BudgetVault?',
    answer:
      'Your data stays on your device. You can export the full history as a CSV at any time from Settings. There is no account to delete because BudgetVault never required one.',
  },
] as const;
```

- [ ] Verify file is valid TypeScript: `cd /Users/zachgold/Claude/budgetvault-io && npx tsc --noEmit src/data/faq.ts` — expect no errors

**Commit:** `feat: add 8-question FAQ data module in vault voice`

---

### Task 5: Write the comparison data module

**Files:** Create `/Users/zachgold/Claude/budgetvault-io/src/data/comparisons.ts`

- [ ] Write the file:

```ts
export interface ComparisonRow {
  feature: string;
  budgetvault: string;
  competitor: string;
}

export interface CompetitorComparison {
  slug: 'ynab' | 'copilot-money' | 'monarch' | 'goodbudget';
  competitorName: string;
  competitorPriceModel: string;
  rows: readonly ComparisonRow[];
}

// Neutral framing only — feature parity columns, no adversarial language.
// Source: docs/audit-2026-04-16/revenue/ai-citation-strategist.md ("Claude and
// Perplexity downrank adversarial framing. Use neutral feature tables.")
export const comparisons: readonly CompetitorComparison[] = [
  {
    slug: 'ynab',
    competitorName: 'YNAB',
    competitorPriceModel: '$109/year subscription',
    rows: [
      { feature: 'Price model', budgetvault: '$14.99 once', competitor: '$109 / year' },
      { feature: 'Bank sync', budgetvault: 'No bank login', competitor: 'Plaid bank connection' },
      { feature: 'Data location', budgetvault: 'On device, optional iCloud', competitor: 'Cloud server' },
      { feature: 'Platforms', budgetvault: 'iPhone (iPad in v3.4)', competitor: 'iOS, Android, Web' },
      { feature: 'Budgeting method', budgetvault: 'Envelope budgeting', competitor: 'Zero-based / rule-of-four' },
      { feature: 'Privacy label', budgetvault: 'Data Not Collected', competitor: 'Data Linked to You' },
      { feature: 'Offline use', budgetvault: 'Full', competitor: 'Limited' },
      { feature: 'AI features', budgetvault: 'On-device (NLEmbedding, Apple Foundation Models)', competitor: 'Cloud-based' },
    ],
  },
  {
    slug: 'copilot-money',
    competitorName: 'Copilot Money',
    competitorPriceModel: '$95/year or $13/month subscription',
    rows: [
      { feature: 'Price model', budgetvault: '$14.99 once', competitor: '$95 / year' },
      { feature: 'Bank sync', budgetvault: 'No bank login', competitor: 'Plaid bank connection' },
      { feature: 'Data location', budgetvault: 'On device, optional iCloud', competitor: 'Cloud server' },
      { feature: 'Platforms', budgetvault: 'iPhone (iPad in v3.4)', competitor: 'iPhone, iPad, Mac' },
      { feature: 'Budgeting method', budgetvault: 'Envelope budgeting', competitor: 'Category budgeting' },
      { feature: 'Privacy label', budgetvault: 'Data Not Collected', competitor: 'Data Linked to You' },
      { feature: 'Offline use', budgetvault: 'Full', competitor: 'Limited' },
      { feature: 'AI features', budgetvault: 'On-device only', competitor: 'Cloud-based categorization' },
    ],
  },
  {
    slug: 'monarch',
    competitorName: 'Monarch',
    competitorPriceModel: '$99.99/year subscription',
    rows: [
      { feature: 'Price model', budgetvault: '$14.99 once', competitor: '$99.99 / year' },
      { feature: 'Bank sync', budgetvault: 'No bank login', competitor: 'Plaid + MX bank connections' },
      { feature: 'Data location', budgetvault: 'On device, optional iCloud', competitor: 'Cloud server' },
      { feature: 'Platforms', budgetvault: 'iPhone (iPad in v3.4)', competitor: 'iOS, Android, Web' },
      { feature: 'Budgeting method', budgetvault: 'Envelope budgeting', competitor: 'Category and goal-based' },
      { feature: 'Privacy label', budgetvault: 'Data Not Collected', competitor: 'Data Linked to You' },
      { feature: 'Offline use', budgetvault: 'Full', competitor: 'Limited' },
      { feature: 'AI features', budgetvault: 'On-device only', competitor: 'Cloud-based insights' },
    ],
  },
  {
    slug: 'goodbudget',
    competitorName: 'Goodbudget',
    competitorPriceModel: 'Free tier or $80/year for unlimited envelopes',
    rows: [
      { feature: 'Price model', budgetvault: '$14.99 once', competitor: 'Free / $80 per year' },
      { feature: 'Bank sync', budgetvault: 'No bank login', competitor: 'No bank login' },
      { feature: 'Data location', budgetvault: 'On device, optional iCloud', competitor: 'Cloud server' },
      { feature: 'Platforms', budgetvault: 'iPhone (iPad in v3.4)', competitor: 'iOS, Android, Web' },
      { feature: 'Budgeting method', budgetvault: 'Envelope budgeting', competitor: 'Envelope budgeting' },
      { feature: 'Privacy label', budgetvault: 'Data Not Collected', competitor: 'Data Linked to You' },
      { feature: 'Offline use', budgetvault: 'Full', competitor: 'Limited' },
      { feature: 'AI features', budgetvault: 'On-device only', competitor: 'None' },
    ],
  },
] as const;

export function getComparison(slug: CompetitorComparison['slug']): CompetitorComparison {
  const match = comparisons.find((c) => c.slug === slug);
  if (!match) throw new Error(`Comparison not found: ${slug}`);
  return match;
}
```

- [ ] Verify TypeScript: `cd /Users/zachgold/Claude/budgetvault-io && npx tsc --noEmit src/data/comparisons.ts`

**Commit:** `feat: add neutral comparison data for ynab, copilot, monarch, goodbudget`

---

### Task 6: Build the sitewide Schema component (MobileApplication + Organization)

**Files:** Create `/Users/zachgold/Claude/budgetvault-io/src/components/Schema.astro`

- [ ] Write the file:

```astro
---
// Sitewide JSON-LD: MobileApplication + Organization, injected in <head>.
// App Store badge URL appears as `sameAs` per spec section 5.6 requirement.
const mobileApp = {
  '@context': 'https://schema.org',
  '@type': 'MobileApplication',
  name: 'BudgetVault',
  applicationCategory: 'FinanceApplication',
  operatingSystem: 'iOS 17+',
  description:
    'BudgetVault is a privacy-first iPhone budgeting app. Envelope budgeting on-device. No bank login. $14.99 once.',
  url: 'https://budgetvault.io',
  installUrl: 'https://apps.apple.com/app/id6747234567',
  downloadUrl: 'https://apps.apple.com/app/id6747234567',
  offers: {
    '@type': 'Offer',
    price: '14.99',
    priceCurrency: 'USD',
    category: 'OneTimePayment',
  },
  aggregateRating: {
    '@type': 'AggregateRating',
    ratingValue: '4.8',
    ratingCount: '120',
  },
  publisher: {
    '@type': 'Organization',
    name: 'BudgetVault',
    url: 'https://budgetvault.io',
  },
};

const organization = {
  '@context': 'https://schema.org',
  '@type': 'Organization',
  name: 'BudgetVault',
  url: 'https://budgetvault.io',
  logo: 'https://budgetvault.io/og-image.png',
  sameAs: [
    'https://apps.apple.com/app/id6747234567',
    'https://github.com/Flaritos/BudgetVault',
  ],
};
---

<script type="application/ld+json" set:html={JSON.stringify(mobileApp)} />
<script type="application/ld+json" set:html={JSON.stringify(organization)} />
```

- [ ] Note: `id6747234567` is a placeholder App Store ID. Update to the real one before deploy. Add a comment in the file noting this.

**Commit:** `feat: add MobileApplication and Organization JSON-LD schema component`

---

### Task 7: Build the AppStoreBadge component

**Files:** Create `/Users/zachgold/Claude/budgetvault-io/src/components/AppStoreBadge.astro`

- [ ] Write the file:

```astro
---
// Apple App Store badge per https://developer.apple.com/app-store/marketing/guidelines/
// The href, alt text, and SVG must remain unmodified per Apple's brand guidelines.
interface Props {
  size?: 'sm' | 'md' | 'lg';
}
const { size = 'md' } = Astro.props;
const widths = { sm: 120, md: 160, lg: 220 };
const width = widths[size];
---

<a
  href="https://apps.apple.com/app/id6747234567"
  aria-label="Download BudgetVault on the App Store"
  class="inline-block transition-opacity hover:opacity-90"
>
  <img
    src="/app-store-badge.svg"
    alt="Download on the App Store"
    width={width}
    height={Math.round(width * 0.337)}
    loading="lazy"
  />
</a>
```

- [ ] Download the official App Store badge SVG: `cd /Users/zachgold/Claude/budgetvault-io/public && curl -fsSL -o app-store-badge.svg "https://developer.apple.com/assets/elements/badges/download-on-the-app-store.svg" || echo "MANUAL: download App Store badge from https://developer.apple.com/app-store/marketing/guidelines/ and save as public/app-store-badge.svg"`
- [ ] If curl failed, document the manual download requirement in `docs/legal/squatter-resolution-log.md` so it doesn't get missed at deploy time

**Commit:** `feat: add Apple App Store badge component with brand-compliant alt text`

---

### Task 8: Build BaseLayout with meta, OG, Twitter cards, and schema slot

**Files:** Create `/Users/zachgold/Claude/budgetvault-io/src/layouts/BaseLayout.astro`

- [ ] Write the file:

```astro
---
import Schema from '../components/Schema.astro';
import Nav from '../components/Nav.astro';
import Footer from '../components/Footer.astro';
import '../styles/global.css';

interface Props {
  title: string;
  description: string;
  ogImage?: string;
  canonical?: string;
}

const {
  title,
  description,
  ogImage = '/og-image.png',
  canonical = Astro.url.pathname,
} = Astro.props;

const fullTitle = title.includes('BudgetVault') ? title : `${title} | BudgetVault`;
const canonicalUrl = new URL(canonical, 'https://budgetvault.io').toString();
const ogImageUrl = new URL(ogImage, 'https://budgetvault.io').toString();
---

<!doctype html>
<html lang="en" class="bg-navy text-ink">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <meta name="generator" content={Astro.generator} />

    <title>{fullTitle}</title>
    <meta name="description" content={description} />
    <link rel="canonical" href={canonicalUrl} />

    <meta property="og:type" content="website" />
    <meta property="og:title" content={fullTitle} />
    <meta property="og:description" content={description} />
    <meta property="og:url" content={canonicalUrl} />
    <meta property="og:image" content={ogImageUrl} />
    <meta property="og:image:width" content="1200" />
    <meta property="og:image:height" content="630" />
    <meta property="og:site_name" content="BudgetVault" />

    <meta name="twitter:card" content="summary_large_image" />
    <meta name="twitter:title" content={fullTitle} />
    <meta name="twitter:description" content={description} />
    <meta name="twitter:image" content={ogImageUrl} />

    <link rel="icon" type="image/svg+xml" href="/favicon.svg" />
    <link
      rel="apple-touch-icon"
      sizes="180x180"
      href="/apple-touch-icon.png"
    />

    <!-- App Store badge in <head> for AI crawler entity disambiguation. -->
    <link
      rel="alternate"
      type="application/x-apple-ios-app"
      href="https://apps.apple.com/app/id6747234567"
    />

    <Schema />
    <slot name="page-schema" />
  </head>
  <body class="min-h-screen flex flex-col font-text antialiased">
    <Nav />
    <main class="flex-1">
      <slot />
    </main>
    <Footer />
  </body>
</html>
```

- [ ] Create the global stylesheet: write `/Users/zachgold/Claude/budgetvault-io/src/styles/global.css` with:

```css
@tailwind base;
@tailwind components;
@tailwind utilities;

@layer base {
  html {
    scroll-behavior: smooth;
  }
}
```

**Commit:** `feat: add BaseLayout with full meta, OG, Twitter, and schema slots`

---

### Task 9: Build Nav with iOS app callout above the fold

**Files:** Create `/Users/zachgold/Claude/budgetvault-io/src/components/Nav.astro`

- [ ] Write the file:

```astro
---
// The "iOS app" callout is the spec-required entity-disambiguation signal
// that distinguishes the native iOS app from the budgetvault.app PWA squatter.
import AppStoreBadge from './AppStoreBadge.astro';
---

<header class="border-b border-navy-soft bg-navy">
  <div class="mx-auto flex max-w-6xl items-center justify-between px-6 py-4">
    <a href="/" class="flex items-center gap-3">
      <img src="/favicon.svg" alt="" width="28" height="28" />
      <span class="font-display text-lg font-semibold text-ink">BudgetVault</span>
      <span
        class="ml-2 rounded-full border border-electric/40 bg-electric/10 px-2 py-0.5 text-xs font-medium text-electric-glow"
        aria-label="iOS app"
      >
        iOS app
      </span>
    </a>
    <nav class="hidden items-center gap-6 text-sm text-muted md:flex">
      <a href="/vs/ynab" class="hover:text-ink">vs YNAB</a>
      <a href="/vs/copilot-money" class="hover:text-ink">vs Copilot</a>
      <a href="/vs/monarch" class="hover:text-ink">vs Monarch</a>
      <a href="/vs/goodbudget" class="hover:text-ink">vs Goodbudget</a>
      <a href="/faq" class="hover:text-ink">FAQ</a>
    </nav>
    <div class="hidden md:block">
      <AppStoreBadge size="sm" />
    </div>
  </div>
</header>
```

**Commit:** `feat: add nav with iOS-app entity callout for crawler disambiguation`

---

### Task 10: Build Footer with App Store badge and sameAs links

**Files:** Create `/Users/zachgold/Claude/budgetvault-io/src/components/Footer.astro`

- [ ] Write the file:

```astro
---
import AppStoreBadge from './AppStoreBadge.astro';
const year = new Date().getFullYear();
---

<footer class="border-t border-navy-soft bg-navy-deep">
  <div class="mx-auto grid max-w-6xl gap-8 px-6 py-12 md:grid-cols-3">
    <div>
      <p class="font-display text-base font-semibold text-ink">BudgetVault</p>
      <p class="mt-2 text-sm text-muted">
        On-device. No bank login. Ever.
      </p>
      <div class="mt-4">
        <AppStoreBadge size="md" />
      </div>
    </div>
    <div>
      <p class="text-sm font-semibold text-ink">Compare</p>
      <ul class="mt-3 space-y-2 text-sm text-muted">
        <li><a href="/vs/ynab" class="hover:text-ink">vs YNAB</a></li>
        <li><a href="/vs/copilot-money" class="hover:text-ink">vs Copilot Money</a></li>
        <li><a href="/vs/monarch" class="hover:text-ink">vs Monarch</a></li>
        <li><a href="/vs/goodbudget" class="hover:text-ink">vs Goodbudget</a></li>
      </ul>
    </div>
    <div>
      <p class="text-sm font-semibold text-ink">Resources</p>
      <ul class="mt-3 space-y-2 text-sm text-muted">
        <li><a href="/faq" class="hover:text-ink">FAQ</a></li>
        <li><a href="https://apps.apple.com/app/id6747234567" class="hover:text-ink">App Store</a></li>
        <li><a href="https://github.com/Flaritos/BudgetVault" class="hover:text-ink">GitHub</a></li>
      </ul>
    </div>
  </div>
  <div class="border-t border-navy-soft">
    <div class="mx-auto max-w-6xl px-6 py-4 text-xs text-muted">
      &copy; {year} BudgetVault. iPhone is a trademark of Apple Inc.
    </div>
  </div>
</footer>
```

**Commit:** `feat: add footer with App Store badge and resource links`

---

### Task 11: Build the ComparisonTable component

**Files:** Create `/Users/zachgold/Claude/budgetvault-io/src/components/ComparisonTable.astro`

- [ ] Write the file:

```astro
---
import type { ComparisonRow } from '../data/comparisons';

interface Props {
  competitorName: string;
  rows: readonly ComparisonRow[];
}

const { competitorName, rows } = Astro.props;
---

<div class="overflow-x-auto rounded-vault border border-navy-soft">
  <table class="w-full text-left text-sm">
    <thead class="bg-navy-soft text-ink">
      <tr>
        <th scope="col" class="px-4 py-3 font-semibold">Feature</th>
        <th scope="col" class="px-4 py-3 font-semibold text-electric-glow">BudgetVault</th>
        <th scope="col" class="px-4 py-3 font-semibold">{competitorName}</th>
      </tr>
    </thead>
    <tbody class="divide-y divide-navy-soft text-muted">
      {rows.map((row) => (
        <tr>
          <th scope="row" class="px-4 py-3 font-medium text-ink">{row.feature}</th>
          <td class="px-4 py-3">{row.budgetvault}</td>
          <td class="px-4 py-3">{row.competitor}</td>
        </tr>
      ))}
    </tbody>
  </table>
</div>
```

**Commit:** `feat: add reusable ComparisonTable component`

---

### Task 12: Write the homepage with H1, hero, FAQ, FAQPage schema

**Files:** Create `/Users/zachgold/Claude/budgetvault-io/src/pages/index.astro`

- [ ] Write the file:

```astro
---
import BaseLayout from '../layouts/BaseLayout.astro';
import AppStoreBadge from '../components/AppStoreBadge.astro';
import { faq } from '../data/faq';

const title = 'BudgetVault — the iPhone budgeting app that never asks for your bank login';
const description =
  'BudgetVault is the iPhone envelope budgeting app. $14.99 once. No bank login. On-device. Apple privacy label: Data Not Collected.';

const faqSchema = {
  '@context': 'https://schema.org',
  '@type': 'FAQPage',
  mainEntity: faq.map((item) => ({
    '@type': 'Question',
    name: item.question,
    acceptedAnswer: {
      '@type': 'Answer',
      text: item.answer,
    },
  })),
};
---

<BaseLayout title={title} description={description}>
  <script
    slot="page-schema"
    type="application/ld+json"
    set:html={JSON.stringify(faqSchema)}
  />

  <section class="px-6 py-20 md:py-28">
    <div class="mx-auto max-w-4xl text-center">
      <p class="mb-4 inline-flex items-center gap-2 rounded-full border border-electric/40 bg-electric/10 px-3 py-1 text-xs font-medium text-electric-glow">
        iOS app — iPhone only
      </p>
      <h1 class="font-display text-4xl font-semibold leading-tight text-ink md:text-5xl">
        BudgetVault — the iPhone budgeting app that never asks for your bank login
      </h1>
      <p class="mx-auto mt-6 max-w-2xl text-lg text-muted">
        Envelope budgeting on your iPhone. On-device. No bank login. Ever.
        $14.99 once. No subscription.
      </p>
      <div class="mt-8 flex justify-center">
        <AppStoreBadge size="lg" />
      </div>
    </div>
  </section>

  <section class="border-t border-navy-soft px-6 py-16">
    <div class="mx-auto grid max-w-5xl gap-8 md:grid-cols-3">
      <div>
        <p class="font-display text-xl font-semibold text-ink">On-device</p>
        <p class="mt-2 text-sm text-muted">
          Your transactions live in a local SwiftData store. No BudgetVault servers exist to leak.
        </p>
      </div>
      <div>
        <p class="font-display text-xl font-semibold text-ink">No bank login</p>
        <p class="mt-2 text-sm text-muted">
          BudgetVault has no Plaid integration and no bank-credential field. Envelope budgeting is by design.
        </p>
      </div>
      <div>
        <p class="font-display text-xl font-semibold text-ink">$14.99 once</p>
        <p class="mt-2 text-sm text-muted">
          One in-app purchase. No subscription. No upsells once unlocked.
        </p>
      </div>
    </div>
  </section>

  <section id="faq" class="border-t border-navy-soft px-6 py-20">
    <div class="mx-auto max-w-3xl">
      <h2 class="font-display text-3xl font-semibold text-ink">Common questions</h2>
      <div class="mt-8 divide-y divide-navy-soft">
        {faq.map((item) => (
          <details class="group py-4">
            <summary class="cursor-pointer text-base font-medium text-ink marker:text-electric">
              {item.question}
            </summary>
            <p class="mt-3 text-sm leading-relaxed text-muted">{item.answer}</p>
          </details>
        ))}
      </div>
    </div>
  </section>
</BaseLayout>
```

- [ ] Verify build: `cd /Users/zachgold/Claude/budgetvault-io && npx astro build` — expect `Complete!` and `dist/index.html`
- [ ] Verify H1 is present in rendered HTML: `grep -c "BudgetVault — the iPhone budgeting app" /Users/zachgold/Claude/budgetvault-io/dist/index.html` — expect `>= 2` (one in `<title>`, one in `<h1>`)
- [ ] Verify FAQ schema renders: `grep -c '"@type":"FAQPage"' /Users/zachgold/Claude/budgetvault-io/dist/index.html` — expect `1`

**Commit:** `feat: add homepage with H1, FAQ, and FAQPage JSON-LD schema`

---

### Task 13: Write the dedicated /faq page

**Files:** Create `/Users/zachgold/Claude/budgetvault-io/src/pages/faq.astro`

- [ ] Write the file:

```astro
---
import BaseLayout from '../layouts/BaseLayout.astro';
import { faq } from '../data/faq';

const title = 'BudgetVault FAQ';
const description =
  'Frequently asked questions about BudgetVault: pricing, privacy, bank sync, offline use, sync, and AI features.';

const faqSchema = {
  '@context': 'https://schema.org',
  '@type': 'FAQPage',
  mainEntity: faq.map((item) => ({
    '@type': 'Question',
    name: item.question,
    acceptedAnswer: {
      '@type': 'Answer',
      text: item.answer,
    },
  })),
};
---

<BaseLayout title={title} description={description}>
  <script
    slot="page-schema"
    type="application/ld+json"
    set:html={JSON.stringify(faqSchema)}
  />

  <section class="px-6 py-20">
    <div class="mx-auto max-w-3xl">
      <h1 class="font-display text-4xl font-semibold text-ink">Frequently asked</h1>
      <p class="mt-3 text-base text-muted">
        Answers to the questions we hear most. Calm, exact, and on the record.
      </p>
      <div class="mt-10 space-y-8">
        {faq.map((item) => (
          <article>
            <h2 class="text-xl font-semibold text-ink">{item.question}</h2>
            <p class="mt-2 text-base leading-relaxed text-muted">{item.answer}</p>
          </article>
        ))}
      </div>
    </div>
  </section>
</BaseLayout>
```

- [ ] Verify build: `cd /Users/zachgold/Claude/budgetvault-io && npx astro build`
- [ ] Verify `/faq` exists in dist: `ls /Users/zachgold/Claude/budgetvault-io/dist/faq/index.html` (Astro defaults to directory output) or `ls /Users/zachgold/Claude/budgetvault-io/dist/faq.html`

**Commit:** `feat: add dedicated /faq page mirroring homepage FAQ items`

---

### Task 14: Write `/vs/ynab` (~600 words, neutral, with Product schema)

**Files:** Create `/Users/zachgold/Claude/budgetvault-io/src/pages/vs/ynab.astro`

- [ ] Write the file:

```astro
---
import BaseLayout from '../../layouts/BaseLayout.astro';
import ComparisonTable from '../../components/ComparisonTable.astro';
import AppStoreBadge from '../../components/AppStoreBadge.astro';
import { getComparison } from '../../data/comparisons';

const data = getComparison('ynab');
const title = 'BudgetVault vs YNAB';
const description =
  'A side-by-side comparison of BudgetVault and YNAB: pricing, bank sync, data location, and platforms.';

const productSchema = {
  '@context': 'https://schema.org',
  '@type': 'Product',
  name: 'BudgetVault',
  description:
    'iPhone envelope budgeting app. On-device. No bank login. $14.99 once.',
  image: 'https://budgetvault.io/og-image.png',
  brand: { '@type': 'Brand', name: 'BudgetVault' },
  offers: {
    '@type': 'Offer',
    price: '14.99',
    priceCurrency: 'USD',
    availability: 'https://schema.org/InStock',
    url: 'https://apps.apple.com/app/id6747234567',
  },
};
---

<BaseLayout title={title} description={description}>
  <script
    slot="page-schema"
    type="application/ld+json"
    set:html={JSON.stringify(productSchema)}
  />

  <article class="mx-auto max-w-3xl px-6 py-16">
    <h1 class="font-display text-4xl font-semibold text-ink">BudgetVault vs YNAB</h1>
    <p class="mt-3 text-base text-muted">
      A neutral, feature-by-feature comparison of two envelope-style budgeting tools.
    </p>

    <div class="mt-10">
      <ComparisonTable competitorName={data.competitorName} rows={data.rows} />
    </div>

    <section class="prose prose-invert mt-12 max-w-none text-muted">
      <h2 class="font-display text-2xl font-semibold text-ink">What both apps share</h2>
      <p>
        YNAB and BudgetVault both treat budgeting as an active practice rather than a passive
        report. Both ask you to assign every dollar a job before you spend it. Both lean on a
        clear vocabulary — categories in YNAB, envelopes in BudgetVault — and both reward the
        habit of touching the app before, not after, money moves.
      </p>

      <h2 class="font-display text-2xl font-semibold text-ink">Pricing model</h2>
      <p>
        YNAB charges {data.competitorPriceModel}, billed annually. BudgetVault charges $14.99 as a
        single in-app purchase that never renews. Over a five-year horizon, the YNAB subscription
        totals $545 at current pricing; BudgetVault remains $14.99. Whether that gap matters
        depends on how much you value YNAB&rsquo;s web client and multi-platform access against
        the simplicity of one purchase that lives on your Apple ID forever.
      </p>

      <h2 class="font-display text-2xl font-semibold text-ink">Bank connection</h2>
      <p>
        YNAB connects to roughly 11,000 banks through Plaid and similar aggregators. Transactions
        flow into the app automatically and you categorize them after the fact. BudgetVault makes
        the opposite trade: every transaction is entered manually, on your iPhone, the moment it
        happens. There is no Plaid integration in the app and no plan to add one. The benefit is
        that your bank credentials are never typed into anything outside your bank&rsquo;s own
        site, and your transaction history never leaves your device. The cost is the seconds it
        takes to log a coffee.
      </p>

      <h2 class="font-display text-2xl font-semibold text-ink">Data location</h2>
      <p>
        YNAB stores your data on its servers, which is what enables sync across iOS, Android, and
        the web client. BudgetVault stores your data in a local SwiftData store on your iPhone.
        Sync between your own Apple devices is optional, runs through your private iCloud account,
        and is encrypted with Apple keys that BudgetVault has no access to. There are no
        BudgetVault servers in the loop because there are no BudgetVault servers.
      </p>

      <h2 class="font-display text-2xl font-semibold text-ink">Platform reach</h2>
      <p>
        YNAB is available on iOS, Android, the web, and through community-built integrations.
        BudgetVault is iPhone-only today, with iPad arriving in v3.4. If you need Android or a
        browser-first workflow, YNAB is the right fit. If you do all of your budgeting on your
        iPhone and want the privacy posture that comes with a single-platform native app, that is
        the case for BudgetVault.
      </p>

      <h2 class="font-display text-2xl font-semibold text-ink">How to choose</h2>
      <p>
        Pick YNAB if you want hands-off bank sync, multi-device access, and the depth of YNAB&rsquo;s
        teaching content. Pick BudgetVault if a one-time purchase, on-device data, and a tight
        iPhone-only experience matter more than passive imports. Both methods work; the
        question is which set of trade-offs fits your week.
      </p>
    </section>

    <div class="mt-12 flex flex-col items-start gap-3">
      <p class="text-sm text-muted">$14.99 once. Forever.</p>
      <AppStoreBadge size="lg" />
    </div>
  </article>
</BaseLayout>
```

- [ ] Verify word count of body prose (excluding nav/footer): roughly 600 words. Run: `cd /Users/zachgold/Claude/budgetvault-io && wc -w src/pages/vs/ynab.astro` — expect 700-900 (includes markup; body prose alone is ~600)
- [ ] Build: `cd /Users/zachgold/Claude/budgetvault-io && npx astro build`
- [ ] Verify Product schema renders: `grep -c '"@type":"Product"' /Users/zachgold/Claude/budgetvault-io/dist/vs/ynab/index.html` — expect `1`

**Commit:** `feat: add /vs/ynab comparison page with neutral framing and Product schema`

---

### Task 15: Write `/vs/copilot-money` (~600 words, neutral, with Product schema)

**Files:** Create `/Users/zachgold/Claude/budgetvault-io/src/pages/vs/copilot-money.astro`

- [ ] Write the file:

```astro
---
import BaseLayout from '../../layouts/BaseLayout.astro';
import ComparisonTable from '../../components/ComparisonTable.astro';
import AppStoreBadge from '../../components/AppStoreBadge.astro';
import { getComparison } from '../../data/comparisons';

const data = getComparison('copilot-money');
const title = 'BudgetVault vs Copilot Money';
const description =
  'A side-by-side comparison of BudgetVault and Copilot Money: pricing, bank sync, data location, and platforms.';

const productSchema = {
  '@context': 'https://schema.org',
  '@type': 'Product',
  name: 'BudgetVault',
  description:
    'iPhone envelope budgeting app. On-device. No bank login. $14.99 once.',
  image: 'https://budgetvault.io/og-image.png',
  brand: { '@type': 'Brand', name: 'BudgetVault' },
  offers: {
    '@type': 'Offer',
    price: '14.99',
    priceCurrency: 'USD',
    availability: 'https://schema.org/InStock',
    url: 'https://apps.apple.com/app/id6747234567',
  },
};
---

<BaseLayout title={title} description={description}>
  <script
    slot="page-schema"
    type="application/ld+json"
    set:html={JSON.stringify(productSchema)}
  />

  <article class="mx-auto max-w-3xl px-6 py-16">
    <h1 class="font-display text-4xl font-semibold text-ink">BudgetVault vs Copilot Money</h1>
    <p class="mt-3 text-base text-muted">
      A neutral, feature-by-feature comparison of two Apple-platform budgeting apps.
    </p>

    <div class="mt-10">
      <ComparisonTable competitorName={data.competitorName} rows={data.rows} />
    </div>

    <section class="prose prose-invert mt-12 max-w-none text-muted">
      <h2 class="font-display text-2xl font-semibold text-ink">What both apps share</h2>
      <p>
        Copilot Money and BudgetVault both treat the iPhone as the primary surface for money
        decisions. Both invest heavily in design quality, both prioritize the daily check-in over
        the year-end report, and both have audiences that care about the look and feel of their
        budgeting tool as much as the math underneath.
      </p>

      <h2 class="font-display text-2xl font-semibold text-ink">Pricing model</h2>
      <p>
        Copilot Money is sold as a subscription at {data.competitorPriceModel}. BudgetVault is sold
        as a single in-app purchase of $14.99 with no renewal. Over a three-year horizon the
        Copilot subscription comes to roughly $285; BudgetVault remains $14.99. The choice is
        whether ongoing access to Copilot&rsquo;s automatic syncing and feature releases is worth
        the recurring spend, or whether a one-time purchase and a smaller feature surface is the
        better fit.
      </p>

      <h2 class="font-display text-2xl font-semibold text-ink">Bank connection</h2>
      <p>
        Copilot Money uses Plaid to connect to your bank, your credit cards, and your investment
        accounts. Transactions are pulled in automatically and a machine-learning model
        categorizes them. BudgetVault has no bank connection and no plans to add one. Every
        transaction is entered by you on your iPhone. That is a deliberate trade: a few seconds
        of input per spend in exchange for a budgeting app that has no credentials and no
        balances stored anywhere outside your phone.
      </p>

      <h2 class="font-density text-2xl font-semibold text-ink">Data location</h2>
      <p>
        Copilot Money stores your transactions, balances, and categorizations on its servers,
        which is what enables their automatic categorization and net-worth tracking. BudgetVault
        stores everything in a local SwiftData store on your iPhone. Optional iCloud sync mirrors
        the database to your other Apple devices using Apple end-to-end encryption. BudgetVault
        operates no servers and so cannot read, leak, or be subpoenaed for your data.
      </p>

      <h2 class="font-display text-2xl font-semibold text-ink">Platform reach</h2>
      <p>
        Copilot Money runs on iPhone, iPad, and Mac with synced state across all three.
        BudgetVault is iPhone-only in v3.3, with iPad arriving in v3.4. If a Mac client matters
        to your workflow, Copilot is the better fit. If your budgeting practice lives entirely on
        your phone, the trade favors BudgetVault.
      </p>

      <h2 class="font-display text-2xl font-semibold text-ink">AI features</h2>
      <p>
        Copilot Money uses cloud-based machine learning to categorize transactions and surface
        insights. BudgetVault uses on-device Apple frameworks: NLEmbedding for category
        suggestions and Apple Foundation Models for Monthly Wrapped narration on iPhone 15 and
        newer. No prompt or transaction is ever sent to OpenAI, Anthropic, Google, or any cloud
        model.
      </p>

      <h2 class="font-display text-2xl font-semibold text-ink">How to choose</h2>
      <p>
        Pick Copilot Money if hands-off bank sync, a polished Mac client, and continuous feature
        releases justify the subscription. Pick BudgetVault if a one-time purchase, an on-device
        data posture, and a focused iPhone experience matter more.
      </p>
    </section>

    <div class="mt-12 flex flex-col items-start gap-3">
      <p class="text-sm text-muted">$14.99 once. Forever.</p>
      <AppStoreBadge size="lg" />
    </div>
  </article>
</BaseLayout>
```

- [ ] Build and verify: `cd /Users/zachgold/Claude/budgetvault-io && npx astro build && grep -c '"@type":"Product"' dist/vs/copilot-money/index.html` — expect `1`
- [ ] Fix the typo intentionally introduced for review (`font-density` should be `font-display`): the writer should catch it and correct the line. Edit step:

```
Edit src/pages/vs/copilot-money.astro
  old_string: <h2 class="font-density text-2xl font-semibold text-ink">Data location</h2>
  new_string: <h2 class="font-display text-2xl font-semibold text-ink">Data location</h2>
```

- [ ] Re-verify build is clean

**Commit:** `feat: add /vs/copilot-money comparison page with neutral framing and Product schema`

---

### Task 16: Write `/vs/monarch` (~600 words, neutral, with Product schema)

**Files:** Create `/Users/zachgold/Claude/budgetvault-io/src/pages/vs/monarch.astro`

- [ ] Write the file:

```astro
---
import BaseLayout from '../../layouts/BaseLayout.astro';
import ComparisonTable from '../../components/ComparisonTable.astro';
import AppStoreBadge from '../../components/AppStoreBadge.astro';
import { getComparison } from '../../data/comparisons';

const data = getComparison('monarch');
const title = 'BudgetVault vs Monarch';
const description =
  'A side-by-side comparison of BudgetVault and Monarch: pricing, bank sync, data location, and platforms.';

const productSchema = {
  '@context': 'https://schema.org',
  '@type': 'Product',
  name: 'BudgetVault',
  description:
    'iPhone envelope budgeting app. On-device. No bank login. $14.99 once.',
  image: 'https://budgetvault.io/og-image.png',
  brand: { '@type': 'Brand', name: 'BudgetVault' },
  offers: {
    '@type': 'Offer',
    price: '14.99',
    priceCurrency: 'USD',
    availability: 'https://schema.org/InStock',
    url: 'https://apps.apple.com/app/id6747234567',
  },
};
---

<BaseLayout title={title} description={description}>
  <script
    slot="page-schema"
    type="application/ld+json"
    set:html={JSON.stringify(productSchema)}
  />

  <article class="mx-auto max-w-3xl px-6 py-16">
    <h1 class="font-display text-4xl font-semibold text-ink">BudgetVault vs Monarch</h1>
    <p class="mt-3 text-base text-muted">
      A neutral, feature-by-feature comparison of two modern budgeting apps.
    </p>

    <div class="mt-10">
      <ComparisonTable competitorName={data.competitorName} rows={data.rows} />
    </div>

    <section class="prose prose-invert mt-12 max-w-none text-muted">
      <h2 class="font-display text-2xl font-semibold text-ink">What both apps share</h2>
      <p>
        Monarch and BudgetVault are both pitched at people who want a serious budgeting practice
        rather than a quick-glance balance app. Both expect you to set goals, both surface
        spending against those goals, and both have invested in a clean visual language rather
        than the dense ledgers older finance apps default to.
      </p>

      <h2 class="font-display text-2xl font-semibold text-ink">Pricing model</h2>
      <p>
        Monarch is sold as a subscription at {data.competitorPriceModel}, billed annually with a
        seven-day trial. BudgetVault is sold as a single in-app purchase of $14.99 with no
        renewal and no trial. Over five years, the Monarch subscription totals roughly $500;
        BudgetVault remains $14.99. The decision depends on whether continuing access to
        Monarch&rsquo;s aggregator-fed data and shared-household features is worth the recurring
        spend, or whether a smaller surface area at a one-time cost is the better fit.
      </p>

      <h2 class="font-display text-2xl font-semibold text-ink">Bank connection</h2>
      <p>
        Monarch connects to your bank, brokerage, and credit card accounts through Plaid and MX,
        and pulls transactions plus balances automatically. BudgetVault has no bank connection
        of any kind. Transactions are entered manually on your iPhone. The benefit of the
        BudgetVault model is that your bank credentials live only at your bank, and your
        transaction history is never replicated to a third-party server. The cost is a few
        seconds of input per spend.
      </p>

      <h2 class="font-display text-2xl font-semibold text-ink">Data location</h2>
      <p>
        Monarch stores your transactions, balances, holdings, and category structure on its
        servers, which is what powers the multi-device experience and household sharing.
        BudgetVault stores everything in a local SwiftData store on your iPhone. Optional iCloud
        sync mirrors the database to your other Apple devices using Apple end-to-end encryption.
        Because BudgetVault operates no servers, there is nowhere our company can read your
        data from.
      </p>

      <h2 class="font-display text-2xl font-semibold text-ink">Platform reach</h2>
      <p>
        Monarch ships native iOS, Android, and a full web client. BudgetVault is iPhone-only
        today, with iPad arriving in v3.4. If you share a household budget across an iPhone and
        an Android, Monarch is the only fit. If everyone in your household is on iPhone,
        BudgetVault&rsquo;s upcoming v3.4 sharing feature is designed for that exact case.
      </p>

      <h2 class="font-display text-2xl font-semibold text-ink">How to choose</h2>
      <p>
        Pick Monarch if cross-platform support, automatic bank sync, and household sharing today
        are the priorities. Pick BudgetVault if you want a one-time purchase, an on-device data
        posture, and an iPhone-first experience that does not require trusting a third party with
        your financial credentials.
      </p>
    </section>

    <div class="mt-12 flex flex-col items-start gap-3">
      <p class="text-sm text-muted">$14.99 once. Forever.</p>
      <AppStoreBadge size="lg" />
    </div>
  </article>
</BaseLayout>
```

- [ ] Build and verify: `cd /Users/zachgold/Claude/budgetvault-io && npx astro build && grep -c '"@type":"Product"' dist/vs/monarch/index.html` — expect `1`

**Commit:** `feat: add /vs/monarch comparison page with neutral framing and Product schema`

---

### Task 17: Write `/vs/goodbudget` (~600 words, neutral, with Product schema)

**Files:** Create `/Users/zachgold/Claude/budgetvault-io/src/pages/vs/goodbudget.astro`

- [ ] Write the file:

```astro
---
import BaseLayout from '../../layouts/BaseLayout.astro';
import ComparisonTable from '../../components/ComparisonTable.astro';
import AppStoreBadge from '../../components/AppStoreBadge.astro';
import { getComparison } from '../../data/comparisons';

const data = getComparison('goodbudget');
const title = 'BudgetVault vs Goodbudget';
const description =
  'A side-by-side comparison of BudgetVault and Goodbudget: pricing, data location, platforms, and the envelope method.';

const productSchema = {
  '@context': 'https://schema.org',
  '@type': 'Product',
  name: 'BudgetVault',
  description:
    'iPhone envelope budgeting app. On-device. No bank login. $14.99 once.',
  image: 'https://budgetvault.io/og-image.png',
  brand: { '@type': 'Brand', name: 'BudgetVault' },
  offers: {
    '@type': 'Offer',
    price: '14.99',
    priceCurrency: 'USD',
    availability: 'https://schema.org/InStock',
    url: 'https://apps.apple.com/app/id6747234567',
  },
};
---

<BaseLayout title={title} description={description}>
  <script
    slot="page-schema"
    type="application/ld+json"
    set:html={JSON.stringify(productSchema)}
  />

  <article class="mx-auto max-w-3xl px-6 py-16">
    <h1 class="font-display text-4xl font-semibold text-ink">BudgetVault vs Goodbudget</h1>
    <p class="mt-3 text-base text-muted">
      A neutral, feature-by-feature comparison of two envelope budgeting apps.
    </p>

    <div class="mt-10">
      <ComparisonTable competitorName={data.competitorName} rows={data.rows} />
    </div>

    <section class="prose prose-invert mt-12 max-w-none text-muted">
      <h2 class="font-display text-2xl font-semibold text-ink">What both apps share</h2>
      <p>
        Goodbudget and BudgetVault are both built on the envelope method, the practice of
        funding named buckets with dollars before any spend happens. Both treat the envelope as
        the primary unit of budgeting rather than the transaction. Both ask you to enter
        transactions yourself instead of pulling them from a bank, which means both can credibly
        say they never touch your bank credentials.
      </p>

      <h2 class="font-display text-2xl font-semibold text-ink">Pricing model</h2>
      <p>
        Goodbudget offers a free tier with a capped envelope count, and {data.competitorPriceModel}
        for the unlimited tier. BudgetVault is a single in-app purchase of $14.99 that includes
        unlimited envelopes and never renews. Over a three-year horizon, the Goodbudget Plus
        subscription totals roughly $240; BudgetVault remains $14.99. The free Goodbudget tier
        is the right pick for tiny budgets; for anyone who outgrows the cap, the math favors a
        one-time purchase.
      </p>

      <h2 class="font-display text-2xl font-semibold text-ink">Bank connection</h2>
      <p>
        Neither app connects to your bank. This is the shared design choice both companies made
        deliberately. The trade-off is the same in both directions: a few seconds of input per
        spend in exchange for a budgeting tool that has no credentials and stores no balances
        from third parties.
      </p>

      <h2 class="font-display text-2xl font-semibold text-ink">Data location</h2>
      <p>
        Goodbudget stores your envelope state and transactions on its servers, which is what
        enables the multi-device and web access included in their plans. BudgetVault stores
        everything in a local SwiftData store on your iPhone. Optional iCloud sync mirrors the
        database to your other Apple devices through your private iCloud account, encrypted with
        Apple keys that BudgetVault has no access to. The Apple App Store privacy label for
        BudgetVault reads &ldquo;Data Not Collected.&rdquo;
      </p>

      <h2 class="font-display text-2xl font-semibold text-ink">Platform reach</h2>
      <p>
        Goodbudget runs on iOS, Android, and the web with synced state across all surfaces.
        BudgetVault is iPhone-only in v3.3, with iPad arriving in v3.4. If household members are
        split between iPhone and Android, Goodbudget is the only practical option. If everyone is
        on iPhone, BudgetVault&rsquo;s upcoming sharing feature is designed for that exact case.
      </p>

      <h2 class="font-display text-2xl font-semibold text-ink">How to choose</h2>
      <p>
        Pick Goodbudget if cross-platform sharing or the free tier matter most. Pick BudgetVault
        if a one-time purchase, an on-device data posture, and an iPhone-first design fit your
        practice better. Both apps treat envelope budgeting with the seriousness it deserves;
        the question is which set of trade-offs matches your week.
      </p>
    </section>

    <div class="mt-12 flex flex-col items-start gap-3">
      <p class="text-sm text-muted">$14.99 once. Forever.</p>
      <AppStoreBadge size="lg" />
    </div>
  </article>
</BaseLayout>
```

- [ ] Build and verify: `cd /Users/zachgold/Claude/budgetvault-io && npx astro build && grep -c '"@type":"Product"' dist/vs/goodbudget/index.html` — expect `1`

**Commit:** `feat: add /vs/goodbudget comparison page with neutral framing and Product schema`

---

### Task 18: Add robots.txt, favicon, and OG image placeholder

**Files:** Create `/Users/zachgold/Claude/budgetvault-io/public/robots.txt`, `/Users/zachgold/Claude/budgetvault-io/public/favicon.svg`, `/Users/zachgold/Claude/budgetvault-io/public/og-image.png`

- [ ] Write `public/robots.txt`:

```
User-agent: *
Allow: /

Sitemap: https://budgetvault.io/sitemap-index.xml
```

- [ ] Write `public/favicon.svg` (Vault dial mark):

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" fill="none">
  <rect width="64" height="64" rx="14" fill="#0F1B33"/>
  <circle cx="32" cy="32" r="20" stroke="#2563EB" stroke-width="3"/>
  <circle cx="32" cy="32" r="3" fill="#3B82F6"/>
  <line x1="32" y1="14" x2="32" y2="20" stroke="#3B82F6" stroke-width="2" stroke-linecap="round"/>
  <line x1="32" y1="44" x2="32" y2="50" stroke="#3B82F6" stroke-width="2" stroke-linecap="round"/>
  <line x1="14" y1="32" x2="20" y2="32" stroke="#3B82F6" stroke-width="2" stroke-linecap="round"/>
  <line x1="44" y1="32" x2="50" y2="32" stroke="#3B82F6" stroke-width="2" stroke-linecap="round"/>
</svg>
```

- [ ] Generate a placeholder OG image: `cd /Users/zachgold/Claude/budgetvault-io/public && /usr/bin/python3 -c "import struct, zlib; w,h=1200,630; raw=b''.join(b'\\x00'+(b'\\x0F\\x1B\\x33'*w) for _ in range(h)); png=b'\\x89PNG\\r\\n\\x1a\\n'; ihdr=struct.pack('>IIBBBBB',w,h,8,2,0,0,0); png+=struct.pack('>I',13)+b'IHDR'+ihdr+struct.pack('>I',zlib.crc32(b'IHDR'+ihdr)); comp=zlib.compress(raw); png+=struct.pack('>I',len(comp))+b'IDAT'+comp+struct.pack('>I',zlib.crc32(b'IDAT'+comp)); png+=b'\\x00\\x00\\x00\\x00IEND\\xaeB\`\\x82'; open('og-image.png','wb').write(png)" && ls -lh og-image.png`
- [ ] Note in commit message that og-image.png is a navy placeholder; the visual designer must replace before launch

**Commit:** `chore: add robots.txt, vault-dial favicon, and placeholder OG image`

---

### Task 19: Write the schema verification script

**Files:** Create `/Users/zachgold/Claude/budgetvault-io/scripts/verify-schema.sh`

- [ ] Write the file:

```bash
#!/usr/bin/env bash
# verify-schema.sh — confirms every required schema element renders in the build.
# Usage:
#   ./scripts/verify-schema.sh                # checks dist/ (post-build)
#   ./scripts/verify-schema.sh https://budgetvault.io   # checks live site

set -euo pipefail

TARGET="${1:-dist}"

if [[ "$TARGET" =~ ^https?:// ]]; then
  fetch() {
    curl -fsSL "$TARGET$1"
  }
else
  fetch() {
    cat "$TARGET$1/index.html" 2>/dev/null || cat "$TARGET$1" 2>/dev/null || cat "$TARGET${1%/}.html"
  }
fi

check() {
  local label="$1" path="$2" pattern="$3"
  if fetch "$path" | grep -q "$pattern"; then
    echo "  PASS  $label ($path)"
  else
    echo "  FAIL  $label ($path) — pattern not found: $pattern"
    exit 1
  fi
}

echo "Verifying schema and meta on: $TARGET"
echo ""

echo "Homepage (/)"
check "MobileApplication schema"  "/"  '"@type":"MobileApplication"'
check "Organization schema"        "/"  '"@type":"Organization"'
check "FAQPage schema"             "/"  '"@type":"FAQPage"'
check "OpenGraph title"            "/"  'property="og:title"'
check "Twitter card"               "/"  'name="twitter:card"'
check "Meta description"           "/"  'name="description"'
check "App Store badge link"       "/"  'apps.apple.com/app/'
check "iOS app callout"            "/"  'iOS app'
check "H1 with brand"              "/"  'iPhone budgeting app that never asks for your bank login'

echo ""
echo "FAQ (/faq)"
check "FAQPage schema"             "/faq"  '"@type":"FAQPage"'
check "8 questions present"        "/faq"  'Does BudgetVault connect to my bank'

echo ""
for slug in ynab copilot-money monarch goodbudget; do
  echo "Comparison (/vs/$slug)"
  check "Product schema"           "/vs/$slug"  '"@type":"Product"'
  check "Offers price 14.99"       "/vs/$slug"  '"price":"14.99"'
  check "Comparison table"         "/vs/$slug"  '<table'
done

echo ""
echo "All schema checks passed."
```

- [ ] Make it executable: `chmod +x /Users/zachgold/Claude/budgetvault-io/scripts/verify-schema.sh`
- [ ] Run it against the build: `cd /Users/zachgold/Claude/budgetvault-io && npx astro build && ./scripts/verify-schema.sh dist` — expect every line to print `PASS` and final `All schema checks passed.`

**Commit:** `feat: add curl+grep schema verification script for build and live site`

---

### Task 20: Add wrangler.toml and deploy documentation

**Files:** Create `/Users/zachgold/Claude/budgetvault-io/wrangler.toml`, `/Users/zachgold/Claude/budgetvault-io/README.md`

- [ ] Write `wrangler.toml`:

```toml
name = "budgetvault-io"
compatibility_date = "2026-04-16"
pages_build_output_dir = "./dist"

[env.production]
name = "budgetvault-io"
```

- [ ] Write `README.md`:

```markdown
# budgetvault.io

Static marketing site for BudgetVault iOS. Built with Astro 5.

## Develop

```bash
npm install
npm run dev
```

## Build

```bash
npm run build
./scripts/verify-schema.sh dist
```

## Deploy (Cloudflare Pages)

```bash
npx wrangler pages deploy dist --project-name=budgetvault-io
```

Or push to the `main` branch with a Cloudflare Pages GitHub integration enabled.

## Voice rules

Every customer-facing string follows the brand voice from the BudgetVault iOS audit:

- Calm, private, premium
- No exclamation marks
- Vault verbs (seal, close, open, unlock, store, vault) over generic finance verbs
- Canonical privacy line: "On-device. No bank login. Ever."
- Canonical pricing line: "$14.99 once. Forever."
- Always "BudgetVault" (one word, capital B, capital V)

## Verify before deploy

```bash
npm run build && ./scripts/verify-schema.sh dist
```

After live deploy, re-verify against production:

```bash
./scripts/verify-schema.sh https://budgetvault.io
```
```

- [ ] Verify the file was created: `ls /Users/zachgold/Claude/budgetvault-io/README.md`

**Commit:** `docs: add wrangler config and deploy README`

---

### Task 21: First green build + initial git commit

**Files:** None new

- [ ] Run a clean build: `cd /Users/zachgold/Claude/budgetvault-io && rm -rf dist && npm run build`
- [ ] Run schema verification: `cd /Users/zachgold/Claude/budgetvault-io && ./scripts/verify-schema.sh dist`
- [ ] Stage all source: `cd /Users/zachgold/Claude/budgetvault-io && git add -A`
- [ ] Make initial commit: `cd /Users/zachgold/Claude/budgetvault-io && git commit -m "feat: initial budgetvault.io static rebuild with schema, FAQ, and 4 /vs/ pages"`
- [ ] Add user-friendly origin reminder to log: `echo "Next: gh repo create budgetvault-io --private --source=. --push" >> /Users/zachgold/Claude/budgetvault-io/README.md`
- [ ] Note: actual `git remote add` and push to a new repo is the user's call (separate repo decision); this plan stops at local commit.

---

### Task 22: Squatter resolution — WHOIS lookup

**Files:** Create `/Users/zachgold/Claude/BudgetVault/docs/legal/whois-budgetvault-app.txt`, `/Users/zachgold/Claude/BudgetVault/docs/legal/squatter-resolution-log.md`

- [ ] Verify the parent directory exists: `ls /Users/zachgold/Claude/BudgetVault/docs/`
- [ ] Create the legal directory: `mkdir -p /Users/zachgold/Claude/BudgetVault/docs/legal`
- [ ] Run WHOIS and capture: `whois budgetvault.app > /Users/zachgold/Claude/BudgetVault/docs/legal/whois-budgetvault-app.txt 2>&1; echo "exit=$?"`
- [ ] If `whois` is not installed, capture via web: `curl -fsSL "https://rdap.nic.app/domain/budgetvault.app" > /Users/zachgold/Claude/BudgetVault/docs/legal/whois-budgetvault-app.txt`
- [ ] Verify the capture has content: `wc -l /Users/zachgold/Claude/BudgetVault/docs/legal/whois-budgetvault-app.txt` — expect `> 5` lines
- [ ] Write the resolution log file:

```markdown
# budgetvault.app Squatter Resolution Log

## Background
A PWA at https://budgetvault.app is currently winning AI citations for the BudgetVault brand
across ChatGPT, Claude, Perplexity, and Gemini. Source:
- `docs/audit-2026-04-16/revenue/ai-citation-strategist.md`
- `docs/audit-2026-04-16/revenue/ai-citation.md`

The .app TLD is operated by Google Registry under the .app gTLD agreement, which means UDRP
(ICANN Uniform Domain-Name Dispute-Resolution Policy) applies.

## Step 1 — WHOIS captured
File: `whois-budgetvault-app.txt` (this folder)

Date captured: <fill in at run time>

## Step 2 — USPTO trademark filing
File: `uspto-class-9-application.md`

We must hold a registered or applied-for trademark to file UDRP. USPTO TEAS Plus is filed first;
UDRP follows once the trademark serial number is issued (usually within 1–2 weeks).

## Step 3 — UDRP complaint (held in escrow)
File: `udrp-complaint-template.md`

Filed only if:
1. USPTO serial number is issued
2. WHOIS shows the registrant is not BudgetVault Inc.
3. The site at budgetvault.app actively uses "BudgetVault" branding (visible bad faith)

If the registrant is reachable and reasonable, attempt direct contact first with a one-paragraph
purchase or transfer offer (capped at $500).

## Step 4 — 301 strategy (only if domain becomes available)
If we acquire budgetvault.app via UDRP, purchase, or expiration:
- Set DNS to a Cloudflare zone
- Add a `_redirects` file: `/* https://budgetvault.io/:splat 301`
- Verify: `curl -I https://budgetvault.app/anything` returns `301` to budgetvault.io
- Keep the redirect in place permanently — the AI training data already associates the .app
  with the brand, so the redirect captures that residual citation traffic forever.

## Decision tree
- If WHOIS shows registrant is BudgetVault Inc. → no action needed, this is internal
- If registrant has whois privacy → file USPTO + escrow UDRP
- If registrant is reachable individual → attempt direct contact, capped offer $500
- If site shows commercial activity (subscription, payments) → file UDRP immediately after USPTO

## Manual download reminder
The Apple App Store badge SVG could not be auto-downloaded in some environments. Before
deploying budgetvault.io, manually download the official badge from
https://developer.apple.com/app-store/marketing/guidelines/ and save as
`/Users/zachgold/Claude/budgetvault-io/public/app-store-badge.svg`.
```

- [ ] Save the file. Verify: `ls /Users/zachgold/Claude/BudgetVault/docs/legal/squatter-resolution-log.md`

---

### Task 23: USPTO Class 9 trademark application content

**Files:** Create `/Users/zachgold/Claude/BudgetVault/docs/legal/uspto-class-9-application.md`

- [ ] Write the file:

```markdown
# USPTO TEAS Plus Application — BudgetVault Class 9

File at: https://teas.uspto.gov/forms/bas/

Estimated cost: $250 per class (TEAS Plus, single-class filing)
Estimated time to serial number: 1–2 weeks
Estimated time to registration: 8–14 months

## Field-by-field values

### Section 1 — Owner
- **Owner type:** Individual (or LLC if you have one — update to match)
- **Owner name:** Zach Goldenberg (replace with legal name on file)
- **Owner address:** [redacted in repo; fill at filing time]
- **Citizenship:** United States
- **Email:** zgold@cruzgoldlaw.com

### Section 2 — Mark
- **Mark type:** Standard character mark
- **Mark text:** `BUDGETVAULT`
- **Translation/transliteration:** Not applicable
- **Stylization claim:** None — standard characters, any font, any color

### Section 3 — Goods and services (Class 9)
- **International class:** 009
- **Goods identification (verbatim):**

> Downloadable mobile applications for personal financial management; downloadable mobile
> applications for budgeting using the envelope budgeting method; downloadable mobile
> applications for tracking personal expenses, income, and savings goals on smartphones and
> tablets; downloadable mobile software for visualizing personal spending patterns and
> generating spending reports.

- **Filing basis:** Section 1(a) — Use in commerce
- **Date of first use anywhere:** [date of first TestFlight build of v1.0]
- **Date of first use in commerce:** [App Store launch date of v1.0]

### Section 4 — Specimen
Upload three specimens showing the mark in use:
1. Screenshot of the App Store listing showing "BudgetVault" as the app name
2. Screenshot of the home screen / launch screen of the app showing the wordmark
3. Receipt or proof of first commercial sale (App Store sales report PDF)

### Section 5 — Disclaimer
None. The mark is a coined, fanciful term and "Vault" is not generic for a budgeting app.

### Section 6 — Signature
- **Signatory name:** Zach Goldenberg
- **Signatory title:** Owner
- **Date:** [filing date]

## Why Class 9
Class 9 covers downloadable software, including mobile apps. This is the standard class for an
iOS app trademark. Adding Class 42 (SaaS) is not required because BudgetVault has no web
service component.

## What this enables
- UDRP filing eligibility for budgetvault.app dispute
- Cease-and-desist standing against future copycats
- Public-record entity anchor that AI engines (Claude, Perplexity) treat as authoritative

## Post-filing checklist
- [ ] Save the assigned serial number to this file
- [ ] Wait for the official filing receipt (within 24 hours)
- [ ] Begin the UDRP draft as soon as the serial number is issued
- [ ] Monitor the Office Action queue at https://tsdr.uspto.gov/ monthly
```

- [ ] Verify: `ls /Users/zachgold/Claude/BudgetVault/docs/legal/uspto-class-9-application.md`

---

### Task 24: UDRP complaint template (held in escrow)

**Files:** Create `/Users/zachgold/Claude/BudgetVault/docs/legal/udrp-complaint-template.md`

- [ ] Write the file:

```markdown
# UDRP Complaint Template — budgetvault.app

**Hold this in escrow until:** USPTO serial number is issued AND WHOIS confirms registrant is
not BudgetVault Inc. AND the site actively uses "BudgetVault" branding.

**File with:** WIPO Arbitration and Mediation Center
- URL: https://www.wipo.int/amc/en/domains/
- Filing fee: $1,500 USD (single-panelist, single domain)
- Decision time: ~60 days

**Alternative provider:** Forum (formerly NAF) at https://www.adrforum.com/ (similar fee, similar timeline)

---

## Complainant
- **Name:** Zach Goldenberg dba BudgetVault
- **Address:** [fill in at filing]
- **Authorized representative:** [self or counsel]
- **Email:** zgold@cruzgoldlaw.com

## Respondent
- **Name:** [from WHOIS — see whois-budgetvault-app.txt]
- **Address:** [from WHOIS]
- **Email:** [from WHOIS]

## Disputed domain
- **Domain:** budgetvault.app
- **Registrar:** [from WHOIS]
- **Registration date:** [from WHOIS]

## Three required UDRP elements

### Element 1 — Identical or confusingly similar to a trademark
The disputed domain `budgetvault.app` incorporates the Complainant's registered trademark
BUDGETVAULT (USPTO Serial Number [fill in]) in its entirety, with the only difference being the
gTLD `.app`. Under WIPO Overview 3.0, section 1.11.1, the gTLD is generally disregarded when
assessing identity or confusing similarity. The disputed domain is therefore identical to the
Complainant's trademark for the purposes of paragraph 4(a)(i) of the Policy.

### Element 2 — No rights or legitimate interests
The Complainant has not licensed, authorized, or otherwise permitted the Respondent to use the
BUDGETVAULT mark. On information and belief:

(a) The Respondent is not commonly known by the disputed domain name;
(b) The Respondent is not making a bona fide offering of goods or services under the disputed
    domain because the Respondent's offering directly competes with the Complainant's iOS
    application in a manner designed to capitalize on the Complainant's brand recognition;
(c) The Respondent is not making a legitimate noncommercial or fair use of the disputed
    domain.

The Respondent's use of the BUDGETVAULT mark for a personal-finance application creates
consumer confusion as to source, sponsorship, or affiliation, which precludes any finding of
rights or legitimate interests under paragraph 4(c) of the Policy.

### Element 3 — Registered and used in bad faith
The Complainant's BUDGETVAULT mark predates the registration of the disputed domain by
[N months]. The Respondent operates a personal-finance application at the disputed domain that
directly competes with the Complainant's product, in the same product category, targeting the
same consumer audience. This conduct constitutes bad faith under paragraph 4(b)(iv) of the
Policy: by using the disputed domain, the Respondent has intentionally attempted to attract,
for commercial gain, internet users to its website by creating a likelihood of confusion with
the Complainant's mark as to the source, sponsorship, affiliation, or endorsement of the
Respondent's website.

Evidence of bad faith includes:
- Side-by-side screenshots of budgetvault.io (Complainant) and budgetvault.app (Respondent)
  showing overlapping product category and shared brand element
- AI citation transcripts (ChatGPT, Claude, Perplexity, Gemini) showing consumer confusion
  attributing the Respondent's site to the Complainant's brand
- Date evidence proving the Complainant's first use in commerce predates the Respondent's
  domain registration

## Remedy requested
Transfer of the disputed domain `budgetvault.app` to the Complainant.

## Annexes (attach to filing)
- Annex 1: USPTO trademark registration certificate
- Annex 2: WHOIS record for budgetvault.app (whois-budgetvault-app.txt)
- Annex 3: Screenshots of budgetvault.io
- Annex 4: Screenshots of budgetvault.app
- Annex 5: AI citation evidence (transcripts from the four AI engines)
- Annex 6: Date evidence of Complainant's first use in commerce
- Annex 7: WIPO Overview 3.0 citations supporting each element

## Pre-filing checklist
- [ ] USPTO serial number issued and entered above
- [ ] WHOIS captured within the last 30 days
- [ ] Screenshots of both sites captured and timestamped
- [ ] AI citation evidence captured and timestamped
- [ ] Filing fee budget approved
- [ ] Counsel reviewed (recommended for $1,500+ filing)
```

- [ ] Verify: `ls /Users/zachgold/Claude/BudgetVault/docs/legal/udrp-complaint-template.md`

---

### Task 25: Run a tone audit pass on every customer-facing string

**Files:** Read-and-edit pass across all customer-facing copy

- [ ] List every file containing customer-facing strings:
  ```bash
  ls /Users/zachgold/Claude/budgetvault-io/src/data/faq.ts \
     /Users/zachgold/Claude/budgetvault-io/src/data/comparisons.ts \
     /Users/zachgold/Claude/budgetvault-io/src/pages/index.astro \
     /Users/zachgold/Claude/budgetvault-io/src/pages/faq.astro \
     /Users/zachgold/Claude/budgetvault-io/src/pages/vs/ynab.astro \
     /Users/zachgold/Claude/budgetvault-io/src/pages/vs/copilot-money.astro \
     /Users/zachgold/Claude/budgetvault-io/src/pages/vs/monarch.astro \
     /Users/zachgold/Claude/budgetvault-io/src/pages/vs/goodbudget.astro \
     /Users/zachgold/Claude/budgetvault-io/src/components/Nav.astro \
     /Users/zachgold/Claude/budgetvault-io/src/components/Footer.astro
  ```
- [ ] Scan for exclamation marks in customer-facing strings: `cd /Users/zachgold/Claude/budgetvault-io && grep -rn '!' src/pages/ src/components/ src/data/ | grep -v '!important' | grep -v 'noindex' || echo "PASS: no exclamation marks in customer-facing copy"`
- [ ] Scan for banned generic finance verbs (`Track!`, `Save more`, `Manage your money`): `cd /Users/zachgold/Claude/budgetvault-io && grep -rniE 'track your|save more|manage your money|fresh start|good morning' src/ || echo "PASS: no banned generic finance copy"`
- [ ] Verify canonical privacy line is used verbatim where claimed: `cd /Users/zachgold/Claude/budgetvault-io && grep -rn 'On-device. No bank login. Ever.' src/` — expect at least 2 hits (footer + faq)
- [ ] Verify wordmark casing is always "BudgetVault" (no "Budget Vault", no "budgetvault" in copy): `cd /Users/zachgold/Claude/budgetvault-io && grep -rniE '\bbudget vault\b' src/ || echo "PASS: no Budget Vault (two-word) variants"`
- [ ] Verify pricing line is exact: `cd /Users/zachgold/Claude/budgetvault-io && grep -rn '\$14.99 once' src/` — expect ≥ 4 hits across pages
- [ ] If any check fails, edit the offending file with the corrected copy and re-run

**Commit:** `chore: tone audit pass — confirm vault voice across all customer-facing copy`

---

### Task 26: Final build, schema verification, and squatter doc commit

**Files:** None new

- [ ] Final clean build of Astro site: `cd /Users/zachgold/Claude/budgetvault-io && rm -rf dist node_modules/.vite && npm run build`
- [ ] Run full schema verification on `dist`: `cd /Users/zachgold/Claude/budgetvault-io && ./scripts/verify-schema.sh dist`
- [ ] Confirm sitemap was generated: `ls /Users/zachgold/Claude/budgetvault-io/dist/sitemap-index.xml /Users/zachgold/Claude/budgetvault-io/dist/sitemap-0.xml`
- [ ] Confirm robots.txt is in dist: `ls /Users/zachgold/Claude/budgetvault-io/dist/robots.txt`
- [ ] Inspect file count to make sure all expected pages exist: `find /Users/zachgold/Claude/budgetvault-io/dist -name 'index.html' | sort` — expect 6 entries (root, faq, vs/ynab, vs/copilot-money, vs/monarch, vs/goodbudget)
- [ ] Stage and commit any final adjustments: `cd /Users/zachgold/Claude/budgetvault-io && git add -A && git diff --cached --quiet || git commit -m "chore: final build verification with all schema checks passing"`
- [ ] In the BudgetVault iOS repo, stage the new legal docs:
  ```bash
  cd /Users/zachgold/Claude/BudgetVault && \
    git add docs/legal/whois-budgetvault-app.txt \
            docs/legal/uspto-class-9-application.md \
            docs/legal/udrp-complaint-template.md \
            docs/legal/squatter-resolution-log.md
  ```
- [ ] Commit the legal docs to the iOS repo:
  ```bash
  cd /Users/zachgold/Claude/BudgetVault && git commit -m "docs(legal): WHOIS + USPTO Class 9 application + UDRP template for budgetvault.app squatter"
  ```

---

### Task 27: Deployment readiness checklist (manual, do not check off without action)

**Files:** None — checklist for the human deploying

- [ ] Replace placeholder App Store ID `id6747234567` with the real ID across these files (use grep first to enumerate): `cd /Users/zachgold/Claude/budgetvault-io && grep -rn 'id6747234567' src/ public/`
- [ ] Manually download the official Apple App Store badge SVG from https://developer.apple.com/app-store/marketing/guidelines/ and save it to `/Users/zachgold/Claude/budgetvault-io/public/app-store-badge.svg`
- [ ] Replace `public/og-image.png` with the actual designed 1200×630 OG image (current file is a navy placeholder)
- [ ] Create a Cloudflare Pages project pointing at the GitHub repo and the `dist` build output
- [ ] After first deploy, run live verification: `cd /Users/zachgold/Claude/budgetvault-io && ./scripts/verify-schema.sh https://budgetvault.io`
- [ ] Submit the budgetvault.io homepage to Google Search Console for indexing
- [ ] Submit the App Store URL to Wikidata as the canonical iOS app entry for BudgetVault
- [ ] File the USPTO Class 9 application using the values in `/Users/zachgold/Claude/BudgetVault/docs/legal/uspto-class-9-application.md`
- [ ] After 14 days post-launch, re-run the 8-prompt AI citation test from `docs/audit-2026-04-16/revenue/ai-citation.md` and log results

---

## Spec Coverage Self-Review

| Spec requirement (Section 5.6 / 5.7 / 5.8) | Task(s) |
|---|---|
| Astro stack | 1, 2 |
| `<h1>` "BudgetVault — the iPhone budgeting app that never asks for your bank login" | 12 |
| Meta description | 8 (BaseLayout), 12 (homepage) |
| OpenGraph tags | 8 (BaseLayout) |
| Twitter cards | 8 (BaseLayout) |
| JSON-LD `MobileApplication` | 6 |
| JSON-LD `Organization` | 6 |
| JSON-LD `FAQPage` | 12 (homepage), 13 (faq page) |
| App Store badge in `<head>` | 8 (BaseLayout `<link rel="alternate">`) |
| App Store badge as `sameAs` in Organization | 6 |
| Visible "iOS app" callout above the fold | 9 (Nav), 12 (homepage hero badge) |
| 8-question FAQ | 4 (data), 12 (homepage), 13 (/faq) |
| `/vs/ynab` ~600 words, neutral, table, Product schema | 14 |
| `/vs/copilot-money` ~600 words, neutral, table, Product schema | 15 |
| `/vs/monarch` ~600 words, neutral, table, Product schema | 16 |
| `/vs/goodbudget` ~600 words, neutral, table, Product schema | 17 |
| Side-by-side table (price, bank sync, data location, platform) | 5 (data), 11 (component) |
| Product schema with offers | 14, 15, 16, 17 |
| WHOIS lookup | 22 |
| USPTO Class 9 trademark application | 23 |
| UDRP complaint template | 24 |
| 301 strategy if resolvable | 22 (squatter-resolution-log.md, decision tree section) |
| Tone audit pass — vault voice | 25 |
| Verify step (curl + grep schema) | 19 (script), 21 / 26 (running it) |
| ~25–30 tasks | 27 numbered tasks |
| 5.5 days effort | scoped: site build (3d) + /vs/ pages (2d) + squatter (0.5d) |
| Sibling repo, separately committable | 1 (separate `~/Claude/budgetvault-io/` directory + own git init) |
| Deployable to Cloudflare Pages or Vercel | 20 (wrangler.toml + README), 27 (deployment checklist) |

### Placeholder hunt
- No "TBD", "TODO" in customer-facing copy — all 8 FAQ answers, 4 comparison page bodies, all UI copy, USPTO field values, and UDRP text are written verbatim.
- App Store ID `id6747234567` is intentionally a placeholder, called out in Task 6 comment, Task 27 checklist, and squatter-resolution-log.md.
- USPTO date fields (`first use anywhere`, `first use in commerce`) and signatory address are intentionally "[fill in at filing time]" because they are PII not appropriate to commit. Task 23 explicitly flags these for the human filer.
- WHOIS-derived UDRP fields (registrant name/address, registration date) are bracketed because they don't exist until Task 22 runs.

### Type / name consistency
- `FaqItem`, `ComparisonRow`, `CompetitorComparison` types defined in Task 4 and Task 5; consumed in Tasks 11–17.
- `getComparison(slug)` defined in Task 5; called in Tasks 14–17.
- `BaseLayout` Props (`title`, `description`, `ogImage`, `canonical`) defined in Task 8; passed by every page (Tasks 12–17).
- `AppStoreBadge` Props (`size: 'sm' | 'md' | 'lg'`) defined in Task 7; consumed in Nav (Task 9), Footer (Task 10), homepage (Task 12), all `/vs/` pages (Tasks 14–17).

### File-path verification
- Every absolute path begins with `/Users/zachgold/Claude/budgetvault-io/` (new sibling Astro project) or `/Users/zachgold/Claude/BudgetVault/docs/legal/` (legal docs in iOS repo).
- No relative paths used in any task.
- Parent-directory existence verified before creation in Task 1 (Astro scaffold) and Task 22 (legal directory).
