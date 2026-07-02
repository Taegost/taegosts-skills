# PR #73 Remediation Plan — Fix Iteration 001

**PR:** fix: test suite hardening and stale directory cleanup
**Reviewers:** coderabbitai[bot], Taegost
**Date:** 2026-07-02

## Deduplicated Findings

Both reviewers flagged the same 7 issues. After deduplication:

| # | File | Issue | Severity |
|---|------|-------|----------|
| 1 | `scripts/run-shellcheck.sh:3` | `--fix` documented but not implemented | Minor |
| 2 | `scripts/run-shellcheck.sh:26-27` | `\|\| exit 1` inside `$(...)` only exits subshell | Moderate |
| 3 | `scripts/run-shellcheck.sh:52` | SC2295: unquoted `$REPO_ROOT` in `${...}` | Info |
| 4 | `tests/scripts/test-cleanup-traps.sh:5-6` | Same subshell `\|\| exit 1` issue as #2 | Moderate |
| 5 | `tests/scripts/test-verify-scripts.sh:65,73` | `rc` captured but never asserted | Info |
| 6 | `tests/scripts/test-default-branch.sh:39-59` | EXIT trap registered too late | Info |
| 7 | `tests/scripts/test-detect-diff-scope.sh:16-36` | Same trap timing gap as #6 | Info |

## Planned Remediations

### Finding 1 — `--fix` option (Minor)
**File:** `scripts/run-shellcheck.sh`
**Change:** Remove `--fix` from the usage/help text since it's not implemented.

### Finding 2 — Subshell exit guard (Moderate)
**File:** `scripts/run-shellcheck.sh`
**Change:** Replace `SCRIPT_DIR="$(cd ... && pwd)"` / `REPO_ROOT="$(cd ... && pwd)"` with a two-step pattern:
```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)" || { echo "ERROR: ..."; exit 1; }
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." 2>/dev/null && pwd)" || { echo "ERROR: ..."; exit 1; }
```
The `|| { ... }` is outside the command substitution, so it actually fails the outer shell.

### Finding 3 — SC2295 unquoted variable (Info)
**File:** `scripts/run-shellcheck.sh`
**Change:** Quote `$REPO_ROOT` inside the parameter expansion: `"${script#"$REPO_ROOT"/}"`

### Finding 4 — Same subshell issue (Moderate)
**File:** `tests/scripts/test-cleanup-traps.sh`
**Change:** Same pattern as Finding 2 — move the failure check outside `$(...)`.

### Finding 5 — Unused `rc` (Info)
**File:** `tests/scripts/test-verify-scripts.sh`
**Change:** Add `[[ $rc -eq 0 ]] &&` to the `--all` and dir-arg test assertions.

### Finding 6 — Trap timing gap (Info)
**File:** `tests/scripts/test-default-branch.sh`
**Change:** Register `trap 'rm -rf "$tmpdir"' EXIT` immediately after the first `mktemp -d`, then extend it after `tmpdir2` is created.

### Finding 7 — Trap timing gap (Info)
**File:** `tests/scripts/test-detect-diff-scope.sh`
**Change:** Same pattern as Finding 6 — register trap after first `mktemp -d`, extend after second.
