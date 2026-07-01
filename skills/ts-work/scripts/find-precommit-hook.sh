#!/usr/bin/env bash
# U10: find-precommit-hook.sh - find pre-commit hooks and referenced scripts
# Output: JSON with {hook_path, scripts[]}
# Exit codes: 0 found hook, 1 error, 2 no hook found

set -uo pipefail

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat <<'EOF'
Usage: find-precommit-hook.sh

Find pre-commit hook in the current git repository and list referenced scripts.

Searches in order:
  1. .git/hooks/pre-commit
  2. .githooks/pre-commit
  Follows symlinks for both locations.

Output: JSON with:
  hook_path - path to the pre-commit hook
  scripts   - array of script paths referenced by or sourced from the hook

Exit codes:
  0 - hook found
  1 - error (not in a git repo)
  2 - no pre-commit hook found
EOF
  exit 0
fi

# Validate we are in a git repo
git_dir=$(git rev-parse --git-dir 2>/dev/null) || {
  echo '{"error":"not inside a git repository"}' >&2
  exit 1
}

hook_path=""
candidates=(
  "$git_dir/hooks/pre-commit"
  ".githooks/pre-commit"
)

for candidate in "${candidates[@]}"; do
  # Resolve symlinks
  if [[ -e "$candidate" ]]; then
    hook_path="$(readlink -f "$candidate" 2>/dev/null || echo "$candidate")"
    break
  fi
done

if [[ -z "$hook_path" ]]; then
  echo "No pre-commit hook found" >&2
  echo '{"hook_path":null,"scripts":[]}'
  exit 2
fi

# Collect scripts: the hook itself plus any sourced/referenced scripts
scripts=("$(basename "$hook_path")")
script_dir="$(dirname "$hook_path")"

if [[ -f "$hook_path" ]]; then
  while IFS= read -r line; do
    ref=""
    if [[ "$line" =~ ^[[:space:]]*\.[[:space:]]+(.+) ]]; then
      ref="${BASH_REMATCH[1]}"
    elif [[ "$line" =~ ^[[:space:]]*source[[:space:]]+(.+) ]]; then
      ref="${BASH_REMATCH[1]}"
    elif [[ "$line" =~ ^[[:space:]]*(bash|sh)[[:space:]]+(.+) ]]; then
      ref="${BASH_REMATCH[2]}"
    fi
    if [[ -n "$ref" ]]; then
      # Clean up quotes
      ref="${ref#\"}"
      ref="${ref%\"}"
      ref="${ref#\'}"
      ref="${ref%\'}"
      # Resolve relative to hook directory
      if [[ "$ref" == /* ]]; then
        abs_ref="$ref"
      else
        abs_ref="$script_dir/$ref"
      fi
      if [[ -f "$abs_ref" ]]; then
        resolved="$(readlink -f "$abs_ref" 2>/dev/null || echo "$abs_ref")"
        scripts+=("$resolved")
      fi
    fi
  done < "$hook_path"
fi

# Build JSON array
scripts_json="["
for i in "${!scripts[@]}"; do
  [[ $i -gt 0 ]] && scripts_json+=","
    _s="${scripts[$i]}"; _s="${_s//\\/\\\\}"; _s="${_s//\"/\\\"}"; scripts_json+="\"${_s}\""
done
scripts_json+="]"

# Escape hook_path for JSON
escaped_hook="${hook_path//\\/\\\\}"
escaped_hook="${escaped_hook//\"/\\\"}"

echo "{\"hook_path\":\"$escaped_hook\",\"scripts\":$scripts_json}"
