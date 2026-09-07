---
title: "Claude Code plugin script path resolution"
date: 2026-09-07
category: docs/solutions/tooling-decisions
module: claude-code-plugins
problem_type: tooling_decision
component: tooling
severity: medium
applies_when:
  - Marketplace-installed skills report shared or skill-local scripts as "not found"
  - Writing or reviewing skill content that invokes scripts bundled with the plugin
  - Supporting platforms other than Claude Code that consume the same skill files
tags:
  - claude-code
  - plugin-structure
  - marketplace
  - skills
  - script-resolution
---

# Claude Code Plugin Script Path Resolution

## Context

Marketplace-installed skills report the plugin's shared scripts as "not found" when invoked (Issue #115): commands such as `scripts/context-gather.sh` fail with a missing-file error, while the same invocation works when run from the repository checkout.

The intuitive diagnosis — the scripts are not shipped — is wrong. Marketplace installs copy the entire plugin root (the repo root; `.claude-plugin/marketplace.json` declares `source: "./"`) into `~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/`, and the shared `scripts/` tier arrives intact. The actual root cause is path resolution: skill bodies invoked scripts with bare CWD-relative paths, and at skill-execution time the Bash tool's CWD is the **user's project**, not the cache directory. A bare `scripts/context-gather.sh` therefore resolves to `<user-project>/scripts/context-gather.sh`, which does not exist.

## Guidance

Reference bundled scripts through the official Claude Code string substitutions, resolved at skill-load time and independent of CWD:

- Plugin-shared tier: `${CLAUDE_PLUGIN_ROOT}/scripts/<script>`
- Cross-skill references: `${CLAUDE_PLUGIN_ROOT}/skills/<skill-name>/scripts/<script>`
- The loaded skill's own scripts: `${CLAUDE_SKILL_DIR}/scripts/<script>`

On platforms where the variables arrive unset (for example, the Hermes sync consuming these files outside Claude Code), use a guarded fallback: resolve from the loaded skill directory or the taegosts-skills checkout, and if still unresolvable, say so visibly and use the documented manual fallback rather than silently skipping.

Script-to-script references inside the scripts themselves are exempt: they keep using `$SCRIPT_DIR`-relative paths, because a script resolving its own dependencies from its own location is correct in every layout.

### Rollout

- Every affected skill's runtime script invocations were rewritten per the fix plan's inventories: bare shared-tier refs, root-relative skill-local refs, `../../scripts/` escapes, and the PATH bootstrap in `ts-coding-workflow`.
- `scripts/verify-script-refs.sh` was added as a regression gate (wired into pre-commit) that fails when a skill document contains an unprefixed runtime script invocation.
- The INDEX generators (`scripts/index-scripts.py`, `scripts/update-indexes.py`) emit a one-line resolution note into every generated `INDEX.md`, so the convention survives regeneration.

The canonical rule lives in the [Script Extraction Standards](../../standards/script-extraction-standards.md) ("Script path resolution"); the change set is in the [fix: Resolve shared script paths for marketplace-installed skills (Issue #115)](../../plans/2026-09-07-001-fix-plugin-script-resolution-plan.md) plan.

## Why This Matters

The fix targets the correct layer. Distribution was never broken — the cache contains every script — so repackaging or reinstalling the plugin could not have helped. Only resolving references against the installation directory (instead of the caller's CWD) makes invocations work both from the checkout and from a marketplace install.

The guard requirement matters because a script reference that fails silently — a step quietly skipped when the variable is unset — degrades the skill's behavior without any signal. Failing visibly turns a platform difference into an actionable message.

## When to Apply

- Marketplace-installed skills report shared or skill-local scripts as "not found"
- Writing or reviewing skill content that invokes scripts bundled with the plugin
- Supporting platforms other than Claude Code that consume the same skill files

## Examples

**Before (incorrect — bare CWD-relative path, resolves against the user's project at runtime):**

```bash
scripts/context-gather.sh
```

**After (correct — substituted at skill-load time on Claude Code, guarded elsewhere):**

```bash
if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ]; then
  CONTEXT_SCRIPT="${CLAUDE_PLUGIN_ROOT}/scripts/context-gather.sh"
else
  echo "context-gather.sh: CLAUDE_PLUGIN_ROOT is unset; resolve it from the loaded skill directory or the taegosts-skills checkout" >&2
  exit 1
fi
bash "$CONTEXT_SCRIPT"
```

## Related

- [Script Extraction Standards](../../standards/script-extraction-standards.md) — canonical rule ("Script path resolution")
- [Plan: fix plugin script resolution](../../plans/2026-09-07-001-fix-plugin-script-resolution-plan.md) — the fix plan that produced this pattern
- [Claude Code Plugin Repository Structure](claude-code-plugin-repository-structure.md) — plugin layout and installation mechanics
- [Research: Plugin Cache and Reload Behavior](../../plans/2026-06-22-003-research-plugin-cache-behavior-plan.md) — carries the dated correction of its earlier "relative conventions hold" conclusion
- Issue #115 — the marketplace-install failure this resolves
