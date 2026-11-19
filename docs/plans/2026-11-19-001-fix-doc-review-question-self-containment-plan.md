---
title: "fix: Self-contained decision questions in ts-doc-review (Issue #222)"
type: fix
date: 2026-11-19
---

# fix: Self-contained decision questions in ts-doc-review (Issue #222)

## Summary

Rewrite the ts-doc-review interactive walk-through so every blocking decision question carries the complete information needed to answer it: the full finding inside the per-finding question, findings list inside the routing question, execution summary inside the bulk-preview question, completion summary inside the Phase 5 terminal question. Codify the rule as a repo standard in `docs/standards/`, wire it into the skill's interactive-mode rules, and open a companion issue to audit other skills for the same print-then-ask pattern.

## Problem Frame

Claude Code collapses text printed before a blocking question while the question dialog is open. The ts-doc-review walk-through prints each finding as a terminal markdown block, then fires a two-line question stem — so the user is asked to decide on a finding they cannot read. Issue #222 reports this for the per-finding question; the same print-then-ask shape affects the routing question, the bulk-preview Proceed/Cancel, and the Phase 5 terminal question. The question text must be the authoritative carrier of decision information; anything printed before it is unreadable at the moment of decision.

## Requirements

**Question behavior (ts-doc-review)**

- R1. Each per-finding question is self-contained: position (`Finding N of M`), plain-English severity, plain-English title, and the `What's wrong` / `Proposed fix` / `Why it works` sections all inside the question text.
- R2. Option descriptions state the effect each action has on the document, not just the label.
- R3. Terms in question text not already explained in the visible conversation get a short inline explanation.
- R4. When a fix has a user-visible trade-off, or overlaps a finding the user already decided on, the question text says so.
- R5. The routing question carries the remaining-findings list; the bulk-preview Proceed/Cancel question carries the execution summary it is about to apply; the Phase 5 terminal question carries the completion summary.

**Repository standard**

- R6. A new standard in `docs/standards/` codifies the self-contained-question rule for all skills in the repo, indexed in `docs/standards/INDEX.md`.
- R7. `skills/ts-doc-review/SKILL.md` interactive-mode rules gain the general rule (decision questions must contain the information needed to make them), citing the standard.

**Companion work**

- R8. A companion GitHub issue audits the other skills for the print-then-ask pattern, references issue #222, and is self-contained for a reader with no plan context.

## Key Technical Decisions

- KTD-1 [behavioral] Question text is the single authoritative carrier of decision information; the terminal output block remains only as a transcript duplicate, never the only place content appears. This replaces the "never merge the two" rule opening `walkthrough.md` "Per-finding presentation". Rationale: pre-question text is collapsed and unreadable while the dialog is open.
- KTD-2 [behavioral] Question text adapts to plain-text rendering: labeled lines (`What's wrong:`, `Proposed fix:`, `Why it works:`), not markdown emphasis. Rationale: the blocking question tool renders plain text; the terminal block keeps its markdown.
- KTD-4 [behavioral] Length discipline: each finding section in the question is 1–3 sentences; each option description is one clause stating its effect. The routing question always carries a total-count line ("There are a total of N findings"), lists at most 4 findings inline in the compressed one-line-per-finding format from `bulk-preview.md` (plain-English severity word in place of the `[P0]` tag: `<severity> <section> — <summary>`, ~80 columns), and above 4 findings drops the list — the question states a summary is too long to print and asks how to handle the set. Rationale: the question tool has practical rendering limits, and the user's default route is one-by-one review, which the count-plus-options question already serves.
- KTD-5 [behavioral] `docs/standards/question-standards.md` is the canonical, repo-wide home of the rule; the `SKILL.md` interactive-mode rule is an instance that cites it. Rationale: single source of truth prevents standard/skill drift; unwired standards become orphaned findings (see `docs/solutions/tooling-decisions/compliance-gate-scope-classification.md`).
- KTD-6 [behavioral] Token economy: `walkthrough.md` edits replace the two-part presentation rather than stacking the new contract on top of the old one; the terminal-block spec shrinks to "duplicate of the question content". Rationale: the orchestrator reads this file on every interactive run, and the repo's token-economy effort is active (PR #123 shrank ts-pr-review and ts-code-review; PR #112 shrank this skill).

## Implementation Units

### U1. Per-finding question carries the full finding

