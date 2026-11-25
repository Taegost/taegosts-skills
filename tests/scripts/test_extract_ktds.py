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
- list-item KTD formats parse alongside the bold heading format: the
  bold-wrapped decision ("- KTDn. **decision.** rationale" — spec is the
  bold text alone, rationale excluded, files from the full line) and the
  bare remainder format ("- KTD-n [type] spec" — hyphenated ID normalized,
  no bold wrapper); a D-entry heading on the line right after a list item
  is absorbed, and bold and list entries coexist in order
- a bold-heading KTD on the line directly after a list item (no blank
  line) is its own entry, not a silently dropped one
- a soft-wrapped bold decision matches across the newline
- a bullet starting "KTDn …" inside a D-entry body is body continuation:
  no phantom KTD, no **Source:** leak into any spec
- spec purity per format: prose after a bold-format list KTD never appends
  (spec stays the decision alone); prose interleaved between bare-format
  list items folds into the item's spec
- a list-format KTD starting its own paragraph after a completed D-entry
  body is extracted — only mid-paragraph bullets inside that body are
  treated as body text

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


def test_list_format_bold_decision_parses():
    # Format A (2026-11-24 gloss/D-entry plan): "- KTD1. **decision.**
    # rationale" — the spec is the bold decision alone (literal checks do
    # exact string comparison and implementers quote the decision, not the
    # rationale); files come from the full line, rationale included
    content = _section(
        "- KTD1. **Render rules live once.** Cross-read from `refs/rules.md`; copies drift.\n"
        "- KTD2. **Glossing is idempotent.** Two passes double-gloss.\n"
    )

    ktds = extract_ktds(find_ktd_section(content))
    assert [k["id"] for k in ktds] == ["KTD1", "KTD2"]
    assert ktds[0]["spec"] == "Render rules live once."
    assert "Copies drift" not in ktds[0]["spec"]
    assert ktds[0]["title"] == ""
    assert ktds[0]["type"] == "literal"
    assert ktds[0]["files"] == ["refs/rules.md"]
    assert ktds[1]["spec"] == "Glossing is idempotent."


def test_list_format_bold_decision_with_behavioral_marker():
    content = _section(
        "- KTD2 [behavioral]. **Gate fires once per batch.** Re-classification drifts.\n"
    )

    ktds = extract_ktds(find_ktd_section(content))
    assert len(ktds) == 1
    assert ktds[0]["id"] == "KTD2"
    assert ktds[0]["type"] == "behavioral"
    assert ktds[0]["spec"] == "Gate fires once per batch."
    assert "Re-classification" not in ktds[0]["spec"]


def test_list_format_hyphenated_id_with_marker():
    # Format B (2026-11-19 self-containment plan): "- KTD-1 [behavioral]
    # spec ... rationale" — no bold wrapper, so decision and rationale stay
    # together in the spec; the hyphenated ID normalizes to KTD1
    content = _section(
        "- KTD-1 [behavioral] Question text carries the decision; the transcript duplicates it. "
        "Rationale: pre-question text is collapsed.\n"
    )

    ktds = extract_ktds(find_ktd_section(content))
    assert len(ktds) == 1
    assert ktds[0]["id"] == "KTD1"
    assert ktds[0]["type"] == "behavioral"
    assert ktds[0]["spec"].startswith("Question text carries the decision")
    assert "Rationale: pre-question text is collapsed." in ktds[0]["spec"]
    assert ktds[0]["title"] == ""


def test_list_format_unmarked_defaults_literal():
    content = _section(
        "- KTD-7 Keep the existing suites green. Rationale: no new tooling.\n"
    )

    ktds = extract_ktds(find_ktd_section(content))
    assert len(ktds) == 1
    assert ktds[0]["id"] == "KTD7"
    assert ktds[0]["type"] == "literal"
    assert ktds[0]["spec"] == "Keep the existing suites green. Rationale: no new tooling."


def test_dentry_heading_after_list_ktd_without_blank_line():
    # The D-entry heading follows the list line with no blank line — one
    # paragraph; the cut must happen at the heading, before spec extraction
    content = _section(
        "- KTD1. **Render rules live once.** Copies drift.\n"
        "#### KTD1.D1. Where the rule lives\n"
        "**Decision:** The rule lives in the walkthrough.\n"
    )

    ktds = extract_ktds(find_ktd_section(content))
    assert len(ktds) == 1
    assert ktds[0]["spec"] == "Render rules live once."
    assert "walkthrough" not in ktds[0]["spec"]
    assert ktds[0]["files"] == []


