---
date: 2026-06-22
topic: import-skills
---

# Import Skills Requirements

## Summary

Import three existing skills (`pr-fix-findings`, `pr-review`, `verify-implementation`) from `~/.claude/skills` into this repository using the Claude Code plugin structure, with a `marketplace.json` manifest and documented per-skill dependencies.

## Requirements

**Plugin structure**

- R1. Repo root contains `.claude-plugin/marketplace.json` with plugin metadata and a `plugins` array pointing to the repo root.
- R2. Each skill lives in `skills/<skill-name>/SKILL.md`, matching the Claude Code plugin convention.
- R3. Skills that need supporting files (references, templates) get a `references/` subdirectory alongside `SKILL.md`. These three skills currently have none — leave the directory out until needed.

**Skills to import**

- R4. `skills/pr-fix-findings/SKILL.md` — copied from `~/.claude/skills/pr-fix-findings/SKILL.md`.
- R5. `skills/pr-review/SKILL.md` — copied from `~/.claude/skills/pr-review/SKILL.md`.
- R6. `skills/verify-implementation/SKILL.md` — copied from `~/.claude/skills/verify-implementation/SKILL.md`.

**Dependencies**

- R7. Each skill's external dependencies are documented in the README. Actual dependencies:
  - `pr-fix-findings` requires `/ce-debug` (Compound Engineering plugin)
  - `pr-review` requires `/code-review` (claude-plugins-official plugin)
  - `verify-implementation` has no plugin dependencies — it is self-contained

**Discoverability**

- R8. `README.md` explains what the plugin contains, how to install it, and lists each skill's dependencies with the correct plugin source.

## Scope Boundaries

- No skill content changes — copy as-is, then iterate in future brainstorms.
- No CI/CD, automated testing, or release pipeline in this pass.
- No migration of skills that already live elsewhere (e.g., Compound Engineering's own skills).
