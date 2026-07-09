#!/usr/bin/env bash
# Test: scripts/run-bundled-validator.sh
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/run-bundled-validator.sh"

pass=0
fail=0
ok() { pass=$((pass + 1)); echo "  PASS: $1"; }
die() { fail=$((fail + 1)); echo "  FAIL: $1"; }

echo "=== test-run-bundled-validator.sh ==="

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

# Build a fake skill bundle with a trivial validator script for testing.
# run-bundled-validator.sh always invokes via python3 (its real callers,
# validate-frontmatter.py and validate-doc-claims.py, are both Python), so
# fixtures must be Python too.
mkdir -p "$tmpdir/fake-skill/scripts"
cat > "$tmpdir/fake-skill/scripts/echo-args.py" <<'EOF'
import sys
print("ran with: " + " ".join(sys.argv[1:]))
sys.exit(0)
EOF

cat > "$tmpdir/fake-skill/scripts/fail-with-2.py" <<'EOF'
import sys
sys.exit(7)
EOF

# --help flag works
output=$("$SCRIPT" --help 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 0 ]] && echo "$output" | grep -q "Usage"; then
  ok "--help flag works"
else
  die "--help flag (rc=$rc)"
fi

# Missing --script exits 3 (usage error)
output=$("$SCRIPT" --skill-dir "$tmpdir/fake-skill" 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 3 ]] && echo "$output" | grep -q "\-\-script is required"; then
  ok "missing --script exits 3"
else
  die "missing --script (rc=$rc, output=$output)"
fi

# --skill-dir missing a value exits 3
output=$("$SCRIPT" --skill-dir 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 3 ]]; then
  ok "--skill-dir with no value exits 3"
else
  die "--skill-dir with no value (rc=$rc, output=$output)"
fi

# Unknown flag exits 3
output=$("$SCRIPT" --bogus 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 3 ]] && echo "$output" | grep -q "unknown argument"; then
  ok "unknown flag exits 3"
else
  die "unknown flag (rc=$rc, output=$output)"
fi

# Unresolvable skill-dir exits 2 with a clear notice
output=$("$SCRIPT" --skill-dir "$tmpdir/does-not-exist" --script scripts/echo-args.py 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 2 ]] && echo "$output" | grep -q "not resolvable on this platform"; then
  ok "unresolvable skill-dir exits 2"
else
  die "unresolvable skill-dir (rc=$rc, output=$output)"
fi

# No --skill-dir and no CLAUDE_SKILL_DIR set exits 2
output=$(env -u CLAUDE_SKILL_DIR "$SCRIPT" --script scripts/echo-args.py 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 2 ]]; then
  ok "no skill-dir source at all exits 2"
else
  die "no skill-dir source at all (rc=$rc, output=$output)"
fi

# Resolvable via --skill-dir: runs the script and passes args through
output=$("$SCRIPT" --skill-dir "$tmpdir/fake-skill" --script scripts/echo-args.py -- foo bar 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 0 ]] && echo "$output" | grep -q "ran with: foo bar"; then
  ok "runs resolvable script via --skill-dir and passes args through"
else
  die "runs resolvable script via --skill-dir (rc=$rc, output=$output)"
fi

# Resolvable via $CLAUDE_SKILL_DIR env var (no --skill-dir flag)
output=$(CLAUDE_SKILL_DIR="$tmpdir/fake-skill" "$SCRIPT" --script scripts/echo-args.py -- baz 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 0 ]] && echo "$output" | grep -q "ran with: baz"; then
  ok "runs resolvable script via \$CLAUDE_SKILL_DIR env fallback"
else
  die "runs resolvable script via \$CLAUDE_SKILL_DIR (rc=$rc, output=$output)"
fi

# --skill-dir explicitly passed overrides $CLAUDE_SKILL_DIR
mkdir -p "$tmpdir/other-skill/scripts"
cat > "$tmpdir/other-skill/scripts/echo-args.py" <<'EOF'
print("other-skill ran")
EOF
output=$(CLAUDE_SKILL_DIR="$tmpdir/fake-skill" "$SCRIPT" --skill-dir "$tmpdir/other-skill" --script scripts/echo-args.py 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 0 ]] && echo "$output" | grep -q "other-skill ran"; then
  ok "--skill-dir overrides \$CLAUDE_SKILL_DIR"
else
  die "--skill-dir override (rc=$rc, output=$output)"
fi

# The validator's own exit code propagates (not swallowed into 0/1/2/3)
"$SCRIPT" --skill-dir "$tmpdir/fake-skill" --script scripts/fail-with-2.py >/dev/null 2>&1
rc=$?
if [[ $rc -eq 7 ]]; then
  ok "validator's own exit code propagates unmodified"
else
  die "validator's own exit code propagates (rc=$rc, expected 7)"
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

echo ""
echo "Results: $pass passed, $fail failed"
[[ $fail -eq 0 ]] && exit 0 || exit 1
