#!/usr/bin/env bash
# Test: skills/ce-work/scripts/find-precommit-hook.sh
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
SCRIPT="$REPO_ROOT/skills/ce-work/scripts/find-precommit-hook.sh"

pass=0
fail=0
ok() { pass=$((pass + 1)); echo "  PASS: $1"; }
die() { fail=$((fail + 1)); echo "  FAIL: $1"; }

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

echo "=== test-find-precommit-hook.sh ==="

# Given: script exists
# When: run with --help
# Then: exits 0, shows usage
output=$("$SCRIPT" --help 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 0 ]] && echo "$output" | grep -q "Usage"; then
  ok "--help flag works"
else
  die "--help flag (rc=$rc)"
fi

# Given: a git repo with .git/hooks/pre-commit
mkdir -p "$tmpdir/repo/.git/hooks"
cd "$tmpdir/repo"
git init -q
cat > .git/hooks/pre-commit << 'HOOKEOF'
#!/bin/bash
echo "running pre-commit"
HOOKEOF
chmod +x .git/hooks/pre-commit

output=$(bash "$SCRIPT" 2>&1) && rc=0 || rc=$?
echo "$output" > "$tmpdir/result1.json"
if [[ $rc -eq 0 ]] && python3 -m json.tool "$tmpdir/result1.json" >/dev/null 2>&1; then
  ok "exits 0 and outputs valid JSON when hook exists"
else
  die "exits 0 and valid JSON (rc=$rc)"
fi

hook_path=$(python3 -c "import json,sys; d=json.load(open('$tmpdir/result1.json')); print(d.get('hook_path',''))")
if [[ -n "$hook_path" ]] && [[ "$hook_path" == *pre-commit* ]]; then
  ok "hook_path contains pre-commit"
else
  die "hook_path=$hook_path does not contain pre-commit"
fi

# Given: .githooks/pre-commit
rm -f .git/hooks/pre-commit
mkdir -p .githooks
cat > .githooks/pre-commit << 'HOOKEOF'
#!/bin/bash
echo "githooks pre-commit"
HOOKEOF
chmod +x .githooks/pre-commit

output=$(bash "$SCRIPT" 2>&1) && rc=0 || rc=$?
echo "$output" > "$tmpdir/result2.json"
if [[ $rc -eq 0 ]]; then
  ok "finds .githooks/pre-commit"
else
  die "did not find .githooks/pre-commit (rc=$rc)"
fi

# Given: no pre-commit hook
rm -rf .git/hooks/pre-commit .githooks/pre-commit
output=$(bash "$SCRIPT" 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 2 ]]; then
  ok "exits 2 when no hook found"
else
  die "expected exit 2 for no hook (rc=$rc)"
fi

# Given: not in a git repo
cd "$tmpdir"
output=$(bash "$SCRIPT" 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 1 ]]; then
  ok "exits 1 when not in git repo"
else
  die "expected exit 1 outside git repo (rc=$rc)"
fi

echo ""
echo "Results: $pass passed, $fail failed"
[[ $fail -eq 0 ]] && exit 0 || exit 1
