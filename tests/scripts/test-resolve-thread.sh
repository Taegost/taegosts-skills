#!/usr/bin/env bash
# test-resolve-thread.sh -- tests for resolve-thread.sh
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SCRIPT="$REPO_ROOT/skills/ts-pr-fix-findings/scripts/resolve-thread.sh"

pass=0
fail=0
ok() { pass=$((pass + 1)); echo "  PASS: $1"; }
die() { fail=$((fail + 1)); echo "  FAIL: $1"; }

echo "=== test-resolve-thread.sh ==="

# --help flag works
output=$("$SCRIPT" --help 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 0 ]] && echo "$output" | grep -q "Usage"; then
  ok "--help flag works"
else
  die "--help flag (rc=$rc)"
fi

# -h flag works
output=$("$SCRIPT" -h 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 0 ]] && echo "$output" | grep -q "Usage"; then
  ok "-h flag works"
else
  die "-h flag (rc=$rc)"
fi

# No arguments exits 1
output=$("$SCRIPT" 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 1 ]] && echo "$output" | grep -q "required"; then
  ok "no arguments exits 1"
else
  die "no arguments (rc=$rc, output=$output)"
fi

# Missing --thread-id exits 1
output=$("$SCRIPT" --pr-url "https://github.com/owner/repo/pull/123" --reviewer alice 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 1 ]] && echo "$output" | grep -q "thread-id"; then
  ok "missing --thread-id exits 1"
else
  die "missing --thread-id (rc=$rc, output=$output)"
fi

# Missing --reviewer exits 1
output=$("$SCRIPT" --pr-url "https://github.com/owner/repo/pull/123" --thread-id "PRRT_test123" 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 1 ]] && echo "$output" | grep -q "reviewer"; then
  ok "missing --reviewer exits 1"
else
  die "missing --reviewer (rc=$rc, output=$output)"
fi

# Shell metacharacters in --pr-url rejected
output=$("$SCRIPT" --pr-url '123;rm -rf /' --thread-id "PRRT_test" --reviewer alice 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 1 ]] && echo "$output" | grep -q "metacharacters"; then
  ok "shell metacharacters in --pr-url rejected"
else
  die "shell metacharacters in --pr-url (rc=$rc, output=$output)"
fi

# Command substitution in --pr-url rejected
output=$("$SCRIPT" --pr-url '123$(whoami)' --thread-id "PRRT_test" --reviewer alice 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 1 ]] && echo "$output" | grep -q "metacharacters"; then
  ok "command substitution in --pr-url rejected"
else
  die "command substitution in --pr-url (rc=$rc, output=$output)"
fi

# Shell metacharacters in --thread-id rejected
output=$("$SCRIPT" --pr-url "https://github.com/owner/repo/pull/123" --thread-id 'PRRT;echo pwned' --reviewer alice 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 1 ]] && echo "$output" | grep -q "metacharacters"; then
  ok "shell metacharacters in --thread-id rejected"
else
  die "shell metacharacters in --thread-id (rc=$rc, output=$output)"
fi

# Shell metacharacters in --reviewer rejected
output=$("$SCRIPT" --pr-url "https://github.com/owner/repo/pull/123" --thread-id "PRRT_test" --reviewer 'alice;rm -rf /' 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 1 ]] && echo "$output" | grep -q "metacharacters"; then
  ok "shell metacharacters in --reviewer rejected"
else
  die "shell metacharacters in --reviewer (rc=$rc, output=$output)"
fi

# Invalid --reviewer format (starts with hyphen) rejected
output=$("$SCRIPT" --pr-url "https://github.com/owner/repo/pull/123" --thread-id "PRRT_test" --reviewer '-alice' 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 1 ]] && echo "$output" | grep -q "invalid format"; then
  ok "invalid --reviewer format (starts with hyphen) rejected"
else
  die "invalid --reviewer format (rc=$rc, output=$output)"
fi

