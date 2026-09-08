#!/usr/bin/env bash
# Test: fleet --help conformance over the 26 compliance-fixed scripts (plan unit U3, Issue #118)
#
# Implements the documented U3 test scenario: the test-to-json.sh assertion
# pattern as a loop over the 26 scripts fixed by the fleet compliance batch.
# Per script, the suite asserts:
#   - the executable bit is set (R7; flagged addition — the scenario text
#     names --help conformance, the exec bit comes from the same R7 line)
#   - `--help` exits 0 — the early help check must answer before
#     required-argument validation rejects the invocation, so required-arg
#     scripts (wait-for-file.sh, fetch-pr-data.sh, ...) exiting 0 here is
#     exactly the assertion
#   - `--help` output contains "Usage"
#   - `--help` writes nothing to stderr (usage is the only output)
#   - running from a tmpdir cwd creates no files (no side effects)
#   - `-h` exits 0 with usage — all 26 handle `-h` by design (uniform
#     `--help | -h` early check, verified in source 2026-09-08)
#   - help documents exit codes — asserted only for the 23 scripts whose
#     help does document them
#
# Exit-code documentation is NOT asserted for the three session-history
# extract-*.py scripts: their only designed exit is 0 (help); failures
# surface as unhandled exceptions, so they have no meaningful distinct exit
# codes to document under the plan's "where the script has meaningful
# distinct ones" clause. Checked and reported to the dispatcher as an
# observation, not silently skipped.
#
# Expectation lists are encoded from a probe of actual help output
# (2026-09-08), per the verify-before-asserting convention.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

pass=0
fail=0
ok() { pass=$((pass + 1)); echo "  PASS: $1"; }
die() { fail=$((fail + 1)); echo "  FAIL: $1"; }

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

echo "=== test-fleet-help.sh ==="

# The 26 scripts fixed by the U3 fleet compliance batch (plan U3 Files list,
# encoded explicitly so the suite is stable as the fleet grows).
FLEET_SCRIPTS=(
  "scripts/detect-changed-code-files.sh"
  "scripts/detect-coverage-gaps.sh"
  "scripts/extract-ktds.py"
  "scripts/git-default-branch.sh"
  "scripts/load-dispatch-standards.sh"
  "scripts/locate-plan.py"
  "scripts/sync-taegosts-skills.sh"
  "scripts/verify-ktd-literal.py"
  "scripts/wait-for-file.sh"
  "scripts/request-reviews.sh"
  "scripts/index-scripts.py"
  "scripts/update-indexes.py"
  "skills/ts-compound/scripts/detect-overlap.py"
  "skills/ts-compound/scripts/session-history/discover-sessions.sh"
  "skills/ts-compound/scripts/validate-frontmatter.py"
  "skills/ts-code-review/scripts/select-reviewers.sh"
  "skills/ts-pr-fix-findings/scripts/fetch-review-comments.sh"
  "skills/ts-pr-fix-findings/scripts/post-pr-comment.sh"
  "skills/ts-pr-fix-findings/scripts/resolve-thread.sh"
  "skills/ts-pr-review/scripts/fetch-pr-data.sh"
  "skills/ts-verify-implementation/scripts/verify-coverage-threshold.sh"
  "skills/ts-compound-refresh/scripts/validate-doc-claims.py"
  "skills/ts-compound-refresh/scripts/validate-frontmatter.py"
  "skills/ts-compound/scripts/session-history/extract-errors.py"
  "skills/ts-compound/scripts/session-history/extract-metadata.py"
  "skills/ts-compound/scripts/session-history/extract-skeleton.py"
)

