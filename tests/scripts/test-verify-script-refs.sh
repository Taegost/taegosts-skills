#!/usr/bin/env bash
# Test: Verify that verify-script-refs.sh fails on unguarded runtime script
# invocations in skill markdown and passes guarded references, whitelist
# exceptions, and non-execution shapes (denylist design: flag/option argument
# position; assignment-prefixed commands; command-executing utilities).
# Backtick-quoted references are report-only advisories (never exit 1).
set -euo pipefail

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

# --help exits 0 and prints usage (exit status captured, so guard the run)
rc=0
out="$("$SCRIPT" --help 2>&1)" || rc=$?
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

# (b4) addition: same-line shell-keyword command positions fail (then / do)
mkdir -p "$tmpdir/keywords/skills/test-skill"
cat > "$tmpdir/keywords/skills/test-skill/SKILL.md" <<'MD'
```bash
if true; then scripts/foo.sh; fi
for x in a; do scripts/bar.sh; done
```
MD
run_gate "$tmpdir/keywords/skills" "$tmpdir/keywords.out"
violations=$(grep -c 'unguarded script reference' "$tmpdir/keywords.out" || true)
if [[ $rc -eq 1 ]] && [[ "$violations" -eq 2 ]]; then
  ok "then/do same-line invocations flagged"
else
  die "shell-keyword command positions not flagged (rc=$rc, violations=$violations)"
  sed -n '1,20p' "$tmpdir/keywords.out"
fi

# (b5) denylist flip: bare refs after command-executing utilities are flagged
mkdir -p "$tmpdir/executors/skills/test-skill"
cat > "$tmpdir/executors/skills/test-skill/SKILL.md" <<'MD'
```bash
sudo scripts/sudo-runner.sh --check
xargs scripts/xargs-runner.sh
time scripts/time-runner.sh
find . -name '*.md' -exec scripts/findexec-runner.sh \;
nohup scripts/nohup-runner.sh
xargs -0 scripts/xargszero-runner.sh
```
MD
run_gate "$tmpdir/executors/skills" "$tmpdir/executors.out"
violations=$(grep -c 'unguarded script reference' "$tmpdir/executors.out" || true)
if [[ $rc -eq 1 ]] && [[ "$violations" -eq 6 ]]; then
  ok "sudo/xargs/time/find -exec/nohup/xargs -0 bare refs flagged (denylist flip)"
else
  die "command-executing utilities not flagged (rc=$rc, violations=$violations)"
  sed -n '1,20p' "$tmpdir/executors.out"
fi

# (b6) denylist flip: flag/option argument position stays exempt
mkdir -p "$tmpdir/argpos/skills/test-skill"
cat > "$tmpdir/argpos/skills/test-skill/SKILL.md" <<'MD'
```bash
cp -r scripts/copy-source.sh /tmp/dest/
ls -la scripts/listing.sh
[ -f scripts/exists.sh ] && echo found
grep -q scripts/grepped.sh
```
MD
run_gate "$tmpdir/argpos/skills" "$tmpdir/argpos.out"
advisories=$(grep -c 'ADVISORY' "$tmpdir/argpos.out" || true)
if [[ $rc -eq 0 ]] && [[ "$advisories" -eq 0 ]]; then
  ok "flag/option argument position (cp -r, ls -la, [ -f ], grep -q) exempt"
else
  die "argument-position refs flagged (rc=$rc, advisories=$advisories)"
  sed -n '1,20p' "$tmpdir/argpos.out"
fi

# (b7) assignment prefixes are consumed, so the ref lands at command position
mkdir -p "$tmpdir/assign/skills/test-skill"
cat > "$tmpdir/assign/skills/test-skill/SKILL.md" <<'MD'
```bash
MODE=test scripts/env-prefixed.sh
A=1 B=2 scripts/two-assignments.sh
```
MD
run_gate "$tmpdir/assign/skills" "$tmpdir/assign.out"
violations=$(grep -c 'unguarded script reference' "$tmpdir/assign.out" || true)
if [[ $rc -eq 1 ]] && [[ "$violations" -eq 2 ]]; then
  ok "assignment-prefixed invocations (MODE=test, A=1 B=2) flagged"
