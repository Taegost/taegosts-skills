"""Unit tests for scripts/lib/index_common.py.

Covers the shared library's public surface directly (no subprocess):

- RESOLUTION_NOTE / DEFAULT_OWNER / TABLE_HEADER constants: exact values
  and shape (the note embeds the ${CLAUDE_PLUGIN_ROOT} substitution syntax)
- read_frontmatter_field: quoted and unquoted scalar values, absent field,
  absent frontmatter, unclosed frontmatter, valueless field, and the
  body-vs-frontmatter boundary
- differs_only_by_last_updated: identical text, text differing only in the
  last-updated line, text differing elsewhere, and a missing last-updated
  line in one input
- looks_generated: resolution-note fingerprint, index frontmatter tag,
  non-index tags, and the legacy no-marker shape
- extract_extra_sections: hand-maintained regions returned verbatim,
  empty regions returning None, IndexStructureError on a generated-looking
  file with no table, and the legacy first-"## " fallback anchor

Import bootstrap mirrors the generators (scripts/update-indexes.py,
scripts/index-scripts.py): scripts/lib/ is not on sys.path, so this file's
directory is added before the shared-module import below.
"""

import sys
from pathlib import Path

import pytest

_LIB_DIR = str(
    Path(__file__).resolve().parent.parent.parent / "scripts" / "lib")
if _LIB_DIR not in sys.path:
    sys.path.insert(0, _LIB_DIR)

from index_common import (  # noqa: E402
    DEFAULT_OWNER,
    RESOLUTION_NOTE,
    TABLE_HEADER,
    IndexStructureError,
    differs_only_by_last_updated,
    extract_extra_sections,
    looks_generated,
    read_frontmatter_field,
)


def generated_index(pre_table="", post_table="", rows=("| a.md | A |",),
                    owner=DEFAULT_OWNER):
    """Build a generated-looking INDEX.md: frontmatter, H1, intro, the
    resolution note, an optional pre-table hand-maintained region, the link
    table, and an optional post-table region."""
    lines = [
        "---",
        "created: 2025-01-01",
        f"owner: {owner}",
        "tags: [index, wave-2]",
        "---",
        "",
        "# Sample Index",
        "",
        "Intro description line.",
        "",
        RESOLUTION_NOTE,
    ]
    if pre_table:
        lines += pre_table.splitlines()
    lines += ["", TABLE_HEADER, "|------|-------------|"]
    lines += list(rows)
    if post_table:
        lines += [""] + post_table.splitlines()
    return "\n".join(lines) + "\n"


class TestModuleConstants:
    """The shared constants carry their contracted exact values."""

    def test_resolution_note_names_plugin_root_resolution(self):
        """The note tells the reader to resolve paths through
        ${CLAUDE_PLUGIN_ROOT} on marketplace installs."""
        assert "${CLAUDE_PLUGIN_ROOT}/<repo-relative-path>" in RESOLUTION_NOTE

    def test_resolution_note_shape(self):
        """The note opens with the relative-paths sentence, is a single
        line (generators emit it as one paragraph), and keeps the literal
        ${...} syntax (it is a plain constant, not an f-string)."""
        assert RESOLUTION_NOTE.startswith(
            "Paths below are relative to this index's directory.")
        assert "\n" not in RESOLUTION_NOTE
        assert "{" in RESOLUTION_NOTE and "}" in RESOLUTION_NOTE

    def test_default_owner_exact_value(self):
        """DEFAULT_OWNER is the known wave-2 automation owner string."""
        assert DEFAULT_OWNER == "wave-2-dispatch-index-automation"

    def test_table_header_exact_value(self):
        """TABLE_HEADER is the exact header line opening the link table."""
        assert TABLE_HEADER == "| Link | Description |"


