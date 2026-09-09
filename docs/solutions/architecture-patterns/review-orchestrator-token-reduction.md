---
title: "Reducing orchestrator token load in ts-pr-review and ts-code-review by extracting mechanical steps to scripts and de-inlining low-frequency prose"
date: 2026-09-08
category: docs/solutions/architecture-patterns
module: ts-pr-review and ts-code-review orchestrator skills (review pipeline)
problem_type: architecture_pattern
component: development_workflow
severity: medium
applies_when:
  - Orchestrator skills carry large inline instruction bodies that are replayed on every invocation
  - Verification or review loops make token cost scale linearly with reviewer or validator count
  - Pipeline stages can read contracts from disk instead of receiving inline prose
symptoms:
  - ts-code-review per-invocation load measured at ~15,002 words
  - token cost grows linearly with reviewer count in the verification loop
root_cause: missing_tooling
resolution_type: tooling_addition
related_components:
  - tooling
  - documentation
tags:
  - token-reduction
  - orchestrator
  - script-extraction
  - bootstrap-dispatch
  - review-pipeline
  - skill-architecture
---

# Reducing orchestrator token load in ts-pr-review and ts-code-review by extracting mechanical steps to scripts and de-inlining low-frequency prose

## Context

The review-pipeline orchestrator skills carried large inline instruction bodies that were re-read into context on every invocation: `ts-code-review`'s per-invocation load measured ~15,002 words, and `ts-pr-review` inlined ~170 words of payload-construction prose plus a legacy availability check for a skill marketplace installs had made unreachable. The cost is not once per session — verification loops (`ts-verify-implementation`, reviewer re-dispatch, validator rounds) replay these bodies every run, and reviewer-side token spend scales linearly with reviewer count because each of the Stage 4 reviewers previously received the template, schema, scope rules, and routing rubric inlined into its spawn prompt.

