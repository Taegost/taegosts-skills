---
title: "fix: PR/work script hardening"
type: fix
date: 2026-07-02
---

## Summary

Security and quality hardening for six scripts across four skill families: `ts-pr-fix-findings`, `ts-plan`, `ts-work`, and `ts-verify-implementation`. Covers input validation, path traversal prevention, missing-value guards, shebang consistency, path resolution correctness, and cross-cutting standardization of metacharacter validation and error output format.

## Problem Frame

CodeRabbit review of PR #20 identified security and quality findings across several helper scripts. The findings range from command injection risk (unvalidated `--repo`/`--pr` inputs) to path traversal (slug validation allowing `/`), inconsistent error handling, and a correctness bug where `scripts[0]` returns a bare basename instead of a resolvable path. Additionally, the scripts use four distinct metacharacter character classes across two different matching mechanisms (grep and bash regex), plus one script with no metacharacter validation, and a mix of plain-text and JSON error output — creating maintenance friction and inconsistent caller contracts.

## Requirements

**Input Validation & Security**

- R1. `fetch-issue-comments.sh` validates `--repo` matches `owner/repo` format (exactly one `/`, alphanumeric segments) and `--pr` is numeric.
- R2. `check-thread-resolution.sh` validates `--repo` and `--pr` with the same pattern as R1.
- R3. `generate-plan-filename.sh` slug validation blocks `/` and `..` to prevent path traversal.
- R4. `detect-missing-artifacts.sh` guards against missing option values before reading `$2` in the argument parser.

**Correctness & Consistency**

- R5. `find-precommit-hook.sh` returns the full resolved path for `scripts[0]` instead of its basename.
- R6. `detect-file-status.sh` and `find-precommit-hook.sh` use `set -euo pipefail` (adding `-e`) consistent with sibling scripts.

**Cross-Cutting Quality**

- R7. All scripts with metacharacter validation use a single standardized regex pattern. `find-precommit-hook.sh` has no metacharacter validation and is excluded.
- R8. `check-thread-resolution.sh` and `fetch-issue-comments.sh` emit structured JSON errors to stderr, matching the pattern used by newer scripts.
- R9. `check-thread-resolution.sh` and `fetch-issue-comments.sh` reject unknown arguments with a JSON error instead of silently ignoring them.
- R10. Test suites for `check-thread-resolution.sh` and `fetch-issue-comments.sh` are expanded to cover input validation, metacharacter rejection, and error paths.

**Safe Execution & Credential Handling**

- R11. All validated user inputs must be consumed via double-quoted variable expansion or passed as separate command arguments — never interpolated into eval, heredoc, or unquoted shell contexts.
- R12. GitHub API credentials are handled externally (via `gh` CLI) and are out of scope for this repository. The new JSON error output format must not echo API responses or token fragments.

**Documentation & Test Coverage**

- R13. Repository documentation is expanded with shell script standards (shebang flags, metacharacter validation, error output format, safe execution context per R11, credential handling per R12) to ensure future scripts follow the same patterns.
- R14. Test plans are extended to cover all new failure modes introduced by this hardening (missing option values, path traversal slugs, malformed repo/PR inputs, unknown arguments, JSON error validation).

## Key Technical Decisions

**KTD1. Standardized metacharacter regex: two variants for two input domains.**

The five scripts with validation currently use four different character classes across two matching mechanisms. Define two regex variants:

- **Non-path inputs** (repo names, slugs): `[\;\|\&\$\`\"\'\/\ \<\>\(\)\{\}\~\ $'\n\t']` — blocks shell metacharacters, path traversal, redirect operators, subshell syntax, brace expansion, and whitespace control characters. Used by `check-thread-resolution.sh`, `fetch-issue-comments.sh`, and `generate-plan-filename.sh`. Note: `\n` and `\t` require ANSI-C quoting (`$'\n\t'`) since bash `[[ =~ ]]` does not interpret backslash escapes.
- **File-path inputs** (`detect-missing-artifacts.sh`, `detect-file-status.sh`): `[\;\|\&\$\`\"\'\<\>\(\)\{\}\~\ $'\n\t']` — same as above but excludes `/` since paths legitimately contain it.

