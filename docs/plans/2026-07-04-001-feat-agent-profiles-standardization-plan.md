---
title: "feat: Implement agent profiles instead of personas"
type: feat
date: 2026-07-04
origin: "GitHub Issue #74"
---

# Implement Agent Profiles Instead of Personas

## Summary

Standardize agent/persona definitions across all taegosts-skills into a uniform agent profile format. Migrates 21 persona files from `references/personas/` to `references/agents/`, adds YAML frontmatter to 40 existing agent/prompt files and creates 4 new agent files with frontmatter, expands 4 inline subagents into full agent definitions, and updates dispatch logic in `ts-work` and `ts-pr-fix-findings`. Establishes `docs/standards/agent-standards.md` as the canonical reference for agent conventions.

## Problem Frame

The repo has three inconsistent patterns for subagent prompt assets:

| Pattern | Skills | Directory | Frontmatter | Count |
|---------|--------|-----------|-------------|-------|
| Personas (no frontmatter) | ts-code-review, ts-doc-review | `references/personas/` | None | 21 |
| Agents (no frontmatter) | ts-compound, ts-plan, ts-work | `references/agents/` | None | 21 |
| Agent profiles (with frontmatter) | Root `agents/` (staging) | `agents/` | Full | 4 |

This creates three problems: no discoverability metadata on 42 of 46 prompt files, terminology drift ("personas" vs "agents" for the same concept), and inline subagent definitions in `ts-verify-implementation` that can't be reused or evolved independently.

## Requirements

