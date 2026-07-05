---
title: "Wave 3: Enhancements + Investigations"
type: feat
date: 2026-07-05
origin: "GitHub Issue #95"
status: draft
---

# Wave 3: Enhancements + Investigations

## Summary

Feature enhancements and research tasks that build on the consolidated script and agent foundation from Waves 1-2. All items in this wave are independent and can be worked in parallel.

## Scope Boundaries

- This plan covers issues #77, #78, #76, #85, and #90
- #90 (ce-compound-refresh) has no description body and the Compound Engineering repo is not accessible — scope cannot be defined until the user clarifies requirements
- #85 is research/investigation, not code changes — it may produce a follow-up implementation issue
- No changes to the agent frontmatter schema (that was Wave 2 #74)

## Implementation Units

### U1: Improve ts-work sub-agent dispatch (#77)

**Goal:** Expand ts-work's agent dispatch to utilize the full set of agent profiles standardized in #74, and refine the parallel/serial decision logic.

**Files:**
- Modify: `skills/ts-work/SKILL.md`
- Read: `skills/ts-work/references/agents/implementer-general.md`
- Read: `skills/ts-work/references/agents/implementer-tests.md`

**Approach:**

1. Review the current "Choose Agent Type" decision logic in ts-work Phase 1 step 4
2. The current logic routes to `implementer-general` (default) or `implementer-tests` (test-only files). Expand to consider additional routing signals:
   - Documentation-only units → route to a documentation-focused agent (if one exists)
   - Script/shell units → consider whether implementer-general is appropriate or if a specialized agent is needed
3. Review the "Always dispatch subagents" directive — ensure bare-prompt routing also constructs proper unit context for the dispatched agent
4. Verify the Parallel Safety Check logic is correct and well-documented

**Test Scenarios:**
- Bare prompt with trivial task → dispatches subagent with constructed context
- Plan with mixed test + source files → dispatches implementer-general (not implementer-tests)
- Plan with test-only files → dispatches implementer-tests
- Plan with overlapping files → serial dispatch with logged reason

**Execution note:** Characterization-first — read the current dispatch logic thoroughly before modifying.

---

### U2: Improve ts-pr-fix-findings summary (#78)

**Goal:** Include the planned fix description in the remediation summary table, not just the word "fix".

**Files:**
- Modify: `skills/ts-pr-fix-findings/SKILL.md`

**Approach:**

1. In Step 9 (Display a summary to the user), the current table has columns: `# | Severity | File | Remediation`
2. Change the Remediation column to include the actual planned fix description from Step 3
3. Also update the Kanban card body (Step 2c) to include the fix description in a structured way
4. Ensure the summary table renders concisely — truncate long fix descriptions to ~80 chars with ellipsis

**Test Scenarios:**
- Single finding with a clear fix → summary shows the fix description
- Multiple findings → each row shows its specific fix, not a generic "fix"
- Finding declined → shows "Declined" or the decline reason
- Finding needs-input → shows "Needs input"

---

### U3: Write ts-doc-review decisions to disk immediately (#76)

**Goal:** Ensure each walk-through decision is persisted to disk after every turn, preventing data loss when the context window fills up.

**Files:**
- Modify: `skills/ts-doc-review/references/walkthrough.md`
- Read: `skills/ts-doc-review/references/open-questions-defer.md`

**Approach:**

The current flow accumulates all Apply decisions in an in-memory Apply set and batches them at end-of-walk-through (line 221 of walkthrough.md: "Nothing is written to disk per-decision except the in-doc Open Questions appends"). If the session compacts or the context window fills, Apply decisions are lost.

1. After each per-finding decision, write the decision to a session artifact file (e.g., a JSON or markdown file tracking decisions)
2. The artifact should record: finding id, action (Apply/Defer/Skip/Acknowledge), timestamp, and any metadata
3. Defer decisions already write to disk (Open Questions section) — no change needed
4. Apply decisions should also write the `suggested_fix` to the artifact immediately, so a resumed session can re-apply
5. On end-of-walk-through, the batch execution reads from the artifact rather than relying on in-memory state
6. This also enables session recovery: if the walk-through is interrupted, the next session can read the artifact and resume

**Test Scenarios:**
- Walk-through with 5 findings, session compacts after finding 3 → decisions 1-3 are on disk
- Walk-through completes normally → artifact is consumed and cleaned up
- Session recovery → artifact is loaded and walk-through resumes from correct position

**Key Technical Decisions:**

- KTD1: Decision artifact format — use JSON with a schema-defined structure (finding_id, action, suggested_fix, timestamp, metadata)
- KTD2: Artifact location — write to a temp file in the working directory, not in the document itself
- KTD3: Cleanup — artifact is deleted after successful end-of-walk-through execution

---

### U4: Investigate behavioral test patterns for skill dispatch (#85)

**Goal:** Determine whether behavioral tests for skill dispatch logic are feasible, and if so, define the test pattern.

**Files:**
- Read: `skills/ts-work/SKILL.md` (dispatch logic)
- Create: `docs/brainstorms/` or `docs/solutions/` (research output)

**Approach:**

This is a research task, not a code change. The output is a documented finding, not implementation.

1. **Question 1: Can we write deterministic tests for skill dispatch logic?**
   - Analyze the "Choose Agent Type" decision logic in ts-work
   - Identify the decision signals (file types, execution notes, complexity assessment)
   - Determine if these signals can be constructed as test fixtures
   - Consider: skills are Claude Code plugin definitions, not traditional code — the "dispatch" is prompt routing, not function calls

2. **Question 2: Should ts-verify-implementation validate dispatch behavior?**
   - Review ts-verify-implementation's scope and agent definitions
   - Determine if dispatch validation fits within its verification mandate

3. **Question 3: Do we need a new test harness?**
   - Evaluate existing test patterns in `tests/`
   - Consider: can we test dispatch decisions by running the skill with known inputs and checking the output?
   - Consider: is a mock/stub approach feasible for skill-level testing?

4. Document findings in a solution doc or brainstorm
5. If a pattern is feasible, define it with examples
6. If not feasible, document why and suggest alternative validation approaches

**Verification:** Research doc exists with clear conclusions for all three questions.

---

### U5: Pull in ce-compound-refresh from Compound Engineering (#90)

**Goal:** Pull `ce-compound-refresh` from EveryInc/compound-engineering-plugin, rename to `ts-compound-refresh`, apply taegosts-skills standards, and ensure all references are correct.

**Source:** `https://github.com/EveryInc/compound-engineering-plugin/tree/main/skills/ce-compound-refresh`

**Files to create:**
- Create: `skills/ts-compound-refresh/SKILL.md` (from upstream, with renames)
- Create: `skills/ts-compound-refresh/references/per-action-flows.md` (NEW — not in ts-compound)

**Files that already exist (shared with ts-compound):**
- `references/concepts-vocabulary.md` — already in `skills/ts-compound/references/`
- `references/schema.yaml` — already in `skills/ts-compound/references/`
- `references/yaml-schema.md` — already in `skills/ts-compound/references/`
- `scripts/validate-frontmatter.py` — already in `skills/ts-compound/scripts/`
- `assets/resolution-template.md` — already in `skills/ts-compound/assets/`

**Approach:**

1. **Inventory and diff.** Compare upstream reference files against existing ts-compound references to determine if they diverge. If identical, reuse the existing files via symlinks or copies. If diverged, evaluate which version is correct.

2. **Create skill directory structure:**
   ```
   skills/ts-compound-refresh/
   ├── SKILL.md
   ├── references/
   │   ├── per-action-flows.md   (NEW)
   │   ├── concepts-vocabulary.md (copy or symlink from ts-compound)
   │   ├── schema.yaml           (copy or symlink from ts-compound)
   │   └── yaml-schema.md        (copy or symlink from ts-compound)
   ├── scripts/
   │   └── validate-frontmatter.py (copy or symlink from ts-compound)
   └── assets/
       └── resolution-template.md  (copy or symlink from ts-compound)
   ```

3. **Rename in SKILL.md.** All `ce-*` references → `ts-*`:
   - `ce-compound` → `ts-compound`
   - `ce-compound-refresh` → `ts-compound-refresh`
   - `ce-brainstorm` → `ts-brainstorm`
   - `AGENTS.md` → `CLAUDE.md` (this repo uses CLAUDE.md, not AGENTS.md)

4. **Apply taegosts-skills standards:**
   - Add YAML frontmatter with `name`, `description`, `argument-hint`
   - Ensure `user_invocable: true` is set
   - Verify the skill follows the naming convention (`ts-` prefix)

5. **Validate cross-references.** After renaming, grep the entire skill for any remaining `ce-` references and fix them. Also verify that all referenced skills (`ts-compound`, `ts-brainstorm`) actually exist.

6. **Update ts-compound.** The ts-compound skill already references `ts-compound-refresh` by name — verify those references still resolve correctly after the new skill is created.

**Key Technical Decisions:**

- KTD1: Shared references — decide whether to copy or symlink the 5 shared reference files. Copies are safer (no broken symlinks) but create drift risk. Symlinks prevent drift but may break on some platforms. **Recommendation: copies**, with a comment in each file noting the canonical source.
- KTD2: The `per-action-flows.md` reference is the only truly new file. It defines the Keep/Update/Consolidate/Replace/Delete execution flows.

**Test Scenarios:**
- `/ts-compound-refresh` is invocable and discovers docs/solutions/
- All `ce-*` references are renamed to `ts-*`
- No broken cross-references to other skills
- Validate-frontmatter.py works from the new location
- CONCEPTS.md bootstrap path works correctly

**Execution note:** Research-first — diff upstream references against existing ts-compound references before creating files.

---

## Dependencies

```
U1 (ts-work dispatch) ─── no dependencies
U2 (pr-fix-findings summary) ─── no dependencies
U3 (doc-review persistence) ─── no dependencies
U4 (dispatch testing research) ─── no dependencies (may inform U1 follow-up)
U5 (ce-compound-refresh) ─── no dependencies
```

All items are fully parallel. U5 is unblocked now that scope is defined.

## Risks & Dependencies

- **U3 complexity:** Writing decisions to disk mid-walk-through changes the state management model. Need to ensure the artifact format is robust and the cleanup logic is correct.
- **U5 reference drift:** The shared reference files (concepts-vocabulary.md, schema.yaml, yaml-schema.md) may have diverged between upstream and ts-compound. Diff carefully before deciding whether to copy or update.
- **U4 scope creep:** Research tasks can expand — keep focused on the three questions in the issue.

## Verification

- U1: ts-work skill dispatches agents correctly for all test scenarios
- U2: ts-pr-fix-findings summary table shows fix descriptions, not just "fix"
- U3: Walk-through decisions survive context window compaction
- U4: Research doc with clear conclusions for all three questions
- U5: `/ts-compound-refresh` is invocable, all `ce-*` references renamed, no broken cross-references