The `..` sequence is additionally blocked in `generate-plan-filename.sh`'s slug validation since the regex alone doesn't catch it. `find-precommit-hook.sh` has no metacharacter validation and is excluded.

**KTD2. JSON error output to stderr for all scripts.**

Newer scripts (`generate-plan-filename.sh`, `detect-missing-artifacts.sh`, `detect-file-status.sh`, `find-precommit-hook.sh`) already use `{"error":"..."}` to stderr. Normalize the two `ts-pr-fix-findings` scripts to the same pattern. Stderr keeps errors separate from stdout data; JSON makes errors machine-parseable. Error messages must use static strings or sanitize interpolated values (escape quotes, strip control characters) before embedding in JSON output. API responses and token fragments must never appear in error messages.

**KTD3. Strict unknown-argument rejection.**

Change `*) shift` (silent ignore) to `*) echo '{"error":"unknown argument"}' >&2; exit 1` in `check-thread-resolution.sh` and `fetch-issue-comments.sh`. Matches the pattern in `generate-plan-filename.sh` and `detect-missing-artifacts.sh`. Silent ignore masks caller bugs.

**KTD4. Add `-e` flag with explicit error handling verification.**

Both `detect-file-status.sh` and `find-precommit-hook.sh` already use `|| { ... }` patterns for expected non-zero exits. Adding `-e` is a safety net for future edits; existing guard patterns ensure no behavior change.

## Implementation Units

### U1. Standardize metacharacter regex across all scripts

**Goal:** Unify the metacharacter validation regex to two consistent patterns — one for non-path inputs, one for file-path inputs.

**Requirements:** R7

**Dependencies:** None

**Files:**
- `skills/ts-pr-fix-findings/scripts/check-thread-resolution.sh`
- `skills/ts-pr-fix-findings/scripts/fetch-issue-comments.sh`
- `skills/ts-plan/scripts/generate-plan-filename.sh`
- `skills/ts-work/scripts/detect-missing-artifacts.sh`
- `skills/ts-verify-implementation/scripts/detect-file-status.sh`

**Approach:** Update each script's metacharacter check per KTD1's two-variant approach. Non-path scripts get the full set including `/`; file-path scripts exclude `/`. For `generate-plan-filename.sh`, add a separate `..` check (the regex catches `/` but not the `..` sequence). Leave `find-precommit-hook.sh` unchanged — it has no metacharacter validation and is excluded.

**Patterns to follow:** The existing validation in `detect-missing-artifacts.sh` (JSON error to stderr, exit 1) is the reference pattern for the error response.

**Test scenarios:**
- Happy path: each script accepts clean alphanumeric input with hyphens.
- Edge case: each script rejects input containing each metacharacter in the standardized set (`;`, `|`, `&`, `$`, backtick, `"`, `'`, `<`, `>`, `(`, `)`, `{`, `}`, `~`, space, newline, tab).
- Edge case: file-path scripts accept input containing `/`.
- Edge case: non-path scripts reject input containing `/`.
- Edge case: `generate-plan-filename.sh` rejects slugs containing `..`.
- Error path: rejection produces valid JSON to stderr with exit code 1.

**Verification:** Each script rejects the appropriate set of metacharacters and produces JSON error output. File-path scripts accept `/`; non-path scripts reject it.

### U2. Harden input validation in ts-pr-fix-findings scripts

**Goal:** Add `owner/repo` format validation and numeric `--pr` check to both `check-thread-resolution.sh` and `fetch-issue-comments.sh`.

**Requirements:** R1, R2, R4

**Dependencies:** U1 (regex standardization happens first)

