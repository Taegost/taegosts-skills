---
name: do-work-loop
description: "Run ce-work and verify-implementation in a loop until the plan is fully satisfied. Requires a plan file path. The central implementation loop for all plan-based work."
user_invocable: true
argument-hint: "[plan doc path or description of work]"
---

# Do Work Loop

The central implementation loop. Runs ce-work and verify-implementation in cycles until verification passes. Most plans require multiple passes — a single ce-work run typically misses things.

## Usage

```bash
/do-work-loop <plan-doc-path>
/do-work-loop docs/plans/2026-06-25-001-feat-script-extraction-pass-plan.md
/do-work-loop <description of work>
```

## Process

### 1. Run ce-work

Invoke `/ce-work $ARGUMENTS`. This reads the plan, creates the task list, and implements the work.

**GATE:** Verify that implementation work was performed — files were created or modified. If no changes were made, investigate why before continuing.

### 2. Run verify-implementation

Invoke `/verify-implementation $ARGUMENTS` (pass the same plan path). This launches 4 parallel review subagents to check correctness, completeness, scope, and standards.

### 3. Evaluate verdict

- **PASS** → proceed to step 4
- **PARTIAL** or **FAIL** → run `/ce-work $ARGUMENTS` again to address the findings, then return to step 2

**Continue this cycle until verify-implementation reports PASS.**

### 4. Post-completion (when verification passes)

1. Update the plan file's frontmatter `status` field from `pending` (or `active`) to `completed`
2. Run `/ce-compound Full, No Session History` to document what was learned
3. Commit and push
4. Summarize what was done

## Loop guard

Cap at 5 iterations. If verification still fails after 5 cycles:
- Report the remaining findings to the user
- Ask whether to continue iterating, address manually, or accept as-is
- Do not silently loop forever

## Why this exists

Single-pass ce-work misses things. Plans describe *what* not *how*, and the implementer (even an agent) makes judgment calls that don't always align with the plan's intent. Verification catches these gaps. Running ce-work again with the verification findings as additional context produces a tighter implementation than either pass alone.
