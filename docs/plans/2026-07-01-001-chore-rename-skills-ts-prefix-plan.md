---
title: "chore: Rename skills to ts- prefix and rebrand from compound-engineering"
type: chore
date: 2026-07-01
---

## Summary

Rename all 13 skill directories and their references to use a `ts-` prefix (replacing `ce-` for the 9 prefixed skills, prepending `ts-` for the 4 unprefixed ones). Update all cross-references, runtime artifact paths, config directory paths, and brand identity strings from `compound-engineering` to `taegosts-skills`. Work on a dedicated feature branch.

## Problem Frame

The skills in this repo originated from the Compound Engineering plugin and have been heavily customized. To avoid namespace collisions with other plugins that use the `ce-` prefix, every skill needs a unique `ts-` prefix. The `compound-engineering` branding in paths and identity strings should also reflect the actual project name (`taegosts-skills`).

## Requirements

**Naming**
- R1. Every skill directory uses a `ts-` prefix.
- R2. The `name:` field in each SKILL.md frontmatter matches the new directory name.
- R3. Every `/skill-name` invocation reference in SKILL.md files points to the new name.

**Cross-references**
- R4. Inter-skill references in SKILL.md files and reference markdown files use the new names.
- R5. Test file paths referencing skill directories point to the new locations.
- R6. Scripts within skills that reference their own or other skill paths are updated.

**Branding**
- R7. Runtime artifact paths under `/tmp/compound-engineering/` become `/tmp/taegosts-skills/`.
- R8. Config directory references (`.compound-engineering/config.local.yaml`) become `.taegosts-skills/config.local.yaml`.
- R9. Brand identity strings (`ai:compound-engineering`, `Compound Engineering`) become `ai:taegosts-skills` / `Taegost's Skills`.
- R10. The shield badge URL in PR description writing references `taegosts-skills`.

## Key Technical Decisions

- **KTD-1: Atomic rename per skill.** Rename each skill directory with `git mv`, then update all references in a single pass per category (SKILL.md, references, tests, scripts). This preserves git history and makes each unit independently reviewable.
- **KTD-2: No backward compatibility aliases.** The old `ce-` names are dropped entirely. The plugin is not yet published to a marketplace where users depend on the old names.
- **KTD-3: Config directory rename.** `.compound-engineering/` → `.taegosts-skills/` in all references, even though the directory doesn't exist yet. This ensures future config setup uses the correct namespace.
- **KTD-4: Brand identity rename.** `ai:compound-engineering` / `Compound Engineering` → `ai:taegosts-skills` / `Taegost's Skills` everywhere, including Proof publishing identity and subagent templates.

## Implementation Units

### U1. Create feature branch and rename skill directories

**Goal:** Establish the branch and rename all 13 skill directories using `git mv`.

**Requirements:** R1

**Dependencies:** None

**Files:**
- `skills/ce-brainstorm/` → `skills/ts-brainstorm/`
- `skills/ce-code-review/` → `skills/ts-code-review/`
- `skills/ce-commit/` → `skills/ts-commit/`
- `skills/ce-commit-push-pr/` → `skills/ts-commit-push-pr/`
- `skills/ce-compound/` → `skills/ts-compound/`
- `skills/ce-debug/` → `skills/ts-debug/`
- `skills/ce-doc-review/` → `skills/ts-doc-review/`
- `skills/ce-plan/` → `skills/ts-plan/`
- `skills/ce-work/` → `skills/ts-work/`
- `skills/do-work-loop/` → `skills/ts-do-work-loop/`
- `skills/pr-fix-findings/` → `skills/ts-pr-fix-findings/`
- `skills/pr-review/` → `skills/ts-pr-review/`
- `skills/verify-implementation/` → `skills/ts-verify-implementation/`

**Approach:** Create branch `chore/rename-skills-ts-prefix` from current HEAD. Run `git mv` for each directory. Commit the directory renames as a standalone commit so git tracks the moves cleanly.

