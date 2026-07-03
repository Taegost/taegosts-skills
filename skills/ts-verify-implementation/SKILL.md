---
name: ts-verify-implementation
description: "Verify a feature branch implementation against its plan. Reviews for correctness, completeness, scope, and standards compliance."
user_invocable: true
---

# Verify Implementation Skill

Reviews a feature branch against its plan by launching 4 parallel review subagents: correctness, completeness, scope, and standards.

## Usage

```bash
/ts-verify-implementation <plan-filename>
/ts-verify-implementation 2026-06-18-003-feat-migration-to-knap-dir-plan.md
/ts-verify-implementation
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

**Extract KTD specifications:**

After reading the plan, extract the Key Technical Decisions section:
```bash
python3 scripts/extract-ktds.py docs/plans/$ARGUMENTS
```

This returns a JSON array of KTDs with their type markers (`[literal]` or `[behavioral]`). Store these for cross-referencing in Step 4.

**KTD classification:**
- `[literal]` KTDs: Regex patterns, code snippets, exact strings. Verified using deterministic script comparison.
- `[behavioral]` KTDs: Patterns, approaches, constraints. Verified using LLM subagent judgment.
- If a KTD has no type marker, default to `[literal]` (safer default).

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

Each subagent receives the plan content, the git diff, and the extracted KTD list. If this is a re-verification run (commits after initial implementation), pass context about what was previously found and fixed so subagents can focus on verifying fixes landed correctly and checking for NEW issues. Do not re-verify already-fixed findings.

**KTD verification workflow:**

For each KTD extracted in Step 2:

1. **Literal KTDs** (`[literal]` type): Run deterministic script comparison:
   ```bash
   python3 scripts/verify-ktd-literal.py --spec "<KTD spec text>" --file <target-file>
   ```
   The script returns JSON with `match: true/false` and a diff if mismatched. Include this output in the subagent's context.

2. **Behavioral KTDs** (`[behavioral]` type): Use LLM subagent verification with criteria from `docs/solutions/behavioral-ktd-verification.md`. The subagent evaluates whether the implementation follows the intent of the decision.

3. **Both types**: The subagent's verdict incorporates the KTD verification results. For literal KTDs, the script result is authoritative. For behavioral KTDs, the subagent applies the behavioral criteria.

**Structured KTD input format:**
```
KTD-N [type]: <spec text> | <files it applies to>
```

Launch all 4 in parallel:

**Subagent 1 — Correctness:**
For each changed file, verify the implementation matches the plan. Flag logic errors, behavioral deviations, or anything that contradicts the plan. For literal KTDs, verify the script output shows `match: true`. For behavioral KTDs, verify the implementation satisfies the intent per `docs/solutions/behavioral-ktd-verification.md`.

**Subagent 2 — Completeness:**
Cross-reference every item in the plan (Requirements, Implementation Units, Files, Test scenarios, Verification criteria, KTDs) against what was implemented. Flag anything missing, partially done, or skipped. For literal KTDs, verify the script output shows `match: true` for all referenced files. For behavioral KTDs, verify the implementation capability exists per `docs/solutions/behavioral-ktd-verification.md`.

**Subagent 3 — Scope:**
Flag any changes NOT called for in the plan — files touched beyond what was needed, logic altered past what was asked, or additions the plan doesn't account for.

**Subagent 4 — Standards:**
Review the changes against project instruction files and any linting or formatting config files in the repo root. Flag violations of repo conventions, naming, structure, or code style.

### 5. Consolidate results

Each subagent outputs a verdict (PASS / FAIL / PARTIAL) followed by a bulleted list of findings with file and line references. Consolidate into a single summary table:

| # | Severity | File | Issue |
|---|----------|------|-------|

Group by severity (Critical → Medium → Low → Info). Include a final verdict and list of items confirmed correct.
