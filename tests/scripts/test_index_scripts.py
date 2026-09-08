"""Integration tests for scripts/index-scripts.py.

Tests:
- Script runs without errors
- Generates INDEX.md files
- Extracts R3 frontmatter from .sh files
- Extracts descriptions from .py docstrings
- Handles scripts without frontmatter gracefully
- R8 format compliance (frontmatter, table structure)
- Emits the script path resolution note
- Regeneration is content-idempotent (created-date preservation, no-op on
  unchanged content)
- A hand-maintained non-default "owner:" frontmatter field survives
  regeneration
- ALL hand-maintained content survives regeneration (same behavior as
  update-indexes.py): "## " sections, heading-less paragraphs between the
  resolution note and the table, and trailing content after the table; a
  generated-looking INDEX.md with no table aborts the run instead of
  being overwritten
- scripts/lib/ helper subdirectories are indexed under lib/<name> and
  non-script files there are excluded
"""

import json
import re
import subprocess
import sys
from datetime import date
from pathlib import Path

import pytest

SCRIPT = Path(__file__).resolve().parent.parent.parent / "scripts" / "index-scripts.py"


def run_indexer(*args, cwd=None):
    """Run index-scripts.py and return (stdout, stderr, returncode)."""
    result = subprocess.run(
        [sys.executable, str(SCRIPT), *args],
        capture_output=True, text=True, check=False,
        cwd=cwd,
    )
    return result.stdout, result.stderr, result.returncode


class TestRunsCleanly:
    """Script executes without errors on the real repo."""

    def test_no_args(self):
        """Running without args should succeed; a second run on the unchanged
        tree must write nothing (content-idempotent regeneration)."""
        stdout, stderr, rc = run_indexer()
        assert rc == 0, f"Expected exit 0, got {rc}. stderr: {stderr}"

        second_stdout, second_stderr, second_rc = run_indexer()
        assert second_rc == 0, (
            f"Expected exit 0, got {second_rc}. stderr: {second_stderr}"
        )
        assert second_stdout.strip() == "", (
            f"Unchanged tree should not be rewritten, got: {second_stdout}"
        )

    def test_dry_run(self):
        """--dry-run should succeed and not write files."""
        stdout, stderr, rc = run_indexer("--dry-run")
        assert rc == 0, f"Expected exit 0, got {rc}. stderr: {stderr}"
        assert "[dry-run]" in stderr, "Expected dry-run marker in stderr"

    def test_single_dir(self):
        """--dir scripts/ should succeed."""
        stdout, stderr, rc = run_indexer("--dir", "scripts/")
        assert rc == 0, f"Expected exit 0, got {rc}. stderr: {stderr}"


class TestGeneratesIndexFiles:
    """INDEX.md files are generated correctly."""

    def test_scripts_index_exists(self):
        """scripts/INDEX.md should exist after running."""
        stdout, _, rc = run_indexer()
        assert rc == 0
        index_path = SCRIPT.parent / "INDEX.md"
        assert index_path.exists(), f"{index_path} not found"
        # Clean up: don't leave generated file around
        # (test runs in the real repo, so the file is expected)

    def test_scripts_index_has_frontmatter(self, tmp_path):
        """Generated INDEX.md should have R8 YAML frontmatter."""
        # Create a temp scripts dir with a test script
        scripts_dir = tmp_path / "scripts"
        scripts_dir.mkdir()
        (scripts_dir / "test-script.sh").write_text(
            "#!/usr/bin/env bash\n# test-script.sh -- A test script\n"
        )

        stdout, _, rc = run_indexer("--dir", str(scripts_dir))
        assert rc == 0

        index_path = scripts_dir / "INDEX.md"
        assert index_path.exists()
        content = index_path.read_text()
        assert content.startswith("---\n"), "Expected YAML frontmatter"
        assert "tags:" in content, "Expected tags field"
        assert "description:" in content, "Expected description field"

    def test_scripts_index_has_table(self, tmp_path):
        """Generated INDEX.md should have Link/Description table (Wave 1 format)."""
        scripts_dir = tmp_path / "scripts"
        scripts_dir.mkdir()
        (scripts_dir / "test-script.sh").write_text(
            "#!/usr/bin/env bash\n# test-script.sh -- A test script\n"
        )

        run_indexer("--dir", str(scripts_dir))
        content = (scripts_dir / "INDEX.md").read_text()
        # Wave 1 authoritative format: Link column with markdown link, not plain Path
        assert "| Link | Description |" in content
        assert "|------|-------------|" in content
        assert "[test-script.sh](./test-script.sh)" in content


