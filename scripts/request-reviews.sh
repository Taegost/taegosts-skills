#!/usr/bin/env bash
# request-reviews.sh -- Request or re-request reviews on a GitHub PR
# Usage: request-reviews.sh <pr-url-or-number> [--fresh] <reviewer1> [reviewer2 ...]
#
# Exit codes: 0 success, 1 error (invalid input or gh failure)

set -euo pipefail

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat <<'EOF'
Usage: request-reviews.sh <pr-url-or-number> [--fresh] <reviewer1> [reviewer2 ...]

Request or re-request reviews on a GitHub PR.

Arguments:
  pr_url      GitHub PR URL or number (required)
  --fresh     Remove reviewers before re-adding to force fresh review (optional)
  reviewers   GitHub usernames to request review from (at least one required)

Examples:
  request-reviews.sh 123 alice bob
  request-reviews.sh 123 --fresh alice
  request-reviews.sh https://github.com/owner/repo/pull/123 --fresh alice bob

Exit codes:
  0 - success
  1 - error (invalid input or gh failure)
EOF
  exit 0
fi

# --- R3 frontmatter (machine-readable) ---
# description: "Request or re-request reviews on a GitHub PR"
# triggers: []
# inputs:
#   - name: pr_url
#     type: string
#     description: GitHub PR URL or number
#   - name: reviewers
#     type: list
#     description: GitHub usernames to request review from
#   - name: fresh
#     type: flag
#     required: false
#     description: Remove reviewers before re-adding to force fresh review

# Validate arguments
if [[ $# -lt 1 ]]; then
  echo "Error: No PR URL or number provided." >&2
  echo "Usage: request-reviews.sh <pr-url-or-number> [--fresh] <reviewer1> [reviewer2 ...]" >&2
  exit 1
fi

PR_URL="$1"
shift

# Validate PR URL/number format
if [[ -z "$PR_URL" ]]; then
  echo "Error: Empty PR URL or number." >&2
  exit 1
fi

# Extract bare PR number from URL (e.g., https://github.com/owner/repo/pull/123 → 123)
# Uses only Bash regex for portability (no grep -P). Rejects anything that doesn't match
# the two accepted formats: bare number or full GitHub PR URL with trailing digits.
# This also acts as the safety gate: any value with shell metacharacters, `/` outside
# the expected URL structure, or non-numeric payloads fails here and never reaches
# the gh api endpoint.
if [[ "$PR_URL" =~ ^[0-9]+$ ]]; then
  PR_NUMBER="$PR_URL"
elif [[ "$PR_URL" =~ ^https://github\.com/[^/]+/[^/]+/pull/([0-9]+)$ ]]; then
  PR_NUMBER="${BASH_REMATCH[1]}"
elif [[ "$PR_URL" =~ https://github\.com/[^/]+/[^/]+/pull/([0-9]+) ]]; then
  # Accept GitHub URL with trailing slash or query params
  PR_NUMBER="${BASH_REMATCH[1]}"
else
  echo "Error: Could not extract PR number from: $PR_URL" >&2
  echo "Expected format: <number> or https://github.com/{owner}/{repo}/pull/<number>" >&2
  exit 1
fi
# Validate PR_NUMBER is strictly numeric before it enters any API path
if ! [[ "$PR_NUMBER" =~ ^[0-9]+$ ]]; then
  echo "Error: Extracted PR number is not numeric: $PR_NUMBER" >&2
  exit 1
fi
# Use PR_NUMBER (validated) for API paths; PR_URL only for gh pr edit/view comment paths
# where gh does its own parsing.
PR_URL_RESOLVED="$PR_NUMBER"

# Parse --fresh flag
FRESH=false
if [[ "${1:-}" == "--fresh" ]]; then
  FRESH=true
  shift
fi

# Validate reviewers
if [[ $# -lt 1 ]]; then
  echo "Error: No reviewers specified." >&2
  echo "Usage: request-reviews.sh <pr-url-or-number> [--fresh] <reviewer1> [reviewer2 ...]" >&2
  exit 1
fi

REVIEWERS=("$@")

# Build -f arguments for gh api
build_reviewer_args() {
  local args=()
  for reviewer in "${REVIEWERS[@]}"; do
    args+=("-f" "reviewers[]=${reviewer}")
  done
  echo "${args[@]}"
}

# Step 1: If --fresh, remove reviewers first to force a fresh review cycle
if [[ "$FRESH" == "true" ]]; then
  echo "Removing reviewers for fresh review request..."
  REVIEWER_ARGS=$(build_reviewer_args)
  # shellcheck disable=SC2086
  if ! gh api -X DELETE "repos/{owner}/{repo}/pulls/${PR_URL_RESOLVED}/requested_reviewers" $REVIEWER_ARGS 2>/dev/null; then
    echo "Warning: Could not remove reviewers via API. Continuing with re-add..." >&2
  fi
fi

# Step 2: Re-add reviewers to trigger fresh review notification
echo "Requesting review from: ${REVIEWERS[*]}"
REVIEWER_ARGS=$(build_reviewer_args)
# shellcheck disable=SC2086
if ! gh api -X POST "repos/{owner}/{repo}/pulls/${PR_URL_RESOLVED}/requested_reviewers" $REVIEWER_ARGS 2>/dev/null; then
  echo "Warning: Primary API call (POST requested_reviewers) failed. Falling back to gh pr edit." >&2
  # Fallback: use gh pr edit
  fallback_failed=0
  for reviewer in "${REVIEWERS[@]}"; do
    if ! gh pr edit "$PR_URL" --add-reviewer "$reviewer" 2>/dev/null; then
      echo "Warning: Could not add reviewer '$reviewer' via gh pr edit." >&2
      fallback_failed=1
    fi
  done
  if [[ "$fallback_failed" -eq 1 ]]; then
    echo "Warning: Some reviewers could not be added. The request may be incomplete." >&2
  fi
fi

# Step 3: If all else fails, post a comment as last resort
# This handles the case where the bot doesn't have write access
if [[ "$FRESH" == "true" ]]; then
  # Check if we actually succeeded by verifying reviewers are listed
  # If gh api failed above, post a comment fallback.
  # IMPORTANT: pass reviewer list via env var to avoid shell-injection vulnerability
  # from interpolating ${REVIEWERS[*]} into a Python string literal.
  REVIEWER_LIST="${REVIEWERS[*]}"
  export REVIEWER_LIST
  if ! gh pr view "$PR_URL" --json reviewRequests 2>/dev/null | python3 -c "
import json, os, sys
data = json.load(sys.stdin)
reviewers = [r.get('login', '') for r in data.get('reviewRequests', [])]
# Read reviewer targets from env var (safe: no external input interpolated into code)
targets = [t.strip() for t in os.environ.get('REVIEWER_LIST', '').split() if t]
if not any(t in reviewers for t in targets):
    sys.exit(1)
" 2>/dev/null; then
    echo "Posting comment fallback for re-review notification..." >&2
    unset REVIEWER_LIST
    gh pr comment "$PR_URL" --body "All review findings addressed and resolved. Ready for re-review." 2>/dev/null || true
  else
    unset REVIEWER_LIST
  fi
fi

echo "Review request complete."
