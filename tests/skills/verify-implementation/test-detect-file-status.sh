#!/usr/bin/env bash
# Test: skills/verify-implementation/scripts/detect-file-status.sh
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
SCRIPT="$REPO_ROOT/skills/verify-implementation/scripts/detect-file-status.sh"

pass=0
fail=0
ok() { pass=$((pass + 1)); echo "  PASS: $1"; }
die() { fail=$((fail + 1)); echo "  FAIL: $1"; }

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

echo "=== test-detect-file-status.sh ==="

# Given: script exists
# When: run with --help
# Then: exits 0, shows usage
output=$("$SCRIPT" --help 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 0 ]] && echo "$output" | grep -q "Usage"; then
  ok "--help flag works"
else
  die "--help flag (rc=$rc)"
fi

# Set up a git repo
cd "$tmpdir"
git init -q
git config user.email "test@test.com"
git config user.name "Test"

# Given: a committed file
echo "tracked content" > tracked.txt
git add tracked.txt
git commit -q -m "add tracked"

output=$("$SCRIPT" tracked.txt 2>&1) && rc=0 || rc=$?
echo "$output" > "$tmpdir/result.json"
if [[ $rc -eq 0 ]]; then
  ok "exits 0 for committed file"
else
  die "exit code for committed file (rc=$rc)"
fi
if python3 -m json.tool "$tmpdir/result.json" >/dev/null 2>&1; then
  ok "output is valid JSON"
else
  die "output is not valid JSON"
fi
status=$(python3 -c "import json; d=json.load(open('$tmpdir/result.json')); print(d['status'])")
if [[ "$status" == "committed" ]]; then
  ok "committed file status is 'committed'"
else
  die "expected committed, got $status"
fi

# Given: a gitignored file on disk
echo "*.log" > .gitignore
git add .gitignore
git commit -q -m "add gitignore"
echo "log data" > app.log

output=$("$SCRIPT" app.log 2>&1) && rc=0 || rc=$?
echo "$output" > "$tmpdir/result2.json"
status=$(python3 -c "import json; d=json.load(open('$tmpdir/result2.json')); print(d['status'])")
if [[ "$status" == "on_disk_gitignored" ]]; then
  ok "gitignored file status is 'on_disk_gitignored'"
else
  die "expected on_disk_gitignored, got $status"
fi

# Given: an untracked file (exists on disk, not tracked, not gitignored)
echo "new content" > untracked.txt

output=$("$SCRIPT" untracked.txt 2>&1) && rc=0 || rc=$?
echo "$output" > "$tmpdir/result2b.json"
if [[ $rc -eq 0 ]]; then
  ok "exits 0 for untracked file"
else
  die "exit code for untracked file (rc=$rc)"
fi
status=$(python3 -c "import json; d=json.load(open('$tmpdir/result2b.json')); print(d['status'])")
if [[ "$status" == "on_disk_untracked" ]]; then
  ok "untracked file status is 'on_disk_untracked'"
else
  die "expected on_disk_untracked, got $status"
fi

# Given: a missing file
output=$("$SCRIPT" nonexistent.txt 2>&1) && rc=0 || rc=$?
echo "$output" > "$tmpdir/result3.json"
if [[ $rc -eq 2 ]]; then
  ok "exits 2 for missing file"
else
  die "expected exit 2 for missing file (rc=$rc)"
fi
status=$(python3 -c "import json; d=json.load(open('$tmpdir/result3.json')); print(d['status'])")
if [[ "$status" == "missing" ]]; then
  ok "missing file status is 'missing'"
else
  die "expected missing, got $status"
fi

# Given: shell metacharacter in path
output=$("$SCRIPT" "/tmp/file;rm" 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 1 ]]; then
  ok "rejects shell metacharacters"
else
  die "expected exit 1 for metacharacters (rc=$rc)"
fi

# Given: no arguments
output=$("$SCRIPT" 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 1 ]]; then
  ok "exits 1 with no arguments"
else
  die "expected exit 1 with no arguments (rc=$rc)"
fi

echo ""
echo "Results: $pass passed, $fail failed"
[[ $fail -eq 0 ]] && exit 0 || exit 1
