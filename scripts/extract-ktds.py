#!/usr/bin/env python3
"""
Extract Key Technical Decisions (KTDs) from plan markdown files.

Parses the "Key Technical Decisions" section of a plan document and extracts
each KTD with its type marker ([literal] or [behavioral]), title, spec text,
and associated files.

Output: JSON array of KTD objects.

Usage:
    python3 scripts/extract-ktds.py <plan-file>

Exit codes:
    0 - Success (KTDs found or section empty/not found)
    1 - Error (file not found, unreadable)

KTD heading format:
    **KTDN [type]. Title.**   (new format, with type marker)
    **KTDN. Title.**          (old format, defaults to [literal])

Where N is a number, [type] is literal or behavioral, and Title is free text.
"""

import json
import re
import sys
from pathlib import Path


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

    # Split content into paragraphs
    paragraphs = re.split(r'\n\s*\n', section_content)

    current_ktd = None

    for para in paragraphs:
        para = para.strip()
        if not para:
            continue

        # Check if this paragraph starts a new KTD
        heading_match = heading_pattern.search(para)
        if heading_match:
            # Save previous KTD if exists
            if current_ktd:
                ktds.append(current_ktd)

            ktd_id = f"KTD{heading_match.group(1)}"
            ktd_type = (heading_match.group(2) or 'literal').lower()
            ktd_title = heading_match.group(3).strip()

            # The spec is everything after the heading in this paragraph
            # plus subsequent paragraphs until the next KTD heading
            spec_start = heading_match.end()
            spec_text = para[spec_start:].strip()

            # Extract file references from the heading paragraph
            file_refs = re.findall(r'`([^`]+\.(?:py|sh|md|js|ts|yaml|yml|json|txt))`', para)

            current_ktd = {
                'id': ktd_id,
                'type': ktd_type,
                'title': ktd_title,
                'spec': spec_text,
                'files': list(file_refs)
            }
        elif current_ktd:
            # This paragraph is part of the current KTD's spec
            if current_ktd['spec']:
                current_ktd['spec'] += '\n\n' + para
            else:
                current_ktd['spec'] = para

            # Extract file references from the spec
            # Look for patterns like `scripts/foo.py` or `skills/bar/SKILL.md`
            file_refs = re.findall(r'`([^`]+\.(?:py|sh|md|js|ts|yaml|yml|json|txt))`', para)
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
