---
title: "Plans Index"
description: "Index of documentation in docs/plans/."
status: active
version: "1.0"
created: 2026-07-08
last-updated: 2026-11-24
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
| [2026-09-09-001-fix-repo-documentation-review-plan.md](./2026-09-09-001-fix-repo-documentation-review-plan.md) | Run a repo-wide documentation review for Issue #119: validate every documented standard, concept, and best practice against current reality; trust-classify every directive (external best-practice v... |
| [2026-10-05-001-split-ratification-csv-plan.md](./2026-10-05-001-split-ratification-csv-plan.md) | The issue #119 ratification workflow (branch `docs/119-repo-documentation-review`) needs `ratification-decisions.csv` (repo root, 761 rows) split into smaller per-audit-surface files under `resourc... |
| [2026-11-19-001-fix-doc-review-question-self-containment-plan.md](./2026-11-19-001-fix-doc-review-question-self-containment-plan.md) | Rewrite the ts-doc-review interactive walk-through so every blocking decision question carries the complete information needed to answer it: the full finding inside the per-finding question, findin... |
| [2026-11-24-001-fix-doc-review-gloss-dentry-plan.md](./2026-11-24-001-fix-doc-review-gloss-dentry-plan.md) | Close the two ts-doc-review failings filed from a real plan-review run: plan-item IDs reaching the user unglossed (#227), and plan edits landing without D-entries so decision rationale survives onl... |
| [ts-audhd-retrofit-instructions.md](./ts-audhd-retrofit-instructions.md) | **For:** a coding agent working in `taegost/taegosts-skills` (clone: https://github.com/taegost/taegosts-skills) **Skills touched:** `ts-plan`, `ts-doc-review` (primarily their SKILL.md and `refere... |
