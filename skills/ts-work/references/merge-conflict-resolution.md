# Merge Conflict Resolution (Triage-First)

Read this reference when a merge or rebase produces conflicts during Phase 2 execution. It replaces file-by-file, read-then-edit conflict resolution with a scan-first workflow that classifies every conflict before touching any of them.

## Why This Exists

Resolving conflicts one file at a time — reading each conflicted file in full, then making individual edits per conflict marker — turns a mechanical operation into a slow one. A rename-style merge (main picked up unrelated changes to files this branch also touched) is usually 80%+ mechanical: the same kind of conflict repeated across many files. Treating every file as if it needs a fresh read discards that pattern.

**Target:** conflict resolution for a mechanical merge (renames, frontmatter drift, description updates) completes in under 10 tool calls, not one read-and-edit pair per conflicted file.

## The Workflow

### 1. Scan before touching anything

```bash
git merge origin/main --no-commit --no-ff 2>&1 | grep "CONFLICT"
```

This lists every conflicted file in one call. Do not open any of them yet.

### 2. Classify with grep, not Read

For each conflicted file, use `grep` to see the conflict shape without loading the whole file:

```bash
for f in <conflicted files>; do
  echo "=== $f ==="
  grep -c "<<<<<<<" "$f"
  grep -A2 "<<<<<<<" "$f"
done
```

`grep -A2` after the conflict marker is almost always enough to classify the conflict. Sort files into three buckets:

- **Frontmatter-only conflict** (e.g., `name:`/`description:` fields, YAML metadata) — mechanical, batch-resolvable with `sed`.
- **New file from main** — the conflict is really "this file doesn't exist on our side" — resolve with `git checkout origin/main -- <path>` (plus a rename if applicable), not a content merge.
- **Content or logic conflict** — the two sides changed overlapping code or prose in ways `grep -A2` can't fully disambiguate. This bucket needs a real read.

### 3. Batch-resolve the mechanical buckets first

Frontmatter-only conflicts across multiple files share the same shape — resolve them with one `sed` pass instead of N individual edits. For a rename-style merge where the pattern is "keep our identifier, take main's improved description":

```bash
sed -i '/^<<<<<<< /,/^>>>>>>> /{ /^name:/s/old-prefix-/new-prefix-/g; /^description:/s/old-prefix-/new-prefix-/g }' <files>
```

Adapt the pattern to the actual conflict shape found in step 2 — the point is one command covering every file with the same shape, not a template to copy verbatim. "New file from main" entries resolve with `git checkout origin/main -- <path>` and a rename where needed, not a diff read.

### 4. Deep-read only the ambiguous remainder

Only the **content or logic conflict** bucket from step 2 gets a full `Read` + individual `Edit`. This should be a small minority of the total conflict count on a mechanical merge — if most files are landing in this bucket, the merge probably isn't mechanical and triage won't compress it much; resolve those the normal way.

### 5. Commit

```bash
git add -A && git commit
```

## Anti-Patterns to Avoid

- **Don't read conflict markers when `grep` already showed you the context.** `grep -A2 "<<<<<<<" <file>` gives enough to decide "batch-resolve" or "needs reading" — a full `Read` on a file already classified as mechanical is wasted.
- **Don't do individual `Edit` calls for pattern-replaceable conflicts.** If several files share the same conflict shape, one `sed` pass beats one `Edit` per file.
- **Don't re-read a file after an `Edit` error unless the error indicates content drift.** "File has been modified since read" needs a re-read. "File has not been read yet" just needs a read first — it does not mean the whole triage was wrong.
- **Don't skip the scan step because the merge "looks simple."** The scan is one command; skipping it to save a call is how file-by-file resolution creeps back in.

## Acceptance Bar

- The agent scans all conflicts (step 1-2) before resolving any of them.
- Frontmatter-only and new-file-from-main conflicts are batch-resolved, not individually edited.
- No conflicted file is read before its conflict type is classified via `grep`.
- A mechanical rename-style merge completes in under 10 tool calls.
