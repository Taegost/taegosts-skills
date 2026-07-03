# Walk-Through Decisions — 2026-07-02-004 Plan Review

Review date: 2026-07-03
Document: `docs/plans/2026-07-02-004-fix-review-skills-plan-validation-plan.md`

## Applied Fixes (safe_auto, anchor 100)

| # | Section | Fix | Reviewer |
|---|---------|-----|----------|
| 1 | R5 | Matched tier 2 conditional phrasing to KTD1: "or pick the most recent plan if none have been modified" | coherence |
| 2 | R6 | Removed `ts-pr-review` from direct consumer list; added note that it inherits transitively via `ts-code-review` | feasibility |
| 3 | U12 | Changed "U12 depends on U5-U10" to "U5-U9" (U10 is a peer, not a dependency) | coherence |
| 4 | U1 ts-do-work-loop | Added frontmatter update note: description and argument-hint must change from mandatory to optional | feasibility |
| 5 | U6 | Added explicit `blockedBy: [U8]` dependency annotation | feasibility + adversarial |

## Walk-Through Decisions

| # | Severity | Title | Decision | Rationale |
|---|----------|-------|----------|-----------|
| 1 | P1 | Scope bloat: U5-U12 are carryover from prior hardening plan | **Apply** — condense U5-U12 into a single verification unit | After U1-U4 are implemented, use updated verification logic to confirm prior hardening plan was fully complete. Collapses 8 units into 1. |
| 2 | P1 | load-plan replaces ts-code-review's richer discovery | **Apply** — use ts-code-review's logic as basis for load-plan | Extract ts-code-review's existing plan discovery logic and make it the basis for the shared load-plan skill, rather than building a simpler version. |
| 3 | P1 | KTD extraction mechanism unspecified | **Apply** — specify extraction in consumers, not load-plan | load-plan only locates and loads the plan. Consumers extract KTDs by parsing markdown headers for "Key Technical Decisions" section. |
| 4 | P1 | load-plan branch-matching algorithm unspecified | **Apply** — document keyword extraction from ts-code-review | Since load-plan uses ts-code-review's logic, the algorithm is keyword extraction from branch name. Document in KTD1 and load-plan SKILL.md. |
| 5 | P1 | No evidence of real user pain | **Apply** — cite hardening plan as evidence | The previous hardening pass (2026-07-02-003) skipped many things that were part of the plan. Cite this in the Problem Frame as concrete evidence of the drift problem. |
| 6 | P1 | load-plan error contract missing | **Apply** — ask user on error | When load-plan encounters an error, ask the user what to do (consistent with tier 3 fallback). |
| 7 | P1 | KTD literal/behavioral classification unspecified | **Apply** — author-labeled with literal default | Plan authors label each KTD with `[literal]` or `[behavioral]`. Default to literal if unclassified. Add a unit of work to update documentation to reflect this standard. |
| 8 | P1 | Behavioral KTD verification lacks concrete criteria | **Apply** — add criteria, gate on user approval | Add explicit verification criteria for behavioral KTDs. Logic needs user approval before implementation. Document in standards. |
| 9 | P2 | No failure mode for KTD mismatch | **Skip** | Failure handling logic already exists in each skill. |
| 10 | P2 | U2-U4 verification lack test scenarios | **Apply** — add test scenarios matching U1's format | Add concrete test scenarios to U2, U3, and U4 with happy paths, edge cases, and error paths. |
| 11 | P2 | load-plan single point of failure | **Apply** — two-phase migration | Phase 1: create load-plan, migrate only ts-pr-fix-findings. Phase 2: after validation, migrate remaining skills. |
| 12 | P2 | Three-tier fallback may produce wrong matches | **Apply** — ask on ambiguity, add plan: argument | Always ask the user when no match exists. Add `plan:` argument for non-interactive callers. |
| 13 | P2 | KTD literal comparison false positives | **Apply** — define normalization policy in standards | Define concrete normalization policy for whitespace, quoting, multi-line snippets. Document in standards. |
| 14 | P2 | Issue #79 mismatches never enumerated | **Apply** — add mismatch list to plan | Add a section listing each of the 10 mismatches with descriptions and requirement mappings. |
| 15 | P3 | ts-work migration label wrong | **Apply** — fix phase reference | Change "Phase 0 inline discovery" to "Phase 1 step 1 inline glob discovery (triggered by blank invocation via Phase 0)." |
| 16 | P3 | U4 step insertion location inconsistent | **Apply** — match U1 notation | Change "Step 1.5" to "between Step 0 and Step 1" to match U1's notation. |
| FYI-2 | P2 | Machine-readable KTD format not considered | **Promote to Apply** — standardize prose, create Python extractor | Keep prose markdown, standardize formatting, create Python script to extract KTDs. |
| FYI-5 | P3 | No priority tiers | **Promote to Apply** — add P1/P2 tiers | P1: core fix (U1-U4), P2: verification (condensed U5). |

## Pending Findings (not yet walked through)

### Actionable (gated_auto / manual at anchor 75/100)

- [x] **[P1]** KTD extraction mechanism unspecified (adversarial, 100, manual) — Applied
- [x] **[P1]** load-plan branch-matching algorithm unspecified (adversarial, 100, manual) — Applied
- [x] **[P1]** No evidence of real user pain (product-lens, 75, manual) — Applied
- [x] **[P1]** load-plan error contract missing (adversarial, 75, manual) — Applied
- [x] **[P1]** KTD literal/behavioral classification unspecified (adversarial, 75, manual) — Applied
- [x] **[P1]** Behavioral KTD verification lacks criteria (scope-guardian, 75, manual) — Applied
- [x] **[P2]** No failure mode for KTD mismatch (scope-guardian, 75, manual) — Skipped
- [x] **[P2]** U2-U4 verification lack test scenarios (scope-guardian, 75, manual) — Applied
- [x] **[P2]** load-plan single point of failure (product-lens, 75, manual) — Applied
- [x] **[P2]** Three-tier fallback may produce wrong matches (product-lens, 75, manual) — Applied
- [x] **[P2]** KTD literal comparison false positives (product-lens, 75, manual) — Applied
- [x] **[P2]** Issue #79 mismatches never enumerated (adversarial, 75, gated_auto) — Applied
- [x] **[P3]** ts-work migration label wrong (adversarial, 75, gated_auto) — Applied
- [x] **[P3]** U4 step insertion location inconsistent (coherence, 75, gated_auto) — Applied

### FYI Observations (anchor 50, no decision required)

- [x] **[P2]** ts-pr-fix-findings cross-reference adds complexity (product-lens, 50) — Already addressed
- [x] **[P2]** Alternative blindness: machine-readable KTD (adversarial, 50) — Promoted to Apply
- [x] **[P3]** load-plan doesn't handle git diff failure (feasibility, 50) — Already addressed
- [x] **[P3]** ts-pr-review inheritance claim (scope-guardian, 50) — Already fixed by Applied #2
- [x] **[P3]** No priority tiers (product-lens, 50) — Promoted to Apply
- [x] **[P3]** Detached HEAD not handled (adversarial, 50) — Already addressed

### Residual Concerns

- U9 title says "Add test" but approach says "audit and fill" (coherence)
- Plans may be incomplete when read mid-implementation (adversarial)

### Deferred Questions

- U6 approach references "scripts with `..` checks" but only lists test files — which scripts? (coherence)
- U5 applies metacharacter tests to files that depend on the hardening plan — should U5 depend on that? (coherence)
