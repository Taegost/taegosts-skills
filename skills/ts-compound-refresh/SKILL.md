---
name: ts-compound-refresh
description: "Companion to ts-compound. Builds CONCEPTS.md from scratch (repo-wide) or runs a targeted refresh cycle over docs/solutions/ and CONCEPTS.md when a new learning suggests older documentation is stale, contradicted, or superseded. Invoked directly or as ts-compound's recommended follow-up."
argument-hint: "[scope-hint] [mode:headless] [mode:bootstrap]"
---

# /ts-compound-refresh

Maintain the knowledge store `ts-compound` builds: bootstrap a repo-wide `CONCEPTS.md` from nothing, or audit existing `docs/solutions/` entries and `CONCEPTS.md` entries in a given scope against current codebase reality and correct what's drifted.

## Purpose

`ts-compound` documents new learnings as they happen — one doc, scoped to one problem, written while context is fresh. It does not go back and re-check older docs. Over time, refactors, renames, and superseding fixes leave some of those older docs inaccurate. `ts-compound-refresh` is the maintenance pass that catches that drift, plus the one-time job of building `CONCEPTS.md`'s repo-wide vocabulary when the project has never had one.

Two operations, one skill:

1. **Bootstrap** — build `CONCEPTS.md` from scratch, seeded with the project's declared domain model. Only meaningful when the file doesn't exist yet.
2. **Refresh cycle** — given a scope hint, re-examine `docs/solutions/` entries and `CONCEPTS.md` entries in that area, verify their claims against the current codebase, and fix what's confirmed stale.

## Usage

```bash
/ts-compound-refresh                          # no scope hint — see Routing below
/ts-compound-refresh <scope-hint>              # targeted refresh, e.g.:
/ts-compound-refresh plugin-versioning-requirements
/ts-compound-refresh payments
/ts-compound-refresh performance-issues
/ts-compound-refresh critical-patterns
/ts-compound-refresh mode:bootstrap            # force concept-map (re)build, skip the routing question
/ts-compound-refresh mode:headless <scope-hint> # non-interactive refresh for automations
```

Scope hints follow the same categories `ts-compound` uses when recommending a refresh (see its Phase 2.5): a specific file, a module or component name, a `docs/solutions/` category name, or a pattern filename/topic.

## Mode Detection

Check `$ARGUMENTS` for `mode:headless` and `mode:bootstrap` tokens. Both are flags, not scope — strip them from arguments before treating the remainder as the scope hint.

| Mode | When | Behavior |
|------|------|----------|
| **Interactive** (default) | No `mode:` token present | May ask a routing question (see below) and previews refresh-cycle fixes before applying them |
| **Headless** | `mode:headless` in arguments | No blocking questions. Routing falls to the headless default (see below). Refresh cycle auto-applies `confirmed_stale` fixes and reports `likely_stale` ones without applying them. Ends with a structured terminal report |

## Routing: Bootstrap vs Refresh

1. **`mode:bootstrap` present** — run Bootstrap regardless of any scope hint. If `CONCEPTS.md` already exists, do not overwrite it silently: in interactive mode, confirm with the user first ("`CONCEPTS.md` already exists with N entries — rebuilding will replace it. Continue, or did you mean to run a refresh cycle instead?"); in headless mode, refuse and report the conflict rather than destroying curated content.
2. **A scope hint is present (and no `mode:bootstrap`)** — run Refresh, scoped to that hint. This is the common path, including `ts-compound`'s own recommended follow-up invocations.
3. **No scope hint, no `mode:bootstrap`**:
   - **Interactive** — ask the user, using the platform's blocking question tool (`AskUserQuestion` in Claude Code, `request_user_input` in Codex, `ask_question` in Antigravity CLI, `ask_user` in Pi): `Build the concept map from scratch, or run a refresh cycle over existing docs?` with options `Build concept map`, `Run a broad refresh cycle (all of docs/solutions/)`, `Cancel`. Fall back to a numbered list in chat only when no blocking tool exists or the call errors. Never silently skip.
   - **Headless** — no question is possible. If `CONCEPTS.md` does not exist, default to Bootstrap (a bare headless invocation with no vocabulary file is almost always the bootstrap case). If `CONCEPTS.md` exists, default to a broad Refresh sweep over all of `docs/solutions/` — this is the "explicit broad sweep" case `ts-compound` describes as valid for a bare invocation.

## Bootstrap Mode

### 1. Preconditions

If `CONCEPTS.md` already exists and this run was not routed here via the `mode:bootstrap` override-and-confirm path above, stop — bootstrap only creates from nothing. Redirect to Refresh mode instead.

### 2. Dispatch the seeder

Use the **Bootstrap dispatch pattern** — the subagent reads its own operating contract from disk rather than receiving it inline.

