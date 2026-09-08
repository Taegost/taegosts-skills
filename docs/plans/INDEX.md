---
title: "Plans Index"
description: "Index of documentation in docs/plans/."
status: active
version: "1.0"
created: 2026-07-08
last-updated: 2026-09-08
owner: wave-2-dispatch-index-automation
dependencies: []
tags: [index]
---

# Plans Index

Index of documentation in docs/plans/.

Paths below are relative to this index's directory. On Claude Code marketplace installs, resolve them through ${CLAUDE_PLUGIN_ROOT}/<repo-relative-path>; on other platforms, resolve from the loaded skill directory or the taegosts-skills checkout.

| Link | Description |
|------|-------------|
| [2026-09-07-001-fix-plugin-script-resolution-plan.md](./2026-09-07-001-fix-plugin-script-resolution-plan.md) | Marketplace-installed skills fail to find the shared `scripts/` tier (and most skill-local scripts) because every skill invokes them with bare CWD-relative paths. The Bash tool's CWD at skill-execu... |
| [2026-09-08-001-fix-repo-hygiene-gates-ci-plan.md](./2026-09-08-001-fix-repo-hygiene-gates-ci-plan.md) | Fix the `scripts/verify-scripts.sh` gate's two design gaps (tests/ scanning, missing library category), rename the four dash-named Python test suites — one also converted to pytest idiom — so bare ... |
| [2026-09-08-002-feat-review-pipeline-token-reduction-plan.md](./2026-09-08-002-feat-review-pipeline-token-reduction-plan.md) | Cut orchestrator token consumption across the PR-review pipeline so `/ts-pr-review` runs complete without session compaction. Three levers, all following the pattern issue #103 / PR #112 already ap... |
