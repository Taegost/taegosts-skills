---
title: "Compliance gate scope classification and enforcement wiring"
date: 2026-09-08
category: docs/solutions/tooling-decisions
module: repo-tooling
problem_type: tooling_decision
component: tooling
severity: medium
related_components:
  - testing_framework
  - development_workflow
symptoms:
  - "verify-scripts.sh flagged 25 test scripts as non-compliant in dir mode while --all mode skipped tests/ — the two modes disagreed on the same repo"
  - "4 false positives on scripts/lib/ demanded --help and an exec bit from sourced, never-executed first-party libraries"
  - "29 false positives buried the 33 genuine offenders, making the gate's failure output unactionable"
  - "Bare pytest tests/ collected only 24 of 97 Python tests — dash-named suites were silently invisible (false green)"
  - "No CI, no pre-commit wiring, no aggregate runner — every gate and suite ran only when a session remembered to"
root_cause: missing_tooling
resolution_type: tooling_addition
applies_when:
  - Writing or modifying a compliance or lint gate that scans mixed file classes (commands, sourced libraries, tests)
  - Choosing which checks apply to which files in a verification script with multiple invocation modes (--all, directory, single-file)
  - Adding Python test suites and needing bare pytest discovery to work with zero configuration
  - Deciding what enforces repo standards locally (pre-commit) versus in CI
  - Wiring a verification gate into pre-commit and GitHub Actions for the first time
tags:
  - repo-hygiene
  - compliance-gate
  - scope-classification
  - false-positives
  - test-discovery
  - pytest
  - pre-commit
  - github-actions
---

# Compliance gate scope classification and enforcement wiring

## Context

Issue #118 tracked three residuals deliberately left out of PR #116's scope, all centered on `scripts/verify-scripts.sh` (the pre-commit gate for script compliance) and the repo's test machinery:

1. **The gate flagged correct things.** A dir-mode run (`scripts/verify-scripts.sh .`) reported 56 passed / 62 failures, of which 29 were false positives: 25 on `tests/` (test scripts run via `bash`/pytest, never invoked as commands) and 4 on `scripts/lib/` (sourced/imported libraries that are never commands). The gate had no exemption mechanism at all — and its `--all` mode already skipped `tests/` while dir mode did not, so the two modes disagreed about scope.
2. **Python test discovery silently skipped 73 of 97 tests.** No pytest config existed, so the default `test_*.py` collection pattern matched only one file; the three dash-named suites in `tests/scripts/` were invisible to bare `pytest tests/`, and a fourth (`tests/skills/ts-compound/test-detect-overlap.py`) was a standalone runner pytest could never collect under any name. A green-looking pytest run covered a quarter of the Python suite — a false green.
3. **Nothing enforced anything.** No CI existed (`.github/workflows/` was absent), the gate was wired into no hook, and the 40+ bash/bats suites had no runner anywhere. Every gate and suite ran only when a session remembered to.

The two correctness residuals were both symptoms of the enforcement residual: the standards already encoded the right intent (`docs/standards/script-frontmatter-convention.md` had an explicit "Test Scripts (Excluded)" section, `docs/standards/script-extraction-standards.md` defined `scripts/lib/` as first-party code "never invoked directly as commands", `docs/standards/testing-standards.md` already mandated `test_<script_name>.py`) — but no tool implemented any of it.

The remediation work itself surfaced three more learnings: gate compliance defined only by grep is not behavioral compliance (a comment containing `--help` passes the gate), deleting a standards doc in Issue #110 had silently orphaned 8 bats tests and a code path that referenced it, and the gate scanning `.` descended into hidden directories — `.claude/worktrees/` contained live worktrees that duplicated the script fleet 4x in the scan.

All fixes landed and verified green on 2026-09-08: `pytest tests/` collects and passes 101 tests, 46 bash/bats suites pass via the new aggregate runner, the gate reports 58/0 in both `--all` and dir mode, and pre-commit runs all four hooks.

## Guidance

### Classify gate scope at a single choke point, keyed on repo-relative path

When a validation gate has multiple scan modes (`--all`, a directory argument, `--file`), scope policy must live in the per-file check function — not in the code that builds each mode's file list. Filtering a mode's file list means the policy is re-declared per mode and the modes drift apart; that is exactly how `--all` skipped `tests/` for months while dir mode kept flagging test scripts.