# Scripts whose --help output documents exit codes (probed reality). All 23
# have meaningful distinct exit codes (0/1, 0/1/2, or 0/2 splits) and
# document them. The three FLEET_SCRIPTS absent from this list get no such
# assertion — see the header comment.
EXIT_DOC_SCRIPTS=(
  "scripts/detect-changed-code-files.sh"
  "scripts/detect-coverage-gaps.sh"
  "scripts/extract-ktds.py"
  "scripts/git-default-branch.sh"
  "scripts/load-dispatch-standards.sh"
  "scripts/locate-plan.py"
  "scripts/sync-taegosts-skills.sh"
  "scripts/verify-ktd-literal.py"
  "scripts/wait-for-file.sh"
  "scripts/request-reviews.sh"
  "scripts/index-scripts.py"
  "scripts/update-indexes.py"
  "skills/ts-compound/scripts/detect-overlap.py"
  "skills/ts-compound/scripts/session-history/discover-sessions.sh"
  "skills/ts-compound/scripts/validate-frontmatter.py"
  "skills/ts-code-review/scripts/select-reviewers.sh"
  "skills/ts-pr-fix-findings/scripts/fetch-review-comments.sh"
  "skills/ts-pr-fix-findings/scripts/post-pr-comment.sh"
  "skills/ts-pr-fix-findings/scripts/resolve-thread.sh"
  "skills/ts-pr-review/scripts/fetch-pr-data.sh"
  "skills/ts-verify-implementation/scripts/verify-coverage-threshold.sh"
  "skills/ts-compound-refresh/scripts/validate-doc-claims.py"
  "skills/ts-compound-refresh/scripts/validate-frontmatter.py"
)

for rel in "${FLEET_SCRIPTS[@]}"; do
  script="$REPO_ROOT/$rel"
  name="$(basename "$rel")"
  workdir="$tmpdir/cwd-check"
  rm -rf "$workdir"
  mkdir -p "$workdir"
  errfile="$tmpdir/last-stderr"   # captured outside the watched cwd

  # R7: these are command-surface scripts, so the exec bit must be set.
  if [[ -x "$script" ]]; then
    ok "$name: executable"
  else
    die "$name: executable"
  fi

  # --help is answered before required-argument validation (rc=0 IS the
  # assertion); stdin is closed so stdin-reading scripts cannot hang.
  out=$(cd "$workdir" && "$script" --help </dev/null 2>"$errfile") && rc=0 || rc=$?
  if [[ $rc -eq 0 ]]; then
    ok "$name: --help exits 0"
  else
    die "$name: --help exits 0 (rc=$rc)"
  fi

  if grep -q "Usage" <<< "$out"; then
    ok "$name: --help prints usage"
  else
    die "$name: --help prints usage"
  fi

  if [[ ! -s "$errfile" ]]; then
    ok "$name: --help writes no stderr"
  else
    die "$name: --help writes no stderr"
  fi

  # Side effects: the tmpdir cwd must still be empty after the run.
  if [[ -z "$(ls -A "$workdir")" ]]; then
    ok "$name: --help creates no files in cwd"
  else
    die "$name: --help creates no files in cwd ($(ls -A "$workdir" | tr '\n' ' '))"
  fi

  # -h: every fleet script handles it by design (uniform --help|-h early
  # check, verified in source 2026-09-08).
  hout=$(cd "$workdir" && "$script" -h </dev/null 2>"$errfile") && hrc=0 || hrc=$?
  if [[ $hrc -eq 0 ]] && grep -q "Usage" <<< "$hout"; then
    ok "$name: -h exits 0 with usage"
  else
    die "$name: -h exits 0 with usage (rc=$hrc)"
  fi

  # Exit-code documentation, only where the script documents exit codes.
  if [[ " ${EXIT_DOC_SCRIPTS[*]} " == *" $rel "* ]]; then
    if grep -q "Exit codes" <<< "$out"; then
      ok "$name: --help documents exit codes"
    else
      die "$name: --help documents exit codes"
    fi
  fi
done

echo ""
echo "Results: $pass passed, $fail failed"
[[ $fail -eq 0 ]] && exit 0 || exit 1
