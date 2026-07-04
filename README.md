# taegosts-skills

A Claude Code plugin containing custom skills for PR review, PR fix, and implementation verification.

## Installation

Add this repository to your Claude Code settings under `extraKnownMarketplaces`:

```json
{
  "extraKnownMarketplaces": {
    "taegosts-skills": {
      "source": {
        "source": "git",
        "url": "https://github.com/Taegost/taegosts-skills.git"
      },
      "autoUpdate": true
    }
  }
}
```

Then enable the plugin in `enabledPlugins`:

```json
{
  "enabledPlugins": {
    "taegosts-skills@taegosts-skills": true
  }
}
```

## Skills

| Skill | Description | Dependencies |
|-------|-------------|-------------|
| `/load-plan` | Loads a plan document for skill execution. Auto-discovers plans from branch names, PR bodies, or explicit paths. | None (self-contained) |
| `/ts-pr-review` | Reviews a pull request and posts inline findings | `code-review` plugin (claude-plugins-official) |
| `/ts-pr-fix-findings` | Fixes findings from a PR review and updates the PR | `/ts-debug` (included), `/load-plan`, `/ts-verify-implementation` |
| `/ts-verify-implementation` | Verifies a feature branch against its plan | None (self-contained) |
| `/ts-coding-workflow` | Mandatory workflow for all coding tasks — plan, review, doc-review, work | `/ts-plan`, `/ts-doc-review`, `/ts-do-work-loop` |
| `/ts-do-work-loop` | Run ts-work and ts-verify-implementation in a loop until the plan is fully satisfied | `/ts-work`, `/ts-verify-implementation`, `/ts-compound` |


The central implementation loop. Runs ts-work and ts-verify-implementation in cycles until verification passes. Most plans require multiple passes — a single ts-work run typically misses things.

```bash
/ts-do-work-loop docs/plans/my-plan.md
```

### Taegost's Skills (Extracted)

