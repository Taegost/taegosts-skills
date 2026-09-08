---
tags: [standards, testing, coverage, auto-dispatch, gap-detection]
description: Canonical reference for test coverage expectations, auto-dispatch gates, and coverage-gap detection across all taegosts-skills.
---

# Testing standards — coverage expectations, auto-dispatch, and gap detection

## Core principle

If a script exists and was changed, it needs a corresponding test file. No line threshold.

## Coverage expectations

- Every script file (`.sh`, `.py`, `.js`, `.ts`, `.rb`, `.go`, etc.) in `scripts/` should have a corresponding test in `tests/scripts/`.
- Test files follow the naming convention: `test-<script-name>.sh` (shell scripts) or `test_<script_name>.py` (Python scripts).
- Bash test suites (`.sh`) use `ok()`/`die()` helpers for pass/fail reporting.
- Bash test suites (`.sh`) use `tmpdir` with `trap 'rm -rf "$tmpdir"' EXIT` for cleanup.
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

## Test runner

`scripts/run-test-suites.sh` runs every bash and bats suite in one command and exits non-zero if any suite fails. Its scope:

- `tests/scripts/test-*.sh`
- `tests/skills/*/test-*.sh`
- `tests/scripts/*.bats` (bats suites are part of the standard battery, not an add-on)

`tests/baselines/` is excluded: baseline capture is manual tooling describing the repo at a point in time, so including it would turn ordinary drift into a red run on arrival.

## Python test discovery

Every Python test suite is pytest-collectable:

- Named `test_<name>.py` (the underscore naming rule above).
- Defines pytest test functions; standalone `test-*.py` runners are prohibited. `tests/skills/ts-compound/test_detect_overlap.py` — converted from a dash-named standalone runner in Issue #118 — is the precedent.
- No pytest configuration file exists or is needed: bare `pytest tests/` collects all Python tests with zero config.

## Test conventions (bash suites)

| Convention | Description |
|------------|-------------|
| `ok()` helper | Increments pass counter, prints `PASS: <description>` |
| `die()` helper | Increments fail counter, prints `FAIL: <description>` |
| `tmpdir` cleanup | `tmpdir=$(mktemp -d)` + `trap 'rm -rf "$tmpdir"' EXIT` |
| Exit-code assertions | Check `$rc` after running scripts, not just output |
| Negative verification | Test error paths and invalid inputs, not just happy paths |

Pytest test functions are the Python-suite convention: plain `test_*` functions with asserts, discovered by pytest itself (see "Python test discovery"). Negative verification applies to both suite kinds.

## Conformance checklist

A bash test suite (`.sh`) is conformant when:

- [ ] Uses `ok()`/`die()` helpers for pass/fail reporting
- [ ] Uses `tmpdir` with cleanup trap for temporary files
- [ ] Asserts exit codes (not just output)
- [ ] Tests happy path, edge cases, and error paths where applicable
- [ ] Reports results summary at the end

A Python test suite (`.py`) is conformant when:

- [ ] Is named `test_<name>.py` so bare `pytest tests/` collects it
- [ ] Defines pytest test functions (no standalone runners, no module-level execution)
- [ ] Tests happy path, edge cases, and error paths where applicable

## Related

- `scripts/detect-changed-code-files.sh` — detects code changes for auto-dispatch trigger
- `scripts/detect-coverage-gaps.sh` — post-implementation coverage-gap detector
- `scripts/run-test-suites.sh` — aggregate bash + bats suite runner
- `.github/workflows/ci.yml` — runs the full battery (pytest, runner, shellcheck, gates) on push/PR to `main`
- `skills/ts-work/SKILL.md` — auto-dispatch logic
- `skills/ts-verify-implementation/SKILL.md` — coverage-gap verification dimension
- `docs/plans/2026-07-02-002-fix-test-suite-hardening-plan.md` — canonical test patterns
