#!/usr/bin/env bash
# U3: solutions-search.sh — search docs/solutions/ for matching conventions
# Input: keywords as arguments
# Output: JSON array with keyword, path, title, excerpt
# Exit codes: 0 matches found, 1 error, 2 no matches found
# R10: validate inputs, reject shell metacharacters

set -uo pipefail

SOLUTIONS_DIR="${SOLUTIONS_DIR:-docs/solutions}"

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat <<'EOF'
Usage: solutions-search.sh [--solutions-dir DIR] KEYWORD [KEYWORD ...]

Search docs/solutions/ frontmatter and content for matching keywords.
Returns JSON array of matches with paths, titles, and excerpts.

Arguments:
  --solutions-dir DIR   Override solutions directory (default: docs/solutions)
  KEYWORD               One or more keywords to search for

Output: JSON array of:
  {
    "keyword": "valkey",
    "path": "docs/solutions/conventions/honcho-deployment-patterns.md",
    "title": "Honcho Deployment Patterns",
    "excerpt": "Run Valkey/Redis without auth..."
  }

Exit codes:
  0 - matches found
  1 - error (invalid input, directory not found)
  2 - no matches found
EOF
  exit 0
fi

# Parse arguments
keywords=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --solutions-dir)
      SOLUTIONS_DIR="$2"
      shift 2
      ;;
    *)
      keywords+=("$1")
      shift
      ;;
  esac
done

# Validate we have keywords
if [[ ${#keywords[@]} -eq 0 ]]; then
  echo '{"error":"no keywords provided"}' >&2
  exit 1
fi

# R10: validate inputs — reject shell metacharacters
for kw in "${keywords[@]}"; do
  if [[ "$kw" =~ [\;\|\&\$\(\)\{\}\`\\\<\>\"\'] ]]; then
    echo "{\"error\":\"invalid keyword: $kw (contains shell metacharacters)\"}" >&2
    exit 1
  fi
done

# Check solutions directory exists
if [[ ! -d "$SOLUTIONS_DIR" ]]; then
  echo '{"error":"solutions directory not found"}' >&2
  exit 1
fi

search_results=()
found_any=false

for kw in "${keywords[@]}"; do
  while IFS= read -r -d '' file; do
    content=$(<"$file")

    # Extract frontmatter
    title=""
    tags=""
    in_frontmatter=false
    fm_count=0
    body=""
    while IFS= read -r line; do
      if [[ "$line" == "---" ]]; then
        fm_count=$((fm_count + 1))
        if [[ $fm_count -eq 1 ]]; then
          in_frontmatter=true
          continue
        elif [[ $fm_count -eq 2 ]]; then
          in_frontmatter=false
          continue
        fi
      fi
      if $in_frontmatter; then
        if [[ "$line" =~ ^title:\ (.*) ]]; then
          title="${BASH_REMATCH[1]}"
          title="${title#\"}"
          title="${title%\"}"
        fi
        if [[ "$line" =~ ^tags: ]]; then
          tags="$line"
        fi
      else
        body+="$line"$'\n'
      fi
    done <<< "$content"

    # Case-insensitive keyword match
    lower_kw=$(echo "$kw" | tr '[:upper:]' '[:lower:]')
    lower_content=$(echo "$title $tags $body" | tr '[:upper:]' '[:lower:]')

    if [[ "$lower_content" == *"$lower_kw"* ]]; then
      found_any=true

      # Get excerpt from first matching non-heading line in body
      excerpt=""
      while IFS= read -r line; do
        lower_line=$(echo "$line" | tr '[:upper:]' '[:lower:]')
        if [[ "$lower_line" == *"$lower_kw"* ]] && [[ -n "$line" ]] && [[ "$line" != \#* ]]; then
          excerpt="$line"
          break
        fi
      done <<< "$body"

      # Shorten excerpt to 200 chars at word boundary
      if [[ ${#excerpt} -gt 200 ]]; then
        excerpt="${excerpt:0:197}"
        last_space=$(echo "$excerpt" | grep -bo ' ' | tail -1 | cut -d: -f1)
        if [[ -n "$last_space" ]]; then
          excerpt="${excerpt:0:$last_space}..."
        else
          excerpt="$excerpt..."
        fi
      fi

      # Escape for JSON
      json_title=$(printf '%s' "$title" | sed 's/\\\\/\\\\\\\\/g; s/\"/\\\\\"/g')
      json_excerpt=$(printf '%s' "$excerpt" | sed 's/\\\\/\\\\\\\\/g; s/\"/\\\\\"/g; s/\t/\\t/g' | tr '\n' ' ')
      rel_path="${file#$(pwd)/}"

      search_results+=("{\"keyword\":\"$kw\",\"path\":\"$rel_path\",\"title\":\"$json_title\",\"excerpt\":\"$json_excerpt\"}")
    fi
  done < <(find "$SOLUTIONS_DIR" -name '*.md' -type f -print0)
done

if ! $found_any; then
  echo "[]"
  exit 2
fi

printf '['
for i in "${!search_results[@]}"; do
  [[ $i -gt 0 ]] && printf ','
  printf '%s' "${search_results[$i]}"
done
printf ']\n'
