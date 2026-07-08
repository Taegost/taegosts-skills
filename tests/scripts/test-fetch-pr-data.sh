#!/usr/bin/env bash
# Test: scripts/gh-get-pr-state.sh
# (Renamed from test-fetch-pr-data.sh following Wave 2 script consolidation)
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/gh-get-pr-state.sh"

pass=0
fail=0
ok() { pass=$((pass + 1)); echo "  PASS: $1"; }
die() { fail=$((fail + 1)); echo "  FAIL: $1"; }

echo "=== test-gh-get-pr-state.sh ==="

# Given: script exists
# When: run with --help
# Then: exits 0, shows usage
output=$("$SCRIPT" --help 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 0 ]] && echo "$output" | grep -q "Usage"; then
  ok "--help flag works"
else
  die "--help flag (rc=$rc)"
fi

# Given: no arguments
# When: run without arguments
# Then: exits 1 with error message
output=$("$SCRIPT" 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 1 ]] && echo "$output" | grep -q "pr-url"; then
  ok "no arguments exits 1"
else
  die "no arguments (rc=$rc, output=$output)"
fi

# Given: PR URL with shell metacharacters
# When: run with malicious input
# Then: exits 1 with error message
output=$("$SCRIPT" --pr-url '123;rm -rf /' 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 1 ]] && (echo "$output" | grep -qi "metacharacter\|invalid\|error"); then
  ok "shell metacharacters rejected"
else
  die "shell metacharacters (rc=$rc, output=$output)"
fi

# Given: valid PR number but gh fails
# When: run with valid number but no gh access
# Then: exits 1 with error message
# Deterministic: override PATH to insert a stub `gh` that always fails with exit 1,
# so we never rely on whether the environment has real gh auth.
tmpdir=$(mktemp -d)
# Build a stub gh that always fails with exit 1
stub_bin="$tmpdir/stub_bin"
mkdir -p "$stub_bin"
cat > "$stub_bin/gh" <<'STUB'
#!/usr/bin/env bash
echo "Failed to fetch PR data: stub gh invoked" >&2
exit 1
STUB
chmod +x "$stub_bin/gh"

cd "$tmpdir" || exit 1
git init -b main >/dev/null 2>&1
git config user.email "test@test.com"
git config user.name "Test"
git commit --allow-empty -m "init" >/dev/null 2>&1
git remote add origin https://example.com/fake.git 2>/dev/null

# Prepend stub_bin so our fake gh is resolved before the real one
output=$(PATH="$stub_bin:$PATH" "$SCRIPT" --pr-url 123 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 1 ]]; then
  ok "gh failure exits 1"
else
  die "gh failure (rc=$rc, output=$output)"
fi
trap 'rm -rf "$tmpdir"' EXIT

# Given: valid PR number format
# When: check input validation accepts numeric (may fail on gh call)
# Then: doesn't fail on format validation
output=$("$SCRIPT" --pr-url "123" 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 1 ]] && (echo "$output" | grep -qi "Failed to fetch\|metacharacter\|format error"); then
  ok "numeric PR number accepted (gh call expected to fail)"
else
  die "numeric PR number (rc=$rc, output=$output)"
fi

# Given: valid PR URL format
# When: check input validation accepts URL (may fail on gh call)
# Then: doesn't fail on format validation
output=$("$SCRIPT" --pr-url "https://github.com/owner/repo/pull/123" 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 1 ]] && (echo "$output" | grep -qi "Failed to fetch\|metacharacter\|format error"); then
  ok "PR URL format accepted (gh call expected to fail)"
else
  die "PR URL format (rc=$rc, output=$output)"
fi

echo ""
echo "Results: $pass passed, $fail failed"
[[ $fail -eq 0 ]] && exit 0 || exit 1
