#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
SCRIPT="$REPO_ROOT/skills/ce-code-review/scripts/select-reviewers.sh"
pass=0 fail=0

echo "=== U13: select-reviewers.sh ==="

output=$("$SCRIPT" --help 2>&1)
if echo "$output" | grep -q "Usage:"; then echo "PASS: --help"; pass=$((pass+1))
else echo "FAIL: --help"; fail=$((fail+1)); fi

output=$(echo -e "src/auth/login.py\nsrc/auth/session.py" | "$SCRIPT" 2>&1)
if echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin); assert 'security' in d['conditional']" 2>/dev/null; then
  echo "PASS: detects auth files"; pass=$((pass+1))
else echo "FAIL: auth detection"; fail=$((fail+1)); fi

output=$(echo -e "src/models/user.py" | "$SCRIPT" 2>&1)
if echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin); assert 'correctness' in d['always_on']" 2>/dev/null; then
  echo "PASS: always-on present"; pass=$((pass+1))
else echo "FAIL: always-on"; fail=$((fail+1)); fi

echo "Results: $pass passed, $fail failed"
[[ $fail -eq 0 ]] && exit 0 || exit 1
