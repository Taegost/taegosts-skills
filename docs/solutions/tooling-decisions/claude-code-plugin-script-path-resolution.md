---
title: "Claude Code plugin script path resolution"
date: 2026-09-07
category: docs/solutions/tooling-decisions
module: claude-code-plugins
problem_type: tooling_decision
component: tooling
severity: medium
symptoms:
  - Marketplace-installed plugin skills report shared or skill-local scripts as not found (Issue #115)
  - The same script invocation succeeds from the repository checkout but fails at skill-execution time from the plugin cache
root_cause: wrong_api
resolution_type: code_fix
applies_when:
  - Marketplace-installed skills report shared or skill-local scripts as "not found"
  - Writing or reviewing skill content that invokes scripts bundled with the plugin
  - Adding a new skill or script that will be invoked from skill markdown
  - Supporting platforms other than Claude Code that consume the same skill files
tags:
  - claude-code
  - plugin-structure
  - marketplace
  - skills
  - script-resolution
  - claude-plugin-root
  - claude-skill-dir
  - regression-gate
---

# Claude Code Plugin Script Path Resolution

## Context

Issue #115 reported that "skills installed as a plugin from the marketplace aren't finding the common scripts." The intuitive diagnosis — the scripts are not shipped — is wrong, and following it wastes time on repackaging and reinstalling.

Marketplace installs copy the entire plugin root (the repo root; `.claude-plugin/marketplace.json` declares `source: "./"`) into `~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/`. This was verified directly: the cache copy's `scripts/` directory contains every shared script, and the cache directory name matched the current `origin/main` HEAD at the time of diagnosis. Distribution was never broken.

The actual root cause is path resolution. Skill bodies invoked scripts with bare CWD-relative paths (`scripts/context-gather.sh`), and at skill-execution time the Bash tool's CWD is the **user's project**, not the cache directory. A bare `scripts/context-gather.sh` therefore resolves to `<user-project>/scripts/context-gather.sh`, which does not exist.

A prior research effort never reached a conclusion at all. `docs/plans/2026-06-22-003-research-plugin-cache-behavior-plan.md` never posed the cache-path question — whether the repo's relative path conventions still hold when skills execute outside the repo — so it went unasked and unanswered. Its evidence stopped at cache **layout** (where the files land) without reaching execution-time **CWD** (where commands actually run), so CWD-relative references kept shipping in the meantime. The plan now carries a dated Correction section that preserves the original text and states the correct mechanism — the documentation gap it left open is what allowed Issue #115 to surface months later.

The repository already contained a partial version of the fix, which is what made the correct diagnosis visible: `skills/ts-compound/SKILL.md`'s session-history blocks used `${CLAUDE_SKILL_DIR}` guards, and `scripts/run-bundled-validator.sh` (added during the Issue #109 work) existed precisely to bridge this CWD mismatch for skill-local validators. Neither covered the shared `scripts/` tier or most skill-local scripts, which were still invoked bare.

## Guidance

Reference bundled scripts through the official Claude Code string substitutions, resolved at skill-load time and independent of CWD. The canonical rule lives in `docs/standards/script-extraction-standards.md` ("Script path resolution") — conventions belong in `docs/standards/`, never in `CLAUDE.md`.

### Resolution tiers

- **Plugin-shared tier** (the repo-root `scripts/` directory): `${CLAUDE_PLUGIN_ROOT}/scripts/<script>`
- **Cross-skill references** (another skill's scripts): `${CLAUDE_PLUGIN_ROOT}/skills/<skill-name>/scripts/<script>`
- **Skill-local tier** (the loaded skill's own `scripts/` directory): `${CLAUDE_SKILL_DIR}/scripts/<script>`

`${CLAUDE_PLUGIN_ROOT}` and `${CLAUDE_SKILL_DIR}` are Claude Code string substitutions performed when the skill is loaded, so the resulting paths are correct regardless of the working directory the Bash tool happens to have at execution time.

### Guarded fallback for other platforms

On platforms where the variables arrive unset — for example the Hermes sync consuming these files outside Claude Code (`scripts/sync-taegosts-skills.sh`) — use a guarded fallback: resolve the script from the loaded skill directory (`<skill-dir>/../../scripts/`) or from a taegosts-skills checkout, and if it is still unresolvable, say so visibly and use the documented manual fallback. Never silently skip. This extends the pattern `run-bundled-validator.sh` already established (exit 2 with a stderr notice, so the caller can fall back to a manual check).

### Intentional exceptions

Three exception classes are deliberate, not oversights:

- **Script-to-script references inside the scripts themselves** keep `$SCRIPT_DIR`-relative paths: a script resolving its own dependencies from its own location is correct in every layout, including the cache.
- **ts-compound's `git rev-parse --show-toplevel` lines** resolve the **user's** repo root on purpose — that value filters session history in the user's repository, not in the plugin.
- **`--script <path>` argument values of `run-bundled-validator.sh` invocations** stay bare: the wrapper resolves that argument relative to `--skill-dir` by contract.

### The ts-coding-workflow Phase 0 bootstrap

One case needed more than a prefix swap. Phase 0 of `skills/ts-coding-workflow/SKILL.md` previously did `REPO_ROOT="$(git rev-parse --show-toplevel)"` and prepended `$REPO_ROOT/scripts` to PATH — under a marketplace install that resolves to the user's project, not the plugin. It now resolves a `PLUGIN_ROOT` from `${CLAUDE_PLUGIN_ROOT}`, falls back to a checkout-candidate loop, and prepends both `$PLUGIN_ROOT/scripts` and every `$PLUGIN_ROOT/skills/*/scripts` directory to PATH so the bare-name invocations later in the file keep working (with a visible notice when nothing resolves).

### Rollout and verification

The rewrite covered four inventories from the fix plan (`docs/plans/2026-09-07-001-fix-plugin-script-resolution-plan.md`): bare shared-tier refs (Inventory A), root-relative skill-local and cross-skill refs including INDEX-pointer prose (Inventory B), `../../scripts/` escapes in the ts-commit/ts-commit-push-pr fallback sections — which in the cache layout resolve to `~/.claude/plugins/scripts/`, outside the plugin root entirely (Inventory C) — and the PATH bootstrap (Inventory D). Fifteen skill files changed in commit `d27ebc4`, plus the exec bit on `run-bundled-validator.sh` that the now-direct invocations require.

Verification ran as a two-cycle `ts-do-work-loop` with four parallel verifiers. Round 1 surfaced four minors — a gate keyword blind spot, an unquoted `${CLAUDE_PLUGIN_ROOT}` expansion, an `owner:` frontmatter clobber by index regeneration, and a missing validator test for the generated-note case — all remediated in commit `910cc74`; the re-verify pass came back clean. The cache simulation from the plan (run a previously-bare invocation from an unrelated CWD with `CLAUDE_PLUGIN_ROOT` pointed at the real cache dir; then unset the variable and confirm the visible guard message) is the manual end-to-end check worth repeating after future path changes.

## Why This Matters

The fix targets the correct layer. Distribution was never broken — the cache contains every script — so repackaging or reinstalling the plugin could not have helped. Only resolving references against the installation directory (instead of the caller's CWD) makes invocations work both from the checkout and from a marketplace install.

The guard requirement matters as much as the substitution itself. A script reference that fails silently — a step quietly skipped when the variable is unset — degrades the skill's behavior without any signal, which is worse than a visible error on a platform difference. Failing visibly turns "this platform didn't expose the script" into an actionable message.

Finally, the diagnostic lesson generalizes: the research's cache-path question went unanswered because its evidence stopped at file layout and never tested runtime behavior — there was no wrong conclusion to catch, only a question left open. Any claim of the form "the paths will resolve" needs to ask *what directory will the process be in when it runs*, not *where did the files get copied*. The dated-correction pattern (append a Correction section, preserve the original text) keeps the research history honest without rewriting it.

## When to Apply

- Marketplace-installed skills report shared or skill-local scripts as "not found"
- Writing or reviewing skill content that invokes scripts bundled with the plugin
- Adding a new skill or script that will be invoked from skill markdown
- Reviewing changes that touch script references in `SKILL.md` or `references/*.md`
- Supporting platforms other than Claude Code that consume the same skill files

## Examples

**Before (incorrect — bare CWD-relative path, resolves against the user's project at runtime):**

```bash
base_branch=$(scripts/context-gather.sh | python3 -c "import sys, json; print(json.load(sys.stdin)['default_branch'])")
```

**After (correct — shared tier, substituted at skill-load time):**

```bash
base_branch=$("${CLAUDE_PLUGIN_ROOT}/scripts/context-gather.sh" | python3 -c "import sys, json; print(json.load(sys.stdin)['default_branch'])")
```

**Cross-skill reference (before → after):**

```bash
# Before — root-relative, CWD-dependent
skills/ts-pr-fix-findings/scripts/post-pr-comment.sh --repo {owner}/{repo} --pr {number} --body "$FALLBACK_BODY"

# After — plugin-rooted cross-skill form
"${CLAUDE_PLUGIN_ROOT}/skills/ts-pr-fix-findings/scripts/post-pr-comment.sh" --repo {owner}/{repo} --pr {number} --body "$FALLBACK_BODY"
```

**Skill-local reference (before → after):**

```bash
# Before
PR_DATA=$(skills/ts-pr-review/scripts/fetch-pr-data.sh "$PR_URL")

# After
PR_DATA=$("${CLAUDE_SKILL_DIR}/scripts/fetch-pr-data.sh" "$PR_URL")
```

**Guarded fallback for non-Claude-Code platforms** (from `skills/ts-commit/SKILL.md`):

```bash
if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && [ -f "${CLAUDE_PLUGIN_ROOT}/scripts/context-gather.sh" ]; then
  "${CLAUDE_PLUGIN_ROOT}/scripts/context-gather.sh"
else
  echo "context-gather.sh not resolvable on this platform (CLAUDE_PLUGIN_ROOT unset or script missing); gather the context manually." >&2
fi
```

**PATH bootstrap when many bare-name invocations follow** (the `ts-coding-workflow` Phase 0 shape, abridged):

```bash
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-}"
if [ -z "$PLUGIN_ROOT" ]; then
  for candidate in "$HOME/ws/taegosts-skills" "$HOME/_ws/taegosts-skills" "$HOME/src/taegosts-skills"; do
    if [ -f "$candidate/scripts/context-gather.sh" ]; then PLUGIN_ROOT="$candidate"; break; fi
  done
fi
if [ -z "$PLUGIN_ROOT" ]; then
  echo "taegosts-skills scripts unresolvable (CLAUDE_PLUGIN_ROOT unset and no taegosts-skills checkout found); continuing without the bundled helper scripts." >&2
else
  export PATH="$PLUGIN_ROOT/scripts:$PATH"
  for d in "$PLUGIN_ROOT"/skills/*/scripts; do
    [[ -d "$d" ]] && export PATH="$d:$PATH"
  done
fi
```

**Bundled validator through the wrapper** (note the deliberately bare `--script` argument — the wrapper resolves it against `--skill-dir`):

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/run-bundled-validator.sh" --skill-dir "${CLAUDE_SKILL_DIR:-<absolute path of the directory containing the SKILL.md you just read>}" --script scripts/validate-frontmatter.py -- <output-path>
```

## Prevention: the `verify-script-refs.sh` regression gate

New gate `scripts/verify-script-refs.sh` makes the convention mechanically enforced instead of review-dependent:

- **Scans** `skills/*/SKILL.md` and `skills/*/references/**/*.md`; `INDEX.md` files are skipped as generator-owned listings, and `skills/*/scripts/*.sh` internals are out of scope (`$SCRIPT_DIR` is correct there).
- **Flags** command-position references to `scripts/<name>.sh|.py` or `skills/<name>/scripts/<name>.sh|.py` that are not prefixed on the same token by `${CLAUDE_PLUGIN_ROOT}`, `${CLAUDE_SKILL_DIR}`, or `$SCRIPT_DIR`, reporting `file:line` per violation.
- **Command position** is decided by a denylist: every preceding word defaults to a command position (so `sudo`, `xargs`, `time`, `nohup`, `find -exec`, and other launchers are caught), and the only exemptions are non-execution shapes — line-initial prose, markdown list markers, flag/option argument position (`cp -r scripts/foo.sh dst`, `[ -f scripts/foo.sh ]`), and quote-stripped separators. Leading `VAR=value` assignment words are consumed before classification, so `MODE=test scripts/foo.sh` is caught.
- **Reports** backtick-quoted script references as advisories (`file:line` + token) instead of silently passing them: the gate exits 0, and the model running it judges each advisory line as mention-only or invocation. The `!`-prefilled exec form is a real invocation and stays on the violation path.
- **Whitelists** exactly the three intentional exceptions above: `--script` wrapper arguments of actual `run-bundled-validator.sh` invocations (separator-free, double-dash only), the ts-compound `git rev-parse --show-toplevel` lines, and `$SCRIPT_DIR`-prefixed references.
- **Wired into** `.pre-commit-config.yaml` (`always_run`, alongside `update-indexes` and `shellcheck`) and covered by 24 R4 tests in `tests/scripts/test-verify-script-refs.sh`, which exercise violation shapes, guarded shapes, each whitelist, advisories, and the error paths.

## Secondary learning: idempotent index regeneration

The gate story surfaced a second, independent defect worth recording: the INDEX generators (`scripts/index-scripts.py`, `scripts/update-indexes.py`) run via the pre-commit `update-indexes` hook, and naive regeneration clobbered hand-maintained `INDEX.md` content. Fixes, all tested:

- **Content-idempotent regeneration** — an existing `INDEX.md` is left completely untouched when the regenerated content differs only in the `last-updated:` line, so re-running the hook no longer produces noise diffs.
- **Frontmatter preservation** — `created:` was already preserved; `owner:` is now preserved the same way (a round-1 finding caught the generator resetting a hand-maintained owner on `skills/ts-compound-refresh/scripts/INDEX.md`).
- **Hand-maintained sections survive** — `## ` sections maintained between the intro and the table (standards/conventions relationship notes) are carried over via `extract_extra_sections` instead of dropped.
- **`lib/` recursion** — `scan_scripts` recurses into `scripts/lib/` so `lib/input-validation.sh` keeps its INDEX row.
- **Convention survives regeneration** — every generated `INDEX.md` now carries a one-line script-resolution note (resolve via `${CLAUDE_PLUGIN_ROOT}` on Claude Code; from the loaded skill directory or a checkout elsewhere), so the rule is re-stated every time the generator runs. `docs/ROUTING.md` is manually maintained and carries the same note.

The general lesson: a generator that runs automatically on every commit must be idempotent with respect to hand-maintained content, or the automation itself becomes the source of drift.

## Known pre-existing issues (not introduced by this fix)

Recorded so they are not misattributed to this branch:

- A bare `verify-scripts.sh` full run reports roughly 58 FAILs on `main` (non-executable files, missing `--help` on files this fix never touched).
- `pytest tests/` does not auto-collect the dash-named Python tests in `tests/scripts/` (e.g. `test-index-scripts.py`, `test-update-indexes.py`) — pytest's default `python_files` pattern is `test_*.py`.

## Related

- [Script Extraction Standards](../../standards/script-extraction-standards.md) — canonical rule ("Script path resolution")
- [Plan: fix plugin script resolution](../../plans/2026-09-07-001-fix-plugin-script-resolution-plan.md) — the fix plan that produced this pattern (inventories A–D, verification steps)
- [Research: Plugin Cache and Reload Behavior](../../plans/2026-06-22-003-research-plugin-cache-behavior-plan.md) — carries a dated correction answering the cache-path question the research never posed
- [Claude Code Plugin Repository Structure](claude-code-plugin-repository-structure.md) — plugin layout and installation mechanics
- `scripts/run-bundled-validator.sh` — the wrapper pattern this guidance extends (Issue #109)
- Issue #115 — the marketplace-install failure this resolves
