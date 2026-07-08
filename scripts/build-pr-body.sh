#!/usr/bin/env bash
# build-pr-body.sh -- Build a formatted PR body from a plan file
# Input: --plan-path <path> --pr-number <number>
# Output: Formatted markdown for PR body on stdout
# Exit codes: 0 success, 1 error

set -euo pipefail

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat <<'EOF'
Usage: build-pr-body.sh --plan-path <path> --pr-number <number>

Build a formatted PR body from a plan file.

Arguments:
  --plan-path <path>      Path to the plan markdown file (required)
  --pr-number <number>    PR number for the body (required)

Output: Formatted markdown on stdout containing:
  - Plan title and summary
  - Completed units
  - Key technical decisions
  - Files created/modified

Exit codes:
  0 - success
  1 - error (missing args, file not found, parse error)

Examples:
  build-pr-body.sh --plan-path docs/plans/2026-07-05-001-plan.md --pr-number 123
  build-pr-body.sh --plan-path plan.md --pr-number 456
EOF
  exit 0
fi

# Parse arguments
plan_path="" pr_number=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --plan-path)
      [[ $# -ge 2 ]] || { echo "Error: --plan-path requires a value" >&2; exit 1; }
      plan_path="$2"; shift 2 ;;
    --pr-number)
      [[ $# -ge 2 ]] || { echo "Error: --pr-number requires a value" >&2; exit 1; }
      pr_number="$2"; shift 2 ;;
    -h|--help)
      echo "Run with --help for usage information." >&2; exit 0 ;;
    *)
      echo "Error: unknown argument: $1" >&2; exit 1 ;;
  esac
done

# Validate required arguments
if [[ -z "$plan_path" ]]; then
  echo "Error: --plan-path is required" >&2
  exit 1
fi

if [[ -z "$pr_number" ]]; then
  echo "Error: --pr-number is required" >&2
  exit 1
fi

# Validate PR number is numeric
if ! [[ "$pr_number" =~ ^[0-9]+$ ]]; then
  echo "Error: --pr-number must be a number" >&2
  exit 1
fi

# Validate plan file exists
if [[ ! -f "$plan_path" ]]; then
  echo "Error: plan file not found: $plan_path" >&2
  exit 1
fi

# Read plan content
plan_content=$(cat "$plan_path")

# Extract title from YAML frontmatter or first heading
title=""
if echo "$plan_content" | grep -q '^title:' 2>/dev/null; then
  title=$(echo "$plan_content" | grep '^title:' | head -1 | sed 's/^title:[[:space:]]*//' | sed 's/^"//' | sed 's/"$//')
fi
if [[ -z "$title" ]]; then
  title=$(echo "$plan_content" | grep '^#' | head -1 | sed 's/^#[[:space:]]*//' || true)
fi
title="${title:-Untitled Plan}"

# Extract summary (first paragraph after the title heading)
summary=""
in_summary=false
while IFS= read -r line; do
  # Skip frontmatter
  if [[ "$line" == "---" ]]; then
    continue
  fi
  # Start collecting after ## Summary
  if [[ "$line" == "## Summary" ]]; then
    in_summary=true
    continue
  fi
  # Stop at next heading
  if [[ "$in_summary" == true ]] && [[ "$line" =~ ^## ]]; then
    break
  fi
  # Collect summary lines
  if [[ "$in_summary" == true ]] && [[ -n "$line" ]]; then
    if [[ -n "$summary" ]]; then
      summary="$summary $line"
    else
      summary="$line"
    fi
  fi
done <<< "$plan_content"

# Extract completed units from Requirements section
units=""
in_requirements=false
while IFS= read -r line; do
  # Start collecting after ## Requirements
  if [[ "$line" == "## Requirements" ]]; then
    in_requirements=true
    continue
  fi
  # Stop at next major heading
  if [[ "$in_requirements" == true ]] && [[ "$line" =~ ^##[[:space:]] ]] && [[ "$line" != "## Requirements" ]]; then
    break
  fi
  # Collect requirement items (lines starting with - W2-R or similar)
  if [[ "$in_requirements" == true ]] && [[ "$line" =~ ^-[[:space:]]W[0-9]+-R ]]; then
    # Extract requirement ID and description (use grep -E for portability — no -P on BSD/macOS)
    req_id=$(echo "$line" | grep -oE 'W[0-9]+-R[0-9]+' | head -1)
    req_desc=$(echo "$line" | sed 's/^-[[:space:]]*W[0-9]*-R[0-9]*\.[[:space:]]*//')
    if [[ -n "$req_id" ]]; then
      units+="- **$req_id**: $req_desc"$'\n'
    fi
  fi
done <<< "$plan_content"

# Extract key technical decisions
decisions=""
in_decisions=false
while IFS= read -r line; do
  # Start collecting after ## Key Technical Decisions
  if [[ "$line" == "## Key Technical Decisions" ]]; then
    in_decisions=true
    continue
  fi
  # Stop at next major heading
  if [[ "$in_decisions" == true ]] && [[ "$line" =~ ^##[[:space:]] ]] && [[ "$line" != "## Key Technical Decisions" ]]; then
    break
  fi
  # Collect KTD items (use grep -E for portability)
  if [[ "$in_decisions" == true ]] && [[ "$line" =~ ^\*\*KTD- ]]; then
    ktd_id=$(echo "$line" | grep -oE 'KTD-[0-9]+' | head -1)
    # KTD titles may use either `.` or `:` after the number: **KTD-1. Title** or **KTD-1: Title**
    ktd_title=$(echo "$line" | sed 's/^\*\*KTD-[0-9]*[.:][[:space:]]*//' | sed 's/\*\*$//')
    if [[ -n "$ktd_id" ]]; then
      decisions+="- **$ktd_id**: $ktd_title"$'\n'
    fi
  fi
done <<< "$plan_content"

# Build the PR body using awk ENVIRON for safe template substitution:
# ENVIRON reads values from environment variables directly without shell expansion,
# so $title/$summary/$units/$decisions containing backticks or $(...) cannot trigger
# command injection (unlike an unquoted heredoc).
# This also correctly handles multi-line content (heredoc-safe).
DEFAULT_SUMMARY="No summary available."
DEFAULT_UNITS="No requirements listed."
DEFAULT_DECISIONS="No key technical decisions listed."

TMPL_TITLE="$title" \
TMPL_SUMMARY="${summary:-$DEFAULT_SUMMARY}" \
TMPL_UNITS="${units:-$DEFAULT_UNITS}" \
TMPL_DECISIONS="${decisions:-$DEFAULT_DECISIONS}" \
TMPL_PLAN_PATH="$plan_path" \
awk 'BEGIN {
    title = ENVIRON["TMPL_TITLE"]
    summary = ENVIRON["TMPL_SUMMARY"]
    units = ENVIRON["TMPL_UNITS"]
    decisions = ENVIRON["TMPL_DECISIONS"]
    plan_path = ENVIRON["TMPL_PLAN_PATH"]

    print "# " title ""
    print ""
    print "## Summary"
    print ""
    print summary
    print ""
    print "## Completed Requirements"
    print ""
    print units
    print "## Key Technical Decisions"
    print ""
    print decisions
    print ""
    print "---"
    print ""
    print "*This PR body was auto-generated from the plan file: `" plan_path "`*"
}'
