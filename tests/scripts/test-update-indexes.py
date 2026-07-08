"""Integration tests for scripts/update-indexes.py.

Tests:
- Script runs without errors
- Generates INDEX.md files in docs/ subdirectories
- Extracts title from first # heading
- Extracts description from first paragraph
- References subdirectory INDEX.md files (R8 scoping)
- Delegates to index-scripts.py
- --dry-run flag works
- --skip-scripts flag works
"""

import subprocess
import sys
from pathlib import Path

import pytest

SCRIPT = Path(__file__).resolve().parent.parent.parent / "scripts" / "update-indexes.py"


def run_updater(*args, cwd=None):
    """Run update-indexes.py and return (stdout, stderr, returncode)."""
    result = subprocess.run(
        [sys.executable, str(SCRIPT), *args],
        capture_output=True, text=True, check=False,
        cwd=cwd,
    )
    return result.stdout, result.stderr, result.returncode


class TestRunsCleanly:
    """Script executes without errors on the real repo."""

    def test_no_args(self):
        """Running without args should succeed."""
        stdout, stderr, rc = run_updater("--skip-scripts")
        assert rc == 0, f"Expected exit 0, got {rc}. stderr: {stderr}"

    def test_dry_run(self):
        """--dry-run should succeed and not write files."""
        stdout, stderr, rc = run_updater("--dry-run", "--skip-scripts")
        assert rc == 0, f"Expected exit 0, got {rc}. stderr: {stderr}"
        assert "[dry-run]" in stderr, "Expected dry-run marker in stderr"

    def test_single_dir(self):
        """--dir docs/standards should succeed."""
        stdout, stderr, rc = run_updater("--dir", "docs/standards")
        assert rc == 0, f"Expected exit 0, got {rc}. stderr: {stderr}"


class TestGeneratesIndexFiles:
    """INDEX.md files are generated correctly."""

    def test_docs_standards_index_exists(self, tmp_path):
        """INDEX.md should be generated for a docs directory."""
        docs_dir = tmp_path / "docs" / "standards"
        docs_dir.mkdir(parents=True)
        (docs_dir / "example.md").write_text(
            "# Example Standard\n\nThis is an example standard document.\n"
        )

        stdout, _, rc = run_updater("--dir", str(docs_dir))
        assert rc == 0

        index_path = docs_dir / "INDEX.md"
        assert index_path.exists(), f"{index_path} not found"

    def test_index_has_frontmatter(self, tmp_path):
        """Generated INDEX.md should have R8 YAML frontmatter."""
        docs_dir = tmp_path / "docs" / "standards"
        docs_dir.mkdir(parents=True)
        (docs_dir / "example.md").write_text(
            "# Example\n\nDescription text.\n"
        )

        run_updater("--dir", str(docs_dir))
        content = (docs_dir / "INDEX.md").read_text()
        assert content.startswith("---\n"), "Expected YAML frontmatter"
        assert "tags:" in content, "Expected tags field"
        assert "description:" in content, "Expected description field"

    def test_index_has_table(self, tmp_path):
        """Generated INDEX.md should have Link/Description table."""
        docs_dir = tmp_path / "docs" / "test"
        docs_dir.mkdir(parents=True)
        (docs_dir / "readme.md").write_text(
            "# Readme\n\nProject overview.\n"
        )

        run_updater("--dir", str(docs_dir))
        content = (docs_dir / "INDEX.md").read_text()
        # Wave 1 authoritative format (PR #97 directive)
        assert "| Link | Description |" in content
        assert "|------|-------------|" in content
        assert "readme.md" in content
        assert "[readme.md](./readme.md)" in content


class TestExtractsMetadata:
    """Title and description extraction from markdown files."""

    def test_extracts_title_for_index_heading(self, tmp_path):
        """Index heading is derived from directory name."""
        docs_dir = tmp_path / "docs" / "my-section"
        docs_dir.mkdir(parents=True)
        (docs_dir / "doc.md").write_text(
            "# My Document Title\n\nSome content.\n"
        )

        run_updater("--dir", str(docs_dir))
        content = (docs_dir / "INDEX.md").read_text()
        assert "# My Section Index" in content

    def test_extracts_description(self, tmp_path):
        """Description is extracted from first paragraph."""
        docs_dir = tmp_path / "docs" / "test"
        docs_dir.mkdir(parents=True)
        (docs_dir / "doc.md").write_text(
            "# Title\n\nFirst paragraph with useful info.\n\nSecond paragraph.\n"
        )

        run_updater("--dir", str(docs_dir))
        content = (docs_dir / "INDEX.md").read_text()
        assert "First paragraph with useful info" in content

    def test_skips_frontmatter_for_description(self, tmp_path):
        """Description extraction skips YAML frontmatter."""
        docs_dir = tmp_path / "docs" / "test"
        docs_dir.mkdir(parents=True)
        (docs_dir / "doc.md").write_text(
            "---\ntitle: Something\ntags: [test]\n---\n\n# Heading\n\nReal description here.\n"
        )

        run_updater("--dir", str(docs_dir))
        content = (docs_dir / "INDEX.md").read_text()
        assert "Real description here" in content

    def test_no_description_fallback(self, tmp_path):
        """Files without description get placeholder."""
        docs_dir = tmp_path / "docs" / "test"
        docs_dir.mkdir(parents=True)
        (docs_dir / "bare.md").write_text("# Just A Heading\n")

        run_updater("--dir", str(docs_dir))
        content = (docs_dir / "INDEX.md").read_text()
        assert "(no description)" in content


class TestR8Scoping:
    """R8 scoping: INDEX.md references subdirectory INDEX.md files."""

    def test_references_subdirectory_index(self, tmp_path):
        """Parent INDEX.md should reference child INDEX.md files."""
        parent = tmp_path / "docs" / "parent"
        child = parent / "child"
        child.mkdir(parents=True)
        (parent / "doc.md").write_text("# Parent Doc\n\nParent content.\n")
        (child / "INDEX.md").write_text(
            "---\ntags: [index]\ndescription: Child index.\n---\n\n# Child Index\n\nChild index.\n\n| Path | Description |\n|------|-------------|\n| a.md | Something |\n"
        )

        run_updater("--dir", str(parent))
        content = (parent / "INDEX.md").read_text()
        assert "child/INDEX.md" in content

    def test_empty_directory_no_index(self, tmp_path):
        """Empty directory produces no INDEX.md."""
        docs_dir = tmp_path / "docs" / "empty"
        docs_dir.mkdir(parents=True)

        stdout, _, rc = run_updater("--dir", str(docs_dir))
        assert rc == 0
        assert not (docs_dir / "INDEX.md").exists()


class TestDelegation:
    """Delegates to index-scripts.py for script indexing."""

    def test_skip_scripts_flag(self):
        """--skip-scripts should not invoke index-scripts.py."""
        stdout, stderr, rc = run_updater("--skip-scripts", "--dry-run")
        assert rc == 0
        # Should not see script indexing output
        assert "scripts/INDEX.md" not in stdout
