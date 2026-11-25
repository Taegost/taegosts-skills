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

Recovery that preserves uncommitted user files. The sequence matters: cherry-picking a commit that already sits at HEAD yields an empty pick, so the rebuild must start below the commits being rewritten:

1. Save the original tip under a stable name: `git branch msgfix-source refs/original/refs/heads/<branch>`. Every later cherry-pick names its commit from this ref, never from the branch itself.
2. Record any staged selection before resetting — `reset --keep` resets the index, so a partially staged file keeps its content in the working tree but loses what was staged. A local change to a file that differs between HEAD and the reset target aborts the reset outright (a safe outcome — nothing moves, the staged selection survives). Save `git diff --cached --name-only` (and per-file `git diff --cached` where partial staging matters) and re-stage from it after the rebuild.
3. Move the branch below the range to rewrite without touching the working tree: `git reset --keep msgfix-source~<n>` — `--keep`, not `--hard`, because `--hard` discards uncommitted user files.
4. Rebuild sequentially: for each original commit, oldest first, `git cherry-pick -n msgfix-source~<k>` (no commit, commit named from the source ref) followed by `git commit -F <msgfile>` with the corrected message in a file.
5. Guard each rebuild against the duplicated `Co-Authored-By` trailer — a message file that already carries the trailer plus an appending commit template produces it twice.

Two applicability limits:

- Linear history only: `git cherry-pick -n` on a merge commit fails without a `-m <mainline>` flag, and adding the mainline flattens the merge instead of preserving its parents. When the rewritten range contains merges, stop and use a merge-preserving rebuild method for those commits instead of this procedure.
- Uncommitted overlap: if an uncommitted user change touches a file a replayed commit also modifies, the cherry-pick stops to protect that change. Run the rebuild in an isolated worktree (`git worktree add`) or temporarily shelve the overlapping change, then restore it afterwards.

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
git branch msgfix-source refs/original/refs/heads/<branch>
git diff --cached --name-only > /tmp/staged.txt   # reset --keep clears staged selections
git reset --keep msgfix-source~<n>                # --keep, never --hard: preserves uncommitted files
git cherry-pick -n msgfix-source~<k>              # commit from the source ref, oldest first
git commit -F <msgfile>   # corrected message; watch for duplicated Co-Authored-By trailer
git add $(cat /tmp/staged.txt)   # restore the recorded staged selection (per-file diffs for partial staging)
```

## Related

- [Centralized gloss rule and D-entry emission across ts-doc-review surfaces](../architecture-patterns/doc-review-gloss-rule-dentry-emission.md) — the solution doc this learning was extracted from during PR 229 review, where the cautionary example sat off-topic in its Examples section
