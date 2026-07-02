---
title: "fix: Test suite hardening and stale directory cleanup"
type: fix
date: 2026-07-02
---

## Summary

Fix shell test defects across the test suite: unguarded `cd` calls, missing exit-code assertions on error paths, and broken cleanup traps. Also remove stale `ce-` prefixed and other pre-rename skill and test directories left over from the `ts-` prefix rename.

## Problem Frame

The test suite has a recurring pattern of shell safety defects introduced during initial script authoring. These defects don't cause test failures today (the scripts being tested behave correctly), but they make the tests themselves fragile — a `cd` failure would silently run tests in the wrong directory, a masked exit code would let a broken implementation pass, and a broken cleanup trap leaks temp directories.

## Requirements

- R1. All `cd` calls in test scripts are guarded so a failure terminates the test immediately instead of continuing from the wrong directory.
- R2. Missing-argument test cases assert that the script under test exits with a non-zero status, not just that the output contains an error keyword.
- R3. Cleanup traps remove the actual `mktemp -d` directory, not a glob that doesn't match it, and are present in every test script that creates temp directories.
- R4. Shellcheck or equivalent static analysis is integrated into the test workflow to catch unguarded `cd` calls, missing `set -e`, and other shell safety issues automatically.
- R5. Cleanup trap behavior is verified by automated tests that confirm temp directories are removed on exit.

## Implementation Principle

- All fixes follow the existing patterns already established in well-structured test files in the codebase.

## Key Technical Decisions

- **KTD-1: Remove stale pre-rename copies instead of fixing them.** The pre-rename skill and test directories (including `ce-` prefixed and unprefixed copies) are dead copies from before the `ts-` prefix rename. They reference old paths and serve no purpose. Removing them eliminates an entire class of duplicated defects.
- **KTD-2: Integrate shellcheck into the test workflow.** To prevent recurrence of shell safety defects (unguarded `cd` calls, missing traps, etc.), shellcheck or equivalent static analysis is required as part of the test validation pipeline.

## Implementation Units

### U1. Guard `cd` calls against failure

**Goal:** Add `|| exit 1` to all bare `cd` calls so failures terminate the test immediately.

**Requirements:** R1

**Files:**
- `tests/skills/ts-plan/test-generate-plan-filename.sh` (line 30)
- `tests/skills/ts-work/test-find-precommit-hook.sh` (lines 31, 81)

**Approach:** Append `|| exit 1` to each bare `cd` call. No other changes needed — the scripts already use `set -uo pipefail` and have correct cleanup traps.

**Test scenarios:**
- Happy path: run each test script and confirm all existing tests still pass.
- Verification: `grep -n 'cd ' <file>` confirms no unguarded `cd` calls remain.

**Verification:** Each test script passes when run against the current codebase. No bare `cd` calls remain in the modified files.

### U2. Assert non-zero exit status on missing-argument tests

**Goal:** Verify that scripts under test exit with status 1 when called without required arguments, not just that the output contains an error keyword.

**Requirements:** R2

**Files:**
- `tests/skills/ts-pr-fix-findings/test-fetch-issue-comments.sh` (lines 14-16)
- `tests/skills/ts-pr-fix-findings/test-check-thread-resolution.sh` (lines 14-16)

**Approach:** Replace the `output=$("$SCRIPT" 2>&1 || true)` pattern with exit-code capture and assertion. Follow the pattern from `tests/skills/ts-work/test-detect-missing-artifacts.sh` (lines 106-112):

Capture the exit code with `output=$("$SCRIPT" 2>&1) && rc=0 || rc=$?`, then assert `$rc -eq 1`. Use the file's existing inline `pass`/`fail` counter style.

**Test scenarios:**
- Happy path: run each test script and confirm all existing tests still pass.
- Negative verification: temporarily break the script under test (e.g., remove its `exit 1`) and confirm the test now fails on the exit-code assertion.

**Verification:** Each test script passes. The exit-code assertion is present and checks for non-zero status.

### U3. Fix broken cleanup traps

**Goal:** Replace glob-based cleanup functions that don't match the actual temp directory with direct `trap 'rm -rf "$tmpdir"' EXIT`.

**Requirements:** R3

**Files:**
- `tests/skills/ts-plan/test-scan-repo-structure.sh` (lines 7-8, 20)
- `tests/scripts/test-validate-findings-json.sh` (lines 8-9, 19)

**Approach:** Remove the `cleanup()` function and its trap in each file. Move `tmpdir=$(mktemp -d)` to after the `pass=0 fail=0` line, then add `trap 'rm -rf "$tmpdir"' EXIT` immediately after. Follow the pattern from `tests/skills/ts-work/test-detect-missing-artifacts.sh` (lines 14-15).

**Test scenarios:**
- Happy path: run the test script and confirm all tests pass.
- Cleanup verification: run the test, note the `$tmpdir` path, and confirm it is removed after the test exits.

**Verification:** The test script passes. The temp directory created by `mktemp -d` is removed on exit.

### U4. Guard `cd` in ts-verify-implementation test

**Goal:** Add `|| exit 1` to the bare `cd` call in the ts-verify-implementation test file.

**Requirements:** R1

**Files:**
- `tests/skills/ts-verify-implementation/test-detect-file-status.sh` (line 30)

**Approach:** Append `|| exit 1` to the bare `cd "$tmpdir"` call. Same pattern as U1.

**Test scenarios:**
- Happy path: run the test script and confirm all existing tests still pass.
- Verification: `grep -n 'cd ' <file>` confirms no unguarded `cd` calls remain.

**Verification:** The test script passes. No bare `cd` calls remain.

### U5. Guard `cd` and fix cleanup in test-detect-diff-scope

