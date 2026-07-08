#!/usr/bin/env bash
# context-gather -- Gather git context as JSON (branch, commits, status, unpushed)
#
# Usage: context-gather.sh [--help]
#
# Outputs JSON on stdout with:
#   - current_branch: current branch name (or null if detached HEAD)
#   - default_branch: resolved default branch name (origin/HEAD or fallback)
#   - recent_commits: last 10 commits as array of objects {hash, subject}
#   - working_tree: {staged: [...], modified: [...], untracked: [...]}
#   - unpushed_count: number of commits ahead of upstream (0 if none)
#   - is_dirty: true if any staged, modified, or untracked files exist
#   - has_open_pr: true if current branch has an open PR (via gh cli)
#
# Exit codes: 0 success, 1 error

set -euo pipefail

show_help() {
    cat <<'EOF'
context-gather.sh - Gather git context as JSON

Usage: context-gather.sh [--help]

Outputs JSON with current branch, default branch, recent commits,
working tree status, unpushed count, dirty flag, and open PR status.

Exit codes:
  0  Success
  1  Error (not in a git repository)
EOF
}

if [[ "${1:-}" == "--help" ]]; then
    show_help
    exit 0
fi

if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo '{"error": "not a git repository"}' >&2
    exit 1
fi

# Current branch
current_branch=$(git branch --show-current 2>/dev/null || echo "")
if [[ -z "$current_branch" ]]; then
    current_branch="null"
else
    current_branch="\"${current_branch}\""
fi

# Default branch delegates to git-default-branch.sh (single source of truth)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/git-default-branch.sh" ]]; then
    source "${SCRIPT_DIR}/git-default-branch.sh" 2>/dev/null || default_branch="main"
    if [[ -n "${DEFAULT_BRANCH:-}" ]]; then
        default_branch="${DEFAULT_BRANCH#origin/}"
    else
        default_branch="main"
    fi
else
    default_branch="main"
fi

# Recent commits (last 10)
recent_commits="["
first=true
while IFS=$'\t' read -r hash subject; do
    if [[ -n "$hash" ]]; then
        if [[ "$first" == "true" ]]; then
            first=false
        else
            recent_commits+=","
        fi
        # Escape double quotes in subject
        subject="${subject//\"/\\\"}"
        recent_commits+="{\"hash\":\"${hash}\",\"subject\":\"${subject}\"}"
    fi
done < <(git log --oneline -10 2>/dev/null | awk '{hash=$1; $1=""; sub(/^ /, ""); print hash"\t"$0}')
recent_commits+="]"

# Working tree status
staged="["
modified="["
untracked="["
s_first=true
m_first=true
u_first=true

while IFS= read -r line; do
    if [[ -z "$line" ]]; then
        continue
    fi

    # git status --porcelain format: XY filename
    # X = index status (staged), Y = work tree status (unstaged)
    # Positions 1 and 2 are the status codes, position 4+ is the filename
    x="${line:0:1}"
    y="${line:1:1}"
    file="${line:3}"

    # Escape double quotes in filename
    file="${file//\"/\\\"}"

    # Staged changes (X position)
    if [[ "$x" == "M" || "$x" == "A" || "$x" == "D" || "$x" == "R" || "$x" == "C" ]]; then
        if [[ "$s_first" == "true" ]]; then s_first=false; else staged+=","; fi
        staged+="\"${file}\""
    fi

    # Unstaged changes (Y position)
    if [[ "$y" == "M" || "$y" == "D" ]]; then
        if [[ "$m_first" == "true" ]]; then m_first=false; else modified+=","; fi
        modified+="\"${file}\""
    fi

    # Untracked (XY=??)
    if [[ "$x" == "?" && "$y" == "?" ]]; then
        if [[ "$u_first" == "true" ]]; then u_first=false; else untracked+=","; fi
        untracked+="\"${file}\""
    fi
done < <(git status --porcelain 2>/dev/null)

staged+="]"
modified+="]"
untracked+="]"

is_dirty="false"
if [[ "$staged" != "[]" || "$modified" != "[]" || "$untracked" != "[]" ]]; then
    is_dirty="true"
fi

# Unpushed commits count
unpushed_count=0
if git rev-parse --abbrev-ref '@{upstream}' > /dev/null 2>&1; then
    unpushed_count=$(git rev-list --count '@{upstream}..HEAD' 2>/dev/null || echo "0")
else
    # No upstream set - check if there are any commits
    unpushed_count=$(git rev-list --count HEAD 2>/dev/null || echo "0")
fi

# Open PR check
has_open_pr="false"
if current_branch_raw=$(git branch --show-current 2>/dev/null) && [[ -n "$current_branch_raw" ]]; then
    pr_state=$(gh pr view --json state --jq '.state' 2>/dev/null || echo "")
    if [[ "$pr_state" == "OPEN" ]]; then
        has_open_pr="true"
    fi
fi

# Output JSON
cat <<EOF
{
  "current_branch": ${current_branch},
  "default_branch": "${default_branch}",
  "recent_commits": ${recent_commits},
  "working_tree": {
    "staged": ${staged},
    "modified": ${modified},
    "untracked": ${untracked}
  },
  "unpushed_count": ${unpushed_count},
  "is_dirty": ${is_dirty},
  "has_open_pr": ${has_open_pr}
}
EOF

exit 0
