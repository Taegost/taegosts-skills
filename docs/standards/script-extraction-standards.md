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
