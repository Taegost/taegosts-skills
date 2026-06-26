#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/to-json.sh"
pass=0 fail=0

echo "=== to-json.sh ==="

# --help long flag
output=$("$SCRIPT" --help 2>&1)
if echo "$output" | grep -q "Usage:"; then echo "PASS: --help"; pass=$((pass+1))
else echo "FAIL: --help"; fail=$((fail+1)); fi

# -h short flag
output=$("$SCRIPT" -h 2>&1)
if echo "$output" | grep -q "Usage:"; then echo "PASS: -h"; pass=$((pass+1))
else echo "FAIL: -h"; fail=$((fail+1)); fi

# key=value with types
output=$("$SCRIPT" name="hello world" count=5 active=true missing=null)
if echo "$output" | python3 -m json.tool > /dev/null 2>&1; then echo "PASS: valid JSON"; pass=$((pass+1))
else echo "FAIL: invalid JSON"; fail=$((fail+1)); fi

# value correctness
if echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d['name']=='hello world'; assert d['count']==5; assert d['active']==True; assert d['missing'] is None" 2>/dev/null; then
  echo "PASS: correct values"; pass=$((pass+1))
else echo "FAIL: wrong values"; fail=$((fail+1)); fi

# array mode
output=$("$SCRIPT" --array one two "three with spaces")
if echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d==['one','two','three with spaces']" 2>/dev/null; then
  echo "PASS: array mode"; pass=$((pass+1))
else echo "FAIL: array mode"; fail=$((fail+1)); fi

# wrap mode
output=$(echo '{"nested": true}' | "$SCRIPT" --wrap data)
if echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d=={'data':{'nested':True}}" 2>/dev/null; then
  echo "PASS: wrap mode"; pass=$((pass+1))
else echo "FAIL: wrap mode"; fail=$((fail+1)); fi

# Special characters — format check AND value survival
output=$("$SCRIPT" path="/tmp/test with spaces/file.yaml" error='contains "quotes"')
if echo "$output" | python3 -m json.tool > /dev/null 2>&1; then echo "PASS: special chars valid JSON"; pass=$((pass+1))
else echo "FAIL: special chars invalid JSON"; fail=$((fail+1)); fi

if echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d['path']=='/tmp/test with spaces/file.yaml'; assert d['error']=='contains \"quotes\"'" 2>/dev/null; then
  echo "PASS: special chars values survived"; pass=$((pass+1))
else echo "FAIL: special chars values corrupted"; fail=$((fail+1)); fi

echo "Results: $pass passed, $fail failed"
[[ $fail -eq 0 ]] && exit 0 || exit 1
