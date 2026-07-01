#!/usr/bin/env bash
# Test: skills/ce-work/scripts/detect-missing-artifacts.sh
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
SCRIPT="$REPO_ROOT/skills/ce-work/scripts/detect-missing-artifacts.sh"

pass=0
fail=0
ok() { pass=$((pass + 1)); echo "  PASS: $1"; }
die() { fail=$((fail + 1)); echo "  FAIL: $1"; }

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

echo "=== test-detect-missing-artifacts.sh ==="

# Given: script exists
# When: run with --help
# Then: exits 0, shows usage
output=$("$SCRIPT" --help 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 0 ]] && echo "$output" | grep -q "Usage"; then
  ok "--help flag works"
else
  die "--help flag (rc=$rc)"
fi

# Given: reference dir has 3 files, plan file lists 2 of them
mkdir -p "$tmpdir/reference"
echo "content1" > "$tmpdir/reference/foo.py"
echo "content2" > "$tmpdir/reference/bar.py"
echo "content3" > "$tmpdir/reference/baz.py"

cat > "$tmpdir/plan-files.txt" << 'EOF'
foo.py
bar.py
EOF

output=$("$SCRIPT" --plan-files "$tmpdir/plan-files.txt" --reference-dir "$tmpdir/reference" 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 0 ]]; then
  ok "exits 0 for valid inputs"
else
  die "exit code for valid inputs (rc=$rc)"
fi

echo "$output" > "$tmpdir/result.json"
if python3 -m json.tool "$tmpdir/result.json" >/dev/null 2>&1; then
  ok "output is valid JSON"
else
  die "output is not valid JSON"
fi

if echo "$output" | python3 -c "import json,sys; data=json.load(sys.stdin); missing=[e for e in data if e['status']=='missing']; assert len(missing)==1 and missing[0]['file']=='baz.py'"; then
  ok "baz.py reported as missing"
else
  die "baz.py not reported as missing"
fi

in_plan_count=$(echo "$output" | python3 -c "import json,sys; data=json.load(sys.stdin); print(len([e for e in data if e['status']=='in_plan']))")
if [[ "$in_plan_count" == "2" ]]; then
  ok "foo.py and bar.py reported as in_plan"
else
  die "expected 2 in_plan, got $in_plan_count"
fi

# Given: all reference files are in plan
cat > "$tmpdir/plan-all.txt" << 'EOF'
foo.py
bar.py
baz.py
EOF

output=$("$SCRIPT" --plan-files "$tmpdir/plan-all.txt" --reference-dir "$tmpdir/reference" 2>&1) && rc=0 || rc=$?
missing_count=$(echo "$output" | python3 -c "import json,sys; data=json.load(sys.stdin); print(len([e for e in data if e['status']=='missing']))")
if [[ "$missing_count" == "0" ]]; then
  ok "no missing when all in plan"
else
  die "expected 0 missing, got $missing_count"
fi

# Given: nonexistent plan file
output=$("$SCRIPT" --plan-files "$tmpdir/nonexistent.txt" --reference-dir "$tmpdir/reference" 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 1 ]]; then
  ok "exits 1 for nonexistent plan file"
else
  die "expected exit 1 for nonexistent plan file (rc=$rc)"
fi

# Given: nonexistent reference dir
output=$("$SCRIPT" --plan-files "$tmpdir/plan-files.txt" --reference-dir "$tmpdir/nonexistent" 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 1 ]]; then
  ok "exits 1 for nonexistent reference dir"
else
  die "expected exit 1 for nonexistent reference dir (rc=$rc)"
fi

# Given: shell metacharacter in path
output=$("$SCRIPT" --plan-files "/tmp/file;rm" --reference-dir "$tmpdir/reference" 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 1 ]]; then
  ok "rejects shell metacharacters"
else
  die "expected exit 1 for metacharacters (rc=$rc)"
fi

# Given: missing required args
output=$("$SCRIPT" 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 1 ]]; then
  ok "exits 1 with no arguments"
else
  die "expected exit 1 with no arguments (rc=$rc)"
fi

echo ""
echo "Results: $pass passed, $fail failed"
[[ $fail -eq 0 ]] && exit 0 || exit 1
