# ASO Acquisition Push Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship Week-4 ASO push for v3.3.0 — privacy-repositioned screenshots, 25-second App Preview, three Custom Product Pages, monthly Wrapped In-App Event, German metadata-only locale, Apple Offer Codes referral, and re-timed review prompts — to capture the 2026 privacy/AI-fatigue zeitgeist at the App Store surface.

**Architecture:** Hybrid plan. Five App Store Connect web-console tasks (no code) ship metadata, screenshots, video, IAE, CPPs, DE locale. Two Swift services ship in-app: `OfferCodeService` (Apple-hosted referral via `UIActivityViewController`) and re-timed `ReviewPromptService` (Wrapped completion + first reconciled month + Day-30 streak triggers). All in-app additions are additive — zero schema changes, zero migrations.

**Tech Stack:** Swift 5.9+, SwiftUI, StoreKit 2, UIKit (UIActivityViewController), XCTest. App Store Connect web console, `xcrun simctl io recordVideo` for App Preview capture.

**Estimated Effort:** 8 days

**Ship Target:** v3.3.0

---

## Pre-flight

- [ ] **Pre-flight 1:** Create branch off `v3.3-wedge`
  ```bash
  cd /Users/zachgold/Claude/BudgetVault
  git checkout v3.3-wedge && git pull
  git checkout -b v3.3-aso-acquisition
  ```

- [ ] **Pre-flight 2:** Confirm clean tree and build green
  ```bash
  git status
  xcodegen generate
  xcodebuild -scheme BudgetVault -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' build 2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
  ```
  Expected: `** BUILD SUCCEEDED **`, no error lines.

- [ ] **Pre-flight 3:** Verify App Store Connect access
  Sign in at https://appstoreconnect.apple.com with the team admin Apple ID. Confirm visibility of: Apps → BudgetVault → Distribution → App Store → iOS App → 3.3.0 prepare-for-submission row, Promote → Custom Product Pages, Promote → In-App Events, Promote → Offer Codes.

---

## File Structure

| Path | Change |
|---|---|
| `BudgetVault/Services/OfferCodeService.swift` | **Create** — eligibility + redemption-URL share helper |
| `BudgetVaultTests/OfferCodeServiceTests.swift` | **Create** — unit tests for eligibility gating |
| `BudgetVault/Services/ReviewPromptService.swift` | Modify — add `checkWrappedComplete`, `checkFirstReconciledMonth`, `checkStreakDay30`; remove existing 14-day trigger |
| `BudgetVaultTests/ReviewPromptServiceTests.swift` | **Create** — unit tests for new trigger gates |
| `BudgetVault/Services/StreakService.swift` | Modify — change milestone trigger from 14 to 30 day at line 113 |
| `BudgetVault/Views/Settings/SettingsView.swift` | Modify — add "Give a friend BudgetVault" row, gated to 30+ days post-purchase |
| `BudgetVault/Views/Dashboard/MonthlyWrappedView.swift` | Modify — call `ReviewPromptService.checkWrappedComplete()` after slide 5 share |
| `BudgetVault/Views/Transactions/HistoryView.swift` | Modify — call `ReviewPromptService.checkFirstReconciledMonth()` after first reconciliation completes a month |
| `BudgetVault/Utilities/AppStorageKeys.swift` | Modify — add `firstPremiumPurchaseDate`, `reviewTriggered_wrappedComplete`, `reviewTriggered_firstReconciledMonth`, `reviewTriggered_streakDay30` |
| `BudgetVault/Services/StoreKitManager.swift` | Modify — record `firstPremiumPurchaseDate` on successful entitlement |
| `docs/aso/v3.3.0-screenshot-copy.md` | **Create** — screenshot caption sheet for designer/uploader |
| `docs/aso/v3.3.0-app-preview-storyboard.md` | **Create** — 25-second video shot list with timestamps + capture commands |
| `docs/aso/v3.3.0-cpp-spec.md` | **Create** — three Custom Product Pages headline + screenshot lineups |
| `docs/aso/v3.3.0-iae-monthly-wrapped.md` | **Create** — In-App Event copy, schedule, and re-run playbook |
| `docs/aso/v3.3.0-de-metadata.md` | **Create** — finished German title/subtitle/keywords/description strings |
| `docs/aso/v3.3.0-vs-rocket-money.md` | **Create** — page outline + EPIC citation, for budgetvault.io marketing site |
| `docs/aso/v3.3.0-squatter-followup.md` | **Create** — WHOIS/UDRP/USPTO follow-up checklist for `budgetvault.app` |

---

## Task 1: Privacy Reposition — Screenshot 1 Caption ("60% share data") [Section 5.13]

**Files:**
- Create: `docs/aso/v3.3.0-screenshot-copy.md`

App Store Connect-only task. The screenshot graphic itself is already designed (B1 hero shot from `aso-v3.1.1.md:46`); we are rewording the overlay caption and adding the Incogni source line.

- [ ] **Step 1: Create caption spec file**

  Create `/Users/zachgold/Claude/BudgetVault/docs/aso/v3.3.0-screenshot-copy.md`:
  ```markdown
  # v3.3.0 Screenshot Captions — En-US

  ## Slot 1 — Privacy Reposition (NEW)
  - **Headline (top, 2 lines, 56pt SF Pro Display Bold, white):**
    `60% of budget apps share your data.`
    `We share zero.`
  - **Footer caption (bottom, 14pt SF Pro Text Regular, white 70%):**
    `Source: Incogni 2026 Budget App Privacy Study`
  - **Background:** B1 daily allowance hero, dark vault ring, accent neon
  - **Apple privacy badge:** "Data Not Collected" overlay, top-right, 22pt

  ## Slot 2 — Price Comparison (REWORDED to remove "YNAB" string)
  - **Headline (top, 2 lines, 56pt SF Pro Display Bold, white):**
    `Other budget apps: $109/year.`
    `BudgetVault: $14.99 once.`
  - **Sub-caption (centered, 24pt, white 80%):**
    `$14.99 vs $545 over 5 years.`
  - **Background:** generic bar chart graphic — NO competitor logo, NO "YNAB" string
  - **Reason:** Apple guideline 1.2 — naming a competitor in a screenshot can trigger rejection.

  ## Slot 3 — Daily Allowance Hero (UNCHANGED)
  - Caption: `Can I spend this?`
  - B1 closeup, no chrome, dark theme.

  ## Slot 4 — Wrapped (MOVED from slot 5)
  - Caption: `Your spending story. 5 slides. On device.`
  - Source: S1D donut intro frame.
  - Reason: Wrapped is the only screenshot organically shared on social per launch posts (`app-store-optimizer.md:28`).

  ## Slot 5 — Vault Intelligence (premium)
  - Caption: `Patterns. Not predictions.`

  ## Slot 6 — History H1B segmented picker (UNCHANGED)

  ## Slot 7 — Onboarding ceremony slide (UNCHANGED)

  ## Slot 8 — Settings showing "Send Feedback" (UNCHANGED)
  ```

- [ ] **Step 2: Commit the spec**
  ```bash
  cd /Users/zachgold/Claude/BudgetVault
  git add docs/aso/v3.3.0-screenshot-copy.md
  git commit -m "docs(aso): screenshot caption sheet for v3.3.0 privacy reposition"
  ```

- [ ] **Step 3: App Store Connect — upload re-captioned screenshots**
  Path: `Apps → BudgetVault → Distribution → App Store → iOS App → 3.3.0 → English (U.S.) → 6.7" Display`.
  1. Click each screenshot slot.
  2. Click "Replace Image" and upload the new render of slot 1 + slot 2 from your designer.
  3. Drag slot 4 (Wrapped) into the position currently held by slot 5; reorder remaining.
  4. Save.

  Expected: preview pane shows new copy on slot 1, no "YNAB" string visible on slot 2, Wrapped now appears at position 4.

---

## Task 2: Website Hero + "vs Rocket Money" Page Spec [Section 5.13]

**Files:**
- Create: `docs/aso/v3.3.0-vs-rocket-money.md`

External marketing-site task. We provide the page outline + canonical EPIC citation; the budgetvault.io static-render plan (Plan 02) ships the actual page.

