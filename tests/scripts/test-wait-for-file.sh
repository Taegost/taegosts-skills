#!/usr/bin/env bash
# Test: scripts/wait-for-file.sh
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/wait-for-file.sh"

pass=0
fail=0
ok() { pass=$((pass + 1)); echo "  PASS: $1"; }
die() { fail=$((fail + 1)); echo "  FAIL: $1"; }

echo "=== test-wait-for-file.sh ==="

# Given: a file that already exists
# When: run the script
# Then: exits 0 immediately
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

touch "$tmpdir/existing-file.txt"
output=$("$SCRIPT" "$tmpdir/existing-file.txt" 5 1 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 0 ]] && echo "$output" | grep -q "File found"; then
  ok "detects existing file"
else
  die "detects existing file (rc=$rc, output=$output)"
fi

# Given: a file that appears after 2 seconds
# When: run the script with short timeout
# Then: exits 0 after file appears
(sleep 2 && touch "$tmpdir/delayed-file.txt") &
output=$("$SCRIPT" "$tmpdir/delayed-file.txt" 10 1 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 0 ]] && echo "$output" | grep -q "File found"; then
  ok "detects file that appears after delay"
else
  die "detects file that appears after delay (rc=$rc, output=$output)"
fi

# Given: a file that never appears
# When: run the script with short timeout
# Then: exits 1 after timeout
output=$("$SCRIPT" "$tmpdir/never-exists.txt" 3 1 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 1 ]] && echo "$output" | grep -q "Timeout"; then
  ok "times out when file never appears"
else
  die "times out when file never appears (rc=$rc, output=$output)"
fi

# Given: no arguments
# When: run the script
# Then: exits with error
output=$("$SCRIPT" 2>&1) && rc=0 || rc=$?
if [[ $rc -ne 0 ]]; then
  ok "fails with no arguments"
else
  die "fails with no arguments (rc=$rc)"
fi

echo ""
echo "Results: $pass passed, $fail failed"
[[ $fail -eq 0 ]] && exit 0 || exit 1
