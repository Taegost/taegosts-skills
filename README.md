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
| `/pr-fix-findings` | Fixes findings from a PR review and updates the PR | Compound Engineering plugin (`/ce-debug`) |
| `/verify-implementation` | Verifies a feature branch against its plan | None (self-contained) |

## Dependencies

Some skills depend on other Claude Code plugins:

- **Compound Engineering plugin** — required by `/pr-fix-findings` (provides `/ce-debug`). Install from [EveryInc/compound-engineering-plugin](https://github.com/EveryInc/compound-engineering-plugin).
- **code-review plugin** — required by `/pr-review` (provides `/code-review`). Install from claude-plugins-official marketplace.

`/verify-implementation` has no external plugin dependencies.