- [ ] **Step 1: Create the `vs Rocket Money` page outline (with website hero copy block)**

  Create `/Users/zachgold/Claude/BudgetVault/docs/aso/v3.3.0-vs-rocket-money.md`:
  ```markdown
  # budgetvault.io / vs / rocket-money

  ## Sister deliverable: budgetvault.io homepage hero copy (spec 5.13)
  Insert into the static-render homepage `<h1>` + `<p>` lead, above-the-fold:

  - **H1:** `BudgetVault — the iPhone budgeting app that never asks for your bank login`
  - **Sub-hero (16pt body, white 80% on dark navy):**
    `No AI deciding for you. No subscription. No bank login.`
  - **CTA button:** `Get it on the App Store — $14.99 once`

  ---


  ## Page route
  `/vs/rocket-money` (matches the four `/vs/` page pattern from spec section 5.7)

  ## Title tag (60 char)
  `BudgetVault vs Rocket Money — Privacy Comparison 2026`

  ## Meta description (155 char)
  `Rocket Money was named in EPIC's 2026 CFPB complaint for sharing user financial data. BudgetVault collects nothing. $14.99 once.`

  ## H1
  `BudgetVault vs Rocket Money`

  ## Hero subhead
  `One asks for your bank login and shares the data. One doesn't, ever.`

  ## Side-by-side table (factual, no adversarial framing)
  | | Rocket Money | BudgetVault |
  |---|---|---|
  | Pricing | $4–12/month subscription | $14.99 once |
  | Bank login required | Yes (Plaid) | No |
  | Data shared with brokers | Yes — see EPIC complaint | No — "Data Not Collected" |
  | Bill negotiation (server-side) | Yes | No (intentionally) |
  | Subscription audit | Yes | Yes (on-device, v3.3) |
  | Platform | iOS + Android + web | iPhone only |

  ## EPIC citation block (factual)
  > In March 2026, the Electronic Privacy Information Center (EPIC) filed a complaint with the Consumer Financial Protection Bureau alleging Rocket Money's data-sharing practices violate consumer financial privacy law. — [EPIC press release](https://epic.org/) (link out)

  ## Closing CTA
  `Try BudgetVault — no bank login, no subscription, no data sharing. $14.99 once.`
  [App Store badge]

  ## Schema.org
  - `Product` schema with `offers.price = 14.99`
  - `FAQPage` schema with 3 Qs ("Does BudgetVault require my bank login?", "Is Rocket Money's bill negotiation worth it?", "What did EPIC's CFPB complaint allege?")
  - `sameAs` linking to Apple App Store URL
  ```

- [ ] **Step 2: Commit**
  ```bash
  git add docs/aso/v3.3.0-vs-rocket-money.md
  git commit -m "docs(aso): vs Rocket Money page outline with EPIC citation"
  ```

---

## Task 3: budgetvault.app Squatter Follow-up Checklist [Section 5.13]

**Files:**
- Create: `docs/aso/v3.3.0-squatter-followup.md`

Action-tracking doc. The squatter resolution work is in spec 5.8; this captures the follow-up checks tied to the v3.3.0 ASO push so a stale `.app` domain doesn't outrank our App Store listing for "BudgetVault" SERPs during the marketing window.

- [ ] **Step 1: Create the follow-up checklist**

  Create `/Users/zachgold/Claude/BudgetVault/docs/aso/v3.3.0-squatter-followup.md`:
  ```markdown
  # budgetvault.app Squatter — Follow-up Checklist

  Owner: Zach. Run weekly during the v3.3.0 marketing window (4 weeks post-ship).

  ## 1. WHOIS check (weekly)
  ```bash
  whois budgetvault.app | grep -E "Registrant|Registrar|Creation Date|Expir"
  ```
  Confirm registrant unchanged. If contact email surfaces, send the buyout offer drafted in spec 5.8.

  ## 2. Google "BudgetVault" SERP check (weekly)
  Open incognito. Search `BudgetVault`. Capture position of:
  - budgetvault.io (target: #1)
  - apps.apple.com/.../budgetvault (target: top-3)
  - budgetvault.app squatter (target: pushed off page 1)

  Log results in `docs/aso/serp-log.md`.

  ## 3. UDRP filing status
  - [ ] Confirm UDRP submitted via WIPO if no response after 14 days
  - [ ] Track case number in this file
  - [ ] Expected resolution: 60 days

  ## 4. USPTO trademark application
  - [ ] BudgetVault Class 9 (downloadable software) filed
  - [ ] Application number recorded: ____
  - [ ] Status check at https://tsdr.uspto.gov/

  ## 5. 301 redirect strategy (if squatter resolves)
  - Configure budgetvault.app DNS A record → budgetvault.io IP
  - Server-side: 301 redirect all paths to https://budgetvault.io/$1
  - Verify with `curl -I https://budgetvault.app`

  ## 6. AI assistant citation tests (weekly during marketing window)
  Prompt each of Claude, ChatGPT, Perplexity, Gemini with:
  - "What is the best privacy-first iOS budgeting app?"
  - "What is BudgetVault?"
  - "BudgetVault vs YNAB"
  Track which answers cite budgetvault.io vs squatter vs neither. Goal: ≥1 citation by end of v3.3.0 window.
  ```

- [ ] **Step 2: Commit**
  ```bash
  git add docs/aso/v3.3.0-squatter-followup.md
  git commit -m "docs(aso): squatter follow-up checklist for v3.3.0 marketing window"
  ```

---

## Task 4: App Preview Video — Storyboard + Capture Commands [Section 5.14]

**Files:**
- Create: `docs/aso/v3.3.0-app-preview-storyboard.md`

The 25-second video uses real UI captured by `xcrun simctl io recordVideo` (Apple requires real UI capture, not mockups). Storyboard is adapted from `ASO_Audit_BudgetVault.md:357-389` with the closing pricing card swapped per spec.

- [ ] **Step 1: Create the storyboard doc**

  Create `/Users/zachgold/Claude/BudgetVault/docs/aso/v3.3.0-app-preview-storyboard.md`:
  ```markdown
  # v3.3.0 App Preview Video — 25 seconds, portrait 886×1920

  ## Apple requirements (non-negotiable)
  - Resolution: 886×1920 (portrait, 9:16)
  - Duration: 15–30s — target 25s
  - Format: H.264 .mp4, max 500MB
  - Audio: app audio only or silence — no voiceover
  - Real app UI only — no mockups, no marketing graphics overlays except Apple-permitted text overlays
  - Apple-allowed text overlay: short captions matching what's on screen

  ## Lead frame (0–3s) — THE OWNABLE MOMENT
  - **Visual:** B1 daily allowance number animating up (0 → $42.18) against the dark vault ring on a black background
  - **Text overlay (top, 32pt SF Pro Display Semibold, white):** `Today's allowance.`
  - **App audio:** silence (let the vault ring tick)
  - **Capture:** start `xcrun simctl io recordVideo` then launch app from cold start; the B1 hero number-up animation fires automatically on DashboardView appear.

  ## Shot 2 (3–8s) — Envelope grid
  - **Visual:** thumb scroll through envelope category cards (Groceries, Transit, Fun)
  - **Text overlay:** `Envelope budgeting. On device.`
  - **App audio:** silence

  ## Shot 3 (8–14s) — Log a transaction
  - **Visual:** tap FAB → number pad → enter `14.50` → tap grocery emoji → tap Save → haptic ripple visible on save
  - **Text overlay:** `Log expenses in seconds.`
  - **App audio:** save haptic chirp (if any)

  ## Shot 4 (14–19s) — Insights / Wrapped tease
  - **Visual:** swipe to Insights tab; trend chart animates in; donut chart spins to show categories; quick cut to Wrapped slide 1 donut intro
  - **Text overlay:** `Your story. 5 slides. Private.`

  ## Shot 5 (19–23s) — Privacy badge
  - **Visual:** zoom into Settings showing the "Data Not Collected" Apple privacy badge
  - **Text overlay:** `No bank login. No subscription.`

  ## Closing card (23–25s) — REQUIRED PRICING CARD
  - **Visual:** BudgetVault icon centered, pricing text below
  - **Text overlay (large, 64pt SF Pro Display Bold, white on black):**
    `$14.99 once. Forever.`
  - **App audio:** silence

  ## Capture commands

  ### Set up the simulator
  ```bash
  open -a Simulator
  xcrun simctl boot "iPhone 17 Pro"
  xcrun simctl status_bar "iPhone 17 Pro" override --time "9:41" --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3
  ```

  ### Install build on simulator
  ```bash
  xcodebuild -scheme BudgetVault -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath /tmp/preview-build build
  xcrun simctl install booted /tmp/preview-build/Build/Products/Debug-iphonesimulator/BudgetVault.app
  ```

  ### Seed demo data
  ```bash
  xcrun simctl launch --console booted io.budgetvault.app -DemoSeed YES
  ```
  (`UITestSeedService` already exists in repo and supports `-DemoSeed YES` launch arg.)

  ### Record each shot
  ```bash
  # Shot 1 — lead frame, run for 4s then ctrl-c
  xcrun simctl io booted recordVideo --codec h264 --type mp4 ~/Movies/preview-shot1.mp4
  ```
  Repeat per shot. iPhone 17 Pro simulator records natively at 1290×2796; resize via ffmpeg:
  ```bash
  ffmpeg -i ~/Movies/preview-shot1.mp4 -vf scale=886:1920 -c:v libx264 -preset slow -crf 18 ~/Movies/preview-shot1-886.mp4
  ```

  ### Stitch + add captions in iMovie
  - Import all five shots in order
  - Add text titles per storyboard (Helvetica/SF Pro fallback, white)
  - Add closing card as a 2-second still
  - Export at 886×1920, H.264, .mp4

  ## Upload path
  Apps → BudgetVault → Distribution → App Store → iOS App → 3.3.0 → English (U.S.) → 6.7" Display → App Previews → Add. Video appears as the first asset in the gallery (before screenshot 1).

  ## Acceptance
  - Video plays for 25s ±2s
  - Closing pricing card reads exactly `$14.99 once. Forever.`
  - No voiceover audio detected
  - Real UI only (Apple reviewer should see live app, not slideshow)
  ```

- [ ] **Step 2: Capture lead frame video locally**

  Run the simulator setup + build first (synchronous):
  ```bash
  open -a Simulator
  xcrun simctl boot "iPhone 17 Pro" 2>/dev/null || true
  xcrun simctl status_bar booted override --time "9:41" --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3
  xcodebuild -scheme BudgetVault -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath /tmp/preview-build build 2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
  xcrun simctl install booted /tmp/preview-build/Build/Products/Debug-iphonesimulator/BudgetVault.app
  xcrun simctl launch booted io.budgetvault.app
  ```

  Then start the recorder in a separate terminal tab and stop it manually with `Ctrl+C` after ~4 seconds (the lead-frame B1 hero animates over the first 2–3 seconds of cold launch):
  ```bash
  xcrun simctl io booted recordVideo --codec h264 --type mp4 ~/Movies/bv-preview-shot1.mp4
  # ...wait ~4s then press Ctrl+C
  ```
  Expected: `~/Movies/bv-preview-shot1.mp4` exists, ~4s duration, B1 hero visible at the start.

- [ ] **Step 3: Capture remaining shots 2–5** following storyboard navigation. Each shot 4–6s wall-clock. Output files: `bv-preview-shot2.mp4` through `bv-preview-shot5.mp4`.

- [ ] **Step 4: Resize all shots to 886×1920**
  ```bash
  for i in 1 2 3 4 5; do
    ffmpeg -y -i ~/Movies/bv-preview-shot${i}.mp4 -vf scale=886:1920 -c:v libx264 -preset slow -crf 18 ~/Movies/bv-preview-shot${i}-886.mp4
  done
  ```

- [ ] **Step 5: Stitch in iMovie**, add per-storyboard text overlays + closing card, export to `~/Movies/bv-preview-v3.3.0.mp4` at 886×1920 H.264.

- [ ] **Step 6: Upload to App Store Connect**
  Path: Apps → BudgetVault → Distribution → App Store → iOS App → 3.3.0 → English (U.S.) → 6.7" Display → App Previews → drag-drop `bv-preview-v3.3.0.mp4`. Wait for Apple's automated frame-checker (~5 min). Confirm thumbnail shows the lead frame B1 hero.

- [ ] **Step 7: Commit storyboard doc**
  ```bash
  cd /Users/zachgold/Claude/BudgetVault
  git add docs/aso/v3.3.0-app-preview-storyboard.md
  git commit -m "docs(aso): 25-second App Preview storyboard + capture commands"
  ```

---

## Task 5: Custom Product Page Spec — `/ynab-refugee`, `/privacy`, `/wrapped` [Section 5.15]

**Files:**
- Create: `docs/aso/v3.3.0-cpp-spec.md`

App Store Connect supports up to 35 Custom Product Pages per app. We ship three for v3.3.0, each tuned to a campaign source.

- [ ] **Step 1: Create CPP spec doc**

  Create `/Users/zachgold/Claude/BudgetVault/docs/aso/v3.3.0-cpp-spec.md`:
  ```markdown
  # v3.3.0 Custom Product Pages — Spec

  Three CPPs ship for v3.3.0. Each has a unique URL (Apple-generated) used in Apple Search Ads, Reddit posts, and Twitter/X campaigns.

  ## CPP 1 — `/ynab-refugee`
  - **Internal name:** `ynab-refugee`
  - **Promotional text:** `Pay $14.99 once. Import your data in 60 seconds. No subscription, ever.`
  - **Screenshot 1 headline:** `Tired of $109/yr?`
  - **Screenshot 1 sub-caption:** `Switch in 60 sec.`
  - **Screenshot 1 visual:** CSV import flow + price-math overlay ($14.99 vs $545 over 5 years)
  - **Screenshot 2:** envelope categories grid
  - **Screenshot 3:** Wrapped slide 5 share card
  - **Use for:** Apple Search Ads bids on `ynab alternative`, `ynab refugee`, `budget no subscription`
  - **Reddit:** link from r/ynab, r/personalfinance posts

  ## CPP 2 — `/privacy`
  - **Internal name:** `privacy`
  - **Promotional text:** `Data Not Collected. No bank login. No tracking. $14.99 once.`
  - **Screenshot 1 headline:** `60% of budget apps share your data.`
  - **Screenshot 1 sub-caption:** `We share zero.`
  - **Screenshot 1 visual:** Apple "Data Not Collected" privacy badge over Face ID lock screenshot
  - **Screenshot 2:** Settings showing iCloud-only sync toggle
  - **Screenshot 3:** B1 daily allowance hero
  - **Use for:** Reddit r/privacy, r/degoogle posts; Apple Search Ads `private budget app`, `no bank sync budget`
  - **Reddit:** link from privacy-focused launch posts

  ## CPP 3 — `/wrapped`
  - **Internal name:** `wrapped`
  - **Promotional text:** `Your spending story. 5 slides. On device. Drops monthly.`
  - **Screenshot 1 headline:** `Your spending. As a story.`
  - **Screenshot 1 visual:** Spotify-style Wrapped slide stack mockup (S1D donut + slide 2 + slide 3 layered with offset)
  - **Screenshot 2:** Wrapped slide 5 share card
  - **Screenshot 3:** Wrapped slide 3 personality card
  - **Use for:** Twitter/X share-driven traffic; Apple Search Ads `monthly wrapped`
  - **Linked from:** Wrapped share-card QR code (already includes budgetvault.io URL → redirect rule routes share traffic here)

  ## App Store Connect navigation path
  Apps → BudgetVault → Distribution → Promote → Custom Product Pages → `+` (top right)
  - Internal Name: as above
  - Set as default? NO (default is generic listing)
  - Localization: English (U.S.) only for v3.3.0
  - Save → Submit for Review (CPPs require review, ~24h)
  - After approval, copy the Apple-issued URL (format: `https://apps.apple.com/us/app/budgetvault/id6473489221?ppid=<UUID>`)

  ## Acceptance
  - 3 CPPs in `In Review` or `Approved` state by ship day
  - URLs captured in this doc and in `research/marketing-plan.md`
  - First Reddit post links to `/ynab-refugee` CPP, not default page
  ```

- [ ] **Step 2: Commit spec**
  ```bash
  git add docs/aso/v3.3.0-cpp-spec.md
  git commit -m "docs(aso): three Custom Product Pages spec for v3.3.0"
  ```

- [ ] **Step 3: Submit `/ynab-refugee` CPP in App Store Connect**
  Path: Apps → BudgetVault → Distribution → Promote → Custom Product Pages → `+`. Use spec values. Upload screenshots from designer (lineup per spec). Submit for Review.

- [ ] **Step 4: Submit `/privacy` CPP** (same path, second `+`).

- [ ] **Step 5: Submit `/wrapped` CPP** (same path, third `+`).

- [ ] **Step 6: After Apple approval, paste each URL into the spec doc** under "URLs after approval" section — append to `docs/aso/v3.3.0-cpp-spec.md` and commit.

---

## Task 6: In-App Event for Monthly Wrapped — ASC Submission [Section 5.16]

**Files:**
- Create: `docs/aso/v3.3.0-iae-monthly-wrapped.md`

In-App Events surface in App Store search results and on the product page with their own card. Wrapped is monthly, so we ship the first event for the next available Sunday after v3.3.0 ships and document the re-run playbook for monthly cadence.

- [ ] **Step 1: Create IAE spec doc**

  Create `/Users/zachgold/Claude/BudgetVault/docs/aso/v3.3.0-iae-monthly-wrapped.md`:
  ```markdown
  # v3.3.0 In-App Event — Monthly Wrapped

  ## Event metadata (App Store Connect → Apps → BudgetVault → Distribution → Promote → In-App Events → `+`)

  - **Reference Name (internal, 64 char max):** `Monthly Wrapped — April 2026`
  - **Badge:** `Special Event` for first run; `New Season` once monthly cadence is established (per `app-store-optimizer.md:8`)
  - **Event Purpose:** `Special Event`
  - **Priority:** `High`

  ## Localization — English (U.S.)
  - **Event Name (30 char max, including spaces):** `April Wrapped Drops Sunday`
  - **Short Description (50 char max):** `Your spending story. 5 slides. On-device only.`
  - **Long Description (120 char max):** `Watch your April spending unfold across 5 slides. 100% on-device. Share the cards. No data leaves your phone.`
  - **Event Card Image (1080×1920):** S1D donut intro frame from MonthlyWrappedView slide 1, exported at full resolution
  - **Event Detail Page Image:** same S1D donut, alternate framing

  ## Schedule
  - **Event Start:** first Sunday after v3.3.0 ships (e.g. May 3, 2026), 00:01 PT
  - **Event End:** following Sunday, 23:59 PT
  - **Pre-event period:** App Store displays event card 14 days before start

  ## Deep link
  - **Event Action:** `Open the App`
  - **Deep Link URL:** `budgetvault://wrapped/april` (existing URL scheme)
  - Confirm `BudgetVaultApp.swift` already routes `wrapped/<month>` to `MonthlyWrappedView`. If not present, defer deep link wiring to the in-app routing pass; ASC will accept "Open the App" without a deep link.

  ## Re-run playbook (post-v3.3.0)
  Each month-end, duplicate this event in ASC:
  1. Apps → Distribution → Promote → In-App Events → click most recent Wrapped event → `Duplicate`
  2. Update Event Name to `[Month] Wrapped Drops Sunday`
  3. Update Reference Name to `Monthly Wrapped — [Month] [Year]`
  4. Update event start/end to next month's first Sunday
  5. Re-export S1D donut for the new month if data has shifted significantly (optional)
  6. Submit for Review (~24h)

  No engineering work required after first build per `app-store-optimizer.md:8`.

  ## Acceptance
  - Event submitted to App Store Connect by v3.3.0 ship day
  - Event card visible in App Store within 14 days of start date
  - Re-run playbook documented
  ```

- [ ] **Step 2: Commit**
  ```bash
  git add docs/aso/v3.3.0-iae-monthly-wrapped.md
  git commit -m "docs(aso): Monthly Wrapped In-App Event spec"
  ```

- [ ] **Step 3: Export the event card image**
  Run the simulator at iPhone 17 Pro Max, navigate to MonthlyWrappedView slide 1, capture screenshot at 1290×2796, crop to 1080×1920 (centered).
  ```bash
  xcrun simctl io booted screenshot ~/Pictures/wrapped-s1d-donut-raw.png
  sips --resampleWidth 1080 ~/Pictures/wrapped-s1d-donut-raw.png --out ~/Pictures/wrapped-s1d-donut-1080.png
  sips --cropToHeightWidth 1920 1080 ~/Pictures/wrapped-s1d-donut-1080.png --out ~/Pictures/wrapped-s1d-donut-1080x1920.png
  ```

- [ ] **Step 4: Submit IAE in App Store Connect**
  Path: Apps → BudgetVault → Distribution → Promote → In-App Events → `+`. Fill per spec. Upload event card. Submit for Review.

---

## Task 7: DE Localization Metadata-Only — Strings [Section 5.17]

**Files:**
- Create: `docs/aso/v3.3.0-de-metadata.md`

Per spec section 5.17 and user decision: metadata-only, no UI translation. App keeps `BudgetVault` wordmark untranslated (proper noun). German keyword leverage is `Haushaltsbuch` (envelope budget term, 100K+ monthly searches per `aso.md:18`).

- [ ] **Step 1: Create DE metadata doc with finished strings**

  Create `/Users/zachgold/Claude/BudgetVault/docs/aso/v3.3.0-de-metadata.md`:
  ```markdown
  # v3.3.0 German (Deutsch) App Store Metadata

  Metadata-only locale per spec section 5.17. UI remains English. The "BudgetVault" wordmark stays as a proper noun.

  ## Title (30 char max, displayed under app name)
  Field: App Name (the app name itself stays `BudgetVault` — Apple-locked).
  Field: Subtitle.

  ### Subtitle (DE) — 30 char max
  `Datenschutz. Ohne Bankzugang.`
  (29 chars — `Datenschutz` is the canonical German privacy term; `ohne Bankzugang` = "without bank login" = the wedge.)

  Backup variant if Apple rejects punctuation:
  `Haushaltsbuch mit Datenschutz.` (30 chars)

  ## Keywords (100 char max, comma-separated, no spaces after commas)
  ```
  haushaltsbuch,umschlag,budget,einnahmen,ausgaben,datenschutz,offline,einmalkauf,ynab,monarch,sparen
  ```
  Char count: 99. Includes `haushaltsbuch` (highest-ROI single keyword in DE per `aso-v3.1.1.md` deferred items), `einmalkauf` (one-time purchase), `umschlag` (envelope).

  ## Promotional Text (170 char max — can update without resubmit)
  `Dein Budget. Privat. Auf deinem iPhone. Kein Bankzugang, kein Abo, keine Daten an Dritte. BudgetVault: Umschlagmethode, einmal bezahlen — 14,99 €.`
  (151 chars)

  ## Description (4000 char max, full marketing copy)
  ```
  BudgetVault — das Haushaltsbuch fürs iPhone, das niemals nach deinem Bankzugang fragt.

  Du verwaltest dein Budget per Umschlagmethode. Du loggst Ausgaben in Sekunden. Du siehst dein verfügbares Tagesbudget auf einen Blick. Und niemand außer dir sieht deine Daten — niemals.

  • KEIN BANKZUGANG. Du gibst keine Login-Daten frei. Plaid, Yodlee oder ähnliche Dienste werden nicht verwendet.

  • KEIN ABO. Einmal 14,99 € — dein Premium gehört dir, für immer.

  • DATENSCHUTZ-ZERTIFIZIERT. Apples "Daten werden nicht erfasst"-Label. Punkt.

  • UMSCHLAGMETHODE. Bewährte Budget-Methode in moderner iOS-App. Eigene Kategorien, Tagesbudget, Monatsabschluss.

  • ON-DEVICE INTELLIGENZ. Mustererkennung läuft auf deinem iPhone — keine Cloud-API, keine externen Server.

  • MONATLICHES WRAPPED. Deine Spending-Story als 5-Slide-Sequenz. Teilbar, falls du willst — vollständig privat, falls nicht.

  • KOSTENLOS-VERSION. 6 Kategorien, 3 wiederkehrende Buchungen, einfache Einsichten, 30-Tage-CSV-Export.

  • PREMIUM (14,99 € einmalig). Unbegrenzte Kategorien, Schulden-Tracker, Vault Intelligence, Monthly Wrapped, voller CSV-Export.

  Hinweis: Die App-Oberfläche ist derzeit nur auf Englisch verfügbar. Die deutsche Lokalisierung ist für eine kommende Version geplant.

  iPhone-Voraussetzungen: iOS 17.0 oder neuer.
  ```

  ## Screenshot captions (DE only — same images, German captions overlay)
  - Slot 1: `60 % der Budget-Apps teilen deine Daten. Wir teilen null.` / `Quelle: Incogni Studie 2026`
  - Slot 2: `Andere Budget-Apps: 109 €/Jahr. BudgetVault: 14,99 € einmalig.`
  - Slot 3: `Kann ich das ausgeben?`
  - Slot 4: `Deine Spending-Story. 5 Slides. Auf dem Gerät.`
  - Slot 5: `Muster. Keine Vorhersagen.`

  ## What's New (release notes, 4000 char max)
  ```
  v3.3.0 — Datenschutz, weiter zugespitzt.

  • Live Activity für Lock Screen + Dynamic Island
  • Monthly Wrapped — teilbare 5-Slide Spending-Story
  • Apple Privacy Label "Daten werden nicht erfasst" prominent
  • Geschenk-Code für Freunde (Einstellungen → Premium)
  • Schnellere App-Vorschau und neue App Store Seiten

  Hinweise zu Datenschutz, Performance, neuen Wrapped-Slides — alles in dieser Version.
  ```

  ## App Store Connect navigation
  Path: Apps → BudgetVault → Distribution → App Store → iOS App → 3.3.0 → click `+ Localization` → select `German` (de-DE).
  - Subtitle: paste DE subtitle
  - Promotional Text: paste DE promo text
  - Keywords: paste DE keyword string
  - Description: paste DE description
  - Screenshots: upload DE-captioned versions (same source images, German caption overlays)
  - What's New: paste DE release notes
  - Save

  ## Acceptance
  - DE locale visible in App Store Connect with all five fields filled
  - Char counts pass Apple validation (no red exclamation marks)
  - Submitted with v3.3.0 build for review
  - On approval, browse `apps.apple.com/de/app/budgetvault/id6473489221` and confirm DE listing renders
  ```

- [ ] **Step 2: Commit**
  ```bash
  git add docs/aso/v3.3.0-de-metadata.md
  git commit -m "docs(aso): German metadata-only locale for v3.3.0 (Haushaltsbuch + Datenschutz wedge)"
  ```

- [ ] **Step 3: Add DE locale in App Store Connect** per nav path in spec. Paste each field exactly as written. Save.

---

## Task 8: AppStorageKeys — New Keys for Premium Date + Review Triggers

**Files:**
- Modify: `BudgetVault/Utilities/AppStorageKeys.swift`

These keys are referenced by Tasks 9–14 (OfferCodeService, ReviewPromptService, StoreKitManager). Centralize first to prevent typo drift.

- [ ] **Step 1: Add new keys**

  Edit `/Users/zachgold/Claude/BudgetVault/BudgetVault/Utilities/AppStorageKeys.swift`. Replace the `Premium & Monetization` section to add `firstPremiumPurchaseDate` and add a new `Review Prompt Triggers` section before `Engagement & Retention`:

  ```swift
      // MARK: - Premium & Monetization
      static let isPremium = "isPremium"
      static let debugPremiumOverride = "debugPremiumOverride"
      static let lastPaywallDecline = "lastPaywallDecline"
      static let reviewPromptCount = "reviewPromptCount"
      static let transactionCount = "transactionCount"
      static let hasSeenTransactionPaywall = "hasSeenTransactionPaywall"
      static let hasSeenStreakPaywall = "hasSeenStreakPaywall"
      /// Unix timestamp of the user's first successful premium purchase. Used to gate the
      /// referral / Offer Code share row to 30+ days post-purchase per spec 5.18.
      static let firstPremiumPurchaseDate = "firstPremiumPurchaseDate"

      // MARK: - Review Prompt Triggers (v3.3.0)
      static let reviewTriggeredWrappedComplete = "reviewTriggered_wrappedComplete"
      static let reviewTriggeredFirstReconciledMonth = "reviewTriggered_firstReconciledMonth"
      static let reviewTriggeredStreakDay30 = "reviewTriggered_streakDay30"
  ```

- [ ] **Step 2: Build**
  ```bash
  xcodebuild -scheme BudgetVault -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' build 2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
  ```
  Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**
  ```bash
  git add BudgetVault/Utilities/AppStorageKeys.swift
  git commit -m "feat(keys): add firstPremiumPurchaseDate + 3 review-trigger keys for v3.3.0"
  ```

---

## Task 9: StoreKitManager — Record First Premium Purchase Date

**Files:**
- Modify: `BudgetVault/Services/StoreKitManager.swift:117-119`

OfferCodeService gates eligibility on 30+ days post-purchase. Capture the first purchase timestamp on successful entitlement.

- [ ] **Step 1: Add purchase-date capture in `purchase()` success path**

  Edit `/Users/zachgold/Claude/BudgetVault/BudgetVault/Services/StoreKitManager.swift`. Find the block at lines 116–119:

  Old:
  ```swift
                  UserDefaults.standard.set(isPremium, forKey: AppStorageKeys.isPremium)
                  if isPremium {
                      KeychainService.set(true, forKey: "isPremium")
                  }
  ```

  New:
  ```swift
                  UserDefaults.standard.set(isPremium, forKey: AppStorageKeys.isPremium)
                  if isPremium {
                      KeychainService.set(true, forKey: "isPremium")
                      // Record first-ever premium purchase timestamp for Offer Code gating (spec 5.18).
                      // Set-once: never overwrite if already populated (restore should not reset eligibility clock).
                      if UserDefaults.standard.double(forKey: AppStorageKeys.firstPremiumPurchaseDate) == 0 {
                          UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: AppStorageKeys.firstPremiumPurchaseDate)
                      }
                  }
  ```

- [ ] **Step 2: Also capture in `checkEntitlements()` for users who already own premium pre-v3.3.0**

  In the same file, find lines 171–181 (`checkEntitlements()` end). Add the same set-once write inside the `if hasPremium` branch at line 177:

  Old:
  ```swift
          // Keychain is the authoritative source of truth for premium status.
          // Sync Keychain to match StoreKit's verified entitlement state.
          if hasPremium {
              KeychainService.set(true, forKey: "isPremium")
          } else {
              KeychainService.delete(forKey: "isPremium")
          }
  ```

  New:
  ```swift
          // Keychain is the authoritative source of truth for premium status.
          // Sync Keychain to match StoreKit's verified entitlement state.
          if hasPremium {
              KeychainService.set(true, forKey: "isPremium")
              // Backfill firstPremiumPurchaseDate for pre-v3.3.0 premium users.
              // Set-once: only writes if the key is missing.
              if UserDefaults.standard.double(forKey: AppStorageKeys.firstPremiumPurchaseDate) == 0 {
                  UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: AppStorageKeys.firstPremiumPurchaseDate)
              }
          } else {
              KeychainService.delete(forKey: "isPremium")
          }
  ```

  Note: backfilled date for legacy users will be "today on first v3.3.0 launch" — this is intentional. We can't recover the true historical date without a server, and a 30-day wait from upgrade is acceptable rather than spamming on day 1.

- [ ] **Step 3: Build + commit**
  ```bash
  xcodegen generate
  xcodebuild -scheme BudgetVault -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' build 2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
  git add BudgetVault/Services/StoreKitManager.swift
  git commit -m "feat(storekit): record firstPremiumPurchaseDate for Offer Code eligibility"
  ```

---

## Task 10: OfferCodeService — Failing Test First (TDD)

**Files:**
- Create: `BudgetVaultTests/OfferCodeServiceTests.swift`

TDD: write the failing test first, watch it fail to compile, then implement the service.

- [ ] **Step 1: Create the test file**

  Create `/Users/zachgold/Claude/BudgetVault/BudgetVaultTests/OfferCodeServiceTests.swift`:
  ```swift
  import XCTest
  @testable import BudgetVault

  /// Tests for OfferCodeService — eligibility gating and share-URL composition.
  /// Spec 5.18: row appears only for users 30+ days post-purchase.
  final class OfferCodeServiceTests: XCTestCase {

      override func setUp() {
          super.setUp()
          UserDefaults.standard.removeObject(forKey: AppStorageKeys.isPremium)
          UserDefaults.standard.removeObject(forKey: AppStorageKeys.firstPremiumPurchaseDate)
      }

      override func tearDown() {
          UserDefaults.standard.removeObject(forKey: AppStorageKeys.isPremium)
          UserDefaults.standard.removeObject(forKey: AppStorageKeys.firstPremiumPurchaseDate)
          super.tearDown()
      }

      // MARK: - Eligibility

      func testNotEligible_freeUser() {
          UserDefaults.standard.set(false, forKey: AppStorageKeys.isPremium)
          XCTAssertFalse(OfferCodeService.isEligibleToShare())
      }

      func testNotEligible_premiumButNoPurchaseDate() {
          UserDefaults.standard.set(true, forKey: AppStorageKeys.isPremium)
          // firstPremiumPurchaseDate not set
          XCTAssertFalse(OfferCodeService.isEligibleToShare())
      }

      func testNotEligible_premiumPurchasedYesterday() {
          UserDefaults.standard.set(true, forKey: AppStorageKeys.isPremium)
          let yesterday = Date().addingTimeInterval(-86_400).timeIntervalSince1970
          UserDefaults.standard.set(yesterday, forKey: AppStorageKeys.firstPremiumPurchaseDate)
          XCTAssertFalse(OfferCodeService.isEligibleToShare())
      }

      func testNotEligible_premiumPurchased29DaysAgo() {
          UserDefaults.standard.set(true, forKey: AppStorageKeys.isPremium)
          let twentyNineDaysAgo = Date().addingTimeInterval(-29 * 86_400).timeIntervalSince1970
          UserDefaults.standard.set(twentyNineDaysAgo, forKey: AppStorageKeys.firstPremiumPurchaseDate)
          XCTAssertFalse(OfferCodeService.isEligibleToShare())
      }

      func testEligible_premiumPurchased30DaysAgo() {
          UserDefaults.standard.set(true, forKey: AppStorageKeys.isPremium)
          let thirtyDaysAgo = Date().addingTimeInterval(-30 * 86_400 - 60).timeIntervalSince1970
          UserDefaults.standard.set(thirtyDaysAgo, forKey: AppStorageKeys.firstPremiumPurchaseDate)
          XCTAssertTrue(OfferCodeService.isEligibleToShare())
      }

      func testEligible_premiumPurchased90DaysAgo() {
          UserDefaults.standard.set(true, forKey: AppStorageKeys.isPremium)
          let ninetyDaysAgo = Date().addingTimeInterval(-90 * 86_400).timeIntervalSince1970
          UserDefaults.standard.set(ninetyDaysAgo, forKey: AppStorageKeys.firstPremiumPurchaseDate)
          XCTAssertTrue(OfferCodeService.isEligibleToShare())
      }

      // MARK: - Share payload

      func testShareItems_includesAppStoreURL() {
          let items = OfferCodeService.shareItems()
          let containsURL = items.contains { ($0 as? URL)?.absoluteString.contains("apps.apple.com") == true }
          XCTAssertTrue(containsURL, "Share items must include the App Store / offer-code redemption URL")
      }

      func testShareItems_includesPersonalMessage() {
          let items = OfferCodeService.shareItems()
          let containsMessage = items.contains { ($0 as? String)?.contains("BudgetVault") == true }
          XCTAssertTrue(containsMessage, "Share items must include a personal-message string mentioning BudgetVault")
      }

      func testShareItems_doesNotMentionFreeOrDiscount() {
          // Apple Offer Codes can be 100% off OR a price reduction; we route the redemption-URL flow
          // through Apple's hosted page so we don't need to claim a specific discount in our copy.
          let items = OfferCodeService.shareItems()
          let stringItems = items.compactMap { $0 as? String }
          for s in stringItems {
              XCTAssertFalse(s.lowercased().contains("free"), "Avoid 'free' wording — Apple controls the actual offer terms")
          }
      }
  }
  ```

- [ ] **Step 2: Run tests — expect compile failure**
  ```bash
  xcodegen generate
  xcodebuild test -scheme BudgetVault -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -only-testing:BudgetVaultTests/OfferCodeServiceTests 2>&1 | tail -30
  ```
  Expected: `error: cannot find 'OfferCodeService' in scope` — confirms TDD red state.

---

## Task 11: OfferCodeService — Implementation

**Files:**
- Create: `BudgetVault/Services/OfferCodeService.swift`

Apple Offer Codes are configured in App Store Connect. Each premium customer gets a one-time-use redemption URL. We share via `UIActivityViewController` — Apple-hosted, no SDK, no server, no tracking.

For v3.3.0 we share the same campaign URL to all eligible users (Apple Offer Codes "URL" mode = many-redemptions code, suitable for non-trackable referral). Per-user unique codes require a backend to mint — explicitly out-of-scope per spec 5.18.

- [ ] **Step 1: Create the service**

  Create `/Users/zachgold/Claude/BudgetVault/BudgetVault/Services/OfferCodeService.swift`:
  ```swift
  import Foundation
  import StoreKit
  import UIKit

  /// Apple Offer Codes referral helper.
  ///
  /// Spec 5.18: premium users 30+ days post-purchase can share a one-redemption-per-user
  /// Apple-hosted offer URL via `UIActivityViewController`. No server, no SDK, no tracking.
  ///
  /// Configuration (App Store Connect, manual):
  /// 1. Apps → BudgetVault → Distribution → Subscriptions / In-App Purchases →
  ///    `io.budgetvault.premium` → Offer Codes → `+`.
  /// 2. Mode: `Custom Codes` → `One Code Per Customer`. Distribute via URL.
  /// 3. Set Offer: `Pay As You Go` → `100% off` (free for 1 redemption per customer).
  /// 4. Audience: `Existing customers` → `Active`.
  /// 5. Copy the resulting redemption URL into `redemptionURL` below.
  ///
  /// The URL embedded here is the public Apple-hosted redemption page; Apple handles
  /// per-user enforcement.
  enum OfferCodeService {

      /// Apple-hosted redemption URL for the v3.3.0 referral campaign.
      /// Replace with the real URL from App Store Connect after creating the offer.
      /// Format: `https://apps.apple.com/redeem?ctx=offercodes&id=6473489221&code=<CAMPAIGN>`
      static let redemptionURL = URL(string: "https://apps.apple.com/redeem?ctx=offercodes&id=6473489221&code=BVFRIEND")!

      /// Number of days the user must be a premium customer before the share row appears.
      static let eligibilityDays: TimeInterval = 30

      // MARK: - Eligibility

      /// Whether the current user can see the "Give a friend BudgetVault" row.
      ///
      /// Returns `true` only when:
      /// - `isPremium` is true, AND
      /// - `firstPremiumPurchaseDate` is set, AND
      /// - The purchase happened ≥30 days ago.
      static func isEligibleToShare() -> Bool {
          let defaults = UserDefaults.standard
          guard defaults.bool(forKey: AppStorageKeys.isPremium) else { return false }
          let purchaseTimestamp = defaults.double(forKey: AppStorageKeys.firstPremiumPurchaseDate)
          guard purchaseTimestamp > 0 else { return false }
          let secondsSincePurchase = Date().timeIntervalSince1970 - purchaseTimestamp
          return secondsSincePurchase >= eligibilityDays * 86_400
      }

      // MARK: - Share payload

      /// Activity items for `UIActivityViewController`.
      /// Composes a personal-message string + the Apple-hosted redemption URL.
      static func shareItems() -> [Any] {
          let message = "I use BudgetVault to manage my budget — private, on-device, no subscription. Here's a free copy on me: "
          return [message, redemptionURL]
      }

      // MARK: - Presentation

      /// Presents the system share sheet from the topmost view controller.
      /// Call from a SwiftUI `Button { }` handler.
      @MainActor
      static func presentShareSheet() {
          guard let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
                let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
              return
          }
          let activityVC = UIActivityViewController(activityItems: shareItems(), applicationActivities: nil)
          // iPad popover anchor (no-op on iPhone but required on iPad to avoid crash):
          activityVC.popoverPresentationController?.sourceView = root.view
          activityVC.popoverPresentationController?.sourceRect = CGRect(x: root.view.bounds.midX, y: root.view.bounds.midY, width: 0, height: 0)
          root.present(activityVC, animated: true)
      }
  }
  ```

- [ ] **Step 2: Add file to xcodegen sources via regenerate**
  ```bash
  xcodegen generate
  ```

- [ ] **Step 3: Run tests — expect green**
  ```bash
  xcodebuild test -scheme BudgetVault -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -only-testing:BudgetVaultTests/OfferCodeServiceTests 2>&1 | tail -20
  ```
  Expected: `Test Suite 'OfferCodeServiceTests' passed`. All 8 tests green.

- [ ] **Step 4: Commit**
  ```bash
  git add BudgetVault/Services/OfferCodeService.swift BudgetVaultTests/OfferCodeServiceTests.swift
  git commit -m "feat(referral): OfferCodeService for Apple-hosted referral URL share (spec 5.18)"
  ```

---

## Task 12: SettingsView — "Give a friend BudgetVault" Row

**Files:**
- Modify: `BudgetVault/Views/Settings/SettingsView.swift:545-560`

Add the share row into the existing About section, immediately above "Send Feedback". Visible only when `OfferCodeService.isEligibleToShare()` returns true.

- [ ] **Step 1: Insert the row in the About section**

  Edit `/Users/zachgold/Claude/BudgetVault/BudgetVault/Views/Settings/SettingsView.swift`. Find this block at lines 546–550 (the existing Share BudgetVault `ShareLink`):

  Old:
  ```swift
              ShareLink(item: URL(string: "https://budgetvault.io")!,
                         subject: Text("BudgetVault"),
                         message: Text("I use BudgetVault to manage my budget \u{2014} private, on-device, and no subscription. Check it out!")) {
                  Label("Share BudgetVault", systemImage: "heart.fill")
              }
  ```

  New (adds the eligibility-gated referral row immediately below the existing ShareLink):
  ```swift
              ShareLink(item: URL(string: "https://budgetvault.io")!,
                         subject: Text("BudgetVault"),
                         message: Text("I use BudgetVault to manage my budget \u{2014} private, on-device, and no subscription. Check it out!")) {
                  Label("Share BudgetVault", systemImage: "heart.fill")
              }

              // Spec 5.18: Apple Offer Codes referral. Visible only to premium users 30+ days
              // post-purchase. Apple-hosted redemption page; no server, no tracking.
              if OfferCodeService.isEligibleToShare() {
                  Button {
                      OfferCodeService.presentShareSheet()
                  } label: {
                      Label("Give a friend BudgetVault", systemImage: "gift.fill")
                  }
              }
  ```

- [ ] **Step 2: Build + smoke test**
  ```bash
  xcodebuild -scheme BudgetVault -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' build 2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
  ```

- [ ] **Step 3: Manual smoke test — toggle eligibility**
  ```bash
  xcrun simctl boot "iPhone 17 Pro Max" 2>/dev/null || true
  xcrun simctl install booted /tmp/preview-build/Build/Products/Debug-iphonesimulator/BudgetVault.app
  # Set debug premium + 31-day-old purchase date
  xcrun simctl spawn booted defaults write io.budgetvault.app debugPremiumOverride -bool true
  xcrun simctl spawn booted defaults write io.budgetvault.app firstPremiumPurchaseDate -double "$(echo "$(date +%s) - 31*86400" | bc)"
  xcrun simctl launch booted io.budgetvault.app
  ```
  Open Settings → About. Expected: "Give a friend BudgetVault" row visible with gift icon. Tap → system share sheet opens with personal message + apps.apple.com URL.

- [ ] **Step 4: Reset debug state and commit**
  ```bash
  xcrun simctl spawn booted defaults delete io.budgetvault.app debugPremiumOverride
  xcrun simctl spawn booted defaults delete io.budgetvault.app firstPremiumPurchaseDate
  cd /Users/zachgold/Claude/BudgetVault
  git add BudgetVault/Views/Settings/SettingsView.swift
  git commit -m "feat(settings): Give a friend BudgetVault row, gated 30+ days post-purchase"
  ```

---

## Task 13: App Store Connect — Create the Offer Code Campaign

**Files:** none (App Store Connect web console only)

The redemption URL hardcoded into `OfferCodeService.redemptionURL` is a placeholder until the offer is created in ASC. Create it now and patch the URL.

- [ ] **Step 1: Create the offer in ASC**
  Path: Apps → BudgetVault → Distribution → In-App Purchases → `io.budgetvault.premium` → Offer Codes → `+`.

  Settings:
  - **Reference Name:** `BVFRIEND-v3.3.0-launch`
  - **Number of Codes:** `1000` (re-mint as needed)
  - **Eligibility:** `New Customers` (must be a non-premium Apple ID — prevents existing premium users from redeeming for themselves)
  - **Offer Type:** `Free` (100% off, one-time purchase)
  - **Distribution Channel:** `Custom Code via URL`
  - **Expiration:** `90 days from creation`

  Submit. Apple generates a redemption URL within ~1 hour.

- [ ] **Step 2: Copy the live redemption URL**
  In the offer detail page, copy the URL under "Custom Code URL". Format will be similar to:
  `https://apps.apple.com/redeem?ctx=offercodes&id=6473489221&code=BVFRIEND`

