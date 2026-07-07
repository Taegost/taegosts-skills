#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
SCRIPT="$REPO_ROOT/skills/ts-code-review/scripts/select-reviewers.sh"
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

# U3: Mixed-surface file activates all applicable personas
output=$(echo "api/auth/login_controller_test.rb" | "$SCRIPT" 2>&1)
if echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin); assert 'security' in d['conditional'] and 'api-contract' in d['conditional'], f'got conditional={d[\"conditional\"]}'" 2>/dev/null; then
  echo "PASS: mixed-surface activates security + api-contract"; pass=$((pass+1))
else echo "FAIL: mixed-surface detection"; fail=$((fail+1)); fi

# U3: testing is in always_on, not conditional
output=$(echo "api/auth/login_controller_test.rb" | "$SCRIPT" 2>&1)
if echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin); assert 'testing' in d['always_on'] and 'testing' not in d['conditional']" 2>/dev/null; then
  echo "PASS: testing in always_on, not conditional"; pass=$((pass+1))
else echo "FAIL: testing location"; fail=$((fail+1)); fi

# U3: File with no conditional matches produces empty conditional
output=$(echo "src/utils/helpers.py" | "$SCRIPT" 2>&1)
if echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d['conditional'] == [], f'got conditional={d[\"conditional\"]}'" 2>/dev/null; then
  echo "PASS: no-match produces empty conditional"; pass=$((pass+1))
else echo "FAIL: no-match conditional"; fail=$((fail+1)); fi

# U3: Pure backend file activates only backend-related personas
output=$(echo "src/db/query_builder.py" | "$SCRIPT" 2>&1)
if echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d['conditional'] == ['performance'], f'got conditional={d[\"conditional\"]}'" 2>/dev/null; then
  echo "PASS: pure backend file activates only performance"; pass=$((pass+1))
else echo "FAIL: pure backend detection"; fail=$((fail+1)); fi

echo "Results: $pass passed, $fail failed"
[[ $fail -eq 0 ]] && exit 0 || exit 1
