# Merge Conflict Resolution (Triage-First)

Read this reference when a merge or rebase produces conflicts during Phase 2 execution. It replaces file-by-file, read-then-edit conflict resolution with a scan-first workflow that classifies *which side should win* before touching any conflict — speed is a consequence of getting that classification right in bulk, not a goal to chase by skipping it.

## Why This Exists

Resolving conflicts one file at a time — reading each conflicted file in full, then making individual edits per conflict marker — turns a mechanical operation into a slow one. But the risk cuts both ways: bulk-applying a resolution *pattern* without first confirming it's correct is how a merge silently loses real work or produces a subtly wrong blend. Triage is not "find a plausible-looking edit and repeat it" — it is "determine the correct resolution for one representative conflict, confirm it generalizes, then apply it in bulk."

**Target:** conflict resolution for a mechanical merge (most conflicts resolve the same way across many files) completes in under 10 tool calls — not one read-and-edit pair per conflicted file, and not a bulk edit applied without verifying it's correct.

## The Workflow

### 1. Scan before touching anything

```bash
git merge origin/main --no-commit --no-ff 2>&1 | grep "CONFLICT"
```

This lists every conflicted file in one call. Do not open any of them yet.

### 2. Classify by resolution strategy, not just by shape

For each conflicted file, look at enough of the conflict to see **both** sides — `grep -A2` after the opening marker often only shows part of "ours" and misses the `=======` divider and "theirs" entirely, which isn't enough to classify correctly:

```bash
for f in <conflicted files>; do
  echo "=== $f ==="
  grep -c "<<<<<<<" "$f"
  awk '/<<<<<<</,/>>>>>>>/' "$f"
done
```

Sort files into buckets by **resolution strategy**:

