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

1. **The review MUST come from the `/ts-code-review` skill.** Reading the diff yourself and writing up findings is NOT a review, no matter how thorough it feels. If you have findings but did not invoke `/ts-code-review` in this session, you have skipped the process — stop and go back to step 1.
2. **HARD GATE before posting:** Step 3 consumes findings ONLY from the `ts-code-review` run artifact (`review.json`). If that file does not exist on disk, you cannot proceed to step 3. There is no fallback path that lets you post self-generated findings.
3. **No tool-call budget.** Use as many tool calls as the process requires. The multi-agent review pipeline is expected to make many calls; this is correct behavior, not waste. Never skip, truncate, or substitute a lighter review to save calls. (Avoid *redundant* calls — re-fetching data you already have — but never trade process steps for call count.)

## Process

### 1. Dispatch the review via ts-code-review

Invoke the `ts-code-review` skill in agent mode, passing the PR through:

```
/ts-code-review <PR number or URL> mode:agent
```

Rules for this invocation:

- **Do NOT pass `base:`** alongside the PR target — `ts-code-review` treats that combination as a conflict and will abort.
- **Do NOT check out the PR branch.** `ts-code-review` handles PR scope itself (`pr-remote` / `local-aligned` detection) without mutating the working tree.
- `mode:agent` returns a single JSON object and writes the full run artifact to `/tmp/taegosts-skills/ts-code-review/<run-id>/` — including `review.json`. This artifact is the sole source of findings for step 3.
- Handle the JSON `status` field:
  - `"skipped"` (PR closed/merged/trivial) — relay the reason to the user and stop.
  - `"failed"` or `"degraded"` — relay the reason to the user and stop. Do NOT fall back to reviewing the diff yourself.
  - `"complete"` — continue to step 2.

### 2. Verify the run artifact (HARD GATE)

Before doing anything else, confirm the artifact exists:

```bash
RUN_DIR="/tmp/taegosts-skills/ts-code-review/<run-id-from-json>"
test -f "$RUN_DIR/review.json" && echo "GATE PASSED" || echo "GATE FAILED"
```

- **GATE FAILED:** Stop. Report to the user that `ts-code-review` did not produce its run artifact. Do not post anything to the PR. Do not reconstruct findings from memory or from the JSON response alone if it conflicts with a missing/failed run.
- **GATE PASSED:** Read `review.json`. All findings, severities, file paths, and line numbers for step 3 come from this file — not from your own reading of the diff.

If `review.json` reports zero findings, post a brief approving review (or comment) noting the clean result, then go to step 4.

### 3. Post the review to the pull request

Each finding MUST be a separate inline review comment (conversation thread), not part of one flat comment. Use the GitHub pull request review endpoint to post all findings as a single review with multiple inline comments.

#### 3a. Gather review metadata

Fetch PR metadata in a single call (if not already available from earlier in the session):

**Script resolution.** On Claude Code, `${CLAUDE_SKILL_DIR}` (this skill's directory) and `${CLAUDE_PLUGIN_ROOT}` (the plugin's install directory, for cross-skill scripts) are substituted at skill-load time, so these script paths work regardless of the Bash tool's working directory. On platforms where the variables arrive unsubstituted, resolve the scripts from the loaded skill directory or from a taegosts-skills checkout. If still unresolvable, say so visibly and use the documented manual fallback — never silently skip.

```bash
PR_DATA=$("${CLAUDE_SKILL_DIR}/scripts/fetch-pr-data.sh" "$PR_URL")
```

Parse the result with `jq` to extract individual fields:

```bash
HEAD_SHA=$(echo "$PR_DATA" | jq -r '.headRefOid')
PR_TITLE=$(echo "$PR_DATA" | jq -r '.title')
```

- `headRefOid` is the `commit_id` for the review. Cross-check it against `scope.head_sha` / `scope.pr_url` in `review.json` — if the PR head has moved since the review ran, warn the user and ask whether to re-run rather than posting stale line numbers.
- If you have already reviewed this PR in a prior run, read the responses to your previous comments and use them to inform framing (e.g., note which prior findings were addressed).

#### 3b. Map and verify line numbers

Save the diff once and turn it into the linemap the payload builder partitions on:

