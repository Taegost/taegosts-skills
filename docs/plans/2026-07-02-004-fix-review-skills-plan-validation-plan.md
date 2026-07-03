---
title: "fix: skills don't validate implementations against plan KTD specifications"
type: fix
date: 2026-07-02
---

# Fix: Skills Don't Validate Against Plan KTD Specifications

## Summary

Skills `ts-work`, `ts-verify-implementation`, and `ts-pr-fix-findings` fail to validate implementations against the feature plan's KTD specifications at the literal level. This plan fixes all 10 mismatches from issue #79 and adds plan-reading capability to all applicable skills.

## Problem Frame

Three root causes allow implementation drift:

1. **ts-work** reads KTDs as part of the plan text but doesn't extract or inline them into its execution context. Implementations drift to inconsistent formats because the exact spec string isn't salient during execution.
2. **ts-verify-implementation** checks "does metacharacter validation exist?" (yes) but not "does the exact regex string match KTD1 character-by-character?" The Completeness subagent sees validation exists and marks it done.
3. **ts-pr-fix-findings** never reads the plan at all. Its entire frame of reference is the reviewer's PR comments, creating four blind spots: no architectural context, no scope boundary awareness, no requirements traceability, and isolated remediation plans.

Additionally, other skills that do coding or reviewing work don't auto-discover plans from `docs/plans/`, missing opportunities to validate against the plan.

**Evidence:** The previous hardening pass (`docs/plans/2026-07-02-003-fix-pr-work-script-hardening-plan.md`) skipped many items that were part of the plan — test coverage gaps, documentation units, and bug fixes that were specified but not implemented. This is concrete evidence that plan drift is a real problem, not a theoretical one.

## Issue #79 Mismatches

| # | Description | Requirement | Unit |
|---|-------------|-------------|------|
| 1 | Regex format inconsistency (skills use different formats than KTD1 spec) | R2, R3, R4 | U2, U3, U4 |
| 2 | Tests only verify `;` for metacharacter rejection, not full blocklist | R7 | U5 (verification) |
| 3 | Path traversal tests missing (`foo/../bar` rejection, `foo..bar` acceptance) | R8 | U5 (verification) |
| 4 | Missing-value guards untested (`--repo`/`--pr` with no value) | R9 | U5 (verification) |
| 5 | Prior hardening plan U6 bug fix lacks regression test | R10 | U5 (verification) |
| 6 | `detect-missing-artifacts.sh` `..` check over-rejects valid filenames | R11 | U5 (verification) |
| 7 | `find-precommit-hook.sh` not validated by test | R12 | U5 (verification) |
| 8 | `.git/` directory exclusion not tested | R13 | U5 (verification) |
| 9 | Prior hardening plan U9 documentation incomplete | R14 | U5 (verification) |
| 10 | Prior hardening plan U10 test audit incomplete | R15 | U5 (verification) |

## Priority Tiers

- **P1 (Core fix):** U1, U2, U3, U4 — address the root causes of plan-validation drift
- **P2 (Verification):** U5 — verify the prior hardening plan was fully implemented using updated logic
- **P3 (Infrastructure):** U6 — KTD extraction utility and standards documentation

## Requirements

### Skill Logic Fixes (Root Causes)

- R1. `ts-work` extracts KTD specifications from the plan and loads them into execution context so implementers apply specs literally
- R2. `ts-verify-implementation` Completeness subagent verifies the *exact KTD spec* is implemented, not just that *something* exists
- R3. `ts-verify-implementation` Correctness subagent verifies implementation strings match KTDs literally
- R4. `ts-pr-fix-findings` reads the feature plan (from `docs/plans/`) before remediating, cross-references findings against KTDs and Scope Boundaries

### Plan Discovery

- R5. A shared `load-plan` skill handles plan discovery for all skills that need plan context. Discovery uses: (1) use plan already passed as argument, (2) check `docs/plans/` for a plan updated on the current branch (via `git diff` against the base branch), or pick the most recent plan if none have been modified, (3) ask user. On ambiguity or error, ask the user what to do.
- R6. All skills that need plan context call `/load-plan`: `ts-work`, `ts-verify-implementation`, `ts-pr-fix-findings`, `ts-code-review`, `ts-coding-workflow`, `ts-do-work-loop`. Skills with existing plan discovery migrate to the shared skill. `ts-pr-review` gets plan discovery transitively through `ts-code-review` and does not need its own migration.

