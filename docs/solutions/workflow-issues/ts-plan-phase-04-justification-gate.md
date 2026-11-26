---
title: "ts-plan Phase 0.4 justification gate: condition framed artifacts on an input source"
module: "ts-plan (planning skill, Phase 0.4 planning bootstrap)"
date: 2026-11-25
problem_type: workflow_issue
component: development_workflow
severity: medium
track: knowledge
symptoms:
  - "Plan documents contain a Problem Frame with no traceable source"
  - "Skill phase lists an artifact to establish without conditioning it on any input source"
  - "Plans built on invented rationale escape review and surface as rework later"
root_cause: missing_validation
resolution_type: workflow_improvement
applies_when:
  - "Authoring a skill phase that instructs an agent to produce a framed artifact"
  - "An artifact requirement in a skill is not conditioned on a named input source"
  - "Downstream adversarial review is selective and can miss confident fabrications on routine work"
related_components:
  - ts-doc-review
  - documentation
tags:
  - ts-plan
  - justification-gate
  - fabrication
  - skill-authoring
  - prompt-engineering
  - problem-frame
---

# ts-plan Phase 0.4 justification gate: condition framed artifacts on an input source

## Context

`ts-plan`'s Phase 0.4 planning bootstrap fabricated a problem-frame rationale whenever the invocation carried none. The phase's bootstrap list named "Problem frame" as something to establish, but nothing in the phase conditioned that item on any input source. Faced with a list demanding content and a request that supplied only a task, the agent invented a plausible-sounding why and planned on top of it (GitHub issue #232, labeled critical, repo taegosts-skills).

The gap was not one line but three surfaces acting together:

1. **Phase 0.4 bootstrap list** — "Problem frame" sat at the top of a list of things the bootstrap "should establish", with no source check anywhere in the phase.
2. **Phase 1.1 planning-context summary** — the no-origin-document path said only "Otherwise use the feature description directly", so a fabricated frame flowed into downstream research agents as if confirmed.
3. **Phase 5.1 pre-write review** — the check "the bounded planning bootstrap established enough product clarity to plan responsibly" accepted any problem frame, traced to nothing.

Consequences split into two paths, both bad. If the fabricated frame was wrong in a way reviewers noticed, the rework landed later at plan-review time. The worse path was the frame that was never caught: `ts-doc-review`'s adversarial pass activates only on high-value challenge surfaces, so a confident fabricated Problem Frame on a routine plan typically evaded scrutiny and shipped inside the plan. The critical label reflects that silent path — plans built on an unverified assumption that nothing in the pipeline was positioned to detect.

Before this fix, no learning in `docs/solutions/` captured this failure mode; the origin plan explicitly deferred the capture to `ts-compound` after implementation.

## The Transferable Lesson

**Fabrication sites live where a workflow phase lists an artifact to "establish" without conditioning it on an input source.** An unconditioned establishment item is a demand for content with no supply constraint. An agent working through the phase has strong completion pressure to fill every listed item; with no named source, invention is the path of least resistance, and the invented content arrives in a confident register that downstream readers rarely challenge.

The fix pattern has three parts, and all three are required:

1. **Gate at entry.** Check for real sources once, at the phase boundary, before the establishment list runs. The gate decides between "source confirmed", "user supplied one", and "absence recorded" — and never leaves the fourth outcome (invention) available.
2. **Downstream consumption checks.** Every later surface that uses the artifact must cite the confirmed source and fail a sourceless one. Without these, the gate is bypassable: a downstream phase can quietly re-derive the frame, reproducing the fabrication after the gate already ran.
3. **Explicit-unknown recording.** When no source exists and none can be asked for, record the absence as a named, visible entry (here: the plan's `## Assumptions` section) rather than synthesizing content to fill the gap.

This is **not always-ask.** An always-ask variant was explicitly rejected at scoping: it interrupts every run, while a rationale source is usually present (a prompt why, an issue body, an origin doc). Gate on the absence of sources, not on the presence of the phase.

## Guidance

All changes are instruction prose in `skills/ts-plan/SKILL.md` — no tooling, no new files. Landed on branch `fix/ts-plan-justification-gate` (issue #232).

### The gate: conditional, once, at Phase 0.4 entry

The gate sits at the top of Phase 0.4 and fires after the Phase 0.2/0.3 origin-doc search resolves, so it never asks about a rationale the origin document already carries. It checks exactly three rationale sources:

- **(a)** a why stated in the prompt itself;
- **(b)** a linked issue whose body **states the problem** — when the prompt references an issue, read the body per Core Principle 8. A task-only issue body with no why does **not** count;
- **(c)** the origin requirements document from Phase 0.2.

The determination is made once here; later phases consume the confirmed rationale or the recorded assumption without re-deriving it. This mirrors the gate-once precedent: consult the settled result once, never re-derive it downstream.

Source (b) carries the subtle case. A linked issue proves the task exists, not why it exists. Reading the body rather than trusting the link is what separates "the issue explains the problem" from "the issue assigns work".

### The ask: blocking, self-contained, with a decline path

If no source exists, the skill asks the user via the platform's blocking question tool (its Interaction Method) and waits for the response before continuing. Fabricating is named as forbidden in the instruction text itself ("never fabricate a justification"), not left implied.

The question text must be self-contained per `docs/standards/question-standards.md`: plain-text labeled lines carrying the whole decision — the request states a task but no reason for doing it, and planning without a justification would build the plan on an unverified assumption. It offers a free-text path (the user supplies the justification) and a decline option whose one-clause stated effect is to proceed while recording the missing rationale as an explicit entry under the plan's `## Assumptions` section.

### Headless/pipeline mode: same destination, no ask

Pipeline invocations cannot block. The headless clause skips the ask and records the missing justification as the same explicit `## Assumptions` entry — a recorded unknown, never an invented rationale. Decline and headless share one destination: a missing rationale is recorded identically regardless of why it is missing, which keeps the downstream check simple and gives fabrication no fallback in any mode. This follows the Phase 0.7 precedent of routing unvalidated bets to `## Assumptions`.

### Downstream consumption checks: the anti-bypass edits

Two existing instructions were rewritten so the gate cannot be bypassed downstream:

- **Phase 1.1** planning-context summary: the no-origin-doc bullet now requires stating the Phase 0.4 gate's confirmed rationale as the problem frame's source — cite it (or, when declined or headless-recorded, the explicit `## Assumptions` entry recording its absence) and never invent a rationale. Research agents receive a frame with provenance, not a re-derived one.
- **Phase 5.1** pre-write review: the bootstrap-clarity check now requires that in every case the problem frame traces to a real rationale source — a why stated in the prompt, a linked issue body, the origin document, the user's answer at the Phase 0.4 justification gate, or the explicit `## Assumptions` entry recording a missing rationale (declined or headless). A problem frame tracing to no source **fails this check**.

Without these two edits the gate would be decorative: Phase 1.1 would summarize a frame it re-derived, and Phase 5.1 would bless whatever frame it found. The review check is what converts the gate from a suggestion into an enforced contract, and the accepted-source list deliberately includes the `## Assumptions` entry — otherwise every plan the gate approves without a rationale would fail the plan's own review, recreating the rework the fix exists to remove.

### Scope discipline

- Instruction prose replaces existing text rather than stacking the gate on top of it. Stacking leaves the original unconditioned instruction live one paragraph away from the new gate, and the model can follow either; replacement removes the fabricating instruction.
- `references/plan-sections.md` is untouched. Its Problem Frame section contract ("why the work is being done") is correct once the gate guarantees a real why upstream; editing the shared reference would propagate the change to `ts-doc-review`, which cross-reads it via a consumer declaration.
- Sibling skills facing the same fabrication risk (`ts-brainstorm`, `ts-work`, `ts-doc-review`) were deliberately left unchanged — the pattern generalizes, but each skill needs its own scoping decision.

## Why This Matters

**The root cause is an unconditioned establishment list, not missing validation.** Adding a post-hoc review of problem frames would catch some fabrications at review cost on every run. Conditioning the artifact on a source at entry prevents the fabrication from existing at all, and costs a check only on runs that reach Phase 0.4 without a rationale.

**Why the gap stayed hidden:** every downstream surface was permissive by design. Phase 1.1 passed the frame through, Phase 5.1 asked only whether "enough product clarity" existed — a confident frame satisfies that on tone alone — and `ts-doc-review`'s adversarial pass targets high-value challenge surfaces, which a routine plan's problem frame is not. A failure mode invisible to all downstream checks needs a prevention at the source, not another detector.

**Why gate once (R3):** re-deriving the rationale at each later phase re-opens the fabrication decision at each phase, and phases can diverge — one citing the user's answer, the next quietly substituting an inference. One determination, consumed everywhere, keeps the plan's frame single-sourced.

**Why replace rather than stack (KTD-4):** the fabrication risk is carried by the old instruction text. A gate added alongside it leaves that text in place, and an agent resolving conflicting instructions may resolve in favor of the concrete establishment list over the abstract prohibition.

**Why one destination for decline and headless (U1.D2):** two recording schemes for the same missing input would double the downstream check's accepted-source list and invite drift between them. One `## Assumptions` entry shape, reached by two routes, keeps the contract minimal.

## When to Apply

- A workflow phase lists artifacts to "establish", "define", or "produce" — condition each item on a named input source, or gate on its absence at phase entry before the list runs.
- An agent-owned phase can plausibly invent the content a section contract demands: problem frames, rationales, personas, success criteria, non-goals.
- The pipeline can run headless — provide an explicit-unknown recording route so the blocking ask never forces fabrication as the only non-blocking option.
- A downstream review surface that scrutinizes only high-value items must still trace load-bearing claims (frames, rationales) to sources; low-scrutiny surfaces are exactly where confident fabrications survive.
- Tempted by always-ask for missing input: gate on source absence instead. Always-ask taxes every run to catch the rare empty one.
- A linked artifact (issue, ticket) is offered as justification for work: read its body and check it states a why; a task-only body is a pointer, not a rationale.

## Examples

### Before: the fabrication site

Phase 0.4's bootstrap list (main, before the fix) opened with an unconditioned demand:

```markdown
The planning bootstrap should establish:
- Problem frame
- Intended behavior
- Scope boundaries and obvious non-goals
- Success criteria
- Blocking questions or assumptions
```

A request carrying only a task ("fix the flaky test") produced an invented Problem Frame paragraph — the list demanded one, nothing supplied one, and nothing downstream asked where it came from.

### After: the gate at Phase 0.4 entry

```markdown
**Justification gate (fires once, at this phase's entry).** After the Phase 0.2/0.3 origin-doc search resolves,
check for a rationale source: a why stated in the prompt itself; a linked issue whose body states the problem
(when the prompt references an issue, read the body per Core Principle 8 — a task-only body with no why does
not count); or the origin requirements document from Phase 0.2. This determination is made once here; later
phases consume the confirmed rationale or the recorded assumption without re-deriving it.

**If no rationale source exists, ask the user** (see Interaction Method) and never fabricate a justification.
[... self-contained question per docs/standards/question-standards.md, free-text path supplies the
justification, decline option proceeds while recording the missing rationale as an explicit entry under the
plan's ## Assumptions section ...] Then wait for their response before continuing.

**Headless/pipeline mode:** skip the ask and record the missing justification as that same explicit
`## Assumptions` entry — a recorded unknown, never an invented rationale.
```

### After: the two consumption checks

Phase 1.1, planning-context summary bullet — before: `Otherwise use the feature description directly`; after:

```markdown
- Otherwise use the feature description directly, stating the Phase 0.4 justification gate's confirmed
  rationale as the problem frame's source — cite it (or, when declined or headless-recorded, the explicit
  `## Assumptions` entry recording its absence) and never invent a rationale
```

Phase 5.1, pre-write review check — before: `If there was no origin document, the bounded planning bootstrap established enough product clarity to plan responsibly`; after:

```markdown
- If there was no origin document, the bounded planning bootstrap established enough product clarity to plan
  responsibly — and in every case the problem frame traces to a real rationale source: a why stated in the
  prompt, a linked issue body, the origin document, the user's answer at the Phase 0.4 justification gate, or
  the explicit `## Assumptions` entry recording a missing rationale (declined or headless). A problem frame
  tracing to no source fails this check
```

### Verification (dry-run scenarios, 4 parallel verifiers, all PASS)

- (a) bare task, no why, no issue reference → the ask fires
- (b) issue body states the problem → no ask
- (c) task-only issue body, no why → the ask fires
- (d) headless invocation → `## Assumptions` entry recorded, nothing invented
- (e) user-supplied rationale cited at Phase 1.1, not reinvented; decline path records the entry
- (f) problem frame tracing to no source fails the Phase 5.1 check

Existing suites pass after the edit (`scripts/run-test-suites.sh`, `scripts/verify-script-refs.sh`). No unit tests were added: the change is a prompt-text asset, and no repo gate asserts question wording — the dry-run verification above is the check.

## Known Looseness (deferred)

The Phase 5.1 accepted-source list says "a linked issue body" without the gate's "states the problem" qualifier. As written, the gate rejects a task-only issue body at Phase 0.4, while the review check's phrasing would accept one. Verifier finding, deliberately deferred with the rest of the plan's scope. Tightening is a three-word edit to the Phase 5.1 bullet when picked up; until then the gate's stricter reading governs, since it runs first and its determination is consumed downstream.

## Related

- `docs/standards/question-standards.md` — the repo-wide blocking-question standard this gate's ask follows
- `docs/solutions/developer-experience/self-contained-blocking-questions-skill-walkthroughs.md` — the prior question-design incident (#222) that produced that standard; this gate's ask reuses its shape (self-contained stem, labeled options, one-clause effects)
- `docs/solutions/architecture-patterns/doc-review-gloss-rule-dentry-emission.md` — gate-once ("consult the settled result once; do not re-derive it at execution time") and verify-claims-on-return precedents for instruction-prose changes
- `docs/plans/2026-11-25-001-fix-ts-plan-justification-gate-plan.md` — origin plan: requirements R1-R5, KTD-1 through KTD-4 (with KTD4.D1), unit U1 with decisions U1.D1-D3
- Issue #232 (critical), closed by branch `fix/ts-plan-justification-gate`
