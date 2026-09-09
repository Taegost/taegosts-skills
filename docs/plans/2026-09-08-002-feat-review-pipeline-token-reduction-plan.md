---
title: "feat: Reduce orchestrator token usage in ts-pr-review and ts-code-review (Issue #113)"
type: feat
date: 2026-09-08
issue: 113
status: completed
---

# feat: Reduce orchestrator token usage in ts-pr-review and ts-code-review (Issue #113)

## Summary

Cut orchestrator token consumption across the PR-review pipeline so `/ts-pr-review` runs complete without session compaction. Three levers, all following the pattern issue #103 / PR #112 already applied to `ts-plan` and `ts-doc-review`: bootstrap dispatch (subagents read their own contracts from disk instead of receiving them inline), de-inlining `@`-included references the orchestrator no longer needs, and converting deterministic orchestrator prose (PR payload construction, Stage 5 merge bookkeeping) into scripts.

---

## Problem Frame

Running `/ts-pr-review` compacts the orchestrator session before subagents finish. Issue #113 names three ts-pr-review bullets and leaves ts-code-review as an open mandate ("the bulk of the token usage… a LOT of instructions here for the orchestrator").

Measurements (words loaded per invocation, current):

| Asset | Words | Load condition |
|---|---|---|
| `skills/ts-code-review/SKILL.md` | 9,624 | Every invocation |
| `@`-included `references/subagent-template.md` | 3,172 | Every invocation |
| `@`-included `references/findings-schema.json` | 1,054 | Every invocation |
| `@`-included `references/agent-catalog.md` | 542 | Every invocation |
| `@`-included `references/diff-scope.md` | 381 | Every invocation |
| `@`-included `references/action-class-rubric.md` | 229 | Every invocation |
| `skills/ts-pr-review/SKILL.md` | 1,484 | Every invocation |

~16.5k words (~22k tokens) load per invocation — the six ts-code-review assets sum to ~15k, plus ~1.5k for ts-pr-review's SKILL.md. The larger cost is dispatch-side: Stage 4 is inline-content dispatch — the orchestrator substitutes the full agent file, diff-scope rules, and findings schema into every reviewer prompt (~5-6k tokens × N reviewers of boilerplate emitted as orchestrator output). Stage 5's eleven-step merge pipeline is LLM-executed bookkeeping prose (~1,100 words). In ts-pr-review, steps 4b/4c have the orchestrator hand-build the GitHub review payload JSON per finding.

The bootstrap-dispatch convention (`docs/solutions/conventions/subagent-bootstrap-dispatch.md`) already covers ts-doc-review, ts-plan, and ts-work. ts-code-review was never converted.

## Requirements

From issue #113:

- **R1** — ts-pr-review: remove the section that checks for `ts-code-review` availability (legacy artifact from the base `code-review` skill era).
- **R2** — ts-pr-review 4b: script line-number verification fully, reducing orchestrator token usage.
- **R3** — ts-pr-review 4c: script review-JSON-payload construction fully.
- **R4** — ts-code-review: reduce the instruction load the orchestrator carries (the bulk of token usage).

Scope decision (user, 2026-09-08): full round — bootstrap dispatch, de-inlining, and Stage 5 merge script extraction.

## Key Technical Decisions

1. **Bootstrap dispatch per the existing convention**, mirroring `skills/ts-doc-review/references/subagent-bootstrap.md`. Each reviewer reads `references/subagent-template.md`, `references/agents/<name>.md`, `references/findings-schema.json`, `references/diff-scope.md`, and `references/action-class-rubric.md` from disk. Dynamic slots stay inline: run ID, reviewer name, intent, PR metadata, scope-mode tags (`<pr-scope-mode>`, `<pr-head-ref>`, `<branch-head-ref>`), `<pr-base-ref>` (pr-remote file-level diffs), `<review-base>` (data-migration base ref), `<standards-paths>`, staged diff/file-list paths. Bootstrap-ack verification, 3-attempt recovery, and inline fallback — same mechanics as ts-doc-review.
2. **Stage 5 merge pipeline becomes a deterministic script** (`merge-findings.py`). Issue #103 already named this class: "deterministic parsing logic written as prose instead of scripts." Validation, dedup, promotion, demotion, gating, partition, and sort/numbering are mechanical; the LLM keeps only judgment steps (disagreement annotation, triage grouping, verdict, coverage prose). Correctness win as well as token win.
3. **4b + 4c become one script** (`build-review-payload.sh`). Line-partition and payload construction are one dataflow over `review.json` + the linemap; a single call honors the skill's own "combine into as few commands as possible" rule and gives one test surface.
4. **`agent-catalog.md` stays `@`-included** — Stage 3 reviewer selection needs it every run; de-inlining saves nothing.
5. **P3-only event rule becomes deterministic.** Current "use judgment on APPROVE vs REQUEST_CHANGES" encodes as `event: COMMENT` with a body note. Deliberate behavior change; documented here and in SKILL.md.

