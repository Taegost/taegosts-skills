#!/usr/bin/env bash
# Test: scripts/classify-document.sh
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/classify-document.sh"
PARSE_JSON="/tmp/parse_json.py"

pass=0
fail=0
ok() { pass=$((pass + 1)); echo "  PASS: $1"; }
die() { fail=$((fail + 1)); echo "  FAIL: $1"; }

tmpdir=$(mktemp -d)

echo "=== test-classify-document.sh ==="

# Given: script exists
# When: run with --help
# Then: exits 0, shows usage
output=$("$SCRIPT" --help 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 0 ]] && echo "$output" | grep -q "Usage"; then
  ok "--help flag works"
else
  die "--help flag (rc=$rc)"
fi

# Given: a plan document
# When: classify the plan
# Then: type is "plan", confidence is "high"
cat > "$tmpdir/plan.md" << 'DOCEOF'
---
title: "feat: Test Plan"
type: feat
date: 2026-06-25
---

# Script Extraction Pass

## Dependency Graph and Build Order

```
U5 (run-id.sh) -> U1 (git-context.sh)
U2 (default-branch.sh) -> U1
```

### U1: git-context.sh

**Goal:** Unified git state.

### U5: run-id.sh

**Goal:** Generate run ID.
DOCEOF

output=$("$SCRIPT" "$tmpdir/plan.md" 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 0 ]]; then
  ok "exits 0 for valid file"
else
  die "exit code for valid file (rc=$rc)"
fi

echo "$output" > /tmp/u6-test.json
if python3 -m json.tool /tmp/u6-test.json >/dev/null 2>&1; then
  ok "output is valid JSON"
else
  die "output is not valid JSON"
fi

doc_type=$(python3 "$PARSE_JSON" /tmp/u6-test.json type)
if [[ "$doc_type" == "plan" ]]; then
  ok "classifies plan correctly"
else
  die "expected plan, got $doc_type"
fi

confidence=$(python3 "$PARSE_JSON" /tmp/u6-test.json confidence)
if [[ "$confidence" == "high" ]]; then
  ok "confidence is high"
else
  die "expected high confidence, got $confidence"
fi

# Given: a requirements document
# When: classify it
# Then: type is "requirements"
cat > "$tmpdir/requirements.md" << 'DOCEOF'
---
title: "Requirements for Feature X"
type: requirements
---

# Requirements

| ID | Requirement |
|----|-------------|
| R1 | User must be able to login |
| R2 | System must validate inputs |

## Acceptance Criteria

- Given a user with valid credentials
- When they submit the login form
- Then they are authenticated
DOCEOF

output=$("$SCRIPT" "$tmpdir/requirements.md" 2>&1) && rc=0 || rc=$?
echo "$output" > /tmp/u6-req.json
doc_type=$(python3 "$PARSE_JSON" /tmp/u6-req.json type)
if [[ "$doc_type" == "requirements" ]]; then
  ok "classifies requirements correctly"
else
  die "expected requirements, got $doc_type"
fi

# Given: a file that doesn't exist
# When: classify it
# Then: exits 1
output=$("$SCRIPT" /nonexistent/file.md 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 1 ]]; then
  ok "exits 1 for nonexistent file"
else
  die "expected exit 1 for nonexistent (rc=$rc)"
fi

# Given: no arguments
# When: run without arguments
# Then: exits 1
output=$("$SCRIPT" 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 1 ]]; then
  ok "exits 1 with no arguments"
else
  die "expected exit 1 with no arguments (rc=$rc)"
fi

# Given: shell metacharacter in path
# When: run with bad path
# Then: exits 1
output=$("$SCRIPT" "/tmp/file;rm" 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 1 ]]; then
  ok "rejects shell metacharacters"
else
  die "expected exit 1 for metacharacters (rc=$rc)"
fi

echo ""
echo "Results: $pass passed, $fail failed"
[[ $fail -eq 0 ]] && exit 0 || exit 1
