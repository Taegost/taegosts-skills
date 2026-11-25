---
title: "Git filter-branch --msg-filter is broken in sandboxed shells"
date: 2026-11-24
category: docs/solutions/workflow-issues
module: environment/shell
problem_type: workflow_issue
component: tooling
severity: medium
applies_when:
  - "Running `git filter-branch --msg-filter` (or any stdin-consuming filter) inside a sandboxed Bash tool"
  - "Recovering a branch after a history rewrite produced empty or mangled commit messages"
tags:
  - git
  - filter-branch
  - sandbox
  - history-rewrite
  - recovery
---

# Git filter-branch --msg-filter is broken in sandboxed shells

## Context

A commit-message rewrite in this repository used `git filter-branch --msg-filter` inside the sandboxed Bash environment. The filter never received the commit message on stdin, so the rewrite produced empty commit messages and mangled subjects across the rewritten history. The recovery had to preserve uncommitted user files sitting in the working tree, which ruled out the obvious `git reset --hard` escape hatch.

## Guidance

Treat `--msg-filter` as broken in sandboxed Bash; rebuild with `git commit -F` instead.

Recovery that preserved uncommitted user files:

1. Abandon the rewritten branch tip without touching the working tree: `git reset --keep refs/original/refs/heads/<branch>` — `--keep`, not `--hard`, because `--hard` discards uncommitted user files.
2. Rebuild sequentially: for each original commit, `git cherry-pick -n <commit>` (no commit) followed by `git commit -F <msgfile>` with the corrected message in a file.
3. Guard each rebuild against the duplicated `Co-Authored-By` trailer — a message file that already carries the trailer plus an appending commit template produces it twice.

## Why This Matters

`--msg-filter` depends on stdin delivery into the filter command. The sandboxed Bash tool breaks that channel, so the filter silently runs against empty input: every rewritten commit loses its message body and the subjects come out mangled. The failure is silent at rewrite time and only visible afterward, when the history is already rewritten — which makes the recovery procedure (and the `--keep` over `--hard` choice that protects uncommitted work) the difference between a clean rebuild and destroyed working-tree state.

## When to Apply

- A history rewrite needs new commit messages in a sandboxed shell → use the sequential rebuild (`git cherry-pick -n` + `git commit -F <msgfile>`), never `--msg-filter`.
- Undoing a completed `filter-branch` rewrite with a dirty working tree → `git reset --keep refs/original/refs/heads/<branch>`, never `--hard`.
- Any filter variant that reads stdin (`--env-filter`, `--tree-filter` with stdin-reading commands) → assume the same sandbox breakage and verify on one commit before rewriting the branch.

## Examples

The failure, as observed:

```text
git filter-branch --msg-filter '...' -- <range>
# result: empty commit messages (msg-filter stdin broken), mangled subjects
```

The rebuild, per commit:

```bash
git reset --keep refs/original/refs/heads/<branch>
git cherry-pick -n <commit>
git commit -F <msgfile>   # corrected message; watch for duplicated Co-Authored-By trailer
```

## Related

- [Centralized gloss rule and D-entry emission across ts-doc-review surfaces](../architecture-patterns/doc-review-gloss-rule-dentry-emission.md) — the solution doc this learning was extracted from during PR 229 review, where the cautionary example sat off-topic in its Examples section