## Implementation Units

### U1. ts-pr-review: remove legacy availability-check section

- **Goal:** Delete the pre-dispatch check for `ts-code-review` availability (R1).
- **Requirements:** R1
- **Dependencies:** none
- **Files:** `skills/ts-pr-review/SKILL.md`
- **Approach:** Delete `### 1. Ensure the ts-code-review skill is available`. Renumber Process steps 2-5 to 1-4 and sub-steps 4a-4e to the new numbering. Sweep cross-references: constraint #1 ("stop and go back to step 2" becomes step 1), constraint #2 ("Step 4 consumes findings" becomes step 3), step-2 artifact rule ("sole source of findings for step 4" becomes step 3), status handler ("continue to step 3" becomes step 2), step-3 gate note ("for step 4 come from this file" becomes step 3), step-4 internal references ("per 4b", "section 4e"), "go to step 5".
- **Test scenarios:** Test expectation: none — prose-only edit, no scripts or behavior touched. Verified by grep: no stale step/sub-step references survive.

### U2. ts-pr-review: `build-review-payload.sh` (scripts steps 3b + 3c, post-U1 numbering)

- **Goal:** Fully script line verification and review-payload construction (R2, R3).
- **Requirements:** R2, R3
- **Dependencies:** none
- **Files:** create `skills/ts-pr-review/scripts/build-review-payload.sh`, `tests/scripts/test-build-review-payload.sh`; update `skills/ts-pr-review/scripts/INDEX.md`
- **Approach:** Bash + `jq`, matching `fetch-pr-data.sh` / `map-diff-lines.sh` conventions (`set -euo pipefail`, `--help` heredoc, documented exit codes). Inputs: `--review-json`, `--linemap`, `--pr-number`, `--head-sha`, `--pr-title`, `--run-id`, `--out-dir`, `--assessment-file`. SKILL.md invocations use `${CLAUDE_SKILL_DIR}/scripts/build-review-payload.sh` per the plugin script-path-resolution decision; outputs anchor to `--out-dir`, never CWD. Outputs: `review-payload.json` (ready for `gh api --input`), `fallback-findings.md` (flat-comment body for non-commentable findings plus `residual_risks` / `testing_gaps` as Info entries), and a one-line stdout summary (postable count, fallback count, chosen event). Logic:
  - Partition: finding `file:line` present in linemap becomes an inline comment (`side: "RIGHT"`); otherwise routes to the fallback list. Diff parsed once.
  - Severity map: P0 to Critical, P1 to High, P2 to Moderate, P3 to Minor; advisory findings / `residual_risks` / `testing_gaps` to Info.
  - Event rule: any P2 or higher triggers `REQUEST_CHANGES`; Info-only triggers `APPROVE`; P3-only triggers `COMMENT` with a body note (KTD 5).
  - Comment body per finding: Summary (title), Description (`why_it_matters`, ~10-line cap), Reason (`evidence` items), Severity, Proposed Fix (`suggested_fix`, ~10-line cap), AI Prompt (deterministically composed from title + `file:line` + `suggested_fix` — no LLM authoring).
  - Top-level body: PR title, verdict, run ID, counts, plus the orchestrator's 2-3 sentence assessment supplied via `--assessment-file` (authored from `review.json` verdict/coverage — the one prose field that stays LLM-authored).
