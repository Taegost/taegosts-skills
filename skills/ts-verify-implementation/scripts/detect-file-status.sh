#!/usr/bin/env bash
# U15: detect-file-status.sh - determine if a file is committed, on disk (gitignored), or missing
# Input: file path (relative to repo root)
# Output: JSON with {path, status: "committed"|"on_disk_gitignored"|"on_disk_untracked"|"missing"}
# Exit codes: 0 success, 1 error, 2 file missing

set -uo pipefail

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat <<'EOF'
Usage: detect-file-status.sh <file-path>

Determine the status of a file relative to the current git repository.

Arguments:
  file-path    Path to check (relative to repo root, or absolute)

Output: JSON with:
  path   - the checked path
  status - one of:
    "committed"          - tracked by git (in index or HEAD)
    "on_disk_gitignored" - exists on disk but listed in .gitignore
    "on_disk_untracked"  - exists on disk, not tracked, not gitignored
    "missing"            - not found on disk and not tracked

Exit codes:
  0 - success
  1 - error (not in a git repo, no argument)
  2 - file is missing (not on disk, not tracked)
EOF
  exit 0
fi

if [[ $# -ne 1 ]]; then
  echo '{"error":"exactly one argument required: file path"}' >&2
  exit 1
fi

file_path="$1"

# R10: validate input - reject shell metacharacters
if [[ "$file_path" =~ [\;\|\&\$\`] ]]; then
  echo '{"error":"path contains shell metacharacters"}' >&2
  exit 1
fi

# Validate we are in a git repo
git rev-parse --git-dir >/dev/null 2>&1 || {
  echo '{"error":"not inside a git repository"}' >&2
  exit 1
}

# Escape path for JSON
escaped_path="${file_path//\\/\\\\}"
escaped_path="${escaped_path//\"/\\\"}"

# Check if tracked by git (committed or staged)
if git ls-files --error-unmatch "$file_path" >/dev/null 2>&1; then
  echo "{\"path\":\"$escaped_path\",\"status\":\"committed\"}"
  exit 0
fi

# Check if file exists on disk
if [[ -f "$file_path" ]]; then
  # Check if it is gitignored
  if git check-ignore -q "$file_path" 2>/dev/null; then
    echo "{\"path\":\"$escaped_path\",\"status\":\"on_disk_gitignored\"}"
  else
    # Exists on disk, not tracked, not gitignored = untracked
    echo "{\"path\":\"$escaped_path\",\"status\":\"on_disk_untracked\"}"
  fi
  exit 0
fi

# File is missing
echo "{\"path\":\"$escaped_path\",\"status\":\"missing\"}"
exit 2
