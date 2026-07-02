# Plan: Script the PR Review Pipeline

## Context

The PR review workflow (`/pr-review`) currently relies on the LLM running ad-hoc `gh` commands inline, building JSON payloads by hand, and re-implementing logic that already exists in helper scripts. This makes every review inconsistent and error-prone — the review just posted on PR #11 hit a JSON escaping bug that required rewriting the payload with Python.

Three changes will make the mechanical parts repeatable:
1. Extract `post-review.sh` (U18) — the most error-prone step
2. Update `validate-findings-json.sh` to match the current P0-P3 schema
3. Wire existing scripts into the skill definitions so the LLM calls scripts instead of re-implementing logic

## Change 1: Extract `post-review.sh`

**File:** `skills/pr-review/scripts/post-review.sh` (new)

**Purpose:** Accept a findings JSON file + PR context, build the review payload, post via GitHub API, fall back to flat comment on failure.

**Inputs:**
- `--repo owner/repo` (required)
- `--pr <number>` (required)
- `--sha <commit-sha>` (required)
- `--title <pr-title>` (required, for the review body header)
- `--findings <file>` (required, path to JSON findings file)

**Findings JSON input format** (what the LLM produces):
```json
[
  {
    "file": "path/to/file.ext",
    "line": 42,
    "severity": "High",
    "summary": "one-sentence bug description",
    "failure_scenario": "concrete inputs → wrong output"
  }
]
```

**Behavior:**
1. Validate inputs (R10: reject metacharacters in repo/pr)
2. Check `gh auth status`
3. Read findings JSON, validate with `validate-findings-json.sh`
4. Determine `event`:
   - Any High/Moderate findings → `REQUEST_CHANGES`
   - Only Minor/Info findings → `APPROVE`
   - If GitHub rejects REQUEST_CHANGES on own PR → fall back to `COMMENT`
5. Build review payload using embedded Python (safe JSON construction):
   - `body`: verdict summary with severity counts
   - `commit_id`: from `--sha`
   - `comments[]`: one per finding with structured body (severity emoji, Summary, Description, Severity, Proposed Fix, AI Prompt)
6. Post via `gh api repos/{owner}/{repo}/pulls/{number}/reviews --input <tmpfile>`
7. On API failure, fall back to `gh pr comment {number} --body <flat comment>`
8. Output: review URL to stdout

**Tests:** `tests/skills/pr-review/test-post-review.sh`
- Test --help flag
- Test missing required args
- Test metacharacter rejection
- Test with mock findings JSON (verify payload structure via dry-run or captured gh call)
- Test fallback behavior when review API fails

**Conventions to follow:**
- `#!/usr/bin/env bash` + `set -euo pipefail`
- `cat <<'EOF'` for help text
- `SCRIPT_DIR` for cross-script calls
- Errors to stderr, JSON/result to stdout
- Exit codes: 0 success, 1 error

## Change 2: Update `validate-findings-json.sh`

**File:** `scripts/validate-findings-json.sh` (existing, rewrite internals)

**What changes:**
- Severity values: `Critical|High|Moderate|Minor|Info` → `P0|P1|P2|P3` (but also accept the old values for backward compat during transition)
- Required fields: `title`, `severity`, `file`, `description` → `title`, `severity`, `file`, `line`, `why_it_matters`, `autofix_class`, `owner`, `requires_verification`, `confidence`, `evidence`, `pre_existing`
- Enum validation for `autofix_class` (`gated_auto|manual|advisory`), `owner` (`downstream-resolver|human|release`), `confidence` (`0|25|50|75|100`)
- Keep the existing exit code convention: 0 valid, 1 script error, 2 validation failure
- Keep the `pass`/`fail` output to stdout, errors to stderr
- Fix the `2>&1` bug that merges validation errors into stdout

**What stays the same:**
- File path: `scripts/validate-findings-json.sh`
- Positional arg: `<findings-json-file>`
- Exit codes: 0/1/2
- Uses embedded Python for validation

**Tests:** `tests/scripts/test-validate-findings-json.sh` (existing, update)
- Test valid findings with all 11 required fields
- Test missing required field → fail
- Test invalid severity value → fail
- Test invalid enum value → fail
- Test old severity values (Critical/High/etc.) → fail (new schema only)

