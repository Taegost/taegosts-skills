#!/usr/bin/env bash
# detect-coverage-gaps.sh -- Flag changed scripts without corresponding test files.
# Usage: detect-coverage-gaps.sh [base_branch]
#
# Discovers changed files autonomously via git diff + git ls-files.
# For any changed script file, checks whether a corresponding test exists in tests/.
# No line threshold — if a script was changed, it needs a test.
# Output: JSON report of gaps found (or empty if no gaps).
set -euo pipefail

# Escape special characters for JSON string values.
# Handles: backslash, double-quote, newline, tab, carriage return.
# Limitation: filenames with control characters other than \n, \t, \r may produce
# invalid JSON. This is acceptable because such filenames are extremely rare in
# practice and git itself handles them poorly. If jq becomes a required dependency,
# replace this with jq-based JSON construction for full spec compliance.
json_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g' | tr '\n' ' ' | tr '\r' ' '
}

BASE_BRANCH="${1:-}"
if [[ -z "$BASE_BRANCH" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  # shellcheck source=scripts/git-default-branch.sh
  source "$SCRIPT_DIR/git-default-branch.sh"
  # git-default-branch.sh sets REPO_ROOT and DEFAULT_BRANCH
  BASE_BRANCH="$DEFAULT_BRANCH"
else
  REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
    echo "Error: not in a git repository" >&2
    exit 2
  }
fi

# Get all changed files (diff + untracked)
CHANGED_FILES=$(
  {
    git diff --name-only "$BASE_BRANCH" 2>/dev/null || true
    git diff --name-only --cached 2>/dev/null || true
    git ls-files --others --exclude-standard 2>/dev/null || true
  } | sort -u
)

# Script extensions to check
SCRIPT_EXTENSIONS="sh|py|js|ts|rb|go|rs|java|php|pl|bash|zsh"

# Find gaps
GAPS=""
GAP_COUNT=0

while IFS= read -r file; do
  [[ -z "$file" ]] && continue

  # Skip non-script files
  ext="${file##*.}"
  case "|$SCRIPT_EXTENSIONS|" in
    *"|$ext|"*) ;;
    *) continue ;;
  esac

  # Skip test files themselves
  case "$file" in
    tests/*|*/tests/*|test-*|*_test.*|*_spec.*|*spec.*|*test.*)
      continue
      ;;
  esac

  # Check for corresponding test file
  # Try patterns: tests/test-<basename>.sh, tests/test-<name>.py, tests/<name>_test.py, etc.
  basename_no_ext="$(basename "${file%.*}")"
  has_test=false

  # Common test file patterns
  for test_pattern in \
    "tests/test-${basename_no_ext}.sh" \
    "tests/test-${basename_no_ext}.py" \
    "tests/test_${basename_no_ext}.py" \
    "tests/${basename_no_ext}_test.py" \
    "tests/${basename_no_ext}_test.go" \
    "tests/${basename_no_ext}.test.ts" \
    "tests/${basename_no_ext}.test.js" \
    "tests/${basename_no_ext}_spec.rb" \
    "tests/scripts/test-${basename_no_ext}.sh" \
    "tests/scripts/test_${basename_no_ext}.py" \
    "test/test-${basename_no_ext}.sh" \
    "test/test_${basename_no_ext}.py" \
    "test/${basename_no_ext}_test.go" \
  ; do
    if [[ -f "$REPO_ROOT/$test_pattern" ]]; then
      has_test=true
      break
    fi
  done

  if [[ "$has_test" == "false" ]]; then
    GAP_COUNT=$((GAP_COUNT + 1))
    if [[ -n "$GAPS" ]]; then
      GAPS="$GAPS,"
    fi
    GAPS="$GAPS
    {
      \"file\": \"$(json_escape "$file")\",
      \"basename\": \"$(json_escape "$basename_no_ext")\",
      \"suggested_test\": \"tests/test-$(json_escape "$basename_no_ext").$ext\"
    }"
  fi
done <<< "$CHANGED_FILES"

# Output JSON report
if [[ $GAP_COUNT -eq 0 ]]; then
  echo '{"gaps": [], "count": 0}'
else
  echo "{
    \"gaps\": [$GAPS
    ],
    \"count\": $GAP_COUNT
  }"
fi
