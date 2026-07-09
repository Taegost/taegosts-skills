#!/usr/bin/env bash
# request-re-review.sh -- Request re-review from a specific reviewer on a GitHub PR
# Input: --pr-url <url> --reviewer <username>
# Output: JSON {success: true, reviewer: "..."}
# Exit codes: 0 success, 1 error

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../../scripts/lib/input-validation.sh
source "$SCRIPT_DIR/../../../scripts/lib/input-validation.sh"

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat <<'EOF'
Usage: request-re-review.sh --pr-url <url> --reviewer <username>

Request re-review from a specific reviewer on a GitHub PR.

Arguments:
  --pr-url <url>           GitHub PR URL or number (required)
  --reviewer <username>    Reviewer GitHub username (required)

Output: JSON with:
  success    - true on success
  reviewer   - the reviewer username

Exit codes:
  0 - success
  1 - error (invalid input, auth failure, API error)

Examples:
  request-re-review.sh --pr-url https://github.com/owner/repo/pull/123 --reviewer alice
  request-re-review.sh --pr-url 123 --reviewer alice
EOF
  exit 0
fi

# Parse arguments
pr_url="" reviewer=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --pr-url)
      [[ $# -ge 2 ]] || { echo '{"ok":false,"error":"--pr-url requires a value"}' >&2; exit 1; }
      pr_url="$2"; shift 2 ;;
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
if [[ -z "$reviewer" ]]; then
  echo '{"ok":false,"error":"--reviewer is required"}' >&2
  exit 1
fi

# Validate --pr-url: reject shell metacharacters
if ! validate_no_metachars "$pr_url" --allow-slash; then
  echo '{"ok":false,"error":"--pr-url contains shell metacharacters"}' >&2
  exit 1
fi

# Validate --pr-url format (must be a GitHub PR URL or numeric)
if ! validate_pr_url_format "$pr_url"; then
  echo '{"ok":false,"error":"--pr-url must be a GitHub PR URL or numeric PR number"}' >&2
  exit 1
fi

# Validate --reviewer: reject shell metacharacters
if ! validate_no_metachars "$reviewer" --allow-slash; then
  echo '{"ok":false,"error":"--reviewer contains shell metacharacters"}' >&2
  exit 1
fi

# Validate --reviewer format (GitHub username: alphanumeric + hyphens, cannot start/end with hyphen)
if ! validate_reviewer_name "$reviewer"; then
  echo '{"ok":false,"error":"--reviewer has invalid format"}' >&2
  exit 1
fi

# Validate gh CLI is available and authenticated
gh_env_rc=0
validate_gh_environment || gh_env_rc=$?
case $gh_env_rc in
  1) echo '{"ok":false,"error":"gh CLI is not installed"}' >&2; exit 1 ;;
  2) echo '{"ok":false,"error":"gh auth not configured"}' >&2; exit 1 ;;
esac

# Request re-review using gh pr edit
if ! gh pr edit "$pr_url" --add-reviewer "$reviewer" 2>/dev/null; then
  echo '{"ok":false,"error":"failed to request re-review"}' >&2
  exit 1
fi

echo "{\"success\":true,\"reviewer\":\"${reviewer}\"}"
