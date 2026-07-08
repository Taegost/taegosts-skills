#!/usr/bin/env bash
# test-post-pr-comment.sh -- tests for post-pr-comment.sh
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SCRIPT="$REPO_ROOT/skills/ts-pr-fix-findings/scripts/post-pr-comment.sh"

pass=0
fail=0
ok() { pass=$((pass + 1)); echo "  PASS: $1"; }
die() { fail=$((fail + 1)); echo "  FAIL: $1"; }

echo "=== test-post-pr-comment.sh ==="

# --help flag works
output=$("$SCRIPT" --help 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 0 ]] && echo "$output" | grep -q "Usage"; then
  ok "--help flag works"
else
  die "--help flag (rc=$rc)"
fi

# No arguments exits 1
output=$("$SCRIPT" 2>&1 < /dev/null) && rc=0 || rc=$?
if [[ $rc -eq 1 ]] && echo "$output" | grep -q "required"; then
  ok "no arguments exits 1"
else
  die "no arguments (rc=$rc, output=$output)"
fi

# Missing --pr exits 1
output=$("$SCRIPT" --repo "owner/repo" --body "hi" 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 1 ]]; then
  ok "missing --pr exits 1"
else
  die "missing --pr (rc=$rc, output=$output)"
fi

# No --body and no stdin (terminal-like: empty pipe simulates closed stdin) exits 1
output=$("$SCRIPT" --repo "owner/repo" --pr 123 < /dev/null 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 1 ]] && echo "$output" | grep -qi "body"; then
  ok "empty stdin with no --body rejected"
else
  die "empty stdin with no --body (rc=$rc, output=$output)"
fi

# Body via stdin is accepted (validation-only check: fails later on gh auth, not on body handling)
output=$(echo "comment text" | "$SCRIPT" --repo "owner/repo" --pr 123 2>&1) && rc=0 || rc=$?
if echo "$output" | grep -q "gh auth\|failed to post comment"; then
  ok "body via stdin accepted, fails downstream on gh auth as expected"
else
  die "body via stdin (rc=$rc, output=$output)"
fi

# Empty --body rejected
output=$("$SCRIPT" --repo "owner/repo" --pr 123 --body "" < /dev/null 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 1 ]] && echo "$output" | grep -q "empty"; then
  ok "rejects empty --body"
else
  die "rejects empty --body (rc=$rc, output=$output)"
fi

# Invalid repo format rejected
output=$("$SCRIPT" --repo "invalid" --pr 123 --body "hi" < /dev/null 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 1 ]] && echo "$output" | grep -q "owner/repo format"; then
  ok "rejects invalid repo format"
else
  die "rejects invalid repo format (rc=$rc, output=$output)"
fi

# Non-numeric PR rejected
output=$("$SCRIPT" --repo "owner/repo" --pr "abc" --body "hi" < /dev/null 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 1 ]] && echo "$output" | grep -q "must be a number"; then
  ok "rejects non-numeric PR"
else
  die "rejects non-numeric PR (rc=$rc, output=$output)"
fi

# Shell metacharacters in --repo rejected
output=$("$SCRIPT" --repo 'owner/repo;rm -rf /' --pr 123 --body "hi" < /dev/null 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 1 ]] && echo "$output" | grep -q "metacharacters"; then
  ok "rejects metacharacters in --repo"
else
  die "rejects metacharacters in --repo (rc=$rc, output=$output)"
fi

# Shell metacharacters in --pr rejected
output=$("$SCRIPT" --repo "owner/repo" --pr '123;echo pwned' --body "hi" < /dev/null 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 1 ]] && echo "$output" | grep -q "metacharacters"; then
  ok "rejects metacharacters in --pr"
else
  die "rejects metacharacters in --pr (rc=$rc, output=$output)"
fi

# Comment body is NOT subject to the metacharacter filter (it travels via -f,
# not shell interpolation) -- shell-special characters in the body must pass
# validation and only fail later on gh auth.
output=$("$SCRIPT" --repo "owner/repo" --pr 123 --body 'Fix; also see `foo` && bar || baz' < /dev/null 2>&1) && rc=0 || rc=$?
if echo "$output" | grep -q "gh auth\|failed to post comment"; then
  ok "comment body is not restricted by the metacharacter filter"
else
  die "comment body should reach gh auth check, not be rejected (rc=$rc, output=$output)"
fi

# Unknown argument exits 1
output=$("$SCRIPT" --repo "owner/repo" --pr 123 --body "hi" --bogus < /dev/null 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 1 ]]; then
  ok "rejects unknown argument"
else
  die "rejects unknown argument (rc=$rc)"
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

# Mocked gh: successful post returns {success:true,url:...}
MOCK_DIR="$(mktemp -d)"
cat > "$MOCK_DIR/gh" <<'MOCKEOF'
#!/usr/bin/env bash
if [[ "$1" == "auth" ]]; then
  exit 0
fi
if [[ "$1" == "api" ]]; then
  echo "https://github.com/owner/repo/pull/123#issuecomment-999"
  exit 0
fi
exit 1
MOCKEOF
chmod +x "$MOCK_DIR/gh"
output=$(echo "done" | PATH="$MOCK_DIR:$PATH" "$SCRIPT" --repo "owner/repo" --pr 123 2>&1) && rc=0 || rc=$?
rm -rf "$MOCK_DIR"
if [[ $rc -eq 0 ]] && echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert d['success'] is True
assert d['url'] == 'https://github.com/owner/repo/pull/123#issuecomment-999'
" >/dev/null 2>&1; then
  ok "successful post returns success:true with comment url"
else
  die "successful post (rc=$rc, output=$output)"
fi

echo ""
echo "Results: $pass passed, $fail failed"
[[ $fail -eq 0 ]] && exit 0 || exit 1
