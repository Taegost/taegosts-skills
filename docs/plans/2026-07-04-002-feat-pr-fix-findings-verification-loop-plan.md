---
title: "feat: Add holistic verification loop to ts-pr-fix-findings"
type: feat
date: 2026-07-04
status: completed
---

# Add Holistic Verification Loop to ts-pr-fix-findings

## Summary

After `ts-pr-fix-findings` fixes PR review findings, it has two verification gaps: (1) Step 6 lets implementers skip resolution checking when a fix diverges from the reviewer's approach, so fixes can land without actually resolving the finding; (2) there's no holistic branch check for regressions, scope creep, or plan violations. This plan addresses both: strengthening Step 6's per-finding resolution verification and adding a post-fix holistic verification step that invokes `ts-verify-implementation`.

## Problem Frame

Issue #87: "When it completes, it doesn't verify if it has caused any further problems or if the changes follow the plan."

Step 6 of `ts-pr-fix-findings` has two verification gaps:

1. **Per-finding resolution gap.** Step 6's semantic verification says "If your planned remediation didn't match the criteria given by the reviewer, skip this question." This escape hatch means when the implementer deliberately diverges from the reviewer's request, no one checks whether the divergent fix actually resolves the reviewer's concern. Technical verification only confirms the edit landed, not that it solves the problem.

2. **Holistic branch gap.** Step 6 catches edit failures but not holistic problems: a fix might introduce scope creep, break a KTD, or violate conventions in an adjacent file. The skill has no mechanism to catch these.

## Requirements

R1. After all individual fixes are verified (Step 6), the skill runs a holistic branch verification against the feature plan using the same 4-dimension model as `ts-verify-implementation` (correctness, completeness, scope, standards).

R2. The holistic verification is conditional on a feature plan being loaded in Step 0a. When no plan exists, the skill relies on Step 6's per-fix verification only.

R3. If holistic verification finds new issues, the findings are dispositioned, planned, and remediated through the existing Steps 3-6 flow, then holistic verification runs again.

R4. The verification loop is capped at 2 iterations. If verification still fails after the cap, remaining findings are surfaced to the user in the Step 9 summary.

R5. The existing Step 6 per-fix verification is preserved — it catches edit failures cheaply before the heavier holistic check runs.

R6. Step 6 must verify that each fix actually resolves the reviewer's original finding, regardless of whether the remediation matches the reviewer's requested approach. The "skip this question" escape hatch for divergent remediations is removed — divergence is allowed, but resolution is still verified.

## Key Technical Decisions

**KTD1: Compose, don't generalize.** `ts-pr-fix-findings` invokes `ts-verify-implementation` as a sub-skill rather than reimplementing its verification logic. Rationale: `ts-verify-implementation` already has the 4-agent model, agent files, subagent template, and KTD verification scripts. `ts-do-work-loop` demonstrates this composition pattern successfully. Reimplementing would create drift.

**KTD2: Two verification steps with distinct purposes.** Step 6 (per-fix technical + resolution verification with per-finding retry loop) and Step 6a (holistic branch verification) serve different purposes. Step 6 catches edit failures and verifies each fix resolves the reviewer's concern, looping back to Step 3 when it doesn't. Step 6a catches regressions across the whole branch. Both are needed — they catch different failure modes at different costs.

**KTD3: Conditional on plan availability.** The verification loop only runs when Step 0a successfully loaded a feature plan. Without a plan, the 4 verification agents lack the reference document for correctness, completeness, and scope checks. Standards verification could run independently, but a partial check is misleading — skip entirely rather than deliver half a verification.

**KTD4: Divergence is allowed, but resolution is mandatory.** Step 6 currently lets implementers skip semantic verification when their fix deliberately diverges from the reviewer's request. This escape hatch is removed. The implementer may fix a finding differently than the reviewer suggested, but they must still verify the fix resolves the reviewer's core concern. The loop back to Step 3 triggers when the fix doesn't resolve the finding, not when it doesn't match the reviewer's suggested approach.

## Implementation Units

### U1. Add Step 6a: Holistic branch verification to ts-pr-fix-findings

**Goal:** Add a new step between Step 6 (per-fix verification) and Step 7 (update PR) that invokes `ts-verify-implementation` for holistic branch verification.

**Requirements:** R1, R2, R5

**Dependencies:** None

**Files:**
- `skills/ts-pr-fix-findings/SKILL.md`

**Approach:**

Insert a new Step 6a after Step 6 with the following logic:

