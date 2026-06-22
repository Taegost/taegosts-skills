---
title: "research: How does Claude Code plugin caching and reload work?"
type: feat
status: active
date: 2026-06-22
---

# Research: Plugin Cache and Reload Behavior

## Summary

Research how Claude Code's plugin system handles caching, reloading, and local development. The answers determine the fix-cycle workflow for the documentation plan (`docs/plans/2026-06-22-002-feat-documentation-lifecycle-plan.md`).

## What We Know

- Plugins are cached at `~/.claude/plugins/cache/<marketplace>/<plugin>/<hash-or-version>/`
- The cache is plain files — no `.git` directory
- Directory names are git commit hashes (e.g., `3e424e85eac8`) for `git`/`github` sources, version numbers (e.g., `3.11.2`) for tagged releases
- Skills are loaded from this cache, not from the original repo
- `.in_use` tracks active sessions via PID files
- The cache was created when the user ran `/plugin` and refreshed when they ran `/reload-plugins`

## Questions to Answer

1. **Does `/reload-plugins` re-clone from the source, or re-read from the existing cache?**
   - Test: edit a cached SKILL.md file, run `/reload-plugins`, check if the edit persists or gets overwritten
   - Test: push a change to the repo, run `/reload-plugins`, check if the cache updates

2. **Can the `git` source type point to a local file path?**
   - Test: change `settings.json` to use `"url": "file:///home/taegost/_ws/taegosts-skills.git"` or `"url": "/home/taegost/_ws/taegosts-skills"`, reload, see if it works
   - Alternative: check if a symlink from the cache to the local repo works

3. **What's the actual workflow for local skill development?**
   - Is there a `~/.claude/skills/` override that takes precedence over marketplace plugins?
   - Can you develop in `~/.claude/skills/` and then move the file to the repo when ready?

## How to Test

Start from the current state: `taegosts-skills` plugin is installed from `github` source, cached at `~/.claude/plugins/cache/taegosts-skills/taegosts-skills/3e424e85eac8/`.

## Expected Output

A short findings doc (or update to this plan) answering each question with evidence. The documentation plan's U3 (fix-cycle walkthrough) depends on these answers.

## Related

- `docs/plans/2026-06-22-002-feat-documentation-lifecycle-plan.md` — U3 is blocked on this research
- `STRATEGY.md` — "Contribution steps" metric (fewer steps = better)
