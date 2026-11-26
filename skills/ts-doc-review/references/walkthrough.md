# Per-finding Walk-through

This reference defines Interactive mode's per-finding walk-through — the path the user enters by picking option A (`Review each finding one by one — accept the recommendation or choose another action`) from the routing question, plus the unified completion report that every terminal path (walk-through, best-judgment, Append-to-Open-Questions, zero findings) emits.

Interactive mode only.

---

## Routing question (the entry point)

After `safe_auto` fixes apply and synthesis produces the remaining finding set, the orchestrator asks a four-option routing question before any walk-through or bulk action runs.

Use the platform's blocking question tool (see SKILL.md — Interactive mode rules for the per-platform tool list, pre-load step, and fallback conditions). Rendering the routing question as narrative text without the numbered-list fallback is a bug.

**Question text (carries the finding set):** the question is the authoritative carrier of the finding set — the Phase 4 report printed before it is only a transcript duplicate (same rule as "Per-finding presentation" below). Above the inline cap the report carries the full findings list as the standard response while the question keeps the capped digest — the cap bounds question text only. Plain text, in this order:

1. Count line: `There are {N} findings awaiting your decision:` — the colon is present only when the findings list follows (over-cap variant ends the line at "decision"). N=1 renders `There is 1 finding awaiting your decision:`.
2. Findings list — only when N ≤ 4: one line per finding in the compressed one-line format from `references/bulk-preview.md` ("Per-finding line format"), with the plain-English severity word in place of the `[P0]` tag (`must fix` / `should fix` / `consider fixing` / `worth noting` — same mapping as the per-finding substitutions below): `{severity word} {section} — {one-line summary}`, lines near 80 columns.
3. Above 4 findings, drop the list — the count line is followed by one plain-text summary line, then the stem `A summary is too long to print here — how do you want to handle this?` (that line remains the question stem). The summary line carries severity counts using the plain-English severity words (zero-count tiers omitted) plus up to 4 section names; above 4 sections, the first 4 followed by `and {K} more`. Example: `2 must fix, 4 should fix, 3 consider fixing — sections: Requirements Trace, Scope Boundaries, Key Technical Decisions, Risks, and 4 more.` The full per-finding list stays in the Phase 4 report (the standard response) and in option A's one-by-one path.
4. Stem when the list is shown: `What should the agent do with these findings?`

**Options (fixed order; no option is labeled `(recommended)` — the routing choice is user-intent):**

```
A. Review each finding one by one — accept the recommendation or choose another action
B. Auto-resolve with best judgment — apply per-finding edits the agent can defend, surface the rest
C. Append findings to the doc's Open Questions section — unresolved items recorded in the document for a later pass — and proceed
D. Report only — take no further action
```

The per-finding `(recommended)` labeling lives inside the walk-through (option A) and the bulk preview (options B/C), where it's applied per-finding from synthesis step 3.5b's `recommended_action`. The routing question itself does not recommend one of A/B/C/D because the right route depends on user intent (engage / trust / triage / skim), not on the finding-set shape — a rule that mapped finding-set shape to routing recommendation (e.g., "most findings are Apply-shaped → recommend best-judgment") would pressure users toward automated paths in ways that conflict with the user-intent framing.

If all remaining findings are FYI-subsection-only (no `gated_auto` or `manual` findings at confidence anchor `75` or `100`), skip the routing question entirely and flow to the Phase 5 terminal question.

**Write-access gate.** At Phase 4 start, before the routing question fires, the orchestrator checks the document is writable — the append mechanic from `references/open-questions-defer.md` and the end-of-walk-through Apply batch both need write access. On failure, fire a self-contained blocking question before anything else: stem `Write check failed — the document is read-only, so the review cannot record decisions: both Apply fixes and Defer appends need write access. Retry the write check, or exit?` with exactly two options — `A. Retry the write check — re-checks now; pick this after restoring write access` and `B. Exit — ends the review report-only; nothing recorded in the document`. A read-only document is a failure to fix, not a mode to adapt around: no review proceeds past a failed gate, and once the gate passes, the routing question always shows all four options with no suppressions.

**Dispatch by selection:**

