---
module: taegosts-skills
date: 2026-07-01
problem_type: convention
component: tooling
severity: low
related_components:
  - documentation
tags:
  - namespace
  - prefix
  - plugin-skills
  - ce-prefix
  - ts-prefix
  - naming-convention
---

# Renaming Skill Prefixes to Avoid Plugin Namespace Collisions

## Context

A Claude Code plugin repository originally shipped 13 skills with the `ce-` prefix (inherited from the Compound Engineering plugin). When multiple plugins in the same `.claude/plugins/cache/` directory use the same prefix, Claude Code cannot disambiguate which plugin owns a skill. This causes collisions where a user invokes `/ce-some-skill` and gets the wrong implementation.

The fix was to rename all skills from `ce-` to `ts-` (Taegost's Skills), which is unique to this plugin. The rename touched directory names, frontmatter fields, cross-skill references, runtime artifact paths, config directory references, brand strings, test paths, and script docstrings across the entire plugin tree.

## Guidance

### Naming Convention

Pick a prefix that is globally unique across all installed plugins. The prefix should be short, distinctive, and unlikely to collide with upstream forks. After choosing the prefix:

1. Rename directories first with `git mv` to preserve history.
2. Update all textual references (frontmatter, cross-references, paths, strings) with targeted sed replacements.
3. Verify no references were missed by grepping for the old prefix.

### Safe Rename Execution

**Step 1 -- Rename directories with git mv**

Use `git mv` (not plain `mv`) so git tracks the rename as a move rather than a delete-and-add. This preserves `git blame` and history.

```bash
git mv skills/ce-skill-a skills/ts-skill-a
git mv skills/ce-skill-b skills/ts-skill-b
# ... repeat for all directories
```

**Step 2 -- Update file contents with word-boundary sed**

Use word-boundary anchors to prevent double-prefixing. Naive replacement of `ce-` with `ts-` will break any string that already contains `ts-` (producing `ts-ts-`).

```bash
# Safe: word-boundary anchored replacement
sed -i 's/\bce-skill-a\b/ts-skill-a/g' skills/ts-*/SKILL.md
sed -i 's/\bce-skill-b\b/ts-skill-b/g' skills/ts-*/references/*.md

# Dangerous: produces ts-ts-skill-a from already-renamed patterns
# sed -i 's/ce-/ts-/g'  # NEVER use this without word boundaries
```

**Step 3 -- Update runtime paths**

Replace artifact and config directory references:

```bash
# Runtime artifacts
sed -i 's|/tmp/old-prefix/|/tmp/new-prefix/|g' skills/ts-*/SKILL.md

# Config directories
sed -i 's|\.old-prefix/|\.new-prefix/|g' skills/ts-*/SKILL.md
```

**Step 4 -- Update brand strings**

Replace the human-readable project name in docstrings and descriptions:

```bash
sed -i 's/Old Brand Name/New Brand Name/g' skills/ts-*/scripts/*.py
sed -i 's/Old Brand Name/New Brand Name/g' skills/ts-*/references/*.md
```

**Step 5 -- Update test references**

Test files reference scripts via `SCRIPT=` variables. Update after directory rename:

```bash
sed -i "s|skills/ce-|skills/ts-|g" tests/skills/ts-*/test-*.sh
```

**Step 6 -- Verify completeness**

Grepping for the old prefix should return zero hits in the plugin tree (excluding historical docs):

```bash
grep -rn '\bce-skill-a\b\|\bce-skill-b\b' skills/ tests/ README.md \
  --include='*.md' --include='*.py' --include='*.sh' \
  | grep -v 'docs/'
# Expected: empty output
```

### What NOT to Rename

- **External URLs** pointing to upstream repos (e.g., `github.com/original-plugin/...`). These are references to external resources, not local skill paths.
- **External skill references** from other plugins (e.g., `ce-worktree` defined by a different plugin). These are out of scope.
- **Historical documentation** in `docs/` directories. These record provenance and should remain as-is.

## Why This Matters

- **Plugin isolation.** Each plugin must own a unique prefix so Claude Code can resolve `/skill-name` invocations unambiguously. Colliding prefixes cause the wrong skill to execute.
- **Discoverability.** The `name:` field in SKILL.md frontmatter is how Claude Code indexes available skills. If two skills share a name, only one is visible.
- **Maintainability.** Using word-boundary sed patterns prevents silent corruption of strings that happen to contain the old prefix as a substring. This is the single most common mistake in bulk rename operations.

## When to Apply

- When forking or extending another plugin's skills and the original prefix collides with the upstream plugin or other installed plugins.
- When a plugin changes ownership or branding and needs a new namespace.
- When adding skills to a repository that already has a different prefix and you want consistency.
- Any time you need to bulk-rename identifiers across a codebase -- the word-boundary sed technique applies universally.

## Examples

### Before / After SKILL.md Frontmatter

```yaml
# Before
---
name: ce-plan
description: "Create structured plans..."
---

# After
---
name: ts-plan
description: "Create structured plans..."
---
```

### Before / After Cross-Reference

```markdown
# Before
Use `/ce-work` to execute the plan.

# After
Use `/ts-work` to execute the plan.
```

### Before / After Runtime Path

```markdown
# Before
Write artifacts to `/tmp/compound-engineering/ce-plan/<run-id>/`

# After
Write artifacts to `/tmp/taegosts-skills/ts-plan/<run-id>/`
```

### Safe vs Unsafe sed Patterns

```bash
# SAFE -- word-boundary anchored per skill name, prevents double-prefix
sed -i 's/\bce-plan\b/ts-plan/g' file.md

# UNSAFE -- replaces ALL occurrences including substrings
# If file already has "ts-plan", this produces "ts-ts-plan"
sed -i 's/ce-/ts-/g' file.md
```

### Verification Grep

```bash
# After all replacements, confirm zero stale references
grep -rn '\bce-plan\b\|\bce-work\b' skills/ tests/ README.md \
  --include='*.md' --include='*.py' --include='*.sh' \
  | grep -v 'docs/'
# Expected output: empty (no matches)
```

## Related

- [CE Skills Extraction](../tooling-decisions/ce-skills-extraction.md) — original extraction of skills from the Compound Engineering plugin
- [Claude Code Plugin Repository Structure](../tooling-decisions/claude-code-plugin-repository-structure.md) — plugin directory conventions
