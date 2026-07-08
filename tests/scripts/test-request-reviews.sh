#!/usr/bin/env bash
# test-request-reviews.sh -- tests for request-reviews.sh
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/request-reviews.sh"

pass=0
fail=0
ok() { pass=$((pass + 1)); echo "  PASS: $1"; }
die() { fail=$((fail + 1)); echo "  FAIL: $1"; }

echo "=== test-request-reviews.sh ==="

# --help flag works
output=$("$SCRIPT" --help 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 0 ]] && echo "$output" | grep -q "Usage"; then
  ok "--help flag works"
else
  die "--help flag (rc=$rc)"
fi

# -h flag works
output=$("$SCRIPT" -h 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 0 ]] && echo "$output" | grep -q "Usage"; then
  ok "-h flag works"
else
  die "-h flag (rc=$rc)"
fi

# No arguments exits 1
output=$("$SCRIPT" 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 1 ]] && echo "$output" | grep -q "No PR URL"; then
  ok "no arguments exits 1"
else
  die "no arguments (rc=$rc, output=$output)"
fi

# No reviewers specified exits 1
output=$("$SCRIPT" 123 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 1 ]] && echo "$output" | grep -q "No reviewers"; then
  ok "no reviewers exits 1"
else
  die "no reviewers (rc=$rc, output=$output)"
fi

# Invalid PR URL/number rejected
output=$("$SCRIPT" "not-a-pr" alice 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 1 ]] && echo "$output" | grep -q "Could not extract PR number"; then
  ok "invalid PR URL rejected"
else
  die "invalid PR URL (rc=$rc, output=$output)"
fi

# Regression (Medium finding): reviewer with an invalid username format
# (e.g. containing whitespace, since REVIEWERS values are raw argv and not
# pre-validated by GitHub) must be rejected before reaching any gh api call.
output=$("$SCRIPT" 123 "alice bob" 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 1 ]] && echo "$output" | grep -q "Invalid reviewer username format"; then
  ok "reviewer with embedded space rejected"
else
  die "reviewer with embedded space (rc=$rc, output=$output)"
fi

# Regression: reviewer starting with a hyphen rejected
output=$("$SCRIPT" 123 -alice 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 1 ]] && echo "$output" | grep -q "Invalid reviewer username format\|No reviewers"; then
  ok "reviewer starting with hyphen rejected"
else
  die "reviewer starting with hyphen (rc=$rc, output=$output)"
fi

# Regression: reviewer ending with a hyphen rejected
output=$("$SCRIPT" 123 "alice-" 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 1 ]] && echo "$output" | grep -q "Invalid reviewer username format"; then
  ok "reviewer ending with hyphen rejected"
else
  die "reviewer ending with hyphen (rc=$rc, output=$output)"
fi

# Valid reviewer with hyphens passes validation (fails later on gh auth/API,
# which is expected without network access in this test environment)
output=$("$SCRIPT" 123 alice-bob 2>&1) && rc=0 || rc=$?
if ! echo "$output" | grep -q "Invalid reviewer username format"; then
  ok "valid reviewer with hyphens passes validation"
else
  die "valid reviewer with hyphens (rc=$rc, output=$output)"
fi

# Script is executable
if [[ -x "$SCRIPT" ]]; then
  ok "script is executable"
else
  die "script is not executable"
fi

# Script has bash shebang
if head -1 "$SCRIPT" | grep -q "^#!/usr/bin/env bash"; then
  ok "script has bash shebang"
else
  die "script missing bash shebang"
fi

# Script uses set -euo pipefail
if grep -q "set -euo pipefail" "$SCRIPT"; then
  ok "script uses set -euo pipefail"
else
  die "script missing set -euo pipefail"
fi

# Regression: reviewer args are built as an array, not a flattened/re-split
# string (the word-splitting bug fix) -- grep the source for the unquoted
# re-expansion pattern that caused it.
if ! grep -qE '\$REVIEWER_ARGS\b' "$SCRIPT"; then
  ok "reviewer args are passed as a quoted array, not re-expanded string"
else
  die "found unquoted \$REVIEWER_ARGS re-expansion (word-splitting risk)"
fi

echo ""
echo "Results: $pass passed, $fail failed"
[[ $fail -eq 0 ]] && exit 0 || exit 1