1. **Gate:** Check if a feature plan was loaded in Step 0a. If no plan was loaded, skip to Step 7 and note that holistic verification was skipped (no plan available).
2. **Invoke:** Run `ts-verify-implementation <plan-filename>` passing only the plan filename (not the full `docs/plans/` path), since `ts-verify-implementation` prepends `docs/plans/` to its argument internally. Note: `ts-do-work-loop` passes the full path to `ts-verify-implementation`, which would double-prefix — this plan uses filename-only to match `ts-verify-implementation`'s actual interface.
3. **Evaluate verdict:**
   - `PASS` → proceed to Step 7
   - `PARTIAL` or `FAIL` → parse `ts-verify-implementation`'s Step 5 summary table to extract findings (each has Severity, File, and Issue columns). Map these to the verification finding format for Step 6b triage. If the output is unparseable or missing the summary table, treat as execution failure.
   - **Execution failure** → if `ts-verify-implementation` fails to execute or returns an unparseable result, surface the error to the user in the Step 9 summary and proceed to Step 7 without blocking. Do not silently skip verification.

The step should reference `ts-verify-implementation` by skill name, not inline its logic. The invocation follows the same pattern as `ts-do-work-loop` Step 2.

**Patterns to follow:**
- `skills/ts-do-work-loop/SKILL.md` — composition pattern for invoking `ts-verify-implementation`
- `skills/ts-verify-implementation/SKILL.md` — the verification process being invoked

### U2. Add Step 6b: Verification failure loop

**Goal:** When holistic verification fails, loop the new findings back through the existing remediation flow.

**Requirements:** R3, R4

**Dependencies:** U1

**Files:**
- `skills/ts-pr-fix-findings/SKILL.md`

**Approach:**

Add Step 6b after Step 6a with the following logic:

1. **Triage new findings:** Present the verification findings to the user with proposed dispositions using the same fix/decline/needs-input model as Step 2b. The user may decline a verification finding if they judge it incorrect or accept it as a false positive. Label findings as `verification-round-N` to distinguish them from reviewer findings.
2. **Loop:** Route through Steps 3-6 (plan fix → validate → remediate → per-fix verify) for the new findings.
3. **Re-verify:** After the loop completes, return to Step 6a for holistic verification.
4. **Loop guard:** Cap at 2 total iterations of Steps 6a-6b. If verification still fails after the cap:
   - Add remaining verification findings to the Step 9 summary table
   - Note in the PR update (Step 7) that holistic verification found unresolved issues
   - Do not block the PR update — the user decides whether to address remaining findings

**Kanban integration:** Create new Kanban cards for verification findings (same format as Step 2c), tagged with `[verification-round-N]` to distinguish from original review findings.

### U3. Update Step 9 summary to reflect verification results

**Goal:** The final summary table includes verification findings and their resolution status.

**Requirements:** R4

**Dependencies:** U1, U2

**Files:**
- `skills/ts-pr-fix-findings/SKILL.md`

**Approach:**

Extend Step 9 to include:
- A "Verification" row in the summary showing the verification verdict (PASS / FAIL / skipped-no-plan)
- If verification found issues, a sub-table of verification findings with their resolution status
- If the loop cap was hit, a note listing unresolved verification findings

### U4. Strengthen Step 6 resolution verification

**Goal:** Remove the "skip this question" escape hatch and add explicit resolution verification for every fix, including divergent remediations.

**Requirements:** R6

**Dependencies:** None

**Files:**
- `skills/ts-pr-fix-findings/SKILL.md`

**Approach:**

Modify Step 6's semantic verification section:

1. **Remove the escape hatch.** Delete "If your planned remediation didn't match the criteria given by the reviewer, skip this question."
2. **Add resolution verification.** After confirming the edit landed (existing technical verification), add a mandatory check:
   - Re-read the reviewer's original finding criteria from the PR review comment to extract the specific concern
   - Check whether the modified code addresses that concern — for code-change findings, verify the relevant code path now behaves correctly; for style/convention findings, verify the pattern matches
   - If the fix diverges from the reviewer's suggested approach, explicitly note the divergence and explain why the alternative approach still satisfies the reviewer's underlying concern
   - If resolution cannot be confirmed, treat as unresolved and loop back to Step 3 for that finding
3. **Preserve the loop guard.** The existing 10-iteration cap per finding remains.

The key change: the loop condition shifts from "edit didn't land" to "edit didn't resolve the finding." An edit can land perfectly (technical verification passes) but still not address what the reviewer flagged (resolution verification fails).

**Patterns to follow:**
- `skills/ts-pr-fix-findings/SKILL.md` Step 6 — existing verification structure, extend rather than rewrite

