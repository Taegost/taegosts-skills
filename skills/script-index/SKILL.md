---
name: script-index
description: "Index of all available scripts. Load this FIRST when starting any coding task. These scripts exist so you don't have to infer, guess, or use fragile tools."
triggers:
  - "Start a coding task"
  - "Need to check something"
  - "About to commit"
  - "About to push"
  - "Need JSON output"
---

# Script Index

**These scripts exist so you don't have to figure things out. USE THEM.**

Before doing ANY coding work, run:

```bash
SKILL_DIR="$(cd "$(dirname "$(find . -name "script-index" -path "*/skills/*" -type d | head -1)")" && pwd)"
SKILL_BASE="$SKILL_DIR/.."
export PATH="$SKILL_BASE/scripts:$PATH"
for d in "$SKILL_BASE/skills"/*/scripts; do
  [[ -d "$d" ]] && export PATH="$d:$PATH"
done
```

## Situation Routing Table

**Before doing ANYTHING, consult this table.** It tells you which skill to load and which scripts to use.

| Situation | Load this skill | Then use these scripts |
|-----------|----------------|----------------------|
| Starting any coding task | `coding-workflow` | `script-index` (this file) |
| PR has review comments | `pr-fix-findings` | `verify-fix.sh`, `verify-scripts.sh` |
| Need to review a PR | `pr-review` | `detect-diff-scope.sh`, `select-reviewers.sh` |
| Need to create a plan | `ce-plan` | `scan-repo-structure.sh`, `generate-plan-filename.sh` |
| Need to review a plan/doc | `ce-doc-review` | `classify-document.sh`, `solutions-search.sh` |
| Implementing a plan | `do-work-loop` | `git-context.sh`, `verify-scripts.sh` |
| Something is broken | `ce-debug` | `git-context.sh` |
| About to commit | — | `verify-scripts.sh --all` |
| After any file edit | — | `verify-fix.sh` |
| Need JSON output from bash | — | `to-json.sh` |
| After solving a problem | `ce-compound` | `validate-frontmatter.py`, `detect-overlap.py` |
| Need to check conventions | — | `solutions-search.sh` |

**Rules:**
1. Load the skill BEFORE starting work, not after
2. Use scripts INSTEAD of grep/sed/Python heredocs
3. `verify-fix.sh` after EVERY edit
4. `verify-scripts.sh --all` before EVERY commit

## Verification (use EVERY time)

| Script | When to use | Example |
|--------|-------------|---------|
| `verify-fix.sh` | After EVERY file edit | `verify-fix.sh --file foo.sh --should-not-contain '&>2'` |
| `verify-scripts.sh` | Before EVERY commit | `verify-scripts.sh --all` |

## JSON Output (use INSTEAD of printf)

| Script | When to use | Example |
|--------|-------------|---------|
| `to-json.sh` | Any time a bash script needs JSON | `to-json.sh name=test count=5` |

## Git Context (use INSTEAD of manual git commands)

| Script | When to use | Example |
|--------|-------------|---------|
| `git-context.sh` | Need branch/status/diff info | `git-context.sh` → JSON |
| `default-branch.sh` | Need to know the default branch | `default-branch.sh` → "main" |
| `run-id.sh` | Need a unique run identifier | `run-id.sh` → "20260626-143052-a1b2" |

## PR Operations

| Script | When to use | Example |
|--------|-------------|---------|
| `pr-metadata.sh` | Need PR state/info | `pr-metadata.sh --repo owner/repo --pr 11` |
| `fetch-issue-comments.sh` | Need PR issue-level comments | `fetch-issue-comments.sh --repo owner/repo --pr 11` |
| `check-thread-resolution.sh` | Need to check resolved threads | `check-thread-resolution.sh --repo owner/repo --pr 11` |

## Diff and Scope Analysis

| Script | When to use | Example |
|--------|-------------|---------|
| `detect-diff-scope.sh` | What files changed, what reviewers apply | `detect-diff-scope.sh --base main` |
| `select-reviewers.sh` | Which code-review personas apply | `echo "src/auth/login.py" \| select-reviewers.sh` |

## Document Analysis

| Script | When to use | Example |
|--------|-------------|---------|
| `classify-document.sh` | What type is this doc? | `classify-document.sh docs/plans/foo.md` |
| `solutions-search.sh` | Find relevant conventions | `solutions-search.sh valkey networkpolicy` |
| `detect-overlap.py` | Check for existing solutions | `detect-overlap.py --title "Foo" --tags "bar" --solutions-dir docs/solutions/` |
| `validate-findings-json.sh` | Validate findings JSON | `validate-findings-json.sh findings.json` |

## Plan and Implementation

| Script | When to use | Example |
|--------|-------------|---------|
| `generate-plan-filename.sh` | Generate plan filename | `generate-plan-filename.sh --type feat --slug my-feature` |
| `scan-repo-structure.sh` | Detect ecosystem/frameworks | `scan-repo-structure.sh` → JSON |
| `detect-missing-artifacts.sh` | Diff plan files against reference | `detect-missing-artifacts.sh --plan-files list.txt --reference-dir ref/` |
| `find-precommit-hook.sh` | Find validation scripts | `find-precommit-hook.sh` → JSON |
| `detect-file-status.sh` | Is file committed/on-disk/missing? | `detect-file-status.sh path/to/file` |

## Config Review

| Script | When to use | Example |
|--------|-------------|---------|
| `check-credentials-in-configmaps.py` | Scan for secrets in YAML | `check-credentials-in-configmaps.py k8s/` |
| `check-networkpolicy-selectors.sh` | Check NetworkPolicy issues | `check-networkpolicy-selectors.sh k8s/` |
| `validate-frontmatter.py` | Validate solution doc frontmatter | `validate-frontmatter.py docs/solutions/` |

## Rules

1. **NEVER grep/sed/Python str.replace for verification** — use `verify-fix.sh`
2. **NEVER printf for JSON** — use `to-json.sh`
3. **NEVER commit without `verify-scripts.sh --all`**
4. **NEVER manually check git state** — use `git-context.sh`
5. **NEVER guess which reviewers apply** — use `select-reviewers.sh`