- [ ] **Step 3: Patch the URL in OfferCodeService**

  Edit `/Users/zachgold/Claude/BudgetVault/BudgetVault/Services/OfferCodeService.swift`. Replace the placeholder `redemptionURL`:

  Old:
  ```swift
      static let redemptionURL = URL(string: "https://apps.apple.com/redeem?ctx=offercodes&id=6473489221&code=BVFRIEND")!
  ```

  New (replace `<PASTE FROM ASC>` with the actual URL from Step 2):
  ```swift
      static let redemptionURL = URL(string: "<PASTE FROM ASC>")!
  ```

- [ ] **Step 4: Verify URL is reachable**
  ```bash
  curl -I "<PASTE URL HERE>"
  ```
  Expected: `HTTP/2 200` or 302 redirect to Apple App Store.

- [ ] **Step 5: Commit URL patch**
  ```bash
  git add BudgetVault/Services/OfferCodeService.swift
  git commit -m "config(referral): patch OfferCodeService URL with live ASC redemption link"
  ```

---

## Task 14: ReviewPromptService — Failing Tests First (TDD)

**Files:**
- Create: `BudgetVaultTests/ReviewPromptServiceTests.swift`

Test the three new gates: `checkWrappedComplete`, `checkFirstReconciledMonth`, `checkStreakDay30`. Each must be one-shot per install (idempotent).

