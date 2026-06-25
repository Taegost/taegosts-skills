#!/usr/bin/env bash
# U1: git-context.sh — unified git state snapshot as JSON
# Calls U2 (default-branch.sh) internally for default_branch resolution
# Output: JSON with current_branch, default_branch, is_detached, dirty_files,
#         untracked_files, staged_files, recent_commits, has_unpushed, repo_root
# Exit codes: 0 success, 1 error

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat <<'EOF'
Usage: git-context.sh

Output a JSON snapshot of the current git repository state.

Fields:
  current_branch   - name of current branch (or "HEAD" if detached)
  default_branch   - resolved default branch name
  is_detached      - true if HEAD is detached
  dirty_files      - list of modified files (unstaged)
  untracked_files  - list of untracked files
  staged_files      - list of staged files
  recent_commits   - last 5 commits as "short_hash subject"
  has_unpushed     - true if there are unpushed commits
  repo_root        - absolute path to repo root

Arguments: none
Exit codes:
  0 - success
  1 - error (not in a git repo)
EOF
  exit 0
fi

# Verify we're in a git repo
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo '{"error":"not inside a git repository"}' >&2
  exit 1
fi

repo_root=$(git rev-parse --show-toplevel)

# Current branch (or HEAD if detached)
current_branch=$(git symbolic-ref --short HEAD 2>/dev/null || echo "HEAD")
is_detached=false
if [[ "$current_branch" == "HEAD" ]]; then
  is_detached=true
fi

# Default branch via U2
default_branch=$("$SCRIPT_DIR/default-branch.sh" 2>/dev/null) || default_branch="unknown"

# Dirty (modified unstaged) files
mapfile -t dirty_files < <(git diff --name-only 2>/dev/null || true)

# Untracked files
mapfile -t untracked_files < <(git ls-files --others --exclude-standard 2>/dev/null || true)

# Staged files
mapfile -t staged_files < <(git diff --cached --name-only 2>/dev/null || true)

# Recent commits (last 5)
mapfile -t recent_commits < <(git log --oneline -5 2>/dev/null || true)

# Has unpushed commits
has_unpushed=false
if [[ "$current_branch" != "HEAD" ]]; then
  upstream=$(git rev-parse --abbrev-ref "@{upstream}" 2>/dev/null) || upstream=""
  if [[ -n "$upstream" ]]; then
    unpushed_count=$(git log --oneline "$upstream..HEAD" 2>/dev/null | wc -l) || unpushed_count=0
    if [[ "$unpushed_count" -gt 0 ]]; then
      has_unpushed=true
    fi
  else
    # No upstream set — consider it unpushed
    has_unpushed=true
  fi
fi

# Build JSON arrays
json_array() {
  local arr=("$@")
  if [[ ${#arr[@]} -eq 0 ]]; then
    echo "[]"
    return
  fi
  printf '['
  for i in "${!arr[@]}"; do
    [[ $i -gt 0 ]] && printf ','
    printf '"%s"' "$(echo "${arr[$i]}" | sed 's/\\/\\\\/g; s/"/\\"/g; s/	/\\t/g; s//\\r/g' | tr '
' ' ')"
  done
  printf ']'
}

# Output JSON
cat <<EOF
{
  "current_branch": "$current_branch",
  "default_branch": "$default_branch",
  "is_detached": $is_detached,
  "dirty_files": $(json_array "${dirty_files[@]+"${dirty_files[@]}"}"),
  "untracked_files": $(json_array "${untracked_files[@]+"${untracked_files[@]}"}"),
  "staged_files": $(json_array "${staged_files[@]+"${staged_files[@]}"}"),
  "recent_commits": $(json_array "${recent_commits[@]+"${recent_commits[@]}"}"),
  "has_unpushed": $has_unpushed,
  "repo_root": "$repo_root"
}
EOF