class TestReadFrontmatterField:
    """Scalar frontmatter fields are read with quotes stripped."""

    def test_reads_double_quoted_value(self):
        """A double-quoted scalar value is returned unquoted."""
        content = '---\nowner: "quoted-owner"\n---\n\n# Title\n'
        assert read_frontmatter_field(content, "owner") == "quoted-owner"

    def test_reads_single_quoted_value(self):
        """A single-quoted scalar value is returned unquoted."""
        content = "---\nowner: 'single-owner'\n---\n\n# Title\n"
        assert read_frontmatter_field(content, "owner") == "single-owner"

    def test_reads_unquoted_value(self):
        """A bare scalar value is returned stripped of surrounding space."""
        content = "---\nowner: plain-owner\n---\n\n# Title\n"
        assert read_frontmatter_field(content, "owner") == "plain-owner"

    def test_absent_field_returns_none(self):
        """Frontmatter present but the requested field missing -> None."""
        content = "---\ntitle: T\ntags: [index]\n---\n\n# Title\n"
        assert read_frontmatter_field(content, "owner") is None

    def test_no_frontmatter_returns_none(self):
        """Content with no frontmatter block at all -> None."""
        assert read_frontmatter_field("# Just markdown\n", "owner") is None

    def test_unclosed_frontmatter_returns_none(self):
        """A frontmatter opener with no closing delimiter is not
        frontmatter -> None."""
        assert read_frontmatter_field("---\nowner: x\n", "owner") is None

    def test_field_without_value_returns_empty_string(self):
        """A field key with no value on the line yields the empty string
        (not None): the field is present, its value is empty."""
        content = "---\nowner:\ntags: [index]\n---\n\n# Title\n"
        assert read_frontmatter_field(content, "owner") == ""

    def test_body_occurrence_is_not_read(self):
        """A field-shaped line in the body does not count; only the
        frontmatter block is consulted."""
        content = "---\ntitle: T\n---\n\nowner: body-owner\n"
        assert read_frontmatter_field(content, "owner") is None


class TestDiffersOnlyByLastUpdated:
    """Content-idempotency comparison normalizes the last-updated line."""

    BASE = (
        "---\n"
        "created: 2025-01-01\n"
        "last-updated: 2025-06-01\n"
        "---\n"
        "\n"
        "# Index\n"
        "\n"
        "| Link | Description |\n"
        "|------|-------------|\n"
        "| a.md | A |\n"
    )

    def test_identical_text_is_true(self):
        """Byte-identical inputs differ by nothing, so True."""
        assert differs_only_by_last_updated(self.BASE, self.BASE) is True

    def test_only_last_updated_line_differing_is_true(self):
        """Swapping only the last-updated date normalizes away -> True."""
        other = self.BASE.replace("last-updated: 2025-06-01",
                                  "last-updated: 2026-09-08")
        assert other != self.BASE
        assert differs_only_by_last_updated(self.BASE, other) is True

    def test_differing_elsewhere_is_false(self):
        """A genuine content change (a table row) is not normalized
        away -> False."""
        other = self.BASE.replace("| a.md | A |", "| a.md | CHANGED |")
        assert differs_only_by_last_updated(self.BASE, other) is False

    def test_last_updated_absent_in_one_input_is_false(self):
        """Normalization rewrites an existing last-updated line but does
        not add one, so present-vs-absent is a real difference -> False."""
        other = self.BASE.replace("last-updated: 2025-06-01\n", "")
        assert differs_only_by_last_updated(self.BASE, other) is False


class TestLooksGenerated:
    """Generator fingerprints: the resolution note or an index tag."""

    def test_resolution_note_marks_generated(self):
        """A file embedding the resolution note is generator-maintained."""
        content = "# Title\n\nIntro.\n\n" + RESOLUTION_NOTE + "\n"
        assert looks_generated(content) is True

    def test_index_tag_marks_generated(self):
        """Frontmatter tags containing "index" mark the file as
        generator-maintained."""
        content = "---\ntags: [index, wave-2]\n---\n\n# Title\n"
        assert looks_generated(content) is True

    def test_non_index_tags_do_not_mark_generated(self):
        """Frontmatter tags without "index" carry no generator
        fingerprint."""
        content = "---\ntags: [guide, reference]\n---\n\n# Title\n"
        assert looks_generated(content) is False

    def test_reindex_tag_does_not_mark_generated(self):
        """A tag containing "index" only as a substring ("reindex") is not
        a generator fingerprint: only the exact token counts, so a
        hand-written file stays hand-written."""
        content = "---\ntags: [reindex]\n---\n\n# Title\n"
        assert looks_generated(content) is False

    def test_not_index_tag_does_not_mark_generated(self):
        """A hyphenated tag ("not-index") is not an index tag: substring
        matching would misclassify it, exact-token matching does not."""
        content = "---\ntags: [not-index]\n---\n\n# Title\n"
        assert looks_generated(content) is False

    def test_exact_index_tag_alone_marks_generated(self):
        """The bare [index] tag still marks the file as
        generator-maintained (guard against over-tightening the match)."""
        content = "---\ntags: [index]\n---\n\n# Title\n"
        assert looks_generated(content) is True

    def test_no_frontmatter_and_no_note_is_legacy(self):
        """A plain hand-written file (no frontmatter, no note) is treated
        as legacy hand-maintained."""
        assert looks_generated("# Hand written\n\nText.\n") is False

    def test_frontmatter_without_tags_is_not_generated(self):
        """Frontmatter present but no tags field and no note -> not
        generator-maintained."""
        content = "---\ntitle: T\nowner: someone\n---\n\n# Title\n"
        assert looks_generated(content) is False


