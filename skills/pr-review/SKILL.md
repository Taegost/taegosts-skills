---
name: pr-review
description: "USE THIS when asked to review a PR or when a PR needs a fresh review. Dispatches parallel reviewer personas, posts findings as inline comments. NOT for fixing findings (use pr-fix-findings for that)."
user_invocable: true
---

# PR Review Skill

Reviews a pull request, notes the PR, and gives AI instructions to follow

## Usage

```bash
/pr-review <link to PR>
/pr-review PR #1
/pr-review 1
```

If no argument is provided, list open PRs and prompt the user to specify one.

## Process

### Efficiency rules (MUST follow)

1. **Batch API calls** — fetch all PR data in 1-2 `gh` calls, not 6+
2. **Save the diff once** — write to `/tmp/pr-review-diff.txt` and reuse for both review and line mapping
3. **No re-fetching** — if you already have the data (head SHA, file list, comments), do not call `gh` again for the same data
4. **One line-number pass** — parse the saved diff to build a file→line mapping ONCE, then look up values from it
5. **Target: ≤5 tool calls total** for steps 2-4 (1 metadata fetch, 1 diff save, 1 review post, 1-2 for code-review skill)

### 1. Ensure code-review skill is available

If the `/code-review` skill is not available, stop and alert the user. Do not continue

### 2. Gather the state of the pull request (batch all API calls)

Make as few `gh` calls as possible. In a **single command**, fetch all PR metadata, comments, and reviews:

```bash
gh pr view NUMBER --json title,state,body,headRefName,baseRefName,headRefOid,author,comments,reviews,files
```

Then **save the diff to a temp file ONCE** — you will reuse it for both review and line number mapping:

```bash
gh pr diff NUMBER > /tmp/pr-review-diff.txt
```

- If you have already reviewed this particular PR:
  - View the comments and conversations from your previous comment
  - Ingest the feedback/responses. Use this information to inform your next iteration, if necessary
- If you have not already reviewed this particular PR:
  - View all comments and conversations for additional context/guidance
- Determine if there are any commits that require reviewing
  - If there aren't any commits that require reviewing, then stop and let the user know. Do not continue.
  
### 3. Review the pull request

- Use the `/code-review` skill to perform the review. Pass it the saved diff file (`/tmp/pr-review-diff.txt`) so it doesn't need to re-fetch.
- **IMPORTANT:** While reviewing, record the file path and new-file line number for each finding. Do NOT re-parse the diff later to find line numbers.

### 4. Add a review to the pull request with your findings

Each finding MUST be a separate inline review comment (conversation thread), not part of one flat comment. Use the GitHub API pull request review endpoint to post all findings as a single review with multiple inline comments.

#### 4a. Gather the review metadata

- The latest commit SHA should already be available from step 2's `headRefOid` field — do NOT make another API call
- Determine the file path and line number for each finding from the **saved diff file** (`/tmp/pr-review-diff.txt`)

**Line number mapping (CRITICAL for speed):** The diff line number is NOT the new-file line number. To map correctly, parse the saved diff file once to build a lookup:

```bash
awk '/^diff --git /{split($0,p," "); file=p[3]; sub(/^a\//,"",file); next}
     /^@@ -[0-9]+,[0-9]+, [0-9]+,[0-9]+ \+[0-9]+/{split($3,a,"+"); split(a[2],b,","); line=b[1]; next}
     /^\+/{print file ":" line; line++; next}
     /^ /{line++}' /tmp/pr-review-diff.txt
```

This outputs `file:new-file-line` for every added line. Use it to find the correct `line` value for each inline comment. For new files (`--- /dev/null`), every `+` line is a new-file line starting from 1. For modified files, the `@@` hunk header's `+N` tells you the starting line number.

#### 4b. Build the review payload

Create a JSON file with the review body and inline comments. The `body` field is the top-level review summary. Each entry in `comments` becomes its own conversation thread:

```json
{
  "body": "## Code Review — PR #N: <title>\n\n**Verdict: <APPROVE|REQUEST_CHANGES>** (<summary>)\n\n<overall assessment paragraph>",
  "commit_id": "<head-sha>",
  "event": "COMMENT",
  "comments": [
    {
      "path": "relative/path/to/file.ext",
      "line": 42,
      "body": "### <severity emoji> Finding 1 — <Severity> | `file.ext` line 42\n\n**Summary:** <brief description>\n\n**Description:** <longer context if needed, max 10 lines>\n\n**Reason:** <why this is a finding>\n\n**Severity:** <Critical|High|Moderate|Minor|Info>\n\n**Proposed Fix:** <description or code block, max 10 lines>\n\n**AI Prompt:** <prompt for an AI agent to validate and fix>"
    }
  ]
}
```

- `path` — file path relative to the repo root, matching the diff
- `line` — the line number in the **new file** (right side of the diff) where the comment should appear
- `body` — the full finding text (all fields: Summary, Description, Reason, Severity, Proposed Fix, AI Prompt)
- `event` — use `COMMENT` for findings; use `APPROVE` if all findings are Info-only; use `REQUEST_CHANGES` if any Moderate+ findings exist

#### 4c. Post the review

```bash
gh api repos/{owner}/{repo}/pulls/{number}/reviews --input review.json
```

#### 4d. Severity rules for the review event

- If there are any findings of `Moderate` severity or higher, set `event` to `REQUEST_CHANGES`
- If there are only `Info` severity findings, set `event` to `APPROVE`
- If all remaining findings are `Minor` or lower, use your judgement on `APPROVE` vs `REQUEST_CHANGES`
- If GitHub rejects `REQUEST_CHANGES` on your own PR (common), fall back to `COMMENT` and note in the body that changes are requested

#### 4e. Fallback: flat comment

If the review API fails or inline comments are not possible (e.g., findings on files not in the diff, or API permission issues), fall back to a single `gh pr comment` with all findings in one body. Structure each finding as a separate section with an `---` separator so they are visually distinct even without threading.

### 5. Display a summary to the user

- Give a brief summary of the number of items found
- Include a table with the results:

| # | Severity | File | Issue |
|---|----------|------|-------|

Group by severity (Critical -> High -> Moderate -> Minor -> Info)
- Include a final verdict
