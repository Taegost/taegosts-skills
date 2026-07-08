#!/usr/bin/env bash
# context-gather.sh -- Gather git context as JSON (branch, commits, status, unpushed)
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

# Current branch (raw, unquoted)
current_branch_raw=$(git branch --show-current 2>/dev/null || echo "")

# Default branch delegates to git-default-branch.sh (single source of truth)
# Run in a subshell because the helper may call `exit` on error; capture stdout.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
default_branch_raw="main"
if [[ -f "${SCRIPT_DIR}/git-default-branch.sh" ]]; then
    if default_branch_output=$("${SCRIPT_DIR}/git-default-branch.sh" 2>/dev/null); then
        default_branch_raw="${DEFAULT_BRANCH:-$default_branch_output}"
        default_branch_raw="${default_branch_raw#origin/}"
        if [[ -z "$default_branch_raw" ]]; then
            default_branch_raw="main"
        fi
    fi
fi

# Recent commits (last 10) — collect as "hash<TAB>subject" lines
recent_commits_raw="$(git log --format='%h	%s' -10 2>/dev/null || true)"

# Working tree status — collect raw porcelain output
working_tree_raw="$(git status --porcelain 2>/dev/null || true)"

# Unpushed commits count
unpushed_count=0
if git rev-parse --abbrev-ref '@{upstream}' > /dev/null 2>&1; then
    unpushed_count=$(git rev-list --count '@{upstream}..HEAD' 2>/dev/null || echo "0")
else
    # No upstream set — fallback: total commit count (matches legacy behavior)
    unpushed_count=$(git rev-list --count HEAD 2>/dev/null || echo "0")
fi

# Open PR check
# IMPORTANT: Don't suppress gh failure. If gh is not authenticated, set a distinct error flag
# instead of silently treating the failure as "no open PR" — that was a bug.
has_open_pr="false"
has_open_pr_error="false"
if [[ -n "$current_branch_raw" ]]; then
    # Capture both stdout and stderr separately to distinguish "no PR" from "gh error"
    pr_state=$(gh pr view --json state --jq '.state' 2>&1)
    gh_exit=$?
    if [[ $gh_exit -eq 0 ]]; then
        # gh succeeded
        if [[ "$pr_state" == "OPEN" ]]; then
            has_open_pr="true"
        fi
        # else: no PR or PR not open, no error
    else
        # gh failed — flag as error (could be auth, network, or PR doesn't exist)
        has_open_pr_error="true"
    fi
fi

# Serialize everything through Python for correct JSON escaping.
# Pass raw data via env vars to avoid any interpolation issues.
# Note: python3 availability is required; this is documented in the script header.
export CTX_CURRENT_BRANCH="$current_branch_raw"
export CTX_DEFAULT_BRANCH="$default_branch_raw"
export CTX_RECENT_COMMITS="$recent_commits_raw"
export CTX_WORKING_TREE="$working_tree_raw"
export CTX_UNPUSHED_COUNT="$unpushed_count"
export CTX_HAS_OPEN_PR="$has_open_pr"
export CTX_HAS_OPEN_PR_ERROR="$has_open_pr_error"

python3 - <<'PY'
import json
import os
import sys

def parse_porcelain(raw):
    """Parse git status --porcelain into {staged, modified, untracked} arrays.
    Handles rename/copy entries (R  old -> new) by extracting only the new path."""
    staged, modified, untracked = [], [], []
    for line in raw.splitlines():
        if not line:
            continue
        x = line[0]
        y = line[1]
        path = line[3:] if len(line) > 3 else ""

        # Handle rename/copy: "R  old -> new" or "R  old -> new" → take the new path
        if x in ('R', 'C'):
            if ' -> ' in path:
                path = path.split(' -> ', 1)[1]
            elif '"' in path:
                # Quoted rename format: "old" -> "new"
                parts = path.split(' -> ')
                if len(parts) == 2 and parts[1].startswith('"') and parts[1].endswith('"'):
                    path = parts[1][1:-1]

        if x in ('M', 'A', 'D', 'R', 'C'):
            staged.append(path)
        if y in ('M', 'D'):
            modified.append(path)
        if x == '?' and y == '?':
            untracked.append(path)
    return staged, modified, untracked

def parse_commits(raw):
    """Parse commit log output into [{hash, subject}, ...] array."""
    commits = []
    for line in raw.splitlines():
        if not line:
            continue
        parts = line.split('\t', 1)
        if len(parts) != 2:
            continue
        commits.append({'hash': parts[0], 'subject': parts[1]})
    return commits

try:
    current_branch = os.environ.get('CTX_CURRENT_BRANCH', '') or None
    default_branch = os.environ.get('CTX_DEFAULT_BRANCH', 'main')
    unpushed_count = int(os.environ.get('CTX_UNPUSHED_COUNT', '0') or '0')
    has_open_pr = os.environ.get('CTX_HAS_OPEN_PR', 'false') == 'true'

    staged, modified, untracked = parse_porcelain(os.environ.get('CTX_WORKING_TREE', ''))
    is_dirty = bool(staged or modified or untracked)

    commits = parse_commits(os.environ.get('CTX_RECENT_COMMITS', ''))

    output = {
        'current_branch': current_branch,
        'default_branch': default_branch,
        'recent_commits': commits,
        'working_tree': {
            'staged': staged,
            'modified': modified,
            'untracked': untracked,
        },
        'unpushed_count': unpushed_count,
        'is_dirty': is_dirty,
        'has_open_pr': has_open_pr,
        'has_open_pr_error': os.environ.get('CTX_HAS_OPEN_PR_ERROR', 'false') == 'true',
    }

    json.dump(output, sys.stdout, ensure_ascii=False)
    sys.stdout.write('\n')
except Exception as e:
    # Emit structured error, not raw traceback
    json.dump({'error': str(e)}, sys.stderr, ensure_ascii=False)
    sys.stderr.write('\n')
    sys.exit(1)
PY

# Clean up env vars
unset CTX_CURRENT_BRANCH CTX_DEFAULT_BRANCH CTX_RECENT_COMMITS \
      CTX_WORKING_TREE CTX_UNPUSHED_COUNT CTX_HAS_OPEN_PR CTX_HAS_OPEN_PR_ERROR

exit 0
