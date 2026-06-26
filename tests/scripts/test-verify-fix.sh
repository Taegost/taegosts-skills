#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/verify-fix.sh"
TESTFILE=$(mktemp)
pass=0 fail=0
cleanup() { rm -f "$TESTFILE"; }
trap cleanup EXIT

echo "=== verify-fix.sh ==="

echo "hello world" > "$TESTFILE"

"$SCRIPT" --file "$TESTFILE" --should-contain "hello" && echo "PASS: should-contain" && pass=$((pass+1)) || { echo "FAIL: should-contain"; fail=$((fail+1)); }

"$SCRIPT" --file "$TESTFILE" --should-not-contain "xyz" && echo "PASS: should-not-contain" && pass=$((pass+1)) || { echo "FAIL: should-not-contain"; fail=$((fail+1)); }

"$SCRIPT" --file "$TESTFILE" --should-contain "MISSING" && { echo "FAIL: should-contain negative"; fail=$((fail+1)); } || { echo "PASS: should-contain negative"; pass=$((pass+1)); }

echo "Results: $pass passed, $fail failed"
[[ $fail -eq 0 ]] && exit 0 || exit 1
