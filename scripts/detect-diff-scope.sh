#!/usr/bin/env bash
# detect-diff-scope.sh -- Compute diff scope and detect which reviewers apply
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  echo "Usage: detect-diff-scope.sh [--base <ref>] [--pr <number>] [--branch <name>]"
  echo ""
  echo "Compute diff scope and detect which reviewers apply."
  echo "Output: JSON with mode, base, head, files_changed, has_migrations, has_tests, diff_line_count"
  echo "Exit codes: 0 (success), 1 (error)"
  exit 0
fi

mode="branch" base="" pr_number="" branch_name=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --base) mode="base"; base="$2"; shift 2 ;;
    --pr) mode="pr-remote"; pr_number="$2"; shift 2 ;;
    --branch) branch_name="$2"; shift 2 ;;
    *) shift ;;
  esac
done

if [[ -z "$base" && "$mode" != "pr-remote" ]]; then
  base=$("$SCRIPT_DIR/default-branch.sh" 2>/dev/null || echo "main")
fi

if [[ "$mode" == "pr-remote" ]]; then
  command -v gh >/dev/null 2>&1 || { echo "gh CLI required for --pr mode" >&2; exit 1; }
  diff_output=$(gh pr diff "$pr_number" --color=never 2>/dev/null || echo "")
  head_ref=$(gh pr view "$pr_number" --json headRefName --jq '.headRefName' 2>/dev/null || echo "unknown")
  base_ref=$(gh pr view "$pr_number" --json baseRefName --jq '.baseRefName' 2>/dev/null || echo "unknown")
else
  # Use branch_name directly in diff if provided — do not checkout
  base_ref="$base"
  if [[ -n "$branch_name" ]]; then
    diff_output=$(git diff "${base}...${branch_name}" 2>/dev/null || echo "")
    head_ref="$branch_name"
  else
    diff_output=$(git diff "${base}...HEAD" 2>/dev/null || echo "")
    head_ref=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
  fi
fi

files_changed=() has_migrations=false has_tests=false diff_line_count=0
[[ -z "$diff_output" ]] && diff_output=""
while IFS= read -r line; do
  if [[ "$line" == "diff --git"* ]]; then
    # Handle git's C-style quoting for filenames with special characters
    raw="${line#diff --git }"
    case "$raw" in
      '"a/'*) raw="${raw#\"a/}" ;;
      'a/'*)  raw="${raw#a/}" ;;
    esac
    case "$raw" in
      *' "b/'*) raw="${raw%%' "b/'*}" ;;
      *' b/'*)  raw="${raw%%' b/'*}" ;;
    esac
    # Remove surrounding quotes if present
    file="${raw%\"}"
    file="${file#\"}"
    files_changed+=("$file")
    if echo "$file" | grep -qiE '(migrate|migration|alembic|flyway|liquibase|db/migrate)'; then
      has_migrations=true
    fi
    if echo "$file" | grep -qiE '(test|spec|_test\.|\.test\.|\.spec\.)'; then
      has_tests=true
    fi
  fi
  diff_line_count=$((diff_line_count + 1))
done <<< "$diff_output"

files_json="[" first=true
for f in "${files_changed[@]}"; do
  [[ -z "$f" ]] && continue
  [[ "$first" == "true" ]] && first=false || files_json+=","
  # Escape backslashes first, then quotes, for valid JSON strings
  escaped="${f//\\/\\\\}"
  files_json+="\"${escaped//\"/\\\"}\""
done
files_json+="]"

cat <<JSONEOF
{"mode":"$mode","base":"$base_ref","head":"$head_ref","files_changed":$files_json,"has_migrations":$has_migrations,"has_tests":$has_tests,"diff_line_count":$diff_line_count}
JSONEOF
