---
title: "README lifecycle documentation for small plugin repos"
date: 2026-06-22
category: documentation-gaps
module: claude-code-plugins
problem_type: documentation_gap
component: documentation
severity: low
applies_when:
  - A new contributor opens the repo and does not know how to invoke the skills
  - A contributor wants to add a new skill and needs the frontmatter template
  - Someone asks "how do I test my changes before pushing?"
tags:
  - claude-code
  - plugin-structure
  - readme
  - documentation
  - usage-examples
  - contributing
---

# README Lifecycle Documentation for Small Plugin Repos

## Context

A Claude Code plugin repository (`taegosts-skills`) contained functional skill definitions but its README only had a high-level description and installation instructions. Users who installed the plugin had no guidance on how to invoke each skill, what output to expect, or how to contribute changes. The repository structure was undocumented, making it difficult for new contributors to understand where skill definitions lived versus planning docs.

An initial brainstorm phase also produced an incorrect dependency claim (that `verify-implementation` depended on the CE plugin) — caught only because SKILL.md files were grepped for references. This demonstrated the need for grounded research before writing documentation.

## Guidance

**Pattern: Self-contained README with three documentation sections for small plugin/tool repos.**

When a repository is small enough that separate files would create navigation overhead, consolidate Usage, Contributing, and Repository Structure into a single README.md rather than splitting into CONTRIBUTING.md, USAGE.md, and similar.

### Section 1: Usage — per-skill subsections with consistent structure

Each skill gets a subsection containing:
- A one-line description of what it does
- A bash code block showing exact invocation syntax
- A "What to expect" paragraph describing runtime behavior
- A dependency note if the skill requires another plugin or tool

```markdown
## Usage

### `/pr-review`
Reviews open pull requests and posts inline comments on issues.

```bash
/pr-review
```

**What to expect:** Scans all open PRs, reads changed files, and posts
actionable inline comments. Requires the code-review plugin.

### `/pr-fix-findings`
Fixes issues identified by a previous `/pr-review` run.

```bash
/pr-fix-findings
```

**What to expect:** Reads review comments, validates findings, presents
proposed actions for approval, then uses `/ce-debug` to implement fixes.
Requires the Compound Engineering plugin.
```

### Section 2: Contributing — explicit workflows with concrete steps

Provide two named workflows, one for each common contribution type, with numbered steps. Include the exact file path to edit, the reload command, and the commit message convention.

```markdown
## Contributing

### Fix an existing skill
1. Fork the repository
2. Edit `skills/<skill-name>/SKILL.md`
3. Run `/reload-plugins` in your Claude Code session to test locally
4. Commit with a conventional message (e.g., `fix: clarify pr-review output format`)
5. Open a PR

### Add a new skill
1. Fork the repository
2. Create `skills/<skill-name>/SKILL.md` with required frontmatter:
   `name`, `description`, `user_invocable: true`
3. Run `/reload-plugins` to verify it loads
4. Commit with `feat: add <skill-name> skill`
5. Open a PR
```

### Section 3: Repository Structure — annotated directory tree

Show the full layout with one-line annotations explaining each path's purpose.

```markdown
## Repository Structure

​```text
.claude-plugin/marketplace.json   # Plugin manifest
skills/<name>/SKILL.md            # Skill definitions (one dir per skill)
docs/                             # Brainstorms, plans, solution docs
README.md                         # This file
STRATEGY.md                       # Product strategy
LICENSE                           # MIT
​```
```

### Key Practice: Research before writing

Before documenting dependencies or relationships between skills and plugins, grep the actual source files. The initial brainstorm incorrectly stated that `verify-implementation` depended on the CE plugin — a grep of SKILL.md files for "CE" or "compound-engine" returned zero matches, correcting the assumption. Always verify claims against source truth, not memory or assumptions.

### Key Practice: Catch naming inconsistencies early

During doc review, a mismatch was found between `marketplace.json` (the actual filename) and `plugin.json` (what the brainstorm had called it). If the manifest name is wrong in the documentation, contributors will edit the wrong file. Cross-reference file names against the actual filesystem before publishing.

## Why This Matters

1. **Reduces onboarding friction.** Without usage examples, users must read SKILL.md source files to understand how to invoke skills. A README section with invocation syntax and behavioral descriptions lets users get productive immediately.

2. **Lowers the contribution barrier.** Named workflows ("Fix an existing skill" vs. "Add a new skill") give contributors a clear mental model. Without this, contributors must reverse-engineer the pattern from existing skills.

3. **Prevents documentation drift.** Consolidating into README.md for a small repo avoids the problem where CONTRIBUTING.md gets updated but USAGE.md does not (or vice versa). A single file is easier to keep accurate.

4. **Grounded documentation avoids misinformation.** The verify-implementation dependency correction shows that brainstorm-phase claims must be verified against source files before being published as documentation. An incorrect dependency claim could send a contributor down a dead-end path.

## When to Apply

- **Small plugin or tool repositories** (under ~10 skills/components) where separate doc files would add navigation overhead without proportional benefit.
- **After initial development is complete** and the repo is being prepared for public use or team onboarding.
- **When skills have non-obvious invocation syntax** or depend on external plugins that users might not know about.
- **When contribution patterns are consistent** across skills (same file to edit, same frontmatter schema, same reload command).
- **Before publishing a first version** — documentation gaps in v1 create a poor first impression that is hard to recover from.

This pattern does **not** apply when the repo is large enough that a single README would exceed ~300 lines, when multiple distinct audiences exist (users vs. contributors vs. maintainers), or when skills have divergent contribution workflows that would clutter a single file.

## Examples

**Before (README with only installation and a skills table):**

```markdown
# my-plugin
A Claude Code plugin with custom skills.

## Installation
[JSON snippets for settings.json]

## Skills
| Skill | Description |
|-------|-------------|
| `/pr-review` | Reviews PRs |
| `/pr-fix-findings` | Fixes findings |
```

A user who installs this plugin has no idea how to invoke the skills, what arguments they accept, or what output to expect.

**After (README with lifecycle coverage):**

```markdown
# my-plugin
A Claude Code plugin with custom skills.

## Installation
[JSON snippets for settings.json]

## Skills
| Skill | Description | Dependencies |
|-------|-------------|-------------|
| `/pr-review` | Reviews PRs | code-review plugin |
| `/pr-fix-findings` | Fixes findings | Compound Engineering |

## Usage

### `/pr-review`
Reviews a pull request and posts inline findings.

```bash
/pr-review PR #1
```

**What to expect:** Scans changed files, posts inline comments grouped
by severity, ends with a summary table and verdict.

## Contributing

### Fix an existing skill
1. Fork the repo
2. Edit `skills/<skill-name>/SKILL.md`
3. Run `/reload-plugins` to test
4. Commit with conventional message, open a PR

## Repository Structure

​```text
.claude-plugin/marketplace.json   # Plugin manifest
skills/<name>/SKILL.md            # Skill definitions
docs/                             # Plans and solutions
​```
```

## Related

- `docs/solutions/tooling-decisions/claude-code-plugin-repository-structure.md` — covers the manifest format decision (marketplace.json vs plugin.json) and directory layout. This doc complements it by covering how to document the structure and usage for contributors.
- `docs/plans/2026-06-22-002-feat-documentation-lifecycle-plan.md` — the implementation plan that produced the README documentation.
- `docs/plans/2026-06-22-003-research-plugin-cache-behavior-plan.md` — research on plugin caching that will enable the fix-cycle walkthrough (U3 of the documentation plan, currently blocked).