- [ ] **Step 1: Create test file**

  Create `/Users/zachgold/Claude/BudgetVault/BudgetVaultTests/ReviewPromptServiceTests.swift`:
  ```swift
  import XCTest
  @testable import BudgetVault

  /// Tests for ReviewPromptService — trigger gates only.
  /// We do NOT call the live SKStoreReviewController in tests; we verify
  /// the per-trigger one-shot dedupe key is set after the gate fires.
  final class ReviewPromptServiceTests: XCTestCase {

      private let triggerKeys = [
          AppStorageKeys.reviewTriggeredWrappedComplete,
          AppStorageKeys.reviewTriggeredFirstReconciledMonth,
          AppStorageKeys.reviewTriggeredStreakDay30,
          "reviewTriggered_firstMonthUnderBudget",
          "reviewTriggered_10thTransaction",
          "lastReviewPromptDate",
          AppStorageKeys.reviewPromptCount,
          AppStorageKeys.lastPaywallDecline,
      ]

      override func setUp() {
          super.setUp()
          for k in triggerKeys { UserDefaults.standard.removeObject(forKey: k) }
      }

      override func tearDown() {
          for k in triggerKeys { UserDefaults.standard.removeObject(forKey: k) }
          super.tearDown()
      }

      // MARK: - checkWrappedComplete

      func testWrappedComplete_firesOnce() {
          ReviewPromptService.checkWrappedComplete()
          XCTAssertTrue(UserDefaults.standard.bool(forKey: AppStorageKeys.reviewTriggeredWrappedComplete))
      }

      func testWrappedComplete_idempotent() {
          ReviewPromptService.checkWrappedComplete()
          // Second call should be a no-op — but the dedupe key remains set.
          ReviewPromptService.checkWrappedComplete()
          XCTAssertTrue(UserDefaults.standard.bool(forKey: AppStorageKeys.reviewTriggeredWrappedComplete))
      }

      // MARK: - checkFirstReconciledMonth

      func testFirstReconciledMonth_firesOnce() {
          ReviewPromptService.checkFirstReconciledMonth()
          XCTAssertTrue(UserDefaults.standard.bool(forKey: AppStorageKeys.reviewTriggeredFirstReconciledMonth))
      }

      func testFirstReconciledMonth_idempotent() {
          ReviewPromptService.checkFirstReconciledMonth()
          ReviewPromptService.checkFirstReconciledMonth()
          XCTAssertTrue(UserDefaults.standard.bool(forKey: AppStorageKeys.reviewTriggeredFirstReconciledMonth))
      }

      // MARK: - checkStreakDay30

      func testStreakDay30_firesAtThirty() {
          ReviewPromptService.checkStreakDay30(streakCount: 30)
          XCTAssertTrue(UserDefaults.standard.bool(forKey: AppStorageKeys.reviewTriggeredStreakDay30))
      }

      func testStreakDay30_doesNotFireBelowThirty() {
          ReviewPromptService.checkStreakDay30(streakCount: 29)
          XCTAssertFalse(UserDefaults.standard.bool(forKey: AppStorageKeys.reviewTriggeredStreakDay30))
      }

      func testStreakDay30_idempotentAtThirty() {
          ReviewPromptService.checkStreakDay30(streakCount: 30)
          ReviewPromptService.checkStreakDay30(streakCount: 31)
          XCTAssertTrue(UserDefaults.standard.bool(forKey: AppStorageKeys.reviewTriggeredStreakDay30))
      }

      // MARK: - 14-day trigger removed

      func testStreakService_doesNotRequestReviewAt14() {
          // The old 14-day trigger in StreakService.checkMilestone() at line 113 is removed.
          // The milestone return value still fires (UI confetti/banner) but no review prompt.
          UserDefaults.standard.set(14, forKey: AppStorageKeys.currentStreak)
          let milestone = StreakService.checkMilestone()
          XCTAssertEqual(milestone, 14, "14-day milestone still detected for celebration UX")
          // Review-prompt count must not have incremented for the 14-day milestone alone.
          XCTAssertEqual(UserDefaults.standard.integer(forKey: AppStorageKeys.reviewPromptCount), 0)
      }
  }
  ```

