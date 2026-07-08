#!/usr/bin/env bash
# verify-coverage-threshold.sh -- Check if coverage meets a minimum threshold
# Input: --coverage-file <path> --threshold <number>
# Output: JSON {success, coverage, threshold, message}
# Exit codes: 0 coverage >= threshold, 1 coverage < threshold, 2 error

set -euo pipefail

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat <<'EOF'
Usage: verify-coverage-threshold.sh --coverage-file <path> --threshold <number>

Check if code coverage meets a minimum threshold.

Arguments:
  --coverage-file <path>    Path to file containing coverage percentage
  --threshold <number>      Minimum coverage percentage required (0-100)

Output: JSON with:
  success    - true if coverage >= threshold, false otherwise
  coverage   - the actual coverage percentage found
  threshold  - the threshold that was checked against
  message    - human-readable result message

Exit codes:
  0 - coverage meets or exceeds threshold
  1 - coverage below threshold
  2 - error (missing args, invalid input, file not found)

Examples:
  verify-coverage-threshold.sh --coverage-file coverage.txt --threshold 80
  verify-coverage-threshold.sh --coverage-file report.txt --threshold 90
EOF
  exit 0
fi

# Parse arguments
coverage_file="" threshold=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --coverage-file)
      [[ $# -ge 2 ]] || { echo '{"ok":false,"error":"--coverage-file requires a value"}' >&2; exit 2; }
      coverage_file="$2"; shift 2 ;;
    --threshold)
      [[ $# -ge 2 ]] || { echo '{"ok":false,"error":"--threshold requires a value"}' >&2; exit 2; }
      threshold="$2"; shift 2 ;;
    -h|--help)
      # Already handled above, but allow it mid-args
      echo "Run with --help for usage information." >&2; exit 0 ;;
    *)
      echo "{\"ok\":false,\"error\":\"unknown argument: $1\"}" >&2; exit 2 ;;
  esac
done

# Validate required arguments
if [[ -z "$coverage_file" ]]; then
  echo '{"ok":false,"error":"--coverage-file is required"}' >&2
  exit 2
fi

if [[ -z "$threshold" ]]; then
  echo '{"ok":false,"error":"--threshold is required"}' >&2
  exit 2
fi

# Validate threshold is numeric (integer or decimal)
if ! [[ "$threshold" =~ ^[0-9]+\.?[0-9]*$ ]]; then
  echo '{"ok":false,"error":"--threshold must be a numeric value"}' >&2
  exit 2
fi

# Validate threshold is in range 0-100
if (( $(echo "$threshold < 0" | bc -l) )) || (( $(echo "$threshold > 100" | bc -l) )); then
  echo '{"ok":false,"error":"--threshold must be between 0 and 100"}' >&2
  exit 2
fi

# Validate coverage file exists
if [[ ! -f "$coverage_file" ]]; then
  echo "{\"ok\":false,\"error\":\"coverage file not found: $coverage_file\"}" >&2
  exit 2
fi

# Read coverage percentage from file
# Supports formats: "85.5%", "Coverage: 85.5%", "85.5", "Total coverage: 85.5%"
coverage_value=""

# Try to extract a percentage number from the file content
# Match patterns like: 85.5%, Coverage: 85.5, Total: 85.5%, plain number
raw_content=$(cat "$coverage_file")

# First try: look for a percentage number (with or without % sign)
if [[ "$raw_content" =~ ([0-9]+\.?[0-9]*)% ]]; then
  coverage_value="${BASH_REMATCH[1]}"
elif [[ "$raw_content" =~ ([0-9]+\.?[0-9]*)[[:space:]]*$ ]]; then
  # Try: last number on a line (plain number)
  coverage_value="${BASH_REMATCH[1]}"
elif [[ "$raw_content" =~ ([0-9]+\.?[0-9]*) ]]; then
  # Fallback: first number found in the file
  coverage_value="${BASH_REMATCH[1]}"
fi

if [[ -z "$coverage_value" ]]; then
  echo '{"ok":false,"error":"could not extract coverage percentage from file"}' >&2
  exit 2
fi

# Validate extracted coverage is a valid number
if ! [[ "$coverage_value" =~ ^[0-9]+\.?[0-9]*$ ]]; then
  echo '{"ok":false,"error":"extracted coverage value is not numeric"}' >&2
  exit 2
fi

# Compare coverage against threshold using bc for decimal support
meets_threshold=$(echo "$coverage_value >= $threshold" | bc -l)

if [[ "$meets_threshold" -eq 1 ]]; then
  # Coverage meets or exceeds threshold
  echo "{\"success\":true,\"coverage\":$coverage_value,\"threshold\":$threshold,\"message\":\"Coverage $coverage_value% meets threshold of $threshold%\"}"
  exit 0
else
  # Coverage below threshold
  echo "{\"success\":false,\"coverage\":$coverage_value,\"threshold\":$threshold,\"message\":\"Coverage $coverage_value% is below threshold of $threshold%\"}"
  exit 1
fi
