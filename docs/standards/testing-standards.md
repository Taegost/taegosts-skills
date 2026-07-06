---
title: "Testing standards — coverage expectations, auto-dispatch, and gap detection"
date: 2026-07-05
category: docs/standards
module: skills/plugin
component: documentation
severity: high
tags:
  - testing
  - coverage
  - auto-dispatch
  - gap-detection
  - standards
---

# Testing standards — coverage expectations, auto-dispatch, and gap detection

## Core principle

If a script exists and was changed, it needs a corresponding test file. No line threshold.

## Coverage expectations

- Every script file (`.sh`, `.py`, `.js`, `.ts`, `.rb`, `.go`, etc.) in `scripts/` should have a corresponding test in `tests/scripts/`.
- Test files follow the naming convention: `test-<script-name>.sh` (shell scripts) or `test_<script_name>.py` (Python scripts).
- Test files use `ok()`/`die()` helpers for pass/fail reporting.
- Test files use `tmpdir` with `trap 'rm -rf "$tmpdir"' EXIT` for cleanup.
- Test files assert exit codes, not just output content.

## Auto-dispatch mechanism

When `ts-work` dispatches `implementer-general` for a unit that modifies code, it evaluates three gates to decide whether to auto-dispatch `implementer-tests`. If any gate passes, `implementer-tests` is dispatched:

1. **Code changed?** — `scripts/detect-changed-code-files.sh` checks if any code-bearing files were modified.
2. **Test scenarios defined?** — Does the unit have a `Test Scenarios:` section with non-manual-only tests?
3. **Test files in unit's Files list?** — Does the unit's `Files:` list contain test files? (This is the existing trigger, preserved as a hard constraint.)

If any gate passes, `implementer-tests` is dispatched to create or update corresponding test files. This closes the blind spot where `implementer-general` doesn't touch tests.

## Coverage-gap detection

`scripts/detect-coverage-gaps.sh` is a post-implementation backstop that runs during `ts-verify-implementation`. It:

1. Discovers changed files autonomously via `git diff --name-only <base_branch>` and `git ls-files --others --exclude-standard`
2. For any changed script file, checks whether a corresponding test file exists in `tests/`
3. Reports gaps as findings (severity: Major)

The detector does not require plans to pre-list test files. It catches gaps regardless of plan quality.

## Test conventions

| Convention | Description |
|------------|-------------|
| `ok()` helper | Increments pass counter, prints `PASS: <description>` |
| `die()` helper | Increments fail counter, prints `FAIL: <description>` |
| `tmpdir` cleanup | `tmpdir=$(mktemp -d)` + `trap 'rm -rf "$tmpdir"' EXIT` |
| Exit-code assertions | Check `$rc` after running scripts, not just output |
| Negative verification | Test error paths and invalid inputs, not just happy paths |

## Conformance checklist

A test file is conformant when:

- [ ] Uses `ok()`/`die()` helpers for pass/fail reporting
- [ ] Uses `tmpdir` with cleanup trap for temporary files
- [ ] Asserts exit codes (not just output)
- [ ] Tests happy path, edge cases, and error paths where applicable
- [ ] Reports results summary at the end

## Related

- `scripts/detect-changed-code-files.sh` — detects code changes for auto-dispatch trigger
- `scripts/detect-coverage-gaps.sh` — post-implementation coverage-gap detector
- `skills/ts-work/SKILL.md` — auto-dispatch logic
- `skills/ts-verify-implementation/SKILL.md` — coverage-gap verification dimension
- `docs/plans/2026-07-02-002-fix-test-suite-hardening-plan.md` — canonical test patterns
