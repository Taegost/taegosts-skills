#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  echo "Usage: select-reviewers.sh [--files <file>]"
  echo "Determine which code-review personas apply based on changed files."
  echo "Reads file list from --files argument or stdin."
  echo "Output: JSON with {always_on: [], conditional: [], rationale: {}}"
  echo "Exit codes: 0 (success), 1 (error)"
  exit 0
fi

files_input=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --files) files_input="${2:-}"; [[ -z "$files_input" ]] && echo "missing value for --files" >&2 && exit 1; shift 2 ;;
    *) shift ;;
  esac
done

if [[ -n "$files_input" ]]; then
  [[ ! -f "$files_input" ]] && echo "file not found: $files_input" >&2 && exit 1
  files=$(cat "$files_input")
else
  files=$(cat)
fi

if [[ -n "$files_input" ]]; then echo "$files_input" | grep -qE '[;&|$`]' && echo "invalid characters" >&2 && exit 1; fi

always_on='["correctness","testing","maintainability","project-standards"]'
conditional=()
rationale_parts=()

while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  case "$f" in
    *auth*|*login*|*session*|*middleware*|*permission*)
      conditional+=("security"); rationale_parts+=("\"security\":\"auth/session files changed\"") ;;
    *migrate*|*migration*|*schema*|*alembic*|*flyway*)
      conditional+=("data-migration"); rationale_parts+=("\"data-migration\":\"migration files changed\"") ;;
    *test*|*spec*)
      conditional+=("testing"); rationale_parts+=("\"testing\":\"test files changed\"") ;;
    *deploy*|*docker*|*k8s*|*kubernetes*|*helm*)
      conditional+=("deployment-verification"); rationale_parts+=("\"deployment-verification\":\"deployment files changed\"") ;;
    *.db*|*database*|*query*|*orm*)
      conditional+=("performance"); rationale_parts+=("\"performance\":\"database files changed\"") ;;
    *api*|*route*|*controller*|*endpoint*)
      conditional+=("api-contract"); rationale_parts+=("\"api-contract\":\"API files changed\"") ;;
  esac
done <<< "$files"

# Deduplicate conditional
conditional_unique=($(printf '%s\n' "${conditional[@]}" | sort -u 2>/dev/null || echo ""))

# Build JSON
cond_json="["
first=true
for c in "${conditional_unique[@]}"; do
  [[ -z "$c" ]] && continue
  [[ "$first" == "true" ]] && first=false || cond_json+=","
  cond_json+="\"$c\""
done
cond_json+="]"

rationale_json="{"
first=true
# Deduplicate rationale_parts
readarray -t rationale_unique < <(printf "%s
" "${rationale_parts[@]}" | sort -u)
for r in "${rationale_unique[@]}"; do
  [[ -z "$r" ]] && continue
  [[ "$first" == "true" ]] && first=false || rationale_json+=","
  rationale_json+="$r"
done
rationale_json+="}"

cat <<JSONEOF
{
  "always_on": $always_on,
  "conditional": $cond_json,
  "rationale": $rationale_json
}
JSONEOF
