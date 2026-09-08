#!/usr/bin/env bash
# run-bundled-validator.sh -- Resolve and run a skill's bundled validator script, or report it unavailable
#
# Usage: run-bundled-validator.sh --skill-dir <path> --script <relative-path> [-- <args>]
#
# Solves the CWD mismatch documented across ts-compound and ts-compound-refresh:
# a bundled validator (e.g. scripts/validate-frontmatter.py) ships inside a
# skill's own directory, but the runtime Bash tool's CWD is the user's
# project, so a bare relative path misses the bundled copy. On Claude Code,
# $CLAUDE_SKILL_DIR resolves to the loaded skill's directory; on platforms
# where it is unset (e.g. native Codex/Gemini installs), pass --skill-dir
# with the absolute path of the directory containing the SKILL.md you just
# read.
#
# Exit codes:
#   Whatever the validator exits with, when it runs.
#   2 - skill directory or script could not be resolved on this platform
#   3 - usage error (missing required arguments)
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: run-bundled-validator.sh --skill-dir <path> --script <relative-path> [-- <args>]

Arguments:
  --skill-dir <path>   Absolute path of the skill directory. Falls back to
                        $CLAUDE_SKILL_DIR when this flag is omitted.
  --script <path>      Validator script path relative to the skill directory
                        (e.g. scripts/validate-frontmatter.py).
  -- <args>             Arguments passed through to the validator script.

If neither --skill-dir nor $CLAUDE_SKILL_DIR resolves to a directory
containing the named script, prints a one-line notice to stderr and exits 2
so the caller can fall back to a manual check instead of silently skipping
validation.

Exit codes:
  <validator's own exit code> - the validator ran
  2 - skill directory or script could not be resolved on this platform
  3 - usage error (missing required arguments)

Examples:
  run-bundled-validator.sh --skill-dir "$CLAUDE_SKILL_DIR" --script scripts/validate-frontmatter.py -- docs/solutions/foo.md
  run-bundled-validator.sh --script scripts/validate-doc-claims.py -- docs/solutions/foo.md
EOF
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

skill_dir="${CLAUDE_SKILL_DIR:-}"
script_path=""
args=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skill-dir)
      [[ $# -ge 2 ]] || { echo "run-bundled-validator: --skill-dir requires a value" >&2; exit 3; }
      skill_dir="$2"; shift 2 ;;
    --script)
      [[ $# -ge 2 ]] || { echo "run-bundled-validator: --script requires a value" >&2; exit 3; }
      script_path="$2"; shift 2 ;;
    --)
      shift
      args=("$@")
      break ;;
    *)
      echo "run-bundled-validator: unknown argument: $1" >&2
      exit 3 ;;
  esac
done

if [[ -z "$script_path" ]]; then
  echo "run-bundled-validator: --script is required" >&2
  exit 3
fi

if [[ -n "$skill_dir" && -f "$skill_dir/$script_path" ]]; then
  exec python3 "$skill_dir/$script_path" "${args[@]}"
fi

echo "run-bundled-validator: bundled $script_path not resolvable on this platform (checked skill-dir: ${skill_dir:-<unset>}); apply the manual checklist instead." >&2
exit 2
