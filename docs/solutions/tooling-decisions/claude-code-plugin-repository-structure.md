---
title: "Claude Code plugin repository structure"
date: 2026-06-22
category: tooling-decisions
module: claude-code-plugins
problem_type: tooling_decision
component: tooling
severity: low
applies_when:
  - Creating a new Claude Code plugin repository from scratch
  - Migrating existing skills from ~/.claude/skills/ into a version-controlled plugin
  - Debugging a plugin that does not appear after installation
tags:
  - claude-code
  - plugin-structure
  - marketplace
  - skills
---

# Claude Code Plugin Repository Structure

## Context

When setting up a repository to function as a Claude Code plugin (a distributable collection of custom skills), the core challenge is choosing the correct manifest format. Claude Code supports two JSON manifests inside `.claude-plugin/`: `marketplace.json` and `plugin.json`. They serve different purposes, and using the wrong one causes plugin discovery to fail silently.

## Guidance

The repo root manifest must be `.claude-plugin/marketplace.json` — not `plugin.json`. `plugin.json` is the format for subdirectories within an already-discovered marketplace tree (e.g., `compound-engineering/3.11.2/.claude-plugin/plugin.json`). For a standalone plugin repo, `marketplace.json` is the entry point.

### Directory structure

```text
.claude-plugin/
  marketplace.json
skills/
  <skill-name>/
    SKILL.md
```

### marketplace.json format

```json
{
  "$schema": "https://anthropic.com/claude-code/marketplace.schema.json",
  "name": "my-plugin",
  "description": "What this plugin does.",
  "owner": {
    "name": "Your Name",
    "url": "https://github.com/yourname"
  },
  "plugins": [
    {
      "name": "my-plugin",
      "description": "Short description.",
      "source": "./",
      "category": "workflow"
    }
  ]
}
```

- `$schema` points to `marketplace.schema.json`, not `plugin.schema.json`.
- The `plugins` array contains entries with `name`, `description`, `source`, and `category`.
- `source: "./"` means the repo root itself is the plugin.

### SKILL.md frontmatter

```yaml
---
name: my-skill
description: "What this skill does"
user_invocable: true
---
```

The `name` field must match the directory name. A mismatch (e.g., `name: knap-my-skill` in `skills/my-skill/SKILL.md`) causes confusion about how users invoke the skill.

### Installation (settings.json)

```json
{
  "extraKnownMarketplaces": {
    "my-plugin": {
      "source": {
        "source": "git",
        "url": "https://github.com/yourname/my-plugin.git"
      },
      "autoUpdate": true
    }
  },
  "enabledPlugins": {
    "my-plugin@my-plugin": true
  }
}
```

## Why This Matters

Using `plugin.json` instead of `marketplace.json` at the repo root is a silent failure. Claude Code's plugin discovery looks for `marketplace.json` to register a new marketplace source; it never finds `plugin.json` at that level, so the plugin simply does not appear. No error message — the skills just aren't there.

Dependency assumptions must also be verified per-skill, not assumed from the plugin's origin. Different skills may depend on different plugins (e.g., one skill needs Compound Engineering, another needs claude-plugins-official, a third is self-contained).

## When to Apply

- Creating a new Claude Code plugin repository from scratch
- Migrating existing skills from `~/.claude/skills/` into a version-controlled plugin
- Debugging a plugin that does not appear after installation (check `marketplace.json` vs `plugin.json` first)
- Documenting skill dependencies for other users of the plugin

## Examples

**Before (incorrect — uses `plugin.json`, which is the wrong manifest for a repo root):**

```text
.claude-plugin/
  plugin.json          <-- WRONG: this is for subdirectories within a marketplace tree
skills/
  my-skill/
    SKILL.md
```

**After (correct — uses `marketplace.json`):**

```text
.claude-plugin/
  marketplace.json     <-- CORRECT: repo root uses marketplace.json
skills/
  my-skill/
    SKILL.md
```

## Related

- Compound Engineering plugin (reference implementation): `compound-engineering-plugin/.claude-plugin/marketplace.json`
- caveman plugin (reference implementation): `caveman/.claude-plugin/marketplace.json`