**Goal:** Fix unguarded `cd` calls and the broken cleanup glob in the diff-scope test.

**Requirements:** R1, R3

**Files:**
- `tests/scripts/test-detect-diff-scope.sh` (lines 8, 20, 38)

**Approach:**
- Line 8: Replace the glob-based `cleanup()` function with `trap 'rm -rf "$tmpdir" "$tmpdir2"' EXIT` after both temp dirs are created.
- Lines 20, 38: Append `|| exit 1` to both bare `cd` calls.

**Test scenarios:**
- Happy path: run the test script and confirm all tests pass.
- Cleanup verification: confirm both temp directories are removed after the test exits.

**Verification:** The test script passes. No bare `cd` calls remain. Both temp directories are cleaned up on exit.

### U6. Guard `cd` and add cleanup traps in test-default-branch and test-git-context

**Goal:** Fix unguarded `cd` calls and add missing cleanup traps in `test-default-branch.sh` and `test-git-context.sh`.

**Requirements:** R1, R3

**Files:**
- `tests/scripts/test-default-branch.sh` (lines 40, 58 — unguarded `cd`; lines 39, 57 — `mktemp -d` with no trap)
- `tests/scripts/test-git-context.sh` (line 74 — unguarded `cd`; line 73 — `mktemp -d` with no trap)

**Approach:**
- Append `|| exit 1` to each bare `cd` call.
- Add `trap 'rm -rf "$tmpdir" "$tmpdir2"' EXIT` after both temp dirs are created in `test-default-branch.sh`.
- Add `trap 'rm -rf "$tmpdir"' EXIT` after the temp dir is created in `test-git-context.sh`.
- Follow the pattern from `tests/skills/ts-work/test-detect-missing-artifacts.sh` (lines 14-15).

**Test scenarios:**
- Happy path: run each test script and confirm all existing tests still pass.
- Cleanup verification: confirm temp directories are removed after each test exits.

**Verification:** Each test script passes. No bare `cd` calls remain. Temp directories are cleaned up on exit.

### U7. Fix stale references in skill routing table

**Goal:** Update `skills/script-index/SKILL.md` to replace all `ce-*` and unprefixed skill names with their `ts-*` equivalents.

**Requirements:** R3

**Files:**
- `skills/script-index/SKILL.md` (lines 34, 36, 37, 39, 43)

**Approach:** Replace `ce-plan` → `ts-plan`, `ce-doc-review` → `ts-doc-review`, `ce-debug` → `ts-debug`, `ce-compound` → `ts-compound`, `pr-fix-findings` → `ts-pr-fix-findings` in the routing table. Follow the word-boundary sed pattern from `docs/solutions/conventions/skill-namespace-prefix-convention.md`.

**Test scenarios:**
- Verification: `grep -n 'ce-\|pr-fix-findings\|verify-implementation' skills/script-index/SKILL.md` returns no stale references.

**Verification:** The routing table references only `ts-*` prefixed skill names.

### U8. Run shellcheck on all test scripts and fix findings

**Goal:** Run shellcheck against all test scripts and fix any issues it identifies beyond what U1-U6 already cover.

**Requirements:** R4

**Files:**
- All `tests/**/*.sh` files

**Approach:** Install shellcheck if not present, run `shellcheck tests/**/*.sh`, and fix all findings. Prioritize issues that overlap with U1-U6 (unguarded `cd`, missing traps) since those units already address them. Focus this unit on any additional issues shellcheck surfaces (e.g., missing quoting, unused variables, deprecated syntax).

**Test scenarios:**
- Run `shellcheck tests/**/*.sh` and confirm zero findings after fixes.
- Run each test script individually and confirm all existing tests still pass.

**Verification:** `shellcheck tests/**/*.sh` returns clean. All test scripts pass.

### U9. Add cleanup trap verification tests

**Goal:** Add automated tests that verify cleanup traps actually remove temp directories on exit.

**Requirements:** R5

**Files:**
- `tests/scripts/test-cleanup-traps.sh` (new file)

**Approach:** Create a test script that sources or runs each test script that creates temp directories, captures the `$tmpdir` path, and asserts it no longer exists after the script exits. Use the existing `pass`/`fail` counter pattern from other test files.

**Test scenarios:**
- Run the cleanup trap test and confirm all assertions pass (temp directories are removed).
- Negative verification: temporarily remove a `trap` statement from a test script and confirm the cleanup test now fails.

**Verification:** The cleanup trap test passes. All test scripts that create temp directories are covered.

### U10. Remove stale pre-rename directories

**Goal:** Delete all pre-rename skill and test directories (including `ce-` prefixed and unprefixed copies) that have `ts-` prefixed canonical copies.

**Requirements:** R3

**Files:**
- `skills/pr-fix-findings/` (directory)
- `skills/verify-implementation/` (directory)
- `tests/skills/pr-fix-findings/` (directory)
- `tests/skills/verify-implementation/` (directory)
- `skills/ce-code-review/` (directory)
- `skills/ce-doc-review/` (directory)
- `skills/ce-plan/` (directory)
- `skills/ce-work/` (directory)
- `tests/skills/ce-code-review/` (directory)
- `tests/skills/ce-compound/` (directory)
- `tests/skills/ce-doc-review/` (directory)
- `tests/skills/ce-plan/` (directory)
- `tests/skills/ce-work/` (directory)

**Approach:** `rm -rf` each directory. These are dead copies from before the rename. Note: the test files in `tests/skills/pr-fix-findings/` and `tests/skills/verify-implementation/` reference old (non-`ts-`) script paths and were already non-functional — they should be deleted alongside the skill directories, not fixed.

**Verification:** The directories no longer exist.
