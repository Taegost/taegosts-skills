#!/usr/bin/env bash
# test-to-json.sh — tests for to-json.sh
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/to-json.sh"
pass=0 fail=0

echo "=== test-to-json.sh ==="

# --help
output=$("$SCRIPT" --help 2>&1)
if echo "$output" | grep -q "Usage:"; then echo "PASS: --help"; pass=$((pass+1))
else echo "FAIL: --help"; fail=$((fail+1)); fi

# -h
output=$("$SCRIPT" -h 2>&1)
if echo "$output" | grep -q "Usage:"; then echo "PASS: -h"; pass=$((pass+1))
else echo "FAIL: -h"; fail=$((fail+1)); fi

# key=value → JSON object
output=$("$SCRIPT" name="hello world" count=5 active=true)
if echo "$output" | python3 -m json.tool > /dev/null 2>&1; then echo "PASS: valid JSON"; pass=$((pass+1))
else echo "FAIL: invalid JSON"; fail=$((fail+1)); fi

# Verify values survived encoding
if echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d['name']=='hello world'; assert d['count']==5; assert d['active']==True" 2>/dev/null; then
  echo "PASS: correct values"; pass=$((pass+1))
else echo "FAIL: wrong values"; fail=$((fail+1)); fi

# --array
output=$("$SCRIPT" --array one two "three with spaces")
if echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d==['one','two','three with spaces']" 2>/dev/null; then
  echo "PASS: array mode"; pass=$((pass+1))
else echo "FAIL: array mode"; fail=$((fail+1)); fi

# --wrap
output=$(echo '{"nested": true}' | "$SCRIPT" --wrap data)
if echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d=={'data':{'nested':True}}" 2>/dev/null; then
  echo "PASS: wrap mode"; pass=$((pass+1))
else echo "FAIL: wrap mode"; fail=$((fail+1)); fi

# Special characters — verify values survived, not just valid JSON
output=$("$SCRIPT" path='/tmp/test with spaces/file.yaml' error='contains "quotes" and \$pecial')
if echo "$output" | python3 -c "
import sys,json
d=json.load(sys.stdin)
assert d['path']=='/tmp/test with spaces/file.yaml', f'path: {d[\"path\"]}'
assert '\"quotes\"' in d['error'], f'error: {d[\"error\"]}'
assert '\$pecial' in d['error'], f'error: {d[\"error\"]}'
" 2>/dev/null; then
  echo "PASS: special chars values survived"; pass=$((pass+1))
else echo "FAIL: special chars corrupted"; fail=$((fail+1)); fi


# --strings flag: all values forced to strings
output=$("$SCRIPT" --strings count=5 active=true version=1.2)
if echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d['count']=='5'; assert d['active']=='true'; assert d['version']=='1.2'" 2>/dev/null; then
  echo "PASS: --strings mode"; pass=$((pass+1))
else echo "FAIL: --strings mode"; fail=$((fail+1)); fi

# version=1.2 stays as string with --strings (was coerced to float before)
output=$("$SCRIPT" --strings version=1.2)
if echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d['version']=='1.2', f'got {d["version"]}'" 2>/dev/null; then
  echo "PASS: version string preserved"; pass=$((pass+1))
else echo "FAIL: version string coerced"; fail=$((fail+1)); fi

# invalid argument should error
if "$SCRIPT" "no-equals-sign" 2>/dev/null; then
  echo "FAIL: invalid arg should error"; fail=$((fail+1))
else
  echo "PASS: invalid arg errors"; pass=$((pass+1))
fi

echo "Results: $pass passed, $fail failed"
[[ $fail -eq 0 ]] && exit 0 || exit 1