These 9 skills were extracted from [EveryInc/compound-engineering-plugin](https://github.com/EveryInc/compound-engineering-plugin) for customization. See [docs/solutions/tooling-decisions/ce-skills-extraction.md](docs/solutions/tooling-decisions/ce-skills-extraction.md) for full context.

| Skill | Description | Dependencies |
|-------|-------------|-------------|
| `/ts-work` | Plan execution and implementation | ts-plan, ts-debug |
| `/ts-plan` | Planning and architecture | ts-brainstorm |
| `/ts-doc-review` | Document review with persona lenses | None |
| `/ts-code-review` | Code review with dynamic personas | None |
| `/ts-compound` | Solution documentation capture | None (standalone) |
| `/ts-debug` | Debugging workflow | None |
| `/ts-brainstorm` | Requirements brainstorming | None |
| `/ts-commit` | Commit workflow | None |
| `/ts-commit-push-pr` | Commit + PR creation | None |

### Documented Solutions

`docs/solutions/` — documented solutions to past problems (bugs, best practices, workflow patterns), organized by category with YAML frontmatter (`module`, `tags`, `problem_type`). Relevant when implementing or debugging in documented areas.

`CONCEPTS.md` — shared domain vocabulary (entities, named processes, status concepts) with project-specific meaning. Relevant when orienting to the codebase or discussing domain concepts.

## Usage

### `/ts-pr-review`

Reviews a pull request, posts inline findings as threaded comments, and reports a severity-ranked summary.

```bash
/ts-pr-review <link to PR>
/ts-pr-review PR #1
/ts-pr-review 1
```

If no argument is provided, lists open PRs and prompts you to pick one. Requires the `code-review` plugin to be installed.

**What to expect:** The skill gathers the PR state, runs `/code-review`, and posts findings as individual inline review comments grouped by severity. It ends with a summary table and verdict (APPROVE or REQUEST_CHANGES).

### `/ts-pr-fix-findings`

Validates findings from a PR review, fixes valid issues, and updates the PR with remediation notes.

```bash
/ts-pr-fix-findings <link to PR>
/ts-pr-fix-findings PR #1
/ts-pr-fix-findings 1
```

If no argument is provided, lists open PRs and prompts you to pick one. Uses `/ts-debug` (now included in this repo).

**What to expect:** The skill reviews all open conversations on the PR, validates each finding, presents proposed actions (fix / decline / needs input) for your approval, then uses `/ts-debug` to implement fixes. When a feature plan is available, it also runs `/ts-verify-implementation` to catch regressions and scope creep. It ends with a summary table and verdict.

### `/ts-verify-implementation`

Verifies a feature branch against its plan by launching 4 parallel review subagents: correctness, completeness, scope, and standards.

```bash
/ts-verify-implementation <plan-filename>
/ts-verify-implementation 2026-06-18-003-feat-migration-to-knap-dir-plan.md
/ts-verify-implementation
```

If no argument is provided, lists available plans in `docs/plans/` and prompts you to pick one. No external plugin dependencies.

**What to expect:** The skill reads the plan, diffs the feature branch against the base branch, and launches 4 subagents in parallel to review for correctness, completeness, scope creep, and standards compliance. It ends with a consolidated summary table and verdict (PASS / PARTIAL / FAIL).

## Dependencies

Some skills depend on other Claude Code plugins:

- **Taegost's Skills skills** — `/ts-pr-fix-findings` uses `/ts-debug`, which is now included in this repo (extracted from EveryInc).
- **code-review plugin** — required by `/ts-pr-review` (provides `/code-review`). Install from claude-plugins-official marketplace.
- `/ts-pr-fix-findings` invokes `/ts-verify-implementation` as a sub-skill when a feature plan is available, to catch regressions and scope creep after individual finding fixes.

`/ts-verify-implementation` has no external plugin dependencies.

## Contributing

### Fix an existing skill

1. Fork the repo and create a feature branch.
2. Edit `skills/<skill-name>/SKILL.md` with your changes.
3. Reload the plugin to test: run `/reload-plugins` in Claude Code, then invoke the skill to verify.
4. Commit with a conventional message (e.g., `fix: correct severity ordering in ts-pr-review`), push, and open a PR.

### Add a new skill

1. Fork the repo and create a feature branch.
2. Create `skills/<skill-name>/SKILL.md` with the required frontmatter:
   ```yaml
   ---
   name: <skill-name>        # must match the directory name
   description: "<one-line description>"
   user_invocable: true
   ---
   ```
   The rest of the file is the skill definition — write the instructions Claude Code will follow when the skill is invoked.
3. Reload the plugin to test: run `/reload-plugins` in Claude Code, then invoke the skill with `/<skill-name>`.
4. Commit with a conventional message (e.g., `feat: add <skill-name> skill`), push, and open a PR.

### Guidelines

- Keep skills focused on a single task.
- Each skill should fail gracefully if its dependencies are missing (check and alert the user).
- Use conventional commit messages: `feat:` for new skills, `fix:` for corrections, `docs:` for documentation changes.

## Repository Structure

```
taegosts-skills/
├── .claude-plugin/
│   └── marketplace.json      # Plugin manifest
├── skills/
│   ├── ts-pr-review/
│   │   └── SKILL.md
│   ├── ts-pr-fix-findings/
│   │   └── SKILL.md
│   ├── ts-verify-implementation/
│   │   └── SKILL.md
│   ├── ts-work/
│   │   └── SKILL.md          # Plan execution
│   ├── ts-do-work-loop/
│   │   └── SKILL.md          # Work loop
│   ├── ts-coding-workflow/
│   │   └── SKILL.md          # Coding workflow
│   ├── ts-plan/
│   │   └── SKILL.md          # Planning and architecture
│   ├── ts-doc-review/
│   │   └── SKILL.md          # Document review
│   ├── ts-code-review/
│   │   └── SKILL.md          # Code review
│   ├── ts-compound/
│   │   └── SKILL.md          # Solution capture
│   ├── ts-debug/
│   │   └── SKILL.md          # Debugging workflow
│   ├── ts-brainstorm/
│   │   └── SKILL.md          # Requirements brainstorming
│   ├── ts-commit/
│   │   └── SKILL.md          # Commit workflow
│   └── ts-commit-push-pr/
│       └── SKILL.md          # Commit + PR creation
├── docs/
│   ├── brainstorms/           # Requirements and idea exploration
│   ├── plans/                 # Implementation plans with status tracking
│   └── solutions/
│       └── tooling-decisions/ # Captured learnings and technical decisions
├── README.md
├── STRATEGY.md
└── LICENSE
```

- **`.claude-plugin/marketplace.json`** — The plugin manifest. Claude Code reads this to discover skills in the repo.
- **`skills/<name>/SKILL.md`** — Each skill is a directory containing a `SKILL.md` with frontmatter (`name`, `description`, `user_invocable: true`) and the skill instructions.
- **`docs/`** — Planning and knowledge capture. Not consumed by Claude Code at runtime.
