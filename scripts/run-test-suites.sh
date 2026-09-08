#!/usr/bin/env bash
# run-test-suites.sh -- Run every bash test suite and bats file, aggregating failures
# Discovers tests/scripts/test-*.sh and tests/skills/*/test-*.sh (run via bash)
# plus tests/scripts/*.bats (run via bats). A failing suite does not abort the
# run: every discovered suite executes and the final summary aggregates results.
#
# Usage:
#   run-test-suites.sh              # run all discovered suites
#   run-test-suites.sh --help       # show this help
#
# Discovery (relative to the repo root containing this script):
#   tests/scripts/test-*.sh     each run via bash
#   tests/skills/*/test-*.sh    each run via bash (one directory level only)
#   tests/scripts/*.bats        each run via bats
#
# tests/baselines/ is never discovered: baseline artifacts are manual tooling
# that drifts by design and would report failures for non-behavioral reasons.
#
# If .bats files are discovered but bats is not installed, the run aborts with
# exit code 2 -- silently skipping them would report a false green.
#
# Output: one header line, per-suite output with a trailing PASS/FAIL line per
# suite, and a final "Results: N passed, M failed" summary.
# Exit codes: 0 (all discovered suites passed), 1 (one or more suites failed),
# 2 (bats not installed while .bats files were discovered)

set -euo pipefail

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  echo "Usage: run-test-suites.sh"
  echo ""
  echo "Run every bash test suite and bats file in the repository, aggregating"
  echo "failures: each discovered suite runs even if an earlier suite failed."
  echo ""
  echo "Discovery:"
  echo "  tests/scripts/test-*.sh     run via bash"
  echo "  tests/skills/*/test-*.sh    run via bash (one directory level only)"
  echo "  tests/scripts/*.bats        run via bats"
  echo ""
  echo "tests/baselines/ is never discovered (manual baseline tooling that"
  echo "drifts by design)."
  echo ""
  echo "Requires: bash; bats only when .bats files are discovered."
  echo ""
  echo "Exit codes: 0 (all suites passed), 1 (one or more suites failed),"
  echo "            2 (bats not installed while .bats files were discovered)"
  exit 0
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Discovery and per-suite reporting use repo-relative paths regardless of the
# caller's cwd.
cd "$REPO_ROOT"

shopt -s nullglob
bash_suites=(tests/scripts/test-*.sh tests/skills/*/test-*.sh)
bats_files=(tests/scripts/*.bats)
shopt -u nullglob

# tests/baselines/ is never discovered -- baseline artifacts drift by design.
# The globs above cannot match that directory; this filter keeps the exclusion
# true even if discovery changes later.
suites=()
for suite in "${bash_suites[@]}"; do
  [[ "$suite" == tests/baselines/* ]] && continue
  suites+=("$suite")
done

if [[ ${#bats_files[@]} -gt 0 ]] && ! command -v bats &>/dev/null; then
  {
    echo "ERROR: bats is not installed, but ${#bats_files[@]} .bats file(s) were discovered:"
    for bats_file in "${bats_files[@]}"; do
      echo "  $bats_file"
    done
    echo "Install bats (e.g. npm install -g bats@1.13.0). Skipping them would"
    echo "report a false green, so the run is aborted."
  } >&2
  exit 2
fi

total=$(( ${#suites[@]} + ${#bats_files[@]} ))
if [[ $total -eq 0 ]]; then
  echo "No test suites discovered under tests/."
  exit 0
fi

echo "=== run-test-suites.sh: ${#suites[@]} bash suite(s), ${#bats_files[@]} bats file(s) ==="

passed=0
failed=0

for suite in "${suites[@]}"; do
  echo "--- $suite"
  rc=0
  bash "$suite" || rc=$?
  if [[ $rc -eq 0 ]]; then
    echo "PASS: $suite"
    passed=$((passed + 1))
  else
    echo "FAIL: $suite (exit $rc)"
    failed=$((failed + 1))
  fi
done

for bats_file in "${bats_files[@]}"; do
  echo "--- $bats_file"
  rc=0
  bats "$bats_file" || rc=$?
  if [[ $rc -eq 0 ]]; then
    echo "PASS: $bats_file"
    passed=$((passed + 1))
  else
    echo "FAIL: $bats_file (exit $rc)"
    failed=$((failed + 1))
  fi
done

echo ""
echo "Results: $passed passed, $failed failed"
[[ $failed -eq 0 ]] && exit 0 || exit 1
