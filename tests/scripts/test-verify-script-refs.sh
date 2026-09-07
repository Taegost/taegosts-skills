#!/usr/bin/env bash
# Test: Verify that verify-script-refs.sh fails on unguarded runtime script
# invocations in skill markdown and passes guarded references, whitelist
# exceptions, and prose mentions.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/verify-script-refs.sh"

pass=0
fail=0
ok() { pass=$((pass + 1)); echo "  PASS: $1"; }
die() { fail=$((fail + 1)); echo "  FAIL: $1"; }

tmpdir=$(mktemp -d)
cleanup() { rm -rf "$tmpdir"; }
trap cleanup EXIT

echo "=== test-verify-script-refs.sh ==="

# run_gate <skills-root> <outfile> — runs the gate, sets global rc
run_gate() {
  rc=0
  "$SCRIPT" "$1" >"$2" 2>&1 || rc=$?
}

# --help exits 0 and prints usage
out="$("$SCRIPT" --help 2>&1)"
rc=$?
if [[ $rc -eq 0 ]] && echo "$out" | grep -q "Usage:"; then
  ok "--help prints usage and exits 0"
else
  die "--help (rc=$rc)"
fi

# (a) repo's real skills/ tree passes
run_gate "$REPO_ROOT/skills" "$tmpdir/real.out"
if [[ $rc -eq 0 ]]; then
  ok "real skills/ tree passes (exit 0)"
else
  die "real skills/ tree fails (rc=$rc)"
  sed -n '1,30p' "$tmpdir/real.out"
fi

# (b) fixture SKILL.md with a bare scripts/foo.sh invocation fails and names file:line
mkdir -p "$tmpdir/bare/skills/test-skill"
cat > "$tmpdir/bare/skills/test-skill/SKILL.md" <<'MD'
## Run

```bash
scripts/foo.sh --flag value
```
MD
run_gate "$tmpdir/bare/skills" "$tmpdir/bare.out"
if [[ $rc -eq 1 ]] && grep -q 'SKILL\.md:4' "$tmpdir/bare.out"; then
  ok "bare scripts/foo.sh invocation fails (exit 1) naming file:line"
else
  die "bare scripts/foo.sh invocation not caught (rc=$rc)"
  sed -n '1,20p' "$tmpdir/bare.out"
fi

# (b2) addition: other command-position shapes fail (pipe, interpreter argv, $( ))
mkdir -p "$tmpdir/shapes/skills/test-skill"
cat > "$tmpdir/shapes/skills/test-skill/SKILL.md" <<'MD'
```bash
ctx | scripts/pipe.sh
python3 scripts/tool.py --x
value=$(scripts/sub.sh)
```
MD
run_gate "$tmpdir/shapes/skills" "$tmpdir/shapes.out"
violations=$(grep -c 'unguarded script reference' "$tmpdir/shapes.out" || true)
if [[ $rc -eq 1 ]] && [[ "$violations" -eq 3 ]]; then
  ok "pipe, argv-of-python3, and \$( ) shapes all flagged"
else
  die "command-position shapes not fully flagged (rc=$rc, violations=$violations)"
  sed -n '1,20p' "$tmpdir/shapes.out"
fi

# (b3) addition: bare root-relative cross-skill reference fails
mkdir -p "$tmpdir/xskill/skills/test-skill"
cat > "$tmpdir/xskill/skills/test-skill/SKILL.md" <<'MD'
```bash
skills/other/scripts/tool.sh --r
```
MD
run_gate "$tmpdir/xskill/skills" "$tmpdir/xskill.out"
if [[ $rc -eq 1 ]] && grep -q 'skills/other/scripts/tool.sh' "$tmpdir/xskill.out"; then
  ok "bare cross-skill skills/<name>/scripts/... reference fails"
else
  die "bare cross-skill reference not caught (rc=$rc)"
  sed -n '1,20p' "$tmpdir/xskill.out"
fi

# (c) fixture with ${CLAUDE_PLUGIN_ROOT} and ${CLAUDE_SKILL_DIR} prefixes passes
mkdir -p "$tmpdir/guarded/skills/test-skill"
cat > "$tmpdir/guarded/skills/test-skill/SKILL.md" <<'MD'
```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/foo.sh" --flag
python3 "${CLAUDE_SKILL_DIR}/scripts/bar.py"
"${CLAUDE_PLUGIN_ROOT}/skills/other/scripts/qux.sh" --r
```
MD
run_gate "$tmpdir/guarded/skills" "$tmpdir/guarded.out"
if [[ $rc -eq 0 ]]; then
  ok "CLAUDE_PLUGIN_ROOT / CLAUDE_SKILL_DIR prefixed references pass"
else
  die "guarded references flagged (rc=$rc)"
  sed -n '1,20p' "$tmpdir/guarded.out"
fi

