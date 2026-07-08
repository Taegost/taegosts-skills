# Extraction Enumeration — Wave 2 Script Extraction

**Date:** 2026-07-07
**Scope:** Inline bash blocks in 5 target skills for Wave 2 extraction

## Decision Criteria

- **Duplication**: Same/near-duplicate logic in multiple skills → extract
- **Token cost**: Block >15 lines and reused → extract
- **Complexity**: Error-handling/fallback chains hard to read inline → extract
- **Testability**: Extraction enables unit testing → extract
- **Trivial one-liners**: Not duplicated → keep-inline

---

## skills/ts-pr-review/SKILL.md

### Block 1: `inline-gh-pr-view` (Step 4a — Gather review metadata)

**Location:** Lines 80-82
**Content:**
```bash
gh pr view NUMBER --json title,state,headRefOid,comments,reviews
```

**Decision:** **EXTRACT** → `scripts/fetch-pr-data.sh`
**Rationale:**
- Reusable across multiple skills (ts-pr-review, ts-pr-fix-findings)
- Encapsulates `gh pr view` with specific JSON fields
- Enables mocking in tests
- Token cost: low but extraction improves consistency

---

### Block 2: `inline-awk-linemap` (Step 4b — Map and verify line numbers)

**Location:** Lines 92-98
**Content:**
```bash
gh pr diff NUMBER > /tmp/ts-pr-review-diff.txt

awk '/^\+\+\+ /{file=substr($2,3); next}
     /^@@/{match($0, /\+[0-9]+/); line=substr($0, RSTART+1, RLENGTH-1)+0; next}
     /^\+/{print file ":" line; line++; next}
     /^ /{line++}' /tmp/ts-pr-review-diff.txt > /tmp/ts-pr-review-linemap.txt
```

**Decision:** **EXTRACT** → `scripts/map-diff-lines.sh`
**Rationale:**
- Complex awk logic with multiple pattern rules
- Error-prone when executed inline by LLM
- Highly testable with sample diff input
- Reusable for any diff-to-linemap conversion
- Token cost: significant (multi-line awk)

---

### Block 3: `inline-gh-api-review` (Step 4e — Post the review)

**Location:** Lines 152-153
**Content:**
```bash
gh api repos/{owner}/{repo}/pulls/{number}/reviews --input review.json
```

**Decision:** **keep-inline**
**Rationale:**
- Simple API call, single line
- Parameters are skill-specific (owner, repo, number)
- Not duplicated in other skills

---

### Block 4: `inline-gh-pr-comment` (Step 4e — Fallback)

**Location:** Lines 156 (referenced in prose)
**Content:**
```bash
gh pr comment
```

**Decision:** **keep-inline**
**Rationale:**
- Referenced as fallback pattern, not a standalone block
- Simple command, skill-specific context

---

### Block 5: `inline-run-dir-check` (Step 3 — Verify run artifact)

**Location:** Lines 63-64
**Content:**
```bash
RUN_DIR="/tmp/taegosts-skills/ts-code-review/<run-id-from-json>"
test -f "$RUN_DIR/review.json" && echo "GATE PASSED" || echo "GATE FAILED"
```

**Decision:** **keep-inline**
**Rationale:**
- Simple file existence check
- Skill-specific path construction
- Not duplicated elsewhere

---

## skills/ts-pr-fix-findings/SKILL.md

### Block 6: `inline-graphql-resolve` (Step 7 — Resolve thread)

**Location:** Lines 233-234
**Content:**
```bash
gh api graphql -f query='mutation { resolveReviewThread(input: {threadId: "THREAD_ID"}) { thread { isResolved } } }'
```

**Decision:** **keep-inline**
**Rationale:**
- Single GraphQL mutation
- Thread ID is runtime-specific
- Not duplicated in other skills

---

### Block 7: `inline-gh-api-reviewers` (Step 8 — Request re-review)

**Location:** Lines 243-244
**Content:**
```bash
gh api -X PUT repos/{owner}/{repo}/pulls/{pr_number}/requested_reviewers -f reviewers[]='{reviewer}'
```

**Decision:** **keep-inline**
**Rationale:**
- Single API call with skill-specific parameters
- Not duplicated elsewhere

---

### Block 8: `inline-gh-pr-edit-reviewer` (Step 8 — Fallback)

**Location:** Lines 247-248
**Content:**
```bash
gh pr edit {pr_number} --add-reviewer {reviewer}
```

**Decision:** **keep-inline**
**Rationale:**
- Simple fallback command
- Not duplicated

---

### Block 9: `inline-gh-pr-comment-fallback` (Step 8 — Permission fallback)

**Location:** Lines 253-254
**Content:**
```bash
gh pr comment {pr_number} --body "All review findings addressed and resolved. Ready for re-review."
```

