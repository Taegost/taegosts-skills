---
title: "fix: ts-plan asks for plan justification when none given"
type: fix
date: 2026-11-25
---

## Summary

Add a gate to `ts-plan` (Phase 0.4 entry): when the invocation carries no rationale source, ask the user for the justification via the Interaction Method instead of fabricating one. Downstream surfaces (Phase 1.1 context summary, Phase 5.1 review) consume the confirmed rationale and never invent one. Change is instruction prose in `skills/ts-plan/SKILL.md` only.

## Problem Frame

Issue #232 (critical): when a plan request arrives without a justification, `ts-plan` fabricates one via the Phase 0.4 planning bootstrap, which lists "Problem frame" as something to establish without conditioning it on any rationale source. The plan is then built on a faulty assumption that is either never caught or causes rework. The never-caught path is real: `ts-doc-review`'s adversarial pass activates only on high-value challenge surfaces, so a confident fabricated Problem Frame on a routine plan typically evades review.

## Requirements

- R1. When no rationale source exists in the invocation, `ts-plan` asks the user for the justification using the platform's blocking question tool (see its Interaction Method) and waits for the response before continuing.
- R2. `ts-plan` never fabricates a justification. If the user declines to give one, the plan records the missing rationale as an explicit unknown, not an invented one.
- R3. The gate evaluates rationale-source presence once (prompt rationale, linked issue body, origin requirements doc) and later phases consume that determination without re-deriving or overriding it.
- R4. The ask works in headless/pipeline mode without blocking: the missing justification is recorded as an explicit assumption in the plan.
- R5. The question text is self-contained per `docs/standards/question-standards.md` — a reader who saw only the dialog understands what is being decided and why.

## Key Technical Decisions

- KTD-1 [behavioral]. Gate fires only when no rationale source exists among: a why stated in the prompt itself, a linked issue body that states the problem (read per Core Principle 8 when the prompt references an issue), or an origin requirements doc found in Phase 0.2. Rationale: user-confirmed scope — an always-ask variant was explicitly rejected because it interrupts every run while a source is usually present. A task-only issue body with no why does not count as a source.
- KTD-2 [behavioral]. Headless/pipeline mode routes the missing justification to an explicit assumption in the plan rather than blocking or fabricating. Rationale: pipeline mode cannot block; the Phase 0.7 headless precedent already routes unvalidated bets to `## Assumptions`, so fabrication is never the fallback in any mode.
- KTD-3. Scope is `skills/ts-plan/SKILL.md` only; `references/plan-sections.md` is untouched. Rationale: the Problem Frame section contract ("why the work is being done") is correct once the gate guarantees a real why exists upstream; editing the shared reference would propagate to `ts-doc-review`, which cross-reads it via a consumer declaration.
- KTD-4. Prose edits replace existing instruction text rather than stacking the gate on top of it. Rationale: token-economy precedent from the readable-plans retrofit. Amended by KTD4.D1 (baseline and word-count handling removed from scope, user decision).

#### KTD4.D1. Baseline and word-count handling removed from plan scope

**Decision:** The plan does not touch `tests/baselines/` word-count or hash baselines; suite verification moved into U1 (justification gate unit) and the separate baseline unit deleted.

**Why:** User directed removal during doc review — the baseline tooling's purpose was unclear and judged out of scope; the refresh is manual tooling excluded from CI, so omitting it breaks no gate.

**Source:** user, 2026-11-25 doc-review walkthrough — "Remove anything dealing with them, they're out of scope"

## Implementation Units

### U1. Justification gate in SKILL.md

**Goal:** `ts-plan` asks for a missing justification instead of fabricating one, in every mode.

**Requirements:** R1 (ask when no rationale source), R2 (never fabricate), R3 (determine once), R4 (headless routing), R5 (question standards)

**Dependencies:** none

**Files:** `skills/ts-plan/SKILL.md`

