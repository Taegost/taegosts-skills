---
title: "Skills lacked plan KTD specification validation"
date: 2026-07-03
category: docs/solutions/tooling-decisions
module: skills/ts-verify-implementation, skills/ts-work, skills/load-plan
problem_type: tooling_decision
component: development_workflow
severity: medium
applies_when:
  - Skills need to validate implementations against plan KTD specifications
  - Plan documents contain literal or behavioral KTDs that must be cross-referenced during implementation
  - No centralized mechanism exists to extract, locate, or verify KTDs from plan files
tags:
  - ktd-validation
  - plan-verification
  - tooling
  - skills-infrastructure
  - literal-comparison
  - behavioral-verification
---

# Skills lacked plan KTD specification validation

## Context

Skills that verify or implement feature branches had no mechanism to cross-reference their work against Key Technical Decisions (KTDs) in the plan document, meaning literal specifications (regex patterns, code snippets, exact strings) and behavioral constraints were never validated against the actual implementation.

## Guidance

The fix introduced five components that together close the KTD verification gap:

### 1. Centralized plan discovery (`skills/load-plan/`)

A new `load-plan` skill with three-tier discovery: explicit path, PR body scanning, and branch-name keyword extraction. Supports both interactive and non-interactive modes via `--non-interactive`, making it safe for agent use.

```
# Interactive
/load-plan

# Agent mode
/load-plan --non-interactive

# Explicit path
/load-plan plan:docs/plans/2026-07-02-004-fix-plan.md
```

Discovery priority: explicit path > PR body (`gh pr view`) > branch name extraction (`scripts/locate-plan.py`).

### 2. Non-interactive plan discovery (`scripts/locate-plan.py`)

Extracts keywords from the current git branch name (stripping prefixes like `feature/`, `fix/` and ticket numbers), then scores plan filenames in `docs/plans/` by keyword overlap. Returns JSON with `path` and `error` fields -- never prompts the user.

### 3. KTD extraction (`scripts/extract-ktds.py`)

Parses the "Key Technical Decisions" section from a plan markdown file. Extracts each KTD with its type marker (`[literal]` or `[behavioral]`), title, spec text, and referenced files. Supports both old-format (`**KTD1. Title.**`) and new-format (`**KTD1 [literal]. Title.**`). Unmarked KTDs default to `[literal]` for safety.

### 4. Deterministic literal verification (`scripts/verify-ktd-literal.py`)

Compares a `[literal]` KTD spec against a target file using normalization rules from `docs/solutions/ktd-normalization-policy.md`:

- Strip leading/trailing whitespace and per-line trailing whitespace
- Preserve relative indentation within multi-line snippets
- Normalize ANSI-C quoting (`$'...'`) to double-quote equivalents
- Strip inline code backticks (markdown formatting)
- Single-newline normalization for multi-line comparisons

Returns JSON with `match: true/false`, the normalized spec, and a unified diff on mismatch. Exit code 0 for match, 1 for mismatch, 2 for error.

### 5. Skill enhancements

**`ts-verify-implementation`**: After reading the plan, calls `extract-ktds.py` to get the KTD list. Each literal KTD is verified via `verify-ktd-literal.py` before subagent launch. Subagent prompts include KTD verification results -- literal KTDs use script output as authoritative; behavioral KTDs use the criteria from `docs/solutions/behavioral-ktd-verification.md`.

**`ts-pr-fix-findings`**: Calls `/load-plan --non-interactive` to load the plan, extracts KTDs, and cross-references each reviewer finding against KTD specifications. Detects KTD conflicts (reviewer request contradicts a KTD) and scope violations (proposed fix breaks an architectural decision).

**`ts-work`**: Calls `extract-ktds.py` after reading the plan. Inlines KTD spec text into each Implementation Unit's context so implementers see the exact constraint. Literal KTDs become "verification constraint" checklist items; behavioral KTDs become intent-based constraints.

## Why This Matters

The root cause was a missing integration layer between plan documents and skill execution. Plans specified KTDs, but skills never consumed them programmatically. The solution addresses this at three levels:

1. **Discovery** -- `load-plan` provides a single entry point for plan context, eliminating duplicated discovery logic and making plan loading reliable in agent mode.

2. **Extraction** -- `extract-ktds.py` converts plan prose into structured KTD objects that skills can programmatically process, with explicit type markers enabling different verification strategies.

3. **Verification** -- `verify-ktd-literal.py` replaces unreliable LLM judgment with deterministic string comparison for literal KTDs, while `behavioral-ktd-verification.md` provides structured criteria for behavioral KTDs. This ensures both types are verified against a consistent standard.

The normalization policy is critical: without it, trivial formatting differences (whitespace, quoting style, markdown backticks) would produce false mismatches, eroding trust in the verification system.

## When to Apply

- Skills need to validate implementations against plan KTD specifications
- Plan documents contain literal or behavioral KTDs that must be cross-referenced during implementation
- No centralized mechanism exists to extract, locate, or verify KTDs from plan files

## Examples

### Before: No KTD verification

```python
# ts-verify-implementation only checked general correctness
# Never verified that literal KTD specs appeared in implementation
subagent_prompt = "Verify the implementation matches the plan..."
```

### After: KTD-aware verification

```python
# Extract KTDs from plan
ktds = subprocess.run(["python3", "scripts/extract-ktds.py", plan_path])

# Verify literal KTDs deterministically
for ktd in ktds:
    if ktd["type"] == "literal":
        result = subprocess.run([
            "python3", "scripts/verify-ktd-literal.py",
            "--spec", ktd["spec"],
            "--file", target_file
        ])
        # Include result in subagent context
```

### Load-plan usage

```bash
# Agent mode (non-interactive)
/load-plan --non-interactive

# With explicit path
/load-plan plan:docs/plans/2026-07-02-004-fix-plan.md
```

## Related

- [Behavioral KTD Verification](../behavioral-ktd-verification.md) — Companion document defining behavioral KTD verification criteria
- [KTD Normalization Policy](../ktd-normalization-policy.md) — Literal KTD normalization rules
- [Script Security Standards](../script-security-standards.md) — Shell script security standards
- [Plan: Fix review skills plan validation](../../plans/2026-07-02-004-fix-review-skills-plan-validation-plan.md) — Parent plan that produced this fix
- [Prior hardening plan](../../plans/2026-07-02-003-fix-pr-work-script-hardening-plan.md) — Plan whose incomplete execution demonstrated the drift problem