**Decision:** **keep-inline**
**Rationale:**
- Simple comment post
- Static message, not duplicated

---

### Block 10: `inline-verification-tracker` (Step 2c — Create tracker)

**Location:** Lines 84-89
**Content:**
```markdown
# PR <pr#> verification tracker
verdict: PENDING
iteration: 0
updated: <ISO 8601 UTC>
```

**Decision:** **keep-inline**
**Rationale:**
- Template content, not executable bash
- Skill-specific structure

---

## skills/ts-commit-push-pr/SKILL.md

### Block 11: `inline-context-fallback` (Context fallback)

**Location:** Lines 40-42
**Content:**
```bash
printf '=== STATUS ===\n'; git status; printf '\n=== DIFF ===\n'; git diff HEAD; printf '\n=== BRANCH ===\n'; git branch --show-current; printf '\n=== LOG ===\n'; git log --oneline -10; printf '\n=== DEFAULT_BRANCH ===\n'; git rev-parse --abbrev-ref origin/HEAD 2>/dev/null || echo 'DEFAULT_BRANCH_UNRESOLVED'; printf '\n=== PR_CHECK ===\n'; gh pr view --json url,title,state 2>/dev/null || echo 'NO_OPEN_PR'
```

**Decision:** **EXTRACT** → `scripts/git-context.sh` (already exists)
**Rationale:**
- Duplicated in ts-commit skill (Block 15)
- Complex multi-command chain
- Already extracted in Wave 1
- Token cost: high

---

### Block 12: `inline-git-add-commit` (Step 3 — Stage and commit)

**Location:** Lines 72-76
**Content:**
```bash
git add file1 file2 file3 && git commit -m "$(cat <<'EOF'
commit message here
EOF
)"
```

**Decision:** **keep-inline**
**Rationale:**
- Template/example pattern, not executable as-is
- File list is dynamic per invocation
- Skill-specific orchestration

---

### Block 13: `inline-git-push` (Step 3 — Push)

**Location:** Line 81
**Content:**
```bash
git push -u origin HEAD
```

**Decision:** **keep-inline**
**Rationale:**
- Single command, trivial
- Not duplicated (used once per workflow)

---

### Block 14: `inline-pr-body-file` (Applying via gh — Write body)

**Location:** Lines 122-125
**Content:**
```bash
BODY_FILE=$(mktemp "${TMPDIR:-/tmp}/ce-pr-body.XXXXXX") && cat > "$BODY_FILE" <<'__CE_PR_BODY_END__'
<the composed body markdown goes here, verbatim>
__CE_PR_BODY_END__
```

**Decision:** **keep-inline**
**Rationale:**
- Template pattern with dynamic content
- Skill-specific body composition
- Not duplicated

---

## skills/ts-verify-implementation/SKILL.md

### Block 15: `inline-determine-base-branch` (Step 1 — Determine base branch)

**Location:** Lines 26-30
**Content:**
```bash
base_branch=$(git remote show origin 2>/dev/null | grep 'HEAD branch' | awk '{print $NF}')
if [ -z "$base_branch" ]; then
  base_branch=$(git branch --list main master develop trunk | head -1 | sed 's/^[* ]*//')
fi
```

**Decision:** **EXTRACT** → `scripts/git-default-branch.sh` (already exists, test in U17)
**Rationale:**
- Duplicated in ts-commit (Block 18) and ts-commit-push-pr (implicit)
- Complex fallback chain
- Already extracted in Wave 1
- Token cost: moderate

---

### Block 16: `inline-extract-ktds` (Step 2 — Extract KTDs)

**Location:** Lines 43-44
**Content:**
```bash
python3 scripts/extract-ktds.py "<plan-path>"
```

**Decision:** **keep-inline**
**Rationale:**
- Single script invocation
- Already extracted (scripts/extract-ktds.py exists)
- Plan path is skill-specific

---

### Block 17: `inline-git-diff` (Step 3 — Get feature branch changes)

**Location:** Line 57
**Content:**
```bash
git diff ${base_branch}...HEAD
```

**Decision:** **keep-inline**
**Rationale:**
- Single command, trivial
- Variable is skill-specific

---

### Block 18: `inline-ktd-verify-literal` (Step 4 — Literal KTD verification)

**Location:** Lines 77-81
**Content:**
```bash
KTD_SPEC_FILE=$(mktemp /tmp/ktd-spec-XXXXXX.txt)
printf '%s\n' '<KTD spec text>' > "$KTD_SPEC_FILE"
python3 scripts/verify-ktd-literal.py --spec-file "$KTD_SPEC_FILE" --file "<target-file>"
rm -f "$KTD_SPEC_FILE"
```

