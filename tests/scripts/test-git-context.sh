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

# Given: temp repo with a known branch and origin/HEAD pointing at main
# When: run the script from inside it
# Then: current_branch/default_branch/is_detached report the fixture state.
# CI checkouts run detached with no origin/HEAD — value assertions against
# the real repo are environment-dependent; the fixture pins them.
fxt=$(mktemp -d)
cd "$fxt" || exit 1
git init -b feature-x >/dev/null 2>&1
git config user.email "test@test.com"
git config user.name "Test"
git commit --allow-empty -m "init" >/dev/null 2>&1
git remote add origin https://example.com/fake.git 2>/dev/null
git update-ref refs/remotes/origin/main "$(git rev-parse HEAD)"
git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main
fx_output=$("$SCRIPT" 2>&1) && rc=0 || rc=$?
fx_branch=$(grep '"current_branch"' <<< "$fx_output" | sed 's/.*": "//;s/".*//')
fx_default=$(grep '"default_branch"' <<< "$fx_output" | sed 's/.*": "//;s/".*//')

if [[ $rc -eq 0 ]] && [[ "$fx_branch" == "feature-x" ]]; then
  ok "current_branch matches fixture branch"
else
  die "current_branch in fixture (rc=$rc, got=$fx_branch)"
fi

if [[ "$fx_default" == "main" ]]; then
  ok "default_branch is main"
else
  die "default_branch is $fx_default"
fi

if grep -q '"is_detached": false' <<< "$fx_output"; then
  ok "is_detached false on a branch"
else
  die "is_detached not false in fixture"
fi

# Given: outside a git repo
# When: run in a non-git dir
# Then: exits 1
tmpdir=$(mktemp -d)
cd "$tmpdir" || exit 1
trap 'rm -rf "$tmpdir" "$fxt"' EXIT
output=$("$SCRIPT" 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 1 ]]; then
  ok "exits 1 outside git repo"
else
  die "expected exit 1 outside git repo (rc=$rc)"
fi

echo ""
echo "Results: $pass passed, $fail failed"
[[ $fail -eq 0 ]] && exit 0 || exit 1