The fix centralizes classification in `classify_scope()`, called from `check_file()`, keyed on the file's repo-relative path (`scripts/verify-scripts.sh`):

```bash
# classify_scope <repo-relative-path> -- prints the check class for a file:
#   skip -- under tests/: not command-surface, out of scope entirely
#   lib  -- under scripts/lib/: syntax + control-characters only
#   full -- everything else: all checks
classify_scope() {
  case "$1" in
    tests/*) echo "skip" ;;
    scripts/lib/*) echo "lib" ;;
    *) echo "full" ;;
  esac
}

rel_path() {
  printf '%s\n' "${1#"$REL_BASE"/}"
}

check_file() {
  local f="$1"
  local rel scope
  rel="$(rel_path "$f")"
  scope="$(classify_scope "$rel")"
  if [[ "$scope" == "skip" ]]; then
    skipped_scope=$((skipped_scope + 1))
    return 0
  fi
  ...
}
```

Every mode shares this one choke point; the only per-mode code left is computing `REL_BASE` — the root the paths are classified and reported against. Inside the repo it is the repo root. For `--file` targets outside the repo (e.g. a test fixture tree), the tree root is inferred from the `tests/` or `scripts/lib/` path segment so the same repo-relative prefixes classify:

```bash
case "$target" in
  "$REPO_ROOT"/*) REL_BASE="$REPO_ROOT" ;;
  # Outside the repo there is no repo root to strip. Infer the tree root
  # from a tests/ or scripts/lib/ path segment when present, so a file
  # passed by path still classifies on the same repo-relative prefixes
  # (tests/ first: out of scope trumps the lib tier).
  *"/tests/"*) REL_BASE="${target%%"/tests/"*}" ;;
  *"/scripts/lib/"*) REL_BASE="${target%%"/scripts/lib/"*}" ;;
  *) REL_BASE="$(dirname "$target")" ;;
esac
```

Two companion rules fell out of the same change:

- **Report failures by repo-relative path, not basename.** Two `validate-frontmatter.py` copies exist in different skills; basename-only failure output is ambiguous. The fixture test asserts the failing twin is reported as `FAIL: scripts/beta/dup.sh: missing --help flag` and the compliant twin `scripts/alpha/dup.sh` is not flagged at all.
- **Exempt by check class, not by wholesale skipping.** `tests/` files are out of scope (skipped, counted in a skip summary, never counted as passed). `scripts/lib/` files keep the cheap checks — syntax (`bash -n` / `python3 -m py_compile`) and the control-character scan — and drop only the command checks (`--help` presence, exec bit). A library is never a command, so command checks are wrong by design; but a syntax-broken library breaks every importer, so the cheap checks stay:

```bash
  # Command-surface checks: --help and the executable bit apply to command
  # scripts only -- scripts/lib/ files are sourced/imported, never invoked.
  if [[ "$scope" == "full" ]]; then
    if [[ ! -x "$f" ]]; then
      failures+=("$rel: not executable")
    fi
    if ! grep -q '\-\-help' "$f" 2>/dev/null; then
      failures+=("$rel: missing --help flag")
    fi
  fi
```

### Rename to the written standard instead of adding tool config

When a discovery mechanism misses files because they violate an already-written naming standard, rename the files — do not add configuration to widen discovery. The dash-named suites were invisible to bare `pytest tests/` because pytest's default pattern is `test_*.py`, and `docs/standards/testing-standards.md` already mandated `test_<script_name>.py` (underscores) — exactly one file followed it. Renaming `test-index-scripts.py` → `test_index_scripts.py` (and the other three) enforces the written standard and makes default collection work with **zero pytest configuration**; a `pytest.ini` widening the pattern would have amended the standard to bless the violation.

The rename carries a trap: **a standalone-runner `test-*.py` renamed naively executes its entire suite during pytest collection**, because its module-level code runs the suite at import time. Such a file must be converted to pytest idiom first — plain `test_*` functions, a `tmp_path` fixture replacing the runner's setup (`tests/skills/ts-compound/test_detect_overlap.py` is the converted precedent):

