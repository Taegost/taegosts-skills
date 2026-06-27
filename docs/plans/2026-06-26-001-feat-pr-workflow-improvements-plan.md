# Plan: PR Workflow Improvements (#13, #7, #10)

## Issues Addressed

- **#13**: Persistent clone with auto-sync script
- **#7**: Accept `owner/repo` argument in pr-fix-findings skill
- **#10**: Use Kanban board as working memory during PR fixes

## Scope

All changes are within the `taegosts-skills` repository. No external dependencies.

## Implementation Units

### U1: sync-taegosts-skills.sh (Issue #13)

**Goal:** A script that maintains a persistent clone and syncs installed skills/scripts/tests.

**Files:**
- `scripts/sync-taegosts-skills.sh` (new)

**Approach:**
1. Clone to `$HERMES_HOME/taegosts-skills/` if not present (persistent, not `/tmp`)
2. Fetch + checkout `main` from `origin` (Taegost/taegosts-skills)
3. Sync skills/ to `$HERMES_HOME/skills/`
4. Sync scripts/ to `$HERMES_HOME/skills/scripts/`
5. Sync tests/ to `$HERMES_HOME/skills/tests/`
6. Report what changed (or "already up to date")
7. Idempotent — safe to run multiple times

### U2: pr-fix-findings repo context (Issue #7)

**Goal:** Eliminate repo discovery guessing.

**Files:**
- `skills/pr-fix-findings/SKILL.md` (modify)

**Approach:**
1. Update usage section to document `owner/repo` argument
2. Add Step 0: determine repo context
3. Remove guidance that suggests listing repos or guessing

### U3: Kanban integration (Issue #10)

**Goal:** Use Kanban board as persistent working memory during PR fixes.

**Files:**
- `skills/pr-fix-findings/SKILL.md` (modify)

**Approach:**
1. Add Step 2c: Create Kanban board and cards per finding
2. Update remediation steps to move cards through status lifecycle
3. Add resume guidance for session recovery
