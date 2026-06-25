---
name: verify-implementation
description: "Verify a feature branch implementation against its plan. Reviews for correctness, completeness, scope, and standards compliance."
user_invocable: true
---

# Verify Implementation Skill

Reviews a feature branch against its plan by launching 4 parallel review subagents: correctness, completeness, scope, and standards.

## Usage

```bash
/verify-implementation <plan-filename>
/verify-implementation 2026-06-18-003-feat-migration-to-knap-dir-plan.md
/verify-implementation
```

If no argument is provided, list available plans and prompt the user to specify one.

## Process

### 1. Determine base branch

```bash
base_branch=$(git remote show origin 2>/dev/null | grep 'HEAD branch' | awk '{print $NF}')
if [ -z "$base_branch" ]; then
  base_branch=$(git branch --list main master develop trunk | head -1 | sed 's/^[* ]*//')
fi
```

### 2. Read the plan

Read `docs/plans/$ARGUMENTS`. If no argument was provided, run `ls docs/plans/` and prompt the user to specify which plan to use.

### 3. Get feature branch changes

```bash
git diff ${base_branch}...HEAD
```

### 3a. Detect missing vs. awaiting manual step

After getting the diff, check whether files listed in the plan that are absent from the diff exist on disk (even if gitignored). Distinguish between:
- **Missing entirely** — file does not exist on disk (Critical)
- **Awaiting manual step** — file exists on disk but is gitignored, e.g. SealedSecret templates awaiting kubeseal (Warning, not Critical)
- **Committed** — file is in the diff (Pass)

### 4. Launch 4 parallel subagents

Each subagent receives the plan content and the git diff. If this is a re-verification run (commits after initial implementation), pass context about what was previously found and fixed so subagents can focus on verifying fixes landed correctly and checking for NEW issues. Do not re-verify already-fixed findings.

Launch all 4 in parallel:

**Subagent 1 — Correctness:**
For each changed file, verify the implementation matches the plan. Flag logic errors, behavioral deviations, or anything that contradicts the plan.

**Subagent 2 — Completeness:**
Cross-reference every item in the plan (Requirements, Implementation Units, Files, Test scenarios, Verification criteria) against what was implemented. Flag anything missing, partially done, or skipped.

**Subagent 3 — Scope:**
Flag any changes NOT called for in the plan — files touched beyond what was needed, logic altered past what was asked, or additions the plan doesn't account for.

**Subagent 4 — Standards:**
Review the changes against CLAUDE.md and any linting or formatting config files in the repo root. Flag violations of repo conventions, naming, structure, or code style.

### 5. Consolidate results

Each subagent outputs a verdict (PASS / FAIL / PARTIAL) followed by a bulleted list of findings with file and line references. Consolidate into a single summary table:

| # | Severity | File | Issue |
|---|----------|------|-------|

Group by severity (Critical → Medium → Low → Info). Include a final verdict and list of items confirmed correct.