## Change 3: Wire Scripts into Skill Definitions

### 3a. Update `skills/pr-review/SKILL.md`

Replace inline `gh` commands with script calls:

| Current (inline) | New (script call) |
|---|---|
| `gh pr view N --json ...` | `scripts/pr-metadata.sh --repo owner/repo --pr N` |
| Run ID generation (inline bash) | `scripts/run-id.sh` |
| `gh api repos/.../pulls/N/reviews --input` | `skills/pr-review/scripts/post-review.sh --repo ... --pr N --sha ... --title ... --findings ...` |

Add a new Step 0 that resolves scripts:
```
SCRIPTS_DIR="<repo-root>/scripts"
SKILL_SCRIPTS_DIR="<repo-root>/skills/pr-review/scripts"
```

Update Step 2 (gather PR state) to call `pr-metadata.sh` and `detect-diff-scope.sh` instead of raw `gh` commands.

Update Step 4 (post review) to call `post-review.sh` instead of inline JSON construction.

Remove the inline JSON payload schema from the skill — it now lives in `post-review.sh`.

Update severity scale in the skill from `Critical|High|Moderate|Minor|Info` to match the P0-P3 schema used by ce-code-review, with a mapping table:
- P0 = Critical (security, data loss, crash)
- P1 = High (functional bug, incorrect behavior)
- P2 = Moderate (code quality, missing validation)
- P3 = Minor/Info (style, suggestions)

### 3b. Update `skills/ce-code-review/SKILL.md`

Replace inline logic with script calls in Stage 1:

| Current (inline) | New (script call) |
|---|---|
| Run ID generation (inline bash) | `scripts/run-id.sh` |
| Diff scope detection (inline git commands) | `scripts/detect-diff-scope.sh --pr N` or `--base ref` |
| Default branch resolution (inline cascade) | `scripts/default-branch.sh` |
| PR metadata fetch (inline `gh pr view`) | `scripts/pr-metadata.sh --repo ... --pr N` |

The sub-agent spawning (Stage 4), merge pipeline (Stage 5), and validation (Stage 5b) stay as LLM-driven — those require judgment.

### 3c. Sync severity scales

The pr-review skill uses `Critical|High|Moderate|Minor|Info`. The ce-code-review skill uses `P0|P1|P2|P3`. These need to be reconciled.

**Decision:** Standardize on `P0|P1|P2|P3` across both skills. The `post-review.sh` script maps P0-P3 to the emoji and verdict logic:
- P0/P1 → `REQUEST_CHANGES`
- P2 → `REQUEST_CHANGES` (or `COMMENT` if all are P2)
- P3 → `APPROVE`

Update the pr-review SKILL.md severity section to use P0-P3 with the mapping table above.

## Implementation Order

1. **Change 2** — Update `validate-findings-json.sh` (no dependencies, needed by Change 1)
2. **Change 1** — Extract `post-review.sh` (depends on updated validator)
3. **Change 3a** — Wire scripts into pr-review SKILL.md
4. **Change 3b** — Wire scripts into ce-code-review SKILL.md
5. **Change 3c** — Sync severity scales

## Files Modified

| File | Action |
|---|---|
| `scripts/validate-findings-json.sh` | Rewrite internals |
| `tests/scripts/test-validate-findings-json.sh` | Update tests |
| `skills/pr-review/scripts/post-review.sh` | New file |
| `tests/skills/pr-review/test-post-review.sh` | New file |
| `skills/pr-review/SKILL.md` | Update to reference scripts, sync severity |
| `skills/ce-code-review/SKILL.md` | Update Stage 1 to reference scripts |

## Verification

1. Run existing test suite: `bash tests/run-all.sh` (108 tests should still pass)
2. Run updated validator tests: `bash tests/scripts/test-validate-findings-json.sh`
3. Run new post-review tests: `bash tests/skills/pr-review/test-post-review.sh`
4. Manual test: run `/pr-review` on a real PR and verify the review posts correctly with inline comments
5. Verify `post-review.sh` fallback: simulate API failure and confirm flat comment is posted
