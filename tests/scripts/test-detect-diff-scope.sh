#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/detect-diff-scope.sh"
pass=0 fail=0

echo "=== U7: detect-diff-scope.sh ==="

# Test: --help
output=$("$SCRIPT" --help 2>&1)
if echo "$output" | grep -q "Usage:"; then echo "PASS: --help"; pass=$((pass + 1))
else echo "FAIL: --help"; fail=$((fail + 1)); fi

# Test: local mode in a temp repo (with feature branch)
tmpdir=$(mktemp -d)
cd "$tmpdir" || exit 1
git init -b main >/dev/null 2>&1
git config user.email "test@test.com"
git config user.name "Test"
echo "initial" > file.txt && git add . && git commit -m "init" >/dev/null 2>&1
git update-ref refs/remotes/origin/main HEAD
git checkout -b feat/test >/dev/null 2>&1
echo "change" >> file.txt && git add . && git commit -m "change" >/dev/null 2>&1

output=$(cd "$tmpdir" && "$SCRIPT" --base main 2>&1)
if echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d['mode']=='base'; assert len(d['files_changed'])>0" 2>/dev/null; then
  echo "PASS: local mode detects changes"; pass=$((pass + 1))
else
  echo "FAIL: local mode"; fail=$((fail + 1))
fi

# Test: has_tests detection (with feature branch)
tmpdir2=$(mktemp -d)
cd "$tmpdir2" || exit 1
trap 'rm -rf "$tmpdir" "$tmpdir2"' EXIT
git init -b main >/dev/null 2>&1
git config user.email "test@test.com"
git config user.name "Test"
echo "initial" > file.txt && git add . && git commit -m "init" >/dev/null 2>&1
git update-ref refs/remotes/origin/main HEAD
git checkout -b feat/test >/dev/null 2>&1
echo "test" > test_something.py && git add . && git commit -m "add test" >/dev/null 2>&1

output=$(cd "$tmpdir2" && "$SCRIPT" --base main 2>&1)
if echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d['has_tests']==True" 2>/dev/null; then
  echo "PASS: detects test files"; pass=$((pass + 1))
else
  echo "FAIL: test detection"; fail=$((fail + 1))
fi

echo "Results: $pass passed, $fail failed"
[[ $fail -eq 0 ]] && exit 0 || exit 1
