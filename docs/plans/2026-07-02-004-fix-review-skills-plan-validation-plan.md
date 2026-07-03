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

## Requirements

### Skill Logic Fixes (Root Causes)

- R1. `ts-work` extracts KTD specifications from the plan and loads them into execution context so implementers apply specs literally
- R2. `ts-verify-implementation` Completeness subagent verifies the *exact KTD spec* is implemented, not just that *something* exists
- R3. `ts-verify-implementation` Correctness subagent verifies implementation strings match KTDs literally
- R4. `ts-pr-fix-findings` reads the feature plan (from `docs/plans/`) before remediating, cross-references findings against KTDs and Scope Boundaries

### Plan Discovery

- R5. All applicable skills auto-discover plans using: (1) use plan already passed as argument or in session, (2) check `docs/plans/` for branch-name match or most recent, (3) ask user
- R6. Skills in scope: `ts-work`, `ts-verify-implementation`, `ts-pr-fix-findings`, `ts-pr-review`, `ts-code-review`, `ts-coding-workflow`, `ts-do-work-loop`. Of these, `ts-work` and `ts-verify-implementation` already read plans (enhanced by U2/U3), `ts-pr-review` delegates to `ts-code-review` (which already has plan discovery via Stage 2b), and `ts-code-review` already has keyword-based auto-discovery. U1 adds or enhances discovery for the remaining 3 skills.

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

**KTD1. Plan discovery mechanism.** All skills use a three-tier fallback: (1) use the plan already passed as an argument or loaded in session, (2) check `docs/plans/` for a plan matching the current branch name or pick the most recent, (3) ask the user. Explicit input always takes precedence over auto-discovery. This standardizes behavior across skills that currently use different discovery methods (ts-work globs by recency, ts-code-review globs by branch keywords, ts-verify-implementation prompts the user).

**KTD2. KTD literal comparison.** The Completeness and Correctness subagents receive explicit instructions to extract each KTD from the plan, find the corresponding implementation code, and compare the literal strings. Completeness verifies "the exact spec is implemented" (not just "something exists"). Correctness verifies "implementation string matches KTD character-by-character." Both subagents receive the KTD section as separate structured input, not buried in the full plan text.

**KTD3. ts-work KTD inlining.** When ts-work reads a plan, it extracts the KTD section and presents each KTD as a named constraint to the implementer. For regex patterns, code snippets, or other literal specs, the KTD content is carried forward as a verification checklist item — the implementer must confirm the implementation matches the spec exactly.

**KTD4. ts-pr-fix-findings plan cross-reference.** After reading PR findings, the skill searches `docs/plans/` for a plan matching the PR's branch. If found, it reads the plan's KTDs and Scope Boundaries. Each finding is cross-referenced: does the reviewer's request contradict a KTD? Is it asking for something explicitly out of scope? Divergences are noted in the remediation plan so the operator can make an informed decision.

## Implementation Units

### U1. Standardize plan discovery across skills

Add a consistent plan-discovery preamble to skills that don't already have one. The preamble follows the three-tier fallback from KTD1.

**Goal:** All applicable skills can discover and load plans from `docs/plans/` automatically.

**Requirements:** R5, R6

**Files:**
- `skills/ts-pr-fix-findings/SKILL.md`
- `skills/ts-do-work-loop/SKILL.md`
- `skills/ts-coding-workflow/SKILL.md`

**Approach:**
- For `ts-pr-fix-findings`: Add a new step between Step 0 (repo context) and Step 1 (ts-debug check) that searches `docs/plans/` for a plan matching the PR's branch. If found, read the plan's KTDs and Scope Boundaries as context for remediation.
- For `ts-do-work-loop`: Add auto-discovery when no argument is provided — glob `docs/plans/*.{md,html}`, pick the most recent, and pass it to ts-work and ts-verify-implementation.
- For `ts-coding-workflow`: Enhance the "Phase 1 gate" Rule (line 57 in the skill file) to auto-discover plans from `docs/plans/` using branch-name keyword matching, presenting candidates to the user instead of asking blindly.
- `ts-work` already has plan discovery (enhanced in U3). `ts-verify-implementation` already reads plans (enhanced in U2). `ts-code-review` already has keyword-based plan discovery in Stage 2b. `ts-pr-review` delegates to `ts-code-review`, so it inherits plan discovery. No changes needed for these 4 skills in this unit.

