#!/usr/bin/env bash
# gh-get-pr-state.sh -- Fetch PR state from GitHub CLI as JSON
# Input: --pr-url <url-or-number>
# Output: JSON {state, head_sha, base_branch}
# Exit codes: 0 success, 1 error

set -euo pipefail

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat <<'EOF'
Usage: gh-get-pr-state.sh --pr-url <url-or-number>

Fetch pull request state from GitHub CLI.

Arguments:
  --pr-url <url-or-number>    GitHub PR URL or number (required)

Output: JSON with:
  state        - "OPEN", "CLOSED", or "MERGED"
  head_sha     - HEAD commit SHA of the PR branch
  base_branch  - target branch name (e.g. "main")

Exit codes:
  0 - success
  1 - error (invalid input, auth failure, API error)

Examples:
  gh-get-pr-state.sh --pr-url 123
  gh-get-pr-state.sh --pr-url https://github.com/owner/repo/pull/123
EOF
  exit 0
fi

# Parse arguments
pr_url=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --pr-url)
      [[ $# -ge 2 ]] || { echo '{"ok":false,"error":"--pr-url requires a value"}' >&2; exit 1; }
      pr_url="$2"; shift 2 ;;
    -h|--help)
      echo "Run with --help for usage information." >&2; exit 0 ;;
    *)
      echo "{\"ok\":false,\"error\":\"unknown argument: $1\"}" >&2; exit 1 ;;
  esac
done

# Validate required arguments
if [[ -z "$pr_url" ]]; then
  echo '{"ok":false,"error":"--pr-url is required"}' >&2
  exit 1
fi

# Validate PR URL/number format - reject shell metacharacters
METACHAR_RE=$'[\x01-\x1f\x7f;<>(){}~\\`!$&\'"|*? \n\t]'
if [[ "$pr_url" =~ $METACHAR_RE ]]; then
  echo '{"ok":false,"error":"--pr-url contains shell metacharacters"}' >&2
  exit 1
fi

# Validate gh CLI is available and authenticated
if ! command -v gh &>/dev/null; then
  echo '{"ok":false,"error":"gh CLI not available"}' >&2
  exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
  echo '{"ok":false,"error":"gh CLI not authenticated"}' >&2
  exit 1
fi

# Fetch PR state, head SHA, and base branch
if ! pr_json=$(gh pr view "$pr_url" --json state,headRefOid,baseRefName 2>&1); then
  echo '{"ok":false,"error":"failed to fetch PR data"}' >&2
  exit 1
fi

# Extract fields using python3 for reliable JSON parsing
if ! command -v python3 &>/dev/null; then
  echo '{"ok":false,"error":"python3 not available"}' >&2
  exit 1
fi

python3 -c "
import json, sys
data = json.loads(sys.stdin.read())
result = {
    'state': data.get('state', 'UNKNOWN'),
    'head_sha': data.get('headRefOid', ''),
    'base_branch': data.get('baseRefName', '')
}
print(json.dumps(result))
" <<< "$pr_json"
