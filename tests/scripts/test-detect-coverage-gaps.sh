#!/usr/bin/env bash
# Test: scripts/detect-coverage-gaps.sh
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/detect-coverage-gaps.sh"

pass=0
fail=0
ok() { pass=$((pass + 1)); echo "  PASS: $1"; }
die() { fail=$((fail + 1)); echo "  FAIL: $1"; }

echo "=== test-detect-coverage-gaps.sh ==="

# Create a temp git repo
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT
cd "$tmpdir"
git init -q
git config user.email "test@test.com"
git config user.name "Test"

# Initial commit
echo "# readme" > README.md
git add README.md
git commit -q -m "initial"

# Given: a new .py script with no test file
# When: run the detector
# Then: gap is flagged
echo "print('hello')" > helper.py
output=$(python3 -c "import json, sys; d=json.loads(sys.argv[1]); print(d['count'])" "$("$SCRIPT" main 2>&1)")
if [[ "$output" == "1" ]]; then
  ok "flags new .py script without test"
else
  die "flags new .py script without test (output=$output)"
fi

# Given: a new .py script WITH a corresponding test file
# Then: no gap flagged
mkdir -p tests
echo "assert True" > tests/test_helper.py
output=$(python3 -c "import json, sys; d=json.loads(sys.argv[1]); print(d['count'])" "$("$SCRIPT" main 2>&1)")
if [[ "$output" == "0" ]]; then
  ok "no gap when test file exists"
else
  die "no gap when test file exists (output=$output)"
fi

# Given: a new .sh script with no test
# Then: gap is flagged
echo '#!/bin/bash' > deploy.sh
output=$(python3 -c "import json, sys; d=json.loads(sys.argv[1]); print(d['count'])" "$("$SCRIPT" main 2>&1)")
if [[ "$output" == "1" ]]; then
  ok "flags new .sh script without test"
else
  die "flags new .sh script without test (output=$output)"
fi

# Given: only non-script files changed
# Then: no gaps
rm -f helper.py deploy.sh
rm -rf tests
echo "# doc" > CHANGELOG.md
output=$(python3 -c "import json, sys; d=json.loads(sys.argv[1]); print(d['count'])" "$("$SCRIPT" main 2>&1)")
if [[ "$output" == "0" ]]; then
  ok "no gaps for non-script files"
else
  die "no gaps for non-script files (output=$output)"
fi

# Given: a test file itself changed
# Then: no gap (test files don't need tests for themselves)
echo "assert True" > tests/test_foo.py
output=$(python3 -c "import json, sys; d=json.loads(sys.argv[1]); print(d['count'])" "$("$SCRIPT" main 2>&1)")
if [[ "$output" == "0" ]]; then
  ok "no gap for test files themselves"
else
  die "no gap for test files themselves (output=$output)"
fi

echo ""
echo "Results: $pass passed, $fail failed"
[[ $fail -eq 0 ]] && exit 0 || exit 1
