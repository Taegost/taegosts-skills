#!/usr/bin/env python3
"""
update-all-indexes.py -- One-time migration script to update all INDEX.md files to R3 format.

This script reads existing INDEX.md files, preserves their content, and rewrites them
with R3-compliant frontmatter and Path/Description table columns.

Usage:
    python3 scripts/update-all-indexes.py
    python3 scripts/update-all-indexes.py --dry-run

Exit codes:
    0 - Success
    1 - Error
"""

import argparse
import re
import sys
from datetime import date
from pathlib import Path


def parse_existing_frontmatter(content: str) -> tuple[dict, str]:
    """Parse existing frontmatter and return (frontmatter_dict, body_content)."""
    match = re.match(r'^---\s*\n(.*?)\n---\s*\n(.*)', content, re.DOTALL)
    if not match:
        return {}, content

    frontmatter = {}
    for line in match.group(1).splitlines():
        line = line.strip()
        if not line or line.startswith('#'):
            continue
        if ':' in line:
            key, value = line.split(':', 1)
            frontmatter[key.strip()] = value.strip()

    return frontmatter, match.group(2)


def extract_title_from_heading(body: str) -> str:
    """Extract title from first # heading in body."""
    match = re.search(r'^#\s+(.+)$', body, re.MULTILINE)
    if match:
        return match.group(1).strip()
    return "Index"


def extract_description_from_body(body: str) -> str:
    """Extract description from first paragraph after heading."""
    lines = body.splitlines()
    in_paragraph = False
    paragraph_lines = []

    for line in lines:
        stripped = line.strip()
        # Skip blank lines before paragraph starts
        if not stripped and not in_paragraph:
            continue
        # Skip headings
        if stripped.startswith('#'):
            if in_paragraph:
                break
            continue
        # Skip table rows
        if stripped.startswith('|'):
            if in_paragraph:
                break
            continue
        # Empty line after paragraph = end of paragraph
        if not stripped:
            if in_paragraph:
                break
            continue
        # This is body text
        paragraph_lines.append(stripped)
        in_paragraph = True

    if paragraph_lines:
        return ' '.join(paragraph_lines)
    return "Index of documentation"


def convert_table_to_path_format(body: str) -> str:
    """Convert Link column to Path column in table."""
    # Replace | Link | Description | with | Path | Description |
    body = re.sub(
        r'\|\s*Link\s*\|\s*Description\s*\|',
        '| Path | Description |',
        body
    )
    # Also handle case-insensitive variants
    body = re.sub(
        r'\|\s*link\s*\|\s*description\s*\|',
        '| Path | Description |',
        body,
        flags=re.IGNORECASE
    )
    return body


def update_index_file(filepath: Path, dry_run: bool = False) -> bool:
    """Update a single INDEX.md file to R3 format.

    Returns True if file was updated, False if no changes needed.
    """
    try:
        content = filepath.read_text(encoding='utf-8')
    except (OSError, UnicodeDecodeError) as e:
        print(f"Error reading {filepath}: {e}", file=sys.stderr)
        return False

    # Parse existing content
    old_fm, body = parse_existing_frontmatter(content)

    # Extract title and description from body
    title = extract_title_from_heading(body)
    description = extract_description_from_body(body)

    # Check if already R3 compliant
    required_fields = ['title', 'description', 'status', 'version', 'created', 'last-updated', 'owner', 'dependencies']
    missing_fields = [f for f in required_fields if f not in old_fm]

    # Check if table already uses Path column
    has_path_column = '| Path |' in body or '| path |' in body.lower()

    if not missing_fields and has_path_column:
        print(f"  {filepath}: Already R3 compliant", file=sys.stderr)
        return False

    # Build new frontmatter
    today = date.today().isoformat()
    tags = old_fm.get('tags', '[index]')
    if not tags.startswith('['):
        tags = f'[{tags}]'

    new_fm_lines = [
        "---",
        f'title: "{title}"',
        f'description: "{description}"',
        "status: active",
        'version: "1.0"',
        f"created: {today}",
        f"last-updated: {today}",
        "owner: wave-2-dispatch-index-automation",
        "dependencies: []",
        f"tags: {tags}",
        "---",
    ]

    # Convert table columns
    body = convert_table_to_path_format(body)

    # Build new content
    new_content = '\n'.join(new_fm_lines) + '\n' + body

    if dry_run:
        print(f"[dry-run] Would update {filepath}", file=sys.stderr)
        print(new_content)
        return True

    filepath.write_text(new_content, encoding='utf-8')
    print(f"  Updated: {filepath}", file=sys.stderr)
    return True


def main():
    parser = argparse.ArgumentParser(
        description="Update all INDEX.md files to R3 format."
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print updated content without writing files",
    )

    args = parser.parse_args()
    repo_root = Path(__file__).resolve().parent.parent

    # Find all INDEX.md files
    index_files = sorted(repo_root.rglob("INDEX.md"))
    # Exclude worktrees and node_modules
    index_files = [f for f in index_files if '.claude/worktrees' not in str(f) and 'node_modules' not in str(f)]

    print(f"Found {len(index_files)} INDEX.md files", file=sys.stderr)

    updated_count = 0
    for filepath in index_files:
        try:
            rel_path = filepath.relative_to(repo_root)
        except ValueError:
            rel_path = filepath
        print(f"\nProcessing: {rel_path}", file=sys.stderr)
        if update_index_file(filepath, args.dry_run):
            updated_count += 1

    print(f"\nUpdated {updated_count} files", file=sys.stderr)
    sys.exit(0)


if __name__ == "__main__":
    main()
