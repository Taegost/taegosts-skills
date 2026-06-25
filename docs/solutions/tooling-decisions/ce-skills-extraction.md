---
title: "CE Skills Extraction — Customizing Compound Engineering for Homelab Workflow"
date: 2026-06-25
category: tooling-decisions
module: homelab
problem_type: tooling_decision
tags: [compound-engineering, claude-code, skills, extraction, customization]
---

# CE Skills Extraction

## Context

The [Compound Engineering plugin](https://github.com/EveryInc/compound-engineering-plugin) (EveryInc) ships 25+ skills for Claude Code. Mike's homelab-k8s workflow uses 9 of them. The plugin has gaps that cause friction during implementation (documented in 10 findings from the Honcho deployment). Rather than building wrappers around a third-party plugin, the 9 relevant skills are extracted into this repo for direct ownership and customization.

## Skills Extracted

| Skill | Lines (with deps) | Purpose |
|-------|-------------------|---------|
| ce-plan | ~4,448 | Planning and architecture |
| ce-compound | ~3,495 | Solution documentation capture |
| ce-code-review | ~2,982 | Code review with dynamic personas |
| ce-brainstorm | ~2,541 | Requirements brainstorming |
| ce-doc-review | ~2,095 | Document review with persona lenses |
| ce-work | ~974 | Plan execution and implementation |
| ce-debug | ~752 | Debugging workflow |
| ce-commit-push-pr | ~304 | Commit + PR creation |
| ce-commit | ~105 | Commit workflow |

**Total:** ~17,700 lines across ~90 files.

## What Was Removed


### Personas (ce-code-review)

- `swift-ios-reviewer.md` — iOS/Swift specific, not relevant to DevOps/k8s
- `julik-frontend-races-reviewer.md` — Frontend race conditions
- `agent-native-reviewer.md` — Claude Code meta-reviewer


### Agents (ce-plan, ce-brainstorm)

- `slack-researcher.md` — No Slack integration in this workflow
- `agent-native-planning-strategist.md` — Platform meta-agent


### Scripts (ce-brainstorm, ce-compound)

- `visual-probe-server.js` + `visual-probes.md` — Node.js visual probe server (optional)
- `session-historian.md` — Session history scripts, Claude Code specific


## Dependency Chain


```text
ce-brainstorm → ce-plan → ce-work → ce-code-review
                                      → ce-commit
                                      → ce-commit-push-pr
                ce-doc-review ↗ (headless review)
                ce-compound (standalone)
                ce-debug (standalone)
```

## Motivating Findings (10 gaps from Honcho deployment)

| # | Finding | Skill | Status |
|---|---------|-------|--------|
| 1 | ce-work doesn't cross-check plans against repo conventions | ce-work | Pending PR 2 |
| 2 | ce-work doesn't detect missing convention artifacts | ce-work | Pending PR 2 |
| 3 | ce-work doesn't validate against pre-commit proactively | ce-work | Pending PR 2 |
| 4 | verify-implementation conflates missing with awaiting manual step | verify-implementation | Pending PR 5 |
| 5 | verify-implementation subagents run stale context on re-verification | verify-implementation | Pending PR 5 |
| 6 | doc-review missed domain-specific security/networking issues | ce-doc-review | Pending PR 3 |
| 7 | ce-compound Solution Extractor created file (violates contract) | ce-compound | Pending PR 4 |
| 8 | No mechanism to detect plan-vs-convention conflicts during doc-review | ce-doc-review | Pending PR 3 |
| 9 | pr-fix-findings doesn't fetch issue-level comments | pr-fix-findings | Pending PR 5 |
| 10 | pr-fix-findings doesn't check conversation resolution status | pr-fix-findings | Pending PR 5 |

## Source

- Upstream: https://github.com/everyinc/compound-engineering-plugin
- Motivating plan: https://github.com/Taegost/homelab-k8s/blob/main/docs/plans/2026-06-23-006-chore-skill-improvements-from-honcho-deployment.md