### Test Coverage (Issue #79 Mismatches)

- R7. Tests verify each KTD1 metacharacter individually (not just `;`)
- R8. Path traversal tests cover `foo/../bar` rejection and `foo..bar` acceptance
- R9. Missing-value guards tested for `--repo`/`--pr` arguments
- R10. Original U6 bug fix (from hardening plan `2026-07-02-003`) has a regression test
- R11. `detect-missing-artifacts.sh` `..` check doesn't over-reject valid filenames like `my.config.js`
- R12. `find-precommit-hook.sh` validated by test
- R13. `.git/` directory exclusion tested

### Documentation

- R14. U9 documentation unit (from hardening plan) completed
- R15. U10 test audit (from hardening plan) completed

## Key Technical Decisions

**KTD1 [literal]. Plan discovery via shared `load-plan` skill.** All skills that need plan context call `/load-plan` instead of implementing their own discovery. The skill is based on ts-code-review's existing plan discovery logic (keyword extraction from branch name, PR body scanning, confidence tagging). The skill uses a three-tier fallback: (1) use the plan already passed as an argument, (2) check `docs/plans/` for a plan that has been updated on the current branch (via `git diff` against the base branch), or pick the most recent plan if none have been modified, (3) ask the user. On ambiguity (multiple matches), always ask the user — never silently pick "most recent." On error (detached HEAD, shallow clone, no remote, unreadable file), ask the user what to do. The `plan:` argument is the recommended path for non-interactive callers. Explicit input always takes precedence over auto-discovery. The skill returns the plan path and content, or an error if no plan is found. The skill is a pure utility — it only locates and loads the plan. It does not execute, verify, modify, or extract content from the plan.

**KTD2 [literal]. KTD classification and verification.** Plan authors label each KTD with a type marker: `[literal]` for regex patterns, code snippets, and exact strings; `[behavioral]` for patterns, approaches, and constraints. If unclassified, default to `[literal]` (safer default). Literal KTDs: the Completeness and Correctness subagents compare character-by-character, applying a normalization policy (see `docs/solutions/ktd-normalization-policy.md`). Behavioral KTDs: the subagents verify the implementation follows the intent of the decision using criteria defined in `docs/solutions/behavioral-ktd-verification.md`. Both subagents receive the KTD section as separate structured input, not buried in the full plan text. KTD extraction is done by the consumer skill (not load-plan) by parsing markdown headers for the "Key Technical Decisions" section.

**KTD3 [literal]. ts-work KTD inlining.** When ts-work reads a plan, it extracts the KTD section by parsing the "Key Technical Decisions" markdown header. Each KTD is presented as a named constraint to the implementer with its type marker (`[literal]` or `[behavioral]`). For literal KTDs, the content is carried forward as a verification checklist item — the implementer must confirm the implementation matches the spec exactly. For behavioral KTDs, the intent is presented as a constraint the implementation must satisfy.

**KTD4 [literal]. ts-pr-fix-findings plan cross-reference.** After reading PR findings, the skill checks `docs/plans/` for a plan that has been updated on the PR's branch (via `git diff` against the base branch). If found, it reads the plan's KTDs and Scope Boundaries. Each finding is cross-referenced: does the reviewer's request contradict a KTD? Is it asking for something explicitly out of scope? Divergences are noted in the remediation plan so the operator can make an informed decision.

## Implementation Units

### U1. Create shared `load-plan` skill and migrate ts-pr-fix-findings (Phase 1)

Create a new `load-plan` skill based on ts-code-review's existing plan discovery logic. In Phase 1, migrate only ts-pr-fix-findings to validate the skill works. Remaining skills migrate in Phase 2 after validation.

**Goal:** Single source of truth for plan discovery. Phase 1 validates with one consumer before broader migration.

**Requirements:** R5, R6

**Phase 1 files:**
- `skills/load-plan/SKILL.md` (new — based on ts-code-review Stage 2b logic)
- `skills/ts-pr-fix-findings/SKILL.md` (migrate)

