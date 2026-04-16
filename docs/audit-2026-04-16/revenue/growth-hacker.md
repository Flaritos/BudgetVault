# Revenue: Growth Hacker Findings

## TL;DR
Wrapped is a viral asset built without a viral payload, the review-prompt is wired but not triggered at a peak-emotion moment, and there is no privacy-clean referral loop — fix these three in v3.3 and you 2-3x organic conversion without violating "Data Not Collected."

## Top 3 Opportunities (Ranked)

1. **Wrapped → Inevitable Share (viral loop, K-factor lever)** — Effort: 3-5 days. Impact: highest. Wrapped exists (5-slide Spotify-style) but the share artifact is the bottleneck. Three changes: (a) render a 1080x1920 PNG via `ImageRenderer<MonthlyWrappedShareCard>` sized for IG Stories with a *visible* "budgetvault.io" wordmark + App Store QR at the bottom (the QR is your attribution-free referral); (b) auto-present `ShareLink` on slide 5 with pre-filled caption "I budgeted $X this month without giving any app my bank login"; (c) include a non-financial brag stat ("47-day streak", "182 logs") so users with low spend still want to share. This is the only loop that scales without paid ads.

2. **Privacy-Safe Referral via App Store Offer Codes / Promo Codes** — Effort: 2-3 days. Impact: medium-high. Add a "Give a friend BudgetVault" row in Settings that distributes one of Apple's free codes per premium user (gated to 30+ days post-purchase). Pre-fill SMS via `UIActivityViewController`. No server, no SDK, no tracking — Apple handles redemption. This is the only referral mechanic compatible with the "Data Not Collected" label. Target K = 0.15 from premium users alone.

3. **Two-Trigger Smart Review Prompt** — Effort: 1 day. Impact: medium. `AppStorageKeys.reviewPromptCount` exists but trigger logic appears bound to Settings rather than a positive moment. Move `SKStoreReviewController.requestReview()` to fire after either: (a) user logs their 10th transaction AND has 7+ day install age AND streak ≥3, or (b) Wrapped completion. Apple caps at 3 prompts/year — spending one on a dopamine peak is the difference between 4.5 and 4.8 stars.

## Top 3 Risks / Debt Items

1. **No instrumentation, no funnel visibility.** "Data Not Collected" is the brand, but you can still increment *on-device-only* counters (install date, days_active, paywall_views, paywall_dismissals, share_taps) and surface them via the existing `FeedbackService` payload. Without this you cannot tell where the funnel breaks. Build a `LocalMetricsService` mirroring `FeedbackService`'s local-log pattern.
2. **Tip Jar buried in Settings.** Consumable tip is a dead asset. Surface a low-friction tip sheet at three peak moments: after Wrapped, after a 30-day streak, and after `Restore Purchases` succeeds ("Enjoying BudgetVault? Buy the dev a coffee — $2.99"). Tips from happy users currently fund nothing.
3. **Single Live Activity touchpoint.** v3.2 added the evening close-vault notification but no morning briefing actually fires (`morningBriefingEnabled` is wired in `SettingsView.swift:18` but no scheduler ships), no end-of-week pulse, no streak-broken recovery push. Post-activation, the app goes silent.

## Quick Wins (<1 day each)
- Trigger `requestReview()` on Day 30 streak hit and Wrapped completion.
- Add `ShareLink` row to Settings header ("Tell a friend") with pre-filled `budgetvault.io` URL — currently buried.
- Surface `launchPricingEndDate` countdown banner on the paywall sheet (computed at `StoreKitManager.swift:15-42`, not surfaced everywhere).
- Wrapped slide 5: "Save to Photos" button that exports a watermarked PNG.
- Tip jar copy: rename "Tip" → "Buy the dev a coffee" with three tiers ($2.99 / $7.99 / $19.99 food-anchored labels).
- Pre-fill all share captions with `budgetvault.io` for free SEO and branded link traffic (server logs only, no SDK).
- Add a non-blocking "Vault Intelligence preview" card on Day 7 of usage so premium isn't introduced cold at a paywall.

## Long Bets (>2 weeks but transformative)
- **Family Sharing entitlement on the $14.99 IAP.** The only Apple-native network-effect lever you have. One purchase → up to 6 household members. Apple's family share-prompt is a free word-of-mouth surface and the conversion math still works at $14.99/family.
- **"Vault Stories" — auto-generated weekly Wrapped-mini.** Every Sunday, generate a 3-card story from on-device data, tappable from Home. Each emits a fresh share-image. Turns Wrapped from annual → 52x/year viral surface.
- **Public budgetvault.io/wrapped gallery.** Opt-in, anonymized, user-curated. Becomes a content-marketing engine (Reddit, Twitter screenshots) without any in-app telemetry.
- **One-way "Send your Wrapped to a partner"** as precursor to full CKShare partner sharing — recipient must install to view. Built-in referral with social proof.

## What NOT to Do
- **No Branch / AppsFlyer / Adjust SDK** for referral attribution — invalidates the privacy label, which is the entire wedge per `BRIEFING.md:48`.
- **No "invite to earn premium discount"** — discounting $14.99 destroys the "lock in $14.99 before $24.99" anchor in `marketing-plan.md`.
- **No email capture for lifecycle marketing** — nukes the r/privacy launch story in `reddit-launch-posts.md`.
- **No "share to unlock features"** dark patterns — kills the trust that IS the product.
- **No server-dependent push notifications** — must remain `UNNotificationCenter` local-only.
- **No countdown pricing you can't honor** — the July 1 cliff in `StoreKitManager.swift:15` needs a credible follow-up plan or it burns goodwill.

Sources:
- [SKStoreReviewController Guide with Examples (Critical Moments)](https://criticalmoments.io/blog/skstorereviewcontroller_guide_with_examples)
- [Increase App Ratings by using SKStoreReviewController (SwiftLee)](https://www.avanderlee.com/swift/skstorereviewcontroller-app-ratings/)
- [SKStoreReviewController | Apple Developer Documentation](https://developer.apple.com/documentation/storekit/skstorereviewcontroller)
