#!/usr/bin/env bash
# Test: scripts/detect-changed-code-files.sh
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/detect-changed-code-files.sh"

pass=0
fail=0
ok() { pass=$((pass + 1)); echo "  PASS: $1"; }
die() { fail=$((fail + 1)); echo "  FAIL: $1"; }

echo "=== test-detect-changed-code-files.sh ==="

# Create a temp git repo for testing
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT
cd "$tmpdir"
git init -q
git config user.email "test@test.com"
git config user.name "Test"

# Create initial commit on main branch
git checkout -b main -q 2>/dev/null || true
echo "# readme" > README.md
git add README.md
git commit -q -m "initial"

# Given: a new .py file (code file)
# When: run the script
# Then: the file is listed
echo "print('hello')" > script.py
output=$("$SCRIPT" main 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 0 ]] && echo "$output" | grep -q "script.py"; then
  ok "detects new .py file"
else
  die "detects new .py file (rc=$rc, output=$output)"
fi

# Given: a new .sh file (code file)
# Then: the file is listed
echo '#!/bin/bash' > deploy.sh
chmod +x deploy.sh
output=$("$SCRIPT" main 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 0 ]] && echo "$output" | grep -q "deploy.sh"; then
  ok "detects new .sh file"
else
  die "detects new .sh file (output=$output)"
fi

# Given: a new .md file (non-code)
# Then: the file is NOT listed
echo "# doc" > CHANGELOG.md
output=$("$SCRIPT" main 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 0 ]] && ! echo "$output" | grep -q "CHANGELOG.md"; then
  ok "filters out .md files"
else
  die "filters out .md files (output=$output)"
fi

# Given: a new test file (tests/ directory)
# Then: the file is NOT listed
mkdir -p tests
echo "assert True" > tests/test_stuff.py
output=$("$SCRIPT" main 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 0 ]] && ! echo "$output" | grep -q "tests/test_stuff.py"; then
  ok "filters out test files in tests/"
else
  die "filters out test files in tests/ (output=$output)"
fi

# Given: a file with test- prefix
# Then: the file is NOT listed
echo "test" > test-foo.sh
output=$("$SCRIPT" main 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 0 ]] && ! echo "$output" | grep -q "test-foo.sh"; then
  ok "filters out test- prefixed files"
else
  die "filters out test- prefixed files (output=$output)"
fi

# Given: only non-code files changed
# Then: output is empty
rm -f script.py deploy.sh
echo "# only docs" > docs.md
output=$("$SCRIPT" main 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 0 ]] && [[ -z "$output" ]]; then
  ok "returns empty when only non-code files changed"
else
  die "returns empty when only non-code files changed (output=$output)"
fi

# Given: a MODIFIED tracked script file (git diff path, not untracked)
# Then: the file is listed via the git diff code path
rm -f docs.md
# Create a feature branch so we can diff against main
git checkout -b feature -q
echo '#!/bin/bash' > tracked.sh
git add tracked.sh
git commit -q -m "add tracked script"
echo '# modified' >> tracked.sh
output=$("$SCRIPT" main 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 0 ]] && echo "$output" | grep -q "tracked.sh"; then
  ok "detects modified tracked script via git diff path"
else
  die "detects modified tracked script via git diff path (rc=$rc, output=$output)"
fi

echo ""
echo "Results: $pass passed, $fail failed"
[[ $fail -eq 0 ]] && exit 0 || exit 1