**Phase 2 files (after Phase 1 validation):**
- `skills/ts-do-work-loop/SKILL.md` (migrate)
- `skills/ts-coding-workflow/SKILL.md` (migrate)
- `skills/ts-work/SKILL.md` (migrate — remove Phase 1 step 1 inline glob discovery triggered by blank invocation via Phase 0)
- `skills/ts-verify-implementation/SKILL.md` (migrate — remove inline `ls docs/plans/` fallback)
- `skills/ts-code-review/SKILL.md` (migrate — remove Stage 2b inline discovery)
- `skills/ts-pr-review/SKILL.md` (inherits via ts-code-review, no change needed)

**Approach — `load-plan` skill:**
- Based on ts-code-review's existing Stage 2b plan discovery logic (keyword extraction from branch name, PR body scanning, confidence tagging)
- Accepts optional argument: plan path, plan filename, or blank
- Three-tier fallback per KTD1:
  1. If argument is a valid plan path/filename, read and return it
  2. If blank, use keyword extraction from branch name to match plans. If no match, ask the user (never silently pick "most recent")
  3. If no plans exist, ask the user what to do
- On error (detached HEAD, shallow clone, no remote, unreadable file), ask the user what to do
- `plan:` argument is recommended for non-interactive callers
- Returns: plan path + plan content (or error)
- Pure utility — only locates and loads the plan. Does not execute, verify, modify, or extract content.

**Approach — consumer migration (Phase 1):**
- `ts-pr-fix-findings`: Add step between Step 0 and Step 1: call `/load-plan` with the PR's branch as context. If a plan is found, extract KTDs (by parsing "Key Technical Decisions" header) and Scope Boundaries for cross-referencing.

**Test scenarios:**
- Happy path: `/load-plan` with explicit path returns plan
- Happy path: `/load-plan` blank, branch keywords match a plan, returns it
- Happy path: `/load-plan` blank, no match, user is prompted
- Edge case: multiple plans match, user is prompted
- Edge case: no plans exist, user is prompted
- Edge case: detached HEAD, user is prompted
- Error path: argument is a path but file doesn't exist, user is prompted

**Verification:** ts-pr-fix-findings calls `/load-plan` and receives correct plan discovery behavior. After PR finding resolution validates the skill, Phase 2 begins.

---

### U2. Enhance ts-verify-implementation for KTD literal comparison

Modify the Completeness and Correctness subagents to verify implementations against KTD specifications at the literal level.

**Goal:** ts-verify-implementation catches KTD mismatches (wrong regex format, missing characters, inconsistent patterns).

**Requirements:** R2, R3

**Files:**
- `skills/ts-verify-implementation/SKILL.md`

**Approach:**
- Step 2 (Read the plan): Extract the KTD section by parsing the "Key Technical Decisions" markdown header. Pass each KTD as a structured item to the subagents with its type marker (`[literal]` or `[behavioral]`).
- Subagent 2 (Completeness): Add instructions — "For each KTD in the plan, find the corresponding implementation code. For `[literal]` KTDs, verify the *exact spec* is implemented — compare the literal character sequence after applying the normalization policy from `docs/solutions/ktd-normalization-policy.md`. For `[behavioral]` KTDs, verify the implementation follows the intent using criteria from `docs/solutions/behavioral-ktd-verification.md`."
- Subagent 1 (Correctness): Add instructions — "For each `[literal]` KTD, extract the implementation string from the diff and compare it against the KTD specification using the normalization policy. Flag any difference — missing characters, extra characters, different quoting style, different escape sequences. For `[behavioral]` KTDs, verify the implementation satisfies the stated intent."
- Both subagents receive a structured KTD list: `KTD-N [type]: <spec text> | <files it applies to>`.

**Patterns to follow:** Current subagent output format (verdict + bulleted findings with file/line references).

**Test scenarios:**
- Happy path: implementation matches `[literal]` KTD exactly → PASS
- Happy path: implementation has wrong regex format → FAIL with specific mismatch
- Happy path: implementation satisfies `[behavioral]` KTD intent → PASS
- Edge case: KTD has two variants (non-path and file-path), both must be verified
- Edge case: implementation uses a different quoting style (double-quoted vs ANSI-C) → FAIL
- Edge case: `[literal]` KTD has minor whitespace differences — normalization policy determines if PASS or FAIL
- Error path: KTD references a file that doesn't exist → FAIL with "file not found"
- Error path: KTD has no type marker → defaults to `[literal]`, verified strictly

