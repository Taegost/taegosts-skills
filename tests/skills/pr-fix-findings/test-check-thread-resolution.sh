#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
SCRIPT="$REPO_ROOT/skills/pr-fix-findings/scripts/check-thread-resolution.sh"
pass=0 fail=0

echo "=== U17: check-thread-resolution.sh ==="

output=$("$SCRIPT" --help 2>&1)
if echo "$output" | grep -q "Usage:"; then echo "PASS: --help"; pass=$((pass+1))
else echo "FAIL: --help"; fail=$((fail+1)); fi

output=$("$SCRIPT" 2>&1 || true)
if echo "$output" | grep -q "required"; then echo "PASS: rejects missing args"; pass=$((pass+1))
else echo "FAIL: rejects missing args"; fail=$((fail+1)); fi

echo "Results: $pass passed, $fail failed"
[[ $fail -eq 0 ]] && exit 0 || exit 1