- **A** — load this walk-through (per-finding loop). Apply decisions accumulate in memory; Open-Questions defers execute inline via `references/open-questions-defer.md`; Skip decisions are recorded as no-action; `Auto-resolve with best judgment on the rest` routes through `references/bulk-preview.md`.
- **B** — load `references/bulk-preview.md` scoped to every pending `gated_auto` / `manual` finding. On Proceed, execute the plan: Apply → end-of-batch document edit; Open-Questions defers → `references/open-questions-defer.md`; Skip → no-op. On Cancel, return to the routing question.
- **C** — load `references/bulk-preview.md` with every pending finding in the Open-Questions bucket (regardless of the agent's natural recommendation). On Proceed, route every finding through `references/open-questions-defer.md`; no document edits apply. On Cancel, return to the routing question.
- **D** — do not enter any dispatch phase. Emit the completion report and flow to Phase 5 terminal question.

---

## Entry (walk-through mode)

The walk-through receives, from the orchestrator:

- The merged findings list in severity order (P0 → P1 → P2 → P3), filtered to actionable findings (confidence anchor `75` or `100` with `autofix_class` `gated_auto` or `manual`). FYI-subsection findings (anchor `50`) are not included — they surface in the final report only and have no walk-through entry.
- The run id for artifact lookups. If the orchestrator has not already generated one this session, generate it now via `${CLAUDE_PLUGIN_ROOT}/scripts/run-id.sh` — the walk-through needs it to derive the decision-log path (see "State" below) before the loop starts.
- Premise-dependency chain annotations from synthesis step 3.5c: each finding may carry `depends_on: <root_id>` or `dependents: [<ids>]`.
- The ID-to-gloss map for the document under review, derived by the orchestrator at Phase 1 (see SKILL.md Phase 1) from document headings and bullet-prefix IDs.

**Resuming an interrupted walk-through.** Before starting the loop, check for an existing decision log at `${TMPDIR:-/tmp}/ts-doc-review-decisions-<run_id>.jsonl`. If one exists and is non-empty (the session compacted or was otherwise interrupted mid-walk-through), read it back and reconstruct the in-memory decision list and Apply set from its entries, then resume the loop at the first finding not yet present in the log. Skip re-presenting already-decided findings.

Each finding's recommended action has already been normalized by synthesis step 3.5b (Deterministic Recommended-Action Tie-Break, `Skip > Defer > Apply`) — the walk-through surfaces that recommendation via the merged finding's `recommended_action` field and does not recompute it.

**Root-first iteration order.** When a finding has `dependents`, iterate it before any of its dependents regardless of severity order within the chain. The root always comes first so the user's root decision can cascade.

**Cascading root decisions.** When the user picks Skip or Defer on a finding with `dependents`:

1. Fire the platform's blocking question tool with a self-contained confirmation — the question text carries the whole decision (the root decision just made, the dependents it would cascade onto, and what each option does), same rule as "Per-finding presentation" below. A terminal echo precedes it as a transcript duplicate — the echo prints the full dependent list (every `{dependent title} — {one-line summary}` line, uncapped) as the standard response, while the question text carries the capped version (capped at 4, per the template below). Plain text, labeled lines:

   ```
   {Skip}/{Defer} chosen for Finding {N} of {M} — {plain-English title}.
   What's wrong: {one-sentence recap of why the finding was flagged}
   Proposed fix: {one-sentence recap of the fix, or "none — flagged without a concrete fix"}
   Why it works: {one-sentence recap}
   {D} dependent finding(s) — findings whose premise assumed this root's resolution — build on this one:
     {dependent title} — {one-line summary}
   Cascading applies the same {action} to all {D} and closes their individual questions; deciding individually answers each dependent separately.
   Cascade this {action} to all {D} dependents?
   ```

   The question text lists at most 4 dependent lines; above 4, list the first 4 followed by a remainder line carrying the true count and the omitted dependents' severity counts in plain words, zero tiers omitted — e.g. `and 9 more dependents — 4 must fix, 3 should fix, 2 consider fixing` (mirrors the routing over-cap summary line, so the bulk Cascade option acts on an aggregate-described set exactly as routing options B and C do; `Decide each dependent individually` remains the full-visibility path). The `{D} dependent finding(s)` count line keeps carrying the true total — the cap bounds only the per-dependent lines.

2. Options (two; each description states its effect):
   - `Cascade — apply same action to all dependents` (recommended) — applies the same action to every dependent now; no further questions about them
   - `Decide each dependent individually` — leaves every dependent open; each gets its own full question

   Labels stay self-contained per the blocking-question tool design rules.
3. On Cascade: apply the root's action to every dependent and skip those findings' walk-through entries. Persistence follows the per-action routing rules from "Per-finding routing" below — the canonical home for every cascaded decision is the in-memory decision list (annotated with `cascaded from {root_title}` and the cascaded action), plus any action-specific side effect. Each cascaded dependent's decision is appended to the on-disk decision log individually, same as a normal per-finding decision — the cascade is a fast path for the user's choice, not an exemption from persistence.
   - Cascaded `Apply` — add the dependent id to the Apply set and record in the decision list.
   - Cascaded `Defer` — invoke the open-questions append flow for the dependent and record the append outcome in the decision list. If the append fails, fall back to the per-finding failure path (Retry / Record only / Convert to Skip) for that dependent before advancing the cascade.
   - Cascaded `Skip` — record in the decision list only; no Apply-set entry, no open-questions append.

   On Individual: proceed normally — the root's dependents each get their own walk-through entry.

When the user picks Apply on a root, do NOT cascade — the premise held, so dependents each need their own decision. Proceed through the walk-through normally.

**Orphaned dependents.** If a dependent's root was rejected in a prior round and the root is suppressed this round (per R29), treat the dependent as a standalone finding with no chain context. Do not reference the missing root.

---

## Per-finding presentation

The blocking question is the single authoritative carrier of decision information: every per-finding question contains the complete finding inside its own question text. Text printed before a question collapses while the dialog is open, so the question never relies on anything printed before it. The terminal output block is only a transcript duplicate of the same content, rendered in markdown for readability — never the only place content appears. When a cap has omitted items from the question text, the duplicate also carries the full uncapped set — that is the standard response's role; it still never holds the only copy of anything the question does show.

### Question text (contains the full finding)

Fire the platform's blocking question tool (see SKILL.md — Interactive mode rules for the per-platform tool list, pre-load step, and fallback conditions). Assemble the question text in this order, plain text throughout — labeled lines, not markdown emphasis:

1. Heading line: `Finding {N} of {M} — {severity word} — {plain-English title}`
2. `What's wrong: {why_it_matters, rendered as-is}` — 1–3 sentences
3. `Proposed fix: {suggested_fix, rendered per the substitution rules below}` — 1–3 sentences
4. `Why it works: {short reasoning, grounded in a pattern cited in the document or codebase when available}` — 1–3 sentences
5. Trade-off / overlap line (only when it applies — omit otherwise): when the fix carries a user-visible trade-off (a cost, scope change, or behavior change beyond the finding itself) or overlaps a finding the user already decided on, the question says so in one line before the stem. Examples: `Trade-off: this drops the advisory enum, so anything still tagging findings advisory loses that tag.` / `Overlap: this rewrites the section you chose to Skip two findings ago.`
6. Conflict-context line (when applicable) — when contributing agents implied different actions for this finding and synthesis step 3.6 broke the tie, surface that briefly. Example: `Coherence recommends Apply; scope-guardian recommends Skip. Agent's recommendation: Skip.` The orchestrator's recommendation — the post-tie-break value — is what the menu labels "recommended."
7. Question stem: one phrase framing the single recommended action as a yes/no question. Examples: `Apply the rename?`, `Defer to Open Questions since the tradeoff is genuine?`, `Skip since the document already resolves this elsewhere?`. Never enumerate alternatives in the stem — the option list carries the alternatives. When the recommendation is close, surface the disagreement in the conflict-context line, not as a multi-option stem.

Length budgets: each labeled section is 1–3 sentences and each option description is one clause. If a finding overflows the budget, tighten the sections — nothing moves back out of the question into pre-question print.

**Substitutions (apply to question text):**

- **`{severity word}`** — plain-English severity in place of the P-tier tag: must fix (P0), should fix (P1), consider fixing (P2), worth noting (P3). P0–P2 match the header words in `references/review-output-template.md`; P3 takes "worth noting" here because that template renders P3-tier content as FYI observations, with no header word of its own. Internal enum values (`safe_auto`, `gated_auto`, `manual`, `FYI`) never appear in question text — user-facing text uses the plain-language labels per the vocabulary note in the same template.
- **`{plain-English title}`** — a 3–8 word summary suitable as a heading. Derived from the merged finding's `title` field but rephrased so it reads as observable consequence (e.g., "Implementers will pick different tiers" rather than "Section X-Y lists four tiers"). For document-review findings, observable consequence is the *effect on a reader, implementer, or downstream decision*, not runtime behavior. When the section name isn't evident from the title or the What's wrong text, append it to the heading (`— {section}`) so the user can locate the finding.
- **`What's wrong:`** — from the merged finding's `why_it_matters` field, rendered as-is; the subagent template's framing guidance ensures it's already observable-consequence-first. As-is rendering does not exempt ID tokens — gloss bare plan-item IDs at render time before the question fires (see **Glossed plan-item IDs** below).
- **`Proposed fix:`** — from the merged finding's `suggested_fix` field. Render as prose describing intent, not as raw markup — the user's job is to trust or reject the action, not review exact text. No code blocks, no diff blocks in question text; document mutations render as prose. Rules:
  - **Default — one sentence describing the effect.** What does the fix achieve, and where does it live? Prefer intent language over quoted text.
    - Good: `Drop the Advisory tier from the enum; advisory-style findings surface in an FYI subsection at the presentation layer.`
    - Good: `Add a deployment-ordering constraint requiring Units 3 and 4 in a single commit.`
    - Bad: `Change "autofix_class: [auto, gated_auto, advisory, present]" to "autofix_class: [safe_auto, gated_auto, manual]" in findings-schema.json on line 48.` — too syntax-focused for a decision loop
  - **Quoted-span budget** — question text renders plain, so quote identifiers with double quotes instead of backticks: at most 2 short quoted spans per sentence, each a single identifier, flag, or short phrase (e.g., "safe_auto", "<work-context>").
- **`Why it works:`** — grounded reasoning that, where possible, references a similar pattern already used in the document or codebase. One to three sentences.
- **Plain language** — any term without an explanation inside this or an earlier question's text gets a short inline explanation at its first use in question text (e.g., "the doc's Open Questions section — unresolved items recorded in the document for a later pass"). Only an explanation that appeared inside an earlier question's own text counts — anything printed outside a question is unreadable at decision time.
- **Glossed plan-item IDs** — any plan-item ID (`R#`, `U#`, `KTD#`, `F#`, `AE#`, a scoped D-entry ID such as `U3.D2`, or a composite token such as `U2 step 4`) in question text, the terminal duplicate, or a dependent-list line carries a parenthetical gloss naming the item in place — `R4 (explicit version tag)` — looked up from the per-round ID-to-gloss map (orchestrator context, derived at Phase 1), falling back to the document the orchestrator holds in context from the Phase 1 read. Per-token decision procedure: already followed by a parenthetical gloss → pass through unchanged; the item's function is named in the same clause as the ID token → no gloss added (`KTD5's own bootstrap chown/repair` — the clause is the gloss); title lines and heading lines always gloss — no exemption; the item resolvable in the document → insert `ID (item name)`; not resolvable → pass through bare — never invent a gloss. The gloss lands at question-assembly time, so the terminal duplicate mirrors the glossed question and the duplicates-rewrite-nothing rule (`docs/solutions/developer-experience/self-contained-blocking-questions-skill-walkthroughs.md`) sees no divergence.

### Pre-fire audit

Before emitting any text rendered from the findings set — routing-question digest lines, bulk-preview one-liners, per-finding questions, dependent-list lines, completion-report lines — run one audit over the assembled text: enumerate every ID token (`R#`, `U#`, `KTD#`, `F#`, `AE#`, scoped D-entry IDs, composite tokens), gloss resolvable bare tokens per **Glossed plan-item IDs** above in a single self-healing pass, then stop — the canonical rule's idempotence clause (it fires only on un-glossed tokens) means a second application would double-gloss — and confirm every remaining bare token is unresolvable-class (the map and the held document both lack it), so it passes bare per the never-invent clause. The audit completes before the question and its terminal duplicate render, so the duplicate mirrors glossed text and the duplicates-rewrite-nothing rule stays intact. Mode applicability: this file's surfaces audit here in interactive runs; in headless runs the envelope runs the same audit at its emission (see `references/synthesis-and-presentation.md`).

### Terminal output block (transcript duplicate)

Before firing the question, print the same content as markdown for transcript readability: `## Finding {N} of {M} — {severity word} {plain-English title}` heading, then the three labeled sections with bold labels and blank lines between, then the trade-off and conflict-context lines when present. It duplicates the question content — adds, drops, and rewrites nothing. The question text, not this block, is what the user reads to decide.

### Confirmation between findings

After the user answers and before printing the next finding's terminal block, emit a one-line confirmation of the action taken. Examples: `→ Applied. Edit staged at "Scope Boundaries" section.`, `→ Deferred. Entry appended to "## Deferred / Open Questions".`, `→ Skipped.`

### Options (four; adapted as noted)

These four options are the **complete, exclusive set** for the regular per-finding question. Fixed order — never reorder, never add, never substitute. In particular, **`Acknowledge` is NOT one of these options** — it appears only in the no-fix sub-question described under "Per-finding routing" below, which fires only when the user picks Apply on a finding that lacks a `suggested_fix`. Importing `Acknowledge` into the regular menu (in place of D, or as a fifth option) is a bug — it silently drops the `Auto-resolve with best judgment on the rest` workflow shortcut, and surfacing `Acknowledge` outside the no-fix path mislabels the user's choice in the completion report's bucket counts.

Each option pairs its label with a one-clause description of the effect on the document:

```
A. Apply the proposed fix  (recommended) — stages the fix; the document is edited in the end-of-walk-through batch
B. Defer — appends the finding to the doc's Open Questions section now; no fix is applied
C. Skip — leaves the document unchanged and records no follow-up
D. Auto-resolve with best judgment on the rest — routes this and every remaining finding through the bulk preview for one approval
```

**Mark the post-tie-break recommendation with `(recommended)` on its option label.** Required, not optional — the label shown above always carries it on whichever option won the tie-break. Only A, B, or C can carry it — synthesis emits `recommended_action` as Apply/Defer/Skip, which maps to A/B/C. D (`Auto-resolve with best judgment on the rest`) is a workflow shortcut for bulk execution across remaining findings, not a finding-level resolution action, so it is never marked `(recommended)`.

When reviewers disagreed or evidence cuts against the default, still mark one option — whichever synthesis produced — and surface the disagreement in the conflict-context line.

### Adaptations

- **N=1 (exactly one pending finding):** the question's heading line omits `Finding N of M`, becoming `{severity word} — {plain-English title}` (the terminal duplicate's heading follows suit). Option D (`Auto-resolve with best judgment on the rest`) is suppressed because no subsequent findings exist — the menu shows three options: Apply / Defer / Skip.