**Patterns to follow:** `ts-work` Phase 0 blank-invocation auto-discovery (glob `docs/plans/*.{md,html}`, pick most recent). `ts-code-review` Stage 2b branch-name keyword extraction.

**Test scenarios:**
- Happy path (ts-do-work-loop): skill invoked with no argument, plan exists in `docs/plans/`, most recent is auto-discovered
- Happy path (ts-pr-fix-findings): PR branch name matches a plan in `docs/plans/`, plan is loaded as context
- Happy path (ts-coding-workflow): branch-name keyword matching finds a candidate plan, user is presented with it
- Edge case: multiple plans exist, most recent is selected (ts-do-work-loop) or user is prompted (ts-coding-workflow)
- Edge case: no plans exist, skill falls through to user prompt
- Error path: plan file referenced but doesn't exist on disk

**Verification:** Each skill can discover a plan from `docs/plans/` when invoked without an explicit path.

---

### U2. Enhance ts-verify-implementation for KTD literal comparison

Modify the Completeness and Correctness subagents to verify implementations against KTD specifications at the literal level.

**Goal:** ts-verify-implementation catches KTD mismatches (wrong regex format, missing characters, inconsistent patterns).

**Requirements:** R2, R3

**Files:**
- `skills/ts-verify-implementation/SKILL.md`

**Approach:**
- Step 2 (Read the plan): Extract the KTD section separately. Pass each KTD as a structured item to the subagents (not buried in full plan text).
- Subagent 2 (Completeness): Add instructions — "For each KTD in the plan, find the corresponding implementation code. Verify the *exact spec* is implemented, not just that *something* exists. For regex patterns, compare the literal character sequence. For code patterns, verify the exact approach matches."
- Subagent 1 (Correctness): Add instructions — "For each KTD, extract the implementation string from the diff and compare it character-by-character against the KTD specification. Flag any difference — missing characters, extra characters, different quoting style, different escape sequences."
- Both subagents receive a structured KTD list: `KTD-N: <spec text> | <files it applies to>`.

**Patterns to follow:** Current subagent output format (verdict + bulleted findings with file/line references).

**Test scenarios:**
- Happy path: implementation matches KTD exactly → PASS
- Happy path: implementation has wrong regex format → FAIL with specific mismatch
- Edge case: KTD has two variants (non-path and file-path), both must be verified
- Edge case: implementation uses a different quoting style (double-quoted vs ANSI-C) → FAIL
- Error path: KTD references a file that doesn't exist → FAIL with "file not found"

**Verification:** Running ts-verify-implementation against a plan with KTDs catches literal mismatches.

---

### U3. Enhance ts-work to load KTD specifications into context

Modify ts-work to extract KTDs from the plan and present them as named constraints during execution.

**Goal:** Implementers apply KTD specs literally because the exact spec string is salient in their context.

**Requirements:** R1

**Files:**
- `skills/ts-work/SKILL.md`

**Approach:**
- Phase 1 (Quick Start), after reading the plan: Extract the KTD section. For each KTD, present it as a "verification constraint" with the exact spec text.
- When a KTD contains a code pattern (regex, function signature, config format), the KTD content is carried forward as a checklist item — the implementer must confirm the implementation matches the spec exactly.
- For Implementation Units that reference KTDs (e.g., "Update per KTD1"), inline the KTD spec text into the unit's context so the implementer doesn't need to resolve the reference.

**Patterns to follow:** Current Phase 1 "Review any references or links provided in the plan" pattern — extend it to KTDs.

**Test scenarios:**
- Happy path: plan has KTDs, implementer applies them literally
- Edge case: plan has multiple KTDs, each applies to different files
- Edge case: KTD references a standard in `docs/solutions/` — implementer reads the standard

**Verification:** ts-work implementations match KTD specs without drift.

---

### U4. Add ts-pr-fix-findings plan cross-reference

Modify ts-pr-fix-findings to read the feature plan before remediating and cross-reference findings against KTDs and Scope Boundaries.

**Goal:** ts-pr-fix-findings detects when a reviewer's request contradicts the original design intent.

**Requirements:** R4

**Files:**
- `skills/ts-pr-fix-findings/SKILL.md`

**Approach:**
- New Step 1.5 (between repo context and ts-debug check): Search `docs/plans/` for a plan matching the PR's branch. Use branch-name keyword extraction (same pattern as ts-code-review Stage 2b auto-discover).
- If a plan is found, read it. Extract KTDs and Scope Boundaries.
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
- Error path: plan exists but is unreadable, skill warns and proceeds

