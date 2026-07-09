#!/usr/bin/env bash
# fetch-issue-comments.sh -- Fetch PR issue-level comments (not threaded inline review comments)
# Input: --repo owner/repo --pr <number>
# Output: JSON array of {id, user, body, created_at}
# Exit codes: 0 success, 1 error

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../../scripts/lib/input-validation.sh
source "$SCRIPT_DIR/../../../scripts/lib/input-validation.sh"

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat <<'EOF'
Usage: fetch-issue-comments.sh --repo owner/repo --pr <number>

Fetch PR issue-level comments (not threaded inline review comments).

Arguments:
  --repo owner/repo    GitHub repository in owner/repo format
  --pr <number>        Pull request number

Output: JSON array of {id, user, body, created_at}

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

if ! validate_no_metachars "$repo" --allow-slash; then
  echo '{"ok":false,"error":"--repo contains shell metacharacters"}' >&2; exit 1
fi
if ! validate_no_metachars "$pr_number"; then
  echo '{"ok":false,"error":"--pr contains shell metacharacters"}' >&2; exit 1
fi

# Validate repo format (owner/repo)
if ! validate_repo_format "$repo"; then
  echo '{"ok":false,"error":"--repo must be in owner/repo format"}' >&2; exit 1
fi

# Validate PR number is numeric
if ! validate_pr_number_format "$pr_number"; then
  echo '{"ok":false,"error":"--pr must be a number"}' >&2; exit 1
fi
validate_gh_environment >/dev/null 2>&1 || { echo '{"ok":false,"error":"gh auth not configured"}' >&2; exit 1; }

gh api "repos/${repo}/issues/${pr_number}/comments" --jq '[.[] | {id: .id, user: .user.login, body: .body, created_at: .created_at}]' 2>/dev/null \
  || { echo '{"ok":false,"error":"failed to fetch comments"}' >&2; exit 1; }
