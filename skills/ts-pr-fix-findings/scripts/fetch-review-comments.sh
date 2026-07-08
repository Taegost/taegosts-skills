#!/usr/bin/env bash
# fetch-review-comments.sh -- Fetch threaded inline review comments (not issue-level comments)
# Input: --repo owner/repo --pr <number>
# Output: JSON array of {id, path, line, author, body, resolved, thread_id}
# Exit codes: 0 success, 1 error

set -euo pipefail

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat <<'EOF'
Usage: fetch-review-comments.sh --repo owner/repo --pr <number>

Fetch threaded inline review comments (comments anchored to a specific
file:line in the diff) -- not issue-level comments posted on the PR
conversation tab. Use fetch-issue-comments.sh for those.

Arguments:
  --repo owner/repo    GitHub repository in owner/repo format
  --pr <number>        Pull request number

Output: JSON array of {id, path, line, author, body, resolved, thread_id}
  id         - the comment's database id
  path       - file path the comment is anchored to
  line       - current line number in the diff (may be null if outdated)
  author     - comment author's GitHub login
  body       - comment text
  resolved   - whether the comment's thread is resolved
  thread_id  - the GraphQL node id of the containing thread

Exit codes:
  0 - success
  1 - error (bad input, auth failure, API error)
EOF
  exit 0
fi

repo="" pr_number=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)
      [[ $# -ge 2 ]] || { echo '{"ok":false,"error":"--repo requires a value"}' >&2; exit 1; }
      repo="$2"; shift 2 ;;
    --pr)
      [[ $# -ge 2 ]] || { echo '{"ok":false,"error":"--pr requires a value"}' >&2; exit 1; }
      pr_number="$2"; shift 2 ;;
    *) echo '{"ok":false,"error":"unknown argument"}' >&2; exit 1 ;;
  esac
done

[[ -z "$repo" || -z "$pr_number" ]] && { echo '{"ok":false,"error":"--repo and --pr required"}' >&2; exit 1; }

# Non-path metacharacter regex (blocks control chars, shell metacharacters, quotes, whitespace)
METACHAR_RE=$'[\x01-\x1f\x7f;<>(){}~\\`!$&\'"|*?/ \n\t]'
# --repo: exclude / (required for owner/repo), validate format separately
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

IFS='/' read -r owner name <<< "$repo"

gh api graphql -f query="query { repository(owner: \"${owner}\", name: \"${name}\") { pullRequest(number: ${pr_number}) { reviewThreads(first: 100) { nodes { id isResolved path line comments(first: 50) { nodes { databaseId body author { login } } } } } } } }" \
  --jq '[.data.repository.pullRequest.reviewThreads.nodes[] as $t | $t.comments.nodes[] | {id: .databaseId, path: $t.path, line: $t.line, author: .author.login, body: .body, resolved: $t.isResolved, thread_id: $t.id}]' 2>/dev/null \
  || { echo '{"ok":false,"error":"failed to fetch review comments"}' >&2; exit 1; }
