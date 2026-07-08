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

# Initial commit on main branch
git checkout -b main -q 2>/dev/null || true
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

# Given: a MODIFIED tracked script file (git diff path, not untracked)
# Then: gap is flagged via the git diff code path
rm -f CHANGELOG.md
# Create a feature branch so we can diff against main
git checkout -b feature -q
echo '#!/bin/bash' > tracked.sh
git add tracked.sh
git commit -q -m "add tracked script"
echo '# modified' >> tracked.sh
output=$(python3 -c "import json, sys; d=json.loads(sys.argv[1]); print(d['count'])" "$("$SCRIPT" main 2>&1)")
if [[ "$output" == "1" ]]; then
  ok "flags modified tracked script via git diff path"
else
  die "flags modified tracked script via git diff path (output=$output)"
fi

# Given: a test file itself changed
# Then: no gap (test files don't need tests for themselves)
# Clean up: remove modified file, then switch back to main
rm -f tracked.sh
git checkout main -q 2>/dev/null || git checkout master -q
rm -rf tests
mkdir -p tests
echo "assert True" > tests/test_foo.py
output=$(python3 -c "import json, sys; d=json.loads(sys.argv[1]); print(d['count'])" "$("$SCRIPT" main 2>&1)")
if [[ "$output" == "0" ]]; then
  ok "no gap for test files themselves"
else
  die "no gap for test files themselves (output=$output)"
fi

# Integration: verify JSON output matches expected schema
# Given: a changed script without a test
# Then: output is valid JSON with correct structure (gaps array, count, file/basename/suggested_test fields)
rm -rf tests
echo '#!/bin/bash' > new-script.sh
git checkout -b schema-test -q
git add new-script.sh
git commit -q -m "add new script"
echo '# modified' >> new-script.sh
json_output=$("$SCRIPT" main 2>&1)
schema_ok=$(python3 -c "
import json, sys
try:
    d = json.loads(sys.argv[1])
    assert 'gaps' in d, 'missing gaps key'
    assert 'count' in d, 'missing count key'
    assert isinstance(d['gaps'], list), 'gaps not a list'
    assert isinstance(d['count'], int), 'count not an int'
    if d['count'] > 0:
        g = d['gaps'][0]
        assert 'file' in g, 'missing file in gap'
        assert 'basename' in g, 'missing basename in gap'
        assert 'suggested_test' in g, 'missing suggested_test in gap'
        # Verify suggested_test uses the actual extension
        assert g['suggested_test'].endswith('.sh'), f'expected .sh extension, got {g[\"suggested_test\"]}'
    print('ok')
except Exception as e:
    print(f'FAIL: {e}', file=sys.stderr)
    sys.exit(1)
" "$json_output" 2>&1) && rc=0 || rc=$?
rm -f new-script.sh
git checkout main -q 2>/dev/null || git checkout master -q
if [[ $rc -eq 0 ]] && [[ "$schema_ok" == "ok" ]]; then
  ok "JSON output matches expected schema"
else
  die "JSON output matches expected schema (rc=$rc, output=$schema_ok)"
fi

# Given: an untracked script under .claude/worktrees/ with no test file
# Then: no gap flagged (worktree paths are excluded from scan)
rm -f new-script.sh
mkdir -p .claude/worktrees/some-branch
echo "print('hello')" > .claude/worktrees/some-branch/orphan.py
output=$(python3 -c "import json, sys; d=json.loads(sys.argv[1]); print(d['count'])" "$("$SCRIPT" main 2>&1)")
rm -rf .claude
if [[ "$output" == "0" ]]; then
  ok "excludes untracked files under .claude/worktrees/"
else
  die "excludes untracked files under .claude/worktrees/ (output=$output)"
fi

echo ""
echo "Results: $pass passed, $fail failed"
[[ $fail -eq 0 ]] && exit 0 || exit 1
