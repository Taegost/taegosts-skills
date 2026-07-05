---
name: ts-pr-review
description: "USE THIS when asked to review a PR or when a PR needs a fresh review. Dispatches the ts-code-review multi-agent pipeline, posts findings as inline comments. NOT for fixing findings (use ts-pr-fix-findings for that)."
user_invocable: true
---

# PR Review Skill

Reviews a pull request by dispatching the `ts-code-review` skill, then posts its findings to the PR as inline review comments.

## Usage

```bash
/ts-pr-review <link to PR>
/ts-pr-review PR #1
/ts-pr-review 1
```

If no argument is provided, list open PRs and prompt the user to specify one.

## Non-negotiable process constraints

These are always-constraints. Violating any of them means the review is invalid and must not be posted.

1. **The review MUST come from the `/ts-code-review` skill.** Reading the diff yourself and writing up findings is NOT a review, no matter how thorough it feels. If you have findings but did not invoke `/ts-code-review` in this session, you have skipped the process — stop and go back to step 2.
2. **HARD GATE before posting:** Step 4 consumes findings ONLY from the `ts-code-review` run artifact (`review.json`). If that file does not exist on disk, you cannot proceed to step 4. There is no fallback path that lets you post self-generated findings.
3. **No tool-call budget.** Use as many tool calls as the process requires. The multi-agent review pipeline is expected to make many calls; this is correct behavior, not waste. Never skip, truncate, or substitute a lighter review to save calls. (Avoid *redundant* calls — re-fetching data you already have — but never trade process steps for call count.)

## Process

### 1. Ensure the ts-code-review skill is available

Verify availability with a concrete check — do not assume:

