#!/usr/bin/env bash
# wait-for-file.sh -- Poll for file existence.
# Usage: wait-for-file.sh <file_path> [timeout_seconds] [poll_interval_seconds]
#
# Returns 0 when file appears, 1 after timeout.
# Default timeout: 180s (3 minutes). Default poll interval: 10s.
# `:?` fails immediately if the arg is unset or empty — stricter than `${1:-default}`
# which would accept an empty string. `set -euo pipefail` ensures any unset variable
# or failed command in the pipeline terminates the script early.
set -euo pipefail

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  echo "Usage: wait-for-file.sh <file_path> [timeout_seconds] [poll_interval_seconds]"
  echo ""
  echo "Poll for file existence."
  echo ""
  echo "Arguments:"
  echo "  file_path                Path to wait for (required)"
  echo "  timeout_seconds          Max seconds to wait (default: 180)"
  echo "  poll_interval_seconds    Seconds between checks (default: 10)"
  echo ""
  echo "Exit codes: 0 (file found), 1 (timeout)"
  exit 0
fi

FILE_PATH="${1:?Usage: wait-for-file.sh <file_path> [timeout_seconds] [poll_interval_seconds]}"
TIMEOUT="${2:-180}"
INTERVAL="${3:-10}"

ELAPSED=0
while [[ $ELAPSED -lt $TIMEOUT ]]; do
  if [[ -f "$FILE_PATH" ]]; then
    echo "File found: $FILE_PATH (after ${ELAPSED}s)"
    exit 0
  fi
  sleep "$INTERVAL"
  ELAPSED=$((ELAPSED + INTERVAL))
done

echo "Timeout after ${TIMEOUT}s: $FILE_PATH not found" >&2
exit 1