### U5. Update README for new ts-verify-implementation dependency

**Goal:** Update the README skills table and prose to reflect the new runtime dependency on `ts-verify-implementation`.

**Requirements:** R1

**Dependencies:** U1

**Files:**
- `README.md`

**Approach:**

1. Update the README skills table row for `/ts-pr-fix-findings` to include `ts-verify-implementation` in the Dependencies column: change from `/ts-debug (included), /load-plan` to `/ts-debug (included), /load-plan, /ts-verify-implementation`.
2. Update the Dependencies prose section that says "/ts-pr-fix-findings uses /ts-debug" to mention the new verification dependency.

**Test expectation:** none — documentation update only.

## Scope Boundaries

### Deferred to Follow-Up Work

- **Generalize `ts-verify-implementation` to accept diff input.** Currently it always computes `git diff ${base_branch}...HEAD`. For `ts-pr-fix-findings`, the diff is already available. A future enhancement could accept an explicit diff parameter, but the current behavior is correct — it diffs against the base branch, which is what we want for holistic verification.

- **`ts-verify-implementation` changes.** This plan assumes `ts-verify-implementation` works as-is when invoked from `ts-pr-fix-findings`. If issues arise during implementation (e.g., the plan path resolution differs between skills), they should be fixed in `ts-verify-implementation` as a separate concern.

### Outside this product's identity

- **Automated CI verification.** This plan adds verification to the skill workflow, not to CI. CI-level verification of PR fixes is a separate infrastructure concern.

## Open Questions

None — the approach is well-bounded by the existing `ts-do-work-loop` composition pattern.

## Risks & Dependencies

- **Risk:** `ts-verify-implementation` may not find the plan when invoked as a sub-skill (path resolution). **Mitigation:** Pass only the plan filename (not the full `docs/plans/` path) to `ts-verify-implementation`, since it prepends `docs/plans/` to its argument internally. Note: `ts-do-work-loop` passes the full path, which would double-prefix — this plan deliberately uses filename-only to match `ts-verify-implementation`'s actual interface.
- **Risk:** Verification loop adds token cost for PRs with many findings. **Mitigation:** The cap at 2 iterations bounds cost. Step 6 catches cheap failures before the expensive holistic check runs.
- **Dependency:** `ts-verify-implementation` must be available as a skill. This is already a dependency of `ts-do-work-loop` and is installed in the same plugin.

## Test Scenarios

### U1 test scenarios

1. **Happy path — plan loaded, verification passes:** Invoke `ts-pr-fix-findings` on a PR with a matching plan. After fixes land, Step 6a invokes `ts-verify-implementation` and gets PASS. The skill proceeds to Step 7 without looping.
2. **No plan available:** Invoke `ts-pr-fix-findings` on a PR with no matching plan (Step 0a finds nothing). Step 6a is skipped. The summary notes "holistic verification skipped (no plan)."
3. **Verification finds issues:** Invoke `ts-pr-fix-findings` on a PR where fixes introduce scope creep. Step 6a gets FAIL with scope findings. The findings flow through Step 6b.

### U2 test scenarios

4. **Loop succeeds on second iteration:** First verification round finds a standards violation. The violation is fixed. Second verification round passes. Summary shows 2 verification rounds, final verdict PASS.
5. **Loop cap hit:** First verification finds issues. Fixes are applied. Second verification still finds issues (different or persistent). The loop cap is reached. Summary shows unresolved verification findings. PR is still updated.
6. **Findings disposition:** Verification findings are presented to the user with proposed dispositions before remediation. The user can decline or redirect verification findings just like reviewer findings.

### U3 test scenarios

7. **Summary includes verification verdict:** After a successful run, the Step 9 summary table includes a "Verification: PASS" row.
8. **Summary includes unresolved findings:** After hitting the loop cap, the Step 9 summary lists unresolved verification findings with their severity and file references.

### U4 test scenarios

9. **Divergent fix resolves finding:** Reviewer says "use regex X." Implementer uses a different approach (e.g., parser instead of regex). Step 6 verifies the parser produces the same result the reviewer wanted. Resolution passes, no loop.
10. **Divergent fix doesn't resolve finding:** Reviewer says "handle null case." Implementer adds a default value but the null path still exists. Step 6 detects the concern isn't resolved. Loops back to Step 3.
11. **Fix matches reviewer request:** Standard case — fix matches what the reviewer asked for. Resolution passes.
12. **Loop cap per finding:** Fix is attempted 10 times and still doesn't resolve. Finding is skipped with a note for the user.