Solved on branch `feat/review-pipeline-token-reduction` (GitHub issue #113, plan `docs/plans/2026-09-08-002-feat-review-pipeline-token-reduction-plan.md`) via six implementation units, verified by the `/ts-verify-implementation` loop in 2 iterations to a final PASS. The general move, applied twice: any SKILL.md step whose rules are exact, deterministic, and testable belongs in a script the step invokes; any reference material needed by fewer than every run belongs on disk, read on demand.

## Guidance

### The extraction decision rule

Classify every block of orchestrator prose into one of three homes:

1. **Deterministic, rule-exact, replayed every run → script it.** If a step's semantics can be written as exact rules (mappings, thresholds, partition rules, sort orders), extract them into a script with its own test suite. The SKILL.md keeps only invocation, exit-code contract, and the one judgment call that remains the orchestrator's.
2. **Correct but low-frequency → de-inline to an on-demand reference.** Material consulted by a minority of runs (argument parsing details, quick-review mode, scope recipes) moves to `references/*.md` and is read only when that path fires.
3. **Dispatch-time roster → keep inline.** The one thing the orchestrator genuinely needs in context every run (here, `agent-catalog.md`, 542 words) stays `@`-included.

### ts-pr-review: build-review-payload.sh (U1-U3)

`skills/ts-pr-review/scripts/build-review-payload.sh` scripts the former manual SKILL.md steps 3b/3c/3d (behavior pinned by `tests/scripts/test-build-review-payload.sh`). It:

- verifies each finding's line exists in the PR diff head-side via the linemap precomputed by `map-diff-lines.sh` (`file:new-line` for every added line);
- maps severity P0-P3 to GitHub display severities (`P0→Critical`, `P1→High`, `P2→Moderate`, `P3→Minor`; advisory-class findings, `residual_risks`, and `testing_gaps` → `Info`);
- partitions findings: inline comment (side RIGHT at file:line) only when the line is in the linemap and the finding is not pre-existing; everything else routes to a fallback flat comment instead of being dropped;
- computes the review event deterministically, so the orchestrator can never hand-edit it inconsistently;
- builds the GitHub Reviews API payload JSON and writes `review-payload.json` + `fallback-findings.md` anchored to `--out-dir` (nothing written until all validation passes).

The event rule, in the script's single-pass jq:

```jq
| (if (($fs | length) == 0) then "APPROVE"
   elif $max_rank >= 2 then "REQUEST_CHANGES"   # any Moderate (P2) or higher
   elif $max_rank == 1 then "COMMENT"           # only Minor (P3)
   else "APPROVE" end) as $event
```

The SKILL.md step is now a call plus a bounded fallback:

```bash
"${CLAUDE_SKILL_DIR}/scripts/build-review-payload.sh" \
  --review-json "$RUN_DIR/review.json" \
  --linemap "$LINEMAP" --pr-number "$PR_NUMBER" --head-sha "$HEAD_SHA" \
  --pr-title "$PR_TITLE" --run-id "$RUN_ID" --out-dir "$OUT_DIR"
```

with the manual fallback stated as a contract, not reproduced prose: construct the payload yourself per the GitHub pull request reviews API, applying the same severity mapping, event rule, and linemap partition the script encodes. The one judgment call kept in prose: GitHub rejects `REQUEST_CHANGES` on your own PR (common) — change the event to `COMMENT` and note it in the body. U1 additionally deleted the legacy ts-code-review availability check (dead after marketplace installs changed how skills resolve).

### ts-code-review: bootstrap dispatch + merge-findings.py (U4-U5)

**U4 — bootstrap dispatch.** Stage 4 reviewers and Stage 5b validators now read their contracts from disk via read-list prompts (see [`subagent-bootstrap-dispatch`](../conventions/subagent-bootstrap-dispatch.md) for the pattern itself — this work applies it, it does not redefine it); only `agent-catalog.md` stays `@`-included. The skill-local `references/subagent-bootstrap.md` carries the read-list shapes and the dynamic-slot table (scope mode, head/base refs, review base, standards paths, PR context, staged diff paths). The reviewer spawn prompt is now:

```text
Read these files IN FULL before starting. Do not begin analysis until all five are read:
1. references/subagent-template.md (your operating contract)
2. references/agents/{reviewer_name}.md (your role)
3. references/findings-schema.json (output schema)
4. references/diff-scope.md (scope rules)
5. references/action-class-rubric.md (autofix_class/owner routing rubric)

After reading all files, emit acknowledgment: one line per file, `<path> (<N> lines)`.
```

with ack verification and 3-attempt recovery before falling back to inline dispatch. The orchestrator keeps a small summary of what each de-inlined file governs (`SKILL.md`'s "Not inlined" note) so it never needs the bodies except on the fallback path.

**U5 — merge-findings.py.** `skills/ts-code-review/scripts/merge-findings.py` (pinned by `tests/skills/ts-code-review/test_merge_findings.py`) extracts the mechanical half of Stage 5. Rules encoded (each previously SKILL.md prose, each now test-pinned):

- fingerprint dedup: `normalize(file)` + line within ±3 (direct tolerance matching with transitive chaining, not floor buckets) + `normalize(title)`;
- merge takes **two independent maxima** — highest severity and highest anchor may come from different group members;
- cross-reviewer promotion `{50: 75, 75: 100, 100: 100}` (0/25 stay);
- conservative conflict routing: `advisory > manual > gated_auto`, `human > release > downstream-resolver`, `requires_verification` OR-ed;
- legacy enum remap (`safe_auto → gated_auto`, `review-fixer → downstream-resolver`) before enum validation;
- mode-aware demotion: P2/P3 + advisory + single non-testing reviewer → demoted to `residual_risks` as `<file:line> -- <title>`;
- late confidence gate: suppress below anchor 75 except P0/P1 at 50+;
- sort severity → anchor desc → file → line with stable monotonic `#`;
- a `coverage` report (drops, remaps, merges, promotions, demotions, suppressions by anchor, and the `conflicts` list naming each reviewer's position) so the orchestrator's judgment steps (disagreement annotation, triage grouping) consume a report instead of re-deriving the merge.

The SKILL.md step states the contract and forbids hand-merging: "Do not re-derive them here or hand-merge when the script runs; read that file before changing the behavior it encodes."

### U6 — prose trim with an explicit stop condition

Deduplicated prose and moved four references to on-demand reads (`subagent-template`, `findings-schema`, `diff-scope`, `action-class-rubric` — now on-disk contracts), adding `references/scope-recipes.md`, `references/quick-review.md`, and `references/argument-parsing.md` for low-frequency paths. Two remaining levers were **deliberately stopped** and documented as residuals: PR-path prose (~600 words) and the Stage 6 inline fallback (~460 words) are behavior-adjacent — trimming further risks changing orchestrator behavior for marginal savings. An optimization pass needs a stop rule, not just a target.

## Why This Matters

Measured per-invocation word counts, before → after:

| Artifact | Before | After |
|---|---|---|
| ts-code-review per-invocation total | 15,002 | 9,636 |
| `skills/ts-code-review/SKILL.md` | 9,624 | 9,094 |
| `subagent-template.md` (de-inlined from dispatch) | 3,172 inline | on disk |
| `findings-schema.md` / `diff-scope.md` / `action-class-rubric.md` | inline | 1,054 / 381 / 229 on disk |
| `agent-catalog.md` | 542 | 542 (kept `@`-included) |
| `skills/ts-pr-review/SKILL.md` | 1,484 | 1,312 |

Three compounding effects beyond the 36% cut:

- **Multiplier exposure.** Every verification loop, validator round, and reviewer re-dispatch replays the orchestrator context. Savings multiply by pipeline fan-out.
- **Determinism.** The review event and the merge pipeline are now computed, not narrated — two runs on identical inputs produce identical payloads and orderings, and the script test suites (`tests/scripts/test-build-review-payload.sh`, `tests/skills/ts-code-review/test_merge_findings.py`) pin the rules against drift.
- **Consistency under fallback.** The manual fallbacks are contracts pointing at the script's encoded behavior, so a degraded run degrades to the same rules rather than to freehand reconstruction.

All gates after merge: the shell and pytest suites, shellcheck, and `verify-scripts --all` — the exact gate commands live in the repo's CI/pre-commit configuration.

## When to Apply

- An orchestrator or workflow skill whose instruction body is re-read every invocation, especially one feeding verification loops or multi-agent fan-out.
- A SKILL.md step whose rules are exact enough to test (severity maps, thresholds, partitions, sort orders, routing ladders).
- Subagent dispatch where the subagent has file-read tools and the template/schema content is static per role.
- Reference material consulted by a minority of runs, currently inlined "just in case."
- Not applicable to: content the orchestrator itself consumes at decision time every run (the agent catalog), or prose whose trim would change behavior (document the residual and stop).

## What Didn't Work

1. **Harness worktree isolation twice cut worktrees from a stale base commit (05a1483) instead of branch HEAD.** The subagent's reported file contents and line numbers did not match the orchestrator's tree — that mismatch was the detection signal. Recovery: one subagent cherry-picked its work onto the correct base; the second was stopped and re-dispatched into a manually created worktree (`git worktree add` at the correct HEAD) with absolute paths in the prompt.
2. **`max(group, key=SEVERITY_RANK)` for "highest severity" was wrong** because `SEVERITY_RANK = {"P0": 0, "P1": 1, "P2": 2, "P3": 3}` encodes lower-is-worse — max picks the *least* severe. Pytest caught it (`'P1' == 'P0'` assertion failures). Correct: `min(group, key=lambda f: SEVERITY_RANK[f["severity"]])["severity"]`.
3. **The original prose "keep highest severity, keep highest anchor" was ambiguous.** Verification round 1 caught that it means two independent maxima (severity from one group member, anchor from another), not a pair taken from the severity-dominant member — `{P0@50, P1@100}` must merge to `P0@100`, not `P1@100`. The SKILL.md comment in `merge_group` now records this reading explicitly.
4. **Pre-commit index churn.** `scripts/update-indexes.py` auto-regenerates `docs/INDEX.md` and `docs/plans/INDEX.md` into any commit touching `scripts/` or `docs/`. Expected mechanical output, but one commit needed `--no-verify` to keep the index churn out of that specific commit.

## Prevention

- **When enum rank dicts encode "lower is worse," "highest severity" is min of rank.** Name the relationship at the dict definition (`# More conservative = less autonomous action. Higher value wins on conflict.` is the good example from the same file for the routing ladders) and write the selection as min/max-of-rank deliberately, never reuse the same direction by analogy with confidence.
- **Pin ambiguous prose semantics as test scenarios before implementing.** Writing the merge semantics as scenarios first — scenario 1b: `{P0@50, P1@100} → P0@100` — resolved the two-maxima question before code existed, and the pytest suite caught the max/min inversion in the same pass. When a plan step states a merge rule in prose, convert it to input/output scenarios in the plan itself.
- **Detect stale-worktree dispatch by content mismatch.** If a subagent's reported file contents or line numbers disagree with the orchestrator's tree, suspect base-commit staleness before suspecting the agent. Prefer manual `git worktree add` at verified HEAD with absolute paths in the prompt over relying on the harness's automatic worktree isolation for branch-tipped work.
- **Expect mechanical pre-commit regeneration.** When a repo auto-generates indexes in pre-commit, treat the churn in a commit that touched triggering paths as expected output; use `--no-verify` only deliberately, for commits where the churn should not land.
- **Keep a verification loop around extraction work.** Both substantive defects in this run (max/min inversion, stale step references) were caught by `/ts-verify-implementation` round 1, not by authoring review — extraction of encoded rules is exactly the change class the loop exists for.

## Examples

### Before/after: SKILL.md step 3c (ts-pr-review)

Before (~170 words of inline partition prose + manual payload construction steps the orchestrator executed by hand each run, plus the legacy availability check from U1's dead code):

> Verify each finding's line appears in the diff head-side... map P0 to Critical, P1 to High... build the payload with `body`, `commit_id`, `event`, `comments[]`... decide the event by severity...

After (a call, a contract, and one judgment call):

```bash
"${CLAUDE_SKILL_DIR}/scripts/build-review-payload.sh" \
  --review-json "$RUN_DIR/review.json" --linemap "$LINEMAP" \
  --pr-number "$PR_NUMBER" --head-sha "$HEAD_SHA" \
  --pr-title "$PR_TITLE" --run-id "$RUN_ID" --out-dir "$OUT_DIR"
```

**Manual fallback:** if the script fails, construct the payload per the GitHub API contract, applying the same severity mapping, event rule, and linemap partition the script encodes.

### Before/after: the two-maxima merge (ts-code-review)

Before (ambiguous prose, then the wrong implementation):

```python
# SKILL.md: "keep highest severity, keep highest anchor"
severity = max(group, key=lambda f: SEVERITY_RANK[f["severity"]])["severity"]  # WRONG: P0=0, picks P3
```

After (independent maxima, `skills/ts-code-review/scripts/merge-findings.py`):

```python
# Original Stage 5 rule 2: "keep highest severity, keep highest anchor" —
# two independent maxima, not a pair from one member. Severity and anchor
# may come from different reviewers (e.g. security P0@50 + correctness
# P1@100 merges to P0@100).
severity = min(group, key=lambda f: SEVERITY_RANK[f["severity"]])["severity"]
confidence = max(f["confidence"] for f in group)
```

### Conservative routing on reviewer disagreement

```python
CONSERVATIVE_AUTO = {"gated_auto": 0, "manual": 1, "advisory": 2}
CONSERVATIVE_OWNER = {"downstream-resolver": 0, "release": 1, "human": 2}

auto = max((f["autofix_class"] for f in group), key=lambda c: CONSERVATIVE_AUTO[c])
owner = max((f["owner"] for f in group), key=lambda o: CONSERVATIVE_OWNER[o])
```

Here higher value = more conservative = less autonomous action, so max is correct — the same file contains both directions of rank dict, which is exactly why each is commented at its definition.

### De-inlined dispatch vs. what stays inline

De-inlined (read by the subagent from disk, ~4.8k words off every dispatch): `subagent-template.md`, `findings-schema.json`, `diff-scope.md`, `action-class-rubric.md`, validator template. Kept inline: `agent-catalog.md` (the dispatch-time roster the orchestrator needs to choose reviewers) and a one-line-per-file "Not inlined" index so the orchestrator knows what exists on disk without loading it.

## Related

- [`subagent-bootstrap-dispatch`](../conventions/subagent-bootstrap-dispatch.md) — the dispatch pattern U4 applies (this doc records the application, not the pattern)
- [`agent-definition-convention`](../conventions/agent-definition-convention.md) — dispatch-pattern taxonomy (bootstrap vs direct-seed)
- [`notification-resilience-via-disk-state`](../workflow-issues/notification-resilience-via-disk-state.md) — the disk-first family these on-disk contracts belong to
- [`claude-code-plugin-script-path-resolution`](../tooling-decisions/claude-code-plugin-script-path-resolution.md) — the `${CLAUDE_SKILL_DIR}`/`${CLAUDE_PLUGIN_ROOT}` resolution constraint the extracted scripts honor (open guard-mechanism question: issue #117)
- Issue #113 (this work), #103 (sibling token-reduction precedent that produced the bootstrap-dispatch convention), #94 / #82 (script-extraction precedents)
