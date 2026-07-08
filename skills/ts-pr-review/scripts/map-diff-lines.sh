#!/usr/bin/env bash
# map-diff-lines.sh -- Generate file:line mapping from unified diff input
# Usage: gh pr diff NUMBER | map-diff-lines.sh
#
# Reads unified diff from stdin and outputs file:line pairs for each added line.
# Used to verify that review findings target commentable lines in a PR diff.
# Input: Unified diff content (from git diff or gh pr diff) on stdin
# Output: file:new-file-line pairs, one per line
# Exit codes: 0 success, 1 error (no input or parse failure)

set -euo pipefail

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat <<'EOF'
Usage: map-diff-lines.sh

Generate file:line mapping from unified diff input.

Reads unified diff from stdin and outputs file:line pairs for each added line.
Each line in the output is in the format: relative/path/to/file.ext:line_number

This is used to verify that review findings target commentable lines in a PR diff.

Input:  Unified diff content on stdin (from git diff or gh pr diff)
Output: file:new-file-line pairs, one per line
Exit codes:
  0 - success
  1 - error (no input or parse failure)

Example:
  gh pr diff 123 | map-diff-lines.sh
  git diff main...feature | map-diff-lines.sh
EOF
  exit 0
fi

# Check if stdin is a terminal (no piped input)
if [[ -t 0 ]]; then
  echo "Error: No input provided. Pipe diff content to this script." >&2
  echo "Usage: gh pr diff NUMBER | map-diff-lines.sh" >&2
  exit 1
fi

# Process the diff and extract file:line pairs for added lines
# Uses POSIX awk - no GNU extensions
awk '/^\+\+\+ / { if (substr($2, 1, 2) == "b/") { file = substr($2, 3) } else { file = $2 } next } /^@@/ { s = $0; while (match(s, /\+[0-9]+/)) { num = substr(s, RSTART + 1, RLENGTH - 1); if (num + 0 > 0) { line = num + 0; break } s = substr(s, RSTART + RLENGTH) } next } /^\+/ { if (file != "" && line > 0) { print file ":" line } line++; next } /^ / { line++; next }'