- **Ours wins wholesale** — main's conflicting change is superseded, already incorporated in a different form on this branch, or otherwise irrelevant to what this branch did. Resolve with `git checkout --ours -- <path>`.
- **Theirs wins wholesale** — the reverse: this branch's local edit to the conflicting hunk was incidental and main's version is the one that should survive. Resolve with `git checkout --theirs -- <path>`.
- **New file from main, no conflict in content** — the file doesn't exist on this branch at all; there's nothing to compare. Resolve with `git checkout origin/main -- <path>` (plus a rename if this branch's naming convention requires it).
- **Structured field-level blend** — the two sides changed *distinct, unambiguous fields* in a structured format (e.g., frontmatter `key: value` pairs where this branch changed `name:` and main changed `description:`). Each field can be selected independently by matching its key — there's no risk of ambiguity about where one side's content ends and the other's begins. Safe for a `sed` pattern (step 3b).
- **Prose or logic blend** — the two sides changed *overlapping* prose, logic, or content in the same region, and the correct result weaves pieces of both together in a way that isn't reducible to "take this named field from each side." There is no reliable field boundary for a pattern-match to key off — combining them correctly requires understanding what each side meant. Needs a real read (step 4).
- **Incompatible changes to the same logic/content** — the two sides made conflicting substantive changes to the same thing and neither simply wins, nor can both be kept. Needs a real read (step 4); do not force this into one of the buckets above.

**Do not default to a blend bucket.** Reaching for a hand-built blend is more error-prone than selecting a side that's already known-correct — it fabricates new content instead of choosing between two states that already exist and are each internally consistent. Prefer "ours wins" / "theirs wins" whenever the conflict is really about one side's change being moot, even if a blend *could* technically be constructed. And within the blend buckets, prefer **structured field-level blend** only when the fields are genuinely distinct and unambiguous — if combining the two sides requires judgment about intent rather than a key match, it's a **prose or logic blend**, not a `sed` candidate, regardless of how the surrounding format looks.

### 3a. Verify a wholesale-win classification before bulk-applying it

Before running `git checkout --ours`/`--theirs` across every file in a bucket, pick 2-3 representative files and confirm by diff that the discarded side genuinely has nothing worth keeping:

```bash
git diff HEAD:<path> origin/main:<path>
```

If the discarded side turns out to contain something unique (a fix, a detail this branch never touched), that file — and every other file you assumed shared its shape — needs re-classification, not a forced bulk resolution. Extrapolating "the first file was mechanical, so the rest probably are too" without checking is how a bulk resolution silently drops real changes.

### 3b. Verify a structured field-level blend by checking the output, not the discard

The risk for a blend isn't losing content wholesale — it's the reconstruction being subtly wrong (the pattern matches the wrong occurrence, a field has an embedded delimiter that breaks it, one file's field order or quoting differs from the sample you checked). Diffing what's discarded doesn't catch this. Instead:

1. Run the `sed` pass against **one file first**, not the whole bucket:

   ```bash
   sed -i '/^<<<<<<< /,/^>>>>>>> /{ /^name:/s/old-prefix-/new-prefix-/g; /^description:/s/old-prefix-/new-prefix-/g }' <single-file>
   ```

   Adapt the pattern to the actual field names and shape found in step 2 — this is not a template to copy verbatim.

2. **Read the resolved result** and confirm it actually contains the correct value from each side, with no leftover conflict markers and no field silently dropped or duplicated.
3. Spot-check the field shape (name, format, presence of colons/quotes inside the value) is uniform across 2-3 other files in the bucket before running the same pattern against the rest — a pattern that produced a correct result on the first file can still corrupt a later one whose field content doesn't match the assumed shape.
4. Only after both checks pass, apply the pattern to the remaining files in the bucket and stage them.

### 3c. Apply the wholesale-win and new-file buckets

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

### 4. Deep-read the prose/logic-blend and incompatible buckets

Files landing in **prose or logic blend** or **incompatible changes to the same logic/content** get a full `Read` + individual `Edit` — there is no safe mechanical shortcut for either. The two buckets differ in what the edit does (weave both sides together vs. pick or reconcile one outcome), not in whether a read is required. This should be a small minority of the total conflict count on a mechanical merge — if most files land here, the merge isn't mechanical and triage won't compress it much; resolve those the normal way.

### 5. Commit

```bash
git add -A && git commit
```

## Anti-Patterns to Avoid

- **Don't classify by surface shape alone.** "This looks like a frontmatter conflict" is not the same question as "which resolution strategy applies here" — a frontmatter-shaped conflict can still be a prose/logic blend if the two sides touched the same field with judgment-dependent changes.
- **Don't bulk-apply a resolution to a whole bucket without the matching verification step first (3a for wholesale-win, 3b for structured blends).** A pattern that looks uniform from one file's `grep` output can still hide a file where the discarded side has something real, or where the blend pattern breaks.
- **Don't treat a structured-field-blend verification (check the output) as interchangeable with a wholesale-win verification (check the discard).** They catch different failure modes; running the wrong one gives false confidence.
- **Don't reach for a content-blending `sed` pass as the default, and don't reach for it at all when the blend isn't reducible to distinct, unambiguous fields.** Check "ours wins" / "theirs wins" first. If a blend is genuinely needed, confirm it's a **structured field-level blend** before considering `sed` — if combining the sides requires judgment, it's a **prose or logic blend** and needs a real read instead.
- **Don't re-read a file after an `Edit` error unless the error indicates content drift.** "File has been modified since read" needs a re-read. "File has not been read yet" just needs a read first — it does not mean the whole triage was wrong.
- **Don't skip the scan step because the merge "looks simple."** The scan is one command; skipping it to save a call is how file-by-file resolution creeps back in.

## Acceptance Bar

- The agent scans all conflicts (step 1) before resolving any of them.
- Every conflict is classified by resolution strategy, not just by surface shape.
- Before a bulk `--ours`/`--theirs` resolution is applied to a bucket, at least one sample file's diff was checked to confirm nothing unique is being discarded.
- Before a `sed`-based structured blend is applied to a bucket, the resolved output (not just the discarded content) was verified on a sample file, and the field shape was spot-checked across others before the pattern was applied broadly.
- No conflicted file is force-fit into a wholesale-win or structured-blend bucket when it actually needs a prose/logic blend or a genuine judgment call.
- A mechanical merge (most conflicts resolve the same way across many files) completes in under 10 tool calls.