- [ ] **Step 2: Run — expect compile failure on new methods**
  ```bash
  xcodegen generate
  xcodebuild test -scheme BudgetVault -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -only-testing:BudgetVaultTests/ReviewPromptServiceTests 2>&1 | tail -30
  ```
  Expected: `error: type 'ReviewPromptService' has no member 'checkWrappedComplete'`. TDD red.

---

## Task 15: ReviewPromptService — Add 3 New Triggers

**Files:**
- Modify: `BudgetVault/Services/ReviewPromptService.swift`

- [ ] **Step 1: Append three new trigger methods**

  Edit `/Users/zachgold/Claude/BudgetVault/BudgetVault/Services/ReviewPromptService.swift`. After the existing `checkTransactionMilestone` method (currently the last method, ends at line 69), add:

  ```swift

      /// Spec 5.18 / 5.19: peak-satisfaction trigger after the user finishes viewing
      /// a Monthly Wrapped sequence. Fires on slide-5 dismiss or share. One-shot per install.
      static func checkWrappedComplete() {
          let defaults = UserDefaults.standard
          let key = AppStorageKeys.reviewTriggeredWrappedComplete
          guard !defaults.bool(forKey: key) else { return }
          defaults.set(true, forKey: key)
          requestIfAppropriate()
      }

      /// Spec 5.19: peak-satisfaction trigger the first time a user completes a
      /// month with all transactions reconciled. One-shot per install.
      static func checkFirstReconciledMonth() {
          let defaults = UserDefaults.standard
          let key = AppStorageKeys.reviewTriggeredFirstReconciledMonth
          guard !defaults.bool(forKey: key) else { return }
          defaults.set(true, forKey: key)
          requestIfAppropriate()
      }

      /// Spec 5.19: 30-day streak hit. Replaces the 14-day trigger removed from
      /// StreakService.checkMilestone(). One-shot per install.
      static func checkStreakDay30(streakCount: Int) {
          let defaults = UserDefaults.standard
          let key = AppStorageKeys.reviewTriggeredStreakDay30
          guard !defaults.bool(forKey: key) else { return }
          guard streakCount >= 30 else { return }
          defaults.set(true, forKey: key)
          requestIfAppropriate()
      }
  ```