class TestExtractExtraSections:
    """Hand-maintained regions are split out of an existing INDEX.md."""

    PRE_TABLE = (
        "## Custom Section\n"
        "\n"
        "A hand-maintained paragraph with no heading marker of its own.\n"
        "\n"
        "- preserved bullet one\n"
        "- preserved bullet two"
    )
    POST_TABLE = (
        "Footer paragraph after the table.\n"
        "\n"
        "## Trailing Section\n"
        "\n"
        "Trailing body."
    )

    def test_both_regions_returned_verbatim(self):
        """A "## " section and a heading-less paragraph between the note
        and the table, plus trailing content after the table, come back
        verbatim (surrounding blank lines stripped, interior blank lines
        preserved)."""
        content = generated_index(pre_table=self.PRE_TABLE,
                                  post_table=self.POST_TABLE)
        extra, trailing = extract_extra_sections(content)
        assert extra == self.PRE_TABLE
        assert trailing == self.POST_TABLE

    def test_no_extra_content_returns_none_none(self):
        """A canonical generated skeleton with nothing hand-maintained
        yields None for both regions."""
        extra, trailing = extract_extra_sections(generated_index())
        assert extra is None
        assert trailing is None

    def test_generated_without_table_raises(self):
        """A generated-looking file (resolution note or index tag) with no
        "| Link |" table header cannot have its hand-maintained regions
        located, so regeneration must abort with IndexStructureError."""
        with_note = (
            "---\n"
            f"owner: {DEFAULT_OWNER}\n"
            "---\n"
            "\n"
            "# Sample Index\n"
            "\n"
            "Intro description line.\n"
            "\n"
            + RESOLUTION_NOTE + "\n"
        )
        with_index_tag = (
            "---\ntags: [index]\n---\n\n# Sample Index\n\nIntro.\n"
        )
        for content in (with_note, with_index_tag):
            with pytest.raises(IndexStructureError) as excinfo:
                extract_extra_sections(content)
            assert "table header" in str(excinfo.value)

    def test_legacy_no_note_anchors_on_first_h2_before_table(self):
        """A pre-note file falls back to the first "## " heading before
        the table: that heading and everything down to the table is the
        preserved region."""
        legacy_h2 = (
            "## Preserved Section\n"
            "\n"
            "Legacy preserved text."
        )
        content = (
            "---\n"
            "owner: someone\n"
            "---\n"
            "\n"
            "# Legacy Index\n"
            "\n"
            "Intro line.\n"
            "\n"
            + legacy_h2 + "\n"
            "\n"
            + TABLE_HEADER + "\n"
            "|------|-------------|\n"
            "| old.md | Old |\n"
        )
        extra, trailing = extract_extra_sections(content)
        assert extra == legacy_h2
        assert trailing is None

    def test_legacy_no_note_no_h2_returns_none_none(self):
        """A legacy file with neither note nor "## " heading before the
        table has no preservable pre-table region: both regions are None."""
        content = (
            "# Legacy Index\n"
            "\n"
            "Intro line.\n"
            "\n"
            + TABLE_HEADER + "\n"
            "|------|-------------|\n"
            "| old.md | Old |\n"
        )
        extra, trailing = extract_extra_sections(content)
        assert extra is None
        assert trailing is None

    def test_legacy_no_note_no_table_is_not_an_error(self):
        """A file with no table and no generator fingerprint is treated
        as hand-written: no regions to preserve, no error raised."""
        extra, trailing = extract_extra_sections(
            "# Hand written\n\nJust prose.\n")
        assert extra is None
        assert trailing is None
