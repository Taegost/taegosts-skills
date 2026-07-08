---
name: ts-verify-implementation
description: "Verify a feature branch implementation against its plan. Reviews for correctness, completeness, scope, and standards compliance."
user_invocable: true
---

# Verify Implementation Skill

Reviews a feature branch against its plan by delegating to 4 parallel review agents via bootstrap dispatch (file paths, not inline content): correctness, completeness, scope, and standards.

## Usage

```bash
/ts-verify-implementation <plan-filename>
/ts-verify-implementation 2026-06-18-003-feat-migration-to-knap-dir-plan.md
/ts-verify-implementation
```

If no argument is provided, list available plans and prompt the user to specify one.

## Dispatch Model

This skill uses the **bootstrap dispatch pattern** — reviewers receive file paths, not inline content. Each reviewer reads its own operating contract, role prompt, and schema from disk.

**Bootstrap pattern:** load skill → execute → return result.

When locating scripts, consult `docs/ROUTING.md` first to find the correct paths via INDEX.md files:
- Core scripts: `scripts/INDEX.md`
- Skill-specific scripts: `skills/ts-verify-implementation/scripts/INDEX.md`
- Reviewer agents: `references/agents/` (read directly)

## Process

### 1. Determine base branch

```bash
base_branch=$(scripts/context-gather.sh | python3 -c "import sys, json; print(json.load(sys.stdin)['default_branch'])")
```

### 2. Load the plan

Invoke `/load-plan` to discover and load the plan. The skill resolves the plan path through explicit path (if provided), PR body scanning, or branch name extraction:
- If `$ARGUMENTS` is provided, pass it as an explicit path: `/load-plan plan:$ARGUMENTS`
- If `$ARGUMENTS` is empty, use auto-discovery: `/load-plan`

Store the returned **plan path** and **plan content** for all subsequent steps.

**Extract KTD specifications:**

After loading the plan, extract the Key Technical Decisions section using the plan path returned by `load-plan`:
```bash
python3 scripts/extract-ktds.py "<plan-path>"
```

This returns a JSON object with `plan`, `ktds`, and `count` fields. The `ktds` field contains an array of KTDs with their type markers (`[literal]` or `[behavioral]`). Store the `ktds` array for cross-referencing in Step 4.

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

1. **Literal KTDs** (`[literal]` type): Run deterministic script comparison. Write the KTD spec to a unique temporary file to avoid shell interpretation of special characters and concurrent-run conflicts:
   ```bash
   KTD_SPEC_FILE=$(mktemp /tmp/ktd-spec-XXXXXX.txt)
   printf '%s\n' '<KTD spec text>' > "$KTD_SPEC_FILE"
   python3 scripts/verify-ktd-literal.py --spec-file "$KTD_SPEC_FILE" --file "<target-file>"
   rm -f "$KTD_SPEC_FILE"
   ```
   The script returns JSON with `match: true/false` and a diff if mismatched. Include this output in the subagent's context.

2. **Behavioral KTDs** (`[behavioral]` type): Use LLM subagent verification with criteria from `docs/solutions/behavioral-ktd-verification.md`. The subagent evaluates whether the implementation follows the intent of the decision.

3. **Both types**: The subagent's verdict incorporates the KTD verification results. For literal KTDs, the script result is authoritative. For behavioral KTDs, the subagent applies the behavioral criteria.

**Structured KTD input format:**

```text
KTD-N [type]: <spec text> | <files it applies to>
```

Launch all 4 verifiers in parallel. For each verifier, read the corresponding agent file from `references/agents/` and spawn a generic subagent using the subagent template at `references/subagent-template.md`.

| Verifier | Agent file | Focus |
|----------|-----------|-------|
| Correctness | `references/agents/correctness-verifier.md` | Logic errors, behavioral deviations, plan contradictions |
| Completeness | `references/agents/completeness-verifier.md` | Missing, partially done, or skipped plan items |
| Scope | `references/agents/scope-verifier.md` | Changes not called for in the plan |
| Standards | `references/agents/standards-verifier.md` | Convention, naming, style violations |

Each subagent receives:
- The agent file content (identity, scope, calibration, suppress conditions)
- The full plan content
- The git diff of all changes
- The structured KTD list
- Re-verification context (if re-verifying a prior round's findings)

### 5. Run coverage-gap detection

Run the coverage-gap detector to flag changed scripts without corresponding test files:

```bash
scripts/detect-coverage-gaps.sh "$base_branch"
```

The detector autonomously discovers changed files via `git diff` and checks whether each changed script has a corresponding test file in `tests/`. No line threshold — if a script was changed, it needs a test. Add any gaps found as findings in the results (severity: Major).

### 6. Consolidate results

Each subagent outputs a verdict (PASS / FAIL / PARTIAL) followed by a bulleted list of findings with file and line references. Consolidate into a single summary table:

| # | Severity | File | Issue |
|---|----------|------|-------|

Group by severity (Critical → Major → Minor). Include a final verdict and list of items confirmed correct.