- [ ] **Step 2: Build**
  ```bash
  xcodebuild -scheme BudgetVault -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' build 2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
  ```

---

## Task 16: StreakService — Remove 14-Day Review Trigger

**Files:**
- Modify: `BudgetVault/Services/StreakService.swift:108-119`

Per spec 5.19, replace the 14-day trigger with the new 30-day trigger. The 14-day milestone still fires (for confetti/celebration UX) — only the review request is moved.

- [ ] **Step 1: Replace the `checkMilestone()` body**

  Edit `/Users/zachgold/Claude/BudgetVault/BudgetVault/Services/StreakService.swift`. Find this block at lines 107–119:

  Old:
  ```swift
      /// Check if current streak just hit a milestone.
      static func checkMilestone() -> Int? {
          let streak = UserDefaults.standard.integer(forKey: AppStorageKeys.currentStreak)
          let milestones = [7, 14, 30, 60, 90]
          if milestones.contains(streak) {
              // Request review at key milestones
              if [14, 30, 60, 90].contains(streak) {
                  ReviewPromptService.requestIfAppropriate()
              }
              return streak
          }
          return nil
      }
  ```

  New (delegates the review-trigger decision to ReviewPromptService.checkStreakDay30):
  ```swift
      /// Check if current streak just hit a milestone.
      ///
      /// Spec 5.19: review prompt has been re-timed to fire at Day-30 only via
      /// `ReviewPromptService.checkStreakDay30`. The 14-day prompt is removed
      /// (was wasted — peak satisfaction lives at Day-30, Wrapped, and first reconciled month).
      static func checkMilestone() -> Int? {
          let streak = UserDefaults.standard.integer(forKey: AppStorageKeys.currentStreak)
          let milestones = [7, 14, 30, 60, 90]
          if milestones.contains(streak) {
              // Day-30 streak hit — single review-prompt opportunity (one-shot per install).
              ReviewPromptService.checkStreakDay30(streakCount: streak)
              return streak
          }
          return nil
      }
  ```

