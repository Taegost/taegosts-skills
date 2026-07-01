#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
SCRIPT="$REPO_ROOT/skills/ce-plan/scripts/scan-repo-structure.sh"
pass=0 fail=0
cleanup() { rm -rf /tmp/test-scan-* 2>/dev/null || true; }
trap cleanup EXIT

echo "=== U20: scan-repo-structure.sh ==="

output=$("$SCRIPT" --help 2>&1)
if echo "$output" | grep -q "Usage:"; then echo "PASS: --help"; pass=$((pass+1))
else echo "FAIL: --help"; fail=$((fail+1)); fi

output=$("$SCRIPT" /nonexistent 2>&1 || true)
if echo "$output" | grep -q "not found"; then echo "PASS: nonexistent dir"; pass=$((pass+1))
else echo "FAIL: nonexistent dir"; fail=$((fail+1)); fi

tmpdir=$(mktemp -d)
echo '{"name":"test"}' > "$tmpdir/package.json"
echo "console.log('hi')" > "$tmpdir/index.js"

output=$("$SCRIPT" "$tmpdir" 2>&1)
if echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d['ecosystem']=='node'; assert 'javascript' in d['languages']" 2>/dev/null; then
  echo "PASS: detects node ecosystem"; pass=$((pass+1))
else echo "FAIL: node detection"; fail=$((fail+1)); fi

echo "Results: $pass passed, $fail failed"
[[ $fail -eq 0 ]] && exit 0 || exit 1
