---
title: "feat: Import skills into Claude Code plugin structure"
type: feat
status: completed
date: 2026-06-22
origin: docs/brainstorms/2026-06-22-import-skills-requirements.md
---

# Import Skills into Claude Code Plugin Structure

## Summary

Import three existing skills (`pr-fix-findings`, `pr-review`, `verify-implementation`) into this repository using the Claude Code plugin directory structure, with a `marketplace.json` manifest and documented per-skill dependencies.

## Problem Frame

The skills are scattered across `~/.claude/skills` on individual machines with no version control or distribution mechanism. The user needs a single repo that works as a Claude Code plugin so that `git pull` propagates updates across all environments.

## Requirements

**Plugin structure**

- R1. Repo root contains `.claude-plugin/marketplace.json` with plugin metadata and a `plugins` array pointing to the repo root (`source: "./"`).
- R2. Each skill lives in `skills/<skill-name>/SKILL.md`, matching Claude Code plugin conventions.

**Skills to import**

- R3. `skills/pr-fix-findings/SKILL.md` — copied from `~/.claude/skills/pr-fix-findings/SKILL.md`.
- R4. `skills/pr-review/SKILL.md` — copied from `~/.claude/skills/pr-review/SKILL.md`.
- R5. `skills/verify-implementation/SKILL.md` — copied from `~/.claude/skills/verify-implementation/SKILL.md`.

**Dependencies**

- R6. Each skill's external dependencies are documented in the README. Actual dependencies:
  - `pr-fix-findings` requires `/ce-debug` (Compound Engineering plugin)
  - `pr-review` requires `/code-review` (claude-plugins-official plugin)
  - `verify-implementation` has no plugin dependencies — it is self-contained

**Discoverability**

- R7. `README.md` explains what the plugin contains, how to install it, and lists each skill's dependencies with the correct plugin source.

## Key Technical Decisions

**Plugin structure uses marketplace.json, not plugin.json.** Claude Code's plugin discovery expects `.claude-plugin/marketplace.json` at the repo root (with a `plugins` array and `source: "./"` pointing to the repo). `plugin.json` is the format for subdirectories within a marketplace tree. Reference: caveman and skill-llm-wiki plugins both use this pattern.

**Skills copied as-is, with one frontmatter fix.** The SKILL.md files are copied verbatim except for `verify-implementation`, whose frontmatter `name` field needs updating from `knap-verify-implementation` to `verify-implementation` to match the directory name. All other content changes are deferred.

## Implementation Units

### U1. Create marketplace manifest

- **Goal:** Create `.claude-plugin/marketplace.json` with the plugin's metadata.
- **Requirements:** R1
- **Dependencies:** None
- **Files:** `.claude-plugin/marketplace.json`
- **Approach:** Create a JSON file following the `marketplace.schema.json` format. Top-level fields: `name`, `description`, `owner`, and a `plugins` array with one entry whose `source` is `"./"` (repo root is the plugin). Reference the caveman plugin's `marketplace.json` as a template.
- **Verification:** File exists and is valid JSON matching the marketplace schema.

### U2. Create skill directories

- **Goal:** Create the `skills/` directory structure for all three skills.
- **Requirements:** R2
- **Dependencies:** None
- **Files:** `skills/pr-fix-findings/`, `skills/pr-review/`, `skills/verify-implementation/`
- **Approach:** Create three directories under `skills/`, one per skill. No `references/` subdirectories — none of these skills have supporting files.
- **Verification:** All three directories exist under `skills/`.

### U3. Copy skill files

- **Goal:** Copy each SKILL.md from `~/.claude/skills/` into the corresponding `skills/` directory, fixing the verify-implementation frontmatter name.
- **Requirements:** R3, R4, R5, R6
- **Dependencies:** U2
- **Files:** `skills/pr-fix-findings/SKILL.md`, `skills/pr-review/SKILL.md`, `skills/verify-implementation/SKILL.md`
- **Approach:** Copy `pr-fix-findings` and `pr-review` verbatim. For `verify-implementation`, update the frontmatter `name` field from `knap-verify-implementation` to `verify-implementation` to match the directory name; copy the rest verbatim.
- **Test expectation:** none — file copy with one metadata correction.
- **Verification:** Each file matches its source in `~/.claude/skills/`, except verify-implementation's corrected `name` field.

### U4. Update README

- **Goal:** Document what the plugin contains, how to install it, and each skill's dependencies.
- **Requirements:** R7
- **Dependencies:** U1, U2, U3
- **Files:** `README.md`
- **Approach:** Update the existing README with:
  - Plugin name and description
  - Installation instructions: add this repo's git URL to `~/.claude/settings.json` under `extraKnownMarketplaces` with `source.type: "git"` and `autoUpdate: true`
  - List of included skills with their descriptions
  - Per-skill dependency table: `pr-fix-findings` needs Compound Engineering plugin (`/ce-debug`), `pr-review` needs claude-plugins-official (`/code-review`), `verify-implementation` has no plugin dependencies
- **Test expectation:** none — documentation only.
- **Verification:** README describes the plugin, lists all three skills with correct dependencies, and has working installation steps.

## Scope Boundaries

- No skill content changes — copy as-is, then iterate in future brainstorms.
- No CI/CD, automated testing, or release pipeline.
- No migration of skills that already live elsewhere.
- No `references/` subdirectories — none of these skills need them yet.
