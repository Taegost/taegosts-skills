# Agent Reference — Executing Ratification Decisions (Issue #119 Documentation Review)

You are executing one batch of user-ratified documentation review decisions for the
taegosts-skills repository. A repo-wide documentation audit produced findings; the user
reviewed every finding offline and recorded a ruling for each. Your job: apply those
rulings to the repository.

You will be given the path to a per-surface CSV file (for example
`resources/doc-ratification/2026-10-05/AS-ratification.csv`). It contains every ratified
finding for ONE audited document (the "surface"). Process every row in the file.

You do not need the originating plan — everything required is in this reference and in
the CSV. Treat the plan and the master spreadsheet as ephemeral objects that may be
removed or changed at any time: do not read them, cite them, or make any artifact
depend on them.

---

## The CSV

Header: `ID,Surface,Location,Claim,Evidence,Trust,Disposition,Decision,Note`

| Column | Meaning |
|---|---|
| `ID` | Row identifier. The letter prefix is the surface code. |
| `Surface` | The audited document this row concerns. |
| `Location` | `file:line` reference into the surface document. Line numbers may be stale — see "Before you edit". |
| `Claim` | The auditor's finding. May carry a `Verdict: drifted` / `Verdict: valid` prefix, and quotes the doc text it targets. |
| `Evidence` | The auditor's verification: what was checked and what reality is. |
| `Trust` | Provenance classification of the finding. Context only. |
| `Disposition` | Lifecycle state of the row. **You update this column as you complete work.** |
| `Decision` | The user's ruling. Your primary instruction. |
| `Note` | The user's supplementary instructions. **Highest authority in the row.** |

Quoted fields contain embedded newlines and commas. Edit the CSV with CSV-aware
tooling (for example Python's `csv` module) — never raw string manipulation.

Order of authority within a row: **Note > Decision > Disposition > Claim/Evidence**.
Decision values are lowercase in the data; match them case-insensitively.

---

## Decision semantics

### `keep` — keep the entry; change nothing in the document

The user ratifies the **entry in the surface document** — that part of the document
stays exactly as it is. Make no edit to the surface document.

Important: keep does **not** endorse the Claim. The user may consider the Claim, or
even the proposed Disposition, wrong — keep overrides both. The entry is kept
regardless of what the Claim asserts about it, and the Claim text stays recorded
unchanged in the CSV (audit trail).

- Flip the row: `Disposition` → `ratified-keep`, `Trust` → `user-confirmed`.
- Read the `Note`. Notes on keep rows may still carry actions — for example "open an
  issue to re-examine this later" or "include this in the issue for TS4". Follow them.
- A keep Decision applies even when the Claim text says `Verdict: drifted`: keep always
  means leave the entry alone. The Note governs anything beyond that.

### `drop` — remove the entry from the surface document

Remove the Claim's target entry (the quoted doc text) from the surface document. The
`Note` carries the specifics of what to remove — read it first. Some Notes say the user
already removed the text themselves; in that case verify the current document state,
make no edit, and leave the row's Disposition as recorded.

- Flip the row: `Disposition` → `fixed-in-U5` (many rows already carry this value).
- `Trust` and all other columns stay unchanged. `Location` is frozen audit-time data —
  never modify it, even when your edits shift line numbers.
- **Line-shift warning:** a removal shifts every line after it, so later rows'
  `Location` numbers may no longer match the file. Re-locate targets by their quoted
  text (see "Before you edit"). Processing line-shifting edits in descending line
  order keeps the remaining rows' numbers valid.

### `rewrite` — rewrite the entry in the surface document

Rewrite the Claim's target entry in the surface document, in place.

- If the `Note` contains explicit rewrite instructions, follow them literally.
- If it does not, infer the intent from `Claim` + `Evidence`: the Claim states what is
  wrong with the current entry, the Evidence states what verified reality is. Rewrite
  the entry so the documented statement matches that reality.
- Flip the row: `Disposition` → `fixed-in-U5`. `Trust` unchanged. `Location` is
  frozen audit-time data — never modify it.
- **Line-shift warning:** a rewrite that adds or removes lines shifts every line after
  it, so later rows' `Location` numbers may no longer match the file. Re-locate
  targets by their quoted text. Processing line-shifting edits in descending line
  order keeps the remaining rows' numbers valid. (An in-place rewrite with unchanged
  line count shifts nothing.)

### `defer` — create a GitHub issue

Create an issue to track the work. See "Issue authoring" below — issues must be
self-contained work items, not spreadsheet exports.

- Flip the row: `Disposition` → `deferred-issue-#<n>` with the real issue number
  (replacing any `#tbd`).