```python
@pytest.fixture()
def solutions_dir(tmp_path):
    """Solutions dir containing one convention doc, as the standalone runner's fixture did."""
    conventions = tmp_path / "docs" / "solutions" / "conventions"
    conventions.mkdir(parents=True)
    (conventions / "valkey-pattern.md").write_text(...)
    return tmp_path / "docs" / "solutions"


def test_exit_2_for_no_matches(solutions_dir):
    r = subprocess.run([sys.executable, SCRIPT, '--title', ..., '--solutions-dir', str(solutions_dir)],
                       capture_output=True, text=True)
    assert r.returncode == 2, f"expected exit 2, got {r.returncode}"
```

Bash suites stay dash-named (`test-*.sh`) — the standard specifies dashes for shell, and pytest never collects them.

### Wire every gate into enforcement the day it exists

A standard that no tool checks is a comment. The enforcement topology that closed the vacuum is three layers with a deliberate speed split:

- **Pre-commit (seconds):** the gate joins the hook chain as a fourth fast hook — `verify-scripts.sh --all`, `language: script`, `pass_filenames: false`, `always_run: true`. Full battery never runs here.
- **Aggregate runner (one command):** `scripts/run-test-suites.sh` discovers `tests/scripts/test-*.sh`, `tests/skills/*/test-*.sh`, and `tests/scripts/*.bats`, runs each (`.sh` via `bash`, `.bats` via `bats`), and aggregates failures — every discovered suite executes even if an earlier one failed, so one red suite cannot hide the state of the rest:

```bash
for suite in "${suites[@]}"; do
  echo "--- $suite"
  rc=0
  bash "$suite" || rc=$?
  if [[ $rc -eq 0 ]]; then
    echo "PASS: $suite"; passed=$((passed + 1))
  else
    echo "FAIL: $suite (exit $rc)"; failed=$((failed + 1))
  fi
done
```

- **CI (full battery):** a first-ever GitHub Actions workflow runs pytest, the aggregate runner, shellcheck, the reference gate, and the compliance gate as separate steps — one job per step keeps failure location legible in the Actions log.

Two design rules inside this topology:

- **Refuse to skip silently — abort instead.** If `.bats` files are discovered but `bats` is not installed, the runner exits 2 with an explicit error rather than skipping them: "silently skipping them would report a false green." Any discovery gap that silently narrows the battery converts a real failure into a green run.
- **Exclude known-drift data from the battery.** `tests/baselines/` (word-count artifacts describing the repo at 2026-07-05) is never discovered — baseline drift would make CI red on arrival for a non-behavioral reason. The runner's globs cannot match it, and an explicit filter keeps the exclusion true if discovery changes later.

