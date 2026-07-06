#!/usr/bin/env bash
# detect-changed-code-files.sh — Return list of modified code-bearing files.
# Filters out test files, non-script files (.md, .yaml, .json, .txt).
# Usage: detect-changed-code-files.sh [base_branch]
#
# If base_branch is not provided, uses the default branch (origin/main or origin/master).
# Output: one file path per line, or empty if no code files changed.
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  echo "Error: not in a git repository" >&2
  exit 2
}

BASE_BRANCH="${1:-}"
if [[ -z "$BASE_BRANCH" ]]; then
  # Resolve default branch
  if git rev-parse --verify origin/main >/dev/null 2>&1; then
    BASE_BRANCH="origin/main"
  elif git rev-parse --verify origin/master >/dev/null 2>&1; then
    BASE_BRANCH="origin/master"
  else
    echo "Error: cannot determine default branch" >&2
    exit 2
  fi
fi

# Get changed files from git diff (staged + unstaged + untracked)
{
  git diff --name-only "$BASE_BRANCH" 2>/dev/null || true
  git diff --name-only --cached 2>/dev/null || true
  git ls-files --others --exclude-standard 2>/dev/null || true
} | sort -u | while IFS= read -r file; do
  # Skip empty lines
  [[ -z "$file" ]] && continue

  # Skip non-script files
  case "$file" in
    *.md|*.yaml|*.yml|*.json|*.txt|*.html|*.css|*.svg|*.png|*.jpg|*.gif|*.lock|*.sum)
      continue
      ;;
  esac

  # Skip test files (files in tests/ directories or with test- prefix)
  case "$file" in
    tests/*|*/tests/*|test-*|*_test.*|*_spec.*|*spec.*|*test.*)
      continue
      ;;
  esac

  # Only include script-like extensions
  case "$file" in
    *.sh|*.py|*.js|*.ts|*.rb|*.go|*.rs|*.java|*.php|*.pl|*.bash|*.zsh)
      echo "$file"
      ;;
  esac
done