- **Goal:** Rewrite "Per-finding presentation" in `walkthrough.md` so the question text contains the complete finding; apply the same shape to the cascade confirmation and the no-fix sub-question in the same file.
- **Requirements:** R1, R2, R3, R4
- **Dependencies:** none
- **Files:** `skills/ts-doc-review/references/walkthrough.md`
- **Approach:** Replace the never-merge rule with KTD-1's duplicate-not-authoritative rule. Question shape: heading line (`Finding N of M — <severity word> — <plain-English title>`), then the three labeled sections, then the trade-off/overlap line when it applies, then the question stem. Rewrite the option set so each description states its effect (e.g., Defer: adds the finding to Open Questions, changes nothing now). Carry the plain-language rule into the substitution rules for question text: any term not already explained in the visible conversation gets a short inline explanation. The terminal block spec becomes a duplicate rendered for transcript readability.
- **Patterns to follow:** Existing substitution rules in `walkthrough.md` "Terminal output block" (plain-English titles, intent-language fixes, code-span budget); vocabulary rule in `references/review-output-template.md`.
- **Test scenarios:** Test expectation: none — prompt-text asset; no repo gate asserts question wording. Verification below is the check.
- **Verification:** Dry-runs with the dialog open and nothing expanded: a sample finding shows all three sections; the cascade confirmation fires (skip a root finding with dependents); the no-fix sub-question fires (apply a finding without a suggested fix). A worst-case dry-run at KTD-4 maxima — longest finding sections, longest option descriptions, routing question at its 4-finding cap — confirms nothing truncates and records the observed size limit. `scripts/verify-script-refs.sh` still passes (preserve existing `${CLAUDE_PLUGIN_ROOT}` script references).

### U2. Routing, bulk-preview, and terminal questions self-contained

- **Goal:** Make the three remaining decision points carry their context inside the question text.
- **Requirements:** R3, R5
- **Dependencies:** U1 (shared plain-language and length conventions)
- **Files:** `skills/ts-doc-review/references/walkthrough.md`, `skills/ts-doc-review/references/bulk-preview.md`, `skills/ts-doc-review/references/synthesis-and-presentation.md`
- **Approach:** Routing question: a total-count line plus the findings list inside the question text per KTD-4 (compressed format, at most 4 findings inline; above that, no list — the question states a summary is too long to print and asks how to handle the set), replacing the implicit reference to the pre-question report. Bulk-preview: the Proceed/Cancel stem carries the execution summary (applying/appending/resolving counts and the paths touched) instead of "the plan above". Phase 5 terminal question: completion summary (applied/deferred/skipped counts and next-stage framing) inside the question text. Terminal prints of the same content remain as duplicates (KTD-1).
- **Patterns to follow:** `bulk-preview.md` "Preview structure" compressed line format; "Scope summary wording by path" for path-specific stems.
- **Test scenarios:** Test expectation: none — prompt-text asset; no repo gate asserts question wording.
- **Verification:** Dry-run each of the three questions with the dialog open and nothing expanded, including a routing question above the 4-finding cap and a worst-case bulk-preview summary at KTD-4 maxima with nothing truncated.

### U3. Repo standard and skill-rule wiring

- **Goal:** Codify the self-contained-question rule as a repo-wide standard and wire it into ts-doc-review's interactive-mode rules.
- **Requirements:** R6, R7
- **Dependencies:** U1 (the rule text generalizes the shape U1 implements)
- **Files:** `docs/standards/question-standards.md` (new), `docs/standards/INDEX.md`, `skills/ts-doc-review/SKILL.md`
- **Approach:** New standard per the docs/standards conventions: minimal frontmatter (`tags`, `description`), rules stated as MUST, conformance checklist, `## Related` cross-links, citing issue #222 as motivation. First paragraph must read as the INDEX description — `scripts/update-indexes.py` derives the row from it. Add the INDEX row by running the generator and check idempotency. Add one bullet to `SKILL.md` "Interactive mode rules": any question asking for a decision must contain the information needed to make it, citing the standard path.
- **Patterns to follow:** `docs/standards/testing-standards.md` (minimal frontmatter, core principle up front, checklist, Related); INDEX conventions per `docs/standards/index-standards.md`.
- **Test scenarios:** Test expectation: none — documentation-only unit; conformance is enforced by review, not by a gate.
- **Verification:** `scripts/update-indexes.py` adds the row and a second run changes nothing (content-idempotent regeneration); `pytest tests/test_validate_index_standards.py` passes; `SKILL.md` rule cites `docs/standards/question-standards.md`.

