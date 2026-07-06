#!/usr/bin/env bash
# test-word-counts.sh -- Verify skill file word counts stay within budget.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

pass=0
fail=0
ok() { pass=$((pass + 1)); echo "  PASS: $1"; }
die() { fail=$((fail + 1)); echo "  FAIL: $1"; }

echo "=== test-word-counts.sh ==="

# R6: ts-plan/SKILL.md must be <= 9,000 words
count=$(wc -w < "$REPO_ROOT/skills/ts-plan/SKILL.md")
if [[ $count -le 9000 ]]; then
  ok "ts-plan/SKILL.md word count ($count) <= 9,000"
else
  die "ts-plan/SKILL.md word count ($count) exceeds 9,000 budget"
fi

echo ""
echo "Results: $pass passed, $fail failed"
[[ $fail -eq 0 ]] && exit 0 || exit 1
