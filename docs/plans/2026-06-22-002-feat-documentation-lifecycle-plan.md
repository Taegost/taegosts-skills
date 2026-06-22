---
title: "feat: Add install, usage, and contribution documentation"
type: feat
status: completed
date: 2026-06-22
---

# Add Install, Usage, and Contribution Documentation

## Summary

Expand the README to cover the full lifecycle: how to install the plugin, how to use each skill, how to contribute changes, and the fix cycle (discovering a skill needs a fix → fixing it → getting it into the repo). The current README covers installation and has a skills table but lacks usage examples, contribution workflow, and the fix-cycle walkthrough.

## Problem Frame

The README currently explains *what* the plugin contains and *how to install* it, but not *how to use* each skill or *how to contribute* changes. A user who installs the plugin and wants to use `/pr-review` has no guidance beyond the skill's own SKILL.md. A contributor who finds a bug in a skill has no documented path from "I found the issue" to "the fix is merged."

## Requirements

- R1. README includes usage examples for each skill (invocation patterns, what to expect).
- R2. README includes a contribution workflow section (fork, branch, PR, testing).
- R3. README includes a fix-cycle walkthrough: "I'm using a skill and it breaks" → find the source → edit in the repo → test via `/reload-plugins` → PR.
- R4. README includes a repo structure explanation so contributors understand where things live.
- R5. README includes instructions for adding a new skill (not just fixing existing ones).
- R6. Installation section can be modified if the documentation work reveals it needs improvement.

## Key Technical Decisions

**All documentation lives in the README.** The repo is small enough that splitting into multiple docs (CONTRIBUTING.md, USAGE.md) adds navigation overhead without benefit. A single README that flows from install → use → contribute → structure keeps everything discoverable in one place.

**Fix-cycle walkthrough depends on unresolved research.** The actual fix cycle is unknown until we understand how the plugin cache and `/reload-plugins` work. Key questions (see `docs/plans/2026-06-22-003-research-plugin-cache-behavior-plan.md`):
- Does `/reload-plugins` re-clone from the source, or re-read from the existing cache?
- Can the `git` source type point to a local file path?
- If not, what's the actual workflow for testing a fix before pushing?

The fix-cycle documentation cannot be written until these are answered. The rest of the plan (usage, contributing, structure, add-new-skill) can proceed independently.

**No formal versioning in this pass.** The repo is small and personal enough that versioning adds overhead without clear benefit. Deferred to future work if the repo grows beyond a handful of contributors.

## Implementation Units

### U1. Add usage section with per-skill examples

- **Goal:** Users can invoke each skill after reading the README.
- **Requirements:** R1
- **Dependencies:** None
- **Files:** `README.md`
- **Approach:** Add a `## Usage` section after the Skills table. For each skill, include: invocation syntax, what it does (1-2 sentences), and a brief example of expected output or behavior. Keep examples minimal — the skill's own SKILL.md is the detailed reference.
- **Test expectation:** none — documentation only.
- **Verification:** Each skill has a usage entry with invocation syntax and expected behavior.

### U2. Add contribution workflow section

- **Goal:** Contributors know how to fork, branch, make changes, and submit a PR — including adding new skills, not just fixing existing ones.
- **Requirements:** R2, R5
- **Dependencies:** None
- **Files:** `README.md`
- **Approach:** Add a `## Contributing` section covering:
  - Fork the repo, create a feature branch
  - For fixing existing skills: edit `skills/<skill-name>/SKILL.md`, test via `/reload-plugins`
  - For adding new skills: create `skills/<new-skill>/SKILL.md` with the required frontmatter (`name`, `description`, `user_invocable: true`), test via `/reload-plugins`
  - Commit with conventional messages, push and open a PR
  Keep it concise — this is a small plugin repo, not a large project with complex CI.
- **Test expectation:** none — documentation only.
- **Verification:** Section covers both fix and add-new-skill workflows.

### U3. Add fix-cycle walkthrough

- **Goal:** Users who discover a skill issue have a documented path from discovery to merged fix.
- **Requirements:** R3
- **Dependencies:** U2, **blocked by** `docs/plans/2026-06-22-003-research-plugin-cache-behavior-plan.md` (must complete first)
- **Files:** `README.md`
- **Approach:** Add a `## Fix Cycle` subsection under Contributing. Walk through the real workflow starting from the user's experience. The exact steps depend on the cache/reload research — the walkthrough must accurately describe where edits happen (repo vs cache), how to test, and how changes flow back into version control.
- **Test expectation:** none — documentation only.
- **Verification:** Walkthrough starts from user experience, accurately describes the edit-test-push cycle based on verified cache behavior.

### U4. Add repo structure explanation

- **Goal:** Contributors understand where skills live and how the plugin manifest works.
- **Requirements:** R4
- **Dependencies:** None
- **Files:** `README.md`
- **Approach:** Add a `## Repository Structure` section with a directory tree showing `.claude-plugin/marketplace.json`, `skills/<name>/SKILL.md`, and `docs/`. Brief explanation of each: marketplace.json is the plugin manifest, skills/ holds the skill definitions, docs/ holds brainstorms, plans, and solutions.
- **Test expectation:** none — documentation only.
- **Verification:** Directory tree matches actual repo structure, each entry has a one-line explanation.

## Scope Boundaries

- No changes to skill content (SKILL.md files).
- No new files beyond README.md modifications.
- No CI/CD or automated testing.
- Installation section can be modified if the documentation work reveals it needs improvement (e.g., clarifying where the repo lives on disk for the fix cycle).
- Formal versioning (changelog, version bumps) is deferred — the repo is small enough that git history serves as the changelog for now.