- [ ] **Step 2: Run the new ReviewPromptService tests**
  ```bash
  xcodebuild test -scheme BudgetVault -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -only-testing:BudgetVaultTests/ReviewPromptServiceTests 2>&1 | tail -20
  ```
  Expected: all 8 tests pass.

- [ ] **Step 3: Run existing StreakService tests to verify no regression**
  ```bash
  xcodebuild test -scheme BudgetVault -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -only-testing:BudgetVaultTests/StreakServiceTests 2>&1 | tail -20
  ```
  Expected: all existing StreakService tests still green.

- [ ] **Step 4: Commit ReviewPromptService + StreakService changes together**
  ```bash
  git add BudgetVault/Services/ReviewPromptService.swift BudgetVault/Services/StreakService.swift BudgetVaultTests/ReviewPromptServiceTests.swift
  git commit -m "feat(reviews): add Wrapped + reconciled-month + Day-30 triggers; remove 14-day prompt (spec 5.19)"
  ```

---

## Task 17: MonthlyWrappedView — Wire `checkWrappedComplete` Trigger

**Files:**
- Modify: `BudgetVault/Views/Dashboard/MonthlyWrappedView.swift:222-263`

Fire `ReviewPromptService.checkWrappedComplete()` when the user reaches slide 5 (peak satisfaction = the share moment).

- [ ] **Step 1: Add `.onChange` modifier on `currentPage` to detect slide-5 reach**

  Edit `/Users/zachgold/Claude/BudgetVault/BudgetVault/Views/Dashboard/MonthlyWrappedView.swift`. Find the `body` block at lines 222–262. Add an `.onChange(of: currentPage)` modifier just before `.preferredColorScheme(.dark)` at line 247:

  Old:
  ```swift
          .overlay(alignment: .topTrailing) {
              Button { dismiss() } label: {
                  Image(systemName: "xmark")
                      .font(.body.weight(.semibold))
                      .foregroundStyle(.white)
                      .frame(width: 32, height: 32)
                      .background(.white.opacity(0.15), in: Circle())
              }
              .padding(.top, 56)
              .padding(.trailing, 20)
          }
          .preferredColorScheme(.dark)
  ```

  New:
  ```swift
          .overlay(alignment: .topTrailing) {
              Button { dismiss() } label: {
                  Image(systemName: "xmark")
                      .font(.body.weight(.semibold))
                      .foregroundStyle(.white)
                      .frame(width: 32, height: 32)
                      .background(.white.opacity(0.15), in: Circle())
              }
              .padding(.top, 56)
              .padding(.trailing, 20)
          }
          // Spec 5.19: review prompt at peak satisfaction (reaching the share-card slide).
          // One-shot per install via ReviewPromptService gate.
          .onChange(of: currentPage) { _, newValue in
              if newValue == 4 { // slide 5 (zero-indexed)
                  ReviewPromptService.checkWrappedComplete()
              }
          }
          .preferredColorScheme(.dark)
  ```

- [ ] **Step 2: Build**
  ```bash
  xcodebuild -scheme BudgetVault -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' build 2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
  ```

- [ ] **Step 3: Commit**
  ```bash
  git add BudgetVault/Views/Dashboard/MonthlyWrappedView.swift
  git commit -m "feat(reviews): wire Wrapped slide-5 trigger to ReviewPromptService"
  ```

---

## Task 18: HistoryView — Wire `checkFirstReconciledMonth` Trigger

**Files:**
- Modify: `BudgetVault/Views/Transactions/HistoryView.swift:640-650`

Fire `checkFirstReconciledMonth()` when a reconciliation toggle leaves the visible month with zero unreconciled transactions for the first time. The trigger itself is one-shot per install via the `reviewTriggeredFirstReconciledMonth` key.

- [ ] **Step 1: Add reconciliation-completion check after toggle**

  Edit `/Users/zachgold/Claude/BudgetVault/BudgetVault/Views/Transactions/HistoryView.swift`. Find the swipe-action block around lines 638–650:

  Old:
  ```swift
                                  transaction.isReconciled.toggle()
                                  try? modelContext.save()
                              } label: {
                                  Label(
                                      transaction.isReconciled ? "Unreview" : "Reviewed",
                                      systemImage: transaction.isReconciled ? "checkmark.circle.fill" : "checkmark.circle"
                                  )
                              }
  ```

  New (add the trigger call after the save):
  ```swift
                                  transaction.isReconciled.toggle()
                                  try? modelContext.save()
                                  // Spec 5.19: detect "first reconciled month" — fires at peak
                                  // satisfaction the first time the user completes reviewing every
                                  // transaction in a visible month period. One-shot per install.
                                  if isMonthFullyReconciled() {
                                      ReviewPromptService.checkFirstReconciledMonth()
                                  }
                              } label: {
                                  Label(
                                      transaction.isReconciled ? "Unreview" : "Reviewed",
                                      systemImage: transaction.isReconciled ? "checkmark.circle.fill" : "checkmark.circle"
                                  )
                              }
  ```

- [ ] **Step 2: Add the `isMonthFullyReconciled()` helper at the bottom of `HistoryView`**

  Find the end of the `HistoryView` struct. Just before its closing `}`, add:
  ```swift

      /// Spec 5.19 helper: returns true when every transaction in the currently
      /// displayed period is reconciled. Used to gate the first-reconciled-month
      /// review prompt.
      private func isMonthFullyReconciled() -> Bool {
          let visible = filteredTransactions
          guard !visible.isEmpty else { return false }
          return visible.allSatisfy { $0.isReconciled }
      }
  ```

  Note: `filteredTransactions` is the existing computed property on `HistoryView:58`. Verified present in the current codebase. If a future refactor renames it, update this helper accordingly.

- [ ] **Step 3: Build**
  ```bash
  xcodebuild -scheme BudgetVault -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' build 2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
  ```

- [ ] **Step 4: Commit**
  ```bash
  git add BudgetVault/Views/Transactions/HistoryView.swift
  git commit -m "feat(reviews): wire first-reconciled-month trigger to ReviewPromptService"
  ```

---

## Task 19: Move Existing Trigger Out of Settings (Spec 5.19 cleanup)

**Files:**
- Inspect: `BudgetVault/Views/Settings/SettingsView.swift`

Spec 5.19 line 274: "Move existing trigger out of Settings (wasted impression)." Currently `SettingsView.swift` line 20 reads `reviewPromptCount` for display — but does it ever **call** `requestIfAppropriate()` from a Settings interaction? Confirm and remove if so.

- [ ] **Step 1: Audit Settings for review-prompt callsites**
  ```bash
  grep -n "requestIfAppropriate\|ReviewPromptService" BudgetVault/Views/Settings/SettingsView.swift
  ```
  - If 0 results: spec line 274 referred to display-only state; nothing to remove. Annotate the `reviewPromptCount` AppStorage with a comment explaining why we keep it (debug/diagnostics).
  - If ≥1 result: remove the call(s); `requestIfAppropriate()` should fire only from trigger gates, never from Settings nav.

- [ ] **Step 2a (if 0 results): Add explanatory comment**

  Edit `BudgetVault/Views/Settings/SettingsView.swift` line 20. Replace:
  ```swift
      @AppStorage(AppStorageKeys.reviewPromptCount) private var reviewPromptCount = 0
  ```
  With:
  ```swift
      // Read-only diagnostic. Spec 5.19: review prompts are now triggered by
      // peak-satisfaction events (Wrapped complete, first reconciled month, Day-30 streak)
      // — never from Settings. This binding stays so per-year-cap state is observable
      // in debug, but no Settings interaction calls ReviewPromptService.
      @AppStorage(AppStorageKeys.reviewPromptCount) private var reviewPromptCount = 0
  ```