**Agent Standards (R1)**
- R1a. All agents must have YAML frontmatter: `name`, `description` (when to activate), `tools`, `effort`
- R1b. All agents require 1-2 paragraphs of identity text after frontmatter
- R1c. Implementer agents (called by `ts-work`) use the implementer heading template
- R1d. Reviewer agents called by `ts-doc-review` use the reviewer heading template (Document type adaptation, What you check, Confidence calibration, What you don't flag). Agents in `ts-code-review` keep their existing heading patterns — only frontmatter and terminology are updated. `ts-verify-implementation` agents get full expansion with verification-specific headings (see R5)

**Migration (R2)**
- R2a. Rename `references/personas/` to `references/agents/` in ts-code-review and ts-doc-review
- R2b. Update all "persona" references to "agent" across all 7 skills
- R2c. Audit ts-compound, ts-plan, ts-work for remaining persona references and add frontmatter to all agent files

**Documentation (R3)**
- R3a. Create `docs/standards/` with `INDEX.md`
- R3b. Create `docs/standards/agent-standards.md` with all agent conventions

**Agent Placement (R4)**
- R4a. Move `agents/implementer-general.md` and `agents/implementer-tests.md` to `skills/ts-work/references/agents/`
- R4b. Move `agents/documentation-reviewer.md` and `agents/test-documentation-reviewer.md` to `skills/ts-doc-review/references/agents/`
- R4c. Update `ts-doc-review/SKILL.md` Build Agent List to include new agents
- R4d. Update `ts-work/SKILL.md` to include the new implementer agents (`implementer-general`, `implementer-tests`) in its agent dispatch section

**ts-verify-implementation Expansion (R5)**
- R5a. Extract 4 inline subagents into separate files under `references/agents/`
- R5b. Expand each agent file with verification-specific headings (What You Verify, Confidence Calibration, What You Don't Flag, Output Format)
- R5c. Create `references/subagent-template.md` adapted for implementation verification

**ts-pr-fix-findings Orchestration (R6)**
- R6a. Add finding-grouping logic to Step 3 for parallel subagent dispatch
- R6b. Add parallel ts-debug subagent dispatch to Step 5

**ts-work Execution Strategy (R7)**
- R7a. Always launch a subagent, even for small inline work
- R7b. Add decision section choosing `implementer-general` vs `implementer-tests` per task
- R7c. Remove `figma-design-sync.md` and all references to it

## Key Technical Decisions

**KTD-1. Two sub-templates for implementer vs reviewer agents.**
The heading structure differs by agent type. Implementer agents need: Scope Boundary, Fidelity to the Plan, What "Done" Looks Like, What You Don't Do, Failure Handling. Reviewer agents need: Document Type Adaptation, What You Check, Confidence Calibration, What You Don't Flag, Output Format (when applicable). A single template with conditional sections would be harder to maintain than two clear templates. The `docs/standards/agent-standards.md` document defines both.

**KTD-2. Conformance pass for ts-code-review; full expansion for ts-verify-implementation.**
`ts-code-review`'s 13 personas are already well-defined with clear domain boundaries and calibration sections. They need only frontmatter addition and "persona" → "agent" terminology updates. Their existing heading patterns (What you're hunting for, Confidence calibration, What you don't flag, Output format) are preserved — they do NOT adopt the ts-doc-review reviewer template. `ts-verify-implementation`'s 4 inline subagents need full expansion because they currently have 2-3 line descriptions that don't define scope boundaries, confidence calibration, or suppress conditions. These also keep their own heading pattern adapted for verification, not the ts-doc-review template.

**KTD-3. Rename `references/personas/` directories rather than moving files individually.**
A `git mv` of the directory preserves git history for all files in one operation. Individual file moves would lose the directory-level rename detection. After the rename, the 2 new root agents move into the already-renamed directory.

**KTD-4. Keep agents skill-local; do not consolidate cross-skill duplicates.**
Several agents exist in multiple skills with near-identical content (e.g., `security-sentinel` in ts-compound and ts-plan). Each skill dispatches from its own `references/agents/` directory. Consolidating into a shared location would introduce cross-skill dependencies. The standardization effort focuses on format consistency, not deduplication. Maintenance of duplicates is a deferred concern.

**KTD-5. Keep both dispatch patterns (template-wrapped and direct-seed).**
`ts-code-review` and `ts-doc-review` inject agent content into a subagent template via `{agent_file}` variable substitution. `ts-work`, `ts-compound`, and `ts-plan` seed agent files directly into generic subagents. Both patterns dispatch the same way (generic subagent + local prompt content). Unifying the dispatch mechanism is out of scope — the standardization effort targets the agent file format.

**KTD-6. ts-verify-implementation gets its own subagent template, not a shared one.**
The verification context (plan + git diff + KTDs) is fundamentally different from code review (PR diff) or document review (plan/requirements doc). A dedicated template avoids polluting the other templates with verification-specific context slots and output contracts.

## Implementation Units

### U1. Define Agent Standard

- **Goal:** Create the canonical standard document defining agent frontmatter schema, two heading sub-templates (implementer and reviewer), and terminology conventions.
- **Requirements:** R1a, R1b, R1c, R1d
- **Dependencies:** None
- **Files:**
  - `docs/standards/agent-standards.md` (create)
  - `docs/standards/INDEX.md` (create)
- **Approach:** Define the frontmatter schema (name, description, tools, effort) with field descriptions and valid values. Define two heading sub-templates:
  - **Implementer template:** Scope Boundary, Fidelity to the Plan, What "Done" Looks Like, What You Don't Do, Failure Handling
  - **Reviewer template:** Document Type Adaptation, What You Check, Confidence Calibration, What You Don't Flag, Output Format (when applicable)
  Document the terminology convention: "agent" everywhere, never "persona". Document the two dispatch patterns (template-wrapped vs direct-seed) as architectural context.
- **Patterns to follow:** The 4 root `agents/` files (`implementer-general.md`, `documentation-reviewer.md`, etc.) are the reference format. The `ts-doc-review/references/subagent-template.md` confidence rubric is the shared calibration anchor.
- **Test scenarios:**
  - Verify `agent-standards.md` defines all required frontmatter fields with descriptions
  - Verify both sub-templates are present with all required headings
  - Verify the terminology section explicitly states "agent" not "persona"
  - Verify `INDEX.md` links to `agent-standards.md` with a description
- **Verification:** Both files exist and contain the complete standard. An implementer reading only these files can create a conforming agent definition.

### U2. Migrate ts-code-review Personas to Agents

- **Goal:** Rename `references/personas/` to `references/agents/`, add frontmatter to all 14 files, update all "persona" references to "agent" throughout the skill.
- **Requirements:** R1a, R1b, R2a, R2b
- **Dependencies:** U1
- **Files:**
  - `skills/ts-code-review/references/personas/` → `skills/ts-code-review/references/agents/` (rename directory)
  - `skills/ts-code-review/references/agents/*.md` (14 files — add frontmatter)
  - `skills/ts-code-review/SKILL.md` (update terminology and paths)
  - `skills/ts-code-review/references/subagent-template.md` (rename `{persona_file}` to `{agent_file}`)
  - `skills/ts-code-review/references/persona-catalog.md` → `skills/ts-code-review/references/agent-catalog.md` (rename, update content)
  - `skills/ts-code-review/references/validator-template.md` (update terminology if present)
  - Note: R2b applies to ALL files under `ts-code-review/references/` that contain "persona" terminology, including `action-class-rubric.md`, `diff-scope.md`, `findings-schema.json`, `review-output-template.md`
- **Approach:**
  1. `git mv references/personas references/agents` in ts-code-review
  2. `git mv persona-catalog.md agent-catalog.md` in ts-code-review/references
  3. Add frontmatter to each of the 14 agent files. Each file gets: `name` (derived from filename), `description` (from the file's existing first paragraph or domain definition), `tools: Read, Grep, Glob` (code reviewers are read-only), `effort: high`
  4. Global find-replace "persona" → "agent" in SKILL.md, subagent-template.md, agent-catalog.md, validator-template.md. Preserve case: "Persona" → "Agent", "personas" → "agents", "PERSONA" → "AGENT"
  5. Update path references: `references/personas/` → `references/agents/` in SKILL.md
  6. Update template variable: `{persona_file}` → `{agent_file}` in subagent-template.md; `{persona}` XML tag → `{agent}`
- **Test scenarios:**
  - Verify `references/personas/` no longer exists
  - Verify `references/agents/` contains all 14 agent files
  - Verify every agent file has valid YAML frontmatter with required fields
  - Verify `SKILL.md` has zero occurrences of "persona" (case-insensitive search)
  - Verify `subagent-template.md` uses `{agent_file}` not `{persona_file}`
  - Verify `agent-catalog.md` exists and uses "agent" terminology
- **Verification:** `grep -ri "persona" skills/ts-code-review/` returns zero results. All 14 agent files have frontmatter.

### U3. Migrate ts-doc-review Personas to Agents

- **Goal:** Rename `references/personas/` to `references/agents/`, move 2 root agents in, ensure all 9 files have conformant frontmatter (add to 7 migrated, verify on 2 moved), update all "persona" references to "agent" throughout the skill.
- **Requirements:** R1a, R1b, R2a, R2b, R4b, R4c
- **Dependencies:** U1
- **Files:**
  - `skills/ts-doc-review/references/personas/` → `skills/ts-doc-review/references/agents/` (rename directory)
  - `skills/ts-doc-review/references/agents/*.md` (7 migrated + 2 moved = 9 files — add frontmatter)
  - `agents/documentation-reviewer.md` → `skills/ts-doc-review/references/agents/documentation-reviewer.md` (move)
  - `agents/test-documentation-reviewer.md` → `skills/ts-doc-review/references/agents/test-documentation-reviewer.md` (move)
  - `skills/ts-doc-review/SKILL.md` (update terminology, paths, Build Agent List)
  - `skills/ts-doc-review/references/subagent-template.md` (rename variables)
  - `skills/ts-doc-review/references/synthesis-and-presentation.md` (update terminology)
  - `skills/ts-doc-review/references/review-output-template.md` (update terminology)
  - `skills/ts-doc-review/references/walkthrough.md` (update terminology if present)
  - `skills/ts-doc-review/references/bulk-preview.md` (update terminology if present)
  - Note: R2b applies to ALL files under `ts-doc-review/references/` that contain "persona" terminology, including `findings-schema.json`, `open-questions-defer.md`
- **Approach:**
  1. `git mv references/personas references/agents` in ts-doc-review
  2. Move `agents/documentation-reviewer.md` and `agents/test-documentation-reviewer.md` into `skills/ts-doc-review/references/agents/`
  3. Add frontmatter to the 7 migrated files. Each gets: `name`, `description`, `tools: Read, Grep, Glob`, `effort: high`. The 2 moved files already have frontmatter — verify conformance with U1's standard.
  4. Global find-replace "persona" → "agent" in SKILL.md, subagent-template.md, synthesis-and-presentation.md, review-output-template.md, walkthrough.md, bulk-preview.md
  5. Update path references: `references/personas/` → `references/agents/`
  6. Update template variable: `{persona_file}` → `{agent_file}`; `{persona}` XML → `{agent}`
  7. Update SKILL.md Build Agent List: add `documentation-reviewer` as always-on, add `test-documentation-reviewer` as conditional
- **Test scenarios:**
  - Verify `references/personas/` no longer exists
  - Verify `references/agents/` contains 9 agent files (7 migrated + 2 moved)
  - Verify every agent file has valid YAML frontmatter
  - Verify `SKILL.md` Build Agent List includes `documentation-reviewer` and `test-documentation-reviewer`
  - Verify `SKILL.md` has zero occurrences of "persona"
  - Verify `subagent-template.md` uses `{agent_file}` not `{persona_file}`
  - Verify `synthesis-and-presentation.md` uses "agent" terminology
- **Verification:** `grep -ri "persona" skills/ts-doc-review/` returns zero results. All 9 agent files have frontmatter. Build Agent List is updated.

### U4. Audit and Update ts-compound, ts-plan, ts-work Agents

- **Goal:** Add frontmatter to all existing agent files in ts-compound (6) and ts-plan (14). Remove `figma-design-sync.md` from ts-work and all references to it.
- **Requirements:** R1a, R1b, R2c, R7c
- **Dependencies:** U1
- **Files:**
  - `skills/ts-compound/references/agents/*.md` (6 files — add frontmatter)
  - `skills/ts-plan/references/agents/*.md` (14 files — add frontmatter)
  - `skills/ts-work/references/agents/figma-design-sync.md` (delete)
  - `skills/ts-work/SKILL.md` (remove figma-design-sync references)
- **Approach:**
  1. Add frontmatter to each agent file. Fields: `name` (from filename), `description` (from first paragraph), `tools` (inferred from content — research agents get `Read, Grep, Glob, WebSearch, WebFetch`; analysis agents get `Read, Grep, Glob`), `effort` (inferred — research agents `medium`, analysis agents `high`)
  2. Delete `figma-design-sync.md`
  3. Search ts-work/SKILL.md for figma-design-sync references and remove them
  4. Search all three skills for any remaining "persona" references and update
- **Test scenarios:**
  - Verify all 6 ts-compound agent files have frontmatter
  - Verify all 14 ts-plan agent files have frontmatter
  - Verify `figma-design-sync.md` no longer exists
  - Verify ts-work/SKILL.md has zero references to figma-design-sync
  - Verify zero "persona" references across all three skills
- **Verification:** All agent files have valid frontmatter. No figma-design-sync references remain.

### U5. Expand ts-verify-implementation Agents

- **Goal:** Extract the 4 inline subagents into separate files with full heading structure. Create a verification-specific subagent template. Update SKILL.md to use the new agent files.
- **Requirements:** R1a, R1b, R5a, R5b, R5c
- **Dependencies:** U1
- **Files:**
  - `skills/ts-verify-implementation/references/agents/correctness-verifier.md` (create)
  - `skills/ts-verify-implementation/references/agents/completeness-verifier.md` (create)
  - `skills/ts-verify-implementation/references/agents/scope-verifier.md` (create)
  - `skills/ts-verify-implementation/references/agents/standards-verifier.md` (create)
  - `skills/ts-verify-implementation/references/subagent-template.md` (create)
  - `skills/ts-verify-implementation/SKILL.md` (update Step 4)
- **Approach:**
  1. Create `references/agents/` directory
  2. Create each agent file with frontmatter (`name`, `description`, `tools: Read, Grep, Glob`, `effort: high`) and full reviewer heading structure adapted for verification:
     - **What You Verify:** domain-specific verification criteria (correctness: logic matches plan; completeness: all plan items present; scope: no unplanned changes; standards: conventions followed)
     - **Confidence Calibration:** adapted from the shared rubric with verification-specific anchors (anchor 100 = plan item clearly missing from diff; anchor 75 = deviation from plan intent; anchor 50 = minor style/convention gap)
     - **What You Don't Flag:** territory boundaries (e.g., correctness-verifier doesn't flag completeness gaps)
     - **Output Format:** structured verdict (PASS / FAIL / PARTIAL) with findings list
  3. Create `references/subagent-template.md` adapted from ts-doc-review's template:
     - Context slots: plan content, git diff, KTD list, re-verification context
     - Output contract: verdict + findings with file/line references
     - Confidence rubric: shared anchored rubric
     - Remove document-review-specific fields (autofix_class, finding_type)
  4. Update SKILL.md Step 4 to reference the new agent files and dispatch pattern
- **Test scenarios:**
  - Verify `references/agents/` contains 4 agent files
  - Verify every agent file has valid YAML frontmatter
  - Verify every agent file has all reviewer-template headings (What You Verify, Confidence Calibration, What You Don't Flag, Output Format)
  - Verify `references/subagent-template.md` exists and defines context slots for plan, diff, and KTDs
  - Verify SKILL.md Step 4 references `references/agents/` paths
  - Verify SKILL.md no longer contains inline subagent definitions
- **Verification:** All 4 agent files conform to the reviewer sub-template. SKILL.md dispatches from `references/agents/` via the new template. The inline definitions are removed.

### U6. Update ts-work Execution Strategy

- **Goal:** Always dispatch subagents (removing inline execution path). Add decision logic for choosing `implementer-general` vs `implementer-tests` per task. Move the 2 implementer agents from root `agents/` into the skill.
- **Requirements:** R4a, R4d, R7a, R7b (includes former U8 scope)
- **Dependencies:** U4 (figma-design-sync removed; frontmatter added to existing agents)
- **Files:**
  - `agents/implementer-general.md` → `skills/ts-work/references/agents/implementer-general.md` (move)
  - `agents/implementer-tests.md` → `skills/ts-work/references/agents/implementer-tests.md` (move)
  - `skills/ts-work/SKILL.md` (update Step 4 execution strategy + add agents to dispatch section)
- **Approach:**
  1. Move both implementer agents into `skills/ts-work/references/agents/`
  2. Update Step 4 "Choose Execution Strategy":
     - Remove the "Inline" strategy row from the strategy table
     - Always dispatch subagents — the decision is serial vs parallel, not inline vs subagent
     - Add a new decision section before the Parallel Safety Check: "Choose Agent Type"
       - If the unit's `Files:` list contains only test files, fixtures, mocks, or test config → use `implementer-tests`
       - Otherwise → use `implementer-general` (this is the default; it covers application code, scripts, production config, infrastructure, and any mixed unit)
       - If the unit has an `Execution note` indicating test-first → dispatch `implementer-tests` first, then `implementer-general`
     - Update subagent dispatch instructions to reference `references/agents/implementer-general.md` or `references/agents/implementer-tests.md` by name
  3. Remove the "Default for bare-prompt work" inline path — bare prompts also dispatch subagents
  4. Add `implementer-general` and `implementer-tests` to the SKILL.md agent dispatch section with references to their `references/agents/` paths
  5. Update subagent dispatch instructions to include the selected agent file content in the subagent prompt and the agent type decision rationale in the dispatch context
  6. Remove any stale references to agent files that no longer exist
- **Test scenarios:**
  - Verify `agents/implementer-general.md` and `agents/implementer-tests.md` no longer exist at repo root
  - Verify both files exist in `skills/ts-work/references/agents/`
  - Verify SKILL.md Step 4 has no "Inline" strategy
  - Verify SKILL.md Step 4 includes an "Choose Agent Type" decision section
  - Verify the decision section describes `implementer-general` vs `implementer-tests` selection criteria
  - Verify SKILL.md references the agent files from `references/agents/`
  - Verify SKILL.md agent dispatch section lists both `implementer-general` and `implementer-tests` with their file paths
  - Verify dispatch payload includes agent file content and agent type decision rationale
  - Verify no stale agent file references remain
- **Verification:** SKILL.md always dispatches subagents. The agent type decision is documented. Both implementer agents are in the correct directory and listed in the dispatch section. Dispatch instructions include agent content in the payload.

### U7. Add ts-pr-fix-findings Orchestration

- **Goal:** Add finding-grouping logic and parallel ts-debug subagent dispatch.
- **Requirements:** R6a, R6b
- **Dependencies:** None (U7 modifies only SKILL.md orchestration logic and does not reference agent files, so it is independent of U1)
- **Files:**
  - `skills/ts-pr-fix-findings/SKILL.md` (update Steps 3 and 5)
- **Approach:**
  1. In Step 3 "Plan the fix for each finding", add a grouping step after fix planning:
     - Group findings by file proximity (same file or closely related files) and concern type (same category of fix)
     - Each group must be independently fixable — no group depends on another group's fix landing first
     - If a finding depends on another finding's fix, merge them into the same group
  2. In Step 5 "Remediate valid findings", replace sequential ts-debug calls with parallel dispatch:
     - Launch one ts-debug subagent per group
     - Each subagent receives: the group's findings, the fix plan for each finding, and the relevant file context
     - Use worktree isolation when available to prevent write conflicts
     - After all subagents complete, consolidate results and proceed to Step 6 verification
- **Test scenarios:**
  - Verify Step 3 includes a grouping instruction
  - Verify the grouping criteria (file proximity, concern type, independence) are defined
  - Verify Step 5 launches parallel ts-debug subagents instead of sequential calls
  - Verify the dispatch instructions include per-group context (findings + fix plans)
  - Verify the post-dispatch consolidation step is documented
- **Verification:** SKILL.md Steps 3 and 5 include the grouping and parallel dispatch logic. An implementer can follow the updated steps without ambiguity.

## Scope Boundaries

### In Scope
- All 7 skills listed in R2: ts-code-review, ts-compound, ts-plan, ts-work, ts-doc-review, ts-verify-implementation, ts-pr-fix-findings
- All persona/agent file migrations and frontmatter additions
- Documentation in `docs/standards/`
- Execution strategy updates in ts-work
- Orchestration updates in ts-pr-fix-findings

### Deferred to Follow-Up Work
- **Cross-skill agent deduplication.** Several agents exist in multiple skills with near-identical content (security-sentinel, best-practices-researcher, data-integrity-guardian, framework-docs-researcher, pattern-recognition-specialist, performance-oracle). Consolidation would require a shared-agent architecture and is a separate effort. Tracked in #83.
- **Dispatch pattern unification.** Two dispatch patterns coexist (template-wrapped and direct-seed). Unifying them is architectural work beyond this standardization. Tracked in #83.
- **ts-brainstorm slack-researcher reference.** `ts-brainstorm/SKILL.md` line 167 references `references/agents/slack-researcher.md` which doesn't exist. This is a pre-existing issue unrelated to the agent standardization.

### Outside Scope
- Changes to the skills' core logic or behavior (only agent definition format changes)
- New agent definitions beyond what's already staged in `agents/`
- Changes to the harness's agent dispatch mechanism

## Risks & Dependencies

- **Risk: Path reference breakage.** Renaming `references/personas/` to `references/agents/` and moving files could break references in SKILL.md, subagent templates, and catalog files. Mitigation: thorough grep for old paths after each migration unit.
- **Risk: Large file count.** 40 files need frontmatter additions, 4 new files need creation with frontmatter, and 21 need directory moves. Mitigation: the work is mechanical and parallelizable across units.
- **Dependency: U1 must complete before U2-U6.** All migration and expansion units reference the standard defined in U1.
- **Dependency: U4 must complete before U6.** The figma-design-sync removal and frontmatter additions happen in U4; U6 builds on the updated agent files.
## Sources & Research

- Root `agents/` files: reference format for frontmatter schema and heading structure
- `skills/ts-doc-review/references/subagent-template.md`: confidence rubric and output contract pattern
- `skills/ts-code-review/references/subagent-template.md`: code-review-specific template pattern
- `docs/solutions/tooling-decisions/ce-skills-extraction.md`: documents the CE extraction that created the personas/agents split
- `docs/solutions/conventions/skill-namespace-prefix-convention.md`: naming convention precedent
- `skills/ts-verify-implementation/SKILL.md` lines 92-103: inline subagent definitions to extract
