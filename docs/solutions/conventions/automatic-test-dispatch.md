---
title: "Automatic test dispatch — closing the test-coverage blind spot"
date: 2026-07-05
category: docs/solutions/conventions
module: skills/plugin
problem_type: convention
component: documentation
severity: medium
applies_when:
  - Implementing plans that modify code files
  - Dispatching implementer-general and implementer-tests agents
tags:
  - auto-dispatch
  - test-coverage
  - implementer-tests
  - convention
---

# Automatic test dispatch — closing the test-coverage blind spot

## Context

When `ts-work` implements a plan that changes scripts, no tests are created or updated. The `implementer-general` agent explicitly refuses to touch tests. The `implementer-tests` agent only writes tests for scenarios already documented in the plan's `Files:` list. There is no mechanism to detect that a changed script should have tests when the plan didn't list them.

## Guidance

### Auto-dispatch gates

Auto-dispatch fires when any of these conditions are met:

1. **Code changed by implementer-general** — Run `scripts/detect-changed-code-files.sh` which diffs the agent's worktree against the base branch and returns a list of modified code-bearing files (`.sh`, `.py`, `.js`, `.ts`, etc.), filtering out test files and non-script files. If non-empty AND the unit has a `Test Scenarios:` section with non-manual-only tests, dispatch `implementer-tests`.

2. **Test scenarios defined** — Does the unit have a `Test Scenarios:` section with non-manual-only tests? If yes AND code was changed, dispatch `implementer-tests`.

3. **ts-work modifies code-bearing files** — When `ts-work` (via `implementer-general`) modifies any code-bearing files in a unit that has test scenarios, dispatch `implementer-tests` regardless of whether the plan explicitly listed test files.

### Existing trigger preserved

The existing trigger (unit's `Files:` list contains test files → `implementer-tests` dispatched) is preserved as-is. The new gates are evaluated only for units that went through `implementer-general`.

### Test conventions

New test files created by auto-dispatch follow established patterns:

- `ok()`/`die()` helpers for pass/fail reporting
- `tmpdir` with `trap 'rm -rf "$tmpdir"' EXIT` for cleanup
- Exit-code assertions (not just output content)
- Negative verification technique (test error paths)

### Failure handling

If auto-dispatch fails, the orchestrator logs the failure and continues. Auto-dispatch is non-blocking — a failure doesn't prevent the unit from being marked complete.

## Why This Matters

- **Coverage backstop:** Catches the blind spot where plans don't list test files but code was changed
- **Convention consistency:** Auto-dispatched tests follow the same patterns as manually-dispatched ones
- **Non-blocking:** Failure doesn't block implementation

## When to Apply

- Any `ts-work` unit that goes through `implementer-general` and has test scenarios defined
- When `scripts/detect-changed-code-files.sh` returns non-empty (code files were modified)

## Example flow

```text
Unit U3: "Create validator script"
  Files: scripts/validate.py (create)
  Test scenarios: Happy path with valid input, Error path with invalid input

  1. Dispatch implementer-general → creates scripts/validate.py
  2. Run detect-changed-code-files.sh → returns ["scripts/validate.py"]
  3. Check Test Scenarios → non-empty, has non-manual tests
  4. Dispatch implementer-tests → creates tests/test-validate.py
```

## Related

- `scripts/detect-changed-code-files.sh` — code change detector
- `scripts/detect-coverage-gaps.sh` — post-implementation coverage-gap detector
- `docs/standards/testing-standards.md` — testing conventions
- `skills/ts-work/SKILL.md` — dispatch logic
