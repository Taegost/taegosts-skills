---
title: "Architecture Patterns Index"
description: "Index of documentation in docs/solutions/architecture-patterns/."
status: active
version: "1.0"
created: 2026-09-08
last-updated: 2026-09-08
owner: wave-2-dispatch-index-automation
dependencies: []
tags: [index]
---

# Architecture Patterns Index

Index of documentation in docs/solutions/architecture-patterns/.

Paths below are relative to this index's directory. On Claude Code marketplace installs, resolve them through ${CLAUDE_PLUGIN_ROOT}/<repo-relative-path>; on other platforms, resolve from the loaded skill directory or the taegosts-skills checkout.

| Link | Description |
|------|-------------|
| [review-orchestrator-token-reduction.md](./review-orchestrator-token-reduction.md) | The review-pipeline orchestrator skills carried large inline instruction bodies that were re-read into context on every invocation: `ts-code-review`'s per-invocation load measured ~15,002 words, an... |