**Verification:** Running ts-verify-implementation against a plan with KTDs catches literal mismatches and behavioral intent violations.

---

### U3. Enhance ts-work to load KTD specifications into context

Modify ts-work to extract KTDs from the plan and present them as named constraints during execution.

**Goal:** Implementers apply KTD specs literally because the exact spec string is salient in their context.

**Requirements:** R1

**Files:**
- `skills/ts-work/SKILL.md`

**Approach:**
- Phase 1 (Quick Start), after reading the plan: Extract the KTD section by parsing the "Key Technical Decisions" markdown header. For each KTD, present it as a "verification constraint" with the exact spec text and its type marker (`[literal]` or `[behavioral]`).
- For `[literal]` KTDs containing code patterns (regex, function signature, config format), the KTD content is carried forward as a checklist item — the implementer must confirm the implementation matches the spec exactly.
- For `[behavioral]` KTDs, the intent is presented as a constraint the implementation must satisfy.
- For Implementation Units that reference KTDs (e.g., "Update per KTD1"), inline the KTD spec text into the unit's context so the implementer doesn't need to resolve the reference.

**Patterns to follow:** Current Phase 1 "Review any references or links provided in the plan" pattern — extend it to KTDs.

**Test scenarios:**
- Happy path: plan has `[literal]` KTDs, implementer applies them literally
- Happy path: plan has `[behavioral]` KTDs, implementer satisfies the intent
- Edge case: plan has multiple KTDs, each applies to different files
- Edge case: KTD references a standard in `docs/solutions/` — implementer reads the standard
- Edge case: KTD has no type marker — defaults to `[literal]`

**Verification:** ts-work implementations match KTD specs without drift.

---

### U4. Add ts-pr-fix-findings plan cross-reference

Modify ts-pr-fix-findings to read the feature plan before remediating and cross-reference findings against KTDs and Scope Boundaries.

**Goal:** ts-pr-fix-findings detects when a reviewer's request contradicts the original design intent.

**Requirements:** R4

**Files:**
- `skills/ts-pr-fix-findings/SKILL.md`

**Approach:**
- New step between Step 0 and Step 1 (between repo context and ts-debug check): Call `/load-plan` with the PR's branch as context.
- If a plan is found, extract KTDs (by parsing "Key Technical Decisions" header) and Scope Boundaries.
- Step 3 (Plan the fix): For each finding, cross-reference against the plan:
  - Does the reviewer's request contradict a KTD? Note the divergence.
  - Is the reviewer asking for something explicitly out of scope per the plan? Note it.
  - Does the fix inadvertently break a requirement or violate a KTD? Flag it.
- The remediation plan includes a "Plan Divergence" column noting any conflict between what the reviewer asked for and what the plan specified.

**Patterns to follow:** ts-code-review Stage 2b plan discovery. Current Step 3 remediation plan format.

**Test scenarios:**
- Happy path: finding aligns with plan, no divergence noted
- Happy path: finding contradicts a KTD, divergence noted in plan
- Edge case: finding asks for something out of scope per plan, flagged
- Edge case: no plan exists for the branch, skill proceeds without plan context
- Error path: plan exists but is unreadable, user is prompted

**Verification:** Remediation plans note divergences between reviewer requests and plan specifications.

---

### U5. Verify prior hardening plan was fully implemented

Using the updated ts-verify-implementation logic from U2, verify that the prior hardening plan (`docs/plans/2026-07-02-003-fix-pr-work-script-hardening-plan.md`) was fully implemented. This consolidates the test coverage, documentation, and bug fix verification from the prior plan into a single unit.

**Goal:** Confirm the prior hardening plan's KTDs, requirements, and implementation units are all complete using the new verification infrastructure.

**Requirements:** R7, R8, R9, R10, R11, R12, R13, R14, R15