- **Test scenarios:**
  - Mixed severities including one P1 → payload carries inline comments with mapped severities, `event: REQUEST_CHANGES`, `commit_id` equals head SHA.
  - Finding on a line absent from the linemap, or a file not in the diff → routed to fallback output, not dropped.
  - Chained contract: a fixture diff piped through `map-diff-lines.sh` into `build-review-payload.sh` → partition matches the map's actual output (pins the script-to-script seam U3 wires).
  - Info-only input (advisory + `residual_risks`) → `event: APPROVE`.
  - P3-only input → `event: COMMENT` with note.
  - Zero findings → minimal approval payload.
  - Malformed `review.json` (missing required fields, invalid JSON) → exit 1, error on stderr.
  - `--help` → usage text, exit 0.

### U3. ts-pr-review: slim SKILL.md steps 3b/3c/3d/3e to script calls (post-U1 numbering)

- **Goal:** Replace payload-construction prose with script invocations so the orchestrator emits one command instead of a per-finding JSON body.
- **Requirements:** R2, R3
- **Dependencies:** U1, U2 (U1 renumbers the steps this unit targets — execute after U1)
- **Files:** `skills/ts-pr-review/SKILL.md`
- **Approach:** Replace steps 3b/3c/3d orchestration prose (post-U1 numbering for old 4b/4c/4d) with: save the diff once → `map-diff-lines.sh` → `build-review-payload.sh` (passing `--assessment-file` from a 2-3 sentence assessment the orchestrator authors from `review.json` verdict/coverage) → `gh api repos/{owner}/{repo}/pulls/{number}/reviews --input review-payload.json` → post `fallback-findings.md` via `post-pr-comment.sh` when non-empty. All script invocations in the rewritten prose use `${CLAUDE_SKILL_DIR}/scripts/...` (and `${CLAUDE_PLUGIN_ROOT}/skills/...` for `post-pr-comment.sh`) per the plugin script-path-resolution decision. Keep the head-SHA staleness cross-check (`headRefOid` vs `scope.head_sha`) and the REQUEST_CHANGES-rejected → COMMENT fallback note (orchestrator judgment, not scriptable). Keep a brief documented manual fallback for script failure.
- **Test scenarios:** Test expectation: none — SKILL.md prose; behavior verified via U2 script tests and `scripts/verify-script-refs.sh` (runtime script invocations are plugin-root prefixed).

### U4. ts-code-review: bootstrap dispatch + de-inline references

- **Goal:** Convert reviewer and validator dispatch from inline-content to bootstrap dispatch; drop ~4.8k words of per-invocation `@`-included load the orchestrator no longer needs (R4).
- **Requirements:** R4
- **Dependencies:** none
- **Files:** create `skills/ts-code-review/references/subagent-bootstrap.md`; modify `skills/ts-code-review/SKILL.md` (Stage 4, Stage 5b, Included References), `skills/ts-code-review/references/subagent-template.md` (rewrite to read-list contract: drop `{agent_file}`/`{diff_scope_rules}`/`{schema}` slots and their Variable Reference rows), `skills/ts-code-review/references/validator-template.md` (same rewrite), `docs/solutions/conventions/subagent-bootstrap-dispatch.md` (add ts-code-review to "When to Apply" and the `applies_when` frontmatter list), `docs/solutions/conventions/agent-definition-convention.md` (Dispatch Patterns and "Adding agents" bullet: ts-code-review and ts-doc-review listed under bootstrap; template-wrapped named deprecated inline fallback only)
- **Approach:** Model `subagent-bootstrap.md` on the ts-doc-review equivalent: bootstrap prompt shape (read-in-full list, schema-as-guidance line, ack format), dynamic-slot table, ack verification, 3-attempt recovery, inline fallback via orchestrator Read-on-demand. The dynamic-slot table carries every current Stage 4 context tag — run ID, reviewer name, intent, PR metadata, `<pr-scope-mode>`, `<pr-head-ref>`, `<branch-head-ref>`, `<pr-base-ref>` (pr-remote file-level diffs), `<review-base>` (data-migration base ref), `<standards-paths>`, staged diff/file-list paths — so nothing the current bundle injects is lost. Rewrite Stage 4 "Spawning" to pass paths plus dynamic slots instead of substituting `{agent_file}` / `{diff_scope_rules}` / `{schema}`. Convert Stage 5b validator dispatch the same way — the validator reads `validator-template.md` itself; finding fields, scope-mode tags, and the diff (inline or staged path) are passed to it. Rewrite `subagent-template.md` and `validator-template.md` into read-list contracts (drop the substitution slots and their Variable Reference rows — the subagent reads the file itself, so there is nothing to substitute); the inline fallback lives in `subagent-bootstrap.md`, where the orchestrator reads each file on demand and passes full content per the convention. Remove `@./` includes for `subagent-template.md`, `diff-scope.md`, `action-class-rubric.md`, and `findings-schema.json`; keep `@./references/agent-catalog.md` (KTD 4).
- **Test scenarios:** Test expectation: none — no executable code. Verification: word-count delta (SKILL.md + includes, before/after); grep of SKILL.md Stage 4 prose for inline-dispatch phrasing ("included below", "agent file content") comes back empty; presence check confirms every current Stage 4 context tag (including `<pr-base-ref>` and `<review-base>`) survives in the bootstrap slot table; `scripts/verify-script-refs.sh` clean.

