#!/usr/bin/env bash
# run-shellcheck.sh -- Run shellcheck on all shell scripts in the repository
# Usage: scripts/run-shellcheck.sh
set -euo pipefail

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat <<'EOF'
Usage: run-shellcheck.sh

Run shellcheck on all shell scripts in the repository to catch shell safety issues.

Scans:
  - tests/        (test scripts)
  - scripts/      (repo scripts)
  - skills/*/scripts/  (skill scripts)

Exit codes:
  0 - all scripts pass shellcheck
  1 - shellcheck not installed
  2 - shellcheck found issues

Requires: shellcheck (https://www.shellcheck.net/)
Install: apt-get install shellcheck (or brew install shellcheck)

Configuration: see .shellcheckrc in the repo root for project-level settings.
EOF
  exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)" || { echo "ERROR: cannot resolve script directory"; exit 1; }
REPO_ROOT="$(cd "$SCRIPT_DIR/.." 2>/dev/null && pwd)" || { echo "ERROR: cannot resolve repo root"; exit 1; }

# Check if shellcheck is installed
if ! command -v shellcheck &>/dev/null; then
  echo "ERROR: shellcheck is not installed."
  echo "Install it with: apt-get install shellcheck (or brew install shellcheck)"
  echo "See: https://www.shellcheck.net/"
  exit 1
fi

# Find all shell scripts across tests, scripts, and skills
all_scripts=()
while IFS= read -r -d '' file; do
  all_scripts+=("$file")
done < <(find "$REPO_ROOT/tests" "$REPO_ROOT/scripts" "$REPO_ROOT/skills" -name "*.sh" -type f -print0 2>/dev/null)

if [[ ${#all_scripts[@]} -eq 0 ]]; then
  echo "No shell scripts found."
  exit 0
fi

echo "=== Running shellcheck on ${#all_scripts[@]} shell scripts ==="

issues=0
for script in "${all_scripts[@]}"; do
  rel_path="${script#"$REPO_ROOT"/}"
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
