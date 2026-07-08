#!/usr/bin/env bash
# test-fetch-review-comments.sh -- tests for fetch-review-comments.sh
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SCRIPT="$REPO_ROOT/skills/ts-pr-fix-findings/scripts/fetch-review-comments.sh"

pass=0
fail=0
ok() { pass=$((pass + 1)); echo "  PASS: $1"; }
die() { fail=$((fail + 1)); echo "  FAIL: $1"; }

echo "=== test-fetch-review-comments.sh ==="

# --help flag works
output=$("$SCRIPT" --help 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 0 ]] && echo "$output" | grep -q "Usage"; then
  ok "--help flag works"
else
  die "--help flag (rc=$rc)"
fi

# No arguments exits 1
output=$("$SCRIPT" 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 1 ]] && echo "$output" | grep -q "required"; then
  ok "no arguments exits 1"
else
  die "no arguments (rc=$rc, output=$output)"
fi

# Missing --pr exits 1
output=$("$SCRIPT" --repo "owner/repo" 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 1 ]]; then
  ok "missing --pr exits 1"
else
  die "missing --pr (rc=$rc, output=$output)"
fi

# Invalid repo format rejected
output=$("$SCRIPT" --repo "invalid" --pr 123 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 1 ]] && echo "$output" | grep -q "owner/repo format"; then
  ok "rejects invalid repo format"
else
  die "rejects invalid repo format (rc=$rc, output=$output)"
fi

# Non-numeric PR rejected
output=$("$SCRIPT" --repo "owner/repo" --pr "abc" 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 1 ]] && echo "$output" | grep -q "must be a number"; then
  ok "rejects non-numeric PR"
else
  die "rejects non-numeric PR (rc=$rc, output=$output)"
fi

# Shell metacharacters in --repo rejected
output=$("$SCRIPT" --repo 'owner/repo;rm -rf /' --pr 123 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 1 ]] && echo "$output" | grep -q "metacharacters"; then
  ok "rejects metacharacters in --repo"
else
  die "rejects metacharacters in --repo (rc=$rc, output=$output)"
fi

# Shell metacharacters in --pr rejected
output=$("$SCRIPT" --repo "owner/repo" --pr '123;echo pwned' 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 1 ]] && echo "$output" | grep -q "metacharacters"; then
  ok "rejects metacharacters in --pr"
else
  die "rejects metacharacters in --pr (rc=$rc, output=$output)"
fi

# JSON error format
output=$("$SCRIPT" 2>&1) && rc=0 || rc=$?
if echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['ok'] is False" >/dev/null 2>&1; then
  ok "JSON error format"
else
  die "JSON error format (output=$output)"
fi

# Unknown argument exits 1
output=$("$SCRIPT" --repo "owner/repo" --pr 123 --bogus 2>&1) && rc=0 || rc=$?
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

# Mocked gh: successful fetch flattens threads into per-comment records with
# path/line/resolved inherited from the containing thread.
MOCK_DIR="$(mktemp -d)"
cat > "$MOCK_DIR/gh" <<'MOCKEOF'
#!/usr/bin/env bash
if [[ "$1" == "auth" ]]; then
  exit 0
fi
if [[ "$1" == "api" ]]; then
  echo '[{"id":111,"path":"src/foo.rb","line":42,"author":"alice","body":"fix this","resolved":false,"thread_id":"PRRT_a"}]'
  exit 0
fi
exit 1
MOCKEOF
chmod +x "$MOCK_DIR/gh"
output=$(PATH="$MOCK_DIR:$PATH" "$SCRIPT" --repo "owner/repo" --pr 123 2>&1) && rc=0 || rc=$?
rm -rf "$MOCK_DIR"
if [[ $rc -eq 0 ]] && echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert isinstance(d, list) and len(d) == 1
c = d[0]
assert c['path'] == 'src/foo.rb'
assert c['line'] == 42
assert c['resolved'] is False
assert c['thread_id'] == 'PRRT_a'
" >/dev/null 2>&1; then
  ok "flattens thread comments with path/line/resolved/thread_id"
else
  die "flattens thread comments (rc=$rc, output=$output)"
fi

echo ""
echo "Results: $pass passed, $fail failed"
[[ $fail -eq 0 ]] && exit 0 || exit 1