### U5. ts-code-review: extract Stage 5 merge to `merge-findings.py`

- **Goal:** Move the mechanical merge pipeline out of orchestrator prose into a deterministic script (R4).
- **Requirements:** R4
- **Dependencies:** U4 (editing order — both touch `SKILL.md`)
- **Files:** create `skills/ts-code-review/scripts/merge-findings.py`, `tests/skills/ts-code-review/test_merge_findings.py` (pytest suite, per testing-standards); update `skills/ts-code-review/scripts/INDEX.md`; modify `skills/ts-code-review/SKILL.md` (Stage 5)
- **Approach:** Python, stdlib `json` only (matches `extract-ktds.py` / `locate-plan.py` precedents), carrying the same script conventions as U2 (header comment, `--help` handling, documented exit codes, executable bit) so `verify-scripts.sh --all` passes on first run; SKILL.md invocations use `${CLAUDE_SKILL_DIR}/scripts/merge-findings.py` per the plugin script-path-resolution decision. Input: compact-return JSON files the orchestrator stages to `<run-dir>/compact/<reviewer>.json` as reviewers return — the script reads only these, never the full-schema artifacts, so a failed artifact write still merges via the compact return (current failure semantics preserved). Output: merged JSON — primary findings with stable `#`, pre-existing list, demoted findings appended to `residual_risks`, unioned `residual_risks` / `testing_gaps`, and a `coverage` block (drop/suppress/demotion counts by anchor, malformed returns, disagreement reports). Encodes current Stage 5 steps 1-10 exactly:
  - Validate compact returns: required fields, enum constraints, anchors restricted to {0, 25, 50, 75, 100}.
  - Fingerprint dedup: `normalize(file) + line_bucket(±3) + normalize(title)`; keep highest severity and anchor; track contributing reviewers.
  - Cross-reviewer agreement: promote merged finding one anchor step (100 stays 100).
  - Separate pre-existing findings.
  - Routing normalization: conservative on disagreement; reject `safe_auto` / `review-fixer` by remapping to `gated_auto` / `downstream-resolver`.
  - Mode-aware demotion: P2/P3 + `advisory` + single non-testing reviewer → `residual_risks`.
  - Late confidence gate: suppress below anchor 75, except P0/P1 at 50+ survive.
  - Partition actionable (`gated_auto`/`manual` + `downstream-resolver`) vs report-only.
  - Sort (severity, anchor descending, file, line) and assign stable `#` across the full primary set.

  SKILL.md Stage 5 collapses to: run the script, then the judgment steps — disagreement annotation (from the script's conflict report), step 9b triage grouping (operates on script output), Coverage prose (counts from the script), and step 11 CE-artifact preservation (learnings and deployment-verification outputs kept alongside the merged set; the script's input is structured reviewer JSON only, so unstructured outputs are preserved by construction). `grouping:` tokens continue to control only the orchestrator's grouping step.
- **Test scenarios** (fixture compact returns):
  - Two reviewers, same issue within ±3 lines, same normalized title → merged once, promoted one anchor step, both reviewers recorded.
  - Two reviewers, same fingerprint, differing severity (P0 vs P1) and differing autofix class → merged finding keeps highest severity and the conservative route; conflict report names both reviewers and their positions.
  - Return-level malformation (missing `residual_risks`) → the entire return is dropped, its findings do not survive (current step 1 semantics).
  - Finding-level malformation (bad enum, anchor `72`) → that finding dropped and flagged; sibling findings in the same return survive.
  - P2 `advisory` from a single non-testing reviewer → demoted to `residual_risks`, count recorded.
  - Same shape sourced by the `testing` reviewer → stays primary (testing never demotes).
  - Same shape flagged by two reviewers → stays primary (corroboration prevents demotion).
  - Anchor-50 P1 → survives the gate; anchor-50 P2 alone → suppressed, count recorded by anchor.
  - `safe_auto` finding → remapped to `gated_auto` / `downstream-resolver`.
  - Sort/numbering: P0 before P1, anchor descending within severity, `#` monotonic across the full set.
  - All reviewers return empty findings → empty primary set, exit 0.
  - `--help` → usage text, exit 0.

