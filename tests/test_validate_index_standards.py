"""Tests for scripts/validate-index-standards.py R7/R8 validation."""

import subprocess
import sys
from pathlib import Path
from typing import Optional

import pytest

SCRIPT = Path(__file__).resolve().parent.parent / "scripts" / "validate-index-standards.py"


def run_validator(content: str, filename: str = "INDEX.md", tmp_path: Optional[Path] = None):
    """Run the validator on a temp file and return the parsed result dict."""
    if tmp_path is None:
        import tempfile
        with tempfile.NamedTemporaryFile(mode="w", suffix=filename, delete=False, dir=".") as f:
            f.write(content)
            f.flush()
            path = Path(f.name)
    else:
        path = tmp_path / filename
        path.write_text(content, encoding="utf-8")

    result = subprocess.run(
        [sys.executable, str(SCRIPT), str(path)],
        capture_output=True, text=True, check=False
    )
    import json
    output = json.loads(result.stderr)
    file_result = output["results"][0] if output["results"] else {}
    return file_result, result.returncode


# ── R7 Fixtures ──

class TestR7Links:
    """R7: All markdown links must use [name](uri) format."""

    def test_compliant_links(self, tmp_path):
        """Valid [name](uri) links should pass."""
        content = "# Test\n\n[Example](https://example.com)\n[Docs](./docs/README.md)\n"
        result, _ = run_validator(content, "test.md", tmp_path)
        r7_violations = [v for v in result.get("violations", []) if v["rule"] == "R7"]
        assert r7_violations == [], f"Expected no R7 violations, got {r7_violations}"

    def test_bare_url_in_parens(self, tmp_path):
        """Bare URL in parentheses without link text should be flagged."""
        content = "# Test\n\nSee (https://example.com) for details.\n"
        result, _ = run_validator(content, "test.md", tmp_path)
        r7_violations = [v for v in result.get("violations", []) if v["rule"] == "R7"]
        assert len(r7_violations) >= 1
        assert "https://example.com" in r7_violations[0]["message"]

    def test_bare_url_standalone(self, tmp_path):
        """Standalone bare URL should be flagged."""
        content = "# Test\n\nVisit https://example.com for info.\n"
        result, _ = run_validator(content, "test.md", tmp_path)
        r7_violations = [v for v in result.get("violations", []) if v["rule"] == "R7"]
        assert len(r7_violations) >= 1
        assert "https://example.com" in r7_violations[0]["message"]

    def test_url_in_fenced_code_block_ignored(self, tmp_path):
        """URLs inside fenced code blocks should NOT be flagged."""
        content = (
            "# Test\n\n"
            "```bash\ncurl https://example.com/api/v1\n```\n\n"
            "Some text after.\n"
        )
        result, _ = run_validator(content, "test.md", tmp_path)
        r7_violations = [v for v in result.get("violations", []) if v["rule"] == "R7"]
        assert r7_violations == [], f"Code block URLs should be ignored, got {r7_violations}"

    def test_url_in_inline_code_ignored(self, tmp_path):
        """URLs inside inline code spans should NOT be flagged."""
        content = "# Test\n\nRun `curl https://example.com` to test.\n"
        result, _ = run_validator(content, "test.md", tmp_path)
        r7_violations = [v for v in result.get("violations", []) if v["rule"] == "R7"]
        assert r7_violations == [], f"Inline code URLs should be ignored, got {r7_violations}"

    def test_url_with_trailing_punctuation(self, tmp_path):
        """URL followed by punctuation should strip trailing chars."""
        content = "# Test\n\nSee https://example.com.\n"
        result, _ = run_validator(content, "test.md", tmp_path)
        r7_violations = [v for v in result.get("violations", []) if v["rule"] == "R7"]
        assert len(r7_violations) >= 1
        # URL should not include the trailing period
        assert "https://example.com" in r7_violations[0]["message"]
        assert "https://example.com." not in r7_violations[0]["message"]

    def test_url_after_space_in_parens(self, tmp_path):
        """URL after space inside parens like [text]( url) should be recognized as a link."""
        content = "# Test\n\n[Example]( https://example.com)\n"
        result, _ = run_validator(content, "test.md", tmp_path)
        r7_violations = [v for v in result.get("violations", []) if v["rule"] == "R7"]
        assert r7_violations == [], f"Space-in-parens link should not be flagged, got {r7_violations}"

    def test_url_in_second_code_block(self, tmp_path):
        """URL in second fenced code block (after toggle back) should be ignored."""
        content = (
            "# Test\n\n"
            "```\nfirst block\n```\n\n"
            "```\ncurl https://example.com\n```\n"
        )
        result, _ = run_validator(content, "test.md", tmp_path)
        r7_violations = [v for v in result.get("violations", []) if v["rule"] == "R7"]
        assert r7_violations == [], f"Second code block URLs should be ignored, got {r7_violations}"