**Verification:** Remediation plans note divergences between reviewer requests and plan specifications.

---

### U5. Add individual metacharacter tests

Expand test suites to verify each KTD1 metacharacter is rejected individually.

**Goal:** Tests verify the full metacharacter blocklist, not just `;`.

**Requirements:** R7

**Files:**
- `tests/skills/ts-work/test-detect-missing-artifacts.sh`
- `tests/skills/ts-pr-fix-findings/test-check-thread-resolution.sh`
- `tests/skills/ts-pr-fix-findings/test-fetch-issue-comments.sh`
- `tests/skills/ts-plan/test-generate-plan-filename.sh`
- `tests/skills/ts-verify-implementation/test-detect-file-status.sh`

**Approach:**
- For each test file, add a test case for each metacharacter in KTD1: `|`, `&`, `$`, `` ` ``, `<`, `>`, `(`, `)`, `{`, `}`, `~`, `*`, `?`, `!`, `"`, `'`, space, `\t`, `\n`
- Use a loop or parameterized test pattern to avoid bloating the file.
- For file-path scripts, also test that `/` is rejected.
- For non-path scripts, test that `/` is accepted (it's valid in non-path contexts like `owner/repo`).
- Test that `\x01` (first control character), `\x1f` (last control character before DEL), and `\x7f` (DEL) are rejected as range boundaries.

**Patterns to follow:** Existing test pattern — run script with invalid input, check exit code and error message.

**Test scenarios:**
- Each metacharacter individually rejected with correct exit code
- Valid inputs without metacharacters accepted
- `/` rejected for file-path scripts, accepted for non-path scripts

**Verification:** All test suites pass with full metacharacter coverage.

---

### U6. Add path traversal and missing-value guard tests

Add tests for `foo/../bar` rejection, `foo..bar` acceptance, and missing-value argument guards.

**Goal:** Path traversal and argument edge cases are tested.

**Requirements:** R8, R9

**Note:** U6 and U8 overlap on path traversal tests for `detect-missing-artifacts.sh`. U8 fixes the underlying `..` over-rejection bug; U6 adds tests for the corrected behavior. Implement U8 first, then U6's `detect-missing-artifacts.sh` tests will pass against the fixed script.

**Files:**
- `tests/skills/ts-work/test-detect-missing-artifacts.sh`
- `tests/skills/ts-pr-fix-findings/test-check-thread-resolution.sh`
- `tests/skills/ts-pr-fix-findings/test-fetch-issue-comments.sh`

**Approach:**
- Path traversal: test that `foo/../bar` is rejected by scripts with `..` checks. Test that `foo..bar` (valid filename with `..` in the middle) is accepted.
- Missing-value guards: test that `--repo` with no value exits with error. Test that `--pr` with no value exits with error.

**Patterns to follow:** Existing test pattern.

**Test scenarios:**
- `foo/../bar` rejected with path traversal error
- `foo..bar` accepted (valid filename)
- `--repo` with missing value exits non-zero with JSON error
- `--pr` with missing value exits non-zero with JSON error

**Verification:** Tests pass for all edge cases.

---

### U7. Add regression test for prior hardening plan U6 bug fix

Add a test that verifies the specific bug fix from U6 of the prior hardening plan (`docs/plans/2026-07-02-003-fix-pr-work-script-hardening-plan.md`).

**Goal:** The original U6 fix doesn't regress.

**Requirements:** R10

**Files:**
- `tests/skills/ts-work/test-detect-missing-artifacts.sh`

**Approach:**
- Read U6 from `docs/plans/2026-07-02-003-fix-pr-work-script-hardening-plan.md` to identify the specific bug fix.
- Add a test case that reproduces the original bug scenario and verifies the fix.

**Patterns to follow:** Existing test pattern.

**Test scenarios:**
- Original bug scenario → correct behavior after fix

**Verification:** Regression test passes.

---

### U8. Fix detect-missing-artifacts.sh `..` over-rejection

The `*\"..\"*` pattern over-rejects valid filenames like `my.config.js`.

**Goal:** `..` check only rejects actual path traversal, not filenames containing `..`.

**Requirements:** R11

**Files:**
- `skills/ts-work/scripts/detect-missing-artifacts.sh`
- `tests/skills/ts-work/test-detect-missing-artifacts.sh`

**Approach:**
- Change the `..` check from `*\"..\"*` (glob match) to a more precise check that detects path traversal sequences (`/../`, `../` at start, `/..` at end) without rejecting valid filenames.
- Add test cases: `my.config.js` accepted, `foo/../bar` rejected, `../etc/passwd` rejected.

**Patterns to follow:** Existing metacharacter validation pattern — check specific dangerous patterns, not broad globs.

**Test scenarios:**
- `my.config.js` accepted (valid filename with `..` in extension)
- `foo/../bar` rejected (path traversal)
- `../etc/passwd` rejected (path traversal)
- `foo..bar` accepted (valid filename)

**Verification:** Tests pass, valid filenames not rejected.

---

### U9. Add find-precommit-hook.sh test

Validate `find-precommit-hook.sh` with a test.

**Goal:** `find-precommit-hook.sh` is covered by tests.

**Requirements:** R12

**Files:**
- `tests/skills/ts-work/test-find-precommit-hook.sh` (exists, 114 lines, 11 test cases)

**Approach:**
- Verify the existing test file adequately covers the script's functionality.
- If gaps remain, add tests for the uncovered scenarios.

**Patterns to follow:** Existing test pattern.

**Test scenarios:**
- Happy path: pre-commit hook found in expected location
- Edge case: no pre-commit hook exists
- Edge case: multiple hook directories

**Verification:** Test passes and covers the script's key behaviors.

---

### U10. Add `.git/` directory exclusion test

Test that `.git/` directories are excluded from processing.

**Goal:** `.git/` exclusion is verified by tests.

**Requirements:** R13

**Files:**
- `tests/skills/ts-work/test-detect-missing-artifacts.sh`

**Approach:**
- Add a test case that includes a `.git/` directory path and verifies it's excluded.

**Patterns to follow:** Existing test pattern.

**Test scenarios:**
- `.git/` directory path excluded from results
- `.git/config` file excluded from results

**Verification:** Test passes.

---

### U11. Complete prior hardening plan U9 documentation unit

Complete the U9 documentation unit from the prior hardening plan (`docs/plans/2026-07-02-003-fix-pr-work-script-hardening-plan.md`).

**Goal:** U9 documentation is complete and accurate.

**Requirements:** R14

**Files:**
- Relevant documentation files referenced by U9

**Approach:**
- Read U9 from `docs/plans/2026-07-02-003-fix-pr-work-script-hardening-plan.md` to understand what documentation was planned.
- Identify any documentation gaps that remain (the prior plan's U9 may have been partially completed).
- Complete the missing documentation.

**Verification:** Documentation is complete.

---

### U12. Complete prior hardening plan U10 test audit

Complete the U10 test audit from the prior hardening plan (`docs/plans/2026-07-02-003-fix-pr-work-script-hardening-plan.md`).

**Goal:** U10 test audit is complete and all gaps addressed.

**Requirements:** R15

**Files:**
- Test files referenced by U10

**Approach:**
- Read U10 from `docs/plans/2026-07-02-003-fix-pr-work-script-hardening-plan.md` to understand what test audit was planned.
- U12 depends on U5-U10 — only address gaps not already covered by those units.
- Audit test coverage and fill any remaining gaps.

**Verification:** Test audit complete, all gaps addressed.

## Scope Boundaries

**In scope:**
- All 10 mismatches from issue #79 (mismatch #1 — regex format inconsistency — is addressed by U2-U4 skill logic fixes; mismatches #2-#10 are addressed by R7-R15 and U5-U12)
- Plan-reading for all applicable skills
- KTD literal verification in ts-verify-implementation
- KTD inlining in ts-work
- Plan cross-reference in ts-pr-fix-findings

**Deferred to Follow-Up Work:**
- Shared plan-discovery utility/script (each skill currently reimplements discovery independently; a shared utility would reduce duplication, but is not required for correctness)

## Risks & Dependencies

- **Risk:** KTD literal comparison in subagents may be too strict — minor formatting differences (whitespace) could cause false positives. Mitigation: compare spec strings after normalizing whitespace. Quoting style differences (double-quoted vs ANSI-C) are intentional failures — different quoting has different escape semantics and should not be normalized.
- **Risk:** Plan discovery by branch name may match wrong plans if branch names are generic. Mitigation: fall through to user prompt on ambiguity.
- **Dependency:** Issue #79 is the primary driver. PR #80 tracks the implementation.
