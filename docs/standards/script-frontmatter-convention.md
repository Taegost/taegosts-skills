# Script Frontmatter Convention

Canonical reference for the description comment format used in all shell scripts across the repository.

## Format

Every `.sh` file in `scripts/` and `skills/*/scripts/` must include a description comment on **line 2**, immediately after the shebang line:

```bash
#!/usr/bin/env bash
# <script-name> -- <1-3 sentence description of when to use this script>
```

### Rules

| Rule | Detail |
|------|--------|
| **Separator** | Use ` -- ` (space, double-dash, space) between the script name and description. Never use `:`, `—`, or `-`. |
| **Name** | The script filename without the path (e.g., `git-context.sh`, not `scripts/git-context.sh`). |
| **Description** | 1-3 sentences describing the script's purpose and when to invoke it. |
| **Placement** | Line 2, immediately after the shebang. Before `set -euo pipefail` or any other code. |
| **Case** | Description starts with a verb in imperative or gerund form (e.g., "Detect...", "Generate...", "Search..."). |

### Example

```bash
#!/usr/bin/env bash
# classify-document.sh -- Detect document type from content signals
#
# Input: Document path
# Output: JSON with type, signals, confidence
# Exit codes: 0 success, 1 error

set -euo pipefail
```

## Test Scripts (Excluded)

Scripts under `tests/` use a different convention and are **not** covered by this standard:

```bash
#!/usr/bin/env bash
# Test: <description of what the test validates>
```

## Scope

This convention applies to:

- All `.sh` files in `scripts/`
- All `.sh` files in `skills/*/scripts/`

It does **not** apply to:

- Test scripts under `tests/`
- Non-shell scripts (`.py`, `.js`, etc.)

## Migration Notes

- Scripts previously prefixed with `# U<id>:` have been normalized to this format. The U-number was a plan-specific artifact and does not belong in the standard format.
- Scripts using em-dash (`—`) separators have been normalized to ` -- `.
- Scripts with no frontmatter have had the description comment added on line 2.
