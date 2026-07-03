#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
SCRIPT="$REPO_ROOT/skills/ts-pr-fix-findings/scripts/check-thread-resolution.sh"
pass=0 fail=0

echo "=== U17: check-thread-resolution.sh ==="

# Helper
ok() { echo "PASS: $1"; pass=$((pass+1)); }
die() { echo "FAIL: $1"; fail=$((fail+1)); }

output=$("$SCRIPT" --help 2>&1)
if echo "$output" | grep -q "Usage:"; then ok "--help"
else die "--help"; fi

# Missing args
output=$("$SCRIPT" 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 1 ]]; then ok "rejects missing args"
else die "rejects missing args (rc=$rc)"; fi

# Invalid repo format
output=$("$SCRIPT" --repo "invalid" --pr 123 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 1 ]]; then ok "rejects invalid repo format"
else die "rejects invalid repo format (rc=$rc)"; fi

# Non-numeric PR
output=$("$SCRIPT" --repo "owner/repo" --pr "abc" 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 1 ]]; then ok "rejects non-numeric PR"
else die "rejects non-numeric PR (rc=$rc)"; fi

# Metacharacters in repo
output=$("$SCRIPT" --repo "owner/repo;id" --pr 123 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 1 ]]; then ok "rejects metacharacters in repo"
else die "rejects metacharacters in repo (rc=$rc)"; fi

# Metacharacters in PR
output=$("$SCRIPT" --repo "owner/repo" --pr "123;id" 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 1 ]]; then ok "rejects metacharacters in PR"
else die "rejects metacharacters in PR (rc=$rc)"; fi

# JSON error format
output=$("$SCRIPT" 2>&1) && rc=0 || rc=$?
if echo "$output" | grep -q '"ok":false'; then ok "JSON error format"
else die "JSON error format"; fi

# Unknown argument
output=$("$SCRIPT" --repo "owner/repo" --pr 123 --bogus 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 1 ]]; then ok "rejects unknown argument"
else die "rejects unknown argument (rc=$rc)"; fi

echo "Results: $pass passed, $fail failed"
[[ $fail -eq 0 ]] && exit 0 || exit 1
