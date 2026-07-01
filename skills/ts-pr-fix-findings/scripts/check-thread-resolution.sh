#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  echo "Usage: check-thread-resolution.sh --repo owner/repo --pr <number>"
  echo "Check which review threads are resolved vs unresolved."
  echo "Output: JSON array of {thread_id, is_resolved, comments: [...]}"
  echo "Exit codes: 0 (success), 1 (error)"
  exit 0
fi

repo="" pr_number=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) repo="$2"; shift 2 ;;
    --pr) pr_number="$2"; shift 2 ;;
    *) shift ;;
  esac
done

[[ -z "$repo" || -z "$pr_number" ]] && { echo "--repo and --pr required" >&2; exit 1; }
echo "$repo$pr_number" | grep -qE '[;&|"$`' && { echo "invalid characters" >&2; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "gh auth not configured" >&2; exit 1; }

IFS='/' read -r owner name <<< "$repo"

gh api graphql -f query="query { repository(owner: \"${owner}\", name: \"${name}\") { pullRequest(number: ${pr_number}) { reviewThreads(first: 100) { nodes { id isResolved comments(first: 10) { nodes { body author { login } createdAt } } } } } } }" \
  --jq '[.data.repository.pullRequest.reviewThreads.nodes[] | {thread_id: .id, is_resolved: .isResolved, comments: [.comments.nodes[] | {body: .body, author: .author.login, created_at: .createdAt}]}]' 2>/dev/null \
  || { echo "failed to check thread resolution" >&2; exit 1; }
