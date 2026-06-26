#!/usr/bin/env bash
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/verify-scripts.sh"
pass=0 fail=0
tmpdir=$(mktemp -d)
cleanup() { rm -rf "$tmpdir"; }
trap cleanup EXIT
echo "=== test-verify-scripts.sh ==="
output=$("$SCRIPT" --help 2>&1)
if echo "$output" | grep -q "Usage:"; then echo "PASS: --help"; pass=$((pass+1))
else echo "FAIL: --help"; fail=$((fail+1)); fi
echo "#!/bin/bash" > "$tmpdir/good.sh" && chmod +x "$tmpdir/good.sh"
echo "# help text with --help" >> "$tmpdir/good.sh"
"$SCRIPT" --file "$tmpdir/good.sh" && echo "PASS: good .sh" && pass=$((pass+1)) || { echo "FAIL: good .sh"; fail=$((fail+1)); }
echo "if then else" > "$tmpdir/bad.sh"
"$SCRIPT" --file "$tmpdir/bad.sh" 2>/dev/null && { echo "FAIL: bad .sh"; fail=$((fail+1)); } || { echo "PASS: bad .sh fails"; pass=$((pass+1)); }
echo "#!/usr/bin/env python3" > "$tmpdir/good.py" && chmod +x "$tmpdir/good.py"
echo "# --help" >> "$tmpdir/good.py"
echo "print(42)" >> "$tmpdir/good.py"
"$SCRIPT" --file "$tmpdir/good.py" && echo "PASS: good .py" && pass=$((pass+1)) || { echo "FAIL: good .py"; fail=$((fail+1)); }
echo "def foo(" > "$tmpdir/bad.py"
"$SCRIPT" --file "$tmpdir/bad.py" 2>/dev/null && { echo "FAIL: bad .py"; fail=$((fail+1)); } || { echo "PASS: bad .py fails"; pass=$((pass+1)); }
echo "content" > "$tmpdir/test.md"
output=$("$SCRIPT" --file "$tmpdir/test.md" 2>&1)
if echo "$output" | grep -q "0 passed"; then echo "PASS: unsupported ext skipped"; pass=$((pass+1))
else echo "FAIL: unsupported ext"; fail=$((fail+1)); fi
"$SCRIPT" --all 2>&1 | grep -q "checking" && echo "PASS: --all mode" && pass=$((pass+1)) || { echo "FAIL: --all"; fail=$((fail+1)); }
"$SCRIPT" "$REPO_ROOT/scripts" 2>&1 | grep -q "passed" && echo "PASS: dir arg" && pass=$((pass+1)) || { echo "FAIL: dir arg"; fail=$((fail+1)); }
echo "Results: $pass passed, $fail failed"
[[ $fail -eq 0 ]] && exit 0 || exit 1
