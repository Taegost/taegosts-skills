#!/usr/bin/env bash
# Test: scripts/run-test-suites.sh (plan unit U4, scenarios b-e)
#
# Covers the documented runner contract against tmpdir fixture trees built
# around a copy of the real runner (REPO_ROOT derives from BASH_SOURCE, so a
# copied runner discovers its own fixture tree):
#   (b) one intentionally failing suite -> exit 1, remaining suites still run
#   (c) all-green fixture tree -> exit 0
#   (d) tests/baselines/ files are never discovered
#   (e) the runner's own --help exits 0 and prints usage
# Plan scenario (a) — a real-repo run of every discovered suite — is deferred
# until the fleet is green (U4 Sequencing note: suites are red before U3).
#
# One addition beyond the plan's declared scenarios, flagged for review: the
# documented exit code 2 (bats missing while .bats files were discovered).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
RUNNER="$REPO_ROOT/scripts/run-test-suites.sh"

pass=0
fail=0
ok() { pass=$((pass + 1)); echo "  PASS: $1"; }
die() { fail=$((fail + 1)); echo "  FAIL: $1"; }

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

echo "=== test-run-test-suites.sh ==="

# Given: the aggregate runner exists in the repo
# When: resolving the script under test
# Then: the file is present
if [[ -f "$RUNNER" ]]; then
  ok "runner exists at scripts/run-test-suites.sh"
else
  die "runner exists at scripts/run-test-suites.sh (missing: $RUNNER)"
fi

# bats may be absent; fixture trees only include a .bats file when it can run.
bats_bin=""
if command -v bats >/dev/null 2>&1; then
  bats_bin="$(command -v bats)"
fi

# ---------------------------------------------------------------------------
# Scenario (e): the runner's own --help exits 0
# ---------------------------------------------------------------------------
help_output=$(bash "$RUNNER" --help 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 0 ]] && grep -q "^Usage:" <<< "$help_output"; then
  ok "(e) --help exits 0 and prints usage"
else
  die "(e) --help exits 0 and prints usage (rc=$rc)"
fi

h_output=$(bash "$RUNNER" -h 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 0 ]] && grep -q "^Usage:" <<< "$h_output"; then
  ok "(e) -h exits 0 and prints usage"
else
  die "(e) -h exits 0 and prints usage (rc=$rc)"
fi

if ! grep -q "^Results:" <<< "$help_output"; then
  ok "(e) --help runs no suites (no Results line in help output)"
else
  die "(e) --help runs no suites (Results line in help output)"
fi

# ---------------------------------------------------------------------------
# Scenario (b): one failing suite -> exit 1, remaining suites still run
# ---------------------------------------------------------------------------
failtree="$tmpdir/failtree"
mkdir -p "$failtree/scripts" "$failtree/tests/scripts" "$failtree/tests/skills/fake-skill"
cp "$RUNNER" "$failtree/scripts/run-test-suites.sh"

marker="$failtree/marker-b2-ran"
# test-a1-fail.sh sorts before the passing suites: if the runner aborted on
# first failure, the PASS lines and side effect below could never appear.
cat > "$failtree/tests/scripts/test-a1-fail.sh" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "deliberate failure"
exit 1
EOF
cat > "$failtree/tests/scripts/test-b2-pass.sh" << EOF
#!/usr/bin/env bash
set -euo pipefail
: > "$marker"
EOF
cat > "$failtree/tests/skills/fake-skill/test-c3-pass.sh" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
:
EOF

expected_pass=2
if [[ -n "$bats_bin" ]]; then
  cat > "$failtree/tests/scripts/fixture-green.bats" << 'EOF'
@test "fixture green" {
  true
}
EOF
  expected_pass=3
fi

out=$(bash "$failtree/scripts/run-test-suites.sh" 2>&1) && rc=0 || rc=$?

if [[ $rc -eq 1 ]]; then
  ok "(b) failing tree exits 1"
else
  die "(b) failing tree exits 1 (rc=$rc)"
fi

if [[ -f "$marker" ]]; then
  ok "(b) suite after the failure still ran (side effect present)"
else
  die "(b) suite after the failure still ran (marker missing)"
fi

if grep -q "^FAIL: tests/scripts/test-a1-fail.sh" <<< "$out"; then
  ok "(b) failing suite reported as FAIL"
else
  die "(b) failing suite reported as FAIL"
fi

if grep -q "^PASS: tests/scripts/test-b2-pass.sh" <<< "$out"; then
  ok "(b) remaining tests/scripts suite reported as PASS"
else
  die "(b) remaining tests/scripts suite reported as PASS"
fi

if grep -q "^PASS: tests/skills/fake-skill/test-c3-pass.sh" <<< "$out"; then
  ok "(b) remaining tests/skills suite reported as PASS"
else
  die "(b) remaining tests/skills suite reported as PASS"
fi

if grep -Fxq "Results: $expected_pass passed, 1 failed" <<< "$out"; then
  ok "(b) summary counts $expected_pass passed, 1 failed"
else
  die "(b) summary counts $expected_pass passed, 1 failed"
fi

