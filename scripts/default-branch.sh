#!/usr/bin/env bash
# default-branch.sh -- Resolve the default branch using cascading fallbacks
# Logic: symbolic-ref → origin/main → origin/master → gh repo view
# Output: Branch name on stdout (e.g., main)
# Exit codes: 0 success, 1 error

set -euo pipefail

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat <<'EOF'
Usage: default-branch.sh

Resolve the default branch of the current git repository using cascading fallbacks:
  1. git symbolic-ref refs/remotes/origin/HEAD
  2. git rev-parse --verify origin/main
  3. git rev-parse --verify origin/master
  4. gh repo view --json defaultBranchRef

Arguments: none
Output:    Default branch name on stdout (e.g., "main")
Exit codes:
  0 - success
  1 - error (not in a git repo or no default branch found)
EOF
  exit 0
fi

# Strategy 1: symbolic-ref
if branch=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null); then
  echo "${branch#origin/}"
  exit 0
fi

# Strategy 2: origin/main exists
if git rev-parse --verify origin/main >/dev/null 2>&1; then
  echo "main"
  exit 0
fi

# Strategy 3: origin/master exists
if git rev-parse --verify origin/master >/dev/null 2>&1; then
  echo "master"
  exit 0
fi

# Strategy 4: gh CLI (if available and authenticated)
if command -v gh >/dev/null 2>&1; then
  if gh auth status >/dev/null 2>&1; then
    branch=$(gh repo view --json defaultBranchRef -q '.defaultBranchRef.name' 2>/dev/null) || true
    if [[ -n "$branch" ]]; then
      echo "$branch"
      exit 0
    fi
  fi
fi

echo "Error: Could not determine default branch" >&2
exit 1
