#!/usr/bin/env bash
# test-sync-taegosts-skills.sh — Tests for sync-taegosts-skills.sh
#
# Uses a local fixture repo instead of cloning from GitHub.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SYNC_SCRIPT="$REPO_ROOT/scripts/sync-taegosts-skills.sh"

PASS=0
FAIL=0
TESTS=0

pass() { PASS=$((PASS + 1)); TESTS=$((TESTS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); TESTS=$((TESTS + 1)); echo "  FAIL: $1"; }

# Create temp directories for testing
TEMP_HOME=$(mktemp -d)
trap 'rm -rf "$TEMP_HOME"' EXIT

# --- Fixture setup ---
# Create a local bare repo with test content to act as the upstream
FIXTURE_BARE="$TEMP_HOME/fixtures/taegosts-skills.git"
FIXTURE_WORK="$TEMP_HOME/fixtures/work"
mkdir -p "$FIXTURE_BARE"
git init --bare --initial-branch=main "$FIXTURE_BARE" >/dev/null 2>&1

# Clone, add content, push
git clone "$FIXTURE_BARE" "$FIXTURE_WORK" >/dev/null 2>&1
cd "$FIXTURE_WORK"
git config user.email "test@test.com"
git config user.name "Test"

# Add a skill
mkdir -p skills/test-skill
echo "test skill content" > skills/test-skill/SKILL.md

# Add a script
mkdir -p scripts
echo '#!/bin/bash
echo "test script"' > scripts/test-script.sh
chmod +x scripts/test-script.sh

# Add a test
mkdir -p tests/scripts
echo '#!/bin/bash
echo "test"' > tests/scripts/test-test.sh
chmod +x tests/scripts/test-test.sh

git add -A >/dev/null 2>&1
git commit -m "initial fixture" >/dev/null 2>&1
git push origin main >/dev/null 2>&1

echo "=== test-sync-taegosts-skills.sh ==="

# Test 1: Script exists and is executable
if [[ -x "$SYNC_SCRIPT" ]]; then
    pass "script exists and is executable"
else
    fail "script not found or not executable at $SYNC_SCRIPT"
fi

# Test 2: Dry run doesn't create anything
export HERMES_HOME="$TEMP_HOME/dry-test"
mkdir -p "$HERMES_HOME"
output=$(HERMES_HOME="$HERMES_HOME" SYNC_REPO_URL="$FIXTURE_BARE" bash "$SYNC_SCRIPT" --dry-run 2>&1)
if [[ ! -d "$HERMES_HOME/taegosts-skills" ]]; then
    pass "dry run does not create clone"
else
    fail "dry run created clone directory"
fi

# Test 3: Real run creates clone and syncs
export HERMES_HOME="$TEMP_HOME/real-test"
mkdir -p "$HERMES_HOME"
output=$(HERMES_HOME="$HERMES_HOME" SYNC_REPO_URL="$FIXTURE_BARE" bash "$SYNC_SCRIPT" 2>&1)
if [[ -d "$HERMES_HOME/taegosts-skills/.git" ]]; then
    pass "real run creates persistent clone"
else
    fail "real run did not create clone"
fi

# Test 4: Skills synced
if [[ -f "$HERMES_HOME/skills/test-skill/SKILL.md" ]]; then
    pass "skills synced to HERMES_HOME/skills/"
else
    fail "skills not synced"
fi

# Test 5: Scripts synced
if [[ -f "$HERMES_HOME/skills/scripts/test-script.sh" ]]; then
    pass "scripts synced to HERMES_HOME/skills/scripts/"
else
    fail "scripts not synced"
fi

# Test 6: Tests synced
if [[ -f "$HERMES_HOME/skills/tests/scripts/test-test.sh" ]]; then
    pass "tests synced to HERMES_HOME/skills/tests/"
else
    fail "tests not synced"
fi

# Test 7: Idempotent — second run reports no changes
output=$(HERMES_HOME="$HERMES_HOME" SYNC_REPO_URL="$FIXTURE_BARE" bash "$SYNC_SCRIPT" 2>&1)
if echo "$output" | grep -q "All up to date"; then
    pass "idempotent: second run reports all up to date"
else
    fail "idempotent: second run reported changes"
    echo "  Output: $output"
fi

# Test 8: Clone is on main branch
cd "$HERMES_HOME/taegosts-skills" || { fail "cd to clone dir failed"; exit 1; }
branch=$(git branch --show-current)
if [[ "$branch" == "main" ]]; then
    pass "clone is on main branch"
else
    fail "clone is on branch '$branch', expected main"
fi

# Test 9: Does not delete non-repo skills
mkdir -p "$HERMES_HOME/skills/fake-external-skill"
echo "not from repo" > "$HERMES_HOME/skills/fake-external-skill/SKILL.md"
HERMES_HOME="$HERMES_HOME" SYNC_REPO_URL="$FIXTURE_BARE" bash "$SYNC_SCRIPT" >/dev/null 2>&1
if [[ -f "$HERMES_HOME/skills/fake-external-skill/SKILL.md" ]]; then
    pass "preserves non-repo skills"
else
    fail "deleted non-repo skill"
fi

# Test 10: Scripts are executable after sync
if [[ -x "$HERMES_HOME/skills/scripts/test-script.sh" ]]; then
    pass "synced scripts are executable"
else
    fail "synced scripts are not executable"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed, $TESTS total"
[[ "$FAIL" -eq 0 ]] && exit 0 || exit 1
