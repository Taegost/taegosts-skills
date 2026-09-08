#!/usr/bin/env bash
# Test: tests for scripts/verify-scripts.sh — scope classification, lib exemption, rel-path output
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/verify-scripts.sh"
pass=0 fail=0
ok() { pass=$((pass + 1)); echo "  PASS: $1"; }
die() { fail=$((fail + 1)); echo "  FAIL: $1"; }

tmpdir=$(mktemp -d)
cleanup() { rm -rf "$tmpdir"; }
trap cleanup EXIT
echo "=== test-verify-scripts.sh ==="

# --help
output=$("$SCRIPT" --help 2>&1)
if echo "$output" | grep -q "Usage:"; then ok "--help"; else die "--help"; fi

# good .sh
echo "#!/bin/bash" > "$tmpdir/good.sh" && chmod +x "$tmpdir/good.sh"
echo "# help text with --help" >> "$tmpdir/good.sh"
if "$SCRIPT" --file "$tmpdir/good.sh" >/dev/null 2>&1; then ok "good .sh"; else die "good .sh"; fi

# bad .sh (syntax error)
echo "if then else" > "$tmpdir/bad.sh"
if "$SCRIPT" --file "$tmpdir/bad.sh" >/dev/null 2>&1; then die "bad .sh"; else ok "bad .sh fails"; fi

# good .py
echo "#!/usr/bin/env python3" > "$tmpdir/good.py" && chmod +x "$tmpdir/good.py"
echo "# --help" >> "$tmpdir/good.py"
echo "print(42)" >> "$tmpdir/good.py"
if "$SCRIPT" --file "$tmpdir/good.py" >/dev/null 2>&1; then ok "good .py"; else die "good .py"; fi

# bad .py (syntax error)
echo "def foo(" > "$tmpdir/bad.py"
if "$SCRIPT" --file "$tmpdir/bad.py" >/dev/null 2>&1; then die "bad .py"; else ok "bad .py fails"; fi

# unsupported extension
echo "content" > "$tmpdir/test.md"
output=$("$SCRIPT" --file "$tmpdir/test.md" 2>&1)
if echo "$output" | grep -q "0 passed"; then ok "unsupported ext skipped"; else die "unsupported ext"; fi

# --all mode (rc may be 0 or 1 depending on scanned scripts — assert output + valid rc)
output=$("$SCRIPT" --all 2>&1) && rc=0 || rc=$?
if [[ $rc -le 1 ]] && echo "$output" | grep -q "checking"; then ok "--all mode"; else die "--all mode (rc=$rc)"; fi

# dir arg (same — valid rc range + output presence)
output=$("$SCRIPT" "$REPO_ROOT/scripts" 2>&1) && rc=0 || rc=$?
if [[ $rc -le 1 ]] && echo "$output" | grep -q "passed"; then ok "dir arg"; else die "dir arg (rc=$rc)"; fi

# syntax-error file should not count as passed
echo "#!/bin/bash" > "$tmpdir/mixed.sh" && chmod +x "$tmpdir/mixed.sh"
echo "# --help" >> "$tmpdir/mixed.sh"
echo "if then" >> "$tmpdir/mixed.sh"
output=$("$SCRIPT" --file "$tmpdir/mixed.sh" 2>&1)
if echo "$output" | grep -q "0 passed"; then
  ok "syntax failure doesn't count as passed"
else
  die "syntax failure counted as passed"
fi

# .py with control characters should fail
printf '#!/usr/bin/env python3\n# --help\nprint(42)\x07' > "$tmpdir/ctrl.py" && chmod +x "$tmpdir/ctrl.py"
if "$SCRIPT" --file "$tmpdir/ctrl.py" >/dev/null 2>&1; then die ".py control chars"; else ok ".py control chars caught"; fi

# --file without path should error
if "$SCRIPT" --file 2>/dev/null; then die "--file without path"; else ok "--file without path errors"; fi

# unknown flag should error
if "$SCRIPT" --bogus 2>/dev/null; then die "--bogus"; else ok "--bogus errors"; fi

