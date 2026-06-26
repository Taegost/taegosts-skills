#!/usr/bin/env bash
# test-verify-fix.sh — tests for verify-fix.sh
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/verify-fix.sh"
pass=0 fail=0

tmpdir=$(mktemp -d)
cleanup() { rm -rf "$tmpdir"; }
trap cleanup EXIT

echo "=== test-verify-fix.sh ==="

# --help
output=$("$SCRIPT" --help 2>&1)
if echo "$output" | grep -q "Usage:"; then echo "PASS: --help"; pass=$((pass+1))
else echo "FAIL: --help"; fail=$((fail+1)); fi

# -h
output=$("$SCRIPT" -h 2>&1)
if echo "$output" | grep -q "Usage:"; then echo "PASS: -h"; pass=$((pass+1))
else echo "FAIL: -h"; fail=$((fail+1)); fi

# --should-contain (positive)
echo "hello world" > "$tmpdir/t.txt"
"$SCRIPT" --file "$tmpdir/t.txt" --should-contain "hello" && echo "PASS: should-contain positive" && pass=$((pass+1)) || { echo "FAIL: should-contain positive"; fail=$((fail+1)); }

# --should-contain (negative)
"$SCRIPT" --file "$tmpdir/t.txt" --should-contain "MISSING" && { echo "FAIL: should-contain negative"; fail=$((fail+1)); } || { echo "PASS: should-contain negative"; pass=$((pass+1)); }

# --should-not-contain (positive)
"$SCRIPT" --file "$tmpdir/t.txt" --should-not-contain "xyz" && echo "PASS: should-not-contain positive" && pass=$((pass+1)) || { echo "FAIL: should-not-contain positive"; fail=$((fail+1)); }

# --should-not-contain (negative)
"$SCRIPT" --file "$tmpdir/t.txt" --should-not-contain "hello" && { echo "FAIL: should-not-contain negative"; fail=$((fail+1)); } || { echo "PASS: should-not-contain negative"; pass=$((pass+1)); }

# --should-match
"$SCRIPT" --file "$tmpdir/t.txt" --should-match "hello.*world" && echo "PASS: should-match" && pass=$((pass+1)) || { echo "FAIL: should-match"; fail=$((fail+1)); }

# --line N --should-contain
echo -e "line1\nline2\nline3" > "$tmpdir/lines.txt"
"$SCRIPT" --file "$tmpdir/lines.txt" --line 2 --should-contain "line2" && echo "PASS: --line should-contain" && pass=$((pass+1)) || { echo "FAIL: --line should-contain"; fail=$((fail+1)); }

# --line N --should-contain (wrong line)
"$SCRIPT" --file "$tmpdir/lines.txt" --line 2 --should-contain "line3" && { echo "FAIL: --line wrong line"; fail=$((fail+1)); } || { echo "PASS: --line wrong line"; pass=$((pass+1)); }

# --no-control-chars (clean file)
echo "clean text" > "$tmpdir/clean.txt"
"$SCRIPT" --file "$tmpdir/clean.txt" --no-control-chars && echo "PASS: no-control-chars clean" && pass=$((pass+1)) || { echo "FAIL: no-control-chars clean"; fail=$((fail+1)); }

# --no-control-chars (dirty file)
printf 'has\x01control' > "$tmpdir/dirty.txt"
"$SCRIPT" --file "$tmpdir/dirty.txt" --no-control-chars && { echo "FAIL: no-control-chars dirty"; fail=$((fail+1)); } || { echo "PASS: no-control-chars dirty"; pass=$((pass+1)); }

# --valid-bash
echo '#!/bin/bash' > "$tmpdir/good.sh"
"$SCRIPT" --file "$tmpdir/good.sh" --valid-bash && echo "PASS: valid-bash" && pass=$((pass+1)) || { echo "FAIL: valid-bash"; fail=$((fail+1)); }

# --valid-bash (bad syntax)
echo "if then else" > "$tmpdir/bad.sh"
"$SCRIPT" --file "$tmpdir/bad.sh" --valid-bash && { echo "FAIL: valid-bash bad"; fail=$((fail+1)); } || { echo "PASS: valid-bash bad"; pass=$((pass+1)); }

# --valid-json
echo '{"key": "value"}' > "$tmpdir/good.json"
"$SCRIPT" --file "$tmpdir/good.json" --valid-json && echo "PASS: valid-json" && pass=$((pass+1)) || { echo "FAIL: valid-json"; fail=$((fail+1)); }

# --valid-json (bad)
echo "not json" > "$tmpdir/bad.json"
"$SCRIPT" --file "$tmpdir/bad.json" --valid-json && { echo "FAIL: valid-json bad"; fail=$((fail+1)); } || { echo "PASS: valid-json bad"; pass=$((pass+1)); }

# --is-executable
echo '#!/bin/bash' > "$tmpdir/exec.sh" && chmod +x "$tmpdir/exec.sh"
"$SCRIPT" --file "$tmpdir/exec.sh" --is-executable && echo "PASS: is-executable" && pass=$((pass+1)) || { echo "FAIL: is-executable"; fail=$((fail+1)); }

# --is-executable (not executable)
echo "test" > "$tmpdir/noexec.sh"
"$SCRIPT" --file "$tmpdir/noexec.sh" --is-executable && { echo "FAIL: is-executable not"; fail=$((fail+1)); } || { echo "PASS: is-executable not"; pass=$((pass+1)); }

# zero checks → FAIL
"$SCRIPT" --file "$tmpdir/t.txt" && { echo "FAIL: zero checks"; fail=$((fail+1)); } || { echo "PASS: zero checks fails"; pass=$((pass+1)); }

# unknown flag → error
"$SCRIPT" --file "$tmpdir/t.txt" --bogus-flag 2>/dev/null && { echo "FAIL: unknown flag"; fail=$((fail+1)); } || { echo "PASS: unknown flag rejected"; pass=$((pass+1)); }

echo "Results: $pass passed, $fail failed"
[[ $fail -eq 0 ]] && exit 0 || exit 1
