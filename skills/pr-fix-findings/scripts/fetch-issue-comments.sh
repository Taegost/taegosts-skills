#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  echo "Usage: fetch-issue-comments.sh --repo owner/repo --pr <number>"
  echo "Fetch PR issue-level comments (not threaded inline review comments)."
  echo "Output: JSON array of {id, user, body, created_at}"
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
echo "$repo$pr_number" | grep -qE '[;&|$\`]' && { echo "invalid characters" >&2; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "gh auth not configured" >&2; exit 1; }

gh api "repos/${repo}/issues/${pr_number}/comments" --jq '[.[] | {id: .id, user: .user.login, body: .body, created_at: .created_at}]' 2>/dev/null \
  || { echo "failed to fetch comments" >&2; exit 1; }