class TestExtractsFrontmatter:
    """R3 frontmatter extraction works for both .sh and .py files."""

    def test_shell_description(self, tmp_path):
        """Extracts description from shell script line 2."""
        scripts_dir = tmp_path / "scripts"
        scripts_dir.mkdir()
        (scripts_dir / "my-script.sh").write_text(
            "#!/usr/bin/env bash\n# my-script.sh -- Does something useful\n"
        )

        run_indexer("--dir", str(scripts_dir))
        content = (scripts_dir / "INDEX.md").read_text()
        assert "Does something useful" in content

    def test_python_description(self, tmp_path):
        """Extracts description from Python module docstring."""
        scripts_dir = tmp_path / "scripts"
        scripts_dir.mkdir()
        (scripts_dir / "my-tool.py").write_text(
            '#!/usr/bin/env python3\n"""\nmy-tool.py -- Processes data files.\n\nMore details.\n"""\n'
        )

        run_indexer("--dir", str(scripts_dir))
        content = (scripts_dir / "INDEX.md").read_text()
        assert "Processes data files" in content

    def test_python_description_plain_docstring(self, tmp_path):
        """Extracts first line of plain docstring (no name prefix)."""
        scripts_dir = tmp_path / "scripts"
        scripts_dir.mkdir()
        (scripts_dir / "helper.py").write_text(
            '#!/usr/bin/env python3\n"""\nHelper utility for parsing.\n"""\n'
        )

        run_indexer("--dir", str(scripts_dir))
        content = (scripts_dir / "INDEX.md").read_text()
        assert "Helper utility for parsing" in content

    def test_python_description_u_prefix(self, tmp_path):
        """Handles U-number prefix in docstring."""
        scripts_dir = tmp_path / "scripts"
        scripts_dir.mkdir()
        (scripts_dir / "checker.py").write_text(
            '#!/usr/bin/env python3\n"""U11: checker.py - scan files for issues.\n"""\n'
        )

        run_indexer("--dir", str(scripts_dir))
        content = (scripts_dir / "INDEX.md").read_text()
        assert "scan files for issues" in content


class TestHandlesMissingFrontmatter:
    """Scripts without R3 frontmatter get placeholder descriptions."""

    def test_no_frontmatter(self, tmp_path):
        """Script without frontmatter gets '(no description)'."""
        scripts_dir = tmp_path / "scripts"
        scripts_dir.mkdir()
        (scripts_dir / "bare.sh").write_text("#!/usr/bin/env bash\necho hello\n")

        run_indexer("--dir", str(scripts_dir))
        content = (scripts_dir / "INDEX.md").read_text()
        assert "(no description)" in content

    def test_empty_directory(self, tmp_path):
        """Empty scripts directory produces no INDEX.md."""
        scripts_dir = tmp_path / "scripts"
        scripts_dir.mkdir()

        stdout, _, rc = run_indexer("--dir", str(scripts_dir))
        assert rc == 0
        assert not (scripts_dir / "INDEX.md").exists()

    def test_mixed_scripts(self, tmp_path):
        """Mix of scripts with and without frontmatter."""
        scripts_dir = tmp_path / "scripts"
        scripts_dir.mkdir()
        (scripts_dir / "good.sh").write_text(
            "#!/usr/bin/env bash\n# good.sh -- Has description\n"
        )
        (scripts_dir / "bare.py").write_text("#!/usr/bin/env python3\nprint('hi')\n")

        run_indexer("--dir", str(scripts_dir))
        content = (scripts_dir / "INDEX.md").read_text()
        assert "Has description" in content
        assert "(no description)" in content


class TestSkillScripts:
    """Skill-specific script directories are indexed."""

    def test_skill_index_generated(self):
        """Skills with scripts/ dirs should have INDEX.md files on disk."""
        stdout, _, rc = run_indexer()
        assert rc == 0
        skills_dir = SCRIPT.parent.parent / "skills"
        skill_indexes = sorted(
            p for p in skills_dir.glob("*/scripts/INDEX.md") if p.is_file()
        )
        assert len(skill_indexes) > 0, "Expected at least one skill INDEX.md"


