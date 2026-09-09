---
title: "Scripts Index"
description: "Index of all scripts in scripts/."
status: active
version: "1.0"
created: 2026-07-08
last-updated: 2026-09-09
owner: wave-2-dispatch-index-automation
dependencies: []
tags: [index, scripts]
---

# Scripts Index

Index of all scripts in scripts/.

Paths below are relative to this index's directory. On Claude Code marketplace installs, resolve them through ${CLAUDE_PLUGIN_ROOT}/<repo-relative-path>; on other platforms, resolve from the loaded skill directory or the taegosts-skills checkout.

| Link | Description |
|------|-------------|
| [build-pr-body.sh](./build-pr-body.sh) | Build a formatted PR body from a plan file |
| [classify-document.sh](./classify-document.sh) | Detect document type from content signals |
| [context-gather.sh](./context-gather.sh) | Gather git context as JSON (branch, commits, status, unpushed) |
| [default-branch.sh](./default-branch.sh) | Resolve the default branch using cascading fallbacks |
| [detect-changed-code-files.sh](./detect-changed-code-files.sh) | Return list of modified code-bearing files. |
| [detect-coverage-gaps.sh](./detect-coverage-gaps.sh) | Flag changed scripts without corresponding test files. |
| [detect-diff-scope.sh](./detect-diff-scope.sh) | Compute diff scope and detect which reviewers apply |
| [extract-ktds.py](./extract-ktds.py) | Extract Key Technical Decisions (KTDs) from plan markdown files. |
| [gh-get-pr-state.sh](./gh-get-pr-state.sh) | Fetch PR state from GitHub CLI as JSON |
| [git-context.sh](./git-context.sh) | Produce a unified git state snapshot as JSON |
| [git-default-branch.sh](./git-default-branch.sh) | Resolve repo root and default branch. |
| [index-scripts.py](./index-scripts.py) | Generate INDEX.md files for script directories. |
| [lib/index_common.py](./lib/index_common.py) | Shared helpers for the INDEX.md generators. |
| [lib/input-validation.sh](./lib/input-validation.sh) | Provide sourceable validation helpers for GitHub API interactions (metacharacter checks, gh CLI/auth checks, format validators) |
| [load-dispatch-standards.sh](./load-dispatch-standards.sh) | Sourceable validation library for dispatch pattern standards |
| [locate-plan.py](./locate-plan.py) | Non-interactive plan location script. |
| [pr-metadata.sh](./pr-metadata.sh) | Fetch PR metadata from GitHub API as JSON |
| [request-reviews.sh](./request-reviews.sh) | Request or re-request reviews on a GitHub PR |
| [run-bundled-validator.sh](./run-bundled-validator.sh) | Resolve and run a skill's bundled validator script, or report it unavailable |
| [run-id.sh](./run-id.sh) | Generate a timestamp-hex run ID |
| [run-shellcheck.sh](./run-shellcheck.sh) | Run shellcheck on all shell scripts in the repository |
| [run-test-suites.sh](./run-test-suites.sh) | Run every bash test suite and bats file, aggregating failures |
| [solutions-search.sh](./solutions-search.sh) | Search docs/solutions/ for matching conventions |
| [sync-taegosts-skills.sh](./sync-taegosts-skills.sh) | Maintain a persistent clone and sync taegosts-skills |
| [to-json.sh](./to-json.sh) | Safe JSON output for bash scripts |
| [update-indexes.py](./update-indexes.py) | Generate INDEX.md files for documentation directories. |
| [validate-findings-json.sh](./validate-findings-json.sh) | Validate findings JSON has required fields |
| [validate-index-standards.py](./validate-index-standards.py) | Validate R7/R8 compliance for documentation files. |
| [verify-fix.sh](./verify-fix.sh) | Confirm that a file edit actually landed |
| [verify-ktd-literal.py](./verify-ktd-literal.py) | Verify whether a [literal] KTD specification appears in a target file. |
| [verify-script-refs.sh](./verify-script-refs.sh) | Detect unguarded runtime script invocations in skill markdown |
| [verify-scripts.sh](./verify-scripts.sh) | Pre-commit gate for scripts |
| [wait-for-file.sh](./wait-for-file.sh) | Poll for file existence. |
