#!/usr/bin/env bash
# test-gh-get-pr-state.sh -- tests for gh-get-pr-state.sh
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/gh-get-pr-state.sh"

pass=0
fail=0
ok() { pass=$((pass + 1)); echo "  PASS: $1"; }
die() { fail=$((fail + 1)); echo "  FAIL: $1"; }

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

echo "=== test-gh-get-pr-state.sh ==="

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
if [[ $rc -eq 1 ]] && echo "$output" | grep -q "required"; then
  ok "no arguments exits 1"
else
  die "no arguments (rc=$rc, output=$output)"
fi

# Empty --pr-url exits 1
output=$("$SCRIPT" --pr-url "" 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 1 ]]; then
  ok "empty --pr-url exits 1"
else
  die "empty --pr-url (rc=$rc, output=$output)"
fi

# Shell metacharacters rejected
output=$("$SCRIPT" --pr-url '123;rm -rf /' 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 1 ]] && echo "$output" | grep -q "metacharacters"; then
  ok "shell metacharacters rejected"
else
  die "shell metacharacters (rc=$rc, output=$output)"
fi

# Command substitution rejected
output=$("$SCRIPT" --pr-url '123$(whoami)' 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 1 ]] && echo "$output" | grep -q "metacharacters"; then
  ok "command substitution rejected"
else
  die "command substitution (rc=$rc, output=$output)"
fi

# Unknown argument exits 1
output=$("$SCRIPT" --pr-url 123 --bogus 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 1 ]]; then
  ok "unknown argument exits 1"
else
  die "unknown argument (rc=$rc, output=$output)"
fi

# Valid PR number format accepted (may fail on gh, but passes input validation)
output=$("$SCRIPT" --pr-url "123" 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 0 ]] || (echo "$output" | grep -q "failed to fetch"); then
  ok "numeric PR number accepted by validation"
else
  die "numeric PR number (rc=$rc, output=$output)"
fi

# Valid PR URL format accepted (may fail on gh, but passes input validation)
output=$("$SCRIPT" --pr-url "https://github.com/owner/repo/pull/123" 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 0 ]] || (echo "$output" | grep -q "failed to fetch"); then
  ok "PR URL format accepted by validation"
else
  die "PR URL format (rc=$rc, output=$output)"
fi

# Missing --pr-url value exits 1
output=$("$SCRIPT" --pr-url 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 1 ]]; then
  ok "missing --pr-url value exits 1"
else
  die "missing --pr-url value (rc=$rc, output=$output)"
fi

echo ""
echo "Results: $pass passed, $fail failed"
[[ $fail -eq 0 ]] && exit 0 || exit 1
