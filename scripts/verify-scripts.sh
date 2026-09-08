#!/usr/bin/env bash
# verify-scripts.sh -- Pre-commit gate for scripts
# Runs all validation checks in one pass. Use before committing.
#
# Usage:
#   verify-scripts.sh [dir]           # verify all .sh and .py in dir
#   verify-scripts.sh --file path     # verify a single file
#   verify-scripts.sh --all           # verify scripts/ and skills/*/scripts/
#   verify-scripts.sh --help
#
# Scope (docs/standards/script-extraction-standards.md, "Gate scope") is
# classified from the file's repo-relative path at check time, so it applies
# identically in all three modes:
#   tests/        out of scope -- skipped, not counted as passed
#   scripts/lib/  syntax + control-character checks only (sourced/imported
#                 libraries, never commands: no --help or exec-bit check)
#   all else      full check set
#
# Checks per file:
#   .sh files: bash -n, control chars, --help flag, executable
#   .py files: python3 -m py_compile, control chars, --help flag, executable
#
# Failures are reported by repo-relative path.
#
# Exit codes: 0 (all pass), 1 (one or more failures)

set -eo pipefail

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  echo "Usage: verify-scripts.sh [dir|--file path|--all]"
  echo ""
  echo "Pre-commit gate for scripts. Runs all validation checks."
  echo ""
  echo "Scope, classified from the repo-relative path (identical in all modes):"
  echo "  tests/          out of scope (skipped, not counted as passed)"
  echo "  scripts/lib/    syntax + control-character checks only (libraries are"
  echo "                  never commands: no --help or exec-bit check)"
  echo "  everything else syntax, control characters, --help flag, executable bit"
  echo ""
  echo "Failures are reported by repo-relative path."
  echo "Exit codes: 0 (all pass), 1 (failures)"
  exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Repo root: prefer the git work tree of the invoking directory (the gate is
# normally run from inside the repo it gates); fall back to the script's own
# repo when there is no enclosing work tree.
if ! REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
fi

total_files=0
skipped_scope=0
failures=()

# classify_scope <repo-relative-path> -- prints the check class for a file:
#   skip -- under tests/: not command-surface, out of scope entirely
#   lib  -- under scripts/lib/: syntax + control-characters only
#   full -- everything else: all checks
classify_scope() {
  case "$1" in
    tests/*) echo "skip" ;;
    scripts/lib/*) echo "lib" ;;
    *) echo "full" ;;
  esac
}

# rel_path <absolute-path> -- prints the path relative to REL_BASE, the root
# failures are reported (and classified) against.
rel_path() {
  printf '%s\n' "${1#"$REL_BASE"/}"
}

check_file() {
  local f="$1"
  local report_skip="${2:-}"
  local rel scope
  rel="$(rel_path "$f")"
  scope="$(classify_scope "$rel")"

  # Gate scope: classification is path-based at check time so every mode
  # (dir, --file, --all) shares this one choke point.
  if [[ "$scope" == "skip" ]]; then
    skipped_scope=$((skipped_scope + 1))
    if [[ "$report_skip" == "report-skip" ]]; then
      echo "  SKIP: $rel (out of scope: test scripts are not checked)"
    fi
    return 0
  fi

  local file_failures=0
  local is_supported=false

  if [[ "$f" == *.sh ]]; then
    is_supported=true
    if ! bash -n "$f" 2>/dev/null; then
      failures+=("$rel: bash syntax error")
      file_failures=$((file_failures + 1))
    fi
  elif [[ "$f" == *.py ]]; then
    is_supported=true
    if ! python3 -m py_compile "$f" 2>/dev/null; then
      failures+=("$rel: Python syntax error")
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
    failures+=("$rel: control characters found")
    file_failures=$((file_failures + 1))
  fi

  # Command-surface checks: --help and the executable bit apply to command
  # scripts only -- scripts/lib/ files are sourced/imported, never invoked.
  if [[ "$scope" == "full" ]]; then
    # Executable check
    if [[ ! -x "$f" ]]; then
      failures+=("$rel: not executable")
      file_failures=$((file_failures + 1))
    fi

    # --help flag check
    if ! grep -q '\-\-help' "$f" 2>/dev/null; then
      failures+=("$rel: missing --help flag")
      file_failures=$((file_failures + 1))
    fi
  fi

  # Only count as passed if no failures
  if [[ $file_failures -eq 0 ]]; then
    total_files=$((total_files + 1))
  fi
}

# REL_BASE: REPO_ROOT for anything scanned inside the repo; for a tree
# outside the repo (e.g. a test fixture) the scanned tree's own root, so the
# same tests/ and scripts/lib/ classification applies there.
if [[ "${1:-}" == "--all" ]]; then
  REL_BASE="$REPO_ROOT"

  files=()
  if [[ -d "$REPO_ROOT/scripts" ]]; then
    while IFS= read -r f; do files+=("$f"); done < <(find "$REPO_ROOT/scripts" \( -name "*.sh" -o -name "*.py" \) | sort)
  fi
  if [[ -d "$REPO_ROOT/skills" ]]; then
    while IFS= read -r f; do files+=("$f"); done < <(find "$REPO_ROOT/skills" \( -path "*/scripts/*.sh" -o -path "*/scripts/*.py" \) | sort)
  fi
elif [[ "${1:-}" == "--file" ]]; then
  if [[ -z "${2:-}" ]]; then
    echo "verify-scripts.sh: --file requires a path argument" >&2
    exit 1
  fi
  target="$(cd "$(dirname "$2")" && pwd)/$(basename "$2")"
  if [[ ! -f "$target" ]]; then
    echo "verify-scripts.sh: file not found: $2" >&2
    exit 1
  fi
  case "$target" in
    "$REPO_ROOT"/*) REL_BASE="$REPO_ROOT" ;;
    # Outside the repo there is no repo root to strip. Infer the tree root
    # from a tests/ or scripts/lib/ path segment when present, so a file
    # passed by path still classifies on the same repo-relative prefixes
    # (tests/ first: out of scope trumps the lib tier).
    *"/tests/"*) REL_BASE="${target%%"/tests/"*}" ;;
    *"/scripts/lib/"*) REL_BASE="${target%%"/scripts/lib/"*}" ;;
    *) REL_BASE="$(dirname "$target")" ;;
  esac
  files=("$target")
elif [[ "${1:-}" == -* ]]; then
  echo "verify-scripts.sh: unknown option '${1:-}'" >&2
  echo "Run 'verify-scripts.sh --help' for usage" >&2
  exit 1
elif [[ -d "${1:-.}" ]]; then
  target="$(cd "${1:-.}" && pwd)"
  case "$target" in
    "$REPO_ROOT"/*) REL_BASE="$REPO_ROOT" ;;
    *) REL_BASE="$target" ;;
  esac
  files=()
  while IFS= read -r f; do files+=("$f"); done < <(find "$target" \( -name "*.sh" -o -name "*.py" \) | sort)
else
  echo "verify-scripts.sh: no files to check" >&2
  exit 1
fi

report_skip=""
if [[ "${1:-}" == "--file" ]]; then
  report_skip="report-skip"
fi

echo "=== verify-scripts.sh: checking ${#files[@]} files ==="

for f in "${files[@]}"; do
  check_file "$f" "$report_skip"
done

echo ""
echo "=== Results: $total_files passed, ${#failures[@]} failures ==="

if [[ $skipped_scope -gt 0 ]]; then
  echo "Out of scope (tests/, not checked): $skipped_scope file(s) skipped"
fi

if [[ ${#failures[@]} -gt 0 ]]; then
  for f in "${failures[@]}"; do
    echo "  FAIL: $f"
  done
  exit 1
fi

echo "All checks passed."
exit 0
