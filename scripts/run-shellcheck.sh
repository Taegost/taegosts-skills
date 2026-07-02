#!/usr/bin/env bash
# Run shellcheck on all test scripts
# Usage: scripts/run-shellcheck.sh [--fix]
set -uo pipefail

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat <<'EOF'
Usage: run-shellcheck.sh [--fix]

Run shellcheck on all test scripts to catch shell safety issues.

Options:
  --fix    Attempt to auto-fix issues (requires shellcheck --format=diff)

Exit codes:
  0 - all scripts pass shellcheck
  1 - shellcheck not installed
  2 - shellcheck found issues

Requires: shellcheck (https://www.shellcheck.net/)
Install: apt-get install shellcheck (or brew install shellcheck)
EOF
  exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd || exit 1)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd || exit 1)"

# Check if shellcheck is installed
if ! command -v shellcheck &>/dev/null; then
  echo "ERROR: shellcheck is not installed."
  echo "Install it with: apt-get install shellcheck (or brew install shellcheck)"
  echo "See: https://www.shellcheck.net/"
  exit 1
fi

# Find all test scripts
test_scripts=()
while IFS= read -r -d '' file; do
  test_scripts+=("$file")
done < <(find "$REPO_ROOT/tests" -name "*.sh" -type f -print0)

if [[ ${#test_scripts[@]} -eq 0 ]]; then
  echo "No test scripts found."
  exit 0
fi

echo "=== Running shellcheck on ${#test_scripts[@]} test scripts ==="

issues=0
for script in "${test_scripts[@]}"; do
  rel_path="${script#$REPO_ROOT/}"
  if ! shellcheck "$script" 2>/dev/null; then
    echo "FAIL: $rel_path"
    issues=$((issues + 1))
  else
    echo "PASS: $rel_path"
  fi
done

echo ""
if [[ $issues -eq 0 ]]; then
  echo "All scripts pass shellcheck."
  exit 0
else
  echo "$issues script(s) have shellcheck issues."
  exit 2
fi