class TestResolutionNoteAndIdempotency:
    """Resolution note is emitted and regeneration is content-idempotent."""

    def _make_scripts_dir(self, tmp_path):
        scripts_dir = tmp_path / "scripts"
        scripts_dir.mkdir()
        (scripts_dir / "test-script.sh").write_text(
            "#!/usr/bin/env bash\n# test-script.sh -- A test script\n"
        )
        return scripts_dir

    def test_resolution_note_present(self, tmp_path):
        """Generated INDEX.md carries the path resolution note after the intro."""
        scripts_dir = self._make_scripts_dir(tmp_path)

        run_indexer("--dir", str(scripts_dir))
        content = (scripts_dir / "INDEX.md").read_text()
        assert "Paths below are relative to this index's directory." in content
        assert "${CLAUDE_PLUGIN_ROOT}/<repo-relative-path>" in content
        # Note sits between the intro description line and the table
        assert content.index("# Scripts Scripts") \
            < content.index("Paths below are relative to this index's directory.") \
            < content.index("| Link | Description |")

    def test_second_run_leaves_file_untouched(self, tmp_path):
        """Regenerating unchanged content writes nothing and prints nothing."""
        scripts_dir = self._make_scripts_dir(tmp_path)
        index_path = scripts_dir / "INDEX.md"

        run_indexer("--dir", str(scripts_dir))
        before = index_path.read_text()

        stdout, _, rc = run_indexer("--dir", str(scripts_dir))
        assert rc == 0
        assert stdout.strip() == "", (
            f"Second run should not report any written file, got: {stdout}"
        )
        assert index_path.read_text() == before

    def test_created_date_preserved_and_content_change_bumps_last_updated(self, tmp_path):
        """Existing created date survives regeneration; genuine changes bump
        only last-updated."""
        scripts_dir = self._make_scripts_dir(tmp_path)
        index_path = scripts_dir / "INDEX.md"
        today = date.today().isoformat()

        run_indexer("--dir", str(scripts_dir))
        # Simulate an older index by backdating both frontmatter dates.
        backdated = (index_path.read_text()
                     .replace(f"created: {today}", "created: 2020-01-01")
                     .replace(f"last-updated: {today}", "last-updated: 2020-01-01"))
        index_path.write_text(backdated)

        # Unchanged content: file untouched, backdated created survives.
        stdout, _, rc = run_indexer("--dir", str(scripts_dir))
        assert rc == 0
        assert stdout.strip() == ""
        assert "created: 2020-01-01" in index_path.read_text()

        # Genuine content change: regenerated with created preserved and
        # last-updated bumped to today.
        (scripts_dir / "extra.sh").write_text(
            "#!/usr/bin/env bash\n# extra.sh -- An extra script\n"
        )
        stdout, _, rc = run_indexer("--dir", str(scripts_dir))
        assert rc == 0
        assert stdout.strip() != "", "Changed content should be rewritten"
        content = index_path.read_text()
        assert "created: 2020-01-01" in content
        assert f"last-updated: {today}" in content
        assert "[extra.sh](./extra.sh)" in content


class TestOwnerPreservation:
    """A hand-maintained non-default owner survives regeneration."""

    def _make_scripts_dir(self, tmp_path):
        scripts_dir = tmp_path / "scripts"
        scripts_dir.mkdir()
        (scripts_dir / "test-script.sh").write_text(
            "#!/usr/bin/env bash\n# test-script.sh -- A test script\n"
        )
        return scripts_dir

    def test_existing_owner_preserved_and_content_change_keeps_it(self, tmp_path):
        """A pre-existing non-default owner field survives regeneration,
        both on a no-op re-run and after genuine content changes."""
        scripts_dir = self._make_scripts_dir(tmp_path)
        index_path = scripts_dir / "INDEX.md"
        today = date.today().isoformat()

        run_indexer("--dir", str(scripts_dir))
        # Hand-set a non-default owner the way a plan-indexing pass would.
        hand_set = re.sub(r"(?m)^owner: .*$",
                          "owner: issue-90-ts-compound-refresh-port",
                          index_path.read_text())
        index_path.write_text(hand_set)

        # Unchanged content: file untouched, hand-set owner survives.
        stdout, _, rc = run_indexer("--dir", str(scripts_dir))
        assert rc == 0
        assert stdout.strip() == ""
        assert "owner: issue-90-ts-compound-refresh-port" in index_path.read_text()

        # Genuine content change: rewritten with the owner preserved and
        # last-updated bumped to today.
        (scripts_dir / "extra.sh").write_text(
            "#!/usr/bin/env bash\n# extra.sh -- An extra script\n"
        )
        stdout, _, rc = run_indexer("--dir", str(scripts_dir))
        assert rc == 0
        assert stdout.strip() != "", "Changed content should be rewritten"
        content = index_path.read_text()
        assert "owner: issue-90-ts-compound-refresh-port" in content
        assert f"last-updated: {today}" in content
        assert "[extra.sh](./extra.sh)" in content


