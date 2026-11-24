"""Unit tests for scripts/extract-ktds.py D-entry handling.

Regression coverage for the decision-log interaction found in PR 225 review:
a level-4 D-entry heading (#### KTDn.Dm.) inside the Key Technical Decisions
section must terminate the preceding KTD's spec collection, and the D-entry's
text and backtick-wrapped filenames must be excluded from every KTD record —
including when the heading follows KTD text without a blank line.

Covers the public surface directly (no subprocess):

- find_ktd_section still returns the full KTD section (level-4 headings do
  not terminate the section — only the KTD record scan)
- extract_ktds with a D-entry between two KTDs: both KTDs extracted, D-entry
  text and files excluded from each
- the no-blank-line case: KTD text and the D-entry heading in one paragraph
- pre-existing behavior preserved: plain prose paragraphs between KTDs still
  append to the preceding KTD's spec, and non-D-entry level-4 headings still
  append (unchanged legacy behavior)
- D-entry bodies split across multiple paragraphs are excluded entirely
- the U3 emitted shape — active D-entry headings plus a superseded entry
  whose heading is struck through — parses with no extractor changes, and
  no D-entry text reaches any KTD's spec

Import bootstrap mirrors tests/scripts/test_update_indexes.py: the script's
filename is hyphenated (not a valid module name), so it is loaded directly
from its file location.
"""

import importlib.util
from pathlib import Path

_SCRIPT = (
    Path(__file__).resolve().parent.parent.parent / "scripts" / "extract-ktds.py"
)

_spec = importlib.util.spec_from_file_location("extract_ktds", _SCRIPT)
_mod = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_mod)

extract_ktds = _mod.extract_ktds
find_ktd_section = _mod.find_ktd_section


def _section(body: str) -> str:
    return f"## Key Technical Decisions\n\n{body}"


def test_dentry_between_two_ktds_is_excluded():
    content = _section(
        "**KTD1. Alpha approach.** Offset breaks under concurrent inserts.\n\n"
        "#### KTD1.D1. Opaque cursor token\n"
        "**Decision:** The cursor is an opaque, signed token.\n"
        "**Why:** Decodable cursors invite client-side parsing.\n"
        "**Source:** user, 2026-11-20 plan discussion\n\n"
        "**KTD2. Gamma fallback.** Retry with backoff `src/retry.py`.\n"
    )

    section = find_ktd_section(content)
    assert section is not None
    # Level-4 headings stay inside the section...
    assert "KTD1.D1" in section

    ktds = extract_ktds(section)
    assert [k["id"] for k in ktds] == ["KTD1", "KTD2"]

    # ...but out of every KTD record
    ktd1 = ktds[0]
    assert ktd1["spec"] == "Offset breaks under concurrent inserts."
    assert "Opaque cursor token" not in ktd1["spec"]
    assert "signed token" not in ktd1["spec"]
    assert ktd1["files"] == []

    ktd2 = ktds[1]
    assert ktd2["spec"] == "Retry with backoff `src/retry.py`."
    assert "cursor" not in ktd2["spec"].lower()
    assert ktd2["files"] == ["src/retry.py"]


def test_dentry_without_blank_line_truncates_ktd_spec():
    # KTD spec text and the D-entry heading share one paragraph
    content = _section(
        "**KTD1. Alpha approach.** Offset breaks under concurrent inserts.\n"
        "#### KTD1.D1. Opaque cursor token\n"
        "**Decision:** The cursor is an opaque, signed token.\n"
    )

    ktds = extract_ktds(find_ktd_section(content))
    assert len(ktds) == 1
    assert ktds[0]["spec"] == "Offset breaks under concurrent inserts."
    assert "D1" not in ktds[0]["spec"]
    assert "signed token" not in ktds[0]["spec"]


def test_dentry_filenames_excluded_from_ktd_files():
    content = _section(
        "**KTD1. Alpha approach.** Offset breaks.\n\n"
        "#### KTD1.D1. Token files\n"
        "**Decision:** Use the codec in `src/cursor.py` and `tests/test_cursor.py`.\n"
        "**Source:** user, 2026-11-20\n"
    )

    ktds = extract_ktds(find_ktd_section(content))
    assert len(ktds) == 1
    assert ktds[0]["files"] == []
    assert "cursor.py" not in ktds[0]["spec"]