- [ ] **Step 2b (if ≥1 result): Remove the call site(s)** in SettingsView and confirm by re-running the grep — should return only the `@AppStorage` declaration.

- [ ] **Step 3: Build + commit**
  ```bash
  xcodebuild -scheme BudgetVault -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' build 2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
  git add BudgetVault/Views/Settings/SettingsView.swift
  git commit -m "chore(reviews): document or remove Settings review-prompt trigger per spec 5.19"
  ```

---

## Task 20: Full Test Suite + Smoke Run

**Files:** none (verification only)

- [ ] **Step 1: Run full test suite**
  ```bash
  cd /Users/zachgold/Claude/BudgetVault
  xcodebuild test -scheme BudgetVault -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' 2>&1 | tail -30
  ```
  Expected: `TEST SUCCEEDED`. All previous 80 tests + 8 new OfferCodeService tests + 8 new ReviewPromptService tests pass = 96 green.

- [ ] **Step 2: Manual smoke — Settings referral row visibility under each state**
  Use `defaults write` to flip eligibility in the simulator and verify the row shows/hides correctly. (Same commands as Task 12 step 3.)

- [ ] **Step 3: Manual smoke — Wrapped review trigger fires only once**
  ```bash
  xcrun simctl spawn booted defaults delete io.budgetvault.app reviewTriggered_wrappedComplete
  ```
  Open app → navigate to Wrapped → swipe to slide 5. Confirm review prompt appears once. Re-open Wrapped, swipe to slide 5 again — no prompt (idempotent).

- [ ] **Step 4: No commit needed; push branch**
  ```bash
  git push -u origin v3.3-aso-acquisition
  ```

---

## Task 21: App Store Connect — Final Submission Checklist

**Files:** none (App Store Connect verification only)

Pre-submit verification before pushing v3.3.0 to App Store review.

- [ ] **Step 1: Verify all ASC-side assets are uploaded and in correct state**

  Path: Apps → BudgetVault → Distribution → App Store → iOS App → 3.3.0.

  Checklist:
  - [ ] Screenshots updated per `docs/aso/v3.3.0-screenshot-copy.md`
  - [ ] Slot 4 = Wrapped (moved from slot 5)
  - [ ] Slot 2 contains NO "YNAB" string (Apple guideline 1.2)
  - [ ] App Preview video (886×1920, 25s) uploaded; thumbnail = B1 hero lead frame
  - [ ] Closing card reads exactly `$14.99 once. Forever.`
  - [ ] DE locale added with subtitle, keywords, description, screenshots, release notes per `docs/aso/v3.3.0-de-metadata.md`
  - [ ] DE keyword field includes `haushaltsbuch`
  - [ ] DE subtitle = `Datenschutz. Ohne Bankzugang.`

- [ ] **Step 2: Verify CPPs are in Approved state**
  Path: Apps → BudgetVault → Distribution → Promote → Custom Product Pages.
  - [ ] `/ynab-refugee` — Approved or In Review
  - [ ] `/privacy` — Approved or In Review
  - [ ] `/wrapped` — Approved or In Review
  - [ ] All three URLs captured in `docs/aso/v3.3.0-cpp-spec.md`

- [ ] **Step 3: Verify In-App Event is submitted**
  Path: Apps → BudgetVault → Distribution → Promote → In-App Events.
  - [ ] `Monthly Wrapped — April 2026` event exists
  - [ ] Start = first Sunday after ship date
  - [ ] Event card image (1080×1920) uploaded
  - [ ] State: Submitted for Review or Approved

- [ ] **Step 4: Verify Offer Code is live**
  Path: Apps → BudgetVault → Distribution → In-App Purchases → `io.budgetvault.premium` → Offer Codes.
  - [ ] `BVFRIEND-v3.3.0-launch` exists
  - [ ] Custom Code URL matches `OfferCodeService.redemptionURL` value in code
  - [ ] At least 1000 codes available

- [ ] **Step 5: Promotional Text rotation (no resubmit needed)**
  Path: Apps → BudgetVault → Distribution → App Store → iOS App → 3.3.0 → Promotional Text.

  En-US:
  ```
  Your data never leaves your iPhone. No accounts, no bank sync, no monthly fee. $14.99 once. Forever.
  ```

  DE:
  ```
  Dein Budget. Privat. Auf deinem iPhone. Kein Bankzugang, kein Abo, keine Daten an Dritte. 14,99 € einmalig.
  ```

- [ ] **Step 6: Submit v3.3.0 build for App Store Review**
  Click `Add for Review` → `Submit for Review`. Apple SLA ~24–48h.

---

## Task 22: Post-Approval Verification (after Apple approves v3.3.0)

**Files:** none

- [ ] **Step 1: Browse the live listings**
  - https://apps.apple.com/us/app/budgetvault/id6473489221 — confirm new screenshots, App Preview video plays, no "YNAB" string visible
  - https://apps.apple.com/de/app/budgetvault/id6473489221 — confirm DE listing renders with `Datenschutz. Ohne Bankzugang.` subtitle and `Haushaltsbuch` discoverable in DE search

- [ ] **Step 2: Test each CPP URL**
  Open each CPP URL from Step 6 of Task 5 in incognito Safari. Verify the headline + screenshot lineup matches spec.

- [ ] **Step 3: Test the Offer Code URL**
  On a separate Apple ID device (or family share child account), open the redemption URL from Task 13. Confirm the App Store opens the redemption sheet showing "BudgetVault Premium — Free."

- [ ] **Step 4: Verify In-App Event surfaces in App Store Search**
  Search "BudgetVault" in App Store. Confirm the "April Wrapped Drops Sunday" event card appears on the product page (visible 14 days before event start per Apple).

- [ ] **Step 5: Update marketing-plan.md with live URLs**
  Append the three CPP URLs + Offer Code URL to `research/marketing-plan.md` under a new "v3.3.0 Live Acquisition Surfaces" section. Commit:
  ```bash
  git add research/marketing-plan.md
  git commit -m "docs(marketing): record live v3.3.0 CPP + Offer Code URLs"
  ```

---

## Task 23: Open PR for v3.3-aso-acquisition Branch

**Files:** none

- [ ] **Step 1: Push final state**
  ```bash
  git push origin v3.3-aso-acquisition
  ```

- [ ] **Step 2: Create PR via gh**
  ```bash
  gh pr create --base v3.3-wedge --title "v3.3.0 ASO acquisition push (Week 4)" --body "$(cat <<'EOF'
  ## Summary
  - Adds OfferCodeService for Apple-hosted referral via Settings, gated 30+ days post-purchase
  - Adds 3 ReviewPromptService triggers (Wrapped complete, first reconciled month, Day-30 streak); removes 14-day trigger from StreakService
  - Captures firstPremiumPurchaseDate on purchase and entitlement checks
  - Ships ASO docs in /docs/aso for App Store Connect submission: screenshot copy, App Preview storyboard + capture commands, three CPP specs, IAE spec, German metadata strings, vs-rocket-money page outline, squatter follow-up checklist

  ## Test plan
  - [ ] All 96 unit tests green (8 new OfferCodeService + 8 new ReviewPromptService)
  - [ ] Manual: Settings referral row appears only when isPremium && firstPremiumPurchaseDate ≥30d
  - [ ] Manual: Wrapped slide-5 fires SKStoreReviewController once, idempotent on second view
  - [ ] Manual: full reconciliation of a month fires SKStoreReviewController once
  - [ ] App Preview video uploaded to ASC and accepted by Apple
  - [ ] DE locale visible in App Store Connect with all 5 fields filled
  - [ ] 3 CPPs submitted to ASC
  - [ ] In-App Event submitted to ASC
  - [ ] Offer Code campaign live in ASC; URL pasted into OfferCodeService

  Spec: docs/superpowers/specs/2026-04-16-v3.3-wedge-and-foundation-design.md sections 5.13–5.19
  Plan: docs/superpowers/plans/04-aso-acquisition.md
  EOF
  )"
  ```

---

## Acceptance Criteria (v3.3.0 ship)

Maps directly to spec section 7 success criteria:

- [ ] App Preview video live in App Store (Task 4)
- [ ] 3 CPPs live (Task 5)
- [ ] DE listing live in App Store Connect (Task 7)
- [ ] Offer Codes flow ships in Settings (Tasks 9–13)
- [ ] Re-timed review prompts ship (Tasks 14–19)
- [ ] Privacy reposition copy live on screenshot 1 + slot 2 reword (Task 1)
- [ ] In-App Event submitted (Task 6)

---

## Spec Coverage Self-Review

| Spec Section | Plan Task(s) | Coverage |
|---|---|---|
| 5.13 Privacy Reposition Copy | 1, 2, 3 | Screenshot caption + vs-Rocket-Money page outline + squatter follow-up |
| 5.14 25-Second App Preview Video | 4 | Storyboard, capture commands, ASC upload path |
| 5.15 Three Custom Product Pages | 5 | All three CPPs (`/ynab-refugee`, `/privacy`, `/wrapped`) with full headline + screenshot lineups |
| 5.16 In-App Event for Monthly Wrapped | 6 | IAE copy (event name, short desc, badge), event card export, ASC submission, re-run playbook |
| 5.17 DE Localization Metadata-Only | 7 | Finished German subtitle, keywords (incl. `Haushaltsbuch`), description, screenshot captions, release notes |
| 5.18 Apple Offer Codes Referral | 8, 9, 10, 11, 12, 13 | AppStorageKey, StoreKitManager date capture, TDD, OfferCodeService, SettingsView row, ASC offer setup |
| 5.19 Smart Review Prompt Re-timing | 8, 14, 15, 16, 17, 18, 19 | AppStorageKeys, TDD tests, 3 new triggers, StreakService 14-day removal, MonthlyWrappedView wiring, HistoryView wiring, Settings cleanup |

All seven in-scope spec sections have task coverage. No "TBD" placeholders. All file paths absolute. No undefined types/functions.
