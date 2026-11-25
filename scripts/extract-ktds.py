#!/usr/bin/env python3
"""
Extract Key Technical Decisions (KTDs) from plan markdown files.

Parses the "Key Technical Decisions" section of a plan document and extracts
each KTD with its type marker ([literal] or [behavioral]), title, spec text,
and associated files.

Output: JSON object with 'plan', 'ktds', and 'count' fields.

Usage:
    python3 scripts/extract-ktds.py <plan-file>

Exit codes:
    0 - Success (KTDs found or section empty/not found)
    1 - Error (file not found, unreadable)

KTD heading format:
    **KTDN [type]. Title.**   (new format, with type marker)
    **KTDN. Title.**          (old format, defaults to [literal])

Where N is a number, [type] is literal or behavioral, and Title is free text.

List-item formats are also recognized — a paragraph starting with "- KTD":

    - KTDN. **Decision sentence.** rationale tail
    - KTDN [type]. **Decision sentence.** rationale tail

The bold-wrapped decision is the spec; the trailing rationale is excluded
(literal KTD verification does exact string comparison), and later prose
paragraphs never append to the spec either. Title is empty and file
references come from the full line. Without a bold wrapper:

    - KTD-N [type] spec text and rationale

the ID may be hyphenated (KTD-1 normalizes to KTD1) and the whole remainder
after the ID and marker is the spec; interleaved prose and later paragraphs
still fold into it. An omitted type marker defaults to [literal] in both
list formats. A bold-heading KTD on the line directly after a list-format
KTD (no blank line) is recognized as its own entry. A list-format KTD that
begins its own paragraph after a completed D-entry body is extracted — only
list lines embedded mid-paragraph inside that body are treated as body text.
"""

import json
import re
import sys
from pathlib import Path

# A backtick-wrapped filename with an extension, e.g. `src/retry.py`
FILE_REF_PATTERN = re.compile(r'`([^`]+\.[a-zA-Z0-9]+)`')


def find_ktd_section(content: str) -> str | None:
    """Find the Key Technical Decisions section content.

    Returns the section content (everything after the heading until the next
    section heading of equal or lesser level), or None if not found.
    """
    # Match the KTD section heading (## or ### level)
    pattern = r'^#{2,3}\s+Key Technical Decisions\s*$'
    match = re.search(pattern, content, re.MULTILINE)
    if not match:
        return None

    # Find the start of the section content (after the heading line)
    start = match.end()
    # Skip the heading line itself
    # Use find() instead of index() to avoid ValueError if heading is last line
    newline_pos = content.find('\n', match.start())
    if newline_pos == -1:
        # Heading is the last line with no trailing newline
        heading_end = len(content)
    else:
        heading_end = newline_pos + 1
    start = max(start, heading_end)

    # Find the next heading of equal or lesser level
    # Count the number of # characters at the start of the matched heading
    heading_level = len(match.group()) - len(match.group().lstrip('#'))
    next_heading_pattern = rf'^#{{{1},{heading_level}}}\s+\S'
    next_match = re.search(next_heading_pattern, content[start:], re.MULTILINE)

    if next_match:
        end = start + next_match.start()
    else:
        end = len(content)

    return content[start:end].strip()


