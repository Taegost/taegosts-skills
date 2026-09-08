#!/usr/bin/env python3
"""Shared helpers for the INDEX.md generators.

Holds the constants and content helpers used by both index generators
(the docs-tree generator and the script-directory generator) so their
shared behavior lives in exactly one place:

- the path resolution note emitted after every intro line;
- the default frontmatter owner and frontmatter field reading;
- content-idempotency (regeneration that would only bump the
  "last-updated:" line is skipped);
- hand-maintained content preservation (see extract_extra_sections).

This module is a library, not a CLI. Importers add this file's directory
to sys.path before importing, mirroring how shell scripts source lib/.
"""

import re

# Resolution note emitted after the intro line of every generated INDEX.md.
# Plain constant (not an f-string) so the ${...} substitution syntax survives.
RESOLUTION_NOTE = (
    "Paths below are relative to this index's directory. On Claude Code "
    "marketplace installs, resolve them through "
    "${CLAUDE_PLUGIN_ROOT}/<repo-relative-path>; on other platforms, resolve "
    "from the loaded skill directory or the taegosts-skills checkout."
)

# Frontmatter owner written when the existing INDEX.md carries none.
# A pre-existing non-default owner is preserved across regeneration.
DEFAULT_OWNER = "wave-2-dispatch-index-automation"

# Header line that opens the link table in every generated INDEX.md.
TABLE_HEADER = "| Link | Description |"


class IndexStructureError(Exception):
    """Raised when an existing INDEX.md looks generator-maintained but its
    structure cannot be safely round-tripped (e.g. the link table header
    is missing). Callers must abort regeneration for that file instead of
    silently overwriting it."""


def read_frontmatter_field(content: str, field: str) -> str | None:
    """Read a scalar field value from a YAML frontmatter block.

    Returns the stripped value, or None if no frontmatter or field is absent.
    """
    match = re.match(r"^---\s*\n(.*?)\n---\s*\n", content, re.DOTALL)
    if not match:
        return None
    for line in match.group(1).splitlines():
        stripped = line.strip()
        if stripped.startswith(f"{field}:"):
            return stripped.split(":", 1)[1].strip().strip('"').strip("'")
    return None


def differs_only_by_last_updated(existing: str, generated: str) -> bool:
    """True when generated matches existing except for the last-updated line.

    Used to keep regeneration content-idempotent: a re-run that would only
    bump the date leaves the file completely untouched.
    """
    def normalize(text: str) -> str:
        return re.sub(r"(?m)^last-updated: .*$", "last-updated: <normalized>",
                      text)

    return normalize(existing) == normalize(generated)


def looks_generated(content: str) -> bool:
    """True when content carries a generator fingerprint.

    A file counts as generator-maintained when it embeds the resolution
    note, or when its frontmatter tags include the exact token "index"
    (both generators emit an index tag). Files carrying neither marker
    are treated as hand-written and regenerated best-effort instead of
    failing.
    """
    if RESOLUTION_NOTE in content:
        return True
    tags = read_frontmatter_field(content, "tags")
    return tags is not None and bool(
        re.search(r"(?<![\w-])index(?![\w-])", tags)
    )


def extract_extra_sections(existing: str) -> tuple[str | None, str | None]:
    """Split an existing INDEX.md into its hand-maintained regions.

    The generators own the frontmatter, H1, intro line, resolution note,
    and the link table. Everything maintained around that skeleton must
    survive regeneration:

    - everything between the resolution note line and the "| Link |" table
      header, regardless of whether lines start with a "## " heading
      marker (plain paragraphs, callouts, and lists are preserved too);
    - everything after the last table row (footers, post-table sections).

    Returns an (extra_sections, trailing_content) tuple of verbatim region
    text with surrounding blank lines stripped; either element is None
    when that region is empty.

    Files without a resolution note fall back to the legacy anchor (the
    first "## " heading before the table) so indexes predating the note
    keep their heading-preservation behavior.

    Raises IndexStructureError when the file looks generator-maintained
    (see looks_generated) but carries no "| Link |" table header: the
    hand-maintained regions cannot then be located, and regenerating
    would silently overwrite them.
    """
    lines = existing.splitlines()
    table_idx = next(
        (i for i, ln in enumerate(lines) if ln.startswith(TABLE_HEADER)),
        None)
    if table_idx is None:
        if looks_generated(existing):
            raise IndexStructureError(
                'existing INDEX.md looks generator-maintained but has no '
                '"| Link |" table header; hand-maintained content cannot '
                'be located safely')
        return None, None

    note_idx = next(
        (i for i, ln in enumerate(lines[:table_idx])
         if ln.startswith(RESOLUTION_NOTE)), None)
    if note_idx is not None:
        start = note_idx + 1
    else:
        start = next(
            (i for i, ln in enumerate(lines[:table_idx])
             if ln.startswith("## ")), table_idx)
    extra = "\n".join(lines[start:table_idx]).strip() or None

    table_end = table_idx
    while table_end < len(lines) and lines[table_end].startswith("|"):
        table_end += 1
    trailing = "\n".join(lines[table_end:]).strip() or None

    return extra, trailing