- Confirm the `/ts-code-review` slash command is present in the available skills/commands list, OR
- Confirm its skill file exists on disk (e.g., `ls` the plugin's skills directory).

If it is not available, stop and alert the user. Do not continue, and do not perform a review yourself as a substitute.

### 2. Dispatch the review via ts-code-review

Invoke the `ts-code-review` skill in agent mode, passing the PR through:

```
/ts-code-review <PR number or URL> mode:agent
```

Rules for this invocation:

- **Do NOT pass `base:`** alongside the PR target — `ts-code-review` treats that combination as a conflict and will abort.
- **Do NOT check out the PR branch.** `ts-code-review` handles PR scope itself (`pr-remote` / `local-aligned` detection) without mutating the working tree.
- `mode:agent` returns a single JSON object and writes the full run artifact to `/tmp/taegosts-skills/ts-code-review/<run-id>/` — including `review.json`. This artifact is the sole source of findings for step 4.
- Handle the JSON `status` field:
  - `"skipped"` (PR closed/merged/trivial) — relay the reason to the user and stop.
  - `"failed"` or `"degraded"` — relay the reason to the user and stop. Do NOT fall back to reviewing the diff yourself.
  - `"complete"` — continue to step 3.

### 3. Verify the run artifact (HARD GATE)

Before doing anything else, confirm the artifact exists:

```bash
RUN_DIR="/tmp/taegosts-skills/ts-code-review/<run-id-from-json>"
test -f "$RUN_DIR/review.json" && echo "GATE PASSED" || echo "GATE FAILED"
```

- **GATE FAILED:** Stop. Report to the user that `ts-code-review` did not produce its run artifact. Do not post anything to the PR. Do not reconstruct findings from memory or from the JSON response alone if it conflicts with a missing/failed run.
- **GATE PASSED:** Read `review.json`. All findings, severities, file paths, and line numbers for step 4 come from this file — not from your own reading of the diff.

If `review.json` reports zero findings, post a brief approving review (or comment) noting the clean result, then go to step 5.

### 4. Post the review to the pull request

Each finding MUST be a separate inline review comment (conversation thread), not part of one flat comment. Use the GitHub pull request review endpoint to post all findings as a single review with multiple inline comments.

#### 4a. Gather review metadata

Fetch PR metadata in a single call (if not already available from earlier in the session):

```bash
gh pr view NUMBER --json title,state,headRefOid,comments,reviews
```

- `headRefOid` is the `commit_id` for the review. Cross-check it against `scope.head_sha` / `scope.pr_url` in `review.json` — if the PR head has moved since the review ran, warn the user and ask whether to re-run rather than posting stale line numbers.
- If you have already reviewed this PR in a prior run, read the responses to your previous comments and use them to inform framing (e.g., note which prior findings were addressed).

#### 4b. Map and verify line numbers

Findings in `review.json` already carry `file` and `line` (new-file line numbers). Before posting, verify each finding's line is commentable — i.e., it appears as an added or context line in the PR diff. Save the diff once and build the verification map from it:

```bash
gh pr diff NUMBER > /tmp/ts-pr-review-diff.txt

awk '/^\+\+\+ /{file=substr($2,3); next}
     /^@@/{match($0, /\+[0-9]+/); line=substr($0, RSTART+1, RLENGTH-1)+0; next}
     /^\+/{print file ":" line; line++; next}
     /^ /{line++}' /tmp/ts-pr-review-diff.txt > /tmp/ts-pr-review-linemap.txt
```

This outputs `file:new-file-line` for every added line. For each finding:

- Line present in the map -> post as an inline comment at that line with `side: "RIGHT"`.
- Line NOT present in the map (finding on an unchanged line, or a file not in the diff) -> route that finding to the fallback flat section (4e) instead of dropping it.

Parse the diff ONCE. Do not re-fetch or re-parse it per finding.

#### 4c. Build the review payload

Map `ts-code-review` severities to the display scale:

| ts-code-review | Display severity |
|----------------|------------------|
| P0 | Critical |
| P1 | High |
| P2 | Moderate |
| P3 | Minor |
| `advisory` findings / `residual_risks` / `testing_gaps` | Info |

Create a JSON file with the review body and inline comments. The `body` field is the top-level review summary (include the `ts-code-review` verdict and run ID for traceability). Each entry in `comments` becomes its own conversation thread:

```json
{
  "body": "## Code Review — PR #N: <title>\n\n**Verdict: <APPROVE|REQUEST_CHANGES>** (<ts-code-review verdict>)\n\n<overall assessment from review.json>\n\n_Review pipeline: ts-code-review run `<run-id>`_",
  "commit_id": "<head-sha>",
  "event": "COMMENT",
  "comments": [
    {
      "path": "relative/path/to/file.ext",
      "line": 42,
      "side": "RIGHT",
      "body": "### <severity emoji> Finding 1 — <Severity> | `file.ext` line 42\n\n**Summary:** <finding title>\n\n**Description:** <why_it_matters from review.json, max 10 lines>\n\n**Reason:** <evidence from review.json>\n\n**Severity:** <Critical|High|Moderate|Minor|Info>\n\n**Proposed Fix:** <suggested_fix, max 10 lines>\n\n**AI Prompt:** <prompt for an AI agent to validate and fix>"
    }
  ]
}
```

- `path` — file path relative to the repo root, matching the diff
- `line` — the line number in the **new file** (right side of the diff) where the comment should appear
- `body` — the full finding text (all fields: Summary, Description, Reason, Severity, Proposed Fix, AI Prompt)
- `side` — required for inline comments on PR diffs; set to `"RIGHT"` to comment on added/modified lines (the right side of the diff). The GitHub Reviews API requires this field to disambiguate which side of a diff the comment applies to. Omit it only when commenting on context lines (unchanged lines within a hunk)
- `event` — use `COMMENT` for findings; use `APPROVE` if all findings are Info-only; use `REQUEST_CHANGES` if any Moderate+ findings exist

#### 4d. Severity rules for the review event

- Any Moderate (P2) or higher finding -> `event: REQUEST_CHANGES`
- Only Info findings -> `event: APPROVE`
- Only Minor (P3) findings -> use judgment on `APPROVE` vs `REQUEST_CHANGES`
- If GitHub rejects `REQUEST_CHANGES` on your own PR (common), fall back to `COMMENT` and note in the body that changes are requested

#### 4e. Post the review

```bash
gh api repos/{owner}/{repo}/pulls/{number}/reviews --input review.json
```

**Fallback:** If the review API fails, or some findings target non-commentable lines (per 4b), post those findings in a single `gh pr comment` with each finding as a separate section split by `---` separators. Inline-postable findings still go through the review API; only the un-postable remainder uses the flat comment.

### 5. Display a summary to the user

- Give a brief summary of the number of items found and the `ts-code-review` verdict
- Include the run artifact path (`/tmp/taegosts-skills/ts-code-review/<run-id>/`) so the full report is auditable
- Include a table with the results:

| # | Severity | File | Issue |
|---|----------|------|-------|

Group by severity (Critical -> High -> Moderate -> Minor -> Info). Reuse the stable `#` values from `review.json` so findings can be cross-referenced between the PR comments, the summary, and the artifact.
- Include a final verdict