**Pin CI tool versions so CI is identical to local.** An unpinned `pip install pytest` resolves to whatever pip serves that day, making green-on-main time-dependent. The delivered workflow pins everything and asserts the pin: `actions/checkout@v7`, `actions/setup-python@v7` with `python-version: '3.12'` (the setup-python interpreter is not PEP 668 externally-managed, unlike the image's system Python — plain `pip` on system Python fails there), `pytest==9.1.0`, `bats@1.13.0` (1.14.0 ships a breaking `run`/`set -e` change), and shellcheck 0.10.0 from the official tarball with a version assertion, because the runner image preinstalls 0.9.0, which drifts lenient against the repo's `.shellcheckrc` disables written against 0.10.0:

```yaml
      - name: Install shellcheck 0.10.0
        run: |
          curl -fsSL https://github.com/koalaman/shellcheck/releases/download/v0.10.0/shellcheck-v0.10.0.linux.x86_64.tar.xz -o /tmp/shellcheck.tar.xz
          tar -xJf /tmp/shellcheck.tar.xz -C /tmp
          sudo mv /tmp/shellcheck-v0.10.0/shellcheck /usr/local/bin/shellcheck
          shellcheck --version | grep -Fx 'version: 0.10.0'
```

The workflow file becomes the canonical record of tool versions; the README references it in dev-setup prose rather than duplicating rationale.

### Gate greps; suites assert behavior

`verify-scripts.sh` only greps file contents for the string `--help`. A comment mentioning `--help` satisfies it. Compliance therefore means the early-argument-check pattern — an actual `--help` branch answering **before** any argument validation or side effect (the `scripts/to-json.sh` exemplar):

```bash
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  echo "Usage: verify-scripts.sh [dir|--file path|--all]"
  ...
  exit 0
fi
```

and behavior is asserted by a sibling suite, not the gate: `tests/scripts/test-fleet-help.sh` loops over the 26 fleet-compliance scripts and asserts, per script, that the exec bit is set; `--help` exits 0 (with stdin closed so stdin-reading scripts cannot hang — for required-argument scripts, rc=0 here *is* the assertion that help is answered before validation); output contains `Usage`; stderr is empty; running from an empty tmpdir cwd creates no files (no side effects); `-h` exits 0 with usage; and exit codes are documented where the script has meaningful distinct ones (three `extract-*.py` scripts with a single designed exit are deliberately outside that assertion, and the suite header says so rather than silently skipping):

```bash
  out=$(cd "$workdir" && "$script" --help </dev/null 2>"$errfile") && rc=0 || rc=$?
  [[ $rc -eq 0 ]] || die "$name: --help exits 0 (rc=$rc)"
  grep -q "Usage" <<< "$out" || die "$name: --help prints usage"
  [[ ! -s "$errfile" ]] || die "$name: --help writes no stderr"
  [[ -z "$(ls -A "$workdir")" ]] || die "$name: --help creates no files in cwd"
```

Cheap string checks belong in the gate (it must stay seconds-fast); anything behavioral belongs in the test suites.

### Deleting a doc or data file orphans its consumers — find them

Issue #110 deleted `docs/standards/dispatch-standards.md`; 8 bats tests and a `get_dispatch_rule` code path kept referencing it, invisibly, until a runner enumerated every suite and the orphans surfaced. When deleting any doc or data file, grep for consumers — tests, scripts, and references — in the same change. The remediation pruned the orphaned tests and kept the self-contained `validate_dispatch_invocation` coverage in `tests/scripts/test-dispatch-standards-enforcement.bats`. Wiring a runner and CI makes such orphans surface immediately instead of after months.

### Execution-process notes

- **Worktree-isolated parallel subagents with disjoint file sets merged clean.** When decomposing multi-unit work across agents, give each agent its own git worktree and a file set that shares nothing; this run's units (gate, renames, fleet batch, runner, CI, docs) landed that way.
- **Prune hidden directories when scanning a tree.** Dir-mode scanning `.` descended into `.git/` and `.claude/`, and a live worktree under `.claude/worktrees/` made the gate scan the fleet four times over. The find now prunes dot-dirs:

```bash
find "$target" -type d -name '.*' -prune -o \( -name "*.sh" -o -name "*.py" \) -print
```

## Why This Matters

- **Disagreeing modes destroy gate credibility.** When `--all` says green and a directory scan says 25 failures, engineers stop trusting both — and the false noise (29 of 62) drowns the genuine signal (33 offenders). After classification, the gate reports 58/0 identically in both modes and every failure is actionable.
- **A false green is worse than a red.** The dash-named suites meant `pytest tests/` "passed" while silently skipping 73 of 97 tests. A red run gets fixed; a green-looking partial run ships.
- **Standards are inert without enforcement.** Every residual in this fix — gate exemptions, underscore naming, lib-tier scoping — was already written in a standards doc that no tool implemented. The gap persisted until it became an issue.
- **Unpinned CI drifts from local.** shellcheck 0.9.0 preinstalled on the runner would pass code the local 0.10.0 rejects; bats 1.14.0 changes `run`/`set -e` semantics. Without exact pins, "green on main" depends on the day.
- **Grep-level compliance invites compliance theater.** A gate satisfied by a comment certifies nothing; only a suite that runs `--help` and inspects exit code, output, and side effects proves the behavior the ecosystem actually relies on.
- **Unmanaged deletion leaves live code pointing at nothing.** Orphaned tests referencing a deleted standard sat in the repo for months, executable only by nobody, because nothing enumerated the suites.

## When to Apply

- Writing or modifying a validation gate with more than one scan mode — put scope policy in the per-file check, keyed on repo-relative paths.
- A tool's default discovery misses files your standards already mis-name — rename to the standard; never add config to accommodate violations of a written rule.
- Renaming any test file into a framework's discovery pattern — check it is not a standalone runner that would execute at import/collection time.
- Introducing a standard of any kind — pair it same-day with the tool, hook, or CI step that enforces it.
- Adding a first CI workflow — pin every action, runtime, and tool version, and assert pins where the tool reports them.
- Deleting a documentation or data file — grep for tests, scripts, and paths referencing it in the same change.
- Scanning a repository tree with `find` — prune hidden directories; tooling state (`.git`, `.claude/worktrees`, plugin caches) is not repo content.
- Decomposing a large multi-unit fix across parallel agents — isolate each in a worktree with a disjoint file set.

## Examples

**Before — modes disagree because each filters its own list:** `--all` enumerated only `scripts/` and `skills/*/scripts/` (so `tests/` was never seen), while dir mode enumerated everything and ran the full check set on all of it: 25 false `tests/` failures, 4 false `scripts/lib/` failures, and no mechanism to express either exemption.

**After — one classifier, three modes agree:** `classify_scope()` at the `check_file()` choke point (above). The gate self-test builds a standalone fixture tree and asserts each scenario: a `--help`-less non-executable file under `tests/` is enumerated but never flagged and counted in `Out of scope (tests/, not checked): 1 file(s) skipped`; a `scripts/lib/` file missing both `--help` and the exec bit passes when syntactically valid; a `scripts/lib/` file with `if then` fails with `FAIL: scripts/lib/broken.sh: bash syntax error`; a command script missing `--help` still fails; failure lines carry repo-relative paths with duplicate basenames disambiguated; and `--file` on a test file prints the skip line and exits 0 without counting it as passed.

**Before — discovery gap:** `pytest tests/` collected 24 of 97 tests; three dash-named suites invisible under the default `test_*.py` pattern, one standalone runner uncollectable under any name.

**After — standard-compliant names, zero config:** `tests/scripts/test_index_scripts.py`, `tests/scripts/test_update_indexes.py`, `tests/scripts/test_index_common.py`, and `tests/skills/ts-compound/test_detect_overlap.py` (converted from standalone runner to pytest functions). `pytest tests/` collects and passes all 101 tests with no pytest configuration file; the testing standard now states the rule ("standalone `test-*.py` runners are prohibited") with the conversion as the cited precedent.

**Before — enforcement vacuum:** no `.github/workflows/`, no runner, gate invoked by hand when remembered; six bash suites were even red from missing exec bits (`rc=126`) with nothing to notice.

**After — wired end to end:** `.pre-commit-config.yaml` carries four hooks ending in `verify-scripts` (fast, seconds); `scripts/run-test-suites.sh` runs 46 bash/bats suites with fail aggregation and a `Results: N passed, M failed` summary, aborting with exit 2 if bats is missing while `.bats` files exist; `.github/workflows/ci.yml` runs the full battery on push and PR to `main` with per-ref concurrency cancellation, every tool pinned (`checkout@v7`, `setup-python@v7` / Python 3.12, `pytest==9.1.0`, `bats@1.13.0`, shellcheck 0.10.0 tarball asserted with `grep -Fx 'version: 0.10.0'`).

**Fleet compliance, behaviorally proven:** 26 scripts across `scripts/` and `skills/*/scripts/` received the early `--help` check (usage text, exit codes where meaningful) plus exec bits; the gate verifies presence, and `tests/scripts/test-fleet-help.sh` verifies behavior per script — exec bit, `--help` and `-h` exit 0 with `Usage` on stdout and empty stderr, no files created in the cwd, and exit codes documented for the 23 scripts that have meaningful distinct ones.

**Orphan pruning:** `tests/scripts/test-dispatch-standards-enforcement.bats` lost the 8 tests that referenced the deleted `dispatch-standards.md` and the dead `get_dispatch_rule` path; the 5 remaining tests exercise `validate_dispatch_invocation` directly against mock skill files and remain green under the runner and CI.

The policy behind the gate's check classes is documented in `docs/standards/script-extraction-standards.md` ("Gate scope") — which path classes get which checks and why — so the classification lives in a standard, not only in gate code.

## Related

- [Claude Code plugin script path resolution](../tooling-decisions/claude-code-plugin-script-path-resolution.md) — parent remediation record (#115/#116) whose "Known pre-existing issues" section pre-registered exactly these residuals; both entries were marked resolved by this work
- [Automatic test dispatch](../conventions/automatic-test-dispatch.md) — shares the test-naming convention; its Test conventions section cites the same `test_<name>.py` rule
- `docs/standards/script-extraction-standards.md` — "Gate scope": the policy the classification implements
- `docs/standards/testing-standards.md` — canonical test naming and runner rules
- Issue [#118](https://github.com/Taegost/taegosts-skills/issues/118) — the repo-hygiene residuals this work resolved