### U6. ts-code-review: prose trim, docs sync, measurement

- **Goal:** Remove duplication the restructure makes safe; record the before/after token-load table.
- **Requirements:** R4
- **Dependencies:** U4, U5
- **Files:** `skills/ts-code-review/SKILL.md`; `docs/solutions/conventions/subagent-bootstrap-dispatch.md` (if not already updated in U4)
- **Approach:** Sweep SKILL.md for duplication: Quality Gates items restating the subagent-template false-positive catalog become one-line references; Stage 5's inline value-constraint list is deleted (the script enforces it). Keep the Severity Scale and Action Routing tables — the orchestrator needs them to read script output. Move low-frequency sections to on-demand reference files, mirroring Stage 6's `references/review-output-template.md` pattern: Stage 1 branch-specific diff recipes, the Quick Review short-circuit, and argument-parsing edge rules become references the orchestrator reads only when those paths fire — the one lever large enough to reach the target without cutting load-bearing instructions. Carry the before/after word-count table in the PR body, mirroring issue #103's measurement pattern. Targets: per-invocation load from ~16.5k to ~7-8k words; per-reviewer dispatch output from ~5-6k to ~0.3k tokens.
- **Test scenarios:** Test expectation: none — prose and index edits; verified by the full gate run.

## Risks and Dependencies

- **Bootstrap fidelity.** Reviewers must actually read their files (known lazy-read failure mode) — mitigated by ack verification, 3-attempt recovery, and the inline fallback, all proven in ts-doc-review.
- **Merge-semantics drift.** The script must match the current LLM-executed rules exactly (gate exceptions, demotion exemptions) — mitigated by tests encoding each edge rule as a fixture (U5).
- **Same-file sequencing.** Two pairs: U1/U3 share `skills/ts-pr-review/SKILL.md` (U1's renumbering lands first; U3 targets post-renumber steps 3b-3e), and U4/U5/U6 share `skills/ts-code-review/SKILL.md`. Full order: U1 → U3 → U4 → U5 → U6.
- **P3-only event behavior change** (KTD 5) — deliberate; surfaced in this plan and in the SKILL.md prose.

## Verification

1. `scripts/run-test-suites.sh` and `pytest tests/` — all existing plus new tests pass (`test-build-review-payload.sh` via test-suite discovery; `test_merge_findings.py` via pytest).
2. `scripts/run-shellcheck.sh`, `scripts/verify-scripts.sh --all`, `scripts/verify-script-refs.sh` — clean.
3. Dry-run `build-review-payload.sh` against a fixture `review.json` and linemap; inspect `review-payload.json` against the GitHub reviews API contract (`path`, `line`, `side`, `body`, `event`, `commit_id`).
4. Word-count table before/after (same assets as the Problem Frame table) recorded in the PR body.
5. Grep sweeps: no stale step/sub-step references in ts-pr-review; no inline-dispatch prose left in ts-code-review SKILL.md Stage 4 ("included below", "agent file content"); the bootstrap reference is reachable from SKILL.md.
6. Live smoke after U6: one `/ts-code-review` run on a small local diff and one `/ts-pr-review` run on a small PR — confirm clean completion, bootstrap acks on first attempt, and no session compaction; record the observed outcome in the PR body alongside the word-count table.

## Scope Boundaries

Non-goals this round:

- No changes to reviewer prompt content (`references/agents/*`, `subagent-template.md` rules) — only who reads it and how it is delivered.
- No changes to ts-pr-fix-findings, ts-plan, ts-doc-review, or ts-work beyond the convention-doc update.
- No new reviewers, severity scales, or merge-rule changes — `merge-findings.py` encodes existing rules; the only rule change is KTD 5 (P3-only event).
- No compaction-tuning of other skills; #113 scope is the review pipeline.
