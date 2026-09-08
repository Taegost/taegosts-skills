---
tags: [standards, scripts, extraction]
description: Canonical reference for when inline bash blocks in skills should be extracted to standalone scripts.
---

# Script Extraction Standards

Canonical reference for when inline bash blocks in skills should be extracted to standalone scripts.

## When to extract

Inline bash blocks in skills should be extracted to standalone scripts when:

- The block is duplicated across multiple skills
- The block contains complex fallback chains or error handling
- Extraction enables unit testing

## Requirements for extracted scripts

Extracted scripts must:

- Follow the frontmatter standard (`docs/standards/script-frontmatter-convention.md`)
- Be executable (`chmod +x`)
- Have corresponding tests in `tests/scripts/`

Trivial one-liners (e.g., `git status`, `gh pr view`) that are not duplicated may remain inline.

## Script path resolution

Runtime script invocations inside skills must resolve against the plugin installation, never against the current working directory.

- **Plugin-shared tier** (the repo-root `scripts/` directory): invoke as `${CLAUDE_PLUGIN_ROOT}/scripts/<script>`
- **Cross-skill references** (another skill's scripts): invoke as `${CLAUDE_PLUGIN_ROOT}/skills/<skill-name>/scripts/<script>`
- **Skill-local tier** (the loaded skill's own `scripts/` directory): invoke as `${CLAUDE_SKILL_DIR}/scripts/<script>`

`${CLAUDE_PLUGIN_ROOT}` and `${CLAUDE_SKILL_DIR}` are Claude Code string substitutions, resolved at skill-load time and independent of the working directory.

- **Bare CWD-relative paths are forbidden.** At skill-execution time the Bash tool's CWD is the user's project, not the plugin cache directory, so a bare `scripts/foo.sh` resolves to `<user-project>/scripts/foo.sh` and fails (Issue #115).
- **Platforms where the variables are unset:** resolve from the loaded skill directory or the taegosts-skills checkout; if still unresolvable, fail visibly — state that the script cannot be located and use the documented manual fallback rather than silently skipping.
- **Script-to-script references** inside the scripts themselves keep using `$SCRIPT_DIR`-relative paths; a script resolving its own dependencies from its own location is correct in every layout.

Unprefixed runtime references are caught by the `scripts/verify-script-refs.sh` regression gate.

### The `scripts/lib/` shared-library tier

`scripts/lib/` is the shared library tier: first-party repo code whose files are sourced (`source .../input-validation.sh`) or imported (`from index_common import ...`, after the importer adds `scripts/lib/` to `sys.path`) by other scripts, never invoked directly as commands.

- **Runtime-invocation rules do not apply inside `scripts/lib/`.** The `${CLAUDE_PLUGIN_ROOT}`/`${CLAUDE_SKILL_DIR}` prefix requirement enforced by `scripts/verify-script-refs.sh` governs command-position invocations in skill markdown; lib files are consumed via `source`/import from other scripts that already resolve their own location.
- **INDEX listing inside `scripts/lib/` is best-effort at the top level only.** Generators list top-level `lib/` files but intentionally do not recurse into nested subdirectories of `lib/`. Coverage gaps inside `scripts/lib/` (e.g. a nested `lib/nested/helper.sh` not appearing in `scripts/INDEX.md`) are expected and must not be flagged in review.

## Gate scope

`scripts/verify-scripts.sh` classifies every scanned file by its repo-relative path and applies one check set per class. The classification happens at check time, so it applies identically in all three gate modes (`--all`, a directory argument, and `--file`) — no mode filters its own file list.

| Path class | Checks applied | Rationale |
|------|----------------|-----------|
| `tests/` | none — out of scope | Test scripts are run via `bash`/pytest, not invoked as commands; they are not command-surface code (matching the frontmatter convention's "Test Scripts (Excluded)" scope in `docs/standards/script-frontmatter-convention.md`) |
| `scripts/lib/` | syntax (`bash -n` / `python3 -m py_compile`) and control-character scan only | First-party shared libraries (see "The `scripts/lib/` shared-library tier" above): sourced or imported, never invoked as commands, so `--help` and the executable bit do not apply — but a syntax-broken library breaks every importer, so the cheap checks stay |
| everything else (`.sh`/`.py`) | full set — syntax, control characters, executable bit, `--help` flag | Command-surface scripts |

Out-of-scope files are neither counted as passed nor failed; they are skipped and reported as a skip count. Failures are reported by repo-relative path, so duplicate basenames in different directories stay distinguishable.
