#!/usr/bin/env bash
# verify-scripts.sh — Pre-commit gate for scripts
# Runs all validation checks in one pass. Use before committing.
#
# Usage:
#   verify-scripts.sh [dir]           # verify all .sh and .py in dir
#   verify-scripts.sh --file path     # verify a single file
#   verify-scripts.sh --all           # verify scripts/ and skills/*/scripts/
#   verify-scripts.sh --help
#
# Checks per file:
#   .sh files: bash -n, control chars, --help flag, executable
#   .py files: python3 -m py_compile, control chars, --help flag, executable
#
# Exit codes: 0 (all pass), 1 (one or more failures)

set -eo pipefail

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  echo "Usage: verify-scripts.sh [dir|--file path|--all]"
  echo ""
  echo "Pre-commit gate for scripts. Runs all validation checks."
  echo ""
  echo "Checks: syntax, control characters, --help flag, executable bit"
  echo "Exit codes: 0 (all pass), 1 (failures)"
  exit 0
fi

total_files=0
failures=()

check_file() {
  local f="$1"
  local name
  name=$(basename "$f")
  local file_failures=0
  local is_supported=false

  if [[ "$f" == *.sh ]]; then
    is_supported=true
    if ! bash -n "$f" 2>/dev/null; then
      failures+=("$name: bash syntax error")
      file_failures=$((file_failures + 1))
    fi
  elif [[ "$f" == *.py ]]; then
    is_supported=true
    if ! python3 -m py_compile "$f" 2>/dev/null; then
      failures+=("$name: Python syntax error")
      file_failures=$((file_failures + 1))
    fi
  fi

  # Skip remaining checks for unsupported extensions
  if [[ "$is_supported" != "true" ]]; then
    return 0
  fi

  # Control character check (portable — no grep -P)
  if ! python3 -c "
import sys
with open(sys.argv[1], 'rb') as f:
    data = f.read()
for b in data:
    if b in (0x09, 0x0a, 0x0d):
        continue
    if 0x00 <= b <= 0x1f or b == 0x7f:
        sys.exit(1)
" "$f" 2>/dev/null; then
    failures+=("$name: control characters found")
    file_failures=$((file_failures + 1))
  fi

  # Executable check
  if [[ ! -x "$f" ]]; then
    failures+=("$name: not executable")
    file_failures=$((file_failures + 1))
  fi

  # --help flag check
  if ! grep -q '\-\-help' "$f" 2>/dev/null; then
    failures+=("$name: missing --help flag")
    file_failures=$((file_failures + 1))
  fi

  # Only count as passed if no failures
  if [[ $file_failures -eq 0 ]]; then
    total_files=$((total_files + 1))
  fi
}

# Determine what to check
if [[ "${1:-}" == "--all" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

  files=()
  if [[ -d "$REPO_ROOT/scripts" ]]; then
    while IFS= read -r f; do files+=("$f"); done < <(find "$REPO_ROOT/scripts" \( -name "*.sh" -o -name "*.py" \) | sort)
  fi
  if [[ -d "$REPO_ROOT/skills" ]]; then
    while IFS= read -r f; do files+=("$f"); done < <(find "$REPO_ROOT/skills" \( -path "*/scripts/*.sh" -o -path "*/scripts/*.py" \) | sort)
  fi
elif [[ "${1:-}" == "--file" ]]; then
  files=("$2")
elif [[ -d "${1:-.}" ]]; then
  files=()
  while IFS= read -r f; do files+=("$f"); done < <(find "${1:-.}" \( -name "*.sh" -o -name "*.py" \) | sort)
else
  echo "verify-scripts.sh: no files to check" >&2
  exit 1
fi

echo "=== verify-scripts.sh: checking ${#files[@]} files ==="

for f in "${files[@]}"; do
  check_file "$f"
done

echo ""
echo "=== Results: $total_files passed, ${#failures[@]} failures ==="

if [[ ${#failures[@]} -gt 0 ]]; then
  for f in "${failures[@]}"; do
    echo "  FAIL: $f"
  done
  exit 1
fi

echo "All checks passed."
exit 0