**Decision:** **keep-inline**
**Rationale:**
- Template pattern with dynamic values
- Already uses extracted script (verify-ktd-literal.py)
- Temp file management is skill-specific

---

### Block 19: `inline-coverage-gap` (Step 5 — Run coverage-gap detection)

**Location:** Line 115
**Content:**
```bash
scripts/detect-coverage-gaps.sh "$base_branch"
```

**Decision:** **keep-inline**
**Rationale:**
- Single script invocation
- Already extracted (scripts/detect-coverage-gaps.sh exists)

---

## skills/ts-commit/SKILL.md

### Block 20: `inline-context-fallback-commit` (Context fallback)

**Location:** Lines 37-39
**Content:**
```bash
printf '=== STATUS ===\n'; git status; printf '\n=== DIFF ===\n'; git diff HEAD; printf '\n=== BRANCH ===\n'; git branch --show-current; printf '\n=== LOG ===\n'; git log --oneline -10; printf '\n=== DEFAULT_BRANCH ===\n'; git rev-parse --abbrev-ref origin/HEAD 2>/dev/null || echo '__DEFAULT_BRANCH_UNRESOLVED__'
```

**Decision:** **EXTRACT** → `scripts/git-context.sh` (already exists)
**Rationale:**
- Duplicated in ts-commit-push-pr (Block 11)
- Complex multi-command chain
- Already extracted in Wave 1
- Token cost: high

---

### Block 21: `inline-gh-repo-view` (Step 1 — Resolve default branch)

**Location:** Lines 51-52
**Content:**
```bash
gh repo view --json defaultBranchRef --jq '.defaultBranchRef.name'
```

**Decision:** **EXTRACT** → `scripts/git-default-branch.sh` (already exists, test in U17)
**Rationale:**
- Part of default branch resolution chain
- Duplicated in ts-verify-implementation (Block 15)
- Already extracted in Wave 1

---

### Block 22: `inline-git-add-commit-commit` (Step 4 — Stage and commit)

**Location:** Lines 94-101
**Content:**
```bash
git add file1 file2 file3 && git commit -m "$(cat <<'EOF'
type(scope): subject line here

Optional body explaining why this change was made,
not just what changed.
EOF
)"
```

**Decision:** **keep-inline**
**Rationale:**
- Template/example pattern
- File list and message are dynamic
- Skill-specific orchestration

---

## Summary

| # | Skill | Anchor | Decision | Target |
|---|-------|--------|----------|--------|
| 1 | ts-pr-review | inline-gh-pr-view | **EXTRACT** | scripts/fetch-pr-data.sh |
| 2 | ts-pr-review | inline-awk-linemap | **EXTRACT** | scripts/map-diff-lines.sh |
| 3 | ts-pr-review | inline-gh-api-review | keep-inline | — |
| 4 | ts-pr-review | inline-gh-pr-comment | keep-inline | — |
| 5 | ts-pr-review | inline-run-dir-check | keep-inline | — |
| 6 | ts-pr-fix-findings | inline-graphql-resolve | keep-inline | — |
| 7 | ts-pr-fix-findings | inline-gh-api-reviewers | keep-inline | — |
| 8 | ts-pr-fix-findings | inline-gh-pr-edit-reviewer | keep-inline | — |
| 9 | ts-pr-fix-findings | inline-gh-pr-comment-fallback | keep-inline | — |
| 10 | ts-pr-fix-findings | inline-verification-tracker | keep-inline | — |
| 11 | ts-commit-push-pr | inline-context-fallback | EXTRACT (W1) | scripts/git-context.sh |
| 12 | ts-commit-push-pr | inline-git-add-commit | keep-inline | — |
| 13 | ts-commit-push-pr | inline-git-push | keep-inline | — |
| 14 | ts-commit-push-pr | inline-pr-body-file | keep-inline | — |
| 15 | ts-verify-implementation | inline-determine-base-branch | EXTRACT (W1) | scripts/git-default-branch.sh |
| 16 | ts-verify-implementation | inline-extract-ktds | keep-inline | — |
| 17 | ts-verify-implementation | inline-git-diff | keep-inline | — |
| 18 | ts-verify-implementation | inline-ktd-verify-literal | keep-inline | — |
| 19 | ts-verify-implementation | inline-coverage-gap | keep-inline | — |
| 20 | ts-commit | inline-context-fallback-commit | EXTRACT (W1) | scripts/git-context.sh |
| 21 | ts-commit | inline-gh-repo-view | EXTRACT (W1) | scripts/git-default-branch.sh |
| 22 | ts-commit | inline-git-add-commit-commit | keep-inline | — |

**Extraction decisions:** 7 total (2 new in Wave 2, 5 already extracted in Wave 1)
**Keep-inline decisions:** 15
