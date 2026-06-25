#!/bin/bash
set -euo pipefail

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  echo "Usage: pr-metadata.sh --repo owner/repo --pr <number>"
  echo "Fetch PR metadata from GitHub API as JSON."
  echo "Output: JSON with number, title, state, base, head, head_sha, url, files_count, review_comments, issue_comments"
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
gh auth status >/dev/null 2>&1 || { echo "gh auth not configured" >&2; exit 1; }

pr_json=$(gh pr view "$pr_number" --repo "$repo" --json \
  number,title,state,baseRefName,headRefName,headRefOid,isCrossRepository,url,files,reviews,comments,mergeable 2>/dev/null) \
  || { echo "failed to fetch PR $pr_number from $repo" >&2; exit 1; }

python3 -c "
import json, sys
data = json.loads(sys.stdin.read())
result = {
    'number': data.get('number'),
    'title': data.get('title'),
    'state': data.get('state'),
    'base': data.get('baseRefName'),
    'head': data.get('headRefName'),
    'head_sha': data.get('headRefOid'),
    'is_cross_repo': data.get('isCrossRepository', False),
    'url': data.get('url'),
    'files_count': len(data.get('files', [])),
    'has_conflicts': data.get('mergeable', 'UNKNOWN') == 'CONFLICTING',
    'review_comments': sum(1 for r in data.get('reviews', []) if r.get('state') != 'PENDING'),
    'issue_comments': len(data.get('comments', []))
}
print(json.dumps(result, indent=2))
" <<< "$pr_json"
