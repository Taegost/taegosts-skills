#!/usr/bin/env bash
# run-id.sh -- Generate a timestamp-hex run ID
# Output: YYYYMMDD-HHMMSS-XXXX (date-time-4hex)
# Exit codes: 0 success, 1 error

set -euo pipefail

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat <<'EOF'
Usage: run-id.sh

Generate a unique run identifier in the format YYYYMMDD-HHMMSS-XXXX.

Arguments: none
Output:    Run ID string on stdout (e.g., 20260625-143052-a1b2)
Exit codes:
  0 - success
  1 - error
EOF
  exit 0
fi

# Generate timestamp
timestamp=$(date +%Y%m%d-%H%M%S)

# Generate 4-char hex suffix
hex_suffix=$(head -c 2 /dev/urandom | od -An -tx1 | tr -d ' \n')

echo "${timestamp}-${hex_suffix}"
