#!/usr/bin/env bash
# test-verify-coverage-threshold.sh -- tests for verify-coverage-threshold.sh
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SCRIPT="$REPO_ROOT/skills/ts-verify-implementation/scripts/verify-coverage-threshold.sh"

pass=0
fail=0
ok() { pass=$((pass + 1)); echo "  PASS: $1"; }
die() { fail=$((fail + 1)); echo "  FAIL: $1"; }

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

echo "=== test-verify-coverage-threshold.sh ==="

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

# No arguments exits 2
output=$("$SCRIPT" 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 2 ]] && echo "$output" | grep -q "required"; then
  ok "no arguments exits 2"
else
  die "no arguments (rc=$rc, output=$output)"
fi

# Missing --threshold exits 2
echo "85" > "$tmpdir/coverage.txt"
output=$("$SCRIPT" --coverage-file "$tmpdir/coverage.txt" 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 2 ]] && echo "$output" | grep -q "threshold"; then
  ok "missing --threshold exits 2"
else
  die "missing --threshold (rc=$rc, output=$output)"
fi

# Missing --coverage-file exits 2
output=$("$SCRIPT" --threshold 80 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 2 ]] && echo "$output" | grep -q "coverage-file"; then
  ok "missing --coverage-file exits 2"
else
  die "missing --coverage-file (rc=$rc, output=$output)"
fi

# Non-existent file exits 2
output=$("$SCRIPT" --coverage-file "/nonexistent/file.txt" --threshold 80 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 2 ]] && echo "$output" | grep -q "not found"; then
  ok "non-existent file exits 2"
else
  die "non-existent file (rc=$rc, output=$output)"
fi

# Non-numeric threshold exits 2
echo "85" > "$tmpdir/coverage.txt"
output=$("$SCRIPT" --coverage-file "$tmpdir/coverage.txt" --threshold "abc" 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 2 ]] && echo "$output" | grep -q "numeric"; then
  ok "non-numeric threshold exits 2"
else
  die "non-numeric threshold (rc=$rc, output=$output)"
fi

# Threshold out of range (>100) exits 2
output=$("$SCRIPT" --coverage-file "$tmpdir/coverage.txt" --threshold 150 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 2 ]] && echo "$output" | grep -q "between"; then
  ok "threshold > 100 exits 2"
else
  die "threshold > 100 (rc=$rc, output=$output)"
fi

# Coverage above threshold exits 0 with success=true
echo "85.5" > "$tmpdir/coverage.txt"
output=$("$SCRIPT" --coverage-file "$tmpdir/coverage.txt" --threshold 80 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 0 ]] && echo "$output" | grep -q '"success":true'; then
  ok "coverage above threshold exits 0"
else
  die "coverage above threshold (rc=$rc, output=$output)"
fi

# Coverage at threshold exits 0 with success=true
echo "80" > "$tmpdir/coverage.txt"
output=$("$SCRIPT" --coverage-file "$tmpdir/coverage.txt" --threshold 80 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 0 ]] && echo "$output" | grep -q '"success":true'; then
  ok "coverage at threshold exits 0"
else
  die "coverage at threshold (rc=$rc, output=$output)"
fi

# Coverage below threshold exits 1 with success=false
echo "65.3" > "$tmpdir/coverage.txt"
output=$("$SCRIPT" --coverage-file "$tmpdir/coverage.txt" --threshold 80 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 1 ]] && echo "$output" | grep -q '"success":false'; then
  ok "coverage below threshold exits 1"
else
  die "coverage below threshold (rc=$rc, output=$output)"
fi

# Coverage with % sign is parsed correctly
echo "92.5%" > "$tmpdir/coverage.txt"
output=$("$SCRIPT" --coverage-file "$tmpdir/coverage.txt" --threshold 80 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 0 ]] && echo "$output" | grep -q '"coverage":92.5'; then
  ok "coverage with % sign parsed"
else
  die "coverage with % sign (rc=$rc, output=$output)"
fi

# Coverage with prefix text is parsed correctly
echo "Total coverage: 88.2%" > "$tmpdir/coverage.txt"
output=$("$SCRIPT" --coverage-file "$tmpdir/coverage.txt" --threshold 80 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 0 ]] && echo "$output" | grep -q '"coverage":88.2'; then
  ok "coverage with prefix text parsed"
else
  die "coverage with prefix text (rc=$rc, output=$output)"
fi

# Empty file exits 2
: > "$tmpdir/empty.txt"
output=$("$SCRIPT" --coverage-file "$tmpdir/empty.txt" --threshold 80 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 2 ]]; then
  ok "empty file exits 2"
else
  die "empty file (rc=$rc, output=$output)"
fi

# Unknown argument exits 2
output=$("$SCRIPT" --coverage-file "$tmpdir/coverage.txt" --threshold 80 --bogus 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 2 ]]; then
  ok "unknown argument exits 2"
else
  die "unknown argument (rc=$rc, output=$output)"
fi

# Regression: a very small decimal value must not be normalized into
# scientific notation (e.g. "1e-05"), which bc -l's POSIX grammar can't
# parse and would corrupt the comparison and JSON output.
echo "0.00001" > "$tmpdir/coverage.txt"
output=$("$SCRIPT" --coverage-file "$tmpdir/coverage.txt" --threshold 0.000001 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 0 ]] && echo "$output" | grep -q '"coverage":0.00001' && ! echo "$output" | grep -qi "e-"; then
  ok "small decimal coverage value avoids scientific notation"
else
  die "small decimal coverage value (rc=$rc, output=$output)"
fi

echo ""
echo "Results: $pass passed, $fail failed"
[[ $fail -eq 0 ]] && exit 0 || exit 1
