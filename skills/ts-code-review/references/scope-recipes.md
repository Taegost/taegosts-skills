# Stage 1 Scope Recipes

Loaded on demand by `SKILL.md` — read the recipe matching the argument form that fired. Currently this file carries the branch-name-argument path; the `base:`, PR number/URL, and standalone paths stay inline in `SKILL.md` Stage 1.

## Branch name argument

Substitute the provided branch name as `<branch>`. Do **not** check out `<branch>`.

If `git rev-parse --abbrev-ref HEAD` equals `<branch>`, use the **standalone (current branch)** path in `SKILL.md` Stage 1 — same tree, explicit branch name; do not use remote-only diff.

**Ref quoting:** `<branch>`, `<branch-ref>`, and base refs are passed as separate, quoted argv tokens to every `gh`/`git` command — e.g. `git merge-base "$BASE" "$branch_ref"` — never interpolated into an unquoted shell string.

Otherwise diff the remote/local ref **without checkout**:

1. Try `gh pr view "$branch" --json baseRefName,url,headRefName` — if a PR exists, prefer the **PR number/URL path** in `SKILL.md` Stage 1 (same remote diff rules).
2. Else fetch first — `git fetch --no-tags origin "$branch"` — **before** selecting `<branch-ref>`, then resolve `<branch-ref>` as `origin/<branch>` when the fetch succeeds, falling back to the local `<branch>` ref when it fails. Resolving an already-existing `origin/<branch>` without fetching first can diff a stale ref that omits the branch's current commits.
3. Resolve default base branch (same logic as the standalone path in `SKILL.md`). Compute `BASE=$(git merge-base "$base_ref" "$branch_ref")` and `git diff -U10 "$BASE" "$branch_ref"`.
4. If `<branch-ref>` cannot be resolved locally, stop: "Cannot diff branch `<branch>` without checkout. Check out that branch, pass its open PR URL/number, or review the current branch with `base:`."

On success for remote branch diff, set **branch-remote scope**. The working tree is **not** `<branch>`. Include `<pr-scope-mode>branch-remote</pr-scope-mode>` and `<branch-head-ref><branch-ref></branch-head-ref>` in the Stage 4 review context bundle. Reviewers and Stage 5b validators must **not** Read/Grep workspace paths for files in `FILES:`. Inspect via `git show <branch-ref>:<path>` or diff hunks only.

Produce:

```
echo "BASE:$BASE" && echo "FILES:" && git diff --name-only "$BASE" "$branch_ref" && echo "DIFF:" && git diff -U10 "$BASE" "$branch_ref" && echo "UNTRACKED:" && git ls-files --others --exclude-standard
```