# ---------------------------------------------------------------------
# Scope classification (plan U1 scenarios a–f): a standalone fixture tree
# outside the repo. The gate infers the fixture tree root from tests/ and
# scripts/lib/ path segments, so repo-relative classification applies to
# fixtures the same way it does inside the repo.
# ---------------------------------------------------------------------
fix="$tmpdir/fixture"
mkdir -p "$fix/tests" "$fix/scripts/lib" "$fix/scripts/alpha" "$fix/scripts/beta"
printf '#!/bin/bash\necho hi\n' > "$fix/tests/missing-help-test.sh"          # (a),(f): non-exec, no --help
printf '#!/bin/bash\nlib_fn() { echo x; }\n' > "$fix/scripts/lib/helper.sh"  # (b): non-exec, no --help, valid
printf 'if then\n' > "$fix/scripts/lib/broken.sh"                            # (c): syntax error
printf '#!/bin/bash\necho tool\n' > "$fix/scripts/tool.sh"                   # (d): command script, no --help
chmod +x "$fix/scripts/tool.sh"
printf '#!/bin/bash\n# --help\necho dup\n' > "$fix/scripts/alpha/dup.sh"     # (e): compliant basename twin
chmod +x "$fix/scripts/alpha/dup.sh"
printf '#!/bin/bash\necho dup\n' > "$fix/scripts/beta/dup.sh"                # (e): failing basename twin
chmod +x "$fix/scripts/beta/dup.sh"

# One dir-mode run over the fixture tree, shared by scenarios (a), (d), (e).
dir_output=$(bash "$SCRIPT" "$fix" 2>&1) && dir_rc=0 || dir_rc=$?

# (a) a --help-less non-executable file under tests/ is not flagged in dir mode:
# it is still enumerated (classification happens at check time), reported in the
# out-of-scope summary, and never appears as a failure.
if [[ $dir_rc -eq 1 ]] \
   && echo "$dir_output" | grep -q "checking 6 files" \
   && ! echo "$dir_output" | grep -q "missing-help-test" \
   && echo "$dir_output" | grep -q "Out of scope (tests/, not checked): 1 file(s) skipped"; then
  ok "(a) tests/ file scanned but not flagged, counted as skipped"
else
  die "(a) tests/ file not skipped in dir mode (rc=$dir_rc)"
fi

# (d) a command script (not under scripts/lib/) missing --help still fails
if echo "$dir_output" | grep -q "FAIL: scripts/tool.sh: missing --help flag" \
   && ! echo "$dir_output" | grep -q "FAIL: scripts/tool.sh: not executable"; then
  ok "(d) command script missing --help still fails"
else
  die "(d) command script missing --help not flagged"
fi

# (e) failure lines carry the repo-relative path, not the bare basename; the
# compliant basename twin (scripts/alpha/dup.sh) is not flagged
if echo "$dir_output" | grep -q "FAIL: scripts/beta/dup.sh: missing --help flag" \
   && ! echo "$dir_output" | grep -q "FAIL: dup.sh:" \
   && ! echo "$dir_output" | grep -q "FAIL: scripts/alpha/dup.sh"; then
  ok "(e) failures report repo-relative paths, duplicate basenames disambiguated"
else
  die "(e) failure output does not use repo-relative paths"
fi

# (b) a scripts/lib/ file missing both --help and the exec bit passes when
# syntactically valid — command checks are exempt, syntax checks retained
output=$(bash "$SCRIPT" --file "$fix/scripts/lib/helper.sh" 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 0 ]] && echo "$output" | grep -q "1 passed"; then
  ok "(b) scripts/lib/ exempt from --help and exec-bit checks"
else
  die "(b) scripts/lib/ exemption not applied (rc=$rc)"
fi

# (c) a scripts/lib/ file with a syntax error still fails
output=$(bash "$SCRIPT" --file "$fix/scripts/lib/broken.sh" 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 1 ]] && echo "$output" | grep -q "FAIL: scripts/lib/broken.sh: bash syntax error"; then
  ok "(c) scripts/lib/ syntax error still fails"
else
  die "(c) scripts/lib/ syntax error not caught (rc=$rc)"
fi

# (f) --file on a test file reports it as out of scope and exits 0; the skip is
# not counted as passed
output=$(bash "$SCRIPT" --file "$fix/tests/missing-help-test.sh" 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 0 ]] \
   && echo "$output" | grep -q "SKIP: tests/missing-help-test.sh (out of scope: test scripts are not checked)" \
   && echo "$output" | grep -q "0 passed"; then
  ok "(f) --file on a test file reports out of scope, exits 0"
else
  die "(f) --file out-of-scope report wrong (rc=$rc)"
fi

echo ""
echo "Results: $pass passed, $fail failed"
if [[ $fail -eq 0 ]]; then
  exit 0
else
  exit 1
fi
