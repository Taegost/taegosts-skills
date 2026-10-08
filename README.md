# taegosts-skills

A Claude Code plugin providing custom skills for planning, brainstorming, implementation, debugging, code and document review, PR review and remediation, commits, and solution documentation.

## Installation

### Install from within Claude Code

In a Claude Code session, add the marketplace and install the plugin:

```text
/plugin marketplace add Taegost/taegosts-skills
/plugin install taegosts-skills@taegosts-skills
```

Pick an install scope when prompted: user (you, in every project), project (everyone working in this repository), or local (you, in this repository only). The same steps work from a shell without a session: `claude plugin marketplace add Taegost/taegosts-skills`, then `claude plugin install taegosts-skills@taegosts-skills`.

### Install via settings files

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
| `/ts-pr-review` | Reviews a pull request and posts inline findings | `/ts-code-review` (in-repo) |
| `/ts-pr-fix-findings` | Fixes findings from a PR review and updates the PR | `/ts-debug` (included), `/load-plan`, `/ts-verify-implementation` |
| `/ts-verify-implementation` | Verifies a feature branch against its plan | None (self-contained) |
| `/ts-coding-workflow` | Mandatory workflow for all coding tasks — plan, review, doc-review, work | `/ts-plan`, `/ts-doc-review`, `/ts-do-work-loop` |
| `/ts-do-work-loop` | Run ts-work and ts-verify-implementation in a loop until the plan is fully satisfied | `/ts-work`, `/ts-verify-implementation`, `/ts-compound` |
| `/ts-compound-refresh` | Refresh docs/solutions learnings against the current codebase | None (self-contained) |
| `/ts-work` | Plan execution and implementation | None (self-contained) |
| `/ts-plan` | Planning and architecture | None (self-contained) |
| `/ts-doc-review` | Document review with persona lenses | None (self-contained) |
| `/ts-code-review` | Code review with dynamic personas | None (self-contained) |
| `/ts-compound` | Solution documentation capture | None (standalone) |
| `/ts-debug` | Debugging workflow | None (self-contained) |
| `/ts-brainstorm` | Requirements brainstorming | None (self-contained) |
| `/ts-commit` | Commit workflow | None (self-contained) |
| `/ts-commit-push-pr` | Commit + PR creation | None (self-contained) |

```bash
/ts-do-work-loop docs/plans/my-plan.md
```

### Taegost's Skills (Extracted)

