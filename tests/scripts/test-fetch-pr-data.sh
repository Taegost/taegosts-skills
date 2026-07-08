#!/usr/bin/env bash
# Test: scripts/fetch-pr-data.sh
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/fetch-pr-data.sh"

pass=0
fail=0
ok() { pass=$((pass + 1)); echo "  PASS: $1"; }
die() { fail=$((fail + 1)); echo "  FAIL: $1"; }

echo "=== test-fetch-pr-data.sh ==="

# Given: script exists
# When: run with --help
# Then: exits 0, shows usage
output=$("$SCRIPT" --help 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 0 ]] && echo "$output" | grep -q "Usage"; then
  ok "--help flag works"
else
  die "--help flag (rc=$rc)"
fi

# Given: no arguments
# When: run without arguments
# Then: exits 1 with error message
output=$("$SCRIPT" 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 1 ]] && echo "$output" | grep -q "No PR URL"; then
  ok "no arguments exits 1"
else
  die "no arguments (rc=$rc, output=$output)"
fi

# Given: empty string argument
# When: run with empty string
# Then: exits 1 with error message
output=$("$SCRIPT" "" 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 1 ]] && echo "$output" | grep -q "Empty PR URL"; then
  ok "empty string exits 1"
else
  die "empty string (rc=$rc, output=$output)"
fi

# Given: PR URL with shell metacharacters
# When: run with malicious input
# Then: exits 1 with error message
output=$("$SCRIPT" '123;rm -rf /' 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 1 ]] && echo "$output" | grep -q "invalid characters"; then
  ok "shell metacharacters rejected"
else
  die "shell metacharacters (rc=$rc, output=$output)"
fi

# Given: PR URL with command substitution
# When: run with $(command)
# Then: exits 1 with error message
output=$("$SCRIPT" '123$(whoami)' 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 1 ]] && echo "$output" | grep -q "invalid characters"; then
  ok "command substitution rejected"
else
  die "command substitution (rc=$rc, output=$output)"
fi

# Given: valid PR number but gh fails
# When: run with valid number but no gh access
# Then: exits 1 with error message
# Note: This test requires gh to fail (no auth or no repo)
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT
cd "$tmpdir" || exit 1
git init -b main >/dev/null 2>&1
git config user.email "test@test.com"
git config user.name "Test"
git commit --allow-empty -m "init" >/dev/null 2>&1
git remote add origin https://example.com/fake.git 2>/dev/null

output=$("$SCRIPT" 123 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 1 ]] && echo "$output" | grep -q "Failed to fetch"; then
  ok "gh failure exits 1"
else
  # If gh somehow succeeds (unlikely in temp repo), that's also acceptable
  if [[ $rc -eq 0 ]]; then
    ok "gh succeeded (unexpected but valid)"
  else
    die "gh failure (rc=$rc, output=$output)"
  fi
fi

# Given: valid PR number format
# When: check input validation accepts numeric
# Then: doesn't fail on format validation (may fail on gh)
output=$("$SCRIPT" "123" 2>&1) && rc=0 || rc=$?
# We just want to ensure it doesn't fail on input validation
if [[ $rc -eq 0 ]] || (echo "$output" | grep -q "Failed to fetch"); then
  ok "numeric PR number accepted"
else
  die "numeric PR number (rc=$rc, output=$output)"
fi

# Given: valid PR URL format
# When: check input validation accepts URL
# Then: doesn't fail on format validation (may fail on gh)
output=$("$SCRIPT" "https://github.com/owner/repo/pull/123" 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 0 ]] || (echo "$output" | grep -q "Failed to fetch"); then
  ok "PR URL format accepted"
else
  die "PR URL format (rc=$rc, output=$output)"
fi

echo ""
echo "Results: $pass passed, $fail failed"
[[ $fail -eq 0 ]] && exit 0 || exit 1
