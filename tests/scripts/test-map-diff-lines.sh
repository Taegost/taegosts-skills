#!/usr/bin/env bash
# Test: scripts/map-diff-lines.sh
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# map-diff-lines.sh relocated to skill-local scripts/ during Wave 2 consolidation
SCRIPT="$REPO_ROOT/skills/ts-pr-review/scripts/map-diff-lines.sh"

pass=0
fail=0
ok() { pass=$((pass + 1)); echo "  PASS: $1"; }
die() { fail=$((fail + 1)); echo "  FAIL: $1"; }

echo "=== test-map-diff-lines.sh ==="

# Given: script exists
# When: run with --help
# Then: exits 0, shows usage
output=$("$SCRIPT" --help 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 0 ]] && echo "$output" | grep -q "Usage"; then
  ok "--help flag works"
else
  die "--help flag (rc=$rc)"
fi

# Given: no piped input (stdin is a terminal)
# When: run without piping
# Then: exits 1 with error message
# Note: We simulate this by closing stdin
output=$(echo "" | "$SCRIPT" 2>&1) && rc=0 || rc=$?
# Empty input should still process (just no output)
if [[ $rc -eq 0 ]]; then
  ok "empty input exits 0 (no output)"
else
  die "empty input handling (rc=$rc)"
fi

# Given: simple diff with one added line
# When: pipe diff to script
# Then: outputs file:line for the added line
diff_input='diff --git a/test.txt b/test.txt
--- a/test.txt
+++ b/test.txt
@@ -1,3 +1,4 @@
 line1
+new line
 line2
 line3'

output=$(echo "$diff_input" | "$SCRIPT" 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 0 ]] && [[ "$output" == "test.txt:2" ]]; then
  ok "simple diff with one added line"
else
  die "simple diff (rc=$rc, output=$output)"
fi

# Given: diff with hunk header @@ -10,5 +20,10 @@
# When: pipe diff to script
# Then: first added line maps to line 20
diff_input='diff --git a/file.py b/file.py
--- a/file.py
+++ b/file.py
@@ -10,5 +20,10 @@
 context line 1
+added line 1
+added line 2
 context line 2
 context line 3'

output=$(echo "$diff_input" | "$SCRIPT" 2>&1) && rc=0 || rc=$?
expected=$(printf 'file.py:21\nfile.py:22')
if [[ $rc -eq 0 ]] && [[ "$output" == "$expected" ]]; then
  ok "hunk header @@ -10,5 +20,10 @@ maps correctly"
else
  die "hunk header mapping (rc=$rc, output=$output)"
fi

# Given: diff with multiple files
# When: pipe diff to script
# Then: outputs file:line for each added line in each file
diff_input='diff --git a/file1.txt b/file1.txt
--- a/file1.txt
+++ b/file1.txt
@@ -1,3 +1,4 @@
 line1
+new line in file1
 line2
 line3
diff --git a/file2.txt b/file2.txt
--- a/file2.txt
+++ b/file2.txt
@@ -5,3 +5,4 @@
 context
+new line in file2
 end'

output=$(echo "$diff_input" | "$SCRIPT" 2>&1) && rc=0 || rc=$?
expected=$(printf 'file1.txt:2\nfile2.txt:6')
if [[ $rc -eq 0 ]] && [[ "$output" == "$expected" ]]; then
  ok "multiple files in diff"
else
  die "multiple files (rc=$rc, output=$output)"
fi

# Given: diff with only context lines (no additions)
# When: pipe diff to script
# Then: no output
diff_input='diff --git a/file.txt b/file.txt
--- a/file.txt
+++ b/file.txt
@@ -1,3 +1,3 @@
 line1
 line2
 line3'

output=$(echo "$diff_input" | "$SCRIPT" 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 0 ]] && [[ -z "$output" ]]; then
  ok "no additions produces no output"
else
  die "no additions (rc=$rc, output=$output)"
fi

# Given: diff with deleted lines (not added)
# When: pipe diff to script
# Then: no output for deleted lines
diff_input='diff --git a/file.txt b/file.txt
--- a/file.txt
+++ b/file.txt
@@ -1,4 +1,3 @@
 line1
-removed line
 line2
 line3'

output=$(echo "$diff_input" | "$SCRIPT" 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 0 ]] && [[ -z "$output" ]]; then
  ok "deleted lines not included in output"
else
  die "deleted lines (rc=$rc, output=$output)"
fi

# Given: output format validation
# When: check output format
# Then: each line matches file:line pattern
diff_input='diff --git a/src/main.py b/src/main.py
--- a/src/main.py
+++ b/src/main.py
@@ -1,5 +1,7 @@
 import os
+import sys
+import json
 def main():
     pass'

output=$(echo "$diff_input" | "$SCRIPT" 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 0 ]]; then
  # Check each line matches file:line pattern
  format_ok=true
  while IFS= read -r line; do
    if ! echo "$line" | grep -qE '^[^:]+:[0-9]+$'; then
      format_ok=false
      break
    fi
  done <<< "$output"
  if [[ "$format_ok" == "true" ]]; then
    ok "output format is file:line per line"
  else
    die "output format invalid: $output"
  fi
else
  die "format validation (rc=$rc)"
fi

# Given: empty diff (just header, no hunks)
# When: pipe diff to script
# Then: no output
diff_input='diff --git a/file.txt b/file.txt
--- a/file.txt
+++ b/file.txt'

output=$(echo "$diff_input" | "$SCRIPT" 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 0 ]] && [[ -z "$output" ]]; then
  ok "empty diff produces no output"
else
  die "empty diff (rc=$rc, output=$output)"
fi

echo ""
echo "Results: $pass passed, $fail failed"
[[ $fail -eq 0 ]] && exit 0 || exit 1