# ---------------------------------------------------------------------------
# Scenario (c): all-green fixture tree exits 0
# ---------------------------------------------------------------------------
greentree="$tmpdir/greentree"
mkdir -p "$greentree/scripts" "$greentree/tests/scripts" "$greentree/tests/skills/fake-skill"
cp "$RUNNER" "$greentree/scripts/run-test-suites.sh"

cat > "$greentree/tests/scripts/test-green-one.sh" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
:
EOF
cat > "$greentree/tests/skills/fake-skill/test-green-two.sh" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
:
EOF

expected_pass=2
if [[ -n "$bats_bin" ]]; then
  cat > "$greentree/tests/scripts/fixture-green.bats" << 'EOF'
@test "fixture green" {
  true
}
EOF
  expected_pass=3
fi

# Run from an unrelated cwd: discovery is repo-relative to the copied runner.
out=$(cd "$tmpdir" && bash "$greentree/scripts/run-test-suites.sh" 2>&1) && rc=0 || rc=$?

if [[ $rc -eq 0 ]]; then
  ok "(c) all-green tree exits 0"
else
  die "(c) all-green tree exits 0 (rc=$rc)"
fi

if grep -Fxq "Results: $expected_pass passed, 0 failed" <<< "$out"; then
  ok "(c) summary counts $expected_pass passed, 0 failed"
else
  die "(c) summary counts $expected_pass passed, 0 failed"
fi

if grep -q "^PASS: tests/skills/fake-skill/test-green-two.sh" <<< "$out"; then
  ok "(c) tests/skills suite discovered and run from unrelated cwd"
else
  die "(c) tests/skills suite discovered and run from unrelated cwd"
fi

# ---------------------------------------------------------------------------
# Scenario (d): tests/baselines/ files are never discovered
# ---------------------------------------------------------------------------
basetree="$tmpdir/baselines-tree"
mkdir -p "$basetree/scripts" "$basetree/tests/scripts" "$basetree/tests/baselines"
cp "$RUNNER" "$basetree/scripts/run-test-suites.sh"

# Canary: exits 1, so the tree would go red if baselines were ever discovered.
cat > "$basetree/tests/baselines/test-word-counts.sh" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "baseline canary must never run"
exit 1
EOF
cat > "$basetree/tests/scripts/test-real-pass.sh" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
:
EOF

out=$(bash "$basetree/scripts/run-test-suites.sh" 2>&1) && rc=0 || rc=$?

if [[ $rc -eq 0 ]]; then
  ok "(d) baselines canary not run (tree exits 0)"
else
  die "(d) baselines canary not run (rc=$rc)"
fi

if grep -Fxq "=== run-test-suites.sh: 1 bash suite(s), 0 bats file(s) ===" <<< "$out"; then
  ok "(d) discovery counts only the real suite"
else
  die "(d) discovery counts only the real suite"
fi

if ! grep -q "baselines" <<< "$out"; then
  ok "(d) output never mentions baselines"
else
  die "(d) output never mentions baselines"
fi

# ---------------------------------------------------------------------------
# Addition beyond the plan's declared scenarios (flagged for review):
# documented exit code 2 — bats missing while .bats files were discovered.
# ---------------------------------------------------------------------------
if [[ -n "$bats_bin" ]]; then
  nobats_tree="$tmpdir/nobats-tree"
  mkdir -p "$nobats_tree/scripts" "$nobats_tree/tests/scripts"
  cp "$RUNNER" "$nobats_tree/scripts/run-test-suites.sh"

  cat > "$nobats_tree/tests/scripts/test-green-one.sh" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
:
EOF
  cat > "$nobats_tree/tests/scripts/fixture-green.bats" << 'EOF'
@test "fixture green" {
  true
}
EOF

  # Hide bats by restricting PATH to a bin dir holding only what the runner
  # needs before its bats check (bash, dirname); everything else is a builtin.
  hiddenbin="$tmpdir/nobats-bin"
  mkdir -p "$hiddenbin"
  ln -s "$(command -v bash)" "$hiddenbin/bash"
  ln -s "$(command -v dirname)" "$hiddenbin/dirname"

  out=$(PATH="$hiddenbin" "$hiddenbin/bash" "$nobats_tree/scripts/run-test-suites.sh" 2>&1) && rc=0 || rc=$?

  if [[ $rc -eq 2 ]]; then
    ok "(addition) bats missing with .bats discovered exits 2"
  else
    die "(addition) bats missing with .bats discovered exits 2 (rc=$rc)"
  fi

  if grep -q "bats is not installed" <<< "$out"; then
    ok "(addition) abort message names the missing tool"
  else
    die "(addition) abort message names the missing tool"
  fi

  if grep -q "tests/scripts/fixture-green.bats" <<< "$out"; then
    ok "(addition) abort lists the discovered .bats file"
  else
    die "(addition) abort lists the discovered .bats file"
  fi
else
  echo "  SKIP: (addition) exit-code-2 check — bats not installed, so the condition cannot be produced"
fi

echo ""
echo "Results: $pass passed, $fail failed"
[[ $fail -eq 0 ]] && exit 0 || exit 1
