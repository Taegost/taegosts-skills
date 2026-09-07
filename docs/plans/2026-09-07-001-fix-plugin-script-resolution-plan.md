---
title: "fix: Resolve shared script paths for marketplace-installed skills (Issue #115)"
type: fix
date: 2026-09-07
origin: "https://github.com/taegost/taegosts-skills/issues/115"
---

# fix: Resolve shared script paths for marketplace-installed skills (Issue #115)

## Summary

Marketplace-installed skills fail to find the shared `scripts/` tier (and most skill-local scripts) because every skill invokes them with bare CWD-relative paths. The Bash tool's CWD at skill-execution time is the **user's project**, not the plugin cache directory, so `scripts/context-gather.sh` resolves to `<user-project>/scripts/...`, which does not exist. Fix by rewriting references to `${CLAUDE_PLUGIN_ROOT}` (plugin-shared tier) and `${CLAUDE_SKILL_DIR}` (skill-local tier) — the official Claude Code string substitutions — with a visible guard/fallback for non-Claude-Code platforms, and add a regression gate that fails if unprefixed runtime references reappear.

## Problem Frame

### Diagnosis (verified 2026-09-07)

The issue title assumes the scripts "are not being put into the plugin cache." That premise is wrong:

1. **Scripts ARE in the plugin cache.** Marketplace installs copy the entire plugin root (the repo root — `.claude-plugin/marketplace.json` declares `source: "./"`) into `~/.claude/plugins/cache/taegosts-skills/taegosts-skills/<version>/`. Verified on this machine: `474b19e4f24b/scripts/` contains all shared scripts and `474b19e4f24b` is the current `origin/main` HEAD.
2. **The bug is path resolution, not distribution.** Skill bodies invoke scripts as bare relative paths. At execution time the Bash tool's CWD is the user's project, so the reference misses the cache copy. The repo already documents this exact mechanism in `skills/ts-compound/SKILL.md` (Phase 2 step 8 note) and in the header of `scripts/run-bundled-validator.sh` (added via #109 work), which solved it for skill-local *validators* only — the shared tier and most skill-local scripts are still invoked bare.
3. **Official mechanism** (Claude Code docs, "Available string substitutions" under skills): `${CLAUDE_PLUGIN_ROOT}` is substituted at skill-load time to the plugin's installation directory and is explicitly intended for "resources shared between the plugin's skills"; `${CLAUDE_SKILL_DIR}` resolves to the loaded skill's own directory. Both work regardless of CWD.
4. `docs/plans/2026-06-22-003-research-plugin-cache-behavior-plan.md` concluded that "relative conventions still hold" in the cache — incorrect, because skills execute with CWD = user project, not the cache directory. This plan corrects that record.

### Chosen strategy

Direct `${CLAUDE_PLUGIN_ROOT}` / `${CLAUDE_SKILL_DIR}` references, with a guard/fallback note for shared references — extending the pattern ts-compound and `run-bundled-validator.sh` already established — so non-Claude-Code platforms (Hermes sync via `scripts/sync-taegosts-skills.sh`) fail visibly rather than silently skipping.

## Locating Every Instance (methodology)

Inventory below was taken against `origin/main` at `474b19e` (2026-09-07). Re-run these greps after branching and again before opening the PR, since the remote may move:

```bash
# A. bare shared-tier runtime refs
git grep -nE '(^|[^A-Za-z_}$/.])scripts/[a-zA-Z0-9_/-]+\.(sh|py)' -- skills | grep -vE 'skills/[a-z-]+/scripts/|session-history'
# B. root-relative skill-local refs
git grep -nE 'skills/[a-z-]+/scripts/' -- skills | grep -v 'INDEX.md:'
# C. ../../ escapes in skill docs ($SCRIPT_DIR refs inside scripts are correct — leave them)
git grep -n '\.\./\.\./scripts' -- skills | grep 'SKILL.md\|references/'
# D. PATH/rev-parse bootstrap
git grep -nE 'rev-parse --show-toplevel|export PATH=' -- skills
# E. coverage check after fix
git grep -n 'CLAUDE_PLUGIN_ROOT\|CLAUDE_SKILL_DIR' -- skills
```

### Inventory A — bare shared-tier `scripts/...` → `${CLAUDE_PLUGIN_ROOT}/scripts/...`

| File | Lines | Runtime calls |
|---|---|---|
| `skills/load-plan/SKILL.md` | 32, 88, 143 | `locate-plan.py` |
| `skills/ts-verify-implementation/SKILL.md` | 37, 54, 89, 126 | `context-gather.sh`, `extract-ktds.py`, `verify-ktd-literal.py`, `detect-coverage-gaps.sh` |
| `skills/ts-work/SKILL.md` | 65, 169, 201 | `extract-ktds.py`, `detect-changed-code-files.sh`, `wait-for-file.sh` |
| `skills/ts-pr-fix-findings/SKILL.md` | 44, 248 | `extract-ktds.py`, `request-reviews.sh` |
| `skills/ts-plan/SKILL.md` | 203 | `wait-for-file.sh` |
| `skills/ts-doc-review/SKILL.md` | 236 | `wait-for-file.sh` |
| `skills/ts-doc-review/references/walkthrough.md` | 46 | `run-id.sh` |
| `skills/ts-compound/SKILL.md` | 65, 363, 366 | `run-bundled-validator.sh` invocations (wrapper exists but is called bare) |
| `skills/ts-compound-refresh/SKILL.md` | 24, 25 | `run-bundled-validator.sh` (prose) |
| `skills/ts-compound-refresh/references/per-action-flows.md` | 64, 67, 78, 81 | `run-bundled-validator.sh` invocations |

### Inventory B — root-relative skill-local refs

Same-skill references → `${CLAUDE_SKILL_DIR}/scripts/...`; the one cross-skill reference → `${CLAUDE_PLUGIN_ROOT}/skills/<name>/scripts/...`.

| File | Lines | Notes |
|---|---|---|
| `skills/ts-doc-review/SKILL.md` | 137, 138 | own scripts (K8s security checks) |
| `skills/ts-pr-fix-findings/SKILL.md` | 59, 62, 66, 235, 239, 253 | own scripts |
| `skills/ts-pr-review/SKILL.md` | 81, 99 | own scripts |
| `skills/ts-pr-review/SKILL.md` | 161 | **cross-skill** (ts-pr-fix-findings' `post-pr-comment.sh`) → PLUGIN_ROOT form |
| INDEX-pointer prose: `skills/ts-code-review/SKILL.md:66`, `skills/ts-compound-refresh/SKILL.md:13`, `skills/ts-verify-implementation/SKILL.md:29`, `skills/load-plan/SKILL.md:143` | — | doc pointers; prefix so the model can open them from any CWD |

### Inventory C — `../../scripts/` escapes

- `skills/ts-commit/SKILL.md:38` and `skills/ts-commit-push-pr/SKILL.md:43` — `../../scripts/context-gather.sh` fallback sections. In the cache layout these resolve to `~/.claude/plugins/scripts/` — outside the plugin root, nonexistent. Replace with guarded `${CLAUDE_PLUGIN_ROOT}/scripts/context-gather.sh`.

### Inventory D — PATH bootstrap

- `skills/ts-coding-workflow/SKILL.md:20-28` — Phase 0 sets `REPO_ROOT="$(git rev-parse --show-toplevel)"` and prepends `$REPO_ROOT/scripts` to PATH. Under a marketplace install that resolves to the **user's project**, not the plugin. Rewrite to export `PATH="${CLAUDE_PLUGIN_ROOT}/scripts:${CLAUDE_PLUGIN_ROOT}/skills"/*/scripts:$PATH` (guarded), keeping bare-name invocations later in the file working.
- `skills/ts-compound/SKILL.md:47, 49, 292` — **leave as-is**: that repo root filters session history in the *user's* repo; intentionally not the plugin root.

### Explicitly not changing

- `source "$SCRIPT_DIR/../../../scripts/lib/input-validation.sh"` inside the 10 skill scripts — script-to-script references resolved from the script's own location; correct in the cache.
- ts-compound's existing `${CLAUDE_SKILL_DIR}` guards (session-history blocks, Phase 2 step 8) — already the target pattern.
- Relative `docs/...` / `references/...` mentions in SKILL.md prose — same bug class, out of scope for #115; file as a follow-up issue.

## Implementation Units

1. **Branch hygiene (pre-work):** branch `fix/issue-115-plugin-script-resolution` from freshly pulled `main`.
2. **Per-skill "Script resolution" note:** one short paragraph per affected SKILL.md (modeled on ts-compound's existing note) stating that `${CLAUDE_PLUGIN_ROOT}` is substituted at load time on Claude Code; if it arrives unsubstituted (other platforms), resolve from the loaded skill directory or the taegosts-skills checkout; if still unresolvable, say so visibly and use the documented manual fallback rather than silently skipping. This is the guard for shared references.
3. **Mechanical replacements** per inventories A–D, including prose mentions so paths stay copy-runnable.
4. **Regression gate:** new `scripts/verify-script-refs.sh` — R3 frontmatter, executable, listed in `scripts/INDEX.md` via `scripts/index-scripts.py`, tests in `tests/scripts/` (per `docs/standards/script-extraction-standards.md`). Fails when a SKILL.md or `references/` file contains a runtime script invocation not prefixed with `${CLAUDE_PLUGIN_ROOT}` / `${CLAUDE_SKILL_DIR}` / `$SCRIPT_DIR`, with an explicit whitelist for the intentional exceptions (ts-compound repo-root lines). Wire into pre-commit alongside `verify-scripts.sh`.
5. **Standards (canonical rule — conventions live in `docs/standards/`, not CLAUDE.md):**
   - `docs/standards/script-extraction-standards.md` — add a "Script path resolution" section as the canonical rule: runtime script invocations in skills use `${CLAUDE_PLUGIN_ROOT}/scripts/...` (shared tier) and `${CLAUDE_SKILL_DIR}/scripts/...` (skill-local tier); never bare CWD-relative paths; non-Claude-Code platforms use the guarded visible fallback. Skill "Script resolution" notes (unit 2) reference this standard.
   - `CLAUDE.md` — no convention content added (per repo policy, conventions live in `docs/standards/`; the Script Extraction Policy already moved there in `310fb32`).
6. **Index files + generators (round 2 feedback — must not regress on regeneration):**
   - `scripts/index-scripts.py` (`generate_index_md()`) and `scripts/update-indexes.py` (`generate_index_md()`) — extend both templates to emit a one-line resolution note after the intro line of every generated INDEX.md, e.g.: *"Paths below are relative to this index. On Claude Code marketplace installs, resolve via `${CLAUDE_PLUGIN_ROOT}/<index dir>/...`; on other platforms, resolve from the loaded skill directory or the taegosts-skills checkout."*
   - Regenerate all INDEX.md files (pre-commit hook runs both generators on commit; alternatively run them directly) so every `scripts/INDEX.md`, `skills/*/scripts/INDEX.md`, and `docs/**/INDEX.md` carries the note.
   - `docs/ROUTING.md` — manually maintained (not generator-owned; `validate-index-standards.py` grants it an R7 exception), so edit directly: add the same resolution note near the top.
   - Update generator tests for the template change: `tests/scripts/test-index-scripts.py`, `tests/scripts/test-update-indexes.py`, and `tests/test_validate_index_standards.py` (assert the note is present in generated output, not just tolerate it).
7. **Docs corrections:**
   - `docs/plans/2026-06-22-003-research-plugin-cache-behavior-plan.md` — correct the "relative conventions still hold" conclusion.
   - `docs/solutions/tooling-decisions/claude-code-plugin-repository-structure.md` — add the script-reference rule (shared tier via `${CLAUDE_PLUGIN_ROOT}`, skill-local via `${CLAUDE_SKILL_DIR}`).
   - New solutions entry for the resolution pattern (via the `ts-compound` skill, per repo convention for non-trivial fixes).
8. **Ship:** PR via `ts-commit-push-pr`; body carries the diagnosis summary and `Fixes #115`.

## Verification

1. `scripts/verify-script-refs.sh` passes; re-run inventory greps A–D → zero unprefixed runtime refs outside the whitelist.
2. **Cache simulation:** from an unrelated CWD (`cd /tmp`) with `CLAUDE_PLUGIN_ROOT` pointing at the real cache dir, run previously-bare commands (e.g. the rewritten `context-gather.sh` and `run-bundled-validator.sh` invocations) → succeed. With the variable unset → visible guard message, no silent skip.
3. Repo gates: `pytest tests/`, `scripts/run-shellcheck.sh`, `scripts/verify-scripts.sh`, index regeneration clean.
4. `claude plugin validate ./` (if available).
5. **End-to-end (manual, post-merge):** refresh the plugin, invoke `ts-commit` or `load-plan` in a different project, confirm the shared script runs. Post the diagnosis comment on issue #115 when opening the PR.
