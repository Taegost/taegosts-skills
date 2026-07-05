---
name: ts-pr-fix-findings
description: "USE THIS when a PR has review comments (CodeRabbit, Mike, or inline findings). Do NOT manually fix findings — load this skill first. Handles dispositions, verification, thread resolution, and re-review. NOT for code review (use ts-pr-review for that)."
user_invocable: true
---

# PR Fix Findings Skill

Validates a pull request review, fixes any found issues, and updates the PR

## Usage

```bash
/ts-pr-fix-findings <number> [owner/repo]
/ts-pr-fix-findings 13 Taegost/taegosts-skills
/ts-pr-fix-findings 14 cinandriel/taegosts-skills
/ts-pr-fix-findings PR #1
/ts-pr-fix-findings 1
```

The `owner/repo` argument is **recommended**. If omitted, the skill determines the repo using Step 0 below.

## Process

### 0. Determine repository context

Before any work, determine which repository the PR lives in. **Do NOT guess or list repos sequentially.**

1. If the user provided `owner/repo` in the invocation, use it directly.
2. If the current directory is a git repository, try `gh pr view {number}` in CWD.
3. If neither works, check session memory for recent PR/repo context.
4. If still unresolved, **ask the user once** which repo. Do not list repos, do not check forks, do not search.

Store the resolved `owner/repo` for all subsequent `gh` commands using `-R {owner}/{repo}`.

After resolving, persist the owner/repo to session memory so future invocations can use it as a fallback. Use `honcho_conclude` or equivalent.

### 0a. Load the feature plan (if available)

Before reviewing findings, attempt to load the feature plan for this PR's branch. This provides architectural context, KTD specifications, and scope boundaries for cross-referencing findings.

1. Call `/load-plan --non-interactive` (the skill uses the current branch name for discovery)
2. If a plan is found:
   - Extract KTDs by calling `python3 scripts/extract-ktds.py "<plan-path>"`
   - Extract Scope Boundaries from the plan's "Scope Boundaries" section
   - Store both for cross-referencing in Step 3
3. If no plan is found, proceed without plan context (this is not an error)

**Why this matters:** Without the plan, findings are evaluated in isolation. With the plan, we can detect when a reviewer's request contradicts a KTD or asks for something explicitly out of scope.

### 1. Ensure ts-debug skill is available

If the `/ts-debug` skill is not available, stop and alert the user. Do not continue

### 2. Gather the state of the pull request

- Get the latest version of the pull request
- Review all open conversations and change requests for findings
- For each finding, do the following:
  - Check if the finding is already resolved. If it is, then it doesn't require remediation.
  - **Check conversation resolution status.** For each threaded review conversation, check whether it has been resolved using the GraphQL API (gh api graphql with reviewThreads query checking isResolved). Skip any conversation where isResolved is true. Only unresolved conversations require remediation.
  - Validate whether the finding is valid
  - Make note of any instructions or detailed descriptions are given
  - Make note of any comments in the conversation thread. They may provide additional context.
- **Fetch issue-level comments.** Run gh api repos/{owner}/{repo}/issues/{pr_number}/comments to get comments posted directly on the PR (not threaded inline). These may contain corrections, updated assessments, or context that changes the validity of review findings. Check each issue-level comment for references to specific findings and update dispositions accordingly. Compare timestamps against the review submission time to identify comments that came after the review.
- If you are unsure whether a finding is valid, prompt the user, do not make an arbitrary decision
- If you feel a particular finding is larger than a simple bug fix, alert the user and ask them what they would like to do with it. Large remediations may require a separate planning session.
- If there aren't any findings, alert the user and stop. Do not continue.

### 2a. Check for merge conflicts

Before reviewing findings, check whether the PR branch has conflicts with the base branch. If conflicts exist, prompt the user: resolve them as part of this workflow, or skip and resolve separately. Do not proceed to finding review until the user decides.

### 2b. Present finding dispositions to the user

Before planning fixes, list every finding with its proposed action: **fix**, **decline**, or **needs input**. Do not proceed until the user confirms or redirects. Findings where you are unsure of validity must be marked "needs input" — do not decline a finding on your own.

### 2c. Create Kanban board and cards

After the user confirms dispositions, create a Kanban board for tracking:

1. Check if a board named `pr-fix-{pr_number}` already exists (`hermes kanban boards list`). If it exists, reuse it. If not, create it using `hermes kanban boards create`
2. For each finding, create a card with:
   - **Title:** `Finding #{id}: {severity} — {file}`
   - **Body:** Disposition (fix/decline/needs-input), the finding summary, and planned remediation
   - **Status:** `todo`
3. This board serves as persistent working memory across sessions. If a session is interrupted, the next session can read the board to see what's been completed.

### 3. Plan the fix for each finding