### U4. Companion audit issue

- **Goal:** Open a GitHub issue auditing the other skills for the print-then-ask pattern, so remediation beyond ts-doc-review is tracked rather than silently dropped.
- **Requirements:** R8
- **Dependencies:** U3 (the issue names the standard as the remediation target)
- **Files:** none in-repo (GitHub issue tracker)
- **Approach:** Create via `gh issue create` using the house bug/audit format (Summary / places to check / acceptance criteria). Body is self-contained for a stranger with no plan context. Audit list from research: blocking-question sites in ts-brainstorm, ts-code-review, ts-commit, ts-commit-push-pr, ts-compound, ts-compound-refresh, ts-debug, ts-plan, and ts-work; the failure-path question in `skills/ts-doc-review/references/open-questions-defer.md`; and the print-only FYI/residual/deferred presentation (user decision 2026-11-19: unchanged here, listed as audit items). Reference issue #222 and `docs/standards/question-standards.md` as the rule being applied. Title prefixed for the cross-skill scope (e.g., `AUDIT: self-contained decision questions across skills`).
- **Patterns to follow:** Issue #222's body structure; issue #118's residual-tracking precedent.
- **Test scenarios:** Test expectation: none — issue-tracker action, no code surface.
- **Verification:** Issue URL resolves; body contains the full audit list, references #222, and names the standard.

## Scope Boundaries

Out of scope:

- FYI observations, residual concerns, and deferred questions stay print-only — explicit user decision (2026-11-19); they are audit items in the companion issue, not changes here.
- The failure-path question in `references/open-questions-defer.md` — companion issue item.
- All other skills' question sites — companion issue items.
- Restructuring the walk-through flow (step order, finding lifecycle, routing model).
- Claude Code's collapsing behavior itself — worked around, not fixed.

### Deferred to Follow-Up Work

- Cross-skill remediation of print-then-ask sites — executed under the companion issue created in U4.

## Risks & Dependencies

- **Question length limits.** Full-finding text plus per-option effect descriptions may strain the question tool's practical rendering size. Mitigation: KTD-4 budgets and the compressed routing-list format; if a finding still overflows, the sections tighten before anything moves back out of the question.
- **Orchestrator token growth.** `walkthrough.md` is read every interactive run; PR #112 shrank this skill and the token-economy effort is active (PR #123 covered ts-pr-review and ts-code-review). Mitigation: KTD-6 replace-don't-stack.
- **Standard/skill-rule drift.** Two statements of one rule can diverge. Mitigation: KTD-5 single canonical home plus citation; `docs/standards/index-standards.md` duplicate-coverage discipline.
- **INDEX description derivation.** `scripts/update-indexes.py` builds the row from the standard's first paragraph; a vague opener becomes a vague index row. Mitigation: write the first paragraph as the one-line description, per `index-standards.md`.
- **Script-reference gate.** `walkthrough.md` carries `${CLAUDE_PLUGIN_ROOT}`-prefixed script references that `scripts/verify-script-refs.sh` enforces; rewrites must preserve them.

## Sources & Research

- Issue #222 body — problem statement, proposed fix, acceptance criteria, "other places to check" list.
- `skills/ts-doc-review/references/walkthrough.md` — section map: never-merge rule at "Per-finding presentation" opening, terminal block and question-stem specs, routing question, cascade confirmation, no-fix sub-question.
- `skills/ts-doc-review/references/bulk-preview.md` — compressed preview line format; "the plan above" stems.
- `skills/ts-doc-review/references/synthesis-and-presentation.md` — Phase 5 terminal question; completion summary printed before it.
- `skills/ts-doc-review/references/review-output-template.md` — existing internal-enum vocabulary rule for user-facing output (existing repo policy, independent of this plan).
- `docs/standards/INDEX.md`, `docs/standards/testing-standards.md`, `docs/standards/index-standards.md` — standard format, INDEX row conventions, generator behavior.
- `docs/solutions/behavioral-ktd-verification.md` — behavioral vs literal KTD split applied above.
- `docs/solutions/tooling-decisions/compliance-gate-scope-classification.md` — wire-standard-references-same-change guidance; issue #118 residual-tracking precedent.
- Repo research: CI gate inventory (`.github/workflows/ci.yml` — no gate validates skill markdown question text), word-count baseline tooling, cross-skill blocking-question site inventory for the U4 audit list.
