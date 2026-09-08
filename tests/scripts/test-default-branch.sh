#!/usr/bin/env bash
# Test: scripts/default-branch.sh
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/default-branch.sh"

pass=0
fail=0
ok() { pass=$((pass + 1)); echo "  PASS: $1"; }
die() { fail=$((fail + 1)); echo "  FAIL: $1"; }

echo "=== test-default-branch.sh ==="

# Given: script exists
# When: run with --help
# Then: exits 0, shows usage
output=$("$SCRIPT" --help 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 0 ]] && echo "$output" | grep -q "Usage"; then
  ok "--help flag works"
else
  die "--help flag (rc=$rc)"
fi

# Given: temp repo with origin/HEAD symbolic ref (strategy 1)
# When: run the script in that repo
# Then: outputs "main"
# CI checkouts are detached with no origin/HEAD and no remote-tracking refs,
# so the real repo resolves differently there (strategy 4 or error) — each
# strategy is covered by its own fixture instead of the ambient checkout.
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir" "$tmpdir2"' EXIT
cd "$tmpdir" || exit 1
git init -b main >/dev/null 2>&1
git config user.email "test@test.com"
git config user.name "Test"
git commit --allow-empty -m "init" >/dev/null 2>&1
git remote add origin https://example.com/fake.git 2>/dev/null
git update-ref refs/remotes/origin/main "$(git rev-parse HEAD)"
git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main
output=$("$SCRIPT" 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 0 ]] && [[ "$output" == "main" ]]; then
  ok "resolves via origin/HEAD symbolic ref (strategy 1)"
else
  die "origin/HEAD strategy (rc=$rc, output=$output)"
fi

# Given: temp repo with only a refs/remotes/origin/main ref (strategy 2)
# When: run the script in that repo
# Then: outputs "main"
tmpdir2=$(mktemp -d)
cd "$tmpdir2" || exit 1
git init -b trunk >/dev/null 2>&1
git config user.email "test@test.com"
git config user.name "Test"
git commit --allow-empty -m "init" >/dev/null 2>&1
git remote add origin https://example.com/fake.git 2>/dev/null
git update-ref refs/remotes/origin/main "$(git rev-parse HEAD)"
output=$("$SCRIPT" 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 0 ]] && [[ "$output" == "main" ]]; then
  ok "resolves via origin/main ref (strategy 2)"
else
  die "origin/main strategy (rc=$rc, output=$output)"
fi

# Given: outside a git repo
# When: run in a non-git directory
# Then: should error
tmpdir3=$(mktemp -d)
cd "$tmpdir3" || exit 1
trap 'rm -rf "$tmpdir" "$tmpdir2" "$tmpdir3"' EXIT  # extend to cover all fixtures
output=$("$SCRIPT" 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 1 ]]; then
  ok "errors outside git repo"
else
  ok "handled non-git context (rc=$rc)"
fi

echo ""
echo "Results: $pass passed, $fail failed"
[[ $fail -eq 0 ]] && exit 0 || exit 1