Only when `ToolSearch` explicitly returns no match or the tool call errors — or on a platform with no blocking question tool — fall back to presenting the options as a numbered list and waiting for the user's next reply.

---

## Per-finding routing

For each finding's answer, record the outcome in the in-memory decision list **and** append the same entry to the on-disk decision log (see "State" below) before advancing to the next finding. The disk write happens every turn, not just at loop end — that's what makes decisions survive a mid-walk-through interruption.

- **Apply the proposed fix** — add the finding's id to an in-memory Apply set. Advance to the next finding. Do not edit the document inline — Apply accumulates for end-of-walk-through batch execution. **No-fix guard:** if the merged finding has no `suggested_fix` (possible on `manual` findings where the agent flagged the issue as observation without a concrete resolution), Apply is not executable. Do not add the finding to the Apply set. Instead, surface the no-fix sub-question described below before advancing.
- **Defer — append to Open Questions section** — invoke the append flow from `references/open-questions-defer.md`. The walk-through's position indicator stays on the current finding during any failure-path sub-question (Retry / Record only / Convert to Skip). On success, record the append location and reference in the in-memory decision list and advance. On conversion-to-Skip from the failure path, advance with the failure noted in the completion report.
- **Skip — don't apply, don't append** — record Skip in the in-memory decision list. Advance. No side effects.
- **Auto-resolve with best judgment on the rest** — exit the walk-through loop. Dispatch the bulk preview from `references/bulk-preview.md`, scoped to the current finding and everything not yet decided. The preview header reports the count of already-decided findings ("K already decided"). If the user picks Cancel from the preview, return to the current finding's per-finding question (not to the routing question). If the user picks Proceed, execute the plan per `references/bulk-preview.md` — Apply findings join the in-memory Apply set with the ones the user already picked, Defer findings route through `references/open-questions-defer.md`, Skip is no-op — then proceed to end-of-walk-through execution. Every finding resolved through the bulk preview also gets a decision-log entry appended at the moment it's resolved, same as the per-finding loop.