else
  die "assignment-prefixed invocations not flagged (rc=$rc, violations=$violations)"
  sed -n '1,20p' "$tmpdir/assign.out"
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

# (c3) addition: guarded references after shell keywords (then/do/else/elif) pass
mkdir -p "$tmpdir/kwguarded/skills/test-skill"
cat > "$tmpdir/kwguarded/skills/test-skill/SKILL.md" <<'MD'
```bash
if true; then "${CLAUDE_PLUGIN_ROOT}/scripts/foo.sh"; fi
for x in a; do "${CLAUDE_SKILL_DIR}/scripts/bar.sh"; done
if [ -f x ]; then "$SCRIPT_DIR/scripts/baz.sh"; else "$SCRIPT_DIR/scripts/qux.sh"; fi
if false; then :; elif true; then "${CLAUDE_PLUGIN_ROOT}/scripts/elif.sh"; fi
```
MD
run_gate "$tmpdir/kwguarded/skills" "$tmpdir/kwguarded.out"
if [[ $rc -eq 0 ]]; then
  ok "guarded references after shell keywords pass"
else
  die "guarded references after keywords flagged (rc=$rc)"
  sed -n '1,20p' "$tmpdir/kwguarded.out"
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

# (d2) non-wrapper --script argument is classified normally (flagged); the
# run-bundled-validator.sh wrapper exception still applies
mkdir -p "$tmpdir/nonwrapper/skills/test-skill"
cat > "$tmpdir/nonwrapper/skills/test-skill/SKILL.md" <<'MD'
```bash
some-runner --script scripts/not-wrapper.sh
"${CLAUDE_PLUGIN_ROOT}/scripts/run-bundled-validator.sh" --skill-dir "${CLAUDE_SKILL_DIR}" --script scripts/wrapper-arg.py
```
MD
run_gate "$tmpdir/nonwrapper/skills" "$tmpdir/nonwrapper.out"
violations=$(grep -c 'unguarded script reference' "$tmpdir/nonwrapper.out" || true)
if [[ $rc -eq 1 ]] && [[ "$violations" -eq 1 ]] && grep -q 'scripts/not-wrapper\.sh' "$tmpdir/nonwrapper.out"; then
  ok "non-wrapper --script argument flagged; wrapper --script exception intact"
else
  die "--script classification wrong (rc=$rc, violations=$violations)"
  sed -n '1,20p' "$tmpdir/nonwrapper.out"
fi

# (d3) the wrapper exception cannot cross a command separator: a second,
# non-wrapper --script reference after ;|& must be flagged
mkdir -p "$tmpdir/separator/skills/test-skill"
cat > "$tmpdir/separator/skills/test-skill/SKILL.md" <<'MD'
```bash
run-bundled-validator.sh --skill-dir "${CLAUDE_SKILL_DIR}" --script scripts/validate-frontmatter.py; some-runner --script scripts/after-separator.sh
```
MD
run_gate "$tmpdir/separator/skills" "$tmpdir/separator.out"
violations=$(grep -c 'unguarded script reference' "$tmpdir/separator.out" || true)
if [[ $rc -eq 1 ]] && [[ "$violations" -eq 1 ]] && grep -q 'scripts/after-separator\.sh' "$tmpdir/separator.out"; then
  ok "wrapper --script exception does not cross command separators"
else
  die "separator-crossing --script not flagged (rc=$rc, violations=$violations)"
  sed -n '1,20p' "$tmpdir/separator.out"
fi

# (e) prose mention of a script name in a bullet is an advisory, not a
# violation: exit stays 0, the advisory names file:line and the token
mkdir -p "$tmpdir/prose/skills/test-skill"
cat > "$tmpdir/prose/skills/test-skill/SKILL.md" <<'MD'
## Support Files

- `scripts/validate-frontmatter.py` — frontmatter parser-safety validator
- `scripts/validate-doc-claims.py` — mechanical claims checker