def extract_ktds(section_content: str) -> list[dict]:
    """Extract individual KTDs from the section content.

    Returns a list of KTD dictionaries with keys: id, type, title, spec, files.
    """
    if not section_content:
        return []

    ktds = []

    # Pattern for KTD headings:
    # **KTD1 [literal]. Title.**  (new format)
    # **KTD1. Title.**            (old format, defaults to [literal])
    # Also handles **KTD1 [behavioral]. Title.**
    heading_pattern = re.compile(
        r'\*\*KTD(\d+)\s*(?:\[(literal|behavioral)\])?\.\s*(.*?)\.\*\*',
        re.IGNORECASE
    )

    # Line-anchored variant of the heading pattern for the paragraph
    # splitter: a bold-heading KTD at a line start. A markdown list carries
    # no blank lines between items, so a bold-heading KTD may share a raw
    # paragraph with the list line directly above it; the splitter must cut
    # there too or the heading entry is silently dropped.
    heading_line_pattern = re.compile(
        r'^\*\*KTD(\d+)\s*(?:\[(literal|behavioral)\])?\.\s*(.*?)\.\*\*',
        re.IGNORECASE | re.MULTILINE
    )

    # Pattern for list-item KTD entries (a paragraph line starting with
    # "- KTD"), recognized alongside the bold heading format:
    # - KTD1. **Decision.** rationale      (bold-wrapped decision)
    # - KTD-1 [behavioral] spec rationale  (hyphenated ID, no bold wrapper)
    # The ID may be hyphenated (normalized below); the type marker is
    # optional and defaults to literal; the entry ends at the next period
    # (bold format) or whitespace (bare format).
    list_pattern = re.compile(
        r'^-\s+KTD-?(\d+)(?:\s*\[(literal|behavioral)\])?[.\s]',
        re.IGNORECASE | re.MULTILINE
    )

    # Pattern for decision-log (D-entry) headings: a level-4 heading whose
    # title starts with a scoped decision ID (<section>.D<sequence>, e.g.
    # KTD1.D1, U3.D2). Per the decision-log rules these live inside the KTD
    # section for plan-wide decisions; their text and file references belong
    # to the decision log, not to any KTD's spec.
    dentry_pattern = re.compile(r'^####\s+\S+\.D\d+\b', re.MULTILINE)

    # Split content into paragraphs
    raw_paragraphs = re.split(r'\n\s*\n', section_content)

    # A markdown list carries no blank lines between items, so one paragraph
    # can hold several list-format KTDs (plus interleaved prose) or mix a
    # bold-heading KTD into the list above it. Split each such paragraph at
    # every list KTD line start and every bold-heading KTD line start so
    # entries are handled one at a time, in order. Per-format consequence:
    # intra-segment prose between items is dropped from bold-format specs
    # (spec = bold decision alone, and later paragraphs never append);
    # bare-format specs include their whole segment, and later paragraphs
    # still append.
    # Each produced segment carries whether it begins its own raw
    # paragraph (blank-line-separated from everything before it): a list
    # line that starts a paragraph is a new KTD even after a D-entry
    # body, while a list line embedded mid-paragraph inside that body is
    # body continuation
    paragraphs = []
    for raw in raw_paragraphs:
        starts = sorted(
            [m.start() for m in list_pattern.finditer(raw)]
            + [m.start() for m in heading_line_pattern.finditer(raw)]
        )
        if not starts:
            paragraphs.append((raw, True))
            continue
        bounds = starts if starts[0] == 0 else [0, *starts]
        for i, bound in enumerate(bounds):
            end = bounds[i + 1] if i + 1 < len(bounds) else len(raw)
            paragraphs.append((raw[bound:end], bound == 0))

    current_ktd = None
    # Whether current_ktd is a list-format entry whose spec came from a
    # bold wrapper: such specs stay the bold decision alone — later
    # paragraphs never append (literal checks compare exact strings)
    current_ktd_list_bold = False
    in_dentry = False

    for para, starts_paragraph in paragraphs:
        para = para.strip()
        if not para:
            continue

        # Check if this paragraph starts a new KTD
        heading_match = heading_pattern.search(para)

        # A paragraph beginning with a list-format marker starts a KTD too;
        # the list match wins so a decision sentence that itself opens with
        # "KTD..." inside the bold wrapper is not misread as a bold heading
        list_match = list_pattern.match(para)

        if list_match:
            if in_dentry and not starts_paragraph:
                # A list line embedded in the D-entry body's own paragraph
                # (e.g. a "- KTD2 …" bullet in a Why line) is body
                # continuation, not a new KTD; the D-entry-body skip below
                # drops it with the rest of the entry
                continue
            # A list-format KTD always ends any D-entry block before it
            in_dentry = False

            # Save previous KTD if exists
            if current_ktd:
                ktds.append(current_ktd)

            # The hyphenated ID form (KTD-1) normalizes here
            ktd_id = f"KTD{list_match.group(1)}"
            ktd_type = (list_match.group(2) or 'literal').lower()

            # A D-entry heading may share this paragraph with the list line
            # (no blank line between them) — cut the paragraph there first,
            # mirroring the bold-format handling
            dmatch = dentry_pattern.search(para)
            if dmatch:
                in_dentry = True
                para = para[:dmatch.start()]

            remainder = para[list_match.end():].strip()

            bold_match = re.match(r'\*\*(.*?)\*\*', remainder, re.DOTALL)
            if bold_match:
                # Bold-wrapped decision ("- KTD1. **Decision.** rationale"):
                # the spec is the bold decision alone — literal KTD checks
                # do exact string comparison, and implementers quote the
                # decision, not the trailing rationale. Title stays empty;
                # file references below still come from the full line.
                spec_text = bold_match.group(1).strip()
            else:
                # Bare format ("- KTD-1 [behavioral] spec ... rationale"):
                # decision and rationale are not separable without a bold
                # wrapper, so the whole remainder is the spec.
                spec_text = remainder
            current_ktd_list_bold = bold_match is not None

            # Extract file references from the full list line (bold and
            # rationale alike)
            file_refs = FILE_REF_PATTERN.findall(para)

            current_ktd = {
                'id': ktd_id,
                'type': ktd_type,
                'title': '',
                'spec': spec_text,
                'files': list(file_refs)
            }
        elif heading_match:
            # A KTD heading always ends any D-entry block before it
            in_dentry = False

            # Save previous KTD if exists
            if current_ktd:
                ktds.append(current_ktd)

            ktd_id = f"KTD{heading_match.group(1)}"
            ktd_type = (heading_match.group(2) or 'literal').lower()
            ktd_title = heading_match.group(3).strip()

            # A D-entry heading may share this paragraph with KTD text
            # (no blank line between them) — cut the paragraph there first
            dmatch = dentry_pattern.search(para)
            if dmatch:
                in_dentry = True
                para = para[:dmatch.start()]

            # The spec is everything after the heading in this paragraph
            # plus subsequent paragraphs until the next KTD heading
            spec_start = heading_match.end()
            spec_text = para[spec_start:].strip()

            # Extract file references from the heading paragraph
            file_refs = FILE_REF_PATTERN.findall(para)

            current_ktd = {
                'id': ktd_id,
                'type': ktd_type,
                'title': ktd_title,
                'spec': spec_text,
                'files': list(file_refs)
            }
            current_ktd_list_bold = False
        else:
            # A D-entry heading ends the current KTD's spec collection:
            # everything from the heading on belongs to the decision log
            dmatch = dentry_pattern.search(para)
            if dmatch:
                in_dentry = True

            if in_dentry:
                # D-entry body (Decision/Why/Source lines and any text
                # truncated above) is excluded from every KTD record
                continue

            if current_ktd and para:
                if current_ktd_list_bold:
                    # Bold-format list KTD: the spec is the bold decision
                    # alone — later prose paragraphs never append, keeping
                    # literal exact-string checks intact
                    continue

                # This paragraph is part of the current KTD's spec
                if current_ktd['spec']:
                    current_ktd['spec'] += '\n\n' + para
                else:
                    current_ktd['spec'] = para

                # Extract file references from the spec
                file_refs = FILE_REF_PATTERN.findall(para)
                current_ktd['files'].extend(file_refs)

    # Don't forget the last KTD
    if current_ktd:
        ktds.append(current_ktd)

    # Clean up specs (strip leading/trailing whitespace, normalize internal whitespace)
    for ktd in ktds:
        ktd['spec'] = ktd['spec'].strip()
        # Remove empty file references
        ktd['files'] = list(set(ktd['files']))

    return ktds


def main():
    if "--help" in sys.argv[1:] or "-h" in sys.argv[1:]:
        print(__doc__.strip())
        sys.exit(0)

    if len(sys.argv) < 2:
        print("Usage: python3 scripts/extract-ktds.py <plan-file>", file=sys.stderr)
        sys.exit(1)

    plan_path = Path(sys.argv[1])

    if not plan_path.exists():
        print(json.dumps({
            'error': f'File not found: {plan_path}',
            'ktds': []
        }))
        sys.exit(1)

    try:
        content = plan_path.read_text(encoding='utf-8')
    except Exception as e:
        print(json.dumps({
            'error': f'Failed to read file: {e}',
            'ktds': []
        }))
        sys.exit(1)

    section = find_ktd_section(content)
    if section is None:
        # No KTD section found — return empty array (not an error)
        print(json.dumps({
            'plan': str(plan_path),
            'ktds': [],
            'note': 'No Key Technical Decisions section found'
        }))
        sys.exit(0)

    ktds = extract_ktds(section)

    result = {
        'plan': str(plan_path),
        'ktds': ktds,
        'count': len(ktds)
    }

    print(json.dumps(result, indent=2))
    sys.exit(0)


if __name__ == '__main__':
    main()
