---
name: pr-fix-findings
description: "Fix findings from a PR Review"
user_invocable: true
---

# PR Fix Findings Skill

Validates a pull request review, fixes any found issues, and updates the PR

## Usage

```bash
/pr-fix-findings <link to PR>
/pr-fix-findings PR #1
/pr-fix-findings 1
```

If no argument is provided, list open PRs and prompt the user to specify one.

## Process

### 1. Ensure ce-debug skill is available

If the `/ce-debug` skill is not available, stop and alert the user. Do not continue

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

### 3. Plan the fix for each finding

- The plan should be documented in `docs/pull_requests/<pr#>_xxx` where `<pr#>` is the number of the pull request and `xxx` is the fix iteration number, incrementing up from 001.
- If your plan to remediate a finding will have an outcome different from what the reviewer requested, that needs to be explicitly noted in the plan.

### 4. Validate the plan against the findings

- Review each of your proposed remediations in the plan and verify:
  - It will remediate the finding 
  - The remediation resolves it based on the criteria given by the reviewer unless you have explicitly decided otherwise and noted it in the plan
- If your proposed fix will not properly remediate a finding, then repeat the process from step 3 for that finding
  - If you have looped a particular finding 10 times, then skip it with a note that you are having trouble finding a proper remediation for the finding and that the user should review the latest remediation plan

### 5. Remediate valid findings

- Use the `/ce-debug` skill to perform the remediation. Make sure you pass it any necessary context, including the plan document.

### 6. Review your remediations

For each fix you performed, verify it actually landed. Do NOT assume a fix worked just because the edit command succeeded — silent failures are common.

**Semantic verification:**
- Does it match the plan?
- Does it remediate the finding as stated in the review?
  - If your planned remediation didn't match the criteria given by the reviewer, skip this question

**Technical verification (MANDATORY for each fix):**
1. **Re-read the file** after editing. Confirm the expected change is present in the actual file content. Python `str.replace()` silently returns the unchanged string when the pattern doesn't match — a non-match looks identical to a successful edit.
2. **Check for control characters.** Run `cat -A <file>` on modified lines. Heredocs interpret escape sequences differently than intended — `\b` becomes a backspace character (`^H`), not a regex word boundary. `\t` and `\r` can also be mangled.
3. **Check file permissions** after any Python file write. Python's `open('w')` strips execute bits. Run `chmod +x <script>` after modifying shell scripts with Python.
4. **Test awk/sed on sample input** before committing. Pipe a representative snippet through the awk/sed command to verify it produces expected output. Escaped characters in heredocs often mangle regex patterns.
5. **Run the test suite** after all fixes. Tests passing is necessary but not sufficient — the fixes could be wrong in ways the tests don't cover.

If any verification step fails, fix the issue before proceeding. Do not commit and hope.

- If the answer to any of those questions is "no", then repeat the process from step 3 for that finding.
  - If you have looped a particular finding 10 times, then skip it with a note that you are having trouble finding a proper remediation for the finding and that the user should review the latest remediation plan  
  
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