# ── R8 Fixtures ──

class TestR8Index:
    """R8: INDEX.md must have YAML frontmatter, Link/Description table, and scoped references."""

    def test_compliant_index(self, tmp_path):
        """A well-formed INDEX.md should pass R8 checks."""
        content = (
            "---\ntags: [index]\ndescription: Test index\n---\n\n"
            "# Index\n\n"
            "| Link | Description |\n"
            "|------|-------------|\n"
            "| [readme](readme.md) | Project readme |\n"
        )
        result, _ = run_validator(content, "INDEX.md", tmp_path)
        r8_violations = [v for v in result.get("violations", []) if v["rule"] == "R8"]
        assert r8_violations == [], f"Expected no R8 violations, got {r8_violations}"

    def test_missing_frontmatter(self, tmp_path):
        """INDEX.md without YAML frontmatter should fail."""
        content = "# Index\n\n| Link | Description |\n|------|-------------|\n| [readme](readme.md) | Readme |\n"
        result, _ = run_validator(content, "INDEX.md", tmp_path)
        r8_violations = [v for v in result.get("violations", []) if v["rule"] == "R8"]
        assert any("frontmatter" in v["message"].lower() for v in r8_violations)

    def test_missing_tags_field(self, tmp_path):
        """Frontmatter without tags should fail."""
        content = "---\ndescription: Test\n---\n\n| Link | Description |\n|------|-------------|\n| [x](x.md) | X |\n"
        result, _ = run_validator(content, "INDEX.md", tmp_path)
        r8_violations = [v for v in result.get("violations", []) if v["rule"] == "R8"]
        assert any("tags" in v["message"].lower() for v in r8_violations)

    def test_missing_description_field(self, tmp_path):
        """Frontmatter without description should fail."""
        content = "---\ntags: [index]\n---\n\n| Link | Description |\n|------|-------------|\n| [x](x.md) | X |\n"
        result, _ = run_validator(content, "INDEX.md", tmp_path)
        r8_violations = [v for v in result.get("violations", []) if v["rule"] == "R8"]
        assert any("description" in v["message"].lower() for v in r8_violations)

    def test_wrong_table_columns(self, tmp_path):
        """Table without Link/Description columns should fail."""
        content = "---\ntags: [index]\ndescription: Test\n---\n\n| Name | Path |\n|------|------|\n| [x](x.md) | X |\n"
        result, _ = run_validator(content, "INDEX.md", tmp_path)
        r8_violations = [v for v in result.get("violations", []) if v["rule"] == "R8"]
        assert any("table" in v["message"].lower() or "link" in v["message"].lower() for v in r8_violations)

    def test_out_of_scope_link(self, tmp_path):
        """Link referencing file outside parent folder should fail (non-ROUTING.md)."""
        # Create a subdirectory structure
        subdir = tmp_path / "subdir"
        subdir.mkdir()
        content = (
            "---\ntags: [index]\ndescription: Test\n---\n\n"
            "| Link | Description |\n"
            "|------|-------------|\n"
            "| [outside](../outside.md) | Out of scope |\n"
        )
        result, _ = run_validator(content, "INDEX.md", subdir)
        r8_violations = [v for v in result.get("violations", []) if v["rule"] == "R8"]
        assert any("outside" in v["message"].lower() or "scope" in v["message"].lower() for v in r8_violations)

    def test_routing_md_exception(self, tmp_path):
        """docs/ROUTING.md may reference files outside its parent folder."""
        docs_dir = tmp_path / "docs"
        docs_dir.mkdir()
        content = (
            "---\ntags: [index]\ndescription: Routing\n---\n\n"
            "| Link | Description |\n"
            "|------|-------------|\n"
            "| [scripts](../scripts/INDEX.md) | Script index |\n"
        )
        result, _ = run_validator(content, "ROUTING.md", docs_dir)
        r8_violations = [v for v in result.get("violations", []) if v["rule"] == "R8"]
        # ROUTING.md is exempt from scope check
        scope_violations = [v for v in r8_violations if "scope" in v["message"].lower() or "outside" in v["message"].lower()]
        assert scope_violations == [], f"ROUTING.md should be exempt from scope check, got {scope_violations}"


# ── extract_links code block tracking ──