# Invalid --reviewer format (ends with hyphen) rejected
output=$("$SCRIPT" --pr-url "https://github.com/owner/repo/pull/123" --thread-id "PRRT_test" --reviewer 'alice-' 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 1 ]] && echo "$output" | grep -q "invalid format"; then
  ok "invalid --reviewer format (ends with hyphen) rejected"
else
  die "invalid --reviewer format ends hyphen (rc=$rc, output=$output)"
fi

# Invalid --pr-url format rejected
output=$("$SCRIPT" --pr-url "not-a-url" --thread-id "PRRT_test" --reviewer alice 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 1 ]] && echo "$output" | grep -q "must be a GitHub PR URL"; then
  ok "invalid --pr-url format rejected"
else
  die "invalid --pr-url format (rc=$rc, output=$output)"
fi

# Unknown argument exits 1
output=$("$SCRIPT" --pr-url 123 --thread-id "PRRT_test" --reviewer alice --bogus 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 1 ]]; then
  ok "unknown argument exits 1"
else
  die "unknown argument (rc=$rc, output=$output)"
fi

# Valid inputs pass validation (will fail on gh auth, but that's expected)
output=$("$SCRIPT" --pr-url "https://github.com/owner/repo/pull/123" --thread-id "PRRT_test123" --reviewer alice 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 0 ]] || (echo "$output" | grep -q "gh auth\|failed to resolve"); then
  ok "valid inputs pass validation"
else
  die "valid inputs (rc=$rc, output=$output)"
fi

# Valid numeric PR number passes validation
output=$("$SCRIPT" --pr-url "123" --thread-id "PRRT_test123" --reviewer alice 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 0 ]] || (echo "$output" | grep -q "gh auth\|failed to resolve"); then
  ok "valid numeric PR number passes validation"
else
  die "valid numeric PR number (rc=$rc, output=$output)"
fi

# Valid reviewer with hyphens passes validation
output=$("$SCRIPT" --pr-url "https://github.com/owner/repo/pull/123" --thread-id "PRRT_test123" --reviewer 'alice-bob' 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 0 ]] || (echo "$output" | grep -q "gh auth\|failed to resolve"); then
  ok "valid reviewer with hyphens passes validation"
else
  die "valid reviewer with hyphens (rc=$rc, output=$output)"
fi

# Script is executable
if [[ -x "$SCRIPT" ]]; then
  ok "script is executable"
else
  die "script is not executable"
fi

# Script has bash shebang
if head -1 "$SCRIPT" | grep -q "^#!/usr/bin/env bash"; then
  ok "script has bash shebang"
else
  die "script missing bash shebang"
fi

# Script uses set -euo pipefail
if grep -q "set -euo pipefail" "$SCRIPT"; then
  ok "script uses set -euo pipefail"
else
  die "script missing set -euo pipefail"
fi

# Regression: a GraphQL error message containing a double quote must not
# break the emitted JSON error object.
MOCK_DIR="$(mktemp -d)"
cat > "$MOCK_DIR/gh" <<'MOCKEOF'
#!/usr/bin/env bash
if [[ "$1" == "auth" ]]; then
  exit 0
fi
if [[ "$1" == "api" ]]; then
  cat <<'JSONEOF'
{"errors":[{"message":"Could not resolve to a node with the global id of \"BAD_ID\""}]}
JSONEOF
  exit 0
fi
exit 1
MOCKEOF
chmod +x "$MOCK_DIR/gh"
output=$(PATH="$MOCK_DIR:$PATH" "$SCRIPT" --pr-url "https://github.com/owner/repo/pull/123" --thread-id "PRRT_test123" --reviewer alice 2>&1) && rc=0 || rc=$?
rm -rf "$MOCK_DIR"
if [[ $rc -eq 1 ]] && echo "$output" | python3 -c "import json,sys; json.load(sys.stdin)" >/dev/null 2>&1; then
  ok "GraphQL error message with embedded quote produces valid JSON"
else
  die "GraphQL error message with embedded quote (rc=$rc, output=$output)"
fi

echo ""
echo "Results: $pass passed, $fail failed"
[[ $fail -eq 0 ]] && exit 0 || exit 1