# (c2) addition: $SCRIPT_DIR prefix passes (script-to-script guard form)
mkdir -p "$tmpdir/scriptdir/skills/test-skill"
cat > "$tmpdir/scriptdir/skills/test-skill/SKILL.md" <<'MD'
```bash
source "$SCRIPT_DIR/../../../scripts/lib/input-validation.sh"
"$SCRIPT_DIR/scripts/helper.sh" arg
```
MD
run_gate "$tmpdir/scriptdir/skills" "$tmpdir/scriptdir.out"
if [[ $rc -eq 0 ]]; then
  ok "\$SCRIPT_DIR-prefixed references pass"
else
  die "\$SCRIPT_DIR references flagged (rc=$rc)"
  sed -n '1,20p' "$tmpdir/scriptdir.out"
fi

# (d) --script scripts/validate-*.py wrapper-arg exception passes
mkdir -p "$tmpdir/wrapper/skills/test-skill"
cat > "$tmpdir/wrapper/skills/test-skill/SKILL.md" <<'MD'
```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/run-bundled-validator.sh" --skill-dir "${CLAUDE_SKILL_DIR}" --script scripts/validate-frontmatter.py -- <output-path>
"${CLAUDE_PLUGIN_ROOT}/scripts/run-bundled-validator.sh" --skill-dir "${CLAUDE_SKILL_DIR}" --script scripts/validate-doc-claims.py -- <successor-doc>
```
MD
run_gate "$tmpdir/wrapper/skills" "$tmpdir/wrapper.out"
if [[ $rc -eq 0 ]]; then
  ok "--script wrapper-arg exception passes"
else
  die "--script wrapper-arg exception flagged (rc=$rc)"
  sed -n '1,20p' "$tmpdir/wrapper.out"
fi

# (e) prose mention of a script name in a bullet (non-invocation shape) passes
mkdir -p "$tmpdir/prose/skills/test-skill"
cat > "$tmpdir/prose/skills/test-skill/SKILL.md" <<'MD'
## Support Files

- `scripts/validate-frontmatter.py` — frontmatter parser-safety validator
- `scripts/validate-doc-claims.py` — mechanical claims checker

The bundled `scripts/validate-frontmatter.py` flags malformed delimiters.
MD
run_gate "$tmpdir/prose/skills" "$tmpdir/prose.out"
if [[ $rc -eq 0 ]]; then
  ok "prose mention in a bullet passes"
else
  die "prose mention flagged (rc=$rc)"
  sed -n '1,20p' "$tmpdir/prose.out"
fi

# (e2) addition: existence-test argument is not command position
mkdir -p "$tmpdir/exists/skills/test-skill"
cat > "$tmpdir/exists/skills/test-skill/SKILL.md" <<'MD'
```bash
if [ -f "$candidate/scripts/context-gather.sh" ]; then PLUGIN_ROOT="$candidate"; break; fi
```
MD
run_gate "$tmpdir/exists/skills" "$tmpdir/exists.out"
if [[ $rc -eq 0 ]]; then
  ok "existence-test argument ([ -f ... ]) passes"
else
  die "existence-test argument flagged (rc=$rc)"
  sed -n '1,20p' "$tmpdir/exists.out"
fi

# (e3) addition: INDEX.md files are skipped (generator-owned listings)
mkdir -p "$tmpdir/idx/skills/test-skill/references"
cat > "$tmpdir/idx/skills/test-skill/SKILL.md" <<'MD'
```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/foo.sh"
```
MD
cat > "$tmpdir/idx/skills/test-skill/references/INDEX.md" <<'MD'
- scripts/bare-listing.sh — would be a violation if scanned
MD
run_gate "$tmpdir/idx/skills" "$tmpdir/idx.out"
if [[ $rc -eq 0 ]]; then
  ok "INDEX.md listings are skipped"
else
  die "INDEX.md flagged (rc=$rc)"
  sed -n '1,20p' "$tmpdir/idx.out"
fi

# (f) addition: ts-compound rev-parse whitelist (user-repo root, not plugin root)
mkdir -p "$tmpdir/tscompound/skills/ts-compound"
cat > "$tmpdir/tscompound/skills/ts-compound/SKILL.md" <<'MD'
```bash
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
```
MD
run_gate "$tmpdir/tscompound/skills" "$tmpdir/tscompound.out"
if [[ $rc -eq 0 ]]; then
  ok "ts-compound git rev-parse --show-toplevel whitelist passes"
else
  die "ts-compound rev-parse whitelist flagged (rc=$rc)"
  sed -n '1,20p' "$tmpdir/tscompound.out"
fi

# unknown flag errors
out="$("$SCRIPT" --bogus 2>&1)"
rc=$?
if [[ $rc -eq 1 ]]; then
  ok "unknown option errors (exit 1)"
else
  die "unknown option rc=$rc (expected 1)"
fi

# missing skills dir errors
out="$("$SCRIPT" "$tmpdir/does-not-exist" 2>&1)"
rc=$?
if [[ $rc -eq 1 ]]; then
  ok "missing skills dir errors (exit 1)"
else
  die "missing skills dir rc=$rc (expected 1)"
fi

echo ""
echo "Results: $pass passed, $fail failed"
if [[ $fail -eq 0 ]]; then
  exit 0
else
  exit 1
fi
