#!/usr/bin/env bash
# git-default-branch.sh -- Resolve repo root and default branch.
# Usage: source git-default-branch.sh
#
# Sets REPO_ROOT and DEFAULT_BRANCH variables.
# Exits with error if not in a git repo or default branch cannot be determined.
# Source this file at the top of scripts that need the repo root and base branch.

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  echo "Usage: source git-default-branch.sh"
  echo ""
  echo "Resolve the repo root and default branch. Source this file at the top"
  echo "of scripts that need the repo root and base branch."
  echo ""
  echo "Sets: REPO_ROOT, DEFAULT_BRANCH (origin/main or origin/master)"
  echo ""
  echo "Exit codes: 0 (success), 2 (not a git repository or cannot determine"
  echo "the default branch)"
  exit 0
fi

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  echo "Error: not in a git repository" >&2
  exit 2
}

if git rev-parse --verify origin/main >/dev/null 2>&1; then
  DEFAULT_BRANCH="origin/main"
elif git rev-parse --verify origin/master >/dev/null 2>&1; then
  DEFAULT_BRANCH="origin/master"
else
  echo "Error: cannot determine default branch" >&2
  exit 2
fi