- The plan should be documented in `docs/pull_requests/<pr#>_xxx` where `<pr#>` is the number of the pull request and `xxx` is the fix iteration number, incrementing up from 001.
- If your plan to remediate a finding will have an outcome different from what the reviewer requested, that needs to be explicitly noted in the plan.

**Cross-reference against the feature plan (if loaded in Step 0a):**

For each finding, check against the plan's KTDs and Scope Boundaries:
- **KTD conflict:** Does the reviewer's request contradict a KTD specification? If yes, note the divergence in the plan. Example: "Reviewer requests changing regex format, but KTD1 specifies the exact format."
- **Scope boundary violation:** Is the reviewer asking for something explicitly out of scope per the plan? If yes, note it. Example: "Reviewer requests adding feature X, but Scope Boundaries list X as deferred."
- **Unintended side effects:** Does the proposed fix inadvertently break a requirement or violate a KTD? If yes, flag it.

Add a "Plan Divergence" column to the remediation plan noting any conflict between what the reviewer asked for and what the plan specified.

**Group findings for parallel remediation:**

After planning fixes, group the findings for parallel dispatch:

- **File proximity:** Findings targeting the same file go in the same group. Findings targeting files in the same directory are candidates for merging if they share a concern type.
- **Concern type:** Map to `autofix_class` categories — findings with the same `autofix_class` (e.g., both `safe_auto` or both `gated_auto`) and touching related code paths can share a group.
- **Independence:** Each group must be independently fixable — no group depends on another group's fix landing first. If a finding depends on another finding's fix, merge them into the same group.
- Record the group assignments in the remediation plan

### 4. Validate the plan against the findings

- Review each of your proposed remediations in the plan and verify:
  - It will remediate the finding 
  - The remediation resolves it based on the criteria given by the reviewer unless you have explicitly decided otherwise and noted it in the plan
- If your proposed fix will not properly remediate a finding, then repeat the process from step 3 for that finding
  - If you have looped a particular finding 10 times, then skip it with a note that you are having trouble finding a proper remediation for the finding and that the user should review the latest remediation plan

### 5. Remediate valid findings

Launch one ts-debug subagent per group in parallel only when each group has an isolated worktree. If worktree isolation is unavailable, serialize the groups (or create a per-group checkout) before dispatch.

For each group:
1. Move all finding Kanban cards in the group to `running`
2. Launch a ts-debug subagent with:
   - The group's findings and their fix plans
   - The relevant file context (the files being modified)
   - The plan document (if loaded)
   - Any KTD or scope boundary context from Step 3
3. After all subagents complete, consolidate results:
   - Move successfully remediated cards to `done`
   - Move failed cards back to `todo` for re-planning
4. If any subagent fails, diagnose the failure before re-dispatching

### 6. Review your remediations

For each fix you performed, verify it actually landed. Do NOT assume a fix worked just because the edit command succeeded — silent failures are common.

**Semantic verification:**
- Does it match the plan?
- Does it remediate the finding as stated in the review?

**Resolution verification (MANDATORY for each fix with disposition "fix"):**

For each finding that was dispositioned as "fix," verify the fix actually resolves the reviewer's concern — not just that the code changed:

1. **Re-read the reviewer's original concern.** What specific behavior, pattern, or issue did they call out?
2. **Check the code path the reviewer referenced.** Does the fix address the specific code the reviewer pointed at, or did it change something adjacent?
3. **Note whether the concern is resolved.** If the fix changed code but the reviewer's specific concern still applies (e.g., they flagged a missing validation and you added a comment instead), the fix is unresolved.
4. **Treat unresolvable fixes as unresolved — but do not loop.** If a fix cannot resolve the concern (e.g., the reviewer's request conflicts with a KTD or is out of scope), surface it to the user as a known residual and continue to Step 6a. Do not loop back to Step 3 for a fix that cannot succeed.

**Technical verification (MANDATORY for each fix):**
1. **Re-read the file** after editing. Confirm the expected change is present in the actual file content. Python `str.replace()` silently returns the unchanged string when the pattern doesn't match — a non-match looks identical to a successful edit.
2. **Check for control characters.** Run `cat -A <file>` on modified lines. Heredocs interpret escape sequences differently than intended — `\b` becomes a backspace character (`^H`), not a regex word boundary. `\t` and `\r` can also be mangled.
3. **Check file permissions** after any Python file write. Python's `open('w')` strips execute bits. Run `chmod +x <script>` after modifying shell scripts with Python.
4. **Test awk/sed on sample input** before committing. Pipe a representative snippet through the awk/sed command to verify it produces expected output. Escaped characters in heredocs often mangle regex patterns.
5. **Run the test suite** after all fixes. Tests passing is necessary but not sufficient — the fixes could be wrong in ways the tests don't cover.

If any verification step fails, fix the issue before proceeding. Do not commit and hope.

- If semantic, resolution, or technical verification fails for a finding, repeat the process from step 3 for that finding. Note: resolution verification is more stringent than semantic verification — it can fail when the code changed but doesn't address the reviewer's specific concern. If the failure is due to a KTD conflict or scope boundary (unresolvable), do not loop — surface it as a known residual instead.
  - If you have looped a particular finding 10 times, then skip it with a note that you are having trouble finding a proper remediation for the finding and that the user should review the latest remediation plan

### 6a. Holistic verification (conditional — requires plan)

**Gate:** This step only runs if Step 0a successfully loaded a feature plan. If no plan was found, skip directly to Step 7.

After all individual finding remediations pass Step 6 verification, run holistic verification against the full feature plan:

1. Extract the filename from Step 0a's plan path: use `basename <plan-path>` to strip the `docs/plans/` prefix. Then invoke `/ts-verify-implementation <plan-filename>` — pass only the filename (e.g., `2026-07-04-002-feat-pr-fix-findings-verification-loop-plan.md`), not the full path. The skill prepends `docs/plans/` to its argument.
2. If the sub-skill fails to execute (error, timeout, or unavailable), log a warning and continue to Step 7. Do not block the PR update on verification infrastructure failures.
3. If the sub-skill executes but returns a PARTIAL or FAIL verdict, proceed to Step 6b.
4. If the sub-skill returns PASS, proceed to Step 7.

**Why holistic verification matters:** Step 6 verifies each fix individually. This step catches regressions, scope creep, and plan violations that per-finding checks miss — the same 4-dimension model (correctness, completeness, scope, standards) used by `ts-do-work-loop`.

### 6b. Verification failure loop (conditional — runs when 6a returns PARTIAL or FAIL)

When `ts-verify-implementation` reports FAIL or PARTIAL:

1. **Parse the verification summary table.** The output is a consolidated table with columns `# | Severity | File | Issue` — not grouped by dimension. Extract all FAIL/PARTIAL findings from the table.
2. **Create Kanban cards for verification findings.** Use the same format as Step 2c, tagged with `[verification-round-N]` to distinguish from original review findings.
3. **Map to Step 3 format.** For each verification finding, translate it to Step 3's expected input: file path, line reference (if available), the verification concern as the reviewer note, and mark the source as `[verification-round-N]`.
4. **Present dispositions to the user.** List each verification finding with its proposed action: **fix**, **decline**, or **needs input**. Do not proceed until the user confirms. The user may decline a verification finding if they judge it acceptable.
5. **Track iteration count.** Update the `verification-loop-tracker` Kanban card with the current iteration number before each round. Read this card before starting to determine whether the cap has been reached.
6. After user confirmation, re-enter the Step 3 fix-plan flow for confirmed findings.
7. After re-planning and re-fixing, re-run Step 6a.
8. **Cap at 2 iterations.** If verification still fails after 2 cycles, report the remaining findings to the user. Continue to Step 7 without blocking — the user can address remaining findings in a follow-up session. Do not silently loop.

### 7. Update the pull request with your results

- If the reviewer used threaded conversations for the findings, make sure you note each one with their specific notes
- For each finding, make a brief note about what your remediation was for it.
  - If you deemed it to be an invalid finding, then include your reasoning why.
  - If there is additional context required (such as an explanation as to why your remediation doesn't meet the reviewer's criteria), make sure it is added
- If the finding was part of a threaded conversation, mark that conversation as Resolved using the GraphQL API:
    ```bash
    gh api graphql -f query='mutation { resolveReviewThread(input: {threadId: "THREAD_ID"}) { thread { isResolved } } }'
    ```
- If necessary, mark the PR and/or reviewer as ready for review again

### 8. Request re-review

After pushing fixes and resolving threads, request re-review from the original reviewer(s). Do not assume they will notice the push:

```bash
gh api -X PUT repos/{owner}/{repo}/pulls/{pr_number}/requested_reviewers -f reviewers[]='{reviewer}'
```

Or use the simpler fallback:
```bash
gh pr edit {pr_number} --add-reviewer {reviewer}
```

This is easy to forget — if the PR shows "Changes Requested" and you have pushed fixes, the reviewer needs to know to look again.

**Permission fallback:** If the bot account does not have write access to the main repo (external contributor), the review request API will return 404 or permission denied. In that case, post a comment instead:
```bash
gh pr comment {pr_number} --body "All review findings addressed and resolved. Ready for re-review."
```

### 9. Display a summary to the user

- Give a brief summary of each remediation
- Include a table with the results:

| # | Severity | File | Remediation |
|---|----------|------|-------------|

Group by severity (Critical -> High -> Moderate -> Minor -> Info)
- Include a final verdict
