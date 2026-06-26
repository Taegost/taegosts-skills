#!/usr/bin/env bash
# to-json.sh — Safe JSON output for bash scripts
# Wraps jq for reliable JSON construction. No embedded Python.
#
# Usage:
#   to-json.sh key1=value1 key2=value2              # simple object
#   to-json.sh --array item1 item2 item3             # simple array
#   echo '{"nested": true}' | to-json.sh --wrap key1 # wrap existing JSON
#   to-json.sh --help
#
# Value coercion: values that parse as valid JSON literals (true, false, null,
# integers, floats) are typed automatically. All other values are strings.
# This matches jq's own semantics. Use --strings to force all values to strings.
#
# Output: Valid JSON on stdout
# Exit codes: 0 (success), 1 (error)

set -euo pipefail

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  echo "Usage: to-json.sh [options] [key=value ...]"
  echo ""
  echo "Safe JSON construction for bash scripts (jq wrapper)."
  echo ""
  echo "Options:"
  echo "  --array item1 item2 ...   Output a JSON array"
  echo "  --wrap key                Read JSON from stdin, wrap as {\"key\": <stdin>}"
  echo "  --strings                 Force all values to strings (no coercion)"
  echo ""
  echo "Value coercion: values matching JSON literals (true/false/null/numbers)"
  echo "are typed automatically. All others are strings."
  echo ""
  echo "Exit codes: 0 (success), 1 (error)"
  exit 0
fi

if ! command -v jq &>/dev/null; then
  echo "to-json.sh: jq is required but not installed" >&2
  exit 1
fi

if [[ "${1:-}" == "--array" ]]; then
  shift
  # Filter out the bare '--' if present
  args=()
  for a in "$@"; do
    [[ "$a" != "--" ]] && args+=("$a")
  done
  printf '%s\n' "${args[@]}" | jq -R . | jq -s .
  exit 0
fi

if [[ "${1:-}" == "--wrap" ]]; then
  key="$2"
  jq -n --arg key "$key" --argjson val "$(cat)" '{($key): $val}'
  exit 0
fi

# Parse key=value pairs
strings_mode=false
if [[ "${1:-}" == "--strings" ]]; then
  strings_mode=true
  shift
fi

# Build jq arguments from key=value pairs
jq_args=()
filter_parts=()

for arg in "$@"; do
  [[ "$arg" == "--" ]] && continue
  if [[ "$arg" != *"="* ]]; then
    echo "to-json.sh: invalid argument '$arg' (expected key=value)" >&2
    exit 1
  fi
  key="${arg%%=*}"
  val="${arg#*=}"

  if [[ "$strings_mode" == "true" ]]; then
    jq_args+=(--arg "$key" "$val")
    filter_parts+=("(\"\$${key}\")")
  else
    # Try --argjson first; fall back to --arg if it's not a valid JSON literal
    if jq -n --argjson v "$val" '.' &>/dev/null 2>&1; then
      jq_args+=(--argjson "$key" "$val")
      filter_parts+=("(\"\$${key}\")")
    else
      jq_args+=(--arg "$key" "$val")
      filter_parts+=("(\"\$${key}\")")
    fi
  fi
done

# Build the filter: {key1: $key1, key2: $key2, ...}
filter="{"
first=true
for arg in "$@"; do
  [[ "$arg" == "--" ]] && continue
  key="${arg%%=*}"
  if [[ "$first" == "true" ]]; then
    filter+="\"$key\": \$${key}"
    first=false
  else
    filter+=", \"$key\": \$${key}"
  fi
done
filter+="}"

jq -n "${jq_args[@]}" "$filter"

