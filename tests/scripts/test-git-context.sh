#!/usr/bin/env bash
# Test: scripts/git-context.sh
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/git-context.sh"

pass=0
fail=0
ok() { pass=$((pass + 1)); echo "  PASS: $1"; }
die() { fail=$((fail + 1)); echo "  FAIL: $1"; }

echo "=== test-git-context.sh ==="

# Given: script exists
# When: run with --help
# Then: exits 0, shows usage
output=$("$SCRIPT" --help 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 0 ]] && echo "$output" | grep -q "Usage"; then
  ok "--help flag works"
else
  die "--help flag (rc=$rc)"
fi

# Given: running in a git repo
# When: run the script
# Then: exits 0, output is valid JSON with required fields
output=$("$SCRIPT" 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 0 ]]; then
  ok "exits 0 in git repo"
else
  die "exit code in git repo (rc=$rc)"
fi

# Check JSON validity
echo "$output" > /tmp/git-ctx-test.json
if python3 -m json.tool /tmp/git-ctx-test.json >/dev/null 2>&1; then
  ok "output is valid JSON"
else
  die "output is not valid JSON"
fi

# Check required fields exist
for field in current_branch default_branch is_detached dirty_files untracked_files staged_files recent_commits has_unpushed repo_root; do
  if grep -q "\"$field\"" /tmp/git-ctx-test.json; then
    ok "has field: $field"
  else
    die "missing field: $field"
  fi
done

# Given: running in the real repo
# When: check specific values
# Then: current_branch matches git branch, default_branch is "main"
branch=$(grep '"current_branch"' /tmp/git-ctx-test.json | sed 's/.*": "//;s/".*//')
if [[ "$branch" == "$(git symbolic-ref --short HEAD 2>/dev/null)" ]]; then
  ok "current_branch matches actual branch"
else
  die "current_branch mismatch"
fi

default=$(grep '"default_branch"' /tmp/git-ctx-test.json | sed 's/.*": "//;s/".*//')
if [[ "$default" == "main" ]]; then
  ok "default_branch is main"
else
  die "default_branch is $default"
fi

# Given: outside a git repo
# When: run in a non-git dir
# Then: exits 1
tmpdir=$(mktemp -d)
cd "$tmpdir" || exit 1
trap 'rm -rf "$tmpdir"' EXIT
output=$("$SCRIPT" 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 1 ]]; then
  ok "exits 1 outside git repo"
else
  die "expected exit 1 outside git repo (rc=$rc)"
fi

echo ""
echo "Results: $pass passed, $fail failed"
[[ $fail -eq 0 ]] && exit 0 || exit 1
