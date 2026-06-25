#!/usr/bin/env bash
# U6: classify-document.sh — detect document type from content signals
# Input: Document path
# Output: JSON with type, signals, confidence
# Exit codes: 0 success, 1 error

set -uo pipefail

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat <<'EOF'
Usage: classify-document.sh DOCUMENT_PATH

Classify a document as "requirements" or "plan" based on content signals.

Signals detected:
  has_implementation_units  - Contains U1/U2/... style unit IDs
  has_u_ids                 - Contains U# references
  frontmatter_type_feat     - Frontmatter has type: feat
  has_dependency_graph      - Contains dependency graph section
  has_build_order           - Contains build order section
  has_user_stories          - Contains user story patterns (As a..., I want...)
  has_acceptance_criteria   - Contains acceptance criteria
  has_requirements_table    - Contains requirements table

Output: JSON with:
  type       - "plan" or "requirements" or "unknown"
  signals    - list of detected signals
  confidence - "high", "medium", or "low"

Exit codes:
  0 - success
  1 - error (file not found, not readable)
EOF
  exit 0
fi

if [[ $# -ne 1 ]]; then
  echo '{"error":"exactly one argument required: document path"}' >&2
  exit 1
fi

doc_path="$1"

# R10: validate input path
if [[ "$doc_path" =~ [\;\|\&\$\`\] ]]; then
  echo '{"error":"invalid path (contains shell metacharacters)"}' >&2
  exit 1
fi

if [[ ! -f "$doc_path" ]]; then
  echo '{"error":"file not found"}' >&2
  exit 1
fi

if [[ ! -r "$doc_path" ]]; then
  echo '{"error":"file not readable"}' >&2
  exit 1
fi

content=$(<"$doc_path")

# Signal detection
signals=()
plan_score=0
req_score=0

# Check for implementation units (U1, U2, etc.)
if echo "$content" | grep -qE '## U[0-9]+:'; then
  signals+=("has_implementation_units")
  plan_score=$((plan_score + 3))
fi

# Check for U# ID references
if echo "$content" | grep -qE '\bU[0-9]+\b'; then
  signals+=("has_u_ids")
  plan_score=$((plan_score + 2))
fi

# Check frontmatter type field
in_frontmatter=false
fm_count=0
frontmatter_type=""
while IFS= read -r line; do
  if [[ "$line" == "---" ]]; then
    fm_count=$((fm_count + 1))
    if [[ $fm_count -ge 2 ]]; then break; fi
    in_frontmatter=true
    continue
  fi
  if $in_frontmatter && [[ "$line" =~ ^type:\ (.*) ]]; then
    frontmatter_type="${BASH_REMATCH[1]}"
    frontmatter_type="${frontmatter_type#\"}"
    frontmatter_type="${frontmatter_type%\"}"
  fi
done <<< "$content"

if [[ "$frontmatter_type" == "feat" || "$frontmatter_type" == "fix" || "$frontmatter_type" == "chore" ]]; then
  signals+=("frontmatter_type_${frontmatter_type}")
  plan_score=$((plan_score + 2))
fi

# Check for dependency graph
if echo "$content" | grep -qi "dependency graph"; then
  signals+=("has_dependency_graph")
  plan_score=$((plan_score + 2))
fi

# Check for build order
if echo "$content" | grep -qi "build order"; then
  signals+=("has_build_order")
  plan_score=$((plan_score + 2))
fi

# Check for user stories (requirements signal)
if echo "$content" | grep -qiE '(as a .*,|i want to |so that )'; then
  signals+=("has_user_stories")
  req_score=$((req_score + 3))
fi

# Check for acceptance criteria
if echo "$content" | grep -qi "acceptance criteria"; then
  signals+=("has_acceptance_criteria")
  req_score=$((req_score + 3))
fi

# Check for requirements table (R1, R2, etc.)
if echo "$content" | grep -qE '\| R[0-9]+ \|'; then
  signals+=("has_requirements_table")
  req_score=$((req_score + 2))
fi

# Determine type and confidence
if [[ $plan_score -gt $req_score ]] && [[ $plan_score -gt 0 ]]; then
  doc_type="plan"
  if [[ $plan_score -ge 5 ]]; then
    confidence="high"
  elif [[ $plan_score -ge 3 ]]; then
    confidence="medium"
  else
    confidence="low"
  fi
elif [[ $req_score -gt 0 ]]; then
  doc_type="requirements"
  if [[ $req_score -ge 5 ]]; then
    confidence="high"
  elif [[ $req_score -ge 3 ]]; then
    confidence="medium"
  else
    confidence="low"
  fi
else
  doc_type="unknown"
  confidence="low"
fi

# Build signals JSON array
signals_json="["
for i in "${!signals[@]}"; do
  [[ $i -gt 0 ]] && signals_json+=","
  signals_json+="\"${signals[$i]}\""
done
signals_json+="]"

echo "{\"type\":\"$doc_type\",\"signals\":$signals_json,\"confidence\":\"$confidence\"}"
