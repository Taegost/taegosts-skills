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
# ${CLAUDE_PLUGIN_ROOT}, ${CLAUDE_SKILL_DIR}, or $SCRIPT_DIR.
#
# Command position is decided denylist-style: every word preceding a
# reference defaults to command position (execution), and only known
# non-execution shapes are exempt. Leading shell assignment words are
# consumed first, so "MODE=test scripts/foo.sh" and "A=1 B=2 scripts/foo.sh"
# resolve to the effective command word (empty at line start = command
# position). The single exempt shape: a word directly before the reference
# that starts with '-' puts the reference in argument position ("cp -r
# scripts/foo.sh dst", "[ -f scripts/foo.sh ]"), with three carve-outs that
# stay command position because they introduce execution:
#   - find's exec family (-exec, -execdir, -ok, -okdir);
#   - a bare --script or -script, whose value is a script to run (see
#     whitelist 1);
#   - a flag run directly after a command-executing utility ("xargs -0
#     scripts/foo.sh") — the flag words are skipped and the utility is
#     inspected against EXECUTOR_WORDS (bash/sh/python/python3, sudo, xargs,
#     time, nohup, env, nice, timeout, watch, strace, stdbuf, setsid, find).
# Consequently line start, |, ;, &, (, !, a backtick, markdown list markers,
# interpreter argv ("python3 scripts/foo.py"), shell keywords (then/do/else/
# elif), and executors ("sudo scripts/foo.sh", "nohup scripts/foo.sh") all
# default to command position.
#
# Backtick-quoted references ("Support Files" bullets, inline prose spans)
# cannot be classified by string matching: the same shape covers a
# mention-only listing and an imperative "Run `scripts/foo.sh`". Each one is
# collected into an advisory list reported at the end; advisories never
# affect the exit code, and the model reading the gate output judges every
# advisory line (mention-only vs invocation). The !`...` exec form is a real
# invocation and stays on the violation path.
#
# Whitelisted exceptions (explicit):
#   1. --script <path> argument values of run-bundled-validator.sh
#      invocations — the wrapper resolves that argument relative to
#      --skill-dir by contract (established in Issue #109), and the wrapper
#      accepts only the double-dash form. Restricted to actual wrapper
#      invocations: the wrapper name must appear earlier in the same command,
#      with only separator-free words between it and --script. Any other
#      tool's --script argument is classified normally.
#   2. skills/ts-compound/SKILL.md 'git rev-parse --show-toplevel' lines — the
#      user-repo root for session-history filtering is intentionally not the
#      plugin root.
#   3. source "$SCRIPT_DIR/..." lines — $SCRIPT_DIR is an accepted guard prefix,
#      and skills/*/scripts/*.sh themselves are not scanned at all (this gate
#      only scans SKILL.md and references/*.md).
#
# Exit codes: 0 (all references guarded; advisories may still be reported),
#             1 (violations or usage error)

set -euo pipefail

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat <<'EOF'
Usage: verify-script-refs.sh [skills-dir]

