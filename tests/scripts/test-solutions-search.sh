#!/usr/bin/env bash
# Test: scripts/solutions-search.sh
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/solutions-search.sh"
# Create temp fixture instead of relying on external repo
FIXTURE_DIR=$(mktemp -d)
mkdir -p "$FIXTURE_DIR/docs/solutions/conventions" "$FIXTURE_DIR/docs/solutions/runtime-errors"
cat > "$FIXTURE_DIR/docs/solutions/conventions/valkey-pattern.md" << 'FIXTURE'
---
title: "Valkey Cache Auth Pattern"
tags: [valkey, redis, cache, networkpolicy]
module: homelab
---
Run Valkey without auth, use NetworkPolicy for namespace isolation.
FIXTURE
cat > "$FIXTURE_DIR/docs/solutions/runtime-errors/longhorn-mount.md" << 'FIXTURE'
---
title: "Longhorn PVC Mount Failures"
tags: [longhorn, storage, multipathd]
module: longhorn
---
multipathd claims iSCSI devices via device-mapper.
FIXTURE
SOLUTIONS_DIR="$FIXTURE_DIR/docs/solutions"

pass=0
fail=0
ok() { pass=$((pass + 1)); echo "  PASS: $1"; }
die() { fail=$((fail + 1)); echo "  FAIL: $1"; }

echo "=== test-solutions-search.sh ==="

# Given: script exists
# When: run with --help
# Then: exits 0, shows usage
output=$("$SCRIPT" --help 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 0 ]] && echo "$output" | grep -q "Usage"; then
  ok "--help flag works"
else
  die "--help flag (rc=$rc)"
fi

# Given: keyword "valkey" and homelab-k8s solutions dir
# When: search for valkey
# Then: exits 0, returns JSON with matches
output=$("$SCRIPT" --solutions-dir "$SOLUTIONS_DIR" valkey 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 0 ]]; then
  ok "exits 0 for matching keyword"
else
  die "exit code for matching keyword (rc=$rc)"
fi

echo "$output" > /tmp/u3-test.json
if python3 -m json.tool /tmp/u3-test.json >/dev/null 2>&1; then
  ok "output is valid JSON"
else
  die "output is not valid JSON"
fi

# Check that valkey results contain expected file
if grep -q "valkey-pattern" /tmp/u3-test.json; then
  ok "found valkey fixture doc"
else
  die "missing valkey fixture doc"
fi

# Check that title is present for honcho-deployment-patterns
if grep -q "Valkey Cache Auth Pattern" /tmp/u3-test.json; then
  ok "found valkey-pattern title"
else
  die "missing valkey-pattern title"
fi

# Given: keyword "networkpolicy"
# When: search for networkpolicy
# Then: exits 0, returns matches
output=$("$SCRIPT" --solutions-dir "$SOLUTIONS_DIR" networkpolicy 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 0 ]]; then
  ok "networkpolicy search returns matches"
else
  die "networkpolicy search (rc=$rc)"
fi

# Given: nonexistent keyword
# When: search for "nonexistentxyz123"
# Then: exits 2, returns empty array
output=$("$SCRIPT" --solutions-dir "$SOLUTIONS_DIR" nonexistentxyz123 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 2 ]]; then
  ok "exits 2 for no matches"
else
  die "expected exit 2 for no matches (rc=$rc)"
fi

if [[ "$output" == "[]" ]]; then
  ok "returns empty array for no matches"
else
  die "expected empty array (got: $output)"
fi

# Given: multiple keywords
# When: search for "valkey networkpolicy"
# Then: exits 0, returns results for both
output=$("$SCRIPT" --solutions-dir "$SOLUTIONS_DIR" valkey networkpolicy 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 0 ]]; then
  ok "multi-keyword search exits 0"
else
  die "multi-keyword search (rc=$rc)"
fi

echo "$output" > /tmp/u3-multi.json
if grep -q '"valkey"' /tmp/u3-multi.json && grep -q '"networkpolicy"' /tmp/u3-multi.json; then
  ok "multi-keyword results contain both keywords"
else
  die "multi-keyword results missing keywords"
fi

# Given: shell metacharacter in keyword
# When: search for keyword with semicolon
# Then: exits 1
output=$("$SCRIPT" --solutions-dir "$SOLUTIONS_DIR" "valkey;rm" 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 1 ]]; then
  ok "rejects shell metacharacters"
else
  die "expected exit 1 for metacharacters (rc=$rc)"
fi

# Given: no keywords
# When: run with only --solutions-dir
# Then: exits 1
output=$("$SCRIPT" --solutions-dir "$SOLUTIONS_DIR" 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 1 ]]; then
  ok "exits 1 with no keywords"
else
  die "expected exit 1 with no keywords (rc=$rc)"
fi

# Given: nonexistent directory
# When: search with bad dir
# Then: exits 1
output=$("$SCRIPT" --solutions-dir /nonexistent valkey 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 1 ]]; then
  ok "exits 1 for nonexistent directory"
else
  die "expected exit 1 for nonexistent dir (rc=$rc)"
fi

echo ""
echo "Results: $pass passed, $fail failed"
[[ $fail -eq 0 ]] && exit 0 || exit 1
