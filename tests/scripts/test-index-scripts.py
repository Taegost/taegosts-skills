"""Integration tests for scripts/index-scripts.py.

Tests:
- Script runs without errors
- Generates INDEX.md files
- Extracts R3 frontmatter from .sh files
- Extracts descriptions from .py docstrings
- Handles scripts without frontmatter gracefully
- R8 format compliance (frontmatter, table structure)
"""

import json
import subprocess
import sys
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
        """Running without args should succeed and produce output."""
        stdout, stderr, rc = run_indexer()
        assert rc == 0, f"Expected exit 0, got {rc}. stderr: {stderr}"
        assert "INDEX.md" in stdout, "Expected INDEX.md path in stdout"

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
        index_path = Path(stdout.strip().splitlines()[0])
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
        """Skills with scripts/ dirs should get INDEX.md files."""
        stdout, _, rc = run_indexer()
        assert rc == 0
        lines = stdout.strip().splitlines()
        skill_indexes = [line for line in lines if "skills/" in line and "INDEX.md" in line]
        assert len(skill_indexes) > 0, "Expected at least one skill INDEX.md"