**Files:**
- `skills/ts-pr-fix-findings/scripts/check-thread-resolution.sh`
- `skills/ts-pr-fix-findings/scripts/fetch-issue-comments.sh`

**Approach:** After the metacharacter check, add validation that `$repo` matches `^[a-zA-Z0-9._-]+/[a-zA-Z0-9._-]+$` (owner/repo with exactly one `/`) and `$pr_number` matches `^[0-9]+$`. Use JSON error output on failure. Also add a `$# -ge 2` guard before assigning `$2` in the argument parser (same pattern as U5) to prevent unbound-variable crashes when `--repo` or `--pr` is the last argument with no value.

**Test scenarios:**
- Happy path: valid `owner/repo` and numeric PR number pass validation.
- Edge case: repo with no `/` is rejected.
- Edge case: repo with multiple `/` is rejected (e.g., `owner/repo/extra`).
- Edge case: PR number with non-numeric characters is rejected (e.g., `abc`, `12a`).
- Error path: `--repo` with no value produces JSON error and exit 1.
- Error path: `--pr` with no value produces JSON error and exit 1.
- Error path: invalid repo produces JSON error to stderr with exit 1.
- Error path: invalid PR number produces JSON error to stderr with exit 1.

**Verification:** Both scripts reject malformed `--repo` and non-numeric `--pr` values with structured JSON errors.

### U3. Normalize error output and unknown-arg handling in ts-pr-fix-findings scripts

**Goal:** Switch `check-thread-resolution.sh` and `fetch-issue-comments.sh` from plain-text errors to JSON, and reject unknown arguments instead of silently ignoring them.

**Requirements:** R8, R9

**Dependencies:** U2 (validation changes are in the same files)

**Files:**
- `skills/ts-pr-fix-findings/scripts/check-thread-resolution.sh`
- `skills/ts-pr-fix-findings/scripts/fetch-issue-comments.sh`

**Approach:** Replace all `echo "..." >&2; exit 1` patterns with `echo '{"error":"..."}' >&2; exit 1`. Change `*) shift` to `*) echo '{"error":"unknown argument"}' >&2; exit 1`. Error messages must use static strings or sanitize interpolated values per KTD2. This matches the pattern in `generate-plan-filename.sh` and `detect-missing-artifacts.sh`.

**Test scenarios:**
- Happy path: valid arguments produce successful output (no behavior change).
- Error path: missing required arguments produces JSON error to stderr.
- Error path: unknown argument (e.g., `--bogus`) produces JSON error to stderr with exit 1.
- Error path: all error output is valid JSON (validate with `python3 -m json.tool`).

**Verification:** All error paths in both scripts produce valid JSON to stderr; unknown arguments are rejected.

### U4. Block path traversal in generate-plan-filename.sh slug validation

**Goal:** Prevent slugs containing `/` or `..` from producing path-traversal filenames.

**Requirements:** R3

**Dependencies:** U1 (regex standardization adds `/` blocking)

**Files:**
- `skills/ts-plan/scripts/generate-plan-filename.sh`
- `tests/skills/ts-plan/test-generate-plan-filename.sh`

