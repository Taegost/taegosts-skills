---
name: coding-workflow
description: "The mandatory workflow for all coding tasks. Plan → review → doc-review → work. Never skip steps."
triggers:
  - "Start a coding task"
  - "Implement a feature"
  - "Fix a bug in code"
  - "Work on a PR"
  - "Begin implementation"
---

# Coding Workflow (Mandatory)

This is the required process for ALL coding tasks across ALL projects. Do not skip steps.

## The Workflow

### Phase 0: Setup

1. **Load script-index** — read `skills/script-index/SKILL.md` to know what tools are available
2. **Add scripts to PATH** — detect skill directory and add both `scripts/` and `skills/*/scripts/` to PATH:

   ```bash
   SKILL_DIR="$(cd "$(dirname "$(find . -name "script-index" -path "*/skills/*" -type d | head -1)")" && pwd)"
   SKILL_BASE="$SKILL_DIR/.."
   export PATH="$SKILL_BASE/scripts:$PATH"
   for d in "$SKILL_BASE/skills"/*/scripts; do
     [[ -d "$d" ]] && export PATH="$d:$PATH"
   done
   ```

### Phase 1: Planning

1. **Create a new branch** from main (or sync fork first if working from a fork)
2. **Run `/ce-plan`** to create a plan document in `docs/plans/`
3. **Present the plan to Mike** for review. Do NOT proceed until he approves.
4. **Run `/ce-doc-review`** on the plan. This may take multiple iterations:
   - Mike reviews findings
   - Fix issues in the plan
   - Re-run doc-review
   - Repeat until Mike approves the plan
5. **Only after Mike explicitly approves** → proceed to Phase 2

### Phase 2: Implementation

6. **Run `do-work-loop`** with the approved plan path. Do NOT use raw `/ce-work`.
   - do-work-loop cycles between ce-work and verify-implementation
   - It catches things a single ce-work pass misses

### Phase 3: Completion

7. If the work resulted in a pull request, use `/pr-fix-findings` to address any review feedback (CodeRabbit, Mike, etc.)
8. **Mike merges** the PR
9. **I sync my fork** main from upstream

## Rules

- **Phase 1 gate:** If a plan already exists that may pertain to the requested work, ask Mike whether to use the existing plan or create a new one. A plan from a previous session may not address the current request — do not assume it does.
- **Never skip Phase 1.** Even if the work seems like a continuation, go through the planning cycle. Each piece of work is its own unit.
- **Never use raw `/ce-work`.** Always use `do-work-loop`.
- **Never start coding before Mike approves the plan.** The plan is the contract.
- **Each PR is a separate piece of work.** Don't carry implementation from one PR into the next without going through Phase 1 again.
- **This applies to ALL coding tasks**, not just taegosts-skills. Homelab-k8s, personal projects, work repos — same process.

## Why This Exists

Mike has ADHD. Follow-through is hard. The plan-review-doc-review cycle creates external structure that prevents:
- Jumping into code without understanding the problem
- Missing edge cases that a single implementation pass would catch
- Scope creep from unreviewed plans
- Rework from misunderstood requirements

The workflow is the ADHD coping mechanism for coding. Respect it.

## Verification Scripts (MUST use)

Before committing ANY code change, run these scripts:

```bash
# After each file edit — confirm the change actually landed
verify-fix.sh --file <path> --should-contain "new text"
verify-fix.sh --file <path> --should-not-contain "old text"

# Before committing — check all scripts pass validation
verify-scripts.sh --all

# When building JSON output in bash — use this instead of printf
to-json.sh key1=value1 key2=value2
```

These scripts are in the skills repo — detect the skill directory and add `scripts/` and `skills/*/scripts/` to PATH at session start (use the loop pattern from Phase 0).

**Do NOT use grep/sed/Python str.replace for verification.** Use verify-fix.sh.
**Do NOT use printf for JSON construction.** Use to-json.sh.