Detect unguarded runtime script invocations in skill markdown (SKILL.md and
references/*.md). Enforces docs/standards/script-extraction-standards.md,
section "Script path resolution": invocations must be prefixed with
${CLAUDE_PLUGIN_ROOT} (plugin-shared tier), ${CLAUDE_SKILL_DIR} (skill-local
tier), or $SCRIPT_DIR.

Command position is denylist-based: a reference is flagged unless the word
before it is a known non-execution shape (flag/option argument position).
Backtick-quoted references (prose code spans, "Support Files" bullets) are
reported as advisories and do not affect the exit code — the reading model
judges each advisory line.

Scans: <skills-dir>/*/SKILL.md and <skills-dir>/*/references/**/*.md
       (INDEX.md files are generator-owned listings and are skipped)

Exit codes:
  0 - all runtime references are guarded (advisories may still be reported)
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
advisories=()

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

consume_trailing_assignments() {
  # Prints $1 with any run of trailing shell assignment words removed
  # ("MODE=test " -> "", "A=1 B=2 " -> ""). A command line may carry
  # assignments before its argv ("MODE=test scripts/foo.sh"), so the word
  # directly before a reference is not necessarily the effective command
  # word: assignment prefixes are consumed so assignment-led invocations
  # ("MODE=test scripts/foo.sh") classify as command position.
  local s="$1" last
  while [[ -n "$s" ]]; do
    last="${s##*[[:space:]]}"
    [[ "$last" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]] || break
    s="$(rtrim "${s%"$last"}")"
  done
  printf '%s' "$s"
}

# Utilities that execute the word an option run precedes ("xargs -0",
# "bash -c"): when flags sit between such a utility and a reference, the
# flags are skipped and the utility inspected (see is_command_position).
EXECUTOR_WORDS='bash sh python python3 sudo xargs time nohup env nice timeout watch strace stdbuf setsid find'

is_command_position() {
  # $1 = line text preceding the reference. Returns 0 when a reference at that
  # spot would be *executed* rather than merely mentioned.
  #
  # Denylist design: every preceding word defaults to command position;
  # only the flag/option argument-position shape below is exempt.
  local prev="$1"
  local prevq rt lastchar lastword stripped w
  # Quoted invocations ("scripts/foo.sh") still sit at command position.
  prevq="${prev//\"/}"
  prevq="${prevq//\'/}"
  # Assignment prefixes carry execution to what follows ("MODE=test ...").
  rt="$(consume_trailing_assignments "$(rtrim "$prevq")")"
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
  lastword="${rt##*[[:space:]]}"
  # Exempt shape: a flag/option word makes the reference its argument, not a
  # command ("cp -r scripts/foo.sh dst", "[ -f scripts/foo.sh ]"). Carve-outs
  # that stay command position because they introduce execution:
  #   - find's exec family and a bare --script take a script/command argument;
  #   - a flag run directly after a command-executing utility ("xargs -0")
  #     still ends in execution — skip the flag words, inspect the utility.
  case "$lastword" in
    -exec | -execdir | -ok | -okdir | --script | -script) return 0 ;;
    -*)
      stripped="$rt"
      while :; do
        w="${stripped##*[[:space:]]}"
        case "$w" in
          -*) stripped="$(rtrim "${stripped%"$w"}")" ;;
          *) break ;;
        esac
      done
      if [[ -n "$stripped" ]]; then
        w="${stripped##*[[:space:]]}"
        case " $EXECUTOR_WORDS " in
          *" $w "*) return 0 ;;
        esac
      fi
      return 1 ;;
  esac
  # Everything else defaults to command position: interpreter argv
  # ("python3 scripts/foo.py"), executors ("sudo", "xargs", "time", "nohup",
  # ...), and command-introducing keywords ("then", "do", "else", "elif").
  return 0
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

  # Backtick-quoted references (prose code spans, "Support Files" bullets)
  # cannot be classified by string matching: the same shape covers a
  # mention-only listing and an imperative "Run `scripts/foo.sh`". By design
  # (no verb heuristics) the gate collects them as advisories for the
  # reading model to judge; advisories do not affect the exit code. The
  # !`...` exec form is a real invocation and stays on the violation path.
  if (( start >= 1 )) && [[ "${line:start-1:1}" == '`' && "${line:end:1}" == '`' ]]; then
    if (( start >= 2 )) && [[ "${line:start-2:1}" == '!' ]]; then
      : # !`scripts/foo.sh` — runtime exec form, fall through to command-position check
    else
      advisories+=("$file:$lineno: backtick-quoted script reference '$token' — judge whether mention-only or invocation")
      return 0
    fi
  fi

  # Whitelist 1: run-bundled-validator.sh --script <path> — the wrapper resolves
  # that argument relative to --skill-dir by contract (established in Issue
  # #109). Restricted to invocations where the wrapper is the invoked command:
  # its name must start the command or follow a path separator (the quoted
  # "${CLAUDE_PLUGIN_ROOT}/scripts/..." form), with only words between it and
  # --script. Argument-position mentions (the wrapper passed to another tool,
  # e.g. "some-runner run-bundled-validator.sh ...") do not whitelist — any
  # other tool's --script argument is classified normally.
  local prevrt wrapper_re
  prevrt="${prev//\"/}"
  prevrt="${prevrt//\'/}"
  prevrt="$(rtrim "$prevrt")"
  wrapper_re='(^|/)run-bundled-validator\.sh([[:space:]]+[^[:space:];|&]+)*[[:space:]]+--script$'
  if [[ "$prevrt" =~ $wrapper_re ]]; then
    return 0
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
echo "=== Results: ${#files[@]} files scanned, ${#violations[@]} unguarded reference(s), ${#advisories[@]} advisory mention(s) ==="

if [[ ${#violations[@]} -gt 0 ]]; then
  for v in "${violations[@]}"; do
    echo "  FAIL: ${v#"$REPO_ROOT"/}"
  done
fi

# Advisories are report-only: the reading model judges each line.
# They never affect the exit code.
if [[ ${#advisories[@]} -gt 0 ]]; then
  echo ""
  echo "=== Advisories: ${#advisories[@]} backtick-quoted script reference(s) — advisories do not affect the exit code ==="
  for a in "${advisories[@]}"; do
    echo "  ADVISORY: ${a#"$REPO_ROOT"/}"
  done
fi

if [[ ${#violations[@]} -gt 0 ]]; then
  exit 1
fi

echo "All script references are guarded."
exit 0