**Approach:** The standardized regex from U1 already blocks `/`. Add an explicit `..` check before the regex (since `..` doesn't contain metacharacters but is a traversal vector). Update error message to mention `..`.

**Patterns to follow:** The existing JSON error pattern in this script.

**Test scenarios:**
- Edge case: slug `../../etc/passwd` is rejected.
- Edge case: slug `foo/../bar` is rejected.
- Edge case: slug `foo..bar` (not a traversal sequence) is accepted.
- Error path: rejection produces JSON error to stderr with exit 1.

**Verification:** Slugs containing `..` as a path segment are rejected; normal slugs with consecutive dots in non-traversal contexts pass.

### U5. Guard missing option values in detect-missing-artifacts.sh

**Goal:** Prevent unbound-variable crash when `--plan-files` or `--reference-dir` is the last argument with no value.

**Requirements:** R4

**Dependencies:** None

**Files:**
- `skills/ts-work/scripts/detect-missing-artifacts.sh`
- `tests/skills/ts-work/test-detect-missing-artifacts.sh`

**Approach:** In the `while`/`case` block, check `$# -ge 2` before assigning `$2` to `plan_files` or `reference_dir`. If the value is missing, emit a JSON error to stderr and exit 1.

**Patterns to follow:** The existing JSON error pattern in this script (`{"error":"..."}` to stderr).

**Test scenarios:**
- Error path: `--plan-files` with no value produces JSON error and exit 1.
- Error path: `--reference-dir` with no value produces JSON error and exit 1.
- Happy path: `--plan-files` and `--reference-dir` with valid values work unchanged.

**Verification:** Invoking with `--plan-files` or `--reference-dir` as the last argument produces a structured JSON error instead of a bash unbound-variable crash.

### U6. Fix scripts[0] path resolution in find-precommit-hook.sh

**Goal:** Return the full resolved path for `scripts[0]` instead of its basename.

**Requirements:** R5

**Dependencies:** None

**Files:**
- `skills/ts-work/scripts/find-precommit-hook.sh`
- `tests/skills/ts-work/test-find-precommit-hook.sh`

**Approach:** Change `scripts=("$(basename "$hook_path")")` to `scripts=("$hook_path")`. The variable `$hook_path` is already the full resolved path at this point (set by the candidate loop with symlink resolution).

**Test scenarios:**
- Happy path: `scripts[0]` in JSON output is an absolute path to the hook file.
- Happy path: `scripts[0]` is resolvable (file exists at that path).
- Integration: downstream consumers that read `scripts[0]` can open the file.

**Verification:** `scripts[0]` in the JSON output starts with `/` and points to an existing file.

### U7. Add -e shebang flag to detect-file-status.sh and find-precommit-hook.sh

**Goal:** Consistent `set -euo pipefail` in both scripts.

**Requirements:** R6

**Dependencies:** None

**Files:**
- `skills/ts-verify-implementation/scripts/detect-file-status.sh`
- `skills/ts-work/scripts/find-precommit-hook.sh`

**Approach:** Change `set -uo pipefail` to `set -euo pipefail` in both scripts. Verify all command paths with explicit `||` handling still behave correctly under `-e`. Both scripts already guard expected non-zero exits (e.g., `git ls-files --error-unmatch ... || ...`, `git rev-parse ... || ...`).

**Test scenarios:**
- Happy path: existing test suites pass unchanged for both scripts.
- Edge case: script behavior is identical before and after the change (no new early exits).

**Verification:** All existing tests pass; no behavior change.

### U8. Expand test suites for ts-pr-fix-findings scripts

**Goal:** Bring `check-thread-resolution.sh` and `fetch-issue-comments.sh` test coverage to the comprehensive standard of newer test files.

**Requirements:** R10

**Dependencies:** U2, U3 (validation and error format changes must land first)

**Files:**
- `tests/skills/ts-pr-fix-findings/test-check-thread-resolution.sh`
- `tests/skills/ts-pr-fix-findings/test-fetch-issue-comments.sh`

**Approach:** Add `ok()`/`die()` helpers, `tmpdir` with cleanup trap, and test cases for: metacharacter rejection (each character in the standardized set), invalid repo format (no slash, multiple slashes), non-numeric PR, unknown arguments, JSON error output validation. Follow the pattern in `tests/skills/ts-work/test-detect-missing-artifacts.sh`.

**Patterns to follow:** `tests/skills/ts-work/test-detect-missing-artifacts.sh` for helpers, tmpdir setup, and JSON validation approach.

**Test scenarios:**
- Each new test case validates the specific fix from U2 and U3.
- JSON error output is validated with `python3 -c "import json, sys; json.load(sys.stdin)"`.
- Test count increases from 2 to 8+ per file.

**Verification:** Both test files have comprehensive coverage matching the standard of newer test suites; all tests pass.

### U9. Document shell script standards in repository documentation

**Goal:** Codify the shell script standards established by this hardening effort so future scripts follow the same patterns.

**Requirements:** R13

**Dependencies:** U1, U2, U3 (standards must be finalized before documenting)

**Files:**
- Repository documentation file (location to be determined — likely `docs/` or `CONTRIBUTING.md`)

**Approach:** Document the following standards: (1) `set -euo pipefail` as the required shebang flag set, (2) the two-variant metacharacter regex approach and when to use each, (3) JSON error output format to stderr with static or sanitized strings, (4) strict unknown-argument rejection, (5) safe execution context (double-quoted expansion for all validated inputs), (6) GitHub credential handling (external, never echoed in error output). Reference existing scripts as examples.

**Test scenarios:**
- Test expectation: none — documentation-only unit.

**Verification:** Documentation exists and covers all six standards with examples.

### U10. Extend test plans to cover all new failure modes

**Goal:** Ensure every new validation, guard, and error path introduced by this hardening effort has corresponding test coverage.

**Requirements:** R14

**Dependencies:** U1 through U8 (all implementation units must be defined first)

**Files:**
- `tests/skills/ts-pr-fix-findings/test-check-thread-resolution.sh`
- `tests/skills/ts-pr-fix-findings/test-fetch-issue-comments.sh`
- `tests/skills/ts-plan/test-generate-plan-filename.sh`
- `tests/skills/ts-work/test-detect-missing-artifacts.sh`
- `tests/skills/ts-work/test-find-precommit-hook.sh`
- `tests/skills/ts-verify-implementation/test-detect-file-status.sh`

**Approach:** Audit each implementation unit's test scenarios against the actual failure modes introduced. For any gap, add test cases. Specific coverage to verify: (1) metacharacter rejection for every character in the expanded blocklist, (2) file-path scripts accept `/`, non-path scripts reject it, (3) `..` traversal slugs rejected, (4) missing option values produce JSON errors, (5) malformed `--repo` and `--pr` inputs rejected, (6) unknown arguments rejected, (7) `scripts[0]` returns full paths, (8) `-e` flag doesn't cause new early exits, (9) JSON error output is valid JSON on all error paths.

**Test scenarios:**
- Each failure mode from U1-U8 has at least one dedicated test case.
- All tests pass after implementation.

**Verification:** Every new failure mode has test coverage; all test suites pass.

## Scope Boundaries

**In scope:** The six issues listed in #69 plus cross-cutting regex, error format, test standardization, repository documentation of standards, and test coverage for all new failure modes.

**Deferred to Follow-Up Work:**
- Metacharacter regex standardization in `find-precommit-hook.sh` is excluded per R7 — it has no validation and none is planned.

## Verification

- All scripts in scope use `set -euo pipefail`.
- All scripts with metacharacter validation use the two-variant regex (non-path inputs include `/`; file-path inputs exclude `/`).
- All error output across all scripts is valid JSON to stderr with static or sanitized error messages.
- `--repo` is validated as `owner/repo`; `--pr` is validated as numeric.
- `generate-plan-filename.sh` rejects slugs with `/` or `..`.
- `detect-missing-artifacts.sh` handles missing option values gracefully.
- `find-precommit-hook.sh` returns full paths in `scripts[0]`.
- All validated inputs are consumed via double-quoted expansion (R11).
- GitHub API credentials are not echoed in error output (R12).
- Test suites for `check-thread-resolution.sh` and `fetch-issue-comments.sh` have 8+ test cases each.
- Shell script standards are documented in repository documentation (R13).
- Every new failure mode has corresponding test coverage (R14).
- All existing and new tests pass.