```bash
gh pr diff "$PR_URL" | "${CLAUDE_SKILL_DIR}/scripts/map-diff-lines.sh" > /tmp/ts-pr-review-linemap.txt
```

The output is `file:new-file-line` for every added line. `build-review-payload.sh` (3c) reads this linemap to partition findings: a finding whose `file:line` appears in the map posts as an inline comment; findings on unchanged lines, in files outside the diff, or flagged pre-existing route to the fallback flat comment (3e) instead of being dropped.

#### 3c. Build the review payload

Two actions:

1. **Author the assessment.** From `review.json`'s verdict and coverage, write a 2-3 sentence overall assessment to a file. This is the only payload content you author — everything else comes from the script:

   ```bash
   cat > /tmp/ts-pr-review-assessment.md <<'EOF'
   <2-3 sentence assessment of the verdict and finding coverage>
   EOF
   ```

2. **Run the payload builder.** The severity mapping (P0-P3 and advisory-class findings -> Critical/High/Moderate/Minor/Info), the comment-body layout, the inline-vs-fallback partition, and the review event all live in the script:

   ```bash
   OUT_DIR="/tmp/ts-pr-review/<run-id>"
   "${CLAUDE_SKILL_DIR}/scripts/build-review-payload.sh" \
     --review-json "$RUN_DIR/review.json" \
     --linemap /tmp/ts-pr-review-linemap.txt \
     --pr-number <pr-number> --head-sha "$HEAD_SHA" \
     --pr-title "$PR_TITLE" --run-id <run-id> \
     --out-dir "$OUT_DIR" \
     --assessment-file /tmp/ts-pr-review-assessment.md
   ```

   It writes `review-payload.json` (the `gh api` POST body) and `fallback-findings.md` (flat-comment body for findings the linemap can't place, plus residual risks and testing gaps rendered as Info entries) into `$OUT_DIR` — never the working directory — and prints `inline=<n> fallback=<n> event=<EVENT>`.

The review event is deterministic, chosen by the script: any Moderate (P2) or higher finding -> `REQUEST_CHANGES`; only Minor (P3) findings -> `COMMENT` with a body note (deliberate behavior change — P3-only reviews no longer use judgment to escalate); Info-only or zero findings -> `APPROVE`.

**Manual fallback:** if `build-review-payload.sh` fails, you may construct `review-payload.json` yourself per the GitHub pull request reviews API contract (`body`, `commit_id`, `event`, `comments[]` with `path`, `line`, `side: "RIGHT"`, `body`), applying the same severity mapping, event rule, and linemap partition the script encodes, then continue at 3e.

#### 3d. Review event override

The review event is set deterministically by `build-review-payload.sh` (3c) — do not hand-edit it. The one judgment call that remains yours: if GitHub rejects `REQUEST_CHANGES` because the PR is your own (common), change the payload's `event` to `COMMENT`, note in the body that changes are requested, and post per 3e.

#### 3e. Post the review

Post the payload as a single review:

```bash
gh api repos/{owner}/{repo}/pulls/{number}/reviews --input "$OUT_DIR/review-payload.json"
```

Then, only if `$OUT_DIR/fallback-findings.md` is non-empty, post it as a flat conversation comment. `post-pr-comment.sh` has no `--body-file` option — it reads the comment body from stdin when `--body` is omitted:

```bash
test -s "$OUT_DIR/fallback-findings.md" && \
  "${CLAUDE_PLUGIN_ROOT}/skills/ts-pr-fix-findings/scripts/post-pr-comment.sh" \
    --repo {owner}/{repo} --pr {number} < "$OUT_DIR/fallback-findings.md"
```

### 4. Display a summary to the user

- Give a brief summary of the number of items found and the `ts-code-review` verdict
- Include the run artifact path (`/tmp/taegosts-skills/ts-code-review/<run-id>/`) so the full report is auditable
- Include a table with the results:

| # | Severity | File | Issue |
|---|----------|------|-------|

Group by severity (Critical -> High -> Moderate -> Minor -> Info). Reuse the stable `#` values from `review.json` so findings can be cross-referenced between the PR comments, the summary, and the artifact.
- Include a final verdict