These 9 skills were extracted from [EveryInc/compound-engineering-plugin](https://github.com/EveryInc/compound-engineering-plugin) for customization. See [docs/solutions/tooling-decisions/ce-skills-extraction.md](docs/solutions/tooling-decisions/ce-skills-extraction.md) for full context.

| Skill | Old Skill |
|-------|-----------|
| `/ts-work` | `/ce-work` |
| `/ts-plan` | `/ce-plan` |
| `/ts-doc-review` | `/ce-doc-review` |
| `/ts-code-review` | `/ce-code-review` |
| `/ts-compound` | `/ce-compound` |
| `/ts-debug` | `/ce-debug` |
| `/ts-brainstorm` | `/ce-brainstorm` |
| `/ts-commit` | `/ce-commit` |
| `/ts-commit-push-pr` | `/ce-commit-push-pr` |

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

If no argument is provided, lists open PRs and prompts you to pick one.

**What to expect:** The skill gathers the PR state, runs `/ts-code-review`, and posts findings as individual inline review comments grouped by severity. It ends with a summary table and verdict (APPROVE or REQUEST_CHANGES).

### `/ts-pr-fix-findings`

Validates findings from a PR review, fixes valid issues, and updates the PR with remediation notes.

```bash
/ts-pr-fix-findings <link to PR>
/ts-pr-fix-findings PR #1
/ts-pr-fix-findings 1
```

If no argument is provided, lists open PRs and prompts you to pick one. Uses `/ts-debug`.

**What to expect:** The skill reviews all open conversations on the PR, validates each finding, presents proposed actions (fix / decline / needs input) for your approval, then uses `/ts-debug` to implement fixes. When a feature plan is available, it also runs `/ts-verify-implementation` to catch regressions and scope creep. It ends with a summary table and verdict.

### `/ts-verify-implementation`

Verifies a feature branch against its plan by launching parallel review subagents: correctness, completeness, scope, and standards.

```bash
/ts-verify-implementation <plan-filename>
/ts-verify-implementation 2026-06-18-003-feat-migration-to-knap-dir-plan.md
/ts-verify-implementation
```

If no argument is provided, lists available plans in `docs/plans/` and prompts you to pick one. No external plugin dependencies.

**What to expect:** The skill reads the plan, diffs the feature branch against the base branch, and launches subagents in parallel to review for correctness, completeness, scope creep, and standards compliance. It ends with a consolidated summary table and verdict (PASS / PARTIAL / FAIL).

## Dependencies

Some skills depend on other Claude Code plugins:

- **Taegost's Skills skills** — `/ts-pr-fix-findings` uses `/ts-debug`, which is now included in this repo (extracted from EveryInc).
- **ts-code-review** — `/ts-pr-review` dispatches it as the review engine; it is an in-repo skill, not an external plugin.
- **ts-verify-implementation** — `/ts-pr-fix-findings` invokes it as a sub-skill when a feature plan is available, to catch regressions and scope creep after individual finding fixes.

`/ts-verify-implementation` has no external plugin dependencies.

## Contributing

### Prerequisites

This repo uses [pre-commit](https://pre-commit.com/) to run checks automatically before every commit (see `.pre-commit-config.yaml`). Set it up once per clone:

1. **Install the `pre-commit` framework** (one-time, per machine):
   ```bash
   pip install pre-commit
   ```
2. **Activate the git hook** (one-time, per clone):
   ```bash
   pre-commit install
   ```
   Without this step, `.pre-commit-config.yaml` has no effect — the checks below will not run automatically, and skipped checks silently let issues through.
3. **Install [ShellCheck](https://www.shellcheck.net/)** 0.10.0, required by the `shellcheck` hook (blocks any commit that touches a `.sh` file if it has a finding). Package managers serve mismatched versions (Homebrew 0.11.x; apt/Scoop 0.9.0), so the official GitHub release tarball is the install path that matches CI:
   ```bash
   # Linux x86_64 (the variant CI installs; other platform tarballs are on the release page)
   curl -fsSL https://github.com/koalaman/shellcheck/releases/download/v0.10.0/shellcheck-v0.10.0.linux.x86_64.tar.xz -o /tmp/shellcheck.tar.xz
   echo "6c881ab0698e4e6ea235245f22832860544f17ba386442fe7e9d629f8cbedf87  /tmp/shellcheck.tar.xz" | sha256sum -c -
   tar -xJf /tmp/shellcheck.tar.xz -C /tmp
   sudo mv /tmp/shellcheck-v0.10.0/shellcheck /usr/local/bin/shellcheck
   ```
   Verify with `shellcheck --version`. See `scripts/run-shellcheck.sh --help` for how it's invoked, and `.shellcheckrc` for project-specific configuration.
4. **Install [pytest](https://pytest.org) and [bats](https://bats-core.readthedocs.io/)** to run the test suite (`pytest tests/` and `scripts/run-test-suites.sh`):
   ```bash
   pip install pytest==9.1.0

   # Requires Node.js/npm
   npm install -g bats@1.13.0
   ```

Pinned tool versions are the same ones CI runs; `.github/workflows/ci.yml` is the canonical version record.

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
│   └── marketplace.json       # Marketplace manifest
├── .github/
│   └── workflows/
│       └── ci.yml             # CI: shellcheck + test suites
├── docs/
│   ├── brainstorms/           # Requirements and idea exploration
│   ├── plans/                 # Implementation plans with status tracking
│   ├── pull_requests/         # PR review artifacts and fix plans
│   ├── standards/             # Enforced standards (agents, scripts, indexes, links, testing)
│   ├── solutions/             # Documented solutions by category
│   │   ├── conventions/
│   │   ├── documentation-gaps/
│   │   ├── tooling-decisions/
│   │   ├── workflow-issues/
│   │   ├── behavioral-ktd-verification.md
│   │   ├── ktd-normalization-policy.md
│   │   └── INDEX.md
│   ├── INDEX.md
│   └── ROUTING.md             # Central documentation navigation hub
├── resources/                 # Documentation-review working files
├── scripts/                   # 30+ repo-level scripts + shared lib/ (see scripts/INDEX.md)
├── skills/                    # One directory per skill, each holding a SKILL.md
│   ├── load-plan/
│   ├── ts-brainstorm/
│   ├── ts-code-review/
│   ├── ts-coding-workflow/
│   ├── ts-commit/
│   ├── ts-commit-push-pr/
│   ├── ts-compound/
│   ├── ts-compound-refresh/
│   ├── ts-debug/
│   ├── ts-doc-review/
│   ├── ts-do-work-loop/
│   ├── ts-plan/
│   ├── ts-pr-fix-findings/
│   ├── ts-pr-review/
│   ├── ts-verify-implementation/
│   └── ts-work/
├── tests/                     # pytest + bats suites (baselines/, scripts/, skills/)
├── .gitignore
├── .pre-commit-config.yaml    # Pre-commit hook configuration
├── .shellcheckrc              # ShellCheck project configuration
├── CLAUDE.md                  # Repository instructions for Claude Code
├── CONCEPTS.md                # Shared domain vocabulary
├── LICENSE
├── README.md
└── STRATEGY.md
```

- **`.claude-plugin/marketplace.json`** — The marketplace manifest. It registers this repository as a marketplace and lists the plugin (`taegosts-skills`, `source: "./"`). Claude Code discovers skills from the plugin root's `skills/` directory, not from this file's contents.
- **`skills/<name>/SKILL.md`** — Each skill is a directory containing a `SKILL.md` with frontmatter (`name`, `description`, `user_invocable: true`) and the skill instructions.
- **`docs/`** — Planning and knowledge capture. Claude Code doesn't consume these files itself at runtime, but skills may read them (e.g., `/ts-verify-implementation` reads `docs/solutions/behavioral-ktd-verification.md`; `scripts/solutions-search.sh` queries `docs/solutions/`).