**Test scenarios:**
- Happy path: All 13 directories exist under `skills/ts-*` after the rename.
- Verification: `ls skills/` shows only `ts-` prefixed directories (plus any non-skill dirs).

**Verification:** `git status` shows 13 renamed directories, no untracked originals.

---

### U2. Update SKILL.md frontmatter and self-references

**Goal:** Update the `name:` field and any self-referential skill invocations in each SKILL.md.

**Requirements:** R2, R3

**Dependencies:** U1

**Files:** All 13 `skills/ts-*/SKILL.md` files

**Approach:** For each SKILL.md, update the `name:` field in frontmatter. Replace all `/ce-*` invocation references with `/ts-*` equivalents. Replace `/do-work-loop` with `/ts-do-work-loop`, `/pr-review` with `/ts-pr-review`, `/pr-fix-findings` with `/ts-pr-fix-findings`, `/verify-implementation` with `/ts-verify-implementation`.

**Patterns to follow:** The existing frontmatter format in each SKILL.md — only the `name:` value changes.

**Test scenarios:**
- Happy path: Every SKILL.md's `name:` field matches its directory name.
- Edge case: References like `/ce-plan output:md` become `/ts-plan output:md` (preserving arguments).
- Verification: `grep -r "name: ce-\|name: do-work\|name: pr-\|name: verify-" skills/ --include="SKILL.md"` returns nothing.

**Verification:**
- `grep -r "name: ce-\|name: do-work\|name: pr-\|name: verify-" skills/ --include="SKILL.md"` returns nothing.
- `grep -rn "/ce-\|/do-work-loop\|/pr-review\|/pr-fix-findings\|/verify-implementation" skills/ --include="SKILL.md"` returns nothing (catches non-frontmatter invocation references).

---

### U3. Update inter-skill references in SKILL.md and reference files

**Goal:** Update all cross-skill references in SKILL.md files and reference markdown files.

**Requirements:** R4

**Dependencies:** U1

**Files:** All `skills/ts-*/SKILL.md` files (cross-skill references, not self-references — those are U2) and all `skills/ts-*/references/**/*.md` files (~78 files total). Use dynamic discovery: `grep -rn 'ce-\|do-work-loop\|pr-fix-findings\|pr-review\|verify-implementation' skills/ --include="*.md" -l` to produce the actual file list at execution time.

**Approach:** Global find-and-replace across all SKILL.md and reference files. The replacements are mechanical:
- `/ce-brainstorm` → `/ts-brainstorm`, `/ce-plan` → `/ts-plan`, `/ce-work` → `/ts-work`, `/ce-debug` → `/ts-debug`, `/ce-commit` → `/ts-commit`, `/ce-commit-push-pr` → `/ts-commit-push-pr`, `/ce-code-review` → `/ts-code-review`, `/ce-doc-review` → `/ts-doc-review`, `/ce-compound` → `/ts-compound`
- `/do-work-loop` → `/ts-do-work-loop`, `/pr-review` → `/ts-pr-review`, `/pr-fix-findings` → `/ts-pr-fix-findings`, `/verify-implementation` → `/ts-verify-implementation`
- Backtick-wrapped references like `` `ce-plan` `` → `` `ts-plan` ``
- Bare references like `ce-brainstorm` (in prose) → `ts-brainstorm`

**Patterns to follow:** Existing reference file formatting — only the skill names change.

**Test scenarios:**
- Happy path: No `ce-*` or unprefixed skill name references remain in any reference file.
- Edge case: References in prose context like "the `ce-plan` skill" become "the `ts-plan` skill".
- Verification: `grep -rn "/ce-\|ce-brainstorm\|ce-plan\|ce-work\|ce-debug\|ce-commit\|ce-code-review\|ce-doc-review\|ce-compound\|do-work-loop\|verify-implementation" skills/ --include="*.md" -l` returns no reference files.

**Verification:** Zero remaining old skill name references in reference markdown files.

