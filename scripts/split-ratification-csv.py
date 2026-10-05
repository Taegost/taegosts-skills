#!/usr/bin/env python3
"""
Split ratification-decisions.csv into per-prefix files for offline review.

Reads the source CSV with the csv module (quoted fields may contain embedded
newlines and commas -- never string-split), groups data rows by ID prefix
(trailing digits stripped, e.g. WK3 -> WK), and writes one
{PREFIX}-ratification.csv per prefix under {dest_root}/{date}/.

The {date} folder is cleared of *.csv files (non-recursive) before the
split, so re-runs are idempotent. Other date folders are untouched.

Usage:
    python3 scripts/split-ratification-csv.py ratification-decisions.csv
    python3 scripts/split-ratification-csv.py ratification-decisions.csv --date 2026-10-05
    python3 scripts/split-ratification-csv.py ratification-decisions.csv --dest /tmp/iso

Exit codes:
    0 - Success
    1 - Source CSV missing or unreadable
    2 - Invalid --date (expected strict YYYY-MM-DD)
    3 - Source header has no ID column
    4 - Row ID yields an empty or unsafe prefix
"""

import argparse
import csv
import re
import sys
from datetime import date
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_DEST_ROOT = REPO_ROOT / "resources" / "doc-ratification"
SAFE_PREFIX_RE = re.compile(r"^[A-Za-z][A-Za-z0-9_-]*$")


def parse_args(argv: list[str]) -> argparse.Namespace:
    """Parse command-line arguments."""
    parser = argparse.ArgumentParser(
        description="Split a ratification decisions CSV into per-prefix files."
    )
    parser.add_argument("source", help="path to the source CSV")
    parser.add_argument(
        "--date",
        default=None,
        help="destination date folder as YYYY-MM-DD (default: today)",
    )
    parser.add_argument(
        "--dest",
        type=Path,
        default=DEFAULT_DEST_ROOT,
        help="destination root directory (default: %(default)s)",
    )
    return parser.parse_args(argv)


def resolve_date_folder(date_arg: str | None) -> str:
    """Return the date folder name, validating --date strictly.

    A value is valid only if it parses as a date AND re-formats to the
    identical canonical YYYY-MM-DD string. Exits with code 2 otherwise.
    """
    if date_arg is None:
        return date.today().isoformat()
    try:
        parsed = date.fromisoformat(date_arg)
    except ValueError:
        print(f"Error: invalid --date {date_arg!r}: expected YYYY-MM-DD", file=sys.stderr)
        sys.exit(2)
    if parsed.isoformat() != date_arg:
        print(
            f"Error: invalid --date {date_arg!r}: not canonical YYYY-MM-DD "
            f"(expected {parsed.isoformat()})",
            file=sys.stderr,
        )
        sys.exit(2)
    return parsed.isoformat()


def clear_stale_csvs(date_dir: Path) -> int:
    """Delete *.csv files directly inside date_dir (non-recursive).

    Returns the number removed. Non-CSV files, directories named *.csv,
    and sibling date folders are untouched.
    """
    removed = 0
    for stale in sorted(date_dir.glob("*.csv")):
        if not stale.is_file():
            continue
        stale.unlink()
        removed += 1
    return removed


def main(argv: list[str] | None = None) -> int:
    """Split the source CSV; returns the process exit code."""
    args = parse_args(argv if argv is not None else sys.argv[1:])

    date_name = resolve_date_folder(args.date)

    source = Path(args.source)
    if not source.is_file():
        print(f"Error: source CSV not found: {source}", file=sys.stderr)
        return 1

    date_dir = args.dest / date_name
    date_dir.mkdir(parents=True, exist_ok=True)

    removed = clear_stale_csvs(date_dir)
    print(f"Cleared {removed} stale CSV file(s) from {date_dir}")

    try:
        infile = source.open("r", encoding="utf-8", newline="")
    except OSError as exc:
        print(f"Error: cannot read source CSV: {exc}", file=sys.stderr)
        return 1

    writers: dict[str, tuple[object, csv.writer]] = {}
    counts: dict[str, int] = {}
    total_rows = 0
    try:
        reader = csv.reader(infile)
        try:
            header = next(reader)
        except StopIteration:
            print("Error: source CSV is empty (no header row)", file=sys.stderr)
            return 1
        try:
            id_idx = header.index("ID")
        except ValueError:
            print(f"Error: source header has no 'ID' column: {header}", file=sys.stderr)
            return 3

        for row_num, row in enumerate(reader, start=2):
            raw_id = row[id_idx].strip() if id_idx < len(row) else ""
            prefix = re.sub(r"\d+$", "", raw_id)
            if not SAFE_PREFIX_RE.match(prefix):
                print(
                    f"Error: row {row_num}: ID {raw_id!r} yields empty or "
                    f"unsafe prefix {prefix!r}",
                    file=sys.stderr,
                )
                return 4
            if prefix not in writers:
                out_path = date_dir / f"{prefix}-ratification.csv"
                outfile = out_path.open("w", encoding="utf-8", newline="")
                writer = csv.writer(outfile)
                writer.writerow(header)
                writers[prefix] = (outfile, writer)
                counts[prefix] = 0
            writers[prefix][1].writerow(row)
            counts[prefix] += 1
            total_rows += 1
    finally:
        infile.close()
        for outfile, _ in writers.values():
            outfile.close()

    for prefix in sorted(counts):
        print(f"{prefix}-ratification.csv: {counts[prefix]} rows")
    print(f"Total: {len(counts)} files, {total_rows} rows")

    return 0


if __name__ == "__main__":
    sys.exit(main())
