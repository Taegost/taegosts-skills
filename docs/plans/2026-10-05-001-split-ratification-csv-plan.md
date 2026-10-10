---
title: "feat: Split ratification CSV into per-prefix files (Issue #119)"
type: feat
date: 2026-10-05
issue: 119
---

# Plan: Split ratification CSV into per-prefix files

## Context

The issue #119 ratification workflow (branch `docs/119-repo-documentation-review`) needs `ratification-decisions.csv` (repo root, 761 rows) split into smaller per-audit-surface files under `resources/doc-ratification/{DATE}/` for offline review. One file per ID prefix (`WK3` → `WK`), named `{PREFIX}-ratification.csv`.

User-confirmed decisions:

- Date defaults to today at runtime, overridable via `--date`.
- Final summary is human-readable (not JSON).

Source data facts (verified 2026-10-05):

- Header: `ID,Surface,Location,Claim,Evidence,Trust,Disposition,Decision,Note`
- 761 data rows, IDs match `^[A-Za-z]+[0-9]+$`, 46 distinct prefixes (44 two-letter prefixes plus one-offs `AT`, `H`)
- Quoted fields contain embedded newlines and commas — the script must use the `csv` module, never string splitting
- Destination `resources/doc-ratification/` exists and is empty

## Changes

1. Save this plan to `docs/plans/2026-10-05-001-split-ratification-csv-plan.md` (this file).
2. New file: `scripts/split-ratification-csv.py` — single script, no other source changes.
3. New file: `tests/test_split_ratification_csv.py` — pytest suite (below).

The script follows `scripts/locate-plan.py` / `scripts/extract-ktds.py` conventions: `#!/usr/bin/env python3`, module docstring with `Usage:` and `Exit codes:` list, argparse, PEP 604 type hints (3.10+), warnings/errors to `sys.stderr`, executable bit.

### Behavior

1. **Args (argparse)**
   - positional `source`: path to source CSV
   - `--date YYYY-MM-DD`: optional, defaults to current date; validated strictly (parse + re-format compare), exit code 2 on bad format
   - `--dest DIR`: optional override of destination root (default `{REPO_ROOT}/resources/doc-ratification`). Exists for test isolation; the spec path remains the default.

2. **Paths**
   - `REPO_ROOT = Path(__file__).resolve().parents[1]`
   - Destination: `{dest_root}/{date}/`, created with `mkdir(parents=True, exist_ok=True)`

3. **Clear destination (step 1 of spec)**
   - Delete only `*.csv` files directly inside the `{date}` folder (`glob("*.csv")`, non-recursive). Other dates' folders and non-CSV files are untouched. Print count removed.

4. **Split (step 2)**
   - Read source with `csv.reader` (`newline=""`, utf-8); first row = header
   - `id_idx = header.index("ID")` — exit code 3 if `ID` column missing
   - Prefix per row: `re.sub(r"\d+$", "", row[id_idx].strip())`
   - Validate prefix non-empty and filesystem-safe (`^[A-Za-z][A-Za-z0-9_-]*$`) — exit code 4 listing row number on violation
   - First row for a prefix → create `{prefix}-ratification.csv`, write header; subsequent rows append via held-open `csv.writer` handles (dict of prefix → (filehandle, writer))
   - Rows are written verbatim as lists — preserves embedded newlines/quotes exactly; source order preserved within each file

5. **Summary (step 3)**
   - Stdout, sorted by prefix: one line per file `{PREFIX}-ratification.csv: N rows`, then totals (files created, total rows)
   - Expected on current data: 46 files, 761 rows total

### Exit codes

`0` success · `1` source missing/unreadable · `2` invalid `--date` · `3` no `ID` column · `4` unsafe/empty prefix

## Tests

`tests/test_split_ratification_csv.py` — pytest, matching `tests/test_validate_index_standards.py` style: invoke via `subprocess.run([sys.executable, SCRIPT, ...])`, `tmp_path` for source CSVs and `--dest` root, parse outputs with `csv` module.

Cases:

1. **Split correctness**: source rows `WK1, WK3, AS1, AS2` → `WK-ratification.csv` 2 rows, `AS-ratification.csv` 2 rows; each file's header equals source header
2. **Round-trip fidelity**: field containing embedded newline + commas + quotes survives split unchanged
3. **Clear step**: stale `*.csv` in date folder removed pre-split; non-CSV file in same folder kept; sibling date folder untouched
4. **Idempotent re-run**: run twice, counts unchanged (no duplicated rows)
5. **Row order**: source order preserved within each output file
6. **Exit codes**: missing source → 1; `--date 2026-10-1` → 2; header without `ID` column → 3; ID with no letter prefix (e.g. `123`) → 4
7. **Summary output**: stdout lists each file with row count plus totals line
8. **Default date**: run without `--date` writes into today's folder name

## Registration

None manual. The pre-commit `update-indexes` hook regenerates `scripts/INDEX.md` on commit; the `verify-scripts` hook checks exec bit and `--help` — the script satisfies both by construction.

## Verification

1. `pytest tests/test_split_ratification_csv.py -v` — all pass
2. `python3 scripts/split-ratification-csv.py ratification-decisions.csv` — expect 46 files, 761 rows, exit 0
3. `ls resources/doc-ratification/2026-10-05/ | wc -l` → 46
4. Row-sum check via Python: data rows across output files sum to 761 (grep -c is unreliable — embedded newlines)
5. Spot-check `WK-ratification.csv`: header matches source header; row count matches WK-prefixed source rows
6. Re-run same command — counts stay 46/761 (clearing step prevents duplicates)
7. `--date 2026-10-01` run → files land in `2026-10-01/`, `2026-10-05/` untouched
