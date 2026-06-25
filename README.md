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
| `/pr-review` | Reviews a pull request and posts inline findings | `code-review` plugin (claude-plugins-official) |
| `/pr-fix-findings` | Fixes findings from a PR review and updates the PR | `/ce-debug` (included) |
| `/verify-implementation` | Verifies a feature branch against its plan | None (self-contained) |

### Compound Engineering Skills (Extracted)

These 9 skills were extracted from [EveryInc/compound-engineering-plugin](https://github.com/EveryInc/compound-engineering-plugin) for customization. See [docs/solutions/tooling-decisions/ce-skills-extraction.md](docs/solutions/tooling-decisions/ce-skills-extraction.md) for full context.

| Skill | Description | Dependencies |
|-------|-------------|-------------|
| `/ce-work` | Plan execution and implementation | ce-plan, ce-debug |
| `/ce-plan` | Planning and architecture | ce-brainstorm |
| `/ce-doc-review` | Document review with persona lenses | None |
| `/ce-code-review` | Code review with dynamic personas | None |
| `/ce-compound` | Solution documentation capture | None (standalone) |
| `/ce-debug` | Debugging workflow | None |
| `/ce-brainstorm` | Requirements brainstorming | None |
| `/ce-commit` | Commit workflow | None |
| `/ce-commit-push-pr` | Commit + PR creation | None |

## Usage

### `/pr-review`

Reviews a pull request, posts inline findings as threaded comments, and reports a severity-ranked summary.

```bash
/pr-review <link to PR>
/pr-review PR #1
/pr-review 1
```

If no argument is provided, lists open PRs and prompts you to pick one. Requires the `code-review` plugin to be installed.

**What to expect:** The skill gathers the PR state, runs `/code-review`, and posts findings as individual inline review comments grouped by severity. It ends with a summary table and verdict (APPROVE or REQUEST_CHANGES).

### `/pr-fix-findings`

Validates findings from a PR review, fixes valid issues, and updates the PR with remediation notes.

```bash
/pr-fix-findings <link to PR>
/pr-fix-findings PR #1
/pr-fix-findings 1
```

If no argument is provided, lists open PRs and prompts you to pick one. Uses `/ce-debug` (now included in this repo).

**What to expect:** The skill reviews all open conversations on the PR, validates each finding, presents proposed actions (fix / decline / needs input) for your approval, then uses `/ce-debug` to implement fixes. It ends with a summary table and verdict.

### `/verify-implementation`

Verifies a feature branch against its plan by launching 4 parallel review subagents: correctness, completeness, scope, and standards.

```bash
/verify-implementation <plan-filename>
/verify-implementation 2026-06-18-003-feat-migration-to-knap-dir-plan.md
/verify-implementation
```

If no argument is provided, lists available plans in `docs/plans/` and prompts you to pick one. No external plugin dependencies.

**What to expect:** The skill reads the plan, diffs the feature branch against the base branch, and launches 4 subagents in parallel to review for correctness, completeness, scope creep, and standards compliance. It ends with a consolidated summary table and verdict (PASS / PARTIAL / FAIL).

## Dependencies

Some skills depend on other Claude Code plugins:

- **Compound Engineering skills** — `/pr-fix-findings` uses `/ce-debug`, which is now included in this repo (extracted from EveryInc).
- **code-review plugin** — required by `/pr-review` (provides `/code-review`). Install from claude-plugins-official marketplace.

`/verify-implementation` has no external plugin dependencies.

## Contributing

### Fix an existing skill

1. Fork the repo and create a feature branch.
2. Edit `skills/<skill-name>/SKILL.md` with your changes.
3. Reload the plugin to test: run `/reload-plugins` in Claude Code, then invoke the skill to verify.
4. Commit with a conventional message (e.g., `fix: correct severity ordering in pr-review`), push, and open a PR.

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
│   ├── pr-review/
│   │   └── SKILL.md
│   ├── pr-fix-findings/
│   │   └── SKILL.md
│   ├── verify-implementation/
│   │   └── SKILL.md
│   ├── ce-work/
│   │   └── SKILL.md          # Plan execution
│   ├── ce-plan/
│   │   └── SKILL.md          # Planning and architecture
│   ├── ce-doc-review/
│   │   └── SKILL.md          # Document review
│   ├── ce-code-review/
│   │   └── SKILL.md          # Code review
│   ├── ce-compound/
│   │   └── SKILL.md          # Solution capture
│   ├── ce-debug/
│   │   └── SKILL.md          # Debugging workflow
│   ├── ce-brainstorm/
│   │   └── SKILL.md          # Requirements brainstorming
│   ├── ce-commit/
│   │   └── SKILL.md          # Commit workflow
│   └── ce-commit-push-pr/
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
