---
title: "feat: Wave 2 — Script Extraction + Index Infrastructure + Dispatch Unification"
type: feat
date: 2026-07-05
origin: "https://github.com/taegost/taegosts-skills/issues/94"
---

# feat: Wave 2 — Script Extraction + Index Infrastructure + Dispatch Unification

## Summary

Extract inline scripts from six skills into reusable script files, build automated index infrastructure (index-scripts.py, update-indexes.py, ROUTING.md), unify the dispatch pattern to Bootstrap across all skills, and harden five scripts with specific bug fixes. Builds on Wave 1's R3 frontmatter, R7 link conventions, and R8 index standards.

The index infrastructure replaces the manual `script-index` skill with automated indexers that scan `scripts/` and `skills/*/scripts/` directories, generate R8-compliant `INDEX.md` files at each level, and maintain `ROUTING.md` as the repo's Map of Content. A pre-commit hook ensures indexes stay current without manual intervention.

**Wave 1 status (PR #99, merged 2026-07-05):** All R3/R7/R8 standards are landed. Script fixes for #63, #47, and #44 are already applied. Shellcheck integration is complete. The testing-standards.md and auto-dispatch mechanism are in place.

**Wave 1.5 status (PR #104, merged 2026-07-06):** Bootstrap dispatch is now the only allowed pattern. Template-wrapped is fully deprecated (not a fallback). Direct-seed is deprecated and only allowed in narrow circumstances with explicit owner approval. ts-work, ts-plan, and ts-doc-review are already migrated to Bootstrap. Testing standards with auto-dispatch and coverage-gap detection are established. Notification resilience via disk-first state is documented.

The index infrastructure replaces the manual `script-index` skill with automated indexers that scan `scripts/` and `skills/*/scripts/` directories (both `.sh` and `.py` files), generate R8-compliant `INDEX.md` files at each level, and maintain `ROUTING.md` as the repo's Map of Content. A pre-commit hook ensures indexes stay current without manual intervention.

## Problem Frame

Skills contain inline shell commands and mechanical steps that the LLM executes token-by-token. These steps are duplicated across skills (default branch resolution appears in three skills, context gathering in two), error-prone when executed inline (complex awk scripts, GraphQL mutations), and expensive in tokens. Wave 1 established the frontmatter and standards foundation; Wave 2 extracts, indexes, and hardens.

Bootstrap is the only allowed dispatch pattern. Template-wrapped and direct-seed are fully deprecated. All skills that call subagents must be migrated to Bootstrap dispatch as part of this PR. Bootstrap centralizes file-path-based dispatch with bootstrap-ack verification, reducing token cost by ~97% per reviewer invocation.

## Requirements

**Index Infrastructure (from #81)**

- R1. `scripts/index-scripts.py` indexes all repo-level scripts using R3 frontmatter, producing `scripts/INDEX.md`
- R2. `docs/ROUTING.md` is a Map of Content pointing to other indices and important information
- R3. `scripts/update-indexes.py` recursively creates/updates INDEX.md files in `docs/` and `skills/*/scripts/`, calls index-scripts.py, and ensures ROUTING.md has entries for all sub-indices. Runs as a pre-commit hook to keep indexes current automatically.
- R4. Update skills that reference inline script locations to reference the new script-index

**Script Extraction (from #82)**

- R5. Extract inline scripts from ts-commit, ts-commit-push-pr, ts-pr-review, ts-verify-implementation, ts-pr-fix-findings, and ts-work into reusable script files under `scripts/` or `skills/<name>/scripts/`
- R6. Each extracted script follows existing conventions: R3 frontmatter (line 2: `# <name> -- <description>`), `--help` flag, JSON output, exit codes (0/1/2), input validation, `set -euo pipefail`, ShellCheck-clean. Each script must have a corresponding test in `tests/scripts/` per `docs/standards/testing-standards.md`.

**Script Fixes (from #63, #60, #61, #47, #44)**

- R7. `check-thread-resolution.sh` and `fetch-issue-comments.sh` validate input formats (owner/repo shape, digits-only PR number), not just shell metacharacters (#63)
- R8. `select-reviewers.sh` uses independent predicate checks instead of case-block-first-match, so a single file can activate multiple reviewer personas (#60)
- R9. `detect-overlap.py` title scorer uses only substring/word-overlap logic, removing SequenceMatcher contribution (#61)
- R10. `find-precommit-hook.sh` outputs the full resolved hook path in scripts[0], not just the basename (#47)
- R11. `detect-missing-artifacts.sh` guards against missing option values before reading `$2`, failing gracefully with JSON error (#44)

**Dispatch Unification**

- R12. All skills use Bootstrap dispatch (file-path-based, bootstrap-ack verification). Template-wrapped is fully deprecated and must be removed from all skills. Direct-seed is deprecated and only allowed in narrow circumstances with explicit owner approval. All skills that call subagents must be migrated to Bootstrap as part of this PR.
- R13. `docs/standards/agent-standards.md` documents Bootstrap as the only allowed dispatch pattern per PR #104. The standards documentation must explicitly state that template-wrapped is deprecated (not a fallback) and direct-seed requires explicit approval. Skills not yet migrated (ts-compound, ts-code-review, ts-verify-implementation) must be migrated to Bootstrap.
- R14. `scripts/update-indexes.py` runs as a pre-commit hook so all INDEX.md files and ROUTING.md are updated automatically before every commit

**CLAUDE.md (from #81)**

- R15. Create a `CLAUDE.md` at the repo root containing: a concise repository summary written for AI consumption, a pointer to `docs/ROUTING.md`, and any rules or standards that all agents running in this repository must follow. CLAUDE.md is NOT an index file.

**Reporting Logic Fix (from #101)**

- R16. `ts-pr-review` line number verification must use `gh pr diff` output (GitHub's 3-line context hunks) instead of local `git diff -U10` for the linemap, so inline comment line numbers match what the Reviews API accepts

## Key Technical Decisions

**KTD-1. Agent consolidation (#83) is out of scope.** The nine cross-skill agent duplicates require their own dedicated plan due to the cross-cutting nature of the changes. Wave 2 focuses on script work and dispatch unification only.

**KTD-2. Bootstrap is the only allowed dispatch pattern (per PR #104).** Orchestrators pass file paths instead of inline content; subagents read their own contract/role/schema from disk. Bootstrap-ack is mandatory: agent emits file paths + line counts; orchestrator verifies. Template-wrapped is fully deprecated — not a fallback. Direct-seed is deprecated and only allowed in narrow circumstances with explicit owner approval. ts-work, ts-plan, and ts-doc-review are already migrated. All remaining skills (ts-compound, ts-code-review, ts-verify-implementation) must be migrated to Bootstrap as part of this PR. See `docs/solutions/conventions/subagent-bootstrap-dispatch.md` for the full pattern.

**KTD-3. Script extraction scope — decision surface, not line count.** The boundary isn't length, it's whether a step has a single canonical textual form or a parameter surface a model can get wrong.

Stays inline: steps with one correct invocation and no context-dependent parameters — overlearned idiom with no plausible near-miss (`git add .`, `git push`).

Extraction candidate regardless of brevity: any step where correctness depends on matching specific field names, indices, schema shapes, or multi-step logic — i.e., more than one syntactically plausible form exists and only one is right.

Prioritize extraction candidates by duplication × decision-surface × blast-radius-of-being-wrong:
- (a) steps duplicated across skills — prose copies of the "same" step diverge under independent edits even with no model involvement
- (b) complex mechanical steps (awk/jq with positional or schema-specific logic, GraphQL mutations) — high decision-surface, the core confabulation risk
- (c) steps with known bugs — the fix's exact text must be pinned; re-derivation risks reproducing or replacing the bug

Frequency of reuse affects extraction cost-effectiveness (bootstrap/dispatch overhead vs. inline tokens), not whether a step qualifies — a single-use step can still warrant extraction if being wrong is expensive to detect or fix downstream.

**KTD-4. New shared scripts go in `scripts/`; skill-specific scripts stay in `skills/<name>/scripts/`.** Shared utilities (default-branch.sh, git-context.sh) serve multiple skills from `scripts/`. Skill-specific scripts (resolve-thread.sh, map-diff-lines.sh) live under the skill's own `scripts/` directory. This matches the existing two-tier structure.

**KTD-5. Python scripts for indexer infrastructure.** `index-scripts.py` and `update-indexes.py` are Python (matching `extract-ktds.py` and `verify-ktd-literal.py` patterns): `#!/usr/bin/env python3`, `pathlib.Path`, `json.dumps()` output, `main()` with `if __name__ == '__main__'` guard, stdlib only.

**KTD-6. Script extraction preserves existing behavior.** Extracted scripts produce the same output format and exit codes as the inline logic they replace. Skills are updated to call the extracted scripts, but their orchestration logic (what to do with the output) stays in the SKILL.md.

**KTD-7. Bootstrap agent definitions follow agent-standards.md.** Each agent file requires YAML frontmatter with 4 required fields: `name`, `description`, `tools`, `effort`. Identity text (1-2 paragraphs) follows frontmatter. Implementer agents use the implementer heading sub-template (scope boundary, fidelity, done criteria, non-goals, failure handling). Reviewer agents use the reviewer heading sub-template. See `docs/standards/agent-standards.md` for the full schema.

## High-Level Technical Design

The plan has five phases with three parallel work streams. Phase 1 (Foundation) and Phase 2 (Index Infrastructure) have no inter-track dependencies and can proceed in parallel. Phase 3 (Script Extraction) benefits from Phase 2 landing first (so the script index can be updated), but individual extraction units are independent of each other. Phase 4 (Dispatch Unification) depends only on U1 (standards update). Wave 1 (PR #99) and Wave 1.5 (PR #104) have already landed, establishing R3/R7/R8 standards, Bootstrap dispatch as primary, testing-standards.md, and notification resilience.

```mermaid
flowchart TB
    subgraph Phase1["Phase 1: Foundation"]
        U1["U1: Update dispatch standards"]
        U2["U2: Fix input validation #63"]
        U3["U3: Fix multi-persona #60"]
        U4["U4: Fix title scorer #61"]
        U5["U5: Fix hook path #47"]
        U6["U6: Guard missing options #44"]
    end

    subgraph Phase2["Phase 2: Index Infrastructure"]
        U7["U7: index-scripts.py"]
        U8["U8: ROUTING.md"]
        U9["U9: update-indexes.py"]
        U10["U10: Deprecate script-index skill"]
    end

    subgraph Phase3["Phase 3: Script Extraction + Fixes"]
        U11["U11: Standards + script enumeration"]
        U12["U12: Shared scripts"]
        U13["U13: ts-pr-review scripts"]
        U14["U14: ts-pr-fix-findings scripts"]
        U15["U15: ts-commit context"]
        U16["U16: ts-work scripts"]
        U17["U17: CLAUDE.md #81"]
        U18["U18: Fix line verification #101"]
    end

    subgraph Phase4["Phase 4: Dispatch Unification"]
        U19["U19: Verify ts-work Bootstrap"]
        U20["U20: Migrate ts-compound to Bootstrap"]
    end

    subgraph Phase5["Phase 5: Finalization"]
        U21["U21: Update all indices"]
    end

    U7 --> U8
    U7 --> U9
    U7 --> U10
    U1 --> U19
    U1 --> U20
    U8 --> U17
    U1 --> U11
    U11 --> U15
    U11 --> U16
    U12 --> U15
    U12 --> U16
    U7 --> U21
    U9 --> U21
    U19 --> U21
    U20 --> U21
```

## Implementation Units

### Phase 1: Foundation (independent, can start immediately)

### U1. Update dispatch standards to reflect Bootstrap as primary

**Goal:** Update `docs/standards/agent-standards.md` to document Bootstrap as the only allowed dispatch pattern. Template-wrapped is fully deprecated (not a fallback). Direct-seed is deprecated and only allowed in narrow circumstances with explicit owner approval.

**Requirements:** R13

**Dependencies:** None

**Files:**
- `docs/standards/agent-standards.md` (update Dispatch Patterns section)

**Approach:**
- PR #104 already updated agent-standards.md with Bootstrap as primary. Verify the current state is correct and complete.
- Document Bootstrap as the only allowed dispatch pattern. State explicitly that template-wrapped is deprecated (not a fallback) and direct-seed is deprecated (only with explicit owner approval).
- Document Bootstrap-ack requirement: agent emits file paths + line counts; orchestrator verifies before accepting findings
- Add migration guidance: how to convert a skill from template-wrapped or direct-seed to Bootstrap
- Reference `docs/solutions/conventions/subagent-bootstrap-dispatch.md` for the full Bootstrap pattern
- Enumerate all skills still on template-wrapped or direct-seed and add migration tasks to this plan

**Patterns to follow:** `docs/solutions/conventions/subagent-bootstrap-dispatch.md` for Bootstrap dispatch. `skills/ts-work/SKILL.md` and `skills/ts-plan/SKILL.md` for already-migrated skills.

**Test scenarios:**
- Happy path: The dispatch patterns section documents Bootstrap as the only allowed pattern
- Happy path: Template-wrapped is explicitly marked as deprecated (not a fallback)
- Happy path: Direct-seed deprecation note is clear and specifies owner approval requirement
- Edge case: Migration guidance is specific enough for an implementer to convert a skill to Bootstrap

**Verification:** `docs/standards/agent-standards.md` documents Bootstrap as the only allowed dispatch pattern, with template-wrapped and direct-seed explicitly deprecated.

---

### U2. Fix pr-fix-findings input validation (#63)

**Goal:** `check-thread-resolution.sh` and `fetch-issue-comments.sh` validate input formats (owner/repo shape, digits-only PR number), not just shell metacharacters.

**Requirements:** R7

**Dependencies:** None

**Files:**
- `skills/ts-pr-fix-findings/scripts/check-thread-resolution.sh` (update validation)
- `skills/ts-pr-fix-findings/scripts/fetch-issue-comments.sh` (update validation)
- `tests/skills/ts-pr-fix-findings/test-check-thread-resolution.sh` (add test cases)
- `tests/skills/ts-pr-fix-findings/test-fetch-issue-comments.sh` (add test cases)

**Approach:**
- **Wave 1 (PR #99) already applied the fix.** Both scripts have `^[a-zA-Z0-9._-]+/[a-zA-Z0-9._-]+$` for repo and `^[0-9]+$` for PR number checks after the metacharacter gate.
- Verify the current implementation is correct and add test cases for edge cases (path traversal, extra slashes, non-numeric PR)
- Ensure test file exists per `docs/standards/testing-standards.md`

**Patterns to follow:** The existing error handling pattern in both scripts (JSON error on stderr, exit 1).

**Test scenarios:**
- Happy path: Valid `owner/repo` and numeric PR pass validation
- Edge case: `1/../../orgs/other/...` is rejected by the format validator
- Edge case: `owner/repo/extra/slashes` is rejected
- Edge case: PR number with letters is rejected
- Error path: Validation failure produces JSON error on stderr with exit 1

**Verification:** Both scripts reject non-conforming inputs with structured JSON errors. Test cases pass.

---

### U3. Fix select-reviewers.sh multi-persona matching (#60)

**Goal:** Replace case-block-first-match with independent predicate checks so a single file can activate multiple reviewer personas.

**Requirements:** R8

**Dependencies:** None

**Files:**
- `skills/ts-code-review/scripts/select-reviewers.sh` (rewrite matching logic)
- `tests/skills/ts-code-review/test-select-reviewers.sh` (update/add test cases)

**Approach:**
- Replace the `case` block (around line 50) with independent `if` predicates for each conditional persona
- Each predicate is evaluated independently — no early exit after first match
- Suppress predicates already covered by `always_on` (e.g., if `testing` is always_on, skip the conditional `testing` predicate)
- Build the conditional array by appending matches, then deduplicate before JSON output
- Preserve the existing JSON output structure: `{always_on: [], conditional: [], rationale: {}}`

**Patterns to follow:** The existing output format in the same script. The `always_on` array is populated first, then conditional predicates run independently.

**Test scenarios:**
- Happy path: `api/auth/login_controller_test.rb` activates security, api-contract, and testing (not just security)
- Happy path: A pure backend file activates only backend-related personas
- Edge case: A file matching no conditional predicates produces empty conditional array
- Edge case: A persona already in `always_on` does not appear in `conditional`

**Verification:** A mixed-surface path like `api/auth/login_controller_test.rb` activates all applicable reviewer personas, not just the first match.

---

### U4. Fix detect-overlap.py title scorer (#61)

**Goal:** Remove SequenceMatcher contribution from `title_similarity()`, using only substring/word-overlap logic.

**Requirements:** R9

**Dependencies:** None

**Files:**
- `skills/ts-compound/scripts/detect-overlap.py` (update `title_similarity` function)
- `tests/skills/ts-compound/test-detect-overlap.py` (update test cases)

**Approach:**
- In `title_similarity()` (around line 87), remove the `SequenceMatcher` ratio contribution
- Keep only the substring/word-overlap based scoring that matches the documented contract
- Verify the composite scoring formula (0.6 * title_sim + 0.4 * tag_overlap) still produces expected results with the simplified scorer
- Update any test cases that relied on SequenceMatcher-specific scores

**Patterns to follow:** The documented scoring algorithm in the existing script's docstring and the script extraction plan (U15).

**Test scenarios:**
- Happy path: Identical titles produce score 1.0
- Happy path: Completely different titles produce score near 0
- Edge case: Substring matches (e.g., "Deployment" in "Deployment Patterns") are detected
- Edge case: Word-overlap catches reordered titles ("Fix Bug A" vs "A Bug Fix")

**Verification:** `title_similarity()` uses only overlap-based logic. Composite scores match documented formula.

---

### U5. Fix find-precommit-hook.sh scripts[0] path (#47)

**Goal:** Output the full resolved hook path in scripts[0], not just the basename.

**Requirements:** R10

**Dependencies:** None

**Files:**
- `skills/ts-work/scripts/find-precommit-hook.sh` (fix line ~58)
- `tests/skills/ts-work/test-find-precommit-hook.sh` (add assertion)

**Approach:**
- **Wave 1 (PR #99) already applied the fix.** Line 58 reads `scripts=("$hook_path")` (full path, not basename).
- Verify the current implementation is correct and add a test assertion confirming scripts[0] is a valid/resolvable path
- Ensure test file exists per `docs/standards/testing-standards.md`

**Patterns to follow:** The existing JSON output construction in the same script.

**Test scenarios:**
- Happy path: scripts[0] in JSON output is a resolvable file path
- Edge case: When hook is found via `.githooks/`, the full path is returned
- Error path: When no hook is found, scripts array is empty (existing behavior preserved)

**Verification:** scripts[0] in the JSON output is a resolvable file path to the pre-commit hook.

---

### U6. Guard detect-missing-artifacts.sh missing options (#44)

**Goal:** Guard against missing option values before reading `$2`, failing gracefully with JSON error.

**Requirements:** R11

**Dependencies:** None

**Files:**
- `skills/ts-work/scripts/detect-missing-artifacts.sh` (update option parsing)
- `tests/skills/ts-work/test-detect-missing-artifacts.sh` (add regression test)

**Approach:**
- **Wave 1 (PR #99) already applied the fix.** Lines 37 and 42 have `[[ $# -ge 2 ]]` guards with JSON error output. Also added python3 availability check.
- Verify the current implementation is correct and add a regression test case for `--plan-files` / `--reference-dir` with no value
- Ensure test file exists per `docs/standards/testing-standards.md`

**Patterns to follow:** The existing JSON error pattern in the same script and other scripts in the repo.

**Test scenarios:**
- Happy path: `--plan-files <file>` works correctly when value is present
- Edge case: `--plan-files` (no value) exits 1 with JSON error, not bash unbound variable error
- Edge case: `--reference-dir` (no value) exits 1 with JSON error
- Error path: Missing value error is structured JSON, not raw bash output

**Verification:** Running `detect-missing-artifacts.sh --plan-files` (no value) exits 1 and prints a JSON error message.

---

### Phase 2: Index Infrastructure (depends on Wave 1 R3/R7/R8 landing on main)

### U7. Create index-scripts.py

**Goal:** Automate script indexing using R3 frontmatter, replacing the manual `script-index` skill.

**Requirements:** R1

**Dependencies:** Wave 1 R3 (script frontmatter standardized), Wave 1 R7/R8 (link/index conventions)

**Files:**
- `scripts/index-scripts.py` (new)
- `tests/scripts/test-index-scripts.py` (new)
- `scripts/INDEX.md` (generated output)

**Approach:**
- Python script following existing patterns: `#!/usr/bin/env python3`, `pathlib.Path`, `json.dumps()` output, `main()` guard
- Scans `scripts/` and `skills/*/scripts/` for `.sh` and `.py` files
- Reads R3 frontmatter from each script (lines 2-3: `# <name> -- <description>`)
- Generates `scripts/INDEX.md` with R8-compliant structure: YAML frontmatter with `tags: [index, scripts]`, description, table with Link and Description columns
- Also generates an `INDEX.md` in each `skills/*/scripts/` directory listing that skill's scripts
- Ensures `docs/ROUTING.md` has an entry pointing to `scripts/INDEX.md` with the prescribed description
- `--help` flag with usage documentation
- Exit codes: 0 success, 1 error

**Patterns to follow:** `scripts/extract-ktds.py` and `scripts/verify-ktd-literal.py` for Python script structure. `docs/standards/index-standards.md` for R8 format.

**Test scenarios:**
- Happy path: Scans all `.sh` and `.py` files in `scripts/` and `skills/*/scripts/`, extracts frontmatter, generates valid index
- Happy path: Generated `scripts/INDEX.md` passes R8 validation
- Happy path: Each `skills/*/scripts/` directory gets its own INDEX.md listing its scripts
- Edge case: Scripts without R3 frontmatter are listed with empty description and a warning is emitted
- Edge case: ROUTING.md entry is created if missing, updated if stale

**Verification:** `scripts/index-scripts.py` generates `scripts/INDEX.md` that passes `scripts/validate-index-standards.py`. ROUTING.md has the correct entry.

---

### U8. Create ROUTING.md

**Goal:** Create the Map of Content pointing to other indices and important information.

**Requirements:** R2

**Dependencies:** U7 (script-index.md must exist to be referenced)

**Files:**
- `docs/ROUTING.md` (new)

**Approach:**
- R8-compliant structure: YAML frontmatter with `tags: [index, routing]`, brief description, table
- Entries point to: `scripts/INDEX.md` (from U7), `docs/standards/INDEX.md`, `docs/solutions/INDEX.md` (from U9)
- Each entry has Link and Description columns per R8
- Only ROUTING.md may reference files outside its parent folder per R8 convention
- The script-index entry uses the prescribed description: "Index of all repo-level scripts. Read this any time you need to perform a repeatable task, such as git operations, JSON output, etc. Also consult this before running any ad-hoc scripts to see if one doesn't already exist"

**Patterns to follow:** `docs/standards/INDEX.md` for R8 structure. The R8 convention in `docs/standards/index-standards.md`.

**Test scenarios:**
- Happy path: ROUTING.md lists all major indices with accurate descriptions
- Happy path: ROUTING.md passes R8 validation
- Edge case: Only ROUTING.md references files outside its parent folder

**Verification:** `scripts/validate-index-standards.py` reports zero errors for ROUTING.md.

---

### U9. Create update-indexes.py

**Goal:** Automate recursive INDEX.md creation/updates across `docs/` and `skills/*/scripts/`.

**Requirements:** R3, R14

**Dependencies:** U7 (index-scripts.py exists), U8 (ROUTING.md exists)

**Files:**
- `scripts/update-indexes.py` (new)
- `tests/scripts/test-update-indexes.py` (new)
- `.pre-commit-config.yaml` or equivalent hook configuration (new or updated)

**Approach:**
- Recursively searches through `docs/` subdirectories for INDEX.md updates
- In each `docs/` subfolder, creates or updates an INDEX.md conforming to R8
- For `docs/solutions/` subdirectories: adds a "Tags" column pulled from solution file frontmatter
- Descriptions pulled from the paragraph between first and second headings in each file
- Ensures ROUTING.md has a table entry pointing to `docs/solutions/INDEX.md`
- Calls `scripts/index-scripts.py` to handle all script indexing (in `scripts/` and `skills/*/scripts/`) — does NOT do any script indexing itself. All script indexing logic lives exclusively in `index-scripts.py`.
- Configured as a pre-commit hook so indexes are updated automatically before every commit
- `--help` flag, `--dry-run` flag for preview
- Exit codes: 0 success, 1 error

**Patterns to follow:** `scripts/index-scripts.py` (U7) for Python structure. `docs/standards/index-standards.md` for R8 format.

**Test scenarios:**
- Happy path: Creates INDEX.md in each `docs/` subfolder that doesn't have one
- Happy path: Creates INDEX.md in each `skills/*/scripts/` directory
- Happy path: Updates existing INDEX.md files to match current directory contents
- Happy path: `docs/solutions/INDEX.md` includes Tags column from frontmatter
- Edge case: `--dry-run` shows what would change without writing
- Edge case: Calls index-scripts.py as part of the run
- Happy path: Pre-commit hook runs update-indexes.py and stages updated INDEX.md files

**Verification:** `scripts/update-indexes.py` produces R8-compliant INDEX.md files. `docs/solutions/INDEX.md` includes Tags column.

---

### U10. Deprecate script-index skill

**Goal:** Remove the manual `script-index` skill, replaced by `index-scripts.py`.

**Requirements:** R4

**Dependencies:** U7 (index-scripts.py exists and works)

**Files:**
- `skills/script-index/SKILL.md` (remove entirely)

**Approach:**
- Remove `skills/script-index/SKILL.md` entirely — `index-scripts.py` (U7) generates `scripts/INDEX.md` which replaces the manual routing table
- `grep` all skills for references to `script-index` and enumerate each one explicitly in this plan so the implementer does not need to search during implementation
- Update each referenced skill to point to `scripts/INDEX.md` instead
- Known references to check: any skill that mentions `script-index`, `/script-index`, or the old manual index routing table

**Patterns to follow:** None — this is a removal/replacement.

**Test scenarios:**
- Happy path: No skill references the old `script-index` skill
- Happy path: `scripts/INDEX.md` is the authoritative script index

**Verification:** `skills/script-index/` is removed or reduced to a redirect. All script references point to `scripts/INDEX.md`.

---

### Phase 3: Script Extraction (depends on Phase 2 for index updates)

### U11. Create dispatch standards documentation and enumerate extraction scripts

**Goal:** Create the standards documentation that all subsequent units in this phase will follow, and enumerate all scripts that need to be extracted per KTD-3.

**Requirements:** R5, R6, R13

**Dependencies:** U1 (dispatch standards updated)

**Files:**
- `docs/standards/dispatch-standard.md` (new — if not already created by U1)
- Enumeration output: list of all inline scripts across all skills that qualify for extraction per KTD-3

**Approach:**
- Create or verify the dispatch standards documentation that all units in this phase must follow
- Follow KTD-3's directions to look through ALL skills and enumerate any additional scripts that need to be pulled out
- For each skill, identify inline blocks that qualify as extraction candidates (per KTD-3 criteria: duplicated across skills, complex mechanical steps, steps with known bugs)
- Output a structured list that subsequent units (U13+) can reference during implementation
- This enumeration must happen before extraction begins to avoid missing scripts

**Patterns to follow:** KTD-3 decision-surface criteria. `skills/ts-work/SKILL.md` and `skills/ts-pr-review/SKILL.md` for examples of inline blocks.

**Test scenarios:**
- Happy path: All 6 target skills are audited for extractable inline blocks
- Happy path: Each identified block is categorized by KTD-3 criteria (duplication, complexity, known bugs)
- Edge case: Blocks that should stay inline (templates, single-idiom steps) are explicitly excluded

**Verification:** A complete enumeration of extractable scripts exists, categorized by KTD-3 criteria, ready for subsequent units to consume.

---

### U12. Create shared scripts: default-branch.sh and context-gather.sh

**Goal:** Extract duplicated default-branch resolution and git-context-gathering into shared scripts.

**Requirements:** R5, R6

**Dependencies:** None (these are new scripts, no existing file conflicts)

**Files:**
- `scripts/default-branch.sh` (existing — verify Wave 1 implementation matches spec)
- `scripts/context-gather.sh` (new)
- `tests/scripts/test-default-branch.sh` (new)
- `tests/scripts/test-context-gather.sh` (new)

**Approach:**
- `default-branch.sh`: Already exists at `scripts/git-default-branch.sh` (renamed in PR #104). Verify the existing implementation matches spec; add tests if missing. Do not create a new script.
- `context-gather.sh`: Gather git context used by ts-commit and ts-commit-push-pr: current branch, default branch, recent commits, dirty/untracked/staged files, unpushed status. Output: JSON on stdout. Combines the inline context-gathering blocks from both skills.
- Both follow R3 frontmatter, `--help`, exit codes, input validation conventions
- Both must have corresponding tests per `docs/standards/testing-standards.md`

**Patterns to follow:** `scripts/git-context.sh` for git state JSON output patterns. `scripts/git-default-branch.sh` for the existing default branch script.

**Test scenarios:**
- Happy path: `default-branch.sh` returns `main` when origin/HEAD points to main
- Happy path: `context-gather.sh` returns valid JSON with all expected fields
- Edge case: Fallback chain works when origin/HEAD is not set
- Edge case: Dirty files list is accurate

**Verification:** Both scripts produce correct output in the taegosts-skills repo. Tests pass.

---

### U13. Extract ts-pr-review inline scripts

**Goal:** Extract the diff line mapping awk script and PR data fetch into reusable scripts.

**Requirements:** R5, R6

**Dependencies:** None

**Files:**
- `skills/ts-pr-review/scripts/map-diff-lines.sh` (new)
- `skills/ts-pr-review/scripts/fetch-pr-data.sh` (new)
- `skills/ts-pr-review/SKILL.md` (update to call extracted scripts)
- `tests/skills/ts-pr-review/test-map-diff-lines.sh` (new)
- `tests/skills/ts-pr-review/test-fetch-pr-data.sh` (new)

**Approach:**
- `map-diff-lines.sh`: Extract the complex awk script (lines 73-78 of SKILL.md) that parses diff output to build `file:line` mapping. Input: diff on stdin or as file argument. Output: JSON mapping of `file:line` to diff locations. The awk logic stays in the script; the skill just calls it and parses the JSON result. **Aligns with R16:** This script's input source will be updated in U18 to use `gh pr diff` instead of local `git diff -U10`.
- `fetch-pr-data.sh`: Extract the `gh pr view` call (line 39) into a script with `--repo` and `--pr` arguments. Output: JSON with PR metadata. Uses `gh` CLI (matching existing patterns). This is a separate concern from `map-diff-lines.sh` (API data fetch vs. diff parsing), so it remains a distinct script.
- Update SKILL.md to call these scripts instead of inline commands

**Patterns to follow:** `scripts/pr-metadata.sh` for PR data fetching. `scripts/to-json.sh` for JSON output patterns.

**Test scenarios:**
- Happy path: `map-diff-lines.sh` correctly maps file:line pairs from a sample diff
- Happy path: `fetch-pr-data.sh` returns valid JSON PR metadata
- Edge case: Large diffs with many hunks are handled correctly
- Edge case: Binary files in diff are skipped

**Verification:** Both scripts produce correct output. SKILL.md calls them instead of inline commands.

---

### U14. Extract ts-pr-fix-findings inline scripts

**Goal:** Extract the thread resolution GraphQL mutation and re-review request into scripts.

**Requirements:** R5, R6

**Dependencies:** None

**Files:**
- `skills/ts-pr-fix-findings/scripts/resolve-thread.sh` (new)
- `skills/ts-pr-fix-findings/scripts/request-re-review.sh` (new)
- `skills/ts-pr-fix-findings/SKILL.md` (update to call extracted scripts)
- `tests/skills/ts-pr-fix-findings/test-resolve-thread.sh` (new)
- `tests/skills/ts-pr-fix-findings/test-request-re-review.sh` (new)

**Approach:**
- `resolve-thread.sh`: Extract the GraphQL mutation (line 198 of SKILL.md) into a script. Input: `--repo owner/repo --thread-id <id>`. Output: JSON with resolution status. Uses `gh api graphql`.
- `request-re-review.sh`: Extract the re-review request (lines 207-212) into a script. Input: `--repo owner/repo --pr number --reviewer name`. Output: JSON confirmation. Uses `gh api` or `gh pr edit`.
- Both include R3 frontmatter, `--help`, input validation (owner/repo format, numeric PR), exit codes
- Update SKILL.md Steps 3 and 5 to call these scripts

**Patterns to follow:** `skills/ts-pr-fix-findings/scripts/check-thread-resolution.sh` for GraphQL API patterns. `scripts/pr-metadata.sh` for `gh api` patterns.

**Test scenarios:**
- Happy path: `resolve-thread.sh` resolves a thread via GraphQL
- Happy path: `request-re-review.sh` requests a re-review
- Edge case: Invalid thread ID produces JSON error
- Edge case: API auth failure produces clear error message

**Verification:** Both scripts work against a real PR. SKILL.md calls them instead of inline commands.

---

### U15. Extract ts-commit and ts-commit-push-pr context gathering

**Goal:** Replace inline context-gathering blocks in ts-commit and ts-commit-push-pr with calls to `context-gather.sh`.

**Requirements:** R5

**Dependencies:** U12 (context-gather.sh exists)

**Files:**
- `skills/ts-commit/SKILL.md` (update to call context-gather.sh)
- `skills/ts-commit-push-pr/SKILL.md` (update to call context-gather.sh)

**Approach:**
- Replace the inline `printf` + git commands blocks (ts-commit line 37, ts-commit-push-pr line 40) with a call to `../../scripts/context-gather.sh`
- The skill parses the JSON output instead of executing individual git commands
- Preserve the skill's orchestration logic (what to do with the context data)

**Patterns to follow:** How other skills consume `scripts/git-context.sh` output.

**Test scenarios:**
- Happy path: ts-commit successfully gathers context via the script
- Happy path: ts-commit-push-pr successfully gathers context via the script
- Edge case: Script failure doesn't block the skill (graceful fallback)

**Verification:** Both skills invoke `context-gather.sh` instead of inline git commands.

---

### U16. Extract ts-work inline scripts

**Goal:** Extract high-value inline steps from ts-work into reusable scripts.

**Requirements:** R5, R6

**Dependencies:** U12 (default-branch.sh may be used)

**Files:**
- `skills/ts-work/SKILL.md` (update to call extracted scripts)
- New scripts as identified (e.g., `scripts/cross-check-conventions.sh` if the convention grep pattern is worth extracting)

**Approach:**
- Audit ts-work SKILL.md for extractable inline steps (context gathering, default branch resolution, convention cross-checking)
- Replace inline blocks with calls to shared or skill-specific scripts
- The incremental commit pattern (`git add && git commit`) is a template, not extractable — stays inline
- Focus on steps that are duplicated with other skills or have meaningful complexity

**Patterns to follow:** The existing script consumption pattern in ts-work (calling `scripts/extract-ktds.py`, `scripts/detect-missing-artifacts.sh`).

**Test scenarios:**
- Happy path: ts-work successfully calls extracted scripts
- Edge case: Script failures are handled gracefully

**Verification:** ts-work SKILL.md calls scripts for mechanical steps instead of inline commands.

---

### U17. Create CLAUDE.md (#81)

**Goal:** Create a `CLAUDE.md` at the repo root with a concise repository summary, pointer to ROUTING.md, and universal agent rules.

**Requirements:** R15

**Dependencies:** U8 (ROUTING.md must exist to be referenced)

**Files:**
- `CLAUDE.md` (new)

**Approach:**
- Write a concise repository summary optimized for AI consumption (what this repo is, its purpose, key concepts)
- Include a pointer to `docs/ROUTING.md` as the entry point for navigating documentation
- Include ONLY high-level rules that EVERY agent touching this repository must follow (e.g., "check ROUTING.md to locate documentation and scripts", "follow R3 frontmatter for all scripts", "Bootstrap is the only allowed dispatch pattern"). If a rule is not needed by every agent, it does NOT belong in CLAUDE.md — it belongs in `docs/`.
- Keep it short — CLAUDE.md is a quick-reference, not a replacement for the full docs tree
- CLAUDE.md is NOT an index file; it does not follow R8 conventions

**Patterns to follow:** CLAUDE.md files in similar repos for structure and brevity.

**Test scenarios:**
- Happy path: CLAUDE.md exists at repo root with summary, ROUTING.md pointer, and rules
- Happy path: ROUTING.md pointer resolves to the actual file
- Edge case: CLAUDE.md is under 100 lines (concise, not exhaustive)

**Verification:** `CLAUDE.md` exists at repo root, references ROUTING.md, and contains universal agent rules.

---

### U18. Fix ts-pr-review line number verification (#101)

**Goal:** Build the linemap from `gh pr diff` output (GitHub's 3-line context) instead of local `git diff -U10` so inline comment line numbers match what the Reviews API accepts.

**Requirements:** R16

**Dependencies:** U13 (map-diff-lines.sh must exist)

**Files:**
- `skills/ts-pr-review/SKILL.md` (update Step 4b linemap generation)
- `skills/ts-pr-review/scripts/map-diff-lines.sh` (from U13 — must use `gh pr diff` output)

**Approach:**
- In Step 4b, replace the local `git diff -U10` with `gh pr diff NUMBER` for linemap generation
- The awk script stays the same; only the input source changes
- This ensures the linemap's hunk boundaries match GitHub's PR diff exactly
- Findings that fall outside GitHub's hunk range are moved to the review body as a fallback (existing behavior preserved)

**Patterns to follow:** The existing awk linemap script in ts-pr-review SKILL.md. The `gh pr diff` usage pattern in other skills.

**Test scenarios:**
- Happy path: Inline comments on lines within GitHub's 3-line context hunks succeed
- Edge case: Lines in local diff's 10-line context but outside GitHub's hunk range are detected and moved to review body
- Edge case: Large diffs with many hunks produce correct linemap

**Verification:** Posting inline comments to a real PR does not produce "Line could not be resolved" errors for lines within GitHub's hunk ranges.

---

### Phase 4: Dispatch Unification (depends on U1 for standards)

### U19. Verify ts-work Bootstrap migration and add auto-dispatch

**Goal:** Verify ts-work's Bootstrap dispatch (migrated in PR #104) is complete and add the auto-dispatch mechanism for `implementer-tests` per `docs/standards/testing-standards.md`.

**Requirements:** R12

**Dependencies:** U1 (standards document updated)

**Files:**
- `skills/ts-work/SKILL.md` (verify/update dispatch instructions)

**Approach:**
- PR #104 already migrated ts-work to Bootstrap dispatch. Verify the migration is complete: agents read their own contract/role from disk, bootstrap-ack is enforced.
- Ensure the auto-dispatch mechanism is wired: when `implementer-general` modifies code files and the unit has non-manual test scenarios, `implementer-tests` is auto-dispatched per the three-gate check in `docs/solutions/conventions/automatic-test-dispatch.md`.
- Verify disk-first completion: agents write output to disk as the authoritative signal. Orchestrator uses Monitor/inotifywait or `scripts/wait-for-file.sh` for detection.
- Preserve the existing serial/parallel dispatch logic and worktree isolation.

**Patterns to follow:** `docs/solutions/conventions/subagent-bootstrap-dispatch.md` for Bootstrap pattern. `docs/solutions/conventions/automatic-test-dispatch.md` for auto-dispatch gates. `docs/solutions/workflow-issues/notification-resilience-via-disk-state.md` for disk-first completion.

**Test scenarios:**
- Happy path: ts-work dispatches implementer-general via Bootstrap (file paths, not inline content)
- Happy path: implementer-tests is auto-dispatched when code files change and test scenarios exist
- Edge case: Bootstrap-ack verification catches line count mismatches
- Edge case: Disk-first completion works when notification is missed

**Verification:** ts-work uses Bootstrap dispatch with auto-dispatch and disk-first completion.

---

### U20. Migrate all remaining skills to Bootstrap dispatch

**Goal:** Migrate ts-compound (direct-seed), ts-code-review (template-wrapped), and ts-verify-implementation (template-wrapped) to Bootstrap dispatch. ts-work, ts-plan, and ts-doc-review are already migrated (PR #104).

**Requirements:** R12

**Dependencies:** U1 (standards document updated)

**Files:**
- `skills/ts-compound/SKILL.md` (update dispatch instructions)
- `skills/ts-code-review/SKILL.md` (update dispatch instructions)
- `skills/ts-verify-implementation/SKILL.md` (update dispatch instructions)

**Approach:**
- PR #104 already migrated ts-work, ts-plan, and ts-doc-review to Bootstrap. Three skills remain.
- **ts-compound:** Convert from direct-seed to file-path-based Bootstrap: orchestrator passes agent file paths, subagent reads its own contract from disk. ts-compound's Phase 1 research agents should work through Bootstrap the same way ts-plan's research agents do.
- **ts-code-review:** Convert from template-wrapped to Bootstrap: create or use existing Bootstrap agent definitions for the code review subagents.
- **ts-verify-implementation:** Convert from template-wrapped to Bootstrap: create or use existing Bootstrap agent definitions for the verification subagents.
- Ensure bootstrap-ack is enforced for all three: agent emits file paths + line counts; orchestrator verifies.
- Verify disk-first completion: agents write output to disk as the authoritative signal.

**Patterns to follow:** `skills/ts-plan/SKILL.md` for the Bootstrap migration pattern (already done). `docs/solutions/conventions/subagent-bootstrap-dispatch.md` for the full Bootstrap pattern.

**Test scenarios:**
- Happy path: ts-compound dispatches research agents via Bootstrap (file paths, not inline content)
- Happy path: ts-code-review dispatches review agents via Bootstrap
- Happy path: ts-verify-implementation dispatches verification agents via Bootstrap
- Happy path: Bootstrap-ack verification works for all three skills
- Error path: If Bootstrap agent definition is missing, the skill fails with a clear error (no fallback to deprecated patterns)

**Verification:** All three skills use Bootstrap dispatch. No template-wrapped or direct-seed patterns remain.

---

### Phase 5: Finalization

### U21. Update docs/standards/INDEX.md and run update-indexes.py

**Goal:** Ensure all indices are up-to-date after Wave 2 changes.

**Requirements:** R3

**Dependencies:** U7, U8, U9 (index infrastructure complete), U1-U20 (all changes landed)

**Files:**
- All `INDEX.md` files across `docs/` and `skills/*/scripts/` (regenerated by `update-indexes.py` — do NOT edit manually)
- `scripts/INDEX.md` (regenerated by `index-scripts.py` — do NOT edit manually)
- `docs/ROUTING.md` (verified up-to-date)

**Approach:**
- Run `scripts/update-indexes.py` to regenerate all INDEX.md files — this script handles everything including calling `index-scripts.py`. `docs/standards/INDEX.md` is updated by the script, not manually.
- Run `scripts/validate-index-standards.py --all` to confirm compliance
- Verify ROUTING.md has entries for all sub-indices
- Ensure all new/updated standards from this PR are documented in the appropriate locations (the script will pick them up from frontmatter)

**Patterns to follow:** R8 convention in `docs/standards/index-standards.md`.

**Test scenarios:**
- Happy path: All INDEX.md files pass R8 validation
- Happy path: ROUTING.md references all sub-indices
- Happy path: `scripts/INDEX.md` lists all scripts with accurate descriptions

**Verification:** `scripts/validate-index-standards.py --all` reports zero errors. `scripts/update-indexes.py` produces no changes (idempotent).

## Scope Boundaries

**In scope:**
- All 6 skills for script extraction (ts-commit, ts-commit-push-pr, ts-pr-review, ts-verify-implementation, ts-pr-fix-findings, ts-work)
- Index infrastructure (index-scripts.py, update-indexes.py, ROUTING.md)
- 5 script hardening fixes (#63, #60, #61, #47, #44) — fixes for #63, #47, #44 already applied in Wave 1; verification and test coverage remain
- Dispatch pattern unification to Bootstrap (ts-compound, ts-code-review, ts-verify-implementation migration; ts-work/ts-plan verification)
- Standards documentation updates
- CLAUDE.md creation (#81)
- ts-pr-review line number verification fix (#101)
- Auto-dispatch wiring for extracted scripts per testing-standards.md

**Deferred to Follow-Up Work:**
- **Agent consolidation (#83)** — requires its own dedicated plan. Tracked separately.
- **Script-index skill removal** — may be kept as a thin redirect if downstream tools depend on it.

**Out of scope:**
- Agent deduplication across skills (#83)
- Changes to skills' core orchestration logic (only dispatch pattern changes)
- New agent definitions beyond what's needed for Bootstrap migration

## Risks & Dependencies

- **Wave 1 landed:** R3/R7/R8 standards, ShellCheck integration, and script fixes (#63, #47, #44) are already on main (PR #99). No dependency gate for Phase 1 or Phase 2.
- **Wave 1.5 landed:** Bootstrap dispatch, testing-standards.md, notification resilience are on main (PR #104). Phase 4 work includes ts-compound, ts-code-review, and ts-verify-implementation migration to Bootstrap.
- **Script extraction coordination:** Track 2 (extraction) and Track 3 (fixes) may touch the same scripts. Coordinate to avoid conflicts — fixes should land before extraction changes the target files.
- **Bootstrap migration risk:** ts-compound, ts-code-review, and ts-verify-implementation must all be migrated to Bootstrap. Migration is a behavioral change; test thoroughly. Template-wrapped is fully deprecated — no fallback.
- **Inline script identification:** Some inline blocks in SKILL.md are templates (e.g., commit message patterns) that should stay inline, not be extracted. The implementer must use judgment on extraction candidates.
- **Testing coverage:** PR #104's auto-dispatch mechanism means extracted scripts automatically get test coverage. The implementer must ensure each extraction unit has test scenarios defined so the auto-dispatch fires.

## System-Wide Impact

- All skills use Bootstrap dispatch (template-wrapped and direct-seed fully deprecated), reducing token cost by ~97% per reviewer invocation
- Automated index infrastructure replaces manual script-index skill
- ROUTING.md provides a single entry point for navigating the repo's documentation
- Extracted scripts reduce token cost for skill invocations and are ShellCheck-clean
- Hardened scripts prevent input validation bugs from PR review findings
- Auto-dispatch ensures test coverage for all extracted scripts without manual planning
- Disk-first completion pattern improves notification resilience across all dispatch flows