### No-fix sub-question (Apply picked on a finding with no `suggested_fix`)

This sub-question — and the `Acknowledge without applying` option in particular — is **exclusive to the no-fix path**. It fires only after the user picks Apply on a finding whose merged record has no `suggested_fix`. Do not surface this sub-question, or its `Acknowledge` option, in the regular per-finding menu. The regular menu's fourth option is always `Auto-resolve with best judgment on the rest` (per "Options" above), never `Acknowledge`.

Synthesis step 3.5b demotes the default recommendation from Apply to Defer for any merged finding without a `suggested_fix`, so `(recommended)` never lands on Apply for these findings. But the menu still lets the user pick Apply manually. When that happens, do not add the finding to the Apply set — the execution pass has no edit payload to apply, which would either fail the batch or record a misleading "applied" outcome.

Fire a blocking sub-question using the platform's question tool. Same self-containment rule as the regular per-finding question: the question text carries the finding, because nothing printed before the dialog is readable while it's open. Position indicator stays on the current finding while the sub-question is open. Plain text:

```
Finding {N} of {M} — {severity word} — {plain-English title}
What's wrong: {why_it_matters, rendered as-is}
Proposed fix: None — the review surfaced the issue without a concrete fix, so Apply has nothing to execute.
How should the agent proceed?
```

