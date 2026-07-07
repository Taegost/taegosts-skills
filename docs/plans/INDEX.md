---
tags: [index]
description: Index of documentation in docs/plans/.
---

# Plans Index

Index of documentation in docs/plans/.

| Link | Description |
|------|-------------|
| [2026-06-22-001-feat-import-skills-plugin-structure-plan.md](2026-06-22-001-feat-import-skills-plugin-structure-plan.md) | Import three existing skills (`pr-fix-findings`, `pr-review`, `verify-implementation`) into this repository using the Claude Code plugin directory structure, with a `marketplace.json` manifest and ... |
| [2026-06-22-002-feat-documentation-lifecycle-plan.md](2026-06-22-002-feat-documentation-lifecycle-plan.md) | Expand the README to cover the full lifecycle: how to install the plugin, how to use each skill, how to contribute changes, and the fix cycle (discovering a skill needs a fix → fixing it → getting ... |
| [2026-06-22-003-research-plugin-cache-behavior-plan.md](2026-06-22-003-research-plugin-cache-behavior-plan.md) | Research how Claude Code's plugin system handles caching, reloading, and local development. The answers determine the fix-cycle workflow for the documentation plan (`docs/plans/2026-06-22-002-feat-... |
| [2026-06-25-001-feat-script-extraction-pass-plan.md](2026-06-25-001-feat-script-extraction-pass-plan.md) | Convert repeatable mechanical steps across all skills into single-use helper scripts organized in two tiers: shared utilities (repo root) and skill-specific scripts (per-skill). Scripts consume zer... |
| [2026-06-26-001-feat-pr-workflow-improvements-plan.md](2026-06-26-001-feat-pr-workflow-improvements-plan.md) | - **#13**: Persistent clone with auto-sync script - **#7**: Accept `owner/repo` argument in pr-fix-findings skill - **#10**: Use Kanban board as working memory during PR fixes |
| [2026-06-26-001-feat-script-pr-review-pipeline-plan.md](2026-06-26-001-feat-script-pr-review-pipeline-plan.md) | The PR review workflow (`/pr-review`) currently relies on the LLM running ad-hoc `gh` commands inline, building JSON payloads by hand, and re-implementing logic that already exists in helper script... |
| [2026-07-01-001-chore-rename-skills-ts-prefix-plan.md](2026-07-01-001-chore-rename-skills-ts-prefix-plan.md) | Rename all 13 skill directories and their references to use a `ts-` prefix (replacing `ce-` for the 9 prefixed skills, prepending `ts-` for the 4 unprefixed ones). Update all cross-references, runt... |
| [2026-07-02-001-fix-ts-doc-review-script-hardening-plan.md](2026-07-02-001-fix-ts-doc-review-script-hardening-plan.md) | **Status: COMPLETED** — all implementation units merged in PR #70 (commit 9080e17). |
| [2026-07-02-002-fix-test-suite-hardening-plan.md](2026-07-02-002-fix-test-suite-hardening-plan.md) | Fix shell test defects across the test suite: unguarded `cd` calls, missing exit-code assertions on error paths, and broken cleanup traps. Also remove stale `ce-` prefixed and other pre-rename skil... |
| [2026-07-02-003-fix-pr-work-script-hardening-plan.md](2026-07-02-003-fix-pr-work-script-hardening-plan.md) | Security and quality hardening for six scripts across four skill families: `ts-pr-fix-findings`, `ts-plan`, `ts-work`, and `ts-verify-implementation`. Covers input validation, path traversal preven... |
| [2026-07-02-004-fix-review-skills-plan-validation-plan.md](2026-07-02-004-fix-review-skills-plan-validation-plan.md) | Skills `ts-work`, `ts-verify-implementation`, and `ts-pr-fix-findings` fail to validate implementations against the feature plan's KTD specifications at the literal level. This plan addresses the r... |
| [2026-07-02-004-review-walkthrough-decisions.md](2026-07-02-004-review-walkthrough-decisions.md) | Review date: 2026-07-03 Document: `docs/plans/2026-07-02-004-fix-review-skills-plan-validation-plan.md` |
| [2026-07-04-001-feat-agent-profiles-standardization-plan.md](2026-07-04-001-feat-agent-profiles-standardization-plan.md) | Standardize agent/persona definitions across all taegosts-skills into a uniform agent profile format. Migrates 21 persona files from `references/personas/` to `references/agents/`, adds YAML frontm... |
| [2026-07-04-002-feat-pr-fix-findings-verification-loop-plan.md](2026-07-04-002-feat-pr-fix-findings-verification-loop-plan.md) | After `ts-pr-fix-findings` fixes PR review findings, it has two verification gaps: (1) Step 6 lets implementers skip resolution checking when a fix diverges from the reviewer's approach, so fixes c... |
| [2026-07-04-003-feat-wave-1-foundation-critical-fixes-plan.md](2026-07-04-003-feat-wave-1-foundation-critical-fixes-plan.md) | Establish foundational documentation standards (link conventions, index standards, script frontmatter), update all relevant existing files to comply, and fix critical bugs in ts-verify-implementati... |
| [2026-07-05-001-feat-test-coverage-token-efficiency-plan.md](2026-07-05-001-feat-test-coverage-token-efficiency-plan.md) | Close the test-coverage blind spot where changed scripts ship without automated tests (Issue 102), reduce token consumption in ts-plan and ts-doc-review by standardizing subagent dispatch and restr... |
| [2026-07-05-001-feat-wave-2-script-extraction-index-infrastructure-plan.md](2026-07-05-001-feat-wave-2-script-extraction-index-infrastructure-plan.md) | Extract inline scripts from six skills into reusable script files, build automated index infrastructure (index-scripts.py, update-indexes.py, ROUTING.md), unify the dispatch pattern to Bootstrap ac... |
