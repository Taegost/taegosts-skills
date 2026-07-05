---
title: "Composition over generalization for verification workflows"
date: 2026-07-04
category: docs/solutions/workflow-issues
module: skills/ts-pr-fix-findings
problem_type: workflow_issue
component: tooling
severity: low
applies_when:
  - "A skill needs verification logic that another skill already implements"
  - "Considering whether to generalize an existing skill vs composing it as a sub-skill"
tags:
  - verification
  - composition
  - skill-design
  - ts-pr-fix-findings
  - ts-verify-implementation
---

# Composition over generalization for verification workflows

## Context

When adding verification to `ts-pr-fix-findings`, we needed to decide whether to generalize `ts-verify-implementation` to handle both use cases or to compose it as a sub-skill. The two skills have different entry points and flows: `ts-verify-implementation` takes a plan filename and runs4 parallel verifiers; `ts-pr-fix-findings` takes a PR number and runs a fix-then-verify cycle.

## Guidance

When a skill needs verification logic that another skill already implements, compose (invoke as sub-skill) rather than generalize. The pattern is demonstrated by `ts-do-work-loop`, which invokes both `ts-work` and `ts-verify-implementation` as sub-skills.

**Key implementation details for composition:**

1. **Argument passing:** `ts-verify-implementation` prepends `docs/plans/` to its argument. Pass only the filename, not the full path, to avoid double-prefixing. Example: `Invoke /ts-verify-implementation 2026-07-04-002-plan.md`, not `Invoke /ts-verify-implementation docs/plans/2026-07-04-002-plan.md`.

2. **Conditional invocation:** Gate the sub-skill call on whether a feature plan was loaded. Without a plan, only per-finding verification runs (Step 6). With a plan, holistic verification (Step 6a) also runs.

3. **Failure handling:** On sub-skill execution failure, log a warning and continue to the next workflow step. Do not block the main workflow on verification infrastructure failures.

4. **Iteration cap:** When the sub-skill returns PARTIAL/FAIL, re-enter the fix loop but cap iterations (2 is a reasonable default). Report remaining findings to the user after exhausting the cap.

## Why This Matters

Generalizing a skill to handle multiple entry points increases its complexity and testing surface. Composition keeps each skill focused on a single task and reuses existing, tested logic. The `ts-do-work-loop` pattern (invoke verify after work) is a proven composition model that other skills can follow.

## When to Apply

- When adding verification to a skill that performs fixes
- When a new workflow needs logic that an existing skill already implements
- When the entry points and flows are different enough that merging would complicate both

## Examples

**Before (no verification):**
```
Step 5: Fix findings
Step 6: Review remediations
Step 7: Update PR
```

**After (composition):**
```
Step 5: Fix findings
Step 6: Review remediations (per-finding technical + resolution verification)
Step 6a: Holistic verification (invoke /ts-verify-implementation <filename>)
Step 6b: Verification failure loop (cap at 2 iterations)
Step 7: Update PR
```

**The `ts-do-work-loop` composition pattern:**
```
Step 1: Run /ts-work
Step 2: Run /ts-verify-implementation
Step 3: Evaluate verdict — PARTIAL/FAIL → repeat from Step 1
```

## Related

- `docs/solutions/tooling-decisions/ce-skills-extraction.md` — original skill extraction from compound-engineering-plugin
- `skills/ts-do-work-loop/SKILL.md` — the composition pattern this follows