def test_dentry_body_across_paragraphs_fully_excluded():
    # Body fields separated by blank lines → multiple paragraphs after the
    # D-entry heading; every one of them belongs to the decision log
    content = _section(
        "**KTD1. Alpha approach.** Offset breaks.\n\n"
        "#### KTD1.D1. Opaque token\n"
        "**Decision:** Opaque, signed.\n\n"
        "**Why:** Parsing invites breakage.\n\n"
        "**Source:** user, 2026-11-20\n\n"
        "**KTD2. Beta approach.** Stable ordering.\n"
    )

    ktds = extract_ktds(find_ktd_section(content))
    assert [k["id"] for k in ktds] == ["KTD1", "KTD2"]
    assert ktds[0]["spec"] == "Offset breaks."
    assert "Parsing invites" not in ktds[0]["spec"]
    assert ktds[1]["spec"] == "Stable ordering."


def test_dentry_emitted_shape_with_superseded_strikethrough():
    # U3 emitted shape (skills/ts-plan/references/plan-sections.md): an
    # active D-entry, a superseded entry whose heading is struck through
    # with a Status line naming its replacement, and a second active
    # entry — parses with no extractor changes; nothing leaks into the spec
    content = _section(
        "**KTD1. Alpha approach.** Offset breaks under concurrent inserts.\n\n"
        "#### KTD1.D1. Opaque cursor token\n"
        "**Decision:** The cursor is an opaque, signed token.\n"
        "**Why:** Decodable cursors invite client-side parsing.\n"
        "**Source:** user, 2026-11-20 plan discussion\n\n"
        "#### ~~KTD1.D1.~~ Opaque cursor token\n"
        "**Status:** superseded by KTD1.D2 (opaque cursor token)\n\n"
        "#### KTD1.D2. Replacement rule\n"
        "**Decision:** Retry with an idempotency key.\n"
        "**Why:** Duplicate inserts corrupt the offset table.\n"
    )

    ktds = extract_ktds(find_ktd_section(content))
    assert [k["id"] for k in ktds] == ["KTD1"]
    assert ktds[0]["spec"] == "Offset breaks under concurrent inserts."
    assert ktds[0]["files"] == []

    # No D-entry body text in the spec: active entries' wording, the
    # supersession wording, and the struck-through marker itself
    spec = ktds[0]["spec"]
    assert "Opaque cursor token" not in spec
    assert "signed token" not in spec
    assert "Replacement rule" not in spec
    assert "idempotency key" not in spec
    assert "superseded by" not in spec
    assert "~~" not in spec


def test_plain_prose_between_ktds_still_appends():
    # Legacy behavior guard: prose with no D-entry keeps appending to the
    # preceding KTD's spec and files
    content = _section(
        "**KTD1. Alpha approach.** Offset breaks.\n\n"
        "Further detail in `docs/offset.md`.\n\n"
        "**KTD2. Beta approach.** Stable ordering.\n"
    )

    ktds = extract_ktds(find_ktd_section(content))
    assert len(ktds) == 2
    assert "Further detail" in ktds[0]["spec"]
    assert "docs/offset.md" in ktds[0]["files"]


def test_non_dentry_level4_heading_still_appends():
    # A level-4 heading that is not a scoped decision ID (no .D<digits>) is
    # not a D-entry; legacy behavior appends it to the KTD's spec
    content = _section(
        "**KTD1. Alpha approach.** Offset breaks.\n\n"
        "#### Notes on measurement\n"
        "Measured under load.\n"
    )

    ktds = extract_ktds(find_ktd_section(content))
    assert len(ktds) == 1
    assert "Notes on measurement" in ktds[0]["spec"]
    assert "Measured under load." in ktds[0]["spec"]


def test_section_without_dentries_unchanged():
    content = _section(
        "**KTD1 [literal]. Alpha approach.** Use `src/a.py`.\n\n"
        "**KTD2 [behavioral]. Beta approach.** Prefer retries.\n"
    )

    ktds = extract_ktds(find_ktd_section(content))
    assert [k["id"] for k in ktds] == ["KTD1", "KTD2"]
    assert ktds[0]["type"] == "literal"
    assert ktds[1]["type"] == "behavioral"
    assert ktds[0]["files"] == ["src/a.py"]
