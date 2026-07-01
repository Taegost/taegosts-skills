#!/usr/bin/env bash
# U19: generate-plan-filename.sh - generate a plan filename with auto-incrementing sequence
# Input: --type feat|fix|chore --slug <string>
# Output: filename like 2026-06-25-002-feat-my-plan.md
# Exit codes: 0 success, 1 error

set -euo pipefail

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat <<'EOF'
Usage: generate-plan-filename.sh --type <feat|fix|chore> --slug <string>

Generate a plan filename with today's date and auto-incrementing sequence number.

Arguments:
  --type <feat|fix|chore>   Type of the plan
  --slug <string>           Slug for the plan name (lowercase, hyphens)

Output: filename like 2026-06-25-002-feat-my-plan.md

Looks in docs/plans/ for existing plans with today's date
and increments the sequence number. If no plans exist for today, starts at 001.

Exit codes:
  0 - success
  1 - error (bad input, invalid type)
EOF
  exit 0
fi

# Parse arguments
plan_type=""
slug=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --type)
      plan_type="$2"
      shift 2
      ;;
    --slug)
      slug="$2"
      shift 2
      ;;
    *)
      echo '{"error":"unknown argument"}' >&2
      exit 1
      ;;
  esac
done

# Validate required args
if [[ -z "$plan_type" ]]; then
  echo '{"error":"--type is required (feat, fix, or chore)"}' >&2
  exit 1
fi

if [[ -z "$slug" ]]; then
  echo '{"error":"--slug is required"}' >&2
  exit 1
fi

# Validate type
case "$plan_type" in
  feat|fix|chore) ;;
  *)
    echo '{"error":"--type must be feat, fix, or chore"}' >&2
    exit 1
    ;;
esac

# R10: validate slug - reject shell metacharacters and spaces
if [[ "$slug" =~ [\;\|\&\$\`\ ] ]]; then
  echo '{"error":"--slug contains invalid characters (spaces or shell metacharacters)"}' >&2
  exit 1
fi

# Get today's date
today=$(date +%Y-%m-%d)

# Plans directory
plans_dir="docs/plans"

# Count existing plans for today
max_seq=0
if [[ -d "$plans_dir" ]]; then
  for f in "$plans_dir"/${today}-[0-9][0-9][0-9]-*.md; do
    [[ -e "$f" ]] || continue
    # Extract sequence number
    basename_f="$(basename "$f")"
    if [[ "$basename_f" =~ ^${today}-([0-9]{3})- ]]; then
      seq_num=$((10#${BASH_REMATCH[1]}))
      if [[ $seq_num -gt $max_seq ]]; then
        max_seq=$seq_num
      fi
    fi
  done
fi

# Next sequence
next_seq=$((max_seq + 1))
seq_padded=$(printf "%03d" "$next_seq")

# Build filename
filename="${today}-${seq_padded}-${plan_type}-${slug}-plan.md"

echo "$filename"
