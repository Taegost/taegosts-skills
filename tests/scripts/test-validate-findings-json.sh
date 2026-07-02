#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/validate-findings-json.sh"
pass=0 fail=0
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

echo "=== U8: validate-findings-json.sh ==="

# Test: --help
output=$("$SCRIPT" --help 2>&1)
if echo "$output" | grep -q "Usage:"; then echo "PASS: --help"; pass=$((pass + 1))
else echo "FAIL: --help"; fail=$((fail + 1)); fi

# Test: valid findings
cat > "$tmpdir/valid.json" << 'JSONEOF'
[{"title":"test","severity":"High","file":"test.py","description":"a finding"}]
JSONEOF
output=$("$SCRIPT" "$tmpdir/valid.json" 2>&1)
if [[ "$output" == "pass" ]]; then echo "PASS: valid findings"; pass=$((pass + 1))
else echo "FAIL: valid findings got: $output"; fail=$((fail + 1)); fi

# Test: invalid severity
cat > "$tmpdir/bad-sev.json" << 'JSONEOF'
[{"title":"test","severity":"WRONG","file":"test.py","description":"a finding"}]
JSONEOF
output=$("$SCRIPT" "$tmpdir/bad-sev.json" 2>&1 || true)
if echo "$output" | grep -q "fail"; then echo "PASS: rejects invalid severity"; pass=$((pass + 1))
else echo "FAIL: should reject invalid severity"; fail=$((fail + 1)); fi

# Test: missing fields
cat > "$tmpdir/missing.json" << 'JSONEOF'
[{"title":"test"}]
JSONEOF
output=$("$SCRIPT" "$tmpdir/missing.json" 2>&1 || true)
if echo "$output" | grep -q "fail"; then echo "PASS: rejects missing fields"; pass=$((pass + 1))
else echo "FAIL: should reject missing fields"; fail=$((fail + 1)); fi

# Test: not JSON
echo "not json" > "$tmpdir/bad.json"
output=$("$SCRIPT" "$tmpdir/bad.json" 2>&1 || true)
if echo "$output" | grep -q "fail\|Error"; then echo "PASS: rejects non-JSON"; pass=$((pass + 1))
else echo "FAIL: should reject non-JSON"; fail=$((fail + 1)); fi

echo "Results: $pass passed, $fail failed"
[[ $fail -eq 0 ]] && exit 0 || exit 1
