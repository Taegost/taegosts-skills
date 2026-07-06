#!/usr/bin/env bash
# detect-changed-code-files.sh — Return list of modified code-bearing files.
# Filters out test files, non-script files (.md, .yaml, .json, .txt).
# Usage: detect-changed-code-files.sh [base_branch]
#
# If base_branch is not provided, uses the default branch (origin/main or origin/master).
# Output: one file path per line, or empty if no code files changed.
set -euo pipefail

BASE_BRANCH="${1:-}"
if [[ -z "$BASE_BRANCH" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  # shellcheck source=scripts/git-default-branch.sh
  source "$SCRIPT_DIR/git-default-branch.sh"
  BASE_BRANCH="$DEFAULT_BRANCH"
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