The bundled `scripts/validate-frontmatter.py` flags malformed delimiters.
MD
run_gate "$tmpdir/prose/skills" "$tmpdir/prose.out"
advisories=$(grep -c 'ADVISORY' "$tmpdir/prose.out" || true)
violations=$(grep -c 'unguarded script reference' "$tmpdir/prose.out" || true)
if [[ $rc -eq 0 ]] && [[ "$advisories" -eq 3 ]] && [[ "$violations" -eq 0 ]] \
   && grep -q 'test-skill/SKILL\.md:3.*backtick-quoted script reference .scripts/validate-frontmatter\.py.' "$tmpdir/prose.out"; then
  ok "prose bullet mentions reported as advisories (exit 0, file:line + token)"
else
  die "prose mention advisory wrong (rc=$rc, advisories=$advisories, violations=$violations)"
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

# (g1) backtick-quoted reference is reported as an advisory with file:line +
# token, and the exit code stays 0
mkdir -p "$tmpdir/advisory/skills/test-skill"
cat > "$tmpdir/advisory/skills/test-skill/SKILL.md" <<'MD'
## Support Files

- `scripts/validate-frontmatter.py` — frontmatter parser-safety validator
MD
run_gate "$tmpdir/advisory/skills" "$tmpdir/advisory.out"
violations=$(grep -c 'unguarded script reference' "$tmpdir/advisory.out" || true)
if [[ $rc -eq 0 ]] && [[ "$violations" -eq 0 ]] \
   && grep -q 'test-skill/SKILL\.md:3.*backtick-quoted script reference .scripts/validate-frontmatter\.py.' "$tmpdir/advisory.out"; then
  ok "backtick-quoted reference reported as advisory (exit 0, SKILL.md:3 + token)"
else
  die "backtick advisory missing or exit wrong (rc=$rc, violations=$violations)"
  sed -n '1,20p' "$tmpdir/advisory.out"
fi

# (g2) the !`...` exec form stays on the violation path (not an advisory)
mkdir -p "$tmpdir/exeform/skills/test-skill"
cat > "$tmpdir/exeform/skills/test-skill/SKILL.md" <<'MD'
```bash
!`scripts/exeform.sh`
```
MD
run_gate "$tmpdir/exeform/skills" "$tmpdir/exeform.out"
advisories=$(grep -c 'ADVISORY' "$tmpdir/exeform.out" || true)
if [[ $rc -eq 1 ]] && [[ "$advisories" -eq 0 ]] && grep -q 'scripts/exeform\.sh' "$tmpdir/exeform.out"; then
  ok "!<backtick> exec form still a violation, not an advisory"
else
  die "!<backtick> exec form misclassified (rc=$rc, advisories=$advisories)"
  sed -n '1,20p' "$tmpdir/exeform.out"
fi

# (g3) an advisory does not mask a real violation in the same file
mkdir -p "$tmpdir/mixed/skills/test-skill"
cat > "$tmpdir/mixed/skills/test-skill/SKILL.md" <<'MD'
```bash
scripts/real-violation.sh
```

- `scripts/mention-only.py` — support file
MD
run_gate "$tmpdir/mixed/skills" "$tmpdir/mixed.out"
violations=$(grep -c 'unguarded script reference' "$tmpdir/mixed.out" || true)
advisories=$(grep -c 'ADVISORY' "$tmpdir/mixed.out" || true)
if [[ $rc -eq 1 ]] && [[ "$violations" -eq 1 ]] && [[ "$advisories" -eq 1 ]]; then
  ok "violation and advisory counted independently (rc 1, 1 violation, 1 advisory)"
else
  die "mixed file classification wrong (rc=$rc, violations=$violations, advisories=$advisories)"
  sed -n '1,20p' "$tmpdir/mixed.out"
fi

# unknown flag errors (expected failure: guard so set -e does not abort)
rc=0
out="$("$SCRIPT" --bogus 2>&1)" || rc=$?
if [[ $rc -eq 1 ]]; then
  ok "unknown option errors (exit 1)"
else
  die "unknown option rc=$rc (expected 1)"
fi

# missing skills dir errors (expected failure: guard so set -e does not abort)
rc=0
out="$("$SCRIPT" "$tmpdir/does-not-exist" 2>&1)" || rc=$?
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
