#!/usr/bin/env bash
# fetch-pr-data.sh -- Fetch PR data from GitHub CLI as JSON
# Usage: fetch-pr-data.sh <pr-url-or-number>
#
# Fetches PR metadata using gh pr view with specific JSON fields.
# Output: JSON object with PR data on stdout
# Exit codes: 0 success, 1 error (invalid input or gh failure)

set -euo pipefail

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat <<'EOF'
Usage: fetch-pr-data.sh <pr-url-or-number>

Fetch PR data from GitHub CLI as JSON.

Arguments:
  pr_url    GitHub PR URL or number (required)

Output: JSON object with PR data including:
  - number, title, body
  - headRefName, baseRefName
  - state, author
  - reviews, mergeable, commits

Exit codes:
  0 - success
  1 - error (invalid input or gh failure)

Examples:
  fetch-pr-data.sh 123
  fetch-pr-data.sh https://github.com/owner/repo/pull/123
  fetch-pr-data.sh owner/repo#123
EOF
  exit 0
fi

# Validate arguments
if [[ $# -lt 1 ]]; then
  echo "Error: No PR URL or number provided." >&2
  echo "Usage: fetch-pr-data.sh <pr-url-or-number>" >&2
  exit 1
fi

PR_URL="$1"

# Validate PR URL/number format
# Accept: numeric (123), URL (https://github.com/...), or owner/repo#123
if [[ -z "$PR_URL" ]]; then
  echo "Error: Empty PR URL or number." >&2
  exit 1
fi

# Check for shell metacharacters (security gate)
if [[ "$PR_URL" =~ [\;\&\|\$\`\(\)\{\}\[\>\<] ]]; then
  echo "Error: PR URL contains invalid characters." >&2
  exit 1
fi

# Fetch PR data using gh CLI
# Fields: number, title, body, headRefName, baseRefName, state, author, reviews, mergeable, commits
if ! gh pr view "$PR_URL" --json number,title,body,headRefName,baseRefName,state,author,reviews,mergeable,commits 2>/dev/null; then
  echo "Error: Failed to fetch PR data. Check that the PR exists and you have access." >&2
  exit 1
fi
