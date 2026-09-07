#!/usr/bin/env bash
# verify-script-refs.sh -- Detect unguarded runtime script invocations in skill markdown
#
# Enforces docs/standards/script-extraction-standards.md, section "Script path
# resolution": runtime script invocations in SKILL.md and references/*.md must
# resolve against the plugin installation, never against the current working
# directory (Issue #115).
#
# Usage:
#   verify-script-refs.sh [skills-dir]   # scan a skills tree (default: <repo>/skills)
#   verify-script-refs.sh --help
#
# A violation is a command-position reference to scripts/<name>.sh|py or
# skills/<name>/scripts/<name>.sh|py that is not prefixed on the same token by
# ${CLAUDE_PLUGIN_ROOT}, ${CLAUDE_SKILL_DIR}, or $SCRIPT_DIR. Command position
# means: start of line, or directly after |, ;, &, (, !, or a backtick, or as
# the argv of bash/sh/python/python3, or directly after a shell keyword that
# introduces a command (then, do, else, elif), or directly after a markdown
# list marker. Prose code spans that only mention a script by name (fully
# wrapped in backticks, e.g. "Support Files" bullets) are not invocations and
# pass.
#
# Whitelisted exceptions (explicit):
#   1. --script <path> argument values of run-bundled-validator.sh invocations
#      — the wrapper resolves that argument relative to --skill-dir by contract.
#   2. skills/ts-compound/SKILL.md 'git rev-parse --show-toplevel' lines — the
#      user-repo root for session-history filtering is intentionally not the
#      plugin root.
#   3. source "$SCRIPT_DIR/..." lines — $SCRIPT_DIR is an accepted guard prefix,
#      and skills/*/scripts/*.sh themselves are not scanned at all (this gate
#      only scans SKILL.md and references/*.md).
#
# Exit codes: 0 (all references guarded), 1 (violations or usage error)

set -euo pipefail

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat <<'EOF'
Usage: verify-script-refs.sh [skills-dir]

Detect unguarded runtime script invocations in skill markdown (SKILL.md and
references/*.md). Enforces docs/standards/script-extraction-standards.md,
section "Script path resolution": invocations must be prefixed with
${CLAUDE_PLUGIN_ROOT} (plugin-shared tier), ${CLAUDE_SKILL_DIR} (skill-local
tier), or $SCRIPT_DIR.

Scans: <skills-dir>/*/SKILL.md and <skills-dir>/*/references/**/*.md
       (INDEX.md files are generator-owned listings and are skipped)

Exit codes:
  0 - all runtime references are guarded
  1 - unguarded references found, or usage error
EOF
  exit 0
fi

if [[ "${1:-}" == -* ]]; then
  echo "verify-script-refs.sh: unknown option '${1:-}'" >&2
  echo "Run 'verify-script-refs.sh --help' for usage" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SKILLS_ROOT="${1:-$REPO_ROOT/skills}"

if [[ ! -d "$SKILLS_ROOT" ]]; then
  echo "verify-script-refs.sh: skills directory not found: $SKILLS_ROOT" >&2
  exit 1
fi

# Command-position candidates. The optional skills/<name>/ prefix makes the
# root-relative cross-skill form detectable; grep's leftmost-longest matching
# reports it as one match rather than two.
CANDIDATE_RE='(skills/[a-z0-9][a-z0-9-]*/)?scripts/[A-Za-z0-9_][A-Za-z0-9_./-]*\.(sh|py)([^A-Za-z0-9_.-]|$)'

violations=()

rtrim() {
  # Prints $1 with trailing whitespace removed.
  local s="$1"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

is_token_char() {
  # Path-token characters: the maximal run a shell would treat as one word.
  case "$1" in
    [A-Za-z0-9_./-] | '$' | '{' | '}') return 0 ;;
    *) return 1 ;;
  esac
}

is_command_position() {
  # $1 = line text preceding the reference. Returns 0 when a reference at that
  # spot would be *executed* rather than merely mentioned.
  local prev="$1"
  local prevq rt lastchar lastword
  # Quoted invocations ("scripts/foo.sh") still sit at command position.
  prevq="${prev//\"/}"
  prevq="${prevq//\'/}"
  rt="$(rtrim "$prevq")"
  if [[ -z "$rt" ]]; then
    return 0
  fi
  lastchar="${rt: -1}"
  case "$lastchar" in
    '|' | ';' | '&' | '(' | '!' | '`') return 0 ;;
  esac
  # Markdown list marker directly before the reference ("- scripts/foo.sh").
  local list_marker_re='^[-*+]$|^[0-9]+[.)]$'
  if [[ "$rt" =~ $list_marker_re ]]; then
    return 0
  fi
  # argv of an interpreter: "python3 scripts/foo.py", "xargs -0 python3 ..."
  lastword="${rt##*[[:space:]]}"
  case "$lastword" in
    bash | sh | python | python3) return 0 ;;
  esac
  # Shell keywords that introduce a command on the same line:
  #   "if true; then scripts/foo.sh; fi"
  #   "for x in a; do scripts/bar.sh; done"
  #   "...; else scripts/baz.sh" / "...; elif scripts/qux.sh; then"
  case "$lastword" in
    then | do | else | elif) return 0 ;;
  esac
  return 1
}

