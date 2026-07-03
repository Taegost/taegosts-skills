---
name: load-plan
description: "Load a plan document for skill execution. Auto-discovers plans from branch names, PR bodies, or explicit paths."
---

# Load Plan

Load a plan document for skill execution. This skill handles plan discovery and loading, providing a single source of truth for all skills that need plan context.

## Purpose

Many skills need to read a plan document before executing work. This skill centralizes plan discovery logic, ensuring consistent behavior across all consumers.

## Usage

```
/load-plan [path]
/load-plan --non-interactive [path]
```

**Arguments:**
- `path` (optional): Explicit path to a plan file. If provided, this takes precedence over all discovery methods.
- `--non-interactive` (optional): Returns errors instead of prompting the user. Consumers in agent mode MUST use this flag.

## Discovery Sources

Plans are discovered in this priority order:

1. **Explicit path** — If a path is provided as an argument, use it directly.
2. **PR body scanning** — If PR metadata is available (from `gh pr view`), scan the PR body for `docs/plans/*.md` paths.
3. **Branch name extraction** — Calls `scripts/locate-plan.py` to extract keywords from the current branch name and match against plan files in `docs/plans/`.

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
```bash
python3 scripts/locate-plan.py
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
```
/load-plan docs/plans/2026-07-02-004-fix-review-skills-plan-validation-plan.md
```

### Auto-discovery (interactive)
```
/load-plan
```

### Agent mode (non-interactive)
```
/load-plan --non-interactive
```

## Dependencies

- `scripts/locate-plan.py` — Branch name keyword extraction
- `scripts/default-branch.sh` — Base branch detection (used by locate-plan.py)
