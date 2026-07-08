#!/usr/bin/env bash
# test-build-pr-body.sh -- tests for build-pr-body.sh
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/build-pr-body.sh"

pass=0
fail=0
ok() { pass=$((pass + 1)); echo "  PASS: $1"; }
die() { fail=$((fail + 1)); echo "  FAIL: $1"; }

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

echo "=== test-build-pr-body.sh ==="

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

# Missing --plan-path exits 1
output=$("$SCRIPT" --pr-number 123 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 1 ]] && echo "$output" | grep -q "plan-path"; then
  ok "missing --plan-path exits 1"
else
  die "missing --plan-path (rc=$rc, output=$output)"
fi

# Missing --pr-number exits 1
echo "test" > "$tmpdir/plan.md"
output=$("$SCRIPT" --plan-path "$tmpdir/plan.md" 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 1 ]] && echo "$output" | grep -q "pr-number"; then
  ok "missing --pr-number exits 1"
else
  die "missing --pr-number (rc=$rc, output=$output)"
fi

# Non-existent plan file exits 1
output=$("$SCRIPT" --plan-path "/nonexistent/plan.md" --pr-number 123 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 1 ]] && echo "$output" | grep -q "not found"; then
  ok "non-existent plan file exits 1"
else
  die "non-existent plan file (rc=$rc, output=$output)"
fi

# Non-numeric PR number exits 1
output=$("$SCRIPT" --plan-path "$tmpdir/plan.md" --pr-number "abc" 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 1 ]] && echo "$output" | grep -q "number"; then
  ok "non-numeric PR number exits 1"
else
  die "non-numeric PR number (rc=$rc, output=$output)"
fi

# Unknown argument exits 1
output=$("$SCRIPT" --plan-path "$tmpdir/plan.md" --pr-number 123 --bogus 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 1 ]]; then
  ok "unknown argument exits 1"
else
  die "unknown argument (rc=$rc, output=$output)"
fi

# Valid plan with frontmatter produces output
cat > "$tmpdir/plan.md" <<'PLANEOF'
---
title: "feat: Test Plan"
type: feat
date: 2026-07-07
---

# feat: Test Plan

## Summary

This is a test plan for validating the PR body builder.

## Requirements

- W2-R1. First requirement description
- W2-R2. Second requirement description
- W2-R3. Third requirement description

## Key Technical Decisions

**KTD-1. First decision.** Description of first decision.

**KTD-2. Second decision.** Description of second decision.
PLANEOF

output=$("$SCRIPT" --plan-path "$tmpdir/plan.md" --pr-number 456 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 0 ]]; then
  if echo "$output" | grep -q "Test Plan" && echo "$output" | grep -q "W2-R1" && echo "$output" | grep -q "KTD-1"; then
    ok "valid plan produces formatted output"
  else
    die "valid plan output missing expected content (output=$output)"
  fi
else
  die "valid plan (rc=$rc, output=$output)"
fi

# Plan with heading-only title works
cat > "$tmpdir/minimal.md" <<'PLANEOF'
# Simple Plan

## Summary

A minimal plan.

## Requirements

- W2-R1. Only requirement
PLANEOF

output=$("$SCRIPT" --plan-path "$tmpdir/minimal.md" --pr-number 789 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 0 ]] && echo "$output" | grep -q "Simple Plan"; then
  ok "heading-only title works"
else
  die "heading-only title (rc=$rc, output=$output)"
fi

# Empty plan file produces minimal output
: > "$tmpdir/empty.md"
output=$("$SCRIPT" --plan-path "$tmpdir/empty.md" --pr-number 1 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 0 ]] && echo "$output" | grep -q "Untitled Plan"; then
  ok "empty plan produces minimal output"
else
  die "empty plan (rc=$rc, output=$output)"
fi

echo ""
echo "Results: $pass passed, $fail failed"
[[ $fail -eq 0 ]] && exit 0 || exit 1