classify_occurrence() {
  # $1 file, $2 line number, $3 line, $4 byte offset of the match start.
  local file="$1" lineno="$2" line="$3" off="$4"
  local start=$off end=$off len=${#line} c
  while (( start > 0 )); do
    c="${line:start-1:1}"
    is_token_char "$c" || break
    start=$((start - 1))
  done
  while (( end < len )); do
    c="${line:end:1}"
    is_token_char "$c" || break
    end=$((end + 1))
  done
  local token="${line:start:end-start}"
  local prev="${line:0:start}"

  # Accepted guard prefixes (docs/standards/script-extraction-standards.md):
  # ${CLAUDE_PLUGIN_ROOT}/..., ${CLAUDE_SKILL_DIR}/..., $SCRIPT_DIR/...
  case "$token" in
    '${CLAUDE_PLUGIN_ROOT}/'* | '${CLAUDE_SKILL_DIR}/'* | '$SCRIPT_DIR/'*) return 0 ;;
  esac

  # Whitelist 1: run-bundled-validator.sh --script <path> — the wrapper resolves
  # that argument relative to --skill-dir by contract (established in Issue #109).
  local prevrt
  prevrt="$(rtrim "$prev")"
  case "$prevrt" in
    *--script) return 0 ;;
  esac

  # Prose mentions: a reference fully wrapped in backticks lists a script by
  # name ("Support Files" bullets, inline descriptions) — not an invocation.
  # The !`...` exec form is a real invocation, so it does not get the exemption.
  if (( start >= 1 )) && [[ "${line:start-1:1}" == '`' && "${line:end:1}" == '`' ]]; then
    if (( start >= 2 )) && [[ "${line:start-2:1}" == '!' ]]; then
      : # !`scripts/foo.sh` — runtime exec form, fall through to command-position check
    else
      return 0
    fi
  fi

  if is_command_position "$prev"; then
    violations+=("$file:$lineno: unguarded script reference '$token'")
  fi
  return 0
}

scan_file() {
  local f="$1" line lineno=0 offsets entry
  local lines=()
  mapfile -t lines <"$f" || return 0
  if [[ ${#lines[@]} -eq 0 ]]; then
    return 0
  fi
  for line in "${lines[@]}"; do
    lineno=$((lineno + 1))
    # Whitelist 2: ts-compound derives the *user's* repo root for session-history
    # filtering (plan Inventory D) — intentionally not the plugin root.
    if [[ "$f" == */skills/ts-compound/SKILL.md && "$line" == *"git rev-parse --show-toplevel"* ]]; then
      continue
    fi
    offsets="$(grep -obE "$CANDIDATE_RE" <<<"$line" || true)"
    if [[ -z "$offsets" ]]; then
      continue
    fi
    while IFS= read -r entry; do
      classify_occurrence "$f" "$lineno" "$line" "${entry%%:*}"
    done <<<"$offsets"
  done
}

files=()
while IFS= read -r f; do files+=("$f"); done < <(
  find "$SKILLS_ROOT" -type f -name '*.md' ! -name 'INDEX.md' \( -name 'SKILL.md' -o -path '*/references/*' \) | sort
)

if [[ ${#files[@]} -eq 0 ]]; then
  echo "verify-script-refs.sh: no SKILL.md or references/*.md files found under $SKILLS_ROOT" >&2
  exit 1
fi

echo "=== verify-script-refs.sh: checking ${#files[@]} files ==="

for f in "${files[@]}"; do
  scan_file "$f"
done

echo ""
echo "=== Results: ${#files[@]} files scanned, ${#violations[@]} unguarded reference(s) ==="

if [[ ${#violations[@]} -gt 0 ]]; then
  for v in "${violations[@]}"; do
    echo "  FAIL: ${v#"$REPO_ROOT"/}"
  done
  exit 1
fi

echo "All script references are guarded."
exit 0
