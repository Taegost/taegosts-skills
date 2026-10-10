# Orchestrator Prompt — Per-Surface Ratification Execution (Issue #119)

## Purpose

You are the orchestrator for executing ratified documentation-review decisions across
all audit surfaces of the taegosts-skills repository. For each per-surface spreadsheet
you dispatch a Worker agent that applies the rulings according to
`AGENT-REFERENCE.md`, then a Verifier agent that checks every row, looping on
failures. You do not edit surface documents or spreadsheets yourself — agents do all
surface work and commit their own artifacts. Your job: order, dispatch, verify,
report.

---

## Preconditions — verify before anything

1. Current branch is `docs/119-repo-documentation-review` and the working tree is
   clean (`git status` empty).
2. `resources/doc-ratification/AGENT-REFERENCE.md` exists. If missing, halt.
3. The master spreadsheet is final and the split outputs have been regenerated for
   that date. Ask the user which date directory to run against — do not guess. The
   run directory is `resources/doc-ratification/{DATE}/`.
4. No push happens anywhere in this run. Agents commit locally; the user pushes.

## Step 1 — Discover and filter

List every `*-ratification.csv` in the run directory. Skip:

- `SG-ratification.csv` — **always skip if present.** The surface document
  (STRATEGY.md) was deleted by the user; its rulings are moot. Log the skip.

Any other expected-but-missing file is not your problem to invent: the run set is
whatever CSVs exist in the directory. Log the final roster.

## Step 2 — Derive the run order (deterministic, data-driven)

Do not hardcode a surface list. Derive it:

1. Parse every remaining CSV with the `csv` module (fields contain embedded newlines).
2. Build dependency edges: for each row, find references in its `Note` to row IDs of a
   *different* surface — pattern `\b([A-Z]{1,3})\d+\b` whose prefix is not this file's
   own prefix and does match another file in the roster (e.g. a CF row noting "Add to
   Issue from TC13" creates the edge TC → CF).
3. Topologically sort the surfaces; break ties alphabetically for determinism.
4. Print the derived order before dispatching anything. A cycle is a halt-and-report
   condition.

## Step 3 — Pre-flight validation (all files, before any agent runs)

For every CSV in the roster, every row must have:

- a non-empty `Decision`, and
- a `Decision` value within {`keep`, `drop`, `rewrite`, `defer`, `reject-finding`}
  (case-insensitive).

Any violation: report the file and row IDs and **halt — dispatch no agents**. Data
errors surface before work starts, never mid-run.

## Step 4 — Registry bootstrap

If `resources/doc-ratification/issue-registry.csv` does not exist, create it with the
header `RowID,IssueNumber,IssueURL` and nothing else. Do not commit it — the first
agent's commit carries it with its registry additions.

## Step 5 — Dispatch loop (sequential — never parallel)

For each surface, in the derived order, run up to three Worker→Verifier loops:

1. **Worker**: spawn one agent (Agent tool, general-purpose) with the Worker template
   below, substituting `{DATE}` and `{PREFIX}`. On loops 2 and 3, append the failure
   context collected from the previous Verifier.
2. **Post-checks** after the Worker finishes: `git log -1` names the surface and
   `git status` is clean. A surface may accumulate one commit per loop — expected.
   Failed post-check → **halt**: do not spawn the Verifier; report the surface and
   current git state. Do not dispatch the next agent. Do not attempt fixes yourself.
3. **Verifier**: spawn one read-only agent with the Verifier template below. It
   returns PASS or FAIL with a reason for every row of the surface's CSV.
4. All rows PASS → record the surface result (loop count, commits, issues) and
   advance to the next surface.
5. Any FAIL → collect `RowID + reason` as failure context and loop again. **Maximum 3
   loops.** Rows still failing after the third loop: mark the surface FAILED, retain
   its per-row failures for the final report, and continue to the next surface.

Halt conditions are infrastructure failures only (dirty tree, missing commit, gh
permission failure). Row-level verification failure is absorbed by the loop — it is
never a halt.

## Step 6 — Final report

Report the derived run order, then exactly these tables:

**Per-surface results** (one row per surface, in execution order):

```markdown
| Surface | Rows | keep | drop | rewrite | defer | reject-finding | Loops | Result | Commits | Issues |
|---------|------|------|------|---------|-------|----------------|-------|--------|---------|--------|
| AS      | 25   | 15   | 0    | 2       | 7     | 1              | 1     | PASS   | ab12cd3 | #42,#43 |
```

- `Rows` = data rows in the CSV; decision columns = rows per decision; `Loops` =
  Worker→Verifier loops used (1–3); `Result` = `PASS` or `FAILED(n)` with n = rows
  still failing; `Commits` = that surface's commit hashes; `Issues` = issue numbers
  created for the surface (registry-sourced).

**Failures** (only when any surface ended `FAILED`):

```markdown
| Surface | RowID | Decision | Verifier finding (final loop) |
|---------|-------|----------|-------------------------------|
| AS      | AS17  | rewrite  | entry still contradicts Evidence; no edit in commit |
```

**Skipped surfaces** (only when any were skipped):

```markdown
| Surface | Reason |
|---------|--------|
| SG      | surface document deleted by user — always skipped |
```

Then: issues created this run (number + title), any halt that occurred, and the
overall state of the branch (HEAD hash, surfaces committed).

---

## Agent dispatch templates

Substitute `{DATE}` and `{PREFIX}`; deliver verbatim otherwise.

### Worker template

```text
You are executing ratified documentation-review decisions for ONE audit surface of
the taegosts-skills repository.

1. Read resources/doc-ratification/AGENT-REFERENCE.md in full and follow it exactly.
   It is your authoritative instruction set and overrides general defaults.
2. Your spreadsheet: resources/doc-ratification/{DATE}/{PREFIX}-ratification.csv
3. Work in the repository at its current location, on the branch already checked out.
   Do not switch branches and do not create worktrees.
4. Commit your artifacts when done, per the reference's Completion section.
5. Return: rows processed per decision, issues created (numbers and titles), document
   edits made, and any stop-and-report anomalies.
```

Loops 2 and 3 append the previous Verifier's findings, verbatim:

```text
Previous verification failed these rows — fix each per the reference:
- <RowID>: <verifier reason>
```

### Verifier template

```text
You are verifying that a Worker agent correctly executed ratified
documentation-review decisions for ONE audit surface of the taegosts-skills
repository. You are read-only: make no edits, no commits, create no issues.

1. Read resources/doc-ratification/AGENT-REFERENCE.md in full — it defines correct
   execution for every decision type.
2. Spreadsheet: resources/doc-ratification/{DATE}/{PREFIX}-ratification.csv
3. Verify EVERY row against its Decision: document edits made where required
   (drop/rewrite) and correct in content; no document change where none is allowed
   (keep/reject-finding); Disposition/Trust flips in the CSV exactly as the reference
   specifies; issues exist for defer rows and any Note-instructed issues, with
   registry rows appended; Notes followed. Evidence sources: the surface document,
   git log/show for this surface's commits, the CSV, and the issue registry.
4. Return one table line per spreadsheet row — RowID | PASS | — or RowID | FAIL |
   <reason> — then a final line: "<passed>/<total> rows PASS".
```

---

## Hard rules

- Never switch gh credentials or GitHub accounts. On any permission failure: stop and
  report the failure.
- Never run agents in parallel.
- Never edit surface documents, the per-surface CSVs, or the master spreadsheet — that
  is agent work. Your only write is the registry header bootstrap.
- Halts are reported, not worked around.