class TestExtractLinks:
    """Verify extract_links skips fenced code blocks."""

    def test_links_in_code_blocks_ignored(self, tmp_path):
        """Links inside code blocks should not be extracted by extract_links."""
        # This is indirectly tested via R8 scope — a link inside a code block
        # pointing to an out-of-scope file should not trigger a scope violation.
        content = (
            "---\ntags: [index]\ndescription: Test\n---\n\n"
            "| Link | Description |\n"
            "|------|-------------|\n"
            "| [local](local.md) | Local |\n\n"
            "```markdown\n[Outside](https://example.com)\n```\n"
        )
        result, _ = run_validator(content, "INDEX.md", tmp_path)
        # No R8 scope violations from the code-block link
        r8_scope = [v for v in result.get("violations", []) if v["rule"] == "R8" and "scope" in v["message"].lower()]
        assert r8_scope == [], f"Code block links should not trigger scope violations, got {r8_scope}"


# ── Link reference definitions ──

class TestLinkReferenceDefinitions:
    """Verify R7 skips markdown link reference definitions."""

    def test_link_reference_definition_not_flagged(self, tmp_path):
        """[ref]: URL syntax should NOT be flagged as bare URLs."""
        content = "# Test\n\n[example]: https://example.com\n\n[example] link\n"
        result, _ = run_validator(content, "test.md", tmp_path)
        r7_violations = [v for v in result.get("violations", []) if v["rule"] == "R7"]
        assert r7_violations == [], f"Link reference definitions should not be flagged, got {r7_violations}"

    def test_link_reference_with_title(self, tmp_path):
        """[ref]: URL \"title\" syntax should NOT be flagged."""
        content = "# Test\n\n[ref]: https://example.com \"Example\"\n\nText.\n"
        result, _ = run_validator(content, "test.md", tmp_path)
        r7_violations = [v for v in result.get("violations", []) if v["rule"] == "R7"]
        assert r7_violations == [], f"Link reference with title should not be flagged, got {r7_violations}"


# ── R8 table edge cases ──

class TestR8TableEdgeCases:
    """Verify check_r8_table handles edge cases correctly."""

    def test_header_as_last_line(self, tmp_path):
        """Table header as the last line should fail (no separator row)."""
        content = "---\ntags: [index]\ndescription: Test\n---\n\n| Link | Description |\n"
        result, _ = run_validator(content, "INDEX.md", tmp_path)
        r8_violations = [v for v in result.get("violations", []) if v["rule"] == "R8"]
        table_violations = [v for v in r8_violations if "table" in v["message"].lower() or "link" in v["message"].lower()]
        assert table_violations != [], "Header without separator should fail R8"

    def test_table_with_only_link_column(self, tmp_path):
        """Table with only Link column (no Description) should fail."""
        content = (
            "---\ntags: [index]\ndescription: Test\n---\n\n"
            "| Link |\n"
            "|------|\n"
            "| [x](x.md) |\n"
        )
        result, _ = run_validator(content, "INDEX.md", tmp_path)
        r8_violations = [v for v in result.get("violations", []) if v["rule"] == "R8"]
        table_violations = [v for v in r8_violations if "table" in v["message"].lower() or "link" in v["message"].lower()]
        assert table_violations != [], "Table without Description column should fail R8"


# ── R8 scope with symlinks ──

class TestR8ScopeStrict:
    """Verify R8 scope check uses strict path comparison."""

    def test_symlink_outside_scope_flagged(self, tmp_path):
        """Symlink pointing outside parent folder should be flagged."""
        subdir = tmp_path / "subdir"
        subdir.mkdir()
        outside = tmp_path / "outside.md"
        outside.write_text("# Outside\n")
        # Create a symlink inside subdir pointing outside
        symlink = subdir / "link.md"
        symlink.symlink_to(outside)
        content = (
            "---\ntags: [index]\ndescription: Test\n---\n\n"
            "| Link | Description |\n"
            "|------|-------------|\n"
            "| [outside](link.md) | Symlinked outside |\n"
        )
        result, _ = run_validator(content, "INDEX.md", subdir)
        # The symlink target is outside the subdir, so it should be flagged
        # (unless .resolve() follows the symlink and finds it "inside")
        r8_scope = [v for v in result.get("violations", []) if v["rule"] == "R8" and ("outside" in v["message"].lower() or "scope" in v["message"].lower())]
        assert r8_scope != [], f"Symlink outside scope should be flagged, got {r8_scope}"


# ── Python version compatibility ──

class TestSyntaxCompatibility:
    """Ensure the script doesn't use syntax requiring Python 3.10+."""

    def test_no_pipe_union_syntax(self):
        """Script should not use `dict | None` syntax (Python 3.10+ only)."""
        content = SCRIPT.read_text(encoding="utf-8")
        # Check that the type hint uses Optional, not pipe union
        assert "Optional[dict]" in content, "Expected Optional[dict] for Python 3.9 compatibility"
        # Ensure no bare dict | None in type hints
        import ast
        try:
            ast.parse(content)
        except SyntaxError as e:
            pytest.fail(f"Script has syntax error: {e}")
