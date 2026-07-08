#!/usr/bin/env bash
# resolve-thread.sh -- Resolve a GitHub PR review thread
# Input: --pr-url <url> --thread-id <id> --reviewer <username>
# Output: JSON {success: true, thread_id: "..."}
# Exit codes: 0 success, 1 error

set -euo pipefail

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat <<'EOF'
Usage: resolve-thread.sh --pr-url <url> --thread-id <id> --reviewer <username>

Resolve a GitHub PR review thread using GraphQL mutation.

Arguments:
  --pr-url <url>           GitHub PR URL (required)
  --thread-id <id>         Review thread node ID (required)
  --reviewer <username>    Reviewer username for context (required)

Output: JSON with:
  success    - true on success
  thread_id  - the resolved thread ID

Exit codes:
  0 - success
  1 - error (invalid input, auth failure, API error)

Examples:
  resolve-thread.sh --pr-url https://github.com/owner/repo/pull/123 --thread-id PRRT_xxx --reviewer alice
EOF
  exit 0
fi

# Parse arguments
pr_url="" thread_id="" reviewer=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --pr-url)
      [[ $# -ge 2 ]] || { echo '{"ok":false,"error":"--pr-url requires a value"}' >&2; exit 1; }
      pr_url="$2"; shift 2 ;;
    --thread-id)
      [[ $# -ge 2 ]] || { echo '{"ok":false,"error":"--thread-id requires a value"}' >&2; exit 1; }
      thread_id="$2"; shift 2 ;;
    --reviewer)
      [[ $# -ge 2 ]] || { echo '{"ok":false,"error":"--reviewer requires a value"}' >&2; exit 1; }
      reviewer="$2"; shift 2 ;;
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
if [[ -z "$thread_id" ]]; then
  echo '{"ok":false,"error":"--thread-id is required"}' >&2
  exit 1
fi
if [[ -z "$reviewer" ]]; then
  echo '{"ok":false,"error":"--reviewer is required"}' >&2
  exit 1
fi

# Non-path metacharacter regex (blocks control chars, shell metacharacters, quotes, whitespace)
METACHAR_RE=$'[\x01-\x1f\x7f;<>(){}~\\`!$&\'"|*? \n\t]'

# Validate --pr-url: reject shell metacharacters
if [[ "$pr_url" =~ $METACHAR_RE ]]; then
  echo '{"ok":false,"error":"--pr-url contains shell metacharacters"}' >&2
  exit 1
fi

# Validate --pr-url format (must be a GitHub PR URL or numeric)
if [[ ! "$pr_url" =~ ^https://github\.com/[a-zA-Z0-9._-]+/[a-zA-Z0-9._-]+/pull/[0-9]+$ ]] && \
   [[ ! "$pr_url" =~ ^[0-9]+$ ]]; then
  echo '{"ok":false,"error":"--pr-url must be a GitHub PR URL or numeric PR number"}' >&2
  exit 1
fi

# Validate --thread-id: reject shell metacharacters
if [[ "$thread_id" =~ $METACHAR_RE ]]; then
  echo '{"ok":false,"error":"--thread-id contains shell metacharacters"}' >&2
  exit 1
fi

# Validate --thread-id format (GitHub node IDs are base64-encoded, alphanumeric + underscore)
if [[ ! "$thread_id" =~ ^[A-Za-z0-9_+=/:-]+$ ]]; then
  echo '{"ok":false,"error":"--thread-id has invalid format"}' >&2
  exit 1
fi

# Validate --reviewer: reject shell metacharacters
if [[ "$reviewer" =~ $METACHAR_RE ]]; then
  echo '{"ok":false,"error":"--reviewer contains shell metacharacters"}' >&2
  exit 1
fi

# Validate --reviewer format (GitHub username: alphanumeric + hyphens, cannot start/end with hyphen)
if [[ ! "$reviewer" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?$ ]]; then
  echo '{"ok":false,"error":"--reviewer has invalid format"}' >&2
  exit 1
fi

# Validate gh CLI is available and authenticated
if ! command -v gh &>/dev/null; then
  echo '{"ok":false,"error":"gh CLI is not installed"}' >&2
  exit 1
fi

gh auth status >/dev/null 2>&1 || { echo '{"ok":false,"error":"gh auth not configured"}' >&2; exit 1; }

# Resolve the review thread using GraphQL mutation
result=$(gh api graphql -f query="mutation { resolveReviewThread(input: {threadId: \"${thread_id}\"}) { thread { id isResolved } } }" 2>/dev/null) || {
  echo '{"ok":false,"error":"failed to resolve thread"}' >&2
  exit 1
}

# Check if the mutation was successful
resolved=$(echo "$result" | python3 -c "import json,sys; data=json.loads(sys.stdin.read()); print(str(data.get('data',{}).get('resolveReviewThread',{}).get('thread',{}).get('isResolved',False)).lower())" 2>/dev/null) || {
  echo '{"ok":false,"error":"failed to parse API response"}' >&2
  exit 1
}

if [[ "$resolved" != "true" ]]; then
  echo '{"ok":false,"error":"thread was not resolved"}' >&2
  exit 1
fi

echo "{\"success\":true,\"thread_id\":\"${thread_id}\"}"
