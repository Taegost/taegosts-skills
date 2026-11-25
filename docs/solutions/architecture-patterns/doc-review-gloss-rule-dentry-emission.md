---
title: Centralized gloss rule and D-entry emission across ts-doc-review surfaces
date: 2026-11-24
category: docs/solutions/architecture-patterns
module: ts-doc-review
problem_type: architecture_pattern
component: documentation
severity: medium
applies_when:
  - Multiple render surfaces present the same domain tokens (plan-item IDs and similar) and each restates its own gloss rule
  - A consumer skill needs to read a contract file owned by a sibling skill
  - Meaning-changing edit passes must leave durable decision records (ledger entries) instead of chat-only rationale
  - Downstream handoff passes must verify that claimed instruction obligations actually landed in the emitted document
tags:
  - doc-review
  - plan-handoff
  - d-entry
  - gloss
  - cross-skill-reference
  - decision-ledger
  - render-surface
  - substitutions
---

# Centralized gloss rule and D-entry emission across ts-doc-review surfaces

## Context

Two structural gaps in `ts-doc-review`, both filed from a real plan-review run (issues #227 and #228):

1. **Render gloss (#227).** Every downstream render surface — the interactive walkthrough question, the headless envelope's `Why:` lines, the bulk-preview per-finding one-liners, and the review-output-template table cells — passed bare plan-item IDs (`R3`, `U2 step 4`, `KTD5`) through to the user. The reader had to round-trip to the plan document to decode a finding, defeating the glossed-references rule that `skills/ts-plan/references/plan-sections.md` already owns.
2. **D-entry emission (#228).** Walkthrough Apply decisions and meaning-changing `safe_auto` fixes edited the plan document with zero decision-ledger entries. The run's decision-log JSONL is deleted after a successful run, so the chat transcript was the only record of why a constraint exists — and a later tightening pass could legitimately strip a user-approved constraint because its approval was nowhere in the document.

Both gaps share one root cause: ts-doc-review never reads ts-plan's section contract, and no rule in its render or execution instructions binds it to that contract.

Approaches rejected before landing:

- **Four per-surface gloss rules** — copying the rule into each render surface produces four drifting copies. The landed design keeps one canonical rule; the other surfaces cross-reference it ("this envelope applies the rule, it does not restate it").
- **Restating the D-entry format inside ts-doc-review** (rejected at scoping, two rounds) — the first shared-file proposal was revised to owner-as-shared-contract: `plan-sections.md` stays the single owner and gains a consumer-declaration line; ts-doc-review cross-reads it.
- **Re-deriving document classification at execution time** — classification is content-shape-based and settled at Phase 1; re-deriving it at the batch pass invites divergence between the gate and the primer.

## Guidance

All changes land as instruction prose in skill reference files, verified by the existing suites (no new tooling). Landed on branch `feat/doc-review-gloss-dentry` (issues #227/#228).

### One canonical gloss rule at the render boundary

`skills/ts-doc-review/references/walkthrough.md` ("Per-finding presentation" → Substitutions) holds the single **Glossed plan-item IDs** rule. Token list: `R#`, `U#`, `KTD#`, `F#`, `AE#`, scoped D-entry IDs such as `U3.D2`, composite tokens such as `U2 step 4`. Per-token decision procedure:

- Already followed by a parenthetical gloss → pass through unchanged (idempotence: render fires only on un-glossed tokens).
- The surrounding sentence already states the item's substance (`KTD5's own bootstrap chown/repair` — the sentence is the gloss) → no gloss added.
- The item is resolvable in the document under review (the orchestrator holds it from the Phase 1 read) → insert `ID (item name)`, e.g. `R4 (explicit version tag)`.
- Not resolvable → pass through bare. Never invent a gloss.

The gloss lands at question-assembly time, so the terminal transcript duplicate mirrors the glossed question and the duplicates-rewrite-nothing rule sees no divergence. The three other surfaces cross-reference, not restate: the synthesis envelope's `Why:` lines and `Dependents` sub-block, the bulk-preview one-liners (with a width-fit rule — fitting by tight paraphrase, not truncation; re-gloss after fitting when the paraphrase drops a glossed token), and the review-output-template row cells. Source-side, the reviewer contract (`subagent-template.md`, read by every reviewer at dispatch) instructs gloss on first use in `why_it_matters` and `suggested_fix` — render re-glosses whatever source misses, and the idempotence check keeps the two layers from double-applying.

### D-entry emission folded into the edit passes

Emission rides the two document-write passes; it is not a separate pass. Both emission sites cross-read the format, Source closed list, meaning-change trigger, and supersession mechanics from `${CLAUDE_PLUGIN_ROOT}/skills/ts-plan/references/plan-sections.md` ("Decision log (D-entries)") — the first cross-skill reference-file read in this repo. The owner file gains one consumer-declaration line: consumed by ts-doc-review's walk-through and `safe_auto` passes; changes propagate to both skills.

- **Classification gate:** consult the Phase 1 classification once at batch start; emission fires only for `plan`-classified documents. Requirements-classified documents take edits only, no D-entries, report omits the line.
- **Per-edit mechanics:** prefix from the governing heading or unit ID where the edit landed, read from the document's live structure — never from the finding's `section` free-text string. Sequence continues from a live scan of the section's D-entry headings. Source per path: walkthrough Apply logs `user` with the originating reviewer named in the context phrase; bulk Proceed logs `user` with a batch-level phrase; `safe_auto` logs `review agent <Name>`. Date from `date +%F` at emission, never inferred. Re-read the document before each edit-and-entry pair.
- **Failure paths:** a failed edit writes no D-entry and the batch continues; a D-entry write that fails after its edit landed retries in-pass, then surfaces prominently — an unlogged landed edit is the exact cascade this stops.
- **Supersession:** a contradicting Apply supersedes per plan-sections — struck heading, `Status:` line first naming the replacement by full scoped ID, `Source: user` protection transferring to the replacement.
- **Completion report:** a D-entry line listing count and scoped IDs; the count equals edits that actually landed, never Apply-set size; omitted at zero (covering all-Defer, all-Skip, and requirements-classified runs).

### Reviewer-contract ledger suppression

The reviewer contract gains an unconditional exclusion: D-entry blocks are the workflow's decision ledger — do not flag their existence, format, placement, or provenance; content findings stay fully in scope; any finding whose fix would change, remove, or contradict a `Source: user` entry names that conflict explicitly. Without it, the next review round flags the ledger this workflow just wrote.

### Verified handoff

`skills/ts-plan/references/plan-handoff.md` option 2 verifies on return: scan the level-4 `#### <section>.D<seq>.` headings for every D-entry obligation the completion report claims — scoped to claimed obligations, because Skip/Defer/Acknowledge legitimately emit none — and carry the result into the re-rendered menu summary line. A gap offers consent-gated repair, never an auto-applied write.

## Why This Matters

**Gloss at the boundary, once.** Bare IDs enter through one field (`why_it_matters`/`suggested_fix`) and exit through four surfaces. Source-side glossing reduces frequency; render-side glossing guarantees coverage; the idempotence check prevents two divergent glosses of the same ID. One canonical copy plus cross-references means the rule cannot drift between surfaces.

**Emission in-pass, not as a phase.** A separate emission pass would re-derive context (classification, section structure, sequence state) that the edit pass already holds, and would decouple the edit from its ledger entry — reintroducing exactly the unlogged-edit gap. Pairing them means a landed edit and its entry succeed or fail visibly together, and sequence numbering derives from a live scan rather than in-memory state a second round could stale.

**Owner-as-shared-contract beats duplication.** The D-entry format, Source closed list, and supersession mechanics are normative in `plan-sections.md`; a second copy inside ts-doc-review would drift the first time either skill changed. The `${CLAUDE_PLUGIN_ROOT}`-anchored sibling path is the only form that resolves in both the repository checkout and the marketplace cache. The guarded visible fallback converts a silent contract miss into a reported failure, and the consumer-declaration line makes the coupling discoverable from the owner side.

**Verification closes the trust loop.** Emission prose alone is a claim; the handoff's heading scan on return turns the claim into a checked result reported where the user next makes a choice, mirroring ts-plan SKILL.md Phase 0.1's end-of-session verify rule — a review that claims ledger writes is checked as part of returning, not trusted.

## When to Apply

- A skill's output references another skill's normative contract → bind the read explicitly: `${CLAUDE_PLUGIN_ROOT}/skills/<owner>/references/<file>.md` cross-read with a guarded visible fallback at the exact site that needs the contract, plus a consumer-declaration line in the owner file. Never duplicate the contract text, never rely on CWD-relative paths, never skip the read silently.
- Multiple surfaces render the same fields → put the per-item rule at one render boundary and cross-reference it from the others; pair with a source-side instruction in the subagent contract so dispatch-time reads reach every agent without touching role prompts.
- A change pass must leave audit records → fold the ledger write into the pass that performs the change, sharing one failure domain: edit fails → no entry; entry fails after edit landed → retry in-pass, then a prominent report.
- Deriving document-structure identifiers → read them from the document's live headings, never from free-text fields; continue sequence numbers from a live scan, not remembered state (keeps second rounds monotonic).
- Gating on an earlier determination → consult the settled result once; do not re-derive it at execution time.
- Verifying claimed writes on return → scope to claimed obligations ("verify what the report claims emitted"), report the verified count at the next decision point, and make repair consent-gated.
- A workflow writes structured blocks into reviewed documents → give its reviewer contract an own-output suppression rule (existence/format/placement/provenance out of scope; content stays in scope).

## Examples

Emitted D-entry shape (all locked by `tests/scripts/test_extract_ktds.py::test_dentry_emitted_shape_with_superseded_strikethrough` — parses with no extractor changes, nothing leaks into the KTD spec):

```markdown
#### KTD1.D1. Opaque cursor token
**Status:** superseded by KTD1.D2 (opaque cursor token)
**Decision:** The cursor is an opaque, signed token.
**Why:** Decodable cursors invite client-side parsing.
**Source:** user, 2026-11-20 plan discussion
```

Headless envelope line carrying the emitted ID as the verification signal:

```markdown
- Overview: corrected the unit count from 6 to 5 (feasibility; Overview.D1)
```

Completion-report ledger line (omitted at zero):

```markdown
Decision entries written: 3 — U2.D1, KTD1.D1, Risks.D2
```

## Related

- `docs/solutions/tooling-decisions/claude-code-plugin-script-path-resolution.md` — the `${CLAUDE_PLUGIN_ROOT}` substitution tiers this pattern extends from scripts to reference-doc reads
- `docs/solutions/developer-experience/self-contained-blocking-questions-skill-walkthroughs.md` — the question-side counterpart; this doc's gloss rule is the render-side half of the same self-contained-presentation standard
- `docs/solutions/tooling-decisions/skills-lack-plan-ktd-validation.md` — same verify-claims-against-artifacts family, different artifact
- Issues #227, #228 (closed by branch `feat/doc-review-gloss-dentry`); origin instructions in `docs/plans/ts-audhd-retrofit-instructions.md`
