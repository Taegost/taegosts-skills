---
title: Canonical section-order ownership and pre-fire ID-gloss audit across plan and doc-review surfaces
date: 2026-11-26
category: docs/solutions/design-patterns
module: ts-plan and ts-doc-review skill instruction prose
problem_type: design_pattern
component: documentation
severity: medium
applies_when:
  - One rule must hold across several user-facing surfaces of a skill or across skill boundaries
  - De-facto ordering or behavior lives implicitly in multiple catalog enumerations with no owner file
  - An existing rule needs tightening without leaving stacked restatements behind
  - IDs rendered to users need consistent glossing derivable before the first render
related_components:
  - development_workflow
tags:
  - instruction-prose
  - single-source-of-truth
  - cross-reference
  - replace-not-stack
  - pre-fire-audit
  - section-order
  - glossing
  - consistency
---

# Canonical section-order ownership and pre-fire ID-gloss audit across plan and doc-review surfaces

## Context

Two consistency gaps in a repo whose product is instruction prose, filed from a real plan-review run and landed together on branch `fix/plan-section-order-gloss-audit` (issues #234 and #233):

1. **Section order (#234).** Plan documents rendered Scope Boundaries, Risks & Dependencies, Open Questions, and Assumptions below Implementation Units — readers hit implementation detail before the sections that force scope and risk decisions. No single file owned section order. The include-when-material catalog in `skills/ts-plan/references/plan-sections.md` carried a listing order, the "Section anatomy" list in `skills/ts-plan/references/markdown-rendering.md` carried a different one (it even contradicted the catalog, listing Implementation Units before Key Technical Decisions), and `SKILL.md` Phase 4.2 carried a third ordering inside its catalog summary — three de-facto orderings, none declared normative.
2. **Gloss consistency (#233).** Plan-item ID glossing (`U3 (payment retry loop)` vs a bare `U3`) was inconsistent across ts-doc-review's user-facing surfaces: the same finding rendered glossed in one surface and bare in another. Root cause: the gloss rule lived inside substitution prose with no assembly-time check, the sentence-states-substance exemption had been stretched from full sentences to title fragments, and the per-token procedure was never run over the assembled text.

An existing learning (`docs/solutions/architecture-patterns/doc-review-gloss-rule-dentry-emission.md`) already recorded the one-canonical-copy pattern for the gloss rule. This run applied that pattern to a new rule class (presentation order) and extended the gloss machinery itself.

## Guidance

All changes are instruction prose in skill reference files, verified by dry-run scenarios and the existing suites — no runtime code, no schema changes.

### One-canonical-copy ownership, applied to a new rule class

An order/presentation rule lives in exactly one reference file: the file that owns rendering. Every other surface carries a pointer line, never a restatement.

- The owner is a new "Section order (plan documents)" subsection in `skills/ts-plan/references/markdown-rendering.md` (added by commit ccb3745, U1). It states the full render order (Summary → Problem Frame → Requirements → Key Technical Decisions → Scope Boundaries → Risks & Dependencies → Open Questions → Assumptions → System-Wide Impact → Acceptance Examples → Documentation / Operational Notes → High-Level Technical Design → Implementation Units → Sources & Research), the skip-absent rule (which sections exist never changes where present ones sit), the front-block anchor rule, the never-below-Implementation-Units clause, and a placement-only clause (the rule orders sections; it never adds or drops one — inclusion criteria stay owned by `plan-sections.md`).
- The catalogs that carry de-facto ordering were reordered to match and given one-line pointers, not restatements. `plan-sections.md` gained "This list names membership, not render order — section order is owned by `references/markdown-rendering.md`" at its hard floor and "Listing order here is catalog order, not render order" at the end of the include-when-material list. `SKILL.md` Phase 4.2's catalog enumeration was re-sequenced to the render order.

The choice of owner matters. `plan-sections.md`'s own header disclaims page-presentation jurisdiction, so restating the order rule there would have created a second drifting copy — the exact anti-pattern the gloss-rule learning records. Put the canonical copy where the jurisdiction already sits, and convert every other enumeration into a pointer.

### De-facto-ordering carriers bite after the gates

Any list that enumerates items in order silently becomes a second copy of the order rule — including lists nobody thought of as order-bearing: section catalogs, `SKILL.md` summary enumerations, anatomy lists. When you introduce a canonical order, every ordered enumeration must be aligned to it, or it contradicts the rule one line below its own pointer.

This bit after implementation passed its gates: dry-run scenario tracing (commit 577ae3d, U7) found `SKILL.md`'s Phase 4.2 enumeration and `markdown-rendering.md`'s Section anatomy list still carrying the old order — two contradicting copies inside the owning skill itself. The fix was mechanical once found, but finding them by inspection had already failed once.

**Lesson: when landing an order rule, grep for every enumeration of the ordered set before declaring done.** Treat "list the sections/items in order" occurrences as rule restatements even when they read as summaries.

### Cross-skill contract read with consumer declaration

The consuming skill cross-reads the owning file at the exact site that needs the rule, with a guarded visible fallback. From `skills/ts-doc-review/references/walkthrough.md` ("Placement of created sections"): fixes creating Scope Boundaries, Risks & Dependencies, Open Questions, or Assumptions insert the section per the order rule cross-read from `${CLAUDE_PLUGIN_ROOT}/skills/ts-plan/references/markdown-rendering.md` ("Section order (plan documents)"); on a platform where the variable is unset or the file is missing, say so visibly and fall back per the plugin path-resolution rule — never silently skip the contract read, because an unread contract is an unenforced one. The plugin-root-anchored sibling path is the only form that resolves in both the repository checkout and the marketplace cache.

The owner file carries a consumer-declaration line so the coupling is discoverable from the owner side: *Consumed by ts-doc-review: its fix-application pass cross-reads this order rule to place the sections its fixes create; changes here propagate to both skills.* This is the second application of the pattern (the first was the D-entry contract cross-read) and the first cross-read of the rendering reference.

### Legacy discipline: placement binds creation only, keyed on records not names

The order rule binds placement of **newly created sections only**. Existing sections are never relocated; mixed adjacency in legacy documents — a review-created Scope Boundaries anchoring in the front block while the document's own late Risks & Dependencies stays put — is an accepted transient state, and no reviewer finding flags late placement. One unconditional rule beats vintage-sniffing.

Two load-bearing details:

- **Placement is not authorization.** The rule states explicitly that it never authorizes creating a section; creation remains governed by the fix's own scope rules. Without that clause the order rule appears to conflict with the standing review rule against adding undiscussed sections.
- **Own-output exclusion is keyed on emitted records, not heading names.** `subagent-template.md`'s new exclusion treats a section as review-created when its content carries the D-entry the creating fix emitted (the entry's Decision line records the creation); content carrying no such record is document content and stays fully in review scope, even inside a section the workflow created. Heading-name matching would misclassify: a document can legitimately contain its own Scope Boundaries, and a review-created section can be renamed downstream.

### Map-derivation completeness: cover every token class the rule enumerates

The ID-to-gloss resolution map derives from every token class the gloss rule enumerates — level-2 to level-4 headings (U-IDs, KTD items, D-entry IDs, section names) **and** bullet-prefix IDs (`R#`, `KTD#`, `F#`, `AE#`, `A#`). Heading-only derivation default-empties on requirements-classified documents, where every R-ID is a bullet prefix and none appears as a heading — the map would resolve nothing exactly where the gloss rule is needed most.

Distribution and lifecycle constraints:

- The map travels as **orchestrator context** to the walkthrough Entry and the headless envelope — never a `findings-schema.json` field. It is presentation state, not finding data.
- **Re-derived each review round** (round 2+ operates on changed document state), and **extended mid-run**: after the Phase 4 edit pass and before envelope assembly, the scoped IDs of D-entries emitted by applied fixes are appended, so applied-fix lines citing `Overview.D1` resolve.
- Composite tokens (`U2 step 4`) resolve via their parent ID.
- Resolution order at the render site: map first, falling back to the document the orchestrator holds from the Phase 1 read; unresolvable tokens pass bare — never invent a gloss.

### Replace-not-stack at every restatement site

When a rule is tightened, the new wording **replaces** the old wording in place at every site that restates it. The stretched exemption ("the surrounding sentence already states the item's substance — the sentence is the gloss") was replaced, not annotated, in both restatement sites: `walkthrough.md`'s per-token procedure and `subagent-template.md`'s source-side instruction. New form: no gloss when the item's function is named **in the same clause** as the ID token; title lines and heading lines always gloss — no exemption. Leaving even one stale copy of the loose wording keeps the stretched reading live one paragraph away from the tightened one.

### Pre-fire audit shape

The audit is defined once, beside the canonical gloss rule in `walkthrough.md` ("Pre-fire audit"), and every other surface cross-references it ("applies the audit, does not restate it"). Its shape:

- **Explicit surface enumeration.** Before emitting any text rendered from the findings set — routing-question digest lines, bulk-preview one-liners, per-finding questions, dependent-list lines, completion-report lines (the headless envelope audits at its own emission, cross-referencing the same definition). Naming every surface is what makes audit coverage independent of routing choice; "audit user-facing text" without the enumeration recreates the surface-by-surface inconsistency being fixed.
- **One self-healing pass, bounded by idempotence.** Enumerate every ID token, gloss resolvable bare tokens in a single pass, then stop — the canonical rule's idempotence clause (it fires only on un-glossed tokens) means a second application would double-gloss.
- **Remaining bare tokens are accounted for, not blanket-failed.** The audit confirms every remaining bare token is either unresolvable-class (map and held document both lack it → passes bare per the never-invent clause) or same-clause-exempt (the item's function is named in the same clause as the ID token, so the canonical rule adds no gloss); titles and headings are never exempt.
- **Completes before any user-facing render**, so the per-finding question and its terminal transcript duplicate mirror the same glossed text and the duplicates-rewrite-nothing rule sees no divergence.

## Why This Matters

**One copy survives drift; two copies already disagree.** The pre-fix state proved the cost: three undeclared orderings in one skill, two of them mutually contradictory. A rule stated once with pointers cannot drift between surfaces, and the pointer lines make ownership discoverable from every restatement site — a future editor who reorders a catalog hits the "names membership, not render order" line instead of silently re-creating the conflict.

**The second-copy failure mode is invisible to per-change gates.** Each changed file was internally consistent; the contradiction only surfaced when a scenario was traced end-to-end across files. Enumeration-alignment defects survive review precisely because each site reads fine alone.

**Consistency must be enforced at assembly time, not asked of prose.** The gloss rule existed and was correct; bare IDs still reached users because nothing ran the procedure over the assembled text. A named audit step with an explicit surface list converts "the rule is written down somewhere" into "this emission cannot leave unaudited text."

**Record-keyed exclusions and placement-only scoping keep rules from fighting each other.** Own-output exclusion keyed on emitted D-entries means the exclusion follows what the workflow actually wrote, not what a heading happens to say. Placement-only scoping means the new order rule never collides with the rule against adding undiscussed content. Both prevent the common failure where fixing one inconsistency creates a second conflict the next round must flag.

**Map coverage failures are silent and class-shaped.** A heading-only map does not error — it resolves nothing on an entire document class. Deriving from every token class the rule enumerates, and keeping the map as context rather than schema, gets resolution right without touching the findings contract.

## When to Apply

- Repos whose product or contract is prose/instruction assets — prompt files, skill definitions, spec suites — adopting a presentation-order or consistency rule over sections, fields, or tokens.
- Anywhere a rule is cross-consumed by multiple surfaces or a sibling skill: bind the consumer read explicitly (`${CLAUDE_PLUGIN_ROOT}`-anchored path, guarded visible fallback) and add a consumer-declaration line in the owner file.
- Anywhere ID-heavy documents feed user-facing renderings (findings, previews, reports, envelopes): canonical per-token rule + per-round resolution map + named pre-fire audit over assembled text.
- Any tightening of an existing rule that is restated in more than one file: replace in place at every restatement site.
- Any workflow that writes content into documents it later re-reviews: own-output exclusion keyed on emitted records, never heading names.
- Any order or consistency rule introduced over an item set that appears in enumerated lists elsewhere: grep every enumeration of the set before declaring done.

## Examples

Before — three undeclared orderings in one skill (`markdown-rendering.md` Section anatomy even listed Implementation Units before Key Technical Decisions, contradicting the catalog one reference away); bare IDs reaching users (`U2 — baseline word-budget gate skipped`, `R5 conformance has no verification step`):

```markdown
- **Implementation Units** — H3 heading per unit with `U<N>.` prefix. ...
- **Key Technical Decisions** — bullets with bold decision name ...
- **Key Flows / Acceptance Examples** — bullets ...
- **Scope Boundaries** — bullets ...
```

After — one owned rule plus pointer lines (commit ccb3745, 577ae3d). Owner, in `markdown-rendering.md`:

```markdown
## Section order (plan documents)

Plan documents render their H2 sections in this order:

Summary → Problem Frame → Requirements → Key Technical Decisions →
Scope Boundaries → Risks & Dependencies → Open Questions → Assumptions →
System-Wide Impact → Acceptance Examples → Documentation / Operational
Notes → High-Level Technical Design → Implementation Units → Sources &
Research

*Consumed by ts-doc-review: its fix-application pass cross-reads this
order rule to place the sections its fixes create; changes here propagate
to both skills.*
```

Pointer in `plan-sections.md`, at both the hard floor and the catalog:

```markdown
This list names membership, not
render order — section order is owned by `references/markdown-rendering.md`
("Section order (plan documents)").
```

Aligned `SKILL.md` Phase 4.2 enumeration — before and after (U7 dry-run catch):

```markdown
- ...the include-when-material catalog (HTD, Scope Boundaries, Open Questions,
  System-Wide Impact, Risks & Dependencies, Acceptance Examples,
  Documentation/Operational Notes, Sources & Research), ...
+ ...the include-when-material catalog (Scope Boundaries, Risks &
  Dependencies, Open Questions, Assumptions, System-Wide Impact, Acceptance
  Examples, Documentation/Operational Notes, HTD, Sources & Research), ...
```

Consumer-side cross-read with guarded fallback, in `walkthrough.md` ("Placement of created sections"):

```markdown
inserts the new section per the section-order rule cross-read from
`${CLAUDE_PLUGIN_ROOT}/skills/ts-plan/references/markdown-rendering.md`
("Section order (plan documents)"). ... on a platform where
`${CLAUDE_PLUGIN_ROOT}` is unset or the file is missing, say so visibly
and fall back per the plugin path-resolution rule ... — never silently
skip the contract read, because an unread contract is an unenforced one.
```

Replace-not-stack on the gloss exemption — before (sentence-level, no title carve-out), after (clause-level, titles always gloss), same edit in `walkthrough.md` and `subagent-template.md`:

```markdown
- ...the surrounding sentence already states the item's substance
  (`KTD5's own bootstrap chown/repair` — the sentence is the gloss) →
  no gloss added;
+ ...the item's function is named in the same clause as the ID token
  (`KTD5's own bootstrap chown/repair` — the clause is the gloss);
  title lines and heading lines always gloss — no exemption;
```

Pre-fire audit (defined once in `walkthrough.md`, cross-referenced from `bulk-preview.md`, `review-output-template.md`, `open-questions-defer.md`, and the headless envelope in `synthesis-and-presentation.md`):

```markdown
Before emitting any text rendered from the findings set — routing-question
digest lines, bulk-preview one-liners, per-finding questions,
dependent-list lines, completion-report lines — run one audit over the
assembled text: enumerate every ID token ..., gloss resolvable bare tokens
... in a single self-healing pass, then stop ..., and confirm every
remaining bare token is unresolvable-class (passes bare per the
never-invent clause) or same-clause-exempt per the canonical rule ...
.
```

Cross-reference form (each surface applies, none restates):

```markdown
The assembled preview — body lines and question-text digest — passes the
pre-fire audit (`references/walkthrough.md`, "Pre-fire audit") before the
question fires.
```

Glossed output the pipeline now guarantees, from the envelope template example (commit 7da8f6b):

```markdown
  Why: U3 (payment retry loop) sets no retry cap, so a provider outage loops charges
```

Positional effect, one row per section (from the plan's HTD table): Implementation Units moved 6 → 13; Scope Boundaries 7 → 5; Risks & Dependencies 10 → 6; Assumptions entered the catalog at position 8.

## Related

- `docs/solutions/architecture-patterns/doc-review-gloss-rule-dentry-emission.md` — the base pattern this learning extends: one-canonical-copy rule file, cross-skill contract read with consumer declaration, render-surface enumeration, idempotence as the re-application bound. This doc adds section-order ownership, de-facto-ordering-carrier alignment, the per-round ID-to-gloss map, replace-not-stack tightening, and the pre-fire audit.
- `docs/solutions/developer-experience/self-contained-blocking-questions-skill-walkthroughs.md` — the question-side counterpart of the same self-contained-presentation standard; the pre-fire audit preserves its duplicates-rewrite-nothing rule.
- `docs/solutions/tooling-decisions/claude-code-plugin-script-path-resolution.md` — the `${CLAUDE_PLUGIN_ROOT}` substitution tiers the cross-skill reference read extends from scripts to reference docs.
- Issues #233, #234 (closed on branch `fix/plan-section-order-gloss-audit`); plan: `docs/plans/2026-11-26-001-fix-plan-section-order-gloss-audit-plan.md`.