---

### U4. Update runtime artifact paths

**Goal:** Replace `/tmp/compound-engineering/` with `/tmp/taegosts-skills/` in all references, and update the `ce-*` subdirectory names within those paths.

**Requirements:** R7

**Dependencies:** U1

**Files:** Use dynamic discovery: `grep -rn '/tmp/compound-engineering' skills/ --include="*.md" -l` at execution time. Known files:
- `skills/ts-brainstorm/SKILL.md`
- `skills/ts-brainstorm/references/handoff.md`
- `skills/ts-compound/SKILL.md`
- `skills/ts-code-review/references/review-output-template.md`
- `skills/ts-code-review/references/subagent-template.md`
- `skills/ts-work/references/shipping-workflow.md`
- `skills/ts-work/references/review-findings-followup.md`
- `skills/ts-work/references/tracker-defer.md`
- `skills/ts-doc-review/references/subagent-template.md`

**Approach:** Replace `/tmp/compound-engineering/ce-code-review/` with `/tmp/taegosts-skills/ts-code-review/`, `/tmp/compound-engineering/ce-brainstorm/` with `/tmp/taegosts-skills/ts-brainstorm/`, `/tmp/compound-engineering/ce-compound/` with `/tmp/taegosts-skills/ts-compound/`, and any other `/tmp/compound-engineering/ce-*` patterns similarly.

**Test scenarios:**
- Happy path: All `/tmp/` paths reference `taegosts-skills` and `ts-*` skill names.
- Verification: `grep -rn "/tmp/compound-engineering" skills/` returns nothing.

**Verification:** Zero remaining `/tmp/compound-engineering/` references.

---

### U5. Update config directory and brand identity references

**Goal:** Rename `.compound-engineering/` config references and `compound-engineering` brand identity strings.

**Requirements:** R6, R8, R9, R10

**Dependencies:** U1

**Files:** Use dynamic discovery: `grep -rn 'compound-engineering\|\.compound-engineering/' skills/ README.md --include="*.md" -l` at execution time. Known files include:
- `README.md` (skill table, directory tree, `Compound Engineering` prose)
- `skills/ts-brainstorm/SKILL.md` (`.compound-engineering/config.local.yaml`)
- `skills/ts-plan/SKILL.md` (`.compound-engineering/config.local.yaml`, `ai:compound-engineering`, `Compound Engineering`, `ce-proof`)
- `skills/ts-plan/references/html-rendering.md` (`.compound-engineering/DESIGN.md`)
- `skills/ts-plan/references/plan-handoff.md` (`ai:compound-engineering`, `Compound Engineering`)
- `skills/ts-brainstorm/references/html-rendering.md` (`.compound-engineering/DESIGN.md`)
- `skills/ts-brainstorm/references/handoff.md` (`ai:compound-engineering`, `Compound Engineering`)
- `skills/ts-doc-review/references/subagent-template.md` (`compound-engineering`)
- `skills/ts-commit-push-pr/references/pr-description-writing.md` (badge URL and alt text)
- `skills/ts-code-review/references/personas/learnings-researcher.md` (`compound-engineering` in search pattern)
- `skills/ts-plan/references/agents/learnings-researcher.md` (`compound-engineering` in search pattern)
- `skills/ts-compound/scripts/validate-frontmatter.py` (`ce-compound` in docstring)
- `skills/ts-compound/scripts/session-history/extract-metadata.py` (`ce-session-extract` in comment)

