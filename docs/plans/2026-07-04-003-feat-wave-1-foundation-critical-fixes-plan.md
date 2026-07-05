---
title: "feat: Wave 1 — Foundation + Critical Fixes"
type: feat
date: 2026-07-04
origin: "https://github.com/taegost/taegosts-skills/issues/93"
status: completed
---

# feat: Wave 1 — Foundation + Critical Fixes

## Summary

Establish foundational documentation standards (link conventions, index standards, script frontmatter), update all relevant existing files to comply, and fix critical bugs in ts-verify-implementation, ts-pr-review, and several scripts. This is the first of three waves; it unblocks Wave 2's script extraction and indexer work.

## Problem Frame

The repository has grown organically — skills, scripts, and documentation lack consistent conventions. Links use mixed formats, indices don't follow a standard structure, and scripts have inconsistent frontmatter. Two active bugs block correct behavior: ts-verify-implementation has its own plan-loading logic instead of using `load-plan`, causing path construction issues, and ts-pr-review omits `side: RIGHT` from inline comment payloads. Several small script quality issues remain from earlier PR reviews.

## Requirements

**Documentation Standards (from #81)**

- R7. All links in the repo use standard markdown link style: `[name](uri)`
- R8. All indices follow a standard structure: YAML frontmatter with `tags`, brief description, table with link and description columns. Only `docs/ROUTING.md` may reference files outside its parent folder.
- R3. All scripts include a standardized frontmatter comment on lines 2-3 (after the shebang) with 1-3 sentences describing when to use the script, in a format consumable by LLMs. Format: `# <name> -- <description>`. No plan-specific prefixes (e.g., `# U19:`) — those are obsolete artifacts from individual plans.

**Bug Fixes**

- R9. ts-verify-implementation uses the `load-plan` skill to locate and load the plan, accepting both full paths and filenames without caring which it receives (#92)
- R10. ts-pr-review payload example includes `side: "RIGHT"` in each comment object (#86)
- R11. Shellcheck runs clean on all test scripts with zero findings, with project configuration documented. Pre-commit hook rejects commits with shellcheck violations. (#72)
- R12. Minor quality defects from PR #20 review are resolved (#64)

## Key Technical Decisions

**KTD-1: Pass full paths; let the callee resolve.** ts-do-work-loop passes the full plan path to ts-verify-implementation. The callee uses the `load-plan` skill to locate and load the plan, so it doesn't need to care whether it receives a full path or a filename. No path manipulation in either skill — `load-plan` handles discovery.

**KTD-2: All relevant files updated to comply.** The R7/R8/R3 standards apply to all relevant files in the repository, not just new/modified ones. R7 (link format) applies to all markdown files. R8 (index structure) applies to all INDEX.md files. R3 (script frontmatter) applies to all `.sh` files in `scripts/` and `skills/*/scripts/`. Existing files are updated to comply as part of this wave.

**KTD-3: R3 frontmatter format.** The standard format is `# <name> -- <description>` (lines 2-3 after shebang, 1-3 sentence description). Existing scripts that use the `# U<id>:` prefix (an artifact from individual plans) will be normalized to drop the prefix. All scripts in `scripts/` and `skills/*/scripts/` will be backfilled or normalized. Test scripts under `tests/` use a different convention (`# Test: <description>`) and are excluded from R3.

**KTD-4: Shellcheck configuration and baseline.** This plan creates `.shellcheckrc`, establishes the baseline on test scripts, and ensures `scripts/run-shellcheck.sh` works with expanded scope (tests/, scripts/, skills/*/scripts/).

**KTD-5: #19 is already resolved.** The stale `.compound-engineering/DESIGN.md` references were cleaned up during the rename in #17. The current `DESIGN.md` references in html-rendering files are functional (graceful fallback). No action needed — the issue should be closed.

**KTD-6: #62 — close if fixed, fix if not.** The regex in `generate-plan-filename.sh` already blocks `/` in the metachar set, and the path traversal check catches `..`. The implementer should verify the current state. If already fixed, close the issue. If not, fix the regex and close.

## Implementation Units

### U1. Link and index standards (R7, R8)

**Goal:** Create the foundational documentation conventions that all indices and links will follow.

**Requirements:** R7, R8

**Dependencies:** None

**Files:**
- `docs/standards/link-convention.md` (new)
- `docs/standards/index-convention.md` (new)
- `scripts/validate-index-standards.py` (new — R7/R8 compliance checker)

**Approach:**
- `link-convention.md`: Document the `[name](uri)` standard. Brief — this is a simple convention.
- `index-convention.md`: Document the R8 standard: each INDEX.md is scoped to its own folder and any indexes one subfolder deep. For example, `docs/INDEX.md` references all files in `docs/` and any indexes in `docs/solutions/` and `docs/standards/`, but NOT in `docs/solutions/conventions/`. YAML frontmatter with `tags: [index]`, brief description, table with at least "Link" and "Description" columns. Only `docs/ROUTING.md` may reference files outside its parent folder.
- Create `scripts/validate-index-standards.py` — a Python script that checks R7/R8 compliance. Must use `pathlib.Path` for all file operations (matching existing patterns in `extract-ktds.py` and `verify-ktd-literal.py`) and output errors as JSON to stderr.
  - R7: verify all markdown links use `[name](uri)` format
  - R8: verify INDEX.md files have YAML frontmatter with `tags`, a description, and a table with Link and Description columns
  - R8: verify each INDEX.md only references files in its own folder and one subfolder deep
  - R8: verify only `docs/ROUTING.md` references files outside its parent folder
  - Output: pass/fail per file with specific violations listed
  - Include a `--help` flag with usage documentation (matching existing script patterns like `verify-fix.sh`)
  - Scope for Wave 1: basic validation. Can be expanded in Wave 2 for more comprehensive checks.

**Patterns to follow:** Existing `docs/standards/agent-standards.md` for document structure. `scripts/extract-ktds.py` and `scripts/verify-ktd-literal.py` for Python validation script patterns. `docs/standards/link-convention.md` and `docs/standards/index-convention.md` (created in this unit) for the new convention documents.

**Test scenarios:**
- Happy path: New convention docs are readable and unambiguous
- Happy path: `scripts/validate-index-standards.py` correctly identifies compliant and non-compliant files
- Edge case: Validation correctly scopes index references to parent folder + one subfolder deep

**Verification:** Both convention docs exist and are referenced from the standards index; `scripts/validate-index-standards.py` runs clean.

### U2. Script frontmatter standard (R3)

**Goal:** Codify the script frontmatter format and backfill/normalize ALL scripts to match.

**Requirements:** R3

**Dependencies:** U1 (standards exist to reference)

**Files:**
- `docs/standards/script-frontmatter-convention.md` (new)
- All `.sh` files in `scripts/` (backfill or normalize)
- All `.sh` files in `skills/*/scripts/` (backfill or normalize)

**Approach:**
- Create `script-frontmatter-convention.md` documenting the format: lines 2-3 after shebang, `# <name> -- <1-3 sentence description of when to use this script>`. Note that test scripts under `tests/` use a different convention (`# Test: <description>`) and are excluded from R3.
- For scripts that already have `# U<id>:` prefixed frontmatter (9 scripts: classify-document.sh, default-branch.sh, git-context.sh, run-id.sh, solutions-search.sh, generate-plan-filename.sh, detect-file-status.sh, find-precommit-hook.sh, detect-missing-artifacts.sh): strip the `# U<id>:` prefix and normalize to `# <name> -- <description>`. The U-number is a plan-specific artifact and does not belong in the standard format.
- For scripts with no frontmatter: add `# <name> -- <description>` on lines 2-3.
- Audit all `.sh` files in `scripts/` and `skills/*/scripts/` — none should be skipped.

**Patterns to follow:** `scripts/git-context.sh`, `scripts/classify-document.sh` for the frontmatter format (after stripping U-prefix).

**Test scenarios:**
- Happy path: Every `.sh` file in `scripts/` and `skills/*/scripts/` has `# <name> -- <description>` on lines 2-3
- Edge case: Frontmatter doesn't interfere with shebang or `set -euo pipefail`
- Edge case: Scripts that already have non-U-prefixed description comments (e.g., `verify-fix.sh`, `to-json.sh`) are normalized to the `# <name> -- <description>` format

**Verification:** Every `.sh` file in `scripts/` and `skills/*/scripts/` has a description comment matching the R3 format on lines 2-3.

### U3. Create scripts/INDEX.md (R8)

**Goal:** Create the script index conforming to R8, listing all scripts in `scripts/`.

**Requirements:** R8

**Dependencies:** U1 (R8 convention exists), U2 (script frontmatter is normalized so descriptions are accurate)

**Files:**
- `scripts/INDEX.md` (new — script index conforming to R8)

**Approach:**
- Create `scripts/INDEX.md` conforming to the R8 standard: YAML frontmatter with `tags: [index, scripts]`, brief description, table listing all scripts in `scripts/` with Link and Description columns.
- Source descriptions from the normalized frontmatter in each script (U2 must be complete first).
- Scope: `scripts/` folder only (no references outside parent folder per R8).

**Patterns to follow:** `docs/standards/index-convention.md` (created in U1) for the R8 format. `docs/standards/INDEX.md` for an existing index example.

**Test scenarios:**
- Happy path: `scripts/INDEX.md` lists all `.sh` files in `scripts/` with accurate descriptions
- Edge case: INDEX.md passes `scripts/validate-index-standards.py` validation
- Edge case: Descriptions match the normalized frontmatter from U2

**Verification:** `scripts/validate-index-standards.py` reports zero errors for `scripts/INDEX.md`.

### U4. Update all existing files to R7/R8 compliance

**Goal:** Bring all existing markdown files and indices into compliance with the R7 (link format) and R8 (index structure) standards.

**Requirements:** R7, R8

**Dependencies:** U1 (conventions defined), U3 (scripts/INDEX.md created)

**Files:**
- All `*.md` files in the repository (audit and fix)
- All existing `INDEX.md` files (update to R8 format)

**Approach:**
- Audit all markdown files for link format compliance (R7): convert any non-standard links to `[name](uri)` format.
- Audit all existing `INDEX.md` files for R8 compliance: add YAML frontmatter with `tags`, description, and table with Link/Description columns.
- Ensure each INDEX.md is scoped to its own folder + one subfolder deep per the R8 convention.
- Run `scripts/validate-index-standards.py` after updates to confirm compliance.

**Patterns to follow:** `docs/standards/link-convention.md` and `docs/standards/index-convention.md` (created in U1).

**Test scenarios:**
- Happy path: All markdown files pass R7 link validation
- Happy path: All INDEX.md files pass R8 validation
- Edge case: No INDEX.md references files beyond one subfolder deep

**Verification:** `scripts/validate-index-standards.py --all` reports zero errors.

### U5. Fix ts-do-work-loop double-prefix (#92)

**Goal:** ts-verify-implementation uses `load-plan` to locate and load the plan, eliminating the double-prefix bug and any plan-loading logic from the verify skill.

**Requirements:** R9

**Dependencies:** None

**Files:**
- `skills/ts-verify-implementation/SKILL.md` (remove plan-loading logic, add `load-plan` invocation)

**Approach:**
- Remove the hardcoded `docs/plans/$ARGUMENTS` path construction from `ts-verify-implementation` Step 2. Replace with: invoke `/load-plan plan:$ARGUMENTS` at the start of the verify workflow. `load-plan` resolves the plan path (explicit path takes priority, then PR body, then branch name extraction).
- Also update the `extract-ktds.py` call (currently line 40: `python3 scripts/extract-ktds.py "docs/plans/$ARGUMENTS"`) to use the path returned by `load-plan` instead of constructing it inline.
- ts-do-work-loop passes the full plan path as-is — no path manipulation needed.
- The key contract: `load-plan` handles all path resolution. Neither `ts-do-work-loop` nor `ts-verify-implementation` construct paths.

**Patterns to follow:** `skills/ts-pr-fix-findings/SKILL.md` which already uses `load-plan` for plan discovery.

**Test scenarios:**
- Happy path: Given a full path like `docs/plans/2026-07-04-001-feat-foo-plan.md`, `load-plan` resolves and loads it
- Happy path: Given a bare filename, `load-plan` resolves and loads it
- Edge case: No double-prefix — `load-plan` handles path resolution, not the verify skill

**Verification:** `ts-verify-implementation` SKILL.md contains no plan path construction logic. `load-plan` is invoked for plan discovery.

### U6. Fix ts-pr-review payload (#86)

**Goal:** ts-pr-review payload example includes `side: "RIGHT"` so inline comments on added lines succeed.

**Requirements:** R10

**Dependencies:** None

**Files:**
- `skills/ts-pr-review/SKILL.md` (review payload example, ~lines 86-99)

**Approach:**
- Add `"side": "RIGHT"` to each comment object in the JSON payload example.
- Add a note in the surrounding documentation explaining that `side: "RIGHT"` is required for inline comments on pull request diffs (the GitHub Reviews API requires it to disambiguate which side of a diff the comment applies to). Omit it only for context lines (unchanged lines within a hunk).

**Patterns to follow:** Existing payload structure in the same file.

**Test scenarios:**
- Happy path: Payload example is valid JSON with `side` field present
- Edge case: Note clarifies when `side` is vs isn't required

**Verification:** The payload example includes `side: "RIGHT"` and the surrounding documentation explains its purpose.

### U7. Shellcheck integration (#72)

**Goal:** Shellcheck configuration exists, runs clean on all test scripts, and is documented.

**Requirements:** R11

**Dependencies:** None

**Files:**
- `.shellcheckrc` (new)
- `scripts/run-shellcheck.sh` (may need updates)
- Test scripts under `tests/**/*.sh` (fix any findings)

**Approach:**
- Create `.shellcheckrc` with project settings: shell dialect (bash), disabled checks (document rationale for each disable inline). Add a 'Shellcheck Configuration' subsection to `docs/solutions/script-security-standards.md` cross-referencing the `.shellcheckrc` settings.
- Run shellcheck against all test scripts and fix findings. This establishes the baseline.
- Ensure `scripts/run-shellcheck.sh` works with the new `.shellcheckrc`. Expand its search scope from `tests/` only to also include `scripts/` and `skills/*/scripts/` directories (currently line 38 only scans `tests/`).

**Patterns to follow:** `docs/solutions/script-security-standards.md` for security conventions.

**Test scenarios:**
- Happy path: `shellcheck tests/**/*.sh` exits 0 with no findings
- Edge case: `.shellcheckrc` disables are documented and justified
- Error path: `scripts/run-shellcheck.sh` reports clear pass/fail output

**Verification:** `scripts/run-shellcheck.sh` exits 0. `.shellcheckrc` exists with documented settings.

### U8. Minor quality fixes (#64)

**Goal:** Resolve the 3 minor findings from PR #20 CodeRabbit review.

**Requirements:** R12

**Dependencies:** None

**Files:**
- `skills/ts-verify-implementation/scripts/detect-file-status.sh` (verify already fixed per #64)
- `scripts/run-shellcheck.sh` (fix `set -uo pipefail` → `set -euo pipefail`)
- `scripts/git-context.sh` (fix `set -uo pipefail` → `set -euo pipefail`)
- `scripts/classify-document.sh` (fix `set -uo pipefail` → `set -euo pipefail`)
- `scripts/solutions-search.sh` (fix `set -uo pipefail` → `set -euo pipefail`)
- `skills/ts-work/scripts/detect-missing-artifacts.sh` (add error handling for edge cases)
- `skills/ts-work/references/review-findings-followup.md` (add `bash` language specifier to fenced code block)

**Approach:**
- Fix #1: Confirm `detect-file-status.sh` already uses `set -euo pipefail` (per issue #64; verify current state). Also fix `set -uo pipefail` → `set -euo pipefail` in 4 scripts that violate the security standard: `run-shellcheck.sh`, `git-context.sh`, `classify-document.sh`, `solutions-search.sh`.
- Fix #2: Add error handling in `detect-missing-artifacts.sh` for the identified edge cases.
- Fix #3: Add `bash` language specifier to the fenced code block in `review-findings-followup.md`.

**Test scenarios:**
- Happy path: All fixes are mechanical and don't change behavior
- Edge case: detect-diff-scope.sh already uses `set -euo pipefail` — confirm `-e` (errexit: exit immediately if any command returns non-zero) is present and no commands intentionally return non-zero without explicit `|| true` guards

**Verification:** All three files have the fixes applied. Tests pass.

### U9. Verify and close stale issues (#19, #62)

**Goal:** Confirm whether #19 and #62 are already resolved; close if so.

**Requirements:** None

**Dependencies:** None

**Files:**
- `skills/ts-brainstorm/references/html-rendering.md` (verify)
- `skills/ts-plan/references/html-rendering.md` (verify)
- `skills/ts-plan/scripts/generate-plan-filename.sh` (verify)

**Approach:**
- #19: Research confirms the stale `.compound-engineering/DESIGN.md` references were cleaned up in #17. Current references are to `.taegosts-skills/DESIGN.md` which is a functional fallback. Verify no residual stale references remain and close. Note: `grep -r "compound-engineering"` will match ~7 files that use the term as a conceptual reference (e.g., in docs/solutions/). The verification should check for stale file-path references (`.compound-engineering/DESIGN.md`) rather than the bare string. Verification command: `grep -r '\.compound-engineering/DESIGN\.md' skills/` — confirm zero matches.
- #62: Research shows the regex already blocks `/` and the traversal check catches `..`. Verify the current state is correct and close. Verification command: run `generate-plan-filename.sh` with test inputs containing `/` and `..` and confirm rejection. If the regex does NOT block them, fix it.

**Verification:** Both issues are confirmed resolved or have minimal remaining work documented.

## Scope Boundaries

**Deferred to Wave 2 (from #81):**
- R4: `index-scripts.py` — indexes all repo-level scripts using frontmatter
- R6: `update-indexes.py` — recursively creates/updates INDEX.md files in `docs/`
- R2: `docs/ROUTING.md` — Map of Content pointing to other indices
- R5: Update skills to reference the new script-index

**Out of scope:**
- Agent consolidation (#83) — Wave 2
- Script extraction (#82) — Wave 2

## Risks & Dependencies

- **Shellcheck findings volume:** Running shellcheck on all test scripts may surface more than trivial fixes. Mitigation: scope is test scripts only; fix findings unit-by-unit.
- **#81 Wave 2 dependency:** R4/R6/R2/R5 cannot start until R7/R8/R3 from this plan land. The plan for #81 should note this split explicitly.

## Wave 2 Prerequisites

Before Wave 2 can start, verify:
- `scripts/validate-index-standards.py --all` reports zero errors
- `docs/standards/INDEX.md` lists all convention docs and conforms to R8
- `scripts/INDEX.md` exists and passes R8 validation
- All `.sh` files in `scripts/` and `skills/*/scripts/` have R3 frontmatter
- `.shellcheckrc` exists and `scripts/run-shellcheck.sh` exits 0
- ts-verify-implementation uses `load-plan` (no hardcoded path construction)
- ts-pr-review payload includes `side: "RIGHT"`

## System-Wide Impact

- R7/R8 conventions established and all relevant existing files updated to comply
- R3 convention established and all existing scripts normalized to comply
- Shellcheck baseline prevents regression of shell safety defects
- ts-verify-implementation uses `load-plan` for plan discovery (no duplicate path logic)
- ts-pr-review payload includes `side: "RIGHT"` for correct inline comments
