---
title: "Workflow Issues Index"
description: "Index of documentation in docs/solutions/workflow-issues/."
status: active
version: "1.0"
created: 2026-07-08
last-updated: 2026-09-07
owner: wave-2-dispatch-index-automation
dependencies: []
tags: [index]
---

# Workflow Issues Index

Index of documentation in docs/solutions/workflow-issues/.

Paths below are relative to this index's directory. On Claude Code marketplace installs, resolve them through ${CLAUDE_PLUGIN_ROOT}/<repo-relative-path>; on other platforms, resolve from the loaded skill directory or the taegosts-skills checkout.

| Link | Description |
|------|-------------|
| [composition-over-generalization-for-verification.md](./composition-over-generalization-for-verification.md) | When adding verification to `ts-pr-fix-findings`, we needed to decide whether to generalize `ts-verify-implementation` to handle both use cases or to compose it as a sub-skill. The two skills have ... |
| [notification-resilience-via-disk-state.md](./notification-resilience-via-disk-state.md) | Background agent completions are lost ~40-50% of the time when the orchestrator is mid-generation. The harness-level notification (`<task-notification>`) is unreliable — it can be missed when the o... |
