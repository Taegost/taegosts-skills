#!/usr/bin/env bash
# check-thread-resolution.sh - check which review threads are resolved vs unresolved
# Input: --repo owner/repo --pr <number>
# Output: JSON array of {thread_id, is_resolved, comments: [...]}
# Exit codes: 0 success, 1 error

set -euo pipefail

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat <<'EOF'
Usage: check-thread-resolution.sh --repo owner/repo --pr <number>

Check which review threads are resolved vs unresolved.

Arguments:
  --repo owner/repo    GitHub repository in owner/repo format
  --pr <number>        Pull request number

Output: JSON array of {thread_id, is_resolved, comments: [...]}

Exit codes:
  0 - success
  1 - error (bad input, auth failure, API error)
EOF
  exit 0
fi

# Guard: require at least 2 args (--repo and --pr)
if [[ $# -lt 2 ]]; then
  echo '{"ok":false,"error":"--repo and --pr are required"}' >&2
  exit 1
fi

repo="" pr_number=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) repo="$2"; shift 2 ;;
    --pr) pr_number="$2"; shift 2 ;;
    *) echo '{"ok":false,"error":"unknown argument"}' >&2; exit 1 ;;
  esac
done

[[ -z "$repo" || -z "$pr_number" ]] && { echo '{"ok":false,"error":"--repo and --pr required"}' >&2; exit 1; }

if [[ "$repo" =~ [\;\|\&\$\`\!\>\<\(\)\{\}\~\*\?/] ]]; then
  echo '{"ok":false,"error":"--repo contains shell metacharacters"}' >&2; exit 1
fi
if [[ "$pr_number" =~ [\;\|\&\$\`\!\>\<\(\)\{\}\~\*\?/] ]]; then
  echo '{"ok":false,"error":"--pr contains shell metacharacters"}' >&2; exit 1
fi

# Validate repo format (owner/repo)
if [[ ! "$repo" =~ ^[a-zA-Z0-9._-]+/[a-zA-Z0-9._-]+$ ]]; then
  echo '{"ok":false,"error":"--repo must be in owner/repo format"}' >&2; exit 1
fi

# Validate PR number is numeric
if [[ ! "$pr_number" =~ ^[0-9]+$ ]]; then
  echo '{"ok":false,"error":"--pr must be a number"}' >&2; exit 1
fi
gh auth status >/dev/null 2>&1 || { echo '{"ok":false,"error":"gh auth not configured"}' >&2; exit 1; }

IFS='/' read -r owner name <<< "$repo"

gh api graphql -f query="query { repository(owner: \"${owner}\", name: \"${name}\") { pullRequest(number: ${pr_number}) { reviewThreads(first: 100) { nodes { id isResolved comments(first: 10) { nodes { body author { login } createdAt } } } } } } }" \
  --jq '[.data.repository.pullRequest.reviewThreads.nodes[] | {thread_id: .id, is_resolved: .isResolved, comments: [.comments.nodes[] | {body: .body, author: .author.login, created_at: .createdAt}]}]' 2>/dev/null \
  || { echo '{"ok":false,"error":"failed to check thread resolution"}' >&2; exit 1; }
