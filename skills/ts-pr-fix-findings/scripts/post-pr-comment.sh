#!/usr/bin/env bash
# post-pr-comment.sh -- Post a top-level (issue-level) comment on a GitHub PR
# Input: --repo owner/repo --pr <number> --body "text" (or body via stdin)
# Output: JSON {success: true, url: "..."}
# Exit codes: 0 success, 1 error

set -euo pipefail

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat <<'EOF'
Usage: post-pr-comment.sh --repo owner/repo --pr <number> --body "comment text"
       echo "comment text" | post-pr-comment.sh --repo owner/repo --pr <number>

Post a top-level (issue-level) comment on a GitHub PR conversation tab.
For threaded inline review comments, use the GitHub Reviews API directly
(see ts-pr-review's review-submission flow) -- this script is for flat
comments only, e.g. the un-postable-finding fallback or status updates.

Arguments:
  --repo owner/repo    GitHub repository in owner/repo format
  --pr <number>        Pull request number
  --body <text>        Comment body. If omitted, read from stdin.

Output: JSON with:
  success    - true on success
  url        - the posted comment's HTML URL

Exit codes:
  0 - success
  1 - error (bad input, auth failure, API error)

Examples:
  post-pr-comment.sh --repo owner/repo --pr 123 --body "Fixes applied, ready for re-review."
  echo "Fixes applied." | post-pr-comment.sh --repo owner/repo --pr 123
EOF
  exit 0
fi

repo="" pr_number="" body="" body_set=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)
      [[ $# -ge 2 ]] || { echo '{"ok":false,"error":"--repo requires a value"}' >&2; exit 1; }
      repo="$2"; shift 2 ;;
    --pr)
      [[ $# -ge 2 ]] || { echo '{"ok":false,"error":"--pr requires a value"}' >&2; exit 1; }
      pr_number="$2"; shift 2 ;;
    --body)
      [[ $# -ge 2 ]] || { echo '{"ok":false,"error":"--body requires a value"}' >&2; exit 1; }
      body="$2"; body_set=true; shift 2 ;;
    *) echo '{"ok":false,"error":"unknown argument"}' >&2; exit 1 ;;
  esac
done

[[ -z "$repo" || -z "$pr_number" ]] && { echo '{"ok":false,"error":"--repo and --pr required"}' >&2; exit 1; }

# Fall back to stdin when --body was not passed
if [[ "$body_set" == false ]]; then
  if [[ -t 0 ]]; then
    echo '{"ok":false,"error":"--body required (or pipe comment text via stdin)"}' >&2; exit 1
  fi
  body="$(cat)"
fi

[[ -z "$body" ]] && { echo '{"ok":false,"error":"comment body must not be empty"}' >&2; exit 1; }

# Non-path metacharacter regex (blocks control chars, shell metacharacters, quotes, whitespace).
# Only applied to --repo and --pr -- the comment body is passed to gh api via
# -f (field value), never interpolated into a shell command, so it is not
# subject to this restriction.
METACHAR_RE=$'[\x01-\x1f\x7f;<>(){}~\\`!$&\'"|*?/ \n\t]'
REPO_METACHAR_RE=$'[\x01-\x1f\x7f;<>(){}~\\`!$&\'"|*? \n\t]'
if [[ "$repo" =~ $REPO_METACHAR_RE ]]; then
  echo '{"ok":false,"error":"--repo contains shell metacharacters"}' >&2; exit 1
fi
if [[ "$pr_number" =~ $METACHAR_RE ]]; then
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

url=$(gh api "repos/${repo}/issues/${pr_number}/comments" -f body="$body" --jq '.html_url' 2>/dev/null) \
  || { echo '{"ok":false,"error":"failed to post comment"}' >&2; exit 1; }

python3 -c "
import json, sys
print(json.dumps({'success': True, 'url': sys.argv[1]}))
" "$url"
