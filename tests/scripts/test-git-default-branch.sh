#!/usr/bin/env bash
# Test: scripts/git-default-branch.sh
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/git-default-branch.sh"

pass=0
fail=0
ok() { pass=$((pass + 1)); echo "  PASS: $1"; }
die() { fail=$((fail + 1)); echo "  FAIL: $1"; }

echo "=== test-git-default-branch.sh ==="

# Given: script exists
# When: check file
# Then: script is readable
if [[ -r "$SCRIPT" ]]; then
  ok "script exists and is readable"
else
  die "script not found or not readable"
fi

# Given: temp repo with origin/main
# When: source the script
# Then: DEFAULT_BRANCH is set to origin/main
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT
cd "$tmpdir" || exit 1
git init -b main >/dev/null 2>&1
git config user.email "test@test.com"
git config user.name "Test"
git commit --allow-empty -m "init" >/dev/null 2>&1
git remote add origin https://example.com/fake.git 2>/dev/null
git update-ref refs/remotes/origin/main "$(git rev-parse HEAD)"

# Source the script to get variables
# shellcheck disable=SC1090 # dynamic path to the script under test, by design
source "$SCRIPT" 2>/dev/null && rc=0 || rc=$?
if [[ $rc -eq 0 ]] && [[ "$DEFAULT_BRANCH" == "origin/main" ]]; then
  ok "resolves origin/main when it exists"
else
  die "origin/main (rc=$rc, DEFAULT_BRANCH=$DEFAULT_BRANCH)"
fi

# Given: temp repo with origin/master (no origin/main)
# When: source the script
# Then: DEFAULT_BRANCH is set to origin/master
tmpdir2=$(mktemp -d)
trap 'rm -rf "$tmpdir" "$tmpdir2"' EXIT
cd "$tmpdir2" || exit 1
git init -b master >/dev/null 2>&1
git config user.email "test@test.com"
git config user.name "Test"
git commit --allow-empty -m "init" >/dev/null 2>&1
git remote add origin https://example.com/fake.git 2>/dev/null
git update-ref refs/remotes/origin/master "$(git rev-parse HEAD)"

# shellcheck disable=SC1090 # dynamic path to the script under test, by design
source "$SCRIPT" 2>/dev/null && rc=0 || rc=$?
if [[ $rc -eq 0 ]] && [[ "$DEFAULT_BRANCH" == "origin/master" ]]; then
  ok "resolves origin/master when origin/main missing"
else
  die "origin/master (rc=$rc, DEFAULT_BRANCH=$DEFAULT_BRANCH)"
fi

# Given: temp repo with neither origin/main nor origin/master
# When: run the script
# Then: exits with error
tmpdir3=$(mktemp -d)
trap 'rm -rf "$tmpdir" "$tmpdir2" "$tmpdir3"' EXIT
cd "$tmpdir3" || exit 1
git init -b develop >/dev/null 2>&1
git config user.email "test@test.com"
git config user.name "Test"
git commit --allow-empty -m "init" >/dev/null 2>&1
git remote add origin https://example.com/fake.git 2>/dev/null

output=$(bash "$SCRIPT" 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 2 ]]; then
  ok "exits 2 when no default branch found"
else
  die "no default branch (rc=$rc, output=$output)"
fi

# Given: outside a git repo
# When: run the script
# Then: exits with error
tmpdir4=$(mktemp -d)
trap 'rm -rf "$tmpdir" "$tmpdir2" "$tmpdir3" "$tmpdir4"' EXIT
cd "$tmpdir4" || exit 1

output=$(bash "$SCRIPT" 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 2 ]]; then
  ok "exits 2 outside git repo"
else
  die "outside git repo (rc=$rc, output=$output)"
fi

# Given: back in temp repo with origin/main
# When: source the script to check REPO_ROOT
# Then: REPO_ROOT matches tmpdir
cd "$tmpdir" || exit 1
# shellcheck disable=SC1090 # dynamic path to the script under test, by design
source "$SCRIPT" 2>/dev/null && rc=0 || rc=$?
if [[ $rc -eq 0 ]] && [[ "$REPO_ROOT" == "$tmpdir" ]]; then
  ok "REPO_ROOT set correctly"
else
  die "REPO_ROOT (rc=$rc, REPO_ROOT=$REPO_ROOT, expected=$tmpdir)"
fi

# Given: output is a valid branch reference
# When: check DEFAULT_BRANCH format
# Then: matches origin/<branch> pattern where <branch> is a valid git ref
# Use git check-ref-format to validate the branch name (it can contain slashes and dots)
cd "$tmpdir" || exit 1
# shellcheck disable=SC1090 # dynamic path to the script under test, by design
source "$SCRIPT" 2>/dev/null && rc=0 || rc=$?
if [[ $rc -eq 0 ]] && [[ "$DEFAULT_BRANCH" =~ ^origin/(.+)$ ]]; then
  branch_name="${BASH_REMATCH[1]}"
  # git check-ref-format validates ref names: allows alphanumeric, -, _, ., and /
  # Strip the refs/heads/ prefix it expects; we're checking just the leaf name
  if git check-ref-format --allow-onelevel "$branch_name" 2>/dev/null; then
    ok "DEFAULT_BRANCH is valid branch reference"
  else
    die "DEFAULT_BRANCH format (git check-ref-format rejected: $DEFAULT_BRANCH)"
  fi
else
  die "DEFAULT_BRANCH format (rc=$rc, DEFAULT_BRANCH=$DEFAULT_BRANCH)"
fi

echo ""
echo "Results: $pass passed, $fail failed"
[[ $fail -eq 0 ]] && exit 0 || exit 1