def test_mixed_bold_and_list_formats_order_preserved():
    content = _section(
        "**KTD1. Alpha approach.** Offset breaks.\n\n"
        "- KTD2. **Bold-wrapped decision.** Rationale tail.\n"
        "- KTD-3 [behavioral] Remainder spec. Rationale: compact.\n\n"
        "**KTD4. Delta approach.** Stable ordering.\n"
    )

    ktds = extract_ktds(find_ktd_section(content))
    assert [k["id"] for k in ktds] == ["KTD1", "KTD2", "KTD3", "KTD4"]
    assert ktds[0]["spec"] == "Offset breaks."
    assert ktds[1]["spec"] == "Bold-wrapped decision."
    assert ktds[2]["type"] == "behavioral"
    assert ktds[2]["spec"] == "Remainder spec. Rationale: compact."
    assert ktds[3]["spec"] == "Stable ordering."


def test_adjacent_bold_heading_after_list_ktd_parsed():
    # A bold-heading KTD on the line directly after a list-format KTD (no
    # blank line) shares one raw paragraph; the splitter must cut at the
    # heading's line start too or the heading entry is silently dropped
    content = _section(
        "- KTD1. **First decision.** Rationale.\n"
        "**KTD2. Second approach.** Second specification.\n"
    )

    ktds = extract_ktds(find_ktd_section(content))
    assert [k["id"] for k in ktds] == ["KTD1", "KTD2"]
    assert ktds[0]["spec"] == "First decision."
    assert ktds[0]["title"] == ""
    assert ktds[1]["title"] == "Second approach"
    assert ktds[1]["spec"] == "Second specification."


def test_list_bold_decision_spans_wrapped_lines():
    # A soft-wrapped bold decision crosses a newline; the bold match needs
    # re.DOTALL or the fallback records the delimiters and rationale as the
    # spec, breaking literal exact-string checks
    content = _section(
        "- KTD1. **Soft-wrapped decision spanning\n two lines.** Rationale tail.\n"
    )

    ktds = extract_ktds(find_ktd_section(content))
    assert len(ktds) == 1
    assert ktds[0]["spec"] == "Soft-wrapped decision spanning\n two lines."
    assert "Rationale tail" not in ktds[0]["spec"]


def test_dentry_body_bullet_does_not_create_ktd():
    # A bullet starting "KTD2 …" inside a D-entry body is body
    # continuation, not a list-format KTD — no phantom record, and the
    # following **Source:** line must not leak into any spec
    content = _section(
        "**KTD1. Offset approach.** Broken under load.\n\n"
        "#### KTD1.D1. Some decision\n"
        "**Decision:** Use the opaque token.\n"
        "**Why:** Rationale detail:\n"
        "- KTD2 supersedes the offset approach entirely\n"
        "**Source:** user, 2026-11-20\n"
    )

    ktds = extract_ktds(find_ktd_section(content))
    assert [k["id"] for k in ktds] == ["KTD1"]
    assert ktds[0]["spec"] == "Broken under load."
    for ktd in ktds:
        assert "supersedes" not in ktd["spec"]
        assert "Source" not in ktd["spec"]


def test_list_ktd_after_completed_dentry_body_extracted():
    # A list-format KTD that begins its own paragraph (blank line before
    # it) after a completed D-entry body is a real new entry — the
    # in-body suppression must not swallow it
    content = _section(
        "- KTD1. **Decision one.** Rationale one.\n\n"
        "#### KTD1.D1. Some decision\n\n"
        "**Why:** rationale text\n\n"
        "- KTD2. **Decision two.** Rationale two.\n"
        "- KTD3. **Decision three.** Rationale three.\n"
    )

    ktds = extract_ktds(find_ktd_section(content))
    assert [k["id"] for k in ktds] == ["KTD1", "KTD2", "KTD3"]
    assert ktds[1]["spec"] == "Decision two."
    assert ktds[2]["spec"] == "Decision three."
    for ktd in ktds:
        assert "rationale text" not in ktd["spec"]


def test_prose_after_bold_list_ktd_not_appended():
    # Bold-format list KTD: the spec is the bold decision alone — a later
    # prose paragraph never appends (literal checks compare exact strings)
    content = _section(
        "- KTD1. **Decision two.** Rationale two.\n\n"
        "prose paragraph after list\n"
    )

    ktds = extract_ktds(find_ktd_section(content))
    assert len(ktds) == 1
    assert ktds[0]["spec"] == "Decision two."


def test_prose_between_bare_list_items_folds_into_spec():
    # Bare-format list KTDs have no separable rationale, so interleaved
    # prose inside the item's segment folds into that item's spec
    content = _section(
        "- KTD-1 First spec. Rationale one.\n"
        "interleaved prose line\n"
        "- KTD-2 Second spec. Rationale two.\n"
    )

    ktds = extract_ktds(find_ktd_section(content))
    assert [k["id"] for k in ktds] == ["KTD1", "KTD2"]
    assert "interleaved prose line" in ktds[0]["spec"]
    assert ktds[1]["spec"] == "Second spec. Rationale two."