**Files:**
- All test files referenced by the prior hardening plan
- All documentation files referenced by the prior hardening plan
- `skills/ts-work/scripts/detect-missing-artifacts.sh` (if `..` over-rejection bug is found)

**Approach:**
- Run the enhanced ts-verify-implementation against the prior hardening plan.
- For each KTD and requirement, verify the implementation matches the spec.
- For any gaps found: add missing tests, complete missing documentation, fix any bugs.
- Specific items to verify:
  - Metacharacter tests cover all KTD1 characters (not just `;`)
  - Path traversal tests cover `foo/../bar` rejection and `foo..bar` acceptance
  - Missing-value guards tested for `--repo`/`--pr`
  - Prior U6 bug fix has regression test
  - `detect-missing-artifacts.sh` `..` check doesn't over-reject valid filenames
  - `find-precommit-hook.sh` covered by tests
  - `.git/` directory exclusion tested
  - Prior U9 documentation complete
  - Prior U10 test audit complete

**Test scenarios:**
- Happy path: all prior plan items verified as implemented → PASS
- Happy path: gap found, remediated, verified → PASS
- Edge case: prior plan's KTD uses `[behavioral]` type — verified using behavioral criteria
- Error path: prior plan references a file that no longer exists → FAIL with "file not found"

**Verification:** All items from the prior hardening plan are verified complete using the new infrastructure.

---

### U6. Create KTD extraction utility and standards documentation

Create a Python script for extracting KTDs from plan documents and document the KTD labeling standard and normalization policy in `docs/solutions/`.

**Goal:** Standardized KTD extraction and documented standards for KTD classification and verification.

**Requirements:** R1, R2, R3

**Files:**
- `scripts/extract-ktds.py` (new)
- `docs/solutions/ktd-normalization-policy.md` (new)
- `docs/solutions/behavioral-ktd-verification.md` (new)

**Approach:**
- `extract-ktds.py`: Parse markdown files, find the "Key Technical Decisions" section, extract each KTD with its type marker (`[literal]` or `[behavioral]`), spec text, and associated files. Output as structured JSON.
- `ktd-normalization-policy.md`: Document the normalization policy for literal KTD comparison — what whitespace is normalized, what quoting differences are acceptable, what constitutes a literal match for multi-line snippets.
- `behavioral-ktd-verification.md`: Document the criteria for verifying behavioral KTDs — what evidence to look for, what constitutes a match vs mismatch, how ambiguous cases are resolved. **Logic needs user approval before implementation.**

**Test scenarios:**
- Happy path: plan with `[literal]` and `[behavioral]` KTDs extracted correctly
- Happy path: plan with no type markers — all default to `[literal]`
- Edge case: KTD spans multiple paragraphs — extracted as single item
- Edge case: plan has no "Key Technical Decisions" section — returns empty array
- Error path: file doesn't exist or is unreadable — returns error

**Verification:** Python script correctly extracts KTDs from existing plan documents.

## Scope Boundaries

**In scope:**
- All 10 mismatches from issue #79 (see mismatch table above)
- Plan-reading for all applicable skills
- KTD literal verification in ts-verify-implementation
- KTD inlining in ts-work
- Plan cross-reference in ts-pr-fix-findings
- KTD extraction utility and standards documentation

**Deferred to Follow-Up Work:**
- Phase 2 consumer migration (ts-work, ts-verify-implementation, ts-code-review, ts-do-work-loop, ts-coding-workflow) — after Phase 1 validation

## Risks & Dependencies

- **Risk:** KTD literal comparison in subagents may be too strict — minor formatting differences (whitespace) could cause false positives. Mitigation: normalization policy documented in `docs/solutions/ktd-normalization-policy.md`. Quoting style differences (double-quoted vs ANSI-C) are intentional failures — different quoting has different escape semantics and should not be normalized.
- **Risk:** Plan discovery by branch name may match wrong plans if branch names are generic. Mitigation: always ask the user on ambiguity, never silently pick "most recent."
- **Risk:** load-plan becomes a single point of failure. Mitigation: two-phase migration — validate with one consumer before broader rollout.
- **Dependency:** Issue #79 is the primary driver. PR #80 tracks the implementation.
- **Dependency:** Behavioral KTD verification criteria (U6) need user approval before implementation.
