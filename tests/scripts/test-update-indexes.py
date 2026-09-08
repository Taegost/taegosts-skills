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
- Emits the script path resolution note
- Regeneration is content-idempotent (created-date preservation, no-op on
  unchanged content)
- A hand-maintained non-default "owner:" frontmatter field survives
  regeneration
- ALL hand-maintained content survives regeneration: "## " sections,
  heading-less paragraphs between the resolution note and the table, and
  trailing content after the table; a generated-looking INDEX.md with no
  table aborts the run instead of being overwritten
"""

import importlib.util
import re
import subprocess
import sys
from datetime import date
from pathlib import Path
from unittest import mock

import pytest

SCRIPT = Path(__file__).resolve().parent.parent.parent / "scripts" / "update-indexes.py"
LIB_COMMON = SCRIPT.parent / "lib" / "index_common.py"


def _load_module():
    """Import update-indexes.py directly (hyphenated filename, not a valid
    module name) so its functions can be unit-tested without subprocess."""
    spec = importlib.util.spec_from_file_location("update_indexes", SCRIPT)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


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

    def test_single_dir(self, tmp_path):
        """--dir <docs subdir> should succeed (tmp copy — must not touch the real tree)."""
        docs_dir = tmp_path / "docs" / "standards"
        docs_dir.mkdir(parents=True)
        (docs_dir / "example.md").write_text(
            "# Example Standard\n\nThis is an example standard document.\n"
        )
        stdout, stderr, rc = run_updater("--dir", str(docs_dir))
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


class TestResolutionNoteAndIdempotency:
    """Resolution note is emitted and regeneration is content-idempotent."""

    def _make_docs_dir(self, tmp_path):
        docs_dir = tmp_path / "docs" / "standards"
        docs_dir.mkdir(parents=True)
        (docs_dir / "example.md").write_text(
            "# Example Standard\n\nThis is an example standard document.\n"
        )
        return docs_dir

    def test_resolution_note_present(self, tmp_path):
        """Generated INDEX.md carries the path resolution note after the intro."""
        docs_dir = self._make_docs_dir(tmp_path)

        run_updater("--dir", str(docs_dir))
        content = (docs_dir / "INDEX.md").read_text()
        assert "Paths below are relative to this index's directory." in content
        assert "${CLAUDE_PLUGIN_ROOT}/<repo-relative-path>" in content
        # Note sits between the intro description line and the table
        assert content.index("# Standards Index") \
            < content.index("Paths below are relative to this index's directory.") \
            < content.index("| Link | Description |")

    def test_second_run_leaves_file_untouched(self, tmp_path):
        """Regenerating unchanged content writes nothing and prints nothing."""
        docs_dir = self._make_docs_dir(tmp_path)
        index_path = docs_dir / "INDEX.md"

        run_updater("--dir", str(docs_dir))
        before = index_path.read_text()

        stdout, _, rc = run_updater("--dir", str(docs_dir))
        assert rc == 0
        assert stdout.strip() == "", (
            f"Second run should not report any written file, got: {stdout}"
        )
        assert index_path.read_text() == before

    def test_created_date_preserved_and_content_change_bumps_last_updated(self, tmp_path):
        """Existing created date survives regeneration; genuine changes bump
        only last-updated."""
        docs_dir = self._make_docs_dir(tmp_path)
        index_path = docs_dir / "INDEX.md"
        today = date.today().isoformat()

        run_updater("--dir", str(docs_dir))
        # Simulate an older index by backdating both frontmatter dates.
        backdated = (index_path.read_text()
                     .replace(f"created: {today}", "created: 2020-01-01")
                     .replace(f"last-updated: {today}", "last-updated: 2020-01-01"))
        index_path.write_text(backdated)

        # Unchanged content: file untouched, backdated created survives.
        stdout, _, rc = run_updater("--dir", str(docs_dir))
        assert rc == 0
        assert stdout.strip() == ""
        assert "created: 2020-01-01" in index_path.read_text()

        # Genuine content change: regenerated with created preserved and
        # last-updated bumped to today.
        (docs_dir / "extra.md").write_text("# Extra\n\nExtra content.\n")
        stdout, _, rc = run_updater("--dir", str(docs_dir))
        assert rc == 0
        assert stdout.strip() != "", "Changed content should be rewritten"
        content = index_path.read_text()
        assert "created: 2020-01-01" in content
        assert f"last-updated: {today}" in content
        assert "[extra.md](./extra.md)" in content


class TestOwnerPreservation:
    """A hand-maintained non-default owner survives regeneration."""

    def _make_docs_dir(self, tmp_path):
        docs_dir = tmp_path / "docs" / "standards"
        docs_dir.mkdir(parents=True)
        (docs_dir / "example.md").write_text(
            "# Example Standard\n\nThis is an example standard document.\n"
        )
        return docs_dir

    def test_existing_owner_preserved_and_content_change_keeps_it(self, tmp_path):
        """A pre-existing non-default owner field survives regeneration,
        both on a no-op re-run and after genuine content changes."""
        docs_dir = self._make_docs_dir(tmp_path)
        index_path = docs_dir / "INDEX.md"
        today = date.today().isoformat()

        run_updater("--dir", str(docs_dir))
        # Hand-set a non-default owner the way a plan-indexing pass would.
        hand_set = re.sub(r"(?m)^owner: .*$",
                          "owner: issue-90-ts-compound-refresh-port",
                          index_path.read_text())
        index_path.write_text(hand_set)

        # Unchanged content: file untouched, hand-set owner survives.
        stdout, _, rc = run_updater("--dir", str(docs_dir))
        assert rc == 0
        assert stdout.strip() == ""
        assert "owner: issue-90-ts-compound-refresh-port" in index_path.read_text()

        # Genuine content change: rewritten with the owner preserved and
        # last-updated bumped to today.
        (docs_dir / "extra.md").write_text("# Extra\n\nExtra content.\n")
        stdout, _, rc = run_updater("--dir", str(docs_dir))
        assert rc == 0
        assert stdout.strip() != "", "Changed content should be rewritten"
        content = index_path.read_text()
        assert "owner: issue-90-ts-compound-refresh-port" in content
        assert f"last-updated: {today}" in content
        assert "[extra.md](./extra.md)" in content


class TestStagesGeneratedFiles:
    """Generated INDEX.md files are git-staged so a pre-commit run needs no
    manual re-add (regression test for the hook silently missing regenerated
    indexes).

    update-indexes.py derives repo_root from its own __file__ location, so
    to test staging in isolation the script itself must be copied into a
    throwaway git repo rather than invoked against a foreign path.
    """

    def _make_isolated_repo(self, tmp_path):
        """Create a throwaway git repo containing the generator, its lib
        module, and one docs directory, with everything committed."""
        repo = tmp_path / "repo"
        (repo / "scripts" / "lib").mkdir(parents=True)
        (repo / "scripts" / "update-indexes.py").write_text(
            SCRIPT.read_text(encoding="utf-8"), encoding="utf-8"
        )
        # The generator imports its shared lib module at startup, so the
        # throwaway repo needs a copy of scripts/lib/ too.
        (repo / "scripts" / "lib" / "index_common.py").write_text(
            LIB_COMMON.read_text(encoding="utf-8"), encoding="utf-8"
        )
        docs_dir = repo / "docs" / "standards"
        docs_dir.mkdir(parents=True)
        (docs_dir / "example.md").write_text(
            "# Example Standard\n\nThis is an example standard document.\n"
        )
        subprocess.run(["git", "init", "-q"], cwd=repo, check=True)
        subprocess.run(
            ["git", "-c", "user.email=t@t.com", "-c", "user.name=t",
             "add", "-A"],
            cwd=repo, check=True,
        )
        subprocess.run(
            ["git", "-c", "user.email=t@t.com", "-c", "user.name=t",
             "commit", "-q", "-m", "init"],
            cwd=repo, check=True,
        )
        return repo, docs_dir

    def test_generated_index_is_staged_in_git_repo(self, tmp_path):
        """Running inside a git repo should `git add` the generated INDEX.md."""
        repo, docs_dir = self._make_isolated_repo(tmp_path)

        result = subprocess.run(
            [sys.executable, str(repo / "scripts" / "update-indexes.py"),
             "--dir", str(docs_dir), "--skip-scripts"],
            cwd=repo, capture_output=True, text=True, check=False,
        )
        assert result.returncode == 0, f"stderr: {result.stderr}"

        status = subprocess.run(
            ["git", "status", "--porcelain"],
            cwd=repo, capture_output=True, text=True, check=True,
        ).stdout
        assert "A  docs/standards/INDEX.md" in status.replace("\\", "/"), (
            f"Expected generated INDEX.md to be staged, got:\n{status}"
        )

    def test_outside_repo_dir_does_not_error(self, tmp_path):
        """--dir pointing outside any git repo should still succeed (staging
        is silently skipped rather than failing the run)."""
        docs_dir = tmp_path / "docs" / "standards"
        docs_dir.mkdir(parents=True)
        (docs_dir / "example.md").write_text("# Example\n\nText.\n")

        stdout, stderr, rc = run_updater("--dir", str(docs_dir))
        assert rc == 0, f"stderr: {stderr}"


class TestTempFileFailureHandling:
    """process_directory's atomic-write error path must not crash with
    NameError if NamedTemporaryFile itself raises before tmp_path is
    assigned (regression test)."""

    def test_named_temp_file_failure_exits_cleanly(self, tmp_path, capsys):
        module = _load_module()
        docs_dir = tmp_path / "docs" / "standards"
        docs_dir.mkdir(parents=True)
        (docs_dir / "example.md").write_text("# Example\n\nText.\n")

        with mock.patch(
            "tempfile.NamedTemporaryFile",
            side_effect=OSError("simulated disk failure"),
        ):
            with pytest.raises(SystemExit) as exc_info:
                module.process_directory(docs_dir, tmp_path, dry_run=False)

        assert exc_info.value.code == 1
        captured = capsys.readouterr()
        assert "simulated disk failure" in captured.err
        assert "NameError" not in captured.err


def _split_preserved_regions(content):
    """Return the (pre-table, post-table) hand-maintained regions of an
    INDEX.md verbatim, for byte-identical preservation assertions."""
    lines = content.splitlines()
    note_idx = next(i for i, ln in enumerate(lines)
                    if ln.startswith("Paths below are relative"))
    table_idx = next(i for i, ln in enumerate(lines)
                     if ln.startswith("| Link |"))
    table_end = table_idx
    while table_end < len(lines) and lines[table_end].startswith("|"):
        table_end += 1
    pre_table = "\n".join(lines[note_idx + 1:table_idx]).strip("\n")
    post_table = "\n".join(lines[table_end:]).strip("\n")
    return pre_table, post_table


class TestHandMaintainedContentPreservation:
    """ALL hand-maintained content survives regeneration: "## " sections,
    heading-less paragraphs between the resolution note and the table, and
    trailing content after the table. Regression coverage for the silent
    drop of non-"## " content on regeneration."""

    CUSTOM_BLOCK = (
        "## Custom Section\n"
        "\n"
        "A hand-maintained paragraph with no heading marker of its own.\n"
        "\n"
        "- preserved bullet one\n"
        "- preserved bullet two"
    )
    TRAILING_BLOCK = (
        "Hand-maintained footer paragraph after the table.\n"
        "\n"
        "Second footer paragraph."
    )

    def _make_docs_dir(self, tmp_path):
        """Create a docs directory holding one indexed markdown file."""
        docs_dir = tmp_path / "docs" / "standards"
        docs_dir.mkdir(parents=True)
        (docs_dir / "example.md").write_text(
            "# Example Standard\n\nThis is an example standard document.\n"
        )
        return docs_dir

    def _seed_custom_content(self, docs_dir):
        """Generate a canonical INDEX.md, then hand-edit both preserved
        regions into it so the fixture matches the generated skeleton."""
        index_path = docs_dir / "INDEX.md"
        run_updater("--dir", str(docs_dir))
        content = index_path.read_text()
        header = "| Link | Description |"
        head, rest = content.split(header, 1)
        seeded = head + self.CUSTOM_BLOCK + "\n\n" + header + rest
        seeded = seeded.rstrip("\n") + "\n\n" + self.TRAILING_BLOCK + "\n"
        index_path.write_text(seeded)
        return index_path

    def test_preserved_content_byte_identical_across_regen(self, tmp_path):
        """A no-op rerun leaves the seeded file untouched; a genuine content
        change to a linked entry rewrites the table but keeps every
        preserved byte of both regions; a further rerun is a no-op again
        (the preservation round-trip is stable)."""
        docs_dir = self._make_docs_dir(tmp_path)
        index_path = self._seed_custom_content(docs_dir)
        seeded = index_path.read_text()

        # No-op rerun: byte-identical file, nothing written.
        stdout, stderr, rc = run_updater("--dir", str(docs_dir))
        assert rc == 0, f"Expected exit 0, got {rc}. stderr: {stderr}"
        assert stdout.strip() == "", (
            f"No-op rerun should not rewrite, got: {stdout}"
        )
        assert index_path.read_text() == seeded

        # Genuine content change to a linked entry: table rewritten,
        # preserved regions byte-identical.
        (docs_dir / "example.md").write_text(
            "# Example Standard\n\nThis is an UPDATED standard document.\n"
        )
        stdout, stderr, rc = run_updater("--dir", str(docs_dir))
        assert rc == 0, f"Expected exit 0, got {rc}. stderr: {stderr}"
        assert stdout.strip() != "", "Changed content should be rewritten"
        content = index_path.read_text()
        assert "This is an UPDATED standard document." in content
        pre_table, post_table = _split_preserved_regions(content)
        assert pre_table == self.CUSTOM_BLOCK, (
            f"Pre-table region altered.\nExpected:\n{self.CUSTOM_BLOCK}"
            f"\nGot:\n{pre_table}"
        )
        assert post_table == self.TRAILING_BLOCK, (
            f"Post-table region altered.\nExpected:\n{self.TRAILING_BLOCK}"
            f"\nGot:\n{post_table}"
        )

        # Rerun after the rewrite is a no-op again: preservation round-trips.
        stdout, _, rc = run_updater("--dir", str(docs_dir))
        assert rc == 0
        assert stdout.strip() == ""
        assert index_path.read_text() == content

    def test_missing_table_header_aborts_regeneration(self, tmp_path):
        """A generated-looking INDEX.md with no "| Link |" table line must
        abort the run (non-zero exit, diagnostic on stderr) without
        touching the file, instead of being silently overwritten."""
        docs_dir = self._make_docs_dir(tmp_path)
        index_path = docs_dir / "INDEX.md"
        run_updater("--dir", str(docs_dir))
        header = "| Link | Description |"
        no_table = index_path.read_text().split(header)[0].rstrip("\n") + "\n"
        index_path.write_text(no_table)
        before = index_path.read_text()

        stdout, stderr, rc = run_updater("--dir", str(docs_dir))
        assert rc != 0, (
            f"Expected non-zero exit for an unpreservable index, got {rc}"
        )
        assert "refusing to regenerate" in stderr, (
            f"Expected a diagnostic on stderr, got: {stderr}"
        )
        assert index_path.read_text() == before, (
            "Failed run must not modify the existing INDEX.md"
        )