**Approach:** Mechanical replacements:
- `.compound-engineering/` → `.taegosts-skills/`
- `ai:compound-engineering` → `ai:taegosts-skills`
- `Compound Engineering` → `Taegost's Skills`
- `ce-proof` → `ts-proof` (the skill reference; the `ce-proof` skill itself doesn't exist as a directory but is referenced as a skill name)
- Badge: `Built_with-Compound_Engineering` → `Built_with-Taegosts_Skills` and update URL
- Search patterns: `compound-engineering|skill-design` → `taegosts-skills|skill-design`

**Test scenarios:**
- Happy path: Zero remaining `compound-engineering` references in any skill file.
- Edge case: The phrase "compound-engineering-plugin" in the badge URL gets updated to point to the correct repo.
- Verification: `grep -rn "compound-engineering" skills/` returns nothing.

**Verification:** All brand references updated; no `compound-engineering` strings remain.

---

### U6. Update test file paths

**Goal:** Update test files that reference skill directory paths.

**Requirements:** R5

**Dependencies:** U1

**Files:** Use dynamic discovery at execution time: `find tests/skills/ -type d` to enumerate all test directories, then `git mv` each. Known directories:
- `tests/skills/ce-plan/` → `tests/skills/ts-plan/`
- `tests/skills/ce-doc-review/` → `tests/skills/ts-doc-review/`
- `tests/skills/ce-code-review/` → `tests/skills/ts-code-review/`
- `tests/skills/ce-work/` → `tests/skills/ts-work/`
- `tests/skills/ce-compound/` → `tests/skills/ts-compound/`
- `tests/skills/pr-fix-findings/` → `tests/skills/ts-pr-fix-findings/`
- `tests/skills/verify-implementation/` → `tests/skills/ts-verify-implementation/`
- `tests/skills/do-work-loop/` → `tests/skills/ts-do-work-loop/` (if it exists)

**Approach:** `git mv` each test directory to match the new skill name. Then update the `SCRIPT=` paths inside each test file to point to the new `skills/ts-*/scripts/` locations. Also update `tests/scripts/` files if they reference old skill paths.

**Test scenarios:**
- Happy path: All test files reference `skills/ts-*/scripts/` paths.
- Verification: `grep -rn "skills/ce-\|skills/pr-fix\|skills/pr-review\|skills/do-work\|skills/verify-impl" tests/` returns nothing.

**Verification:** Test directories and internal paths match new skill names.

---

### U7. Verify completeness and run tests

**Goal:** Confirm no old references remain and existing tests still pass.

**Requirements:** R1–R10

**Dependencies:** U2, U3, U4, U5, U6

**Files:** N/A (verification only)

**Approach:** Run comprehensive grep for any remaining old references. Scope to `skills/`, `tests/`, and `README.md` — exclude `docs/` (historical documentation is preserved as-is) and the plan document itself:
- `grep -rn "ce-brainstorm\|ce-plan\|ce-work\|ce-debug\|ce-commit\|ce-code-review\|ce-doc-review\|ce-compound\|ce-commit-push-pr\|do-work-loop\|pr-fix-findings\|pr-review\|verify-implementation" skills/ tests/ README.md --include="*.md" --include="*.sh" --include="*.py"` — should return nothing.
- `grep -rn "compound-engineering" skills/ tests/ README.md --include="*.md" --include="*.sh" --include="*.py"` — should return nothing.
- Run existing test scripts to confirm they still resolve paths correctly.

**Test scenarios:**
- Happy path: Zero remaining old references; all tests pass.
- Error path: If tests fail, diagnose path mismatches and fix.

**Verification:** Clean grep results; test suite passes.

## Scope Boundaries

**Intentionally excluded (historical documentation):**
- Files under `docs/solutions/`, `docs/brainstorms/`, and `docs/plans/` that reference old `ce-*` or `compound-engineering` names are preserved as-is. These are historical records of past decisions and their provenance value outweighs the branding inconsistency. The U7 verification grep explicitly excludes `docs/`.

**Deferred to Follow-Up Work:**
- Updating the `.claude-plugin/marketplace.json` (it doesn't reference skill names directly, but the plugin description could be refreshed).
- Creating a `.taegosts-skills/config.local.yaml` if the user wants to set `plan_output:` or other config.

**Outside this work:**
- Behavioral changes to any skill.
- New features or capabilities.
- Changes to the plugin installation mechanism.
