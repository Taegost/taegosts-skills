"""Tests for scripts/split-ratification-csv.py -- issue #119 CSV split."""

import csv
import subprocess
import sys
from datetime import date
from pathlib import Path

SCRIPT = Path(__file__).resolve().parent.parent / "scripts" / "split-ratification-csv.py"

HEADER = ["ID", "Surface", "Location", "Claim", "Evidence", "Trust", "Disposition", "Decision", "Note"]


def make_source(tmp_path: Path, rows: list[list[str]], header: list[str] | None = None) -> Path:
    """Write a source CSV into tmp_path and return its path."""
    source = tmp_path / "source.csv"
    with source.open("w", encoding="utf-8", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(header if header is not None else HEADER)
        writer.writerows(rows)
    return source


def run_script(*args: object) -> subprocess.CompletedProcess:
    """Run the script as a subprocess; never raises on nonzero exit."""
    return subprocess.run(
        [sys.executable, str(SCRIPT), *(str(a) for a in args)],
        capture_output=True, text=True, check=False,
    )


def read_csv(path: Path) -> list[list[str]]:
    with path.open("r", encoding="utf-8", newline="") as f:
        return list(csv.reader(f))


def basic_rows() -> list[list[str]]:
    return [
        ["WK1", "s", "l", "claim one", "ev", "t", "d", "dec", "n"],
        ["WK3", "s", "l", "claim two", "ev", "t", "d", "dec", "n"],
        ["AS1", "s", "l", "claim three", "ev", "t", "d", "dec", "n"],
        ["AS2", "s", "l", "claim four", "ev", "t", "d", "dec", "n"],
    ]


# ── Case 1: split correctness ──

class TestSplitCorrectness:
    """Rows group into {PREFIX}-ratification.csv with the source header."""

    def test_split_groups_by_prefix(self, tmp_path):
        source = make_source(tmp_path, basic_rows())
        dest = tmp_path / "dest"
        result = run_script(source, "--dest", dest, "--date", "2026-10-05")
        assert result.returncode == 0, result.stderr

        out_dir = dest / "2026-10-05"
        wk_rows = read_csv(out_dir / "WK-ratification.csv")
        as_rows = read_csv(out_dir / "AS-ratification.csv")

        assert wk_rows[0] == HEADER
        assert as_rows[0] == HEADER
        assert len(wk_rows) == 3  # header + WK1 + WK3
        assert len(as_rows) == 3  # header + AS1 + AS2
        assert [r[0] for r in wk_rows[1:]] == ["WK1", "WK3"]
        assert [r[0] for r in as_rows[1:]] == ["AS1", "AS2"]


# ── Case 2: round-trip fidelity ──

class TestRoundTripFidelity:
    """Embedded newlines, commas, and quotes survive the split unchanged."""

    def test_embedded_newline_commas_quotes(self, tmp_path):
        tricky = 'line one,\nline "two" quoted, and, more commas'
        source = make_source(tmp_path, [
            ["WK1", tricky, "l", "c", "e", "t", "d", "dec", "n"],
            ["AS1", "plain", "l", "c", "e", "t", "d", "dec", "n"],
        ])
        dest = tmp_path / "dest"
        result = run_script(source, "--dest", dest, "--date", "2026-10-05")
        assert result.returncode == 0, result.stderr

        rows = read_csv(dest / "2026-10-05" / "WK-ratification.csv")
        assert rows[1][1] == tricky


# ── Case 3: clear step ──

class TestClearStep:
    """Stale CSVs in the date folder removed; non-CSV and siblings kept."""

    def test_clears_only_csv_in_date_folder(self, tmp_path):
        source = make_source(tmp_path, basic_rows())
        dest = tmp_path / "dest"
        out_dir = dest / "2026-10-05"
        out_dir.mkdir(parents=True)
        (out_dir / "stale-ratification.csv").write_text("old,data\n", encoding="utf-8")
        (out_dir / "notes.txt").write_text("keep me", encoding="utf-8")
        sibling = dest / "2026-10-01"
        sibling.mkdir()
        (sibling / "sibling-ratification.csv").write_text("sibling,data\n", encoding="utf-8")

        result = run_script(source, "--dest", dest, "--date", "2026-10-05")
        assert result.returncode == 0, result.stderr

        assert not (out_dir / "stale-ratification.csv").exists()
        assert (out_dir / "notes.txt").exists()
        assert (sibling / "sibling-ratification.csv").read_text(encoding="utf-8") == "sibling,data\n"
        assert (out_dir / "WK-ratification.csv").exists()

    def test_skips_directory_named_csv(self, tmp_path):
        """A directory named *.csv is not deleted and does not crash the clear."""
        source = make_source(tmp_path, basic_rows())
        dest = tmp_path / "dest"
        out_dir = dest / "2026-10-05"
        out_dir.mkdir(parents=True)
        (out_dir / "weird.csv").mkdir()

        result = run_script(source, "--dest", dest, "--date", "2026-10-05")
        assert result.returncode == 0, result.stderr

        assert (out_dir / "weird.csv").is_dir()
        assert (out_dir / "WK-ratification.csv").exists()


# ── Case 4: idempotent re-run ──

class TestIdempotentRerun:
    """Running twice does not duplicate rows."""

    def test_rerun_preserves_counts(self, tmp_path):
        source = make_source(tmp_path, basic_rows())
        dest = tmp_path / "dest"
        first = run_script(source, "--dest", dest, "--date", "2026-10-05")
        assert first.returncode == 0, first.stderr
        second = run_script(source, "--dest", dest, "--date", "2026-10-05")
        assert second.returncode == 0, second.stderr

        wk = read_csv(dest / "2026-10-05" / "WK-ratification.csv")
        as_ = read_csv(dest / "2026-10-05" / "AS-ratification.csv")
        assert len(wk) == 3
        assert len(as_) == 3


# ── Case 5: row order ──

class TestRowOrder:
    """Source order preserved within each output file."""

    def test_order_preserved(self, tmp_path):
        rows = [
            ["WK3", "s", "l", "third", "e", "t", "d", "dec", "n"],
            ["WK1", "s", "l", "first", "e", "t", "d", "dec", "n"],
            ["WK2", "s", "l", "second", "e", "t", "d", "dec", "n"],
            ["AS1", "s", "l", "only", "e", "t", "d", "dec", "n"],
        ]
        source = make_source(tmp_path, rows)
        dest = tmp_path / "dest"
        result = run_script(source, "--dest", dest, "--date", "2026-10-05")
        assert result.returncode == 0, result.stderr

        wk = read_csv(dest / "2026-10-05" / "WK-ratification.csv")
        assert [r[3] for r in wk[1:]] == ["third", "first", "second"]


# ── Case 6: exit codes ──

class TestExitCodes:
    """1 missing source, 2 bad date, 3 no ID column, 4 bad prefix."""

    def test_missing_source_exits_1(self, tmp_path):
        result = run_script(tmp_path / "nope.csv", "--dest", tmp_path / "dest", "--date", "2026-10-05")
        assert result.returncode == 1

    def test_noncanonical_date_exits_2(self, tmp_path):
        source = make_source(tmp_path, basic_rows())
        result = run_script(source, "--dest", tmp_path / "dest", "--date", "2026-10-1")
        assert result.returncode == 2

    def test_no_id_column_exits_3(self, tmp_path):
        source = make_source(tmp_path, basic_rows(), header=["Foo", "Bar"])
        result = run_script(source, "--dest", tmp_path / "dest", "--date", "2026-10-05")
        assert result.returncode == 3

    def test_numeric_id_exits_4(self, tmp_path):
        source = make_source(tmp_path, [
            ["123", "s", "l", "c", "e", "t", "d", "dec", "n"],
        ])
        result = run_script(source, "--dest", tmp_path / "dest", "--date", "2026-10-05")
        assert result.returncode == 4


# ── Case 7: summary output ──

class TestSummaryOutput:
    """Stdout lists each file with row count plus a totals line."""

    def test_summary_lines(self, tmp_path):
        source = make_source(tmp_path, basic_rows())
        dest = tmp_path / "dest"
        result = run_script(source, "--dest", dest, "--date", "2026-10-05")
        assert result.returncode == 0, result.stderr

        assert "AS-ratification.csv: 2 rows" in result.stdout
        assert "WK-ratification.csv: 2 rows" in result.stdout
        # sorted by prefix: AS line before WK line
        assert result.stdout.index("AS-ratification.csv: 2 rows") < result.stdout.index("WK-ratification.csv: 2 rows")
        assert "Total: 2 files, 4 rows" in result.stdout


# ── Case 8: default date ──

class TestDefaultDate:
    """Without --date, output lands in today's folder."""

    def test_default_date_is_today(self, tmp_path):
        source = make_source(tmp_path, basic_rows())
        dest = tmp_path / "dest"
        result = run_script(source, "--dest", dest)
        assert result.returncode == 0, result.stderr

        today_dir = dest / date.today().isoformat()
        assert (today_dir / "WK-ratification.csv").exists()
        assert (today_dir / "AS-ratification.csv").exists()
