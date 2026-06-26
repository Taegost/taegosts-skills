#!/usr/bin/env bash
# Test: skills/ce-plan/scripts/generate-plan-filename.sh
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
SCRIPT="$REPO_ROOT/skills/ce-plan/scripts/generate-plan-filename.sh"

pass=0
fail=0
ok() { pass=$((pass + 1)); echo "  PASS: $1"; }
die() { fail=$((fail + 1)); echo "  FAIL: $1"; }

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

echo "=== test-generate-plan-filename.sh ==="

# Given: script exists
# When: run with --help
# Then: exits 0, shows usage
output=$("$SCRIPT" --help 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 0 ]] && echo "$output" | grep -q "Usage"; then
  ok "--help flag works"
else
  die "--help flag (rc=$rc)"
fi

# Run from temp dir (no docs/plans/ dir exists)
cd "$tmpdir"
today=$(date +%Y-%m-%d)

# Given: no existing plans for today
# When: generate a plan filename
# Then: sequence number is 001
output=$("$SCRIPT" --type feat --slug my-feature 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 0 ]]; then
  ok "exits 0 for valid inputs"
else
  die "exit code (rc=$rc)"
fi

expected="${today}-001-feat-my-feature-plan.md"
if [[ "$output" == "$expected" ]]; then
  ok "first plan filename is $expected"
else
  die "expected $expected, got $output"
fi

# Given: one existing plan for today
# When: generate another plan filename
# Then: sequence number is 002
mkdir -p docs/plans
touch "docs/plans/${today}-001-feat-existing.md"

output=$("$SCRIPT" --type fix --slug bug-fix 2>&1) && rc=0 || rc=$?
expected="${today}-002-fix-bug-fix-plan.md"
if [[ "$output" == "$expected" ]]; then
  ok "second plan filename is $expected"
else
  die "expected $expected, got $output"
fi

# Given: multiple existing plans for today
# When: generate another
# Then: increments correctly
touch "docs/plans/${today}-002-fix-another.md"
touch "docs/plans/${today}-005-chore-cleanup.md"

output=$("$SCRIPT" --type chore --slug refactoring 2>&1) && rc=0 || rc=$?
expected="${today}-006-chore-refactoring-plan.md"
if [[ "$output" == "$expected" ]]; then
  ok "increments past 005 to 006"
else
  die "expected $expected, got $output"
fi

# Given: invalid type
output=$("$SCRIPT" --type invalid --slug test 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 1 ]]; then
  ok "exits 1 for invalid type"
else
  die "expected exit 1 for invalid type (rc=$rc)"
fi

# Given: missing --slug
output=$("$SCRIPT" --type feat 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 1 ]]; then
  ok "exits 1 for missing --slug"
else
  die "expected exit 1 for missing --slug (rc=$rc)"
fi

# Given: missing --type
output=$("$SCRIPT" --slug test 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 1 ]]; then
  ok "exits 1 for missing --type"
else
  die "expected exit 1 for missing --type (rc=$rc)"
fi

# Given: slug with spaces
output=$("$SCRIPT" --type feat --slug "has spaces" 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 1 ]]; then
  ok "rejects slug with spaces"
else
  die "expected exit 1 for slug with spaces (rc=$rc)"
fi

echo ""
echo "Results: $pass passed, $fail failed"
[[ $fail -eq 0 ]] && exit 0 || exit 1
