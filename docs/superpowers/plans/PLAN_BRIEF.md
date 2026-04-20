# Plan-Writing Briefing — BudgetVault v3.3
**Read first if you've been dispatched to write a v3.3 implementation plan.**

## Source-of-Truth Documents (read these in order)

1. **The spec** — `docs/superpowers/specs/2026-04-16-v3.3-wedge-and-foundation-design.md`
2. **The audit synthesis** — `docs/audit-2026-04-16/SYNTHESIS.md`
3. **Your assigned audit detail files** (listed in your task prompt)
4. **MEMORY pointer** — see `MEMORY.md` and `memory/project_v32_shipped.md` for current state of the codebase

## Project Architecture Rules (DO NOT VIOLATE)

1. Money = `Int64` cents (NOT `Decimal` — SwiftData corrupts it)
2. `@Query` in Views only, ViewModels use `@Observable`
3. AI insights 100% on-device, no external APIs
4. `VersionedSchema` from day 1 (`BudgetVaultSchemaV1` exists)
5. Half-open date intervals: `date >= periodStart && date < nextPeriodStart`
6. No `#Unique` macro (breaks CloudKit)
7. Use `Color.accentColor` not `.accent`
8. StoreKit `Transaction` alias: use `StoreKit.Transaction`
9. Use `xcodegen generate` after adding files (config in `project.yml`)

## Plan Document Format (REQUIRED)

Save your plan to `docs/superpowers/plans/<NN>-<kebab-title>.md` where NN matches your assigned plan number (01–07).

**Header (REQUIRED):**

```markdown
# [Feature Name] Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** [One sentence]

**Architecture:** [2-3 sentences about approach]

**Tech Stack:** [Key technologies/libraries]

**Estimated Effort:** [X days]

**Ship Target:** [vX.X.X]

---
```

**Then a File Structure section** mapping every file Created / Modified / Tested in this plan, with one-line responsibility for each.

**Then numbered Tasks**, each containing:
- **Files:** Create / Modify (with `path:line-range`) / Test
- Bite-sized steps (2–5 min each), each as a checkbox `- [ ]`
- TDD pattern where applicable: write failing test → run, see fail → impl → run, see pass → commit
- COMPLETE CODE in every step that changes code (no "TODO", no "similar to above")
- Exact bash commands with expected output
- Conventional commit messages

## No Placeholders — these are plan failures, never write them:

- "TBD", "TODO", "implement later", "fill in details"
- "Add appropriate error handling" (show the exact handler)
- "Write tests for the above" (without actual test code)
- "Similar to Task N" (repeat the code)
- "Handle edge cases" (enumerate them)
- References to types/functions not defined in any task

## Context Brevity

Plans are read by engineers (or subagents) executing tasks one at a time. Don't pad. Skip:
- Marketing rationale (the spec has it)
- Cross-references to other plans (the user orchestrates that)
- "What this teaches you" / "Why this matters" sections

Lead with what to do.

## Self-Review Before Saving

After writing the complete plan, scan for:
1. Spec coverage — does every spec requirement in your scope have a task?
2. Placeholder hunt — any of the failure patterns above?
3. Type consistency — do method names / property names match across tasks?
4. File paths — are they absolute and correct?

Fix inline. Save. Done.
