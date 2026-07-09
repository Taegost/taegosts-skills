# Merge Conflict Resolution (Triage-First)

Read this reference when a merge or rebase produces conflicts during Phase 2 execution. It replaces file-by-file, read-then-edit conflict resolution with a scan-first workflow that classifies *which side should win* before touching any conflict — speed is a consequence of getting that classification right in bulk, not a goal to chase by skipping it.

## Why This Exists

Resolving conflicts one file at a time — reading each conflicted file in full, then making individual edits per conflict marker — turns a mechanical operation into a slow one. But the risk cuts both ways: bulk-applying a resolution *pattern* without first confirming which side is actually correct is how a merge silently loses real work. Triage is not "find a plausible-looking edit and repeat it" — it is "determine the correct resolution for one representative conflict, confirm it generalizes, then apply it in bulk."

**Target:** conflict resolution for a mechanical merge (one side's changes are superseded or irrelevant across many files) completes in under 10 tool calls — not one read-and-edit pair per conflicted file, and not a bulk edit applied without verifying it's correct.

## The Workflow

### 1. Scan before touching anything

```bash
git merge origin/main --no-commit --no-ff 2>&1 | grep "CONFLICT"
```

This lists every conflicted file in one call. Do not open any of them yet.

### 2. Classify by which side should win, not just by shape

For each conflicted file, look at enough of the conflict to see **both** sides — `grep -A2` after the opening marker often only shows part of "ours" and misses the `=======` divider and "theirs" entirely, which isn't enough to judge who should win:

```bash
for f in <conflicted files>; do
  echo "=== $f ==="
  grep -c "<<<<<<<" "$f"
  awk '/<<<<<<</,/>>>>>>>/' "$f"
done
```

Sort files into buckets by **resolution strategy**, not just by surface shape:

- **Ours wins wholesale** — main's conflicting change is superseded, already incorporated in a different form on this branch, or otherwise irrelevant to what this branch did (e.g., main tweaked content this branch already restructured as part of a larger rename). Resolve with `git checkout --ours -- <path>`.
- **Theirs wins wholesale** — the reverse: this branch's local edit to the conflicting hunk was incidental and main's version is the one that should survive. Resolve with `git checkout --theirs -- <path>`.
- **New file from main, no conflict in content** — the file doesn't exist on this branch at all; there's nothing to compare. Resolve with `git checkout origin/main -- <path>` (plus a rename if this branch's naming convention requires it).
- **Both sides must survive** — the two sides changed genuinely independent things (e.g., this branch renamed an identifier, main improved unrelated prose in the same block) and the correct result keeps pieces of both. This is the only bucket where a content-blending edit (sed pattern or manual edit) is appropriate — see step 3b.
- **Incompatible changes to the same logic/content** — the two sides made conflicting substantive changes to the same thing and neither simply wins. Needs a real read; do not force this into one of the buckets above.

**Do not default to "both sides must survive."** Reaching for a hand-built blend is more error-prone than selecting a side that's already known-correct — it fabricates new content via pattern-matching instead of choosing between two states that already exist and are each internally consistent. Prefer "ours wins" / "theirs wins" whenever the conflict is really about one side's change being moot, even if a blend *could* technically be constructed.

### 3a. Verify the classification on a sample before bulk-applying it

Before running `git checkout --ours`/`--theirs` across every file in a bucket, pick 2-3 representative files and confirm by diff that the discarded side genuinely has nothing worth keeping:

```bash
git diff HEAD:<path> origin/main:<path>
```

If the discarded side turns out to contain something unique (a fix, a detail this branch never touched), that file — and every other file you assumed shared its shape — needs re-classification, not a forced bulk resolution. Extrapolating "the first file was mechanical, so the rest probably are too" without checking is how a bulk resolution silently drops real changes.

### 3b. Apply per bucket

```bash
# Ours wins wholesale
git checkout --ours -- <files-in-this-bucket>

# Theirs wins wholesale
git checkout --theirs -- <files-in-this-bucket>

# New file from main
git checkout origin/main -- <path>

# Mark resolved once content is correct
git add <files>
```

Only reach for a `sed` content-blend in the "both sides must survive" bucket, and only after step 3a confirmed the shared shape across the bucket:

```bash
sed -i '/^<<<<<<< /,/^>>>>>>> /{ /^name:/s/old-prefix-/new-prefix-/g; /^description:/s/old-prefix-/new-prefix-/g }' <files>
```

Adapt the pattern to the actual conflict shape found in step 2 — this is not a template to copy verbatim, and it should be the exception, not the default tool.

### 4. Deep-read only the genuinely ambiguous remainder

Files landing in "incompatible changes to the same logic/content" get a full `Read` + individual `Edit`. This should be a small minority of the total conflict count on a mechanical merge — if most files land here, the merge isn't mechanical and triage won't compress it much; resolve those the normal way.

### 5. Commit

```bash
git add -A && git commit
```

## Anti-Patterns to Avoid

- **Don't classify by surface shape alone.** "This looks like a frontmatter conflict" is not the same question as "which side should win here" — answer the second question, not just the first.
- **Don't bulk-apply a resolution to a whole bucket without spot-checking a sample first (step 3a).** A pattern that looks uniform from one file's `grep` output can still hide a file where the discarded side has something real.
- **Don't reach for a content-blending `sed` pass as the default.** It's the right tool only when both sides must survive — check "ours wins" / "theirs wins" first, since selecting an already-correct side is safer than reconstructing one.
- **Don't re-read a file after an `Edit` error unless the error indicates content drift.** "File has been modified since read" needs a re-read. "File has not been read yet" just needs a read first — it does not mean the whole triage was wrong.
- **Don't skip the scan step because the merge "looks simple."** The scan is one command; skipping it to save a call is how file-by-file resolution creeps back in.

## Acceptance Bar

- The agent scans all conflicts (step 1) before resolving any of them.
- Every conflict is classified by which side should win, not just by surface shape.
- Before a bulk `--ours`/`--theirs`/sed resolution is applied to a bucket, at least one sample file's diff was checked to confirm nothing unique is being discarded.
- No conflicted file is force-fit into "ours wins" or "theirs wins" when it actually needs both sides or a real read.
- A mechanical merge (most conflicts resolve to one side winning wholesale) completes in under 10 tool calls.
