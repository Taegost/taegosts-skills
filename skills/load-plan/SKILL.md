---
name: load-plan
description: "Load a plan document for skill execution. Auto-discovers plans from branch names, PR bodies, or explicit paths."
user_invocable: true
---

# Load Plan

Load a plan document for skill execution. This skill handles plan discovery and loading, providing a single source of truth for all skills that need plan context.

## Purpose

Many skills need to read a plan document before executing work. This skill centralizes plan discovery logic, ensuring consistent behavior across all consumers.

## Usage

```bash
/load-plan [plan:]
/load-plan --non-interactive [plan:]
```

**Arguments:**
- `plan:` (optional): Explicit path to a plan file. If provided, this takes precedence over all discovery methods.
- `--non-interactive` (optional): Returns errors instead of prompting the user. Consumers in agent mode MUST use this flag.

## Discovery Sources

Plans are discovered in this priority order:

1. **Explicit path** — If a path is provided as an argument, use it directly.
2. **PR body scanning** — If PR metadata is available (from `gh pr view`), scan the PR body for `docs/plans/*.md` paths.
3. **Branch name extraction** — Calls `${CLAUDE_PLUGIN_ROOT}/scripts/locate-plan.py` to extract keywords from the current branch name and match against plan files in `docs/plans/`.

If all sources return empty:
- **Interactive mode** (default): Prompt the user to provide a path
- **Non-interactive mode** (`--non-interactive`): Return an error to the consumer

## Behavior

### Interactive Mode (default)

1. Attempt discovery using the sources above
2. If a plan is found, load and return its content
3. If multiple plans match (from branch name extraction), ask the user to choose
4. If no plan is found, prompt the user: "No plan found for this branch. Please provide a plan path:"
5. On error (detached HEAD, unreadable file), ask the user what to do

### Non-Interactive Mode (`--non-interactive`)

1. Attempt discovery using the sources above
2. If a plan is found, load and return its content
3. If multiple plans match, return an error listing the candidates
4. If no plan is found, return an error: "No plan found for this branch"
5. On error, return the error message to the consumer

**Consumers in agent mode MUST use `--non-interactive`** and stop with an error if no plan can be found.

## Output

The skill outputs:
1. **Plan path** — The resolved path to the plan file
2. **Plan content** — The full content of the plan file

## Implementation

### Step 1: Try explicit path

If an argument is provided and it's a valid file path:
- Read the file
- Return path + content

### Step 2: Try PR body scanning

If no explicit path, check for PR metadata:
```bash
gh pr view --json body,url,headRefName 2>/dev/null
```

If PR body contains a `docs/plans/*.md` path:
- Extract the path
- Read the file
- Return path + content

### Step 3: Try branch name extraction

If no PR metadata or no plan found in PR body:

**Script resolution.** `${CLAUDE_PLUGIN_ROOT}` is substituted to the plugin's install directory at skill-load time on Claude Code, so plugin-rooted script paths work regardless of the Bash tool's working directory. On platforms where it arrives unsubstituted, resolve shared-tier scripts from the loaded skill directory (`<skill-dir>/../../scripts/`) or from a taegosts-skills checkout. If still unresolvable, say so visibly and use the documented manual fallback — never silently skip.

```bash
if [[ -n "${CLAUDE_PLUGIN_ROOT:-}" && -f "${CLAUDE_PLUGIN_ROOT}/scripts/locate-plan.py" ]]; then
  python3 "${CLAUDE_PLUGIN_ROOT}/scripts/locate-plan.py"
elif [[ -n "${CLAUDE_SKILL_DIR:-}" && -f "${CLAUDE_SKILL_DIR}/../../scripts/locate-plan.py" ]]; then
  python3 "${CLAUDE_SKILL_DIR}/../../scripts/locate-plan.py"
else
  echo "locate-plan.py not resolvable on this platform (checked CLAUDE_PLUGIN_ROOT and <skill-dir>/../../scripts); say so visibly and use the documented manual fallback — never silently skip." >&2
fi
```

If the script returns a path:
- Read the file
- Return path + content

### Step 4: Handle "not found"

**Interactive mode:**
- Prompt the user for a path
- If user provides a path, read and return
- If user cancels, return empty

**Non-interactive mode:**
- Return error: "No plan found for this branch"

### Step 5: Handle ambiguity

If `locate-plan.py` returns multiple matches:
- **Interactive mode:** List candidates, ask user to choose
- **Non-interactive mode:** Return error listing candidates

## Error Handling

| Error | Interactive | Non-Interactive |
|-------|-------------|-----------------|
| No plan found | Prompt user | Return error |
| Multiple matches | Ask user to choose | Return error with candidates |
| File unreadable | Ask user what to do | Return error |
| Detached HEAD | Ask user what to do | Return error |
| No remote | Ask user what to do | Return error |

## Examples

### Explicit path

```bash
/load-plan plan:docs/plans/2026-09-08-002-feat-review-pipeline-token-reduction-plan.md
```

### Auto-discovery (interactive)

```bash
/load-plan
```

### Agent mode (non-interactive)

```bash
/load-plan --non-interactive
```

## Dependencies

- `${CLAUDE_PLUGIN_ROOT}/scripts/locate-plan.py` — Branch name keyword extraction and plan discovery