class TestHandMaintainedContentPreservation:
    """ALL hand-maintained content survives regeneration, matching
    update-indexes.py behavior: "## " sections, heading-less paragraphs
    between the resolution note and the table, and trailing content after
    the table."""

    CUSTOM_BLOCK = (
        "## Custom Section\n"
        "\n"
        "A hand-maintained paragraph with no heading marker of its own."
    )
    TRAILING_BLOCK = "Hand-maintained footer paragraph after the table."

    def _make_scripts_dir(self, tmp_path):
        """Create a scripts directory holding one indexed shell script."""
        scripts_dir = tmp_path / "scripts"
        scripts_dir.mkdir()
        (scripts_dir / "test-script.sh").write_text(
            "#!/usr/bin/env bash\n# test-script.sh -- A test script\n"
        )
        return scripts_dir

    def _seed_custom_content(self, scripts_dir):
        """Generate a canonical INDEX.md, then hand-edit both preserved
        regions into it so the fixture matches the generated skeleton."""
        index_path = scripts_dir / "INDEX.md"
        run_indexer("--dir", str(scripts_dir))
        content = index_path.read_text()
        header = "| Link | Description |"
        head, rest = content.split(header, 1)
        seeded = head + self.CUSTOM_BLOCK + "\n\n" + header + rest
        seeded = seeded.rstrip("\n") + "\n\n" + self.TRAILING_BLOCK + "\n"
        index_path.write_text(seeded)
        return index_path

    def test_preserved_content_byte_identical_across_regen(self, tmp_path):
        """A no-op rerun leaves the seeded file untouched (byte-identical);
        a genuine content change rewrites the table but keeps both
        preserved regions; a further rerun is a no-op again."""
        scripts_dir = self._make_scripts_dir(tmp_path)
        index_path = self._seed_custom_content(scripts_dir)
        seeded = index_path.read_text()

        # No-op rerun: byte-identical file, nothing written.
        stdout, stderr, rc = run_indexer("--dir", str(scripts_dir))
        assert rc == 0, f"Expected exit 0, got {rc}. stderr: {stderr}"
        assert stdout.strip() == "", (
            f"No-op rerun should not rewrite, got: {stdout}"
        )
        assert index_path.read_text() == seeded

        # Genuine content change: table rewritten, preserved regions kept.
        (scripts_dir / "extra.sh").write_text(
            "#!/usr/bin/env bash\n# extra.sh -- An extra script\n"
        )
        stdout, stderr, rc = run_indexer("--dir", str(scripts_dir))
        assert rc == 0, f"Expected exit 0, got {rc}. stderr: {stderr}"
        assert stdout.strip() != "", "Changed content should be rewritten"
        content = index_path.read_text()
        assert "[extra.sh](./extra.sh)" in content
        assert self.CUSTOM_BLOCK in content, "Pre-table region dropped"
        assert self.TRAILING_BLOCK in content, "Post-table region dropped"

        # Rerun after the rewrite is a no-op again: preservation round-trips.
        stdout, _, rc = run_indexer("--dir", str(scripts_dir))
        assert rc == 0
        assert stdout.strip() == ""
        assert index_path.read_text() == content

    def test_missing_table_header_aborts_regeneration(self, tmp_path):
        """A generated-looking INDEX.md with no "| Link |" table line must
        abort the run (non-zero exit, diagnostic on stderr) without
        touching the file, instead of being silently overwritten."""
        scripts_dir = self._make_scripts_dir(tmp_path)
        index_path = scripts_dir / "INDEX.md"
        run_indexer("--dir", str(scripts_dir))
        header = "| Link | Description |"
        no_table = index_path.read_text().split(header)[0].rstrip("\n") + "\n"
        index_path.write_text(no_table)
        before = index_path.read_text()

        stdout, stderr, rc = run_indexer("--dir", str(scripts_dir))
        assert rc != 0, (
            f"Expected non-zero exit for an unpreservable index, got {rc}"
        )
        assert "refusing to regenerate" in stderr, (
            f"Expected a diagnostic on stderr, got: {stderr}"
        )
        assert index_path.read_text() == before, (
            "Failed run must not modify the existing INDEX.md"
        )


class TestLibDirectoryRecursion:
    """Helper-library subdirectories (scripts/lib/) are indexed under
    their relative path, and non-script files inside them are excluded."""

    def test_lib_scripts_indexed_and_non_scripts_excluded(self, tmp_path):
        """A .sh and a .py in lib/ render as lib/<name> rows; a .txt in
        the same directory is excluded from the generated table."""
        scripts_dir = tmp_path / "scripts"
        lib_dir = scripts_dir / "lib"
        lib_dir.mkdir(parents=True)
        (lib_dir / "helper.sh").write_text(
            "#!/usr/bin/env bash\n# helper.sh -- A shell helper\n"
        )
        (lib_dir / "helper.py").write_text(
            '#!/usr/bin/env python3\n"""\nhelper.py -- A python helper.\n"""\n'
        )
        (lib_dir / "notes.txt").write_text("not a script\n")

        stdout, stderr, rc = run_indexer("--dir", str(scripts_dir))
        assert rc == 0, f"Expected exit 0, got {rc}. stderr: {stderr}"

        content = (scripts_dir / "INDEX.md").read_text()
        assert "| [lib/helper.sh](./lib/helper.sh) | A shell helper |" in content
        assert "| [lib/helper.py](./lib/helper.py) | A python helper. |" in content
        assert "notes.txt" not in content