`Why it works:` is omitted here — there is no proposed fix to justify; the Proposed fix line itself states why Apply isn't executable.

**Options (fixed order; each description states its effect):**

```
A. Defer to Open Questions  (recommended) — appends the finding to the doc's Open Questions section now; no fix is applied
B. Skip — leaves the document unchanged and records no follow-up
C. Acknowledge without applying — records it as acknowledged in the completion report; no document edit
```

**Routing:**

- **A. Defer to Open Questions** — invoke the append flow from `references/open-questions-defer.md` as though the user had originally picked Defer. Failure-path handling is identical (Retry / Record only / Convert to Skip). On success, record the append location in the decision list (annotated `redirected from Apply — no suggested_fix`) and advance.
- **B. Skip** — record Skip in the decision list (annotated `redirected from Apply — no suggested_fix`). Advance. No side effects.
- **C. Acknowledge without applying** — record the finding in the decision list as `acknowledged` (annotated `Apply picked but no suggested_fix — no edit dispatched`). Do not add to the Apply set. Advance. The completion report surfaces Acknowledged as its own dedicated bucket with its own count, its own per-finding action label, and its own position in the report ordering (`Applied / Deferred / Skipped / Acknowledged`) — see "Minimum required fields" and "Report ordering" in the unified completion report section below for the full contract. The acknowledgement reason is surfaced on each per-finding line. For round-to-round suppression (distinct from report display), Acknowledged decisions carry forward in the multi-round decision primer as a rejected-class decision alongside Skip and Defer so round-N+1 synthesis suppresses re-raises via R29 — semantically the user saw the finding, chose not to act, and wants it recorded, which is equivalent to Skip for suppression purposes but remains its own bucket in the report.