**Approach:**
- Add the gate at Phase 0.4 entry, after the Phase 0.2/0.3 origin-doc search resolves. It checks the three rationale sources from KTD-1 and, finding none, asks via the Interaction Method — mirroring the existing empty-feature-description gate's shape ("If the feature description above is empty, ask the user… Then wait for their response before continuing.").
- The question must satisfy `docs/standards/question-standards.md`: self-contained text (the plan would otherwise be built on an unverified assumption), plain-text labeled lines, one-clause option effects, a free-text path for the justification, and a decline path that proceeds with the rationale recorded as an explicit entry under the plan's `## Assumptions` section (R2; same destination as the headless route).
- Add the headless clause to the gate in the same edit: pipeline mode skips the ask and records the missing justification as an explicit assumption (KTD-2).
- Adjust the two downstream surfaces so the gate is not bypassed: the Phase 1.1 planning-context-summary instruction ("Otherwise use the feature description directly") must name the confirmed rationale as the source and forbid inventing one; the Phase 5.1 review check ("the bounded planning bootstrap established enough product clarity") must verify the problem frame traces to a real source — prompt, issue body, origin doc, user answer, or the explicit `## Assumptions` entry recording a missing rationale (declined or headless).

**Patterns to follow:** the empty-feature-description gate in `skills/ts-plan/SKILL.md`; the Phase 0.5 blocking-gate phrasing (blocking tool, explicit do-not-proceed rule); Phase 0.7's headless routing to `## Assumptions`.

**Test scenarios:** Test expectation: none — prompt-text asset; no repo gate asserts question wording. Verification below is the check.

**Verification:** dry-run the changed behavior: (a) a bare task with no why and no issue reference triggers the ask; (b) a task referencing an issue whose body states the problem does not trigger it; (c) a task-only issue body with no why triggers it; (d) headless invocation records the assumption and never invents a rationale; (e) a user-supplied rationale reaches the Phase 1.1 planning-context summary cited, not reinvented, and the decline path records the `## Assumptions` entry without invention; (f) a problem frame tracing to no source fails the Phase 5.1 review check. Existing suites pass after the edit (`scripts/run-test-suites.sh`, `scripts/verify-script-refs.sh`).

#### U1.D1. Phase 5.1 accepted-source list extended

**Decision:** The Phase 5.1 trace check accepts the explicit `## Assumptions` entry recording a missing rationale (declined or headless) as a valid source.

**Why:** Without it, every plan the gate approves without a rationale fails the plan's own review check — the rework issue #232 is meant to remove.

**Source:** user, 2026-11-25 approved review agent coherence + test-documentation's proposal

#### U1.D2. Decline-path destination set to ## Assumptions

**Decision:** A declined rationale is recorded under the plan's `## Assumptions` section, the same destination as the headless route.

**Why:** User redirected from the reviewer's Problem Frame proposal — one destination for a missing rationale regardless of why it is missing is simpler than two.

**Source:** user, 2026-11-25 doc-review walkthrough — "use that same place rather than come up with something new"

#### U1.D3. Downstream edits gain verification scenarios

**Decision:** U1's verification adds scenario (e) — a confirmed rationale reaches the Phase 1.1 summary cited, not reinvented — and (f) — a sourceless problem frame fails the Phase 5.1 check.

**Why:** Each anti-bypass edit now has a scenario that fails if the edit is skipped; issue #232's never-caught path lives in those downstream surfaces.

**Source:** user, 2026-11-25 approved review agent test-documentation's proposal

## Scope Boundaries

- Other skills (`ts-brainstorm`, `ts-work`, `ts-doc-review`) keep their current behavior even where they face the same fabrication risk.
- No workflow restructuring beyond the gate and its two downstream consistency edits.
- No always-ask variant (rejected at scoping).
- Baseline and word-count refresh (`tests/baselines/`) — out of scope by user decision; those files drift when `SKILL.md` changes and are refreshed manually outside this plan (KTD4.D1).

### Deferred to Follow-Up Work

- Capture the fabricated-rationale failure mode in `docs/solutions/` via `ts-compound` after implementation — no such learning exists in the corpus yet.

## Sources & Research

- Issue #232 — the defect report and its critical label.
- `docs/standards/question-standards.md` — repo-wide blocking-question conformance rules the new ask must pass.
- `docs/solutions/developer-experience/self-contained-blocking-questions-skill-walkthroughs.md` — prior blocking-question incident and fix shape.
- `docs/solutions/architecture-patterns/doc-review-gloss-rule-dentry-emission.md` — gate-once and verify-claims-on-return precedents for instruction-prose changes.
- `docs/solutions/behavioral-ktd-verification.md` — KTD `[behavioral]` marking convention used above.
- `docs/plans/2026-11-19-001-fix-doc-review-question-self-containment-plan.md` — skeleton and test-expectation precedent for a prompt-instruction-only fix.
