# Engineering: DevOps / Release Engineering Findings

## TL;DR
Zero release automation exists — no CI, no Fastlane, no branch protection, manual versioning, and crash signals are invisible because MetricKit (Apple's privacy-safe first-party telemetry) is not wired up; one weekend of Fastlane + GitHub Actions + MetricKit unlocks daily TestFlight builds without violating the "Data Not Collected" wedge.

## Top 3 Opportunities (Ranked)

1. **Fastlane + GitHub Actions on self-hosted runner (your Mac)** — Effort: 1–2 days. Impact: high. `gh api repos/.../actions/workflows` returns `{"total_count":0}`. Add `fastlane/Fastfile` with three lanes: `test` (xcodebuild test on iPhone 17 Pro sim), `beta` (xcodegen generate → match → gym → pilot upload), `release` (deliver metadata + screenshots). Runner = your local Mac via `actions-runner` (free, no third-party data). PR-triggered `test` lane gates merges; tag-triggered `beta` lane ships TestFlight in ~12 minutes unattended. Replaces the entire manual Xcode Organizer dance referenced in MEMORY.md ("Pending: PR #1 merge + IPA upload").

2. **MetricKit integration for crash + hang reporting** — Effort: 4 hours. Impact: critical for v3.3 confidence. `Grep MetricKit` returns zero matches. Apple's `MXMetricManager` delivers daily crash reports, hang diagnostics, disk-write telemetry, and battery impact directly to your app — 100% on-device, App Store privacy-label compliant. Persist payloads to `Documents/diagnostics/` and surface via the existing `FeedbackService` so users can opt to attach when reporting bugs. This is the only way you'll know v3.3 isn't crashing in the field without a third-party SDK.

3. **Versioning + release notes automation** — Effort: 4 hours. Impact: medium. `project.yml:43,111` shows `CURRENT_PROJECT_VERSION: "1"` hard-coded across two targets and never incremented (every TestFlight build collides). Add `scripts/bump-version.sh` that reads `git rev-list --count HEAD` into `CURRENT_PROJECT_VERSION` and parses commit subjects since last tag (`v3.2.1..HEAD`) into `fastlane/metadata/en-US/release_notes.txt`. Eliminates the "build number already used" App Store Connect rejection and removes manual changelog drafting.

## Top 3 Risks / Debt Items

1. **Main branch is unprotected.** `gh api .../branches/main/protection` returns 404. Solo dev means accidental force-push risk is real; `git branch -a` shows 17 abandoned `worktree-agent-*` branches and stale `v3.0-option-c`, `v3.0-phase5-gestures`, `v3.2-daily-loop` polluting refs. Enable: required PR + require linear history + require status checks (once CI exists). Run `git branch -D` cleanup on the worktree branches.

2. **No pre-merge test gate.** 80 tests + 4 UI test files (DeepSmokeUITest captures 45 screenshots) exist but rely on manual `Cmd-U`. The MEMORY.md note "8 audit rounds, 50+ fixes" implies regressions were caught reactively. A 6-minute `xcodebuild test` lane on PRs would have caught most.

3. **Signing + secrets are implicit.** `CODE_SIGN_STYLE: Automatic` (project.yml:13) works locally but breaks headless CI. No `Matchfile`, no App Store Connect API key checked into 1Password / macOS Keychain reference. First CI run will fail signing. Mitigate with `fastlane match` + ASC API key stored in macOS Keychain (referenced via `security find-generic-password` in CI), never in repo.

## Quick Wins (<1 day each)

- Add `.github/workflows/pr.yml` running `xcodegen generate && xcodebuild test -scheme BudgetVault -destination 'platform=iOS Simulator,name=iPhone 17 Pro'` on every PR.
- Enable GitHub branch protection on `main` (gh api PUT) requiring 1 review + status checks once CI is green.
- Add `scripts/preflight.sh` chaining: `xcodegen generate`, `swift format lint`, `xcodebuild test`. Run via git pre-push hook.
- Delete 17 stale `worktree-agent-*` branches: `git branch -D $(git branch | grep worktree-agent)`.
- Move `ExportOptions.plist` into `fastlane/` and reference from `gym(export_options:)`.
- Add SwiftLint via SPM plugin — catches style drift across 82 Swift files at compile time, no third-party server.

## Long Bets (>2 weeks but transformative)

- **Snapshot testing for App Store screenshots** — Replace `screenshots/` (manually captured per `4009c31`, `214090f` commits) with `fastlane snapshot` + `frameit`. v3.3 screenshots regenerate on every release for free, and adding DE/ES/FR localization later costs zero incremental effort.
- **Localization pipeline scaffolding** — Even before translating, extract strings to `Localizable.xcstrings` (Xcode 15 catalog format) and add `xcodebuild -exportLocalizations` to CI. When v3.4 ships DE/ES/FR, only `.xliff` files change.
- **Self-hosted GitHub runner as a launchd service on the Mac mini** — Always-on, no per-minute billing, no source code leaving your network. Privacy-brand-aligned and free.

## What NOT to Do

- ❌ Sentry / Bugsnag / Firebase Crashlytics — would invalidate "Data Not Collected" privacy label. MetricKit replaces them.
- ❌ Codemagic / Bitrise / GitHub-hosted macOS runners (paid, send build artifacts to third parties). Self-hosted on your existing Mac is free and private.
- ❌ Plaid / analytics SDKs — explicit BRIEFING constraint.
- ❌ Don't introduce CocoaPods or Carthage — SPM only; the codebase has zero current dependencies and that's a feature.
- ❌ Don't over-engineer with Tuist — xcodegen already works; switching is a 2-week migration with zero user-facing benefit.
- ❌ Don't add semantic-release / conventional commits enforcement — solo dev, friction outweighs benefit at this scale.
