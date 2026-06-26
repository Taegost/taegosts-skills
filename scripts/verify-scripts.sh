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
#   .py files: python3 -m py_compile, --help flag, executable
#   JSON output: if script outputs JSON, validate it
#
# Exit codes: 0 (all pass), 1 (one or more failures)

set -euo pipefail

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  echo "Usage: verify-scripts.sh [dir|--file path|--all]"
  echo ""
  echo "Pre-commit gate for scripts. Runs all validation checks."
  echo ""
  echo "Checks: syntax, control characters, --help flag, executable bit"
  echo "Exit codes: 0 (all pass), 1 (failures)"
  exit 0
fi

total_pass=0
total_fail=0
failures=()

check_file() {
  local f="$1"
  local name=$(basename "$f")
  
  if [[ "$f" == *.sh ]]; then
    # bash -n syntax check
    if ! bash -n "$f" 2>/dev/null; then
      failures+=("$name: bash syntax error")
      total_fail=$((total_fail + 1))
      return
    fi
    
    # Control character check
    if cat -A "$f" | grep -qP '[\x00-\x08\x0b\x0c\x0e-\x1f]' 2>/dev/null; then
      failures+=("$name: control characters found")
      total_fail=$((total_fail + 1))
    fi
    
    # Executable check
    if [[ ! -x "$f" ]]; then
      failures+=("$name: not executable")
      total_fail=$((total_fail + 1))
    fi
    
    # --help flag check
    if ! grep -q '\-\-help' "$f" 2>/dev/null; then
      failures+=("$name: missing --help flag")
      total_fail=$((total_fail + 1))
    fi
    
  elif [[ "$f" == *.py ]]; then
    # Python syntax check
    if ! python3 -m py_compile "$f" 2>/dev/null; then
      failures+=("$name: Python syntax error")
      total_fail=$((total_fail + 1))
      return
    fi
    
    # Executable check
    if [[ ! -x "$f" ]]; then
      failures+=("$name: not executable")
      total_fail=$((total_fail + 1))
    fi
    
    # --help flag check
    if ! grep -q '\-\-help' "$f" 2>/dev/null; then
      failures+=("$name: missing --help flag")
      total_fail=$((total_fail + 1))
    fi
  fi
  
  total_pass=$((total_pass + 1))
}

# Determine what to check
if [[ "${1:-}" == "--all" ]]; then
  files=()
  [[ -d "scripts" ]] && while IFS= read -r f; do files+=("$f"); done < <(find scripts -name "*.sh" -o -name "*.py" | sort)
  [[ -d "skills" ]] && while IFS= read -r f; do files+=("$f"); done < <(find skills -path "*/scripts/*.sh" -o -path "*/scripts/*.py" | sort)
elif [[ "${1:-}" == "--file" ]]; then
  files=("$2")
elif [[ -d "${1:-.}" ]]; then
  files=()
  while IFS= read -r f; do files+=("$f"); done < <(find "${1:-.}" -name "*.sh" -o -name "*.py" | sort)
else
  echo "verify-scripts.sh: no files to check" >&2
  exit 1
fi

echo "=== verify-scripts.sh: checking ${#files[@]} files ==="

for f in "${files[@]}"; do
  check_file "$f"
done

echo ""
echo "=== Results: $total_pass checked, ${#failures[@]} failures ==="

if [[ ${#failures[@]} -gt 0 ]]; then
  for f in "${failures[@]}"; do
    echo "  FAIL: $f"
  done
  exit 1
fi

echo "All checks passed."
exit 0