```bash
RUN_ID=$(date +%Y%m%d-%H%M%S)-$(head -c4 /dev/urandom | od -An -tx1 | tr -d ' ')
mkdir -p "/tmp/taegosts-skills/ts-compound-refresh/$RUN_ID"
```

Dispatch one `domain-vocabulary-seeder` subagent:

1. **Agent file path** — `references/agents/domain-vocabulary-seeder.md`
2. **Contract file** — `skills/ts-compound/references/concepts-vocabulary.md`
3. **Artifact path** — `/tmp/taegosts-skills/ts-compound-refresh/{run_id}/concepts-draft.md`
4. **Preamble to use verbatim** (supplied in the task prompt):
   > Shared domain vocabulary for this project — entities, named processes, and status concepts with project-specific meaning. Seeded with core domain vocabulary, then accretes as ts-compound and ts-compound-refresh process learnings; direct edits are fine. Glossary only, not a spec or catch-all.

Require the bootstrap acknowledgment (file paths + line counts) before accepting the draft, same as `ts-compound`'s dispatch contract. Re-dispatch on a missing ack, up to 3 attempts.

### 3. Write CONCEPTS.md

Read the artifact back and write it verbatim to `CONCEPTS.md` at the repo root. Only the orchestrator writes the product file — the subagent's artifact is scratch space under `/tmp/taegosts-skills/ts-compound-refresh/`.

### 4. Report

Interactive: summarize the entry count and top-level clusters, then ask what's next (re-run `ts-compound` on the next learning, or done).

Headless: structured report (see "Success Output" below).

## Refresh Mode

### 1. Dispatch the auditor

Generate a run id and run dir the same way as Bootstrap mode. Dispatch one `stale-doc-auditor` subagent via bootstrap dispatch:

1. **Agent file path** — `references/agents/stale-doc-auditor.md`
2. **Schema files** — `skills/ts-compound/references/schema.yaml`, `skills/ts-compound/references/yaml-schema.md`
3. **Scope hint** — the resolved scope argument (or `all of docs/solutions/` for a broad sweep)
4. **Artifact path** — `/tmp/taegosts-skills/ts-compound-refresh/{run_id}/audit.json`

Require the bootstrap acknowledgment before accepting findings, same retry contract as above.

### 2. Read findings back

Read `audit.json`. Partition findings into `confirmed_stale`, `likely_stale`, and `still_accurate`. Findings with a `null` `proposed_fix` are report-only regardless of classification.

### 3. Apply fixes

**Interactive:** present a compact preview of every `confirmed_stale` and `likely_stale` finding with a non-null `proposed_fix` — grouped by classification, one line each (`path — issue → proposed_fix`) — then ask Proceed/Cancel using the platform's blocking question tool. On Proceed, apply every listed fix directly (single-file markdown edits, no cross-file dependencies expected for this class of change); on Cancel, apply nothing and report findings only.

**Headless:** auto-apply `confirmed_stale` fixes silently (they were verified directly against the codebase, same evidentiary bar as `ts-doc-review`'s `safe_auto` tier). Do not auto-apply `likely_stale` fixes — those need human judgment; surface them in the report instead.

`CONCEPTS.md` findings follow the same classification split: `confirmed_stale` entries get corrected (fixing the drifted phrasing while preserving the "file stands on its own" discipline from `concepts-vocabulary.md`); `likely_stale` entries are reported only.

### 4. Report

Interactive: confirm what was applied, list anything still needing a human look, and ask what's next.

Headless: structured report (see "Success Output" below).

## Success Output

### Headless mode

```
✓ Refresh complete (headless mode)

Operation: bootstrap | refresh
Scope: <scope hint, or "concept map" for bootstrap, or "all of docs/solutions/" for broad sweep>
Candidates examined: <N>
Confirmed stale — fixed: <N> (<paths>)
Likely stale — needs review: <N> (<paths>)
Still accurate: <N>
CONCEPTS.md: <created with N entries | N entries corrected | no changes needed>

Refresh complete
```

### Interactive mode

Prose summary covering the same fields, followed by a "What's next?" offer using the platform's blocking question tool: re-run `ts-compound` on the next learning, run another refresh with a different scope, or done. Never silently skip.

## What It Doesn't Do

- Doesn't second-guess documented decisions that are still accurate — staleness is about factual drift against the current codebase, not stylistic disagreement.
- Doesn't run automatically. `ts-compound` only recommends it; a human or an automation must invoke it explicitly (per `ts-compound`'s Phase 2.5 — headless `ts-compound` runs never trigger this skill on their own).
- Doesn't create new `docs/solutions/` entries for newly-discovered problems — that's `ts-compound`'s job.