**Cascading roots.** When the finding is a root with dependents and the user picks A (Defer) or B (Skip) from this sub-question, run the cascade confirmation in "Cascading root decisions" above — treat the sub-question's choice as the root's effective action. Option C (Acknowledge) does not cascade; the root is recorded as acknowledged and dependents each get their own walk-through entry.

---

## Override rule

"Override" means the user picks a different preset action (Defer or Skip in place of Apply, or Apply in place of the agent's recommendation). No inline freeform custom-fix authoring — the walk-through is a decision loop, not a pair-editing surface. A user who wants a variant of the proposed fix picks Skip and hand-edits outside the flow; if they also want the finding tracked, they can Defer first and edit afterward.

---

## State

The orchestrator maintains two representations of the same state, kept in sync every turn:

- **In-memory** — an Apply set (finding ids the user picked Apply on), a decision list (every answered finding with its action and any metadata like `append_location` for Deferred or `reason` for Skipped), and the current position in the findings list. Used for fast access during the loop (e.g., computing "K already decided" for the bulk-preview handoff).
- **On disk** — a decision-log file at `${TMPDIR:-/tmp}/ts-doc-review-decisions-<run_id>.jsonl`, one JSON object per line, appended immediately after each finding is routed (see "Per-finding routing" above). Each line carries at minimum: `finding_id`, `action` (`apply` / `defer` / `skip` / `acknowledge`), `timestamp`, and the same metadata the in-memory entry carries (`append_location`, `reason`, cascade annotations). The file is append-only — the orchestrator never rewrites or truncates it mid-walk-through, so a partial write from an interrupted turn can't corrupt already-recorded decisions.

**Why both.** The in-memory copy is what the loop actually reads from turn to turn — it's cheap and doesn't require a disk round-trip for every check. The disk copy exists purely for durability: if the session compacts, the user cancels mid-prompt, or the network drops, the in-memory list is gone but the decision log is not. Resuming re-hydrates the in-memory state from disk (see "Resuming an interrupted walk-through" above) instead of re-asking the user about findings already answered.

**What's still not durable.** The Apply set's *document edits* remain batched at end-of-walk-through (see "End-of-walk-through execution" below) — an Apply decision is persisted to the decision log the moment it's made, but the actual document mutation doesn't happen until the batch pass. If the session is interrupted before that pass runs, the decision log still shows the finding as `apply`, so a resumed session can complete the batch without re-asking the user; it does not silently lose the decision the way the old in-memory-only design did.

Cross-session persistence (a *new* invocation of ts-doc-review after the prior one exited cleanly) remains out of scope — the decision log is scoped to a single run id and is not consulted by a fresh run.

---

## End-of-walk-through execution

After the loop terminates — either every finding has been answered, or the user took `Auto-resolve with best judgment on the rest → Proceed` — the walk-through hands off to the execution phase:

1. **Apply set:** in a single pass, the orchestrator applies every accumulated Apply-set finding's `suggested_fix` to the document. Document edits happen inline via the platform's edit tool — ts-doc-review has no batch-fixer subagent (per scope boundary); the orchestrator performs the edits directly, since `gated_auto` and `manual` fixes for documents are single-file markdown changes with no cross-file dependencies. **Defensive no-fix check:** before dispatching the edit for each Apply-set entry, verify the merged finding carries a `suggested_fix`. If it does not (the decision-time no-fix guard in "Per-finding routing" should prevent this, but treat it as a defensive fallback), skip the edit, record the finding in the completion report's failure section with reason `Apply skipped — no suggested_fix available`, and continue the batch. Do not fail the entire pass because one Apply-set entry lacks a fix. On a plan-classified document (see "D-entry emission in the batch pass" below), each landed edit is followed in the same pass by its D-entry write — the pairing is part of this batch, not a separate pass.
2. **Defer set:** already executed inline during the walk-through via `references/open-questions-defer.md`. Nothing to dispatch here.
3. **Skip:** no-op.

### Placement of created sections

An Apply-set fix that creates content in Scope Boundaries, Risks & Dependencies, Open Questions, or Assumptions — a section the document lacked — inserts the new section per the section-order rule cross-read from `${CLAUDE_PLUGIN_ROOT}/skills/ts-plan/references/markdown-rendering.md` ("Section order (plan documents)"). Sibling skills sit side by side under the plugin root in both the repository checkout and the marketplace cache, so this path resolves in both; on a platform where `${CLAUDE_PLUGIN_ROOT}` is unset or the file is missing, say so visibly and fall back per the plugin path-resolution rule (`docs/solutions/tooling-decisions/claude-code-plugin-script-path-resolution.md`) — never silently skip the contract read, because an unread contract is an unenforced one. Existing sections are never relocated — a legacy document's late sections keep their position, so a created section may anchor far from its late sibling; mixed adjacency is the accepted outcome, not a defect to fix while applying other edits. The rule binds placement only — it never authorizes creating a section; creation remains governed by the fix's own scope rules.

### D-entry emission in the batch pass

Read the D-entry format, the Source closed list, and the supersession mechanics from `${CLAUDE_PLUGIN_ROOT}/skills/ts-plan/references/plan-sections.md` ("Decision log (D-entries)"), together with its glossed-references rule. Sibling skills sit side by side under the plugin root in both the repository checkout and the marketplace cache, so this path resolves in both; on a platform where `${CLAUDE_PLUGIN_ROOT}` is unset or the file is missing, say so visibly and fall back per the plugin path-resolution rule (`docs/solutions/tooling-decisions/claude-code-plugin-script-path-resolution.md`) — never silently skip the contract read, because an unread contract is an unenforced one. Emission scope, recorded here where the two contracts meet: Apply edits and meaning-changing fixes emit D-entries; Defer's durable record is its Open Questions entry (already appended inline during the walk-through), and Skip and Acknowledge stay in the decision list and completion report — they stage no content change, so the ledger has nothing to record.

**Classification gate.** Consult the Phase 1 document classification once at batch start: emission fires only for `plan`-classified documents, and the gate never re-classifies — it reads the same settled Phase 1 result the primer and routing used, so ledger and review cannot disagree about the document's classification. Requirements-classified documents take the batch edits only: no D-entries are written, and the completion report omits the D-entry line.

**Per-edit mechanics.** After each Apply-set edit lands, emit its D-entry into the section the edit touched, in the same pass:

- **Prefix** — take the section prefix from the governing heading or unit ID where the edit landed, read from the document's live structure, never from the finding's `section` string: `section` is free text and can name a location the headings do not carry, while a scoped ID must match the document's real structure.
- **Sequence** — scan the section's D-entry headings at emission time — superseded struck-through entries included — and continue after the highest number present, so a second round on the same section keeps numbering monotonic without renumbering anything.
- **Source** — `user`, with the originating reviewer named in the context phrase (e.g., `user, <date> approved review agent coherence's proposal`): the user made the decision, and naming whose proposal they approved keeps the ledger auditable.
- **Date** — run `date +%F` at emission; never infer the date from session memory or the document.

**Re-read before every write.** The batch pass extends the concurrent-edit discipline from `references/open-questions-defer.md`: re-read the document from disk before each edit-and-entry pair, not once at batch start — the user may be editing alongside a long batch, and a stale read would clobber their changes.

**Failure paths.**

- **Edit fails** — record the finding in the completion report's failure section, emit no D-entry for it, and continue the batch: an entry for an edit that did not land would record a decision the document does not carry.
- **D-entry write fails after the edit landed** — retry the write in-pass; on persistent failure, surface it prominently in the report's failure section and continue the batch. An edit that landed without its ledger entry is the exact unlogged-change cascade this emission exists to stop, so the failure is never silently skipped.

**Supersession.** Together with the classification gate at batch start, scan the target sections' live D-entries. When an Apply contradicts an existing entry, supersede it per plan-sections — old heading struck through, `Status:` line first naming the replacement by full scoped ID, Decision/Why lines left legible. A `Source: user` entry supersedes only through a user Apply — this batch is a user decision, so it qualifies — and the replacement entry also carries `Source: user`, because protection transfers down the chain and only the live entry needs guarding.

**KTD obligations carry over** from plan-sections: a plan-wide decision (no single governing section) logs its D-entry in the KTD section and each affected unit carries a glossed one-line pointer; a D-entry that changes what a KTD says updates the KTD text and adds the glossed amendment pointer.

After execution completes, delete the decision-log file for this run id — the walk-through finished normally, so there's nothing left to resume. If a later round of the same session starts a new walk-through (e.g., re-verification after fixes land), it generates a fresh run id and a fresh log rather than reusing the deleted one.

After execution completes (or after `Auto-resolve with best judgment on the rest → Cancel` followed by the user working through remaining findings one at a time, or after the loop runs to completion), emit the unified completion report described below.

---

## Unified completion report

Every terminal path of Interactive mode emits the same completion report structure. This covers:

- Walk-through completed (all findings answered)
- Walk-through bailed via `Auto-resolve with best judgment on the rest → Proceed`
- Top-level best-judgment (routing option B) completed
- Top-level Append-to-Open-Questions (routing option C) completed
- Zero findings after `safe_auto` (routing question was skipped — the completion summary is a one-line degenerate case of this structure)

### Minimum required fields

- **Per-finding entries:** for every finding the flow touched, a line with — at minimum — title, severity, the action taken (Applied / Deferred / Skipped / Acknowledged), the append location for Deferred entries, a one-line reason for Skipped entries (grounded in the finding's confidence anchor or the one-line `why_it_matters` snippet), and the acknowledgement reason for Acknowledged entries (e.g., `Apply picked but no suggested_fix available`). Any `why_it_matters` snippet reused in a per-finding line carries the same plan-item ID gloss the Substitutions block requires — the report applies the same rule, with no separate wording.
- **Summary counts by action:** totals per bucket (e.g., `4 applied, 2 deferred, 2 skipped`). Include an `acknowledged` count when any entries land in that bucket; omit the label when the count is zero.
- **D-entry line:** when the run emitted D-entries, a line listing the count and the scoped IDs (e.g., `Decision entries written: 3 — U2.D1, KTD1.D1, Risks.D2`), rendered alongside the summary counts. The count equals edits that actually landed, never the Apply-set size — a failed edit writes no entry — and the line is omitted entirely when the count is zero, which covers the all-Defer and all-Skip terminals and every requirements-classified run.
- **Failures called out explicitly:** any Apply that failed (e.g., document write error, or the defensive no-fix fallback skipping an Apply-set entry), any Open-Questions append that failed, and any D-entry write that failed persistently after its edit landed. Failures surface above the per-finding list so they are not missed.
- **End-of-review verdict:** carried over from Phase 4's Coverage section.

### Report ordering

Failures first (above the per-finding list), then per-finding entries grouped by action bucket in the order `Applied / Deferred / Skipped / Acknowledged`, then summary counts, then Coverage (FYI observations, residual concerns), then the verdict. Omit any bucket whose count is zero.

### Zero-findings degenerate case

When the routing question was skipped because no `gated_auto` / `manual` findings at confidence anchor `75` or `100` remained after `safe_auto`, the completion report collapses to its summary-counts + verdict form with one added line — the count of `safe_auto` fixes applied. The summary wording:

No FYI or residual concerns:

```
All findings resolved — 3 fixes applied.

Verdict: Ready.
```

FYI or residual concerns remain:

```
All actionable findings resolved — 3 fixes applied. (2 FYI observations, 1 residual concern remain in the report.)

Verdict: Ready.
```

On a plan-classified document whose fixes emitted D-entries, the same one-line summary appends the ledger count and scoped IDs (e.g., `All findings resolved — 3 fixes applied; decision entries: Overview.D1, Risks.D2`), omitted when the count is zero — a requirements document's degenerate line is unchanged.

---

## Execution posture

The walk-through is operationally read-only with respect to the project except for five permitted writes: the in-memory Apply set / decision list (managed by the orchestrator), the on-disk decision log (`${TMPDIR:-/tmp}/ts-doc-review-decisions-<run_id>.jsonl`, appended after every finding), the in-doc Open Questions appends (external side effects managed by `references/open-questions-defer.md`), the Phase 4 `safe_auto` fix pass (the silent-apply pass in `references/synthesis-and-presentation.md`; on a plan-classified document each meaning-changing fix lands paired with its D-entry), and the end-of-walk-through batch document edits (the orchestrator's final Apply pass, whose landed edits are paired in the same pass with their D-entries on a plan-classified document — emission rides the edit passes, it is not an additional write surface). Those agents remain strictly read-only. Unlike `ts-code-review`, there is no fixer subagent — the orchestrator owns the document edit directly.
