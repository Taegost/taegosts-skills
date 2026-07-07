#!/usr/bin/env bash
# select-reviewers.sh -- Determine which code-review agents apply based on changed files
set -euo pipefail

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  echo "Usage: select-reviewers.sh [--files <file>]"
  echo "Determine which code-review agents apply based on changed files."
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
  # Independent predicate checks — each evaluated regardless of prior matches
  # Skip "testing" since it is always_on
  if [[ "$f" == *auth* ]] || [[ "$f" == *login* ]] || [[ "$f" == *session* ]] || [[ "$f" == *middleware* ]] || [[ "$f" == *permission* ]]; then
    conditional+=("security"); rationale_parts+=("\"security\":\"auth/session files changed\"")
  fi
  if [[ "$f" == *migrate* ]] || [[ "$f" == *migration* ]] || [[ "$f" == *schema* ]] || [[ "$f" == *alembic* ]] || [[ "$f" == *flyway* ]]; then
    conditional+=("data-migration"); rationale_parts+=("\"data-migration\":\"migration files changed\"")
  fi
  # testing predicate skipped — already in always_on
  if [[ "$f" == *deploy* ]] || [[ "$f" == *docker* ]] || [[ "$f" == *k8s* ]] || [[ "$f" == *kubernetes* ]] || [[ "$f" == *helm* ]]; then
    conditional+=("deployment-verification"); rationale_parts+=("\"deployment-verification\":\"deployment files changed\"")
  fi
  if [[ "$f" == *.db* ]] || [[ "$f" == *database* ]] || [[ "$f" == *query* ]] || [[ "$f" == *orm* ]]; then
    conditional+=("performance"); rationale_parts+=("\"performance\":\"database files changed\"")
  fi
  if [[ "$f" == *api* ]] || [[ "$f" == *route* ]] || [[ "$f" == *controller* ]] || [[ "$f" == *endpoint* ]]; then
    conditional+=("api-contract"); rationale_parts+=("\"api-contract\":\"API files changed\"")
  fi
done <<< "$files"

# Deduplicate conditional
mapfile -t conditional_unique < <(printf '%s\n' "${conditional[@]}" | sort -u 2>/dev/null)

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