- Multiple defer rows may belong to the same issue per their Notes ("Add to same Issue
  as AS3"). Group them; each grouped row records the same issue number.

### `reject-finding` — overruled audit finding; change nothing

The user completely rejects the Claim as invalid. Make no edit to the surface
document; the entry it targeted stays as-is.

- Flip the row: `Disposition` → `rejected-finding`, `Trust` → `user-confirmed`. This
  preserves the audit trail that the finding was raised and overruled — never clean the
  row up into a "valid" disposition.
- Read the `Note` and follow anything it instructs beyond that.

### Empty `Decision` — error, not a fallback

Every row must carry a Decision. An empty Decision cell means the data is incomplete —
never guess, never fall back to the proposed `Disposition`, and do not process the row.
Stop and report the row ID as an error.

---

## Before you edit (every time)

1. **Line numbers are hints, not truth.** Documents were hand-edited after the audit.
   Re-locate the target text by the quoted wording in the Claim/Note, not by line
   number. Some Notes explicitly warn that line numbers shifted.
2. **If the target text is already gone or already matches the desired end state**, the
   user likely fixed it manually — several Notes say so. Make no edit; keep the row's
   recorded Disposition and Note as-is.
3. **Never rewrite a rule to bless the status quo.** If the Evidence indicates the code
   is wrong rather than the document, make no edit — record it in your completion
   report instead.
4. **Preserve surrounding structure and formatting.** Keep the document's tone,
   heading hierarchy, and conventions. Generated INDEX tables are never hand-edited;
   `python3 scripts/update-indexes.py` regenerates them.

---

## Issue authoring (defer rows)

Each issue is a standalone work item that must not require any context from the plan
or the CSV files to work on.

- **Audience:** a person with no knowledge of this codebase or the review can pick the
  issue up and work on it without asking any additional questions.
- **Body**, in plain prose:
  - the problem and why it matters;
  - current state — what the document or code says today, with `file:line`;
  - desired end state — what needs deciding, changing, or building;
  - acceptance criteria — how "done" is recognized.
- Carry the relevant `Claim` / `Evidence` / `Note` content into the issue body — that
  information is necessary context and belongs in the issue. What is prohibited is
  referring to the source files instead of including the content: no "see TS5 in the
  ratification CSV", no links to the plan or the spreadsheets. The plan and CSVs are
  ephemeral; the issue must carry everything itself. Row IDs may be included for
  traceability; they must not be the substance.
- An origin line such as "Identified during the repo documentation review (issue
  #119)." is fine; anything stronger (links to the plan or CSVs) is not.
- **Title:** a plain descriptive summary of the work — no spreadsheet jargon.
- Create with `gh issue create` in this repository (`Taegost/taegosts-skills`), using
  the session's active credential. Never switch accounts or credentials; if creation
  fails on permissions, stop and report.
- **Registry:** after creation, append one line per covered row to
  `resources/doc-ratification/issue-registry.csv` (header `RowID,IssueNumber,IssueURL`),
  creating the file if it is absent.
- **When a Note says to add this row to an issue created for a different row** ("Add
  to Issue from TC13"): resolve that issue number from the registry (fallback:
  `gh issue list`), then extend that issue with this row's detail. If it cannot be
  found, stop and report — do not create a duplicate issue.

---

## Ledger bookkeeping

- Write updates **only into your per-surface CSV**: the `Disposition` and `Trust`
  flips described above. Every other column stays byte-identical. `Location` holds
  audit-time line numbers, kept frozen so the numbers still match the commit history
  the audit ran against.
- Never touch `ratification-decisions.csv` (repo root), other surfaces' CSVs, the
  plan, or registry rows belonging to other surfaces (the registry is append-only for
  your rows).
- The master spreadsheet is merged from the per-surface files later by separate
  tooling.

---

## Completion

1. Re-run the gates over what you touched, at minimum
   `python3 scripts/validate-index-standards.py` on the affected trees. The pre-commit
   hooks (index regeneration, shellcheck, script verification) run on commit and must
   pass.
2. Commit your artifacts on the current branch — surface-document edits, your
   per-surface CSV, and your registry additions — with a conventional message such as
   `docs(#119): apply ratification decisions for <surface>`.
3. Report in chat (not committed): rows processed per decision, issues created
   (numbers and titles), document edits made, and anything you stopped on.

---

## Stop-and-report conditions

The decisions are pre-approved: execute them without asking for further confirmation.
Stopping is for anomalies only:

- an empty `Decision` cell — the data is incomplete; report the row ID as an error;
- target text cannot be located and the Note does not explain it;
- a Note references an issue that does not exist;
- `gh` fails on permissions (never switch credentials — report the failure);
- the Evidence indicates the code is wrong rather than the document;
- anything ambiguous after reading the full row — report it, do not guess.
