#!/usr/bin/env python3
"""
Validate R7/R8 compliance for documentation files.

R7: Verify all markdown links use [name](uri) format.
R8: Verify INDEX.md files have correct structure and scoping.

Usage:
    python3 scripts/validate-index-standards.py <file-or-directory> [...]
    python3 scripts/validate-index-standards.py --help

Exit codes:
    0 - All files pass validation
    1 - One or more files have violations

Output: JSON to stderr with per-file results.
"""

import argparse
import json
import re
import sys
from pathlib import Path


def parse_frontmatter(content: str) -> dict | None:
    """Extract YAML frontmatter from markdown content.

    Returns a dict of frontmatter fields, or None if no frontmatter found.
    """
    match = re.match(r'^---\s*\n(.*?)\n---\s*\n', content, re.DOTALL)
    if not match:
        return None

    frontmatter = {}
    for line in match.group(1).splitlines():
        line = line.strip()
        if not line or line.startswith('#'):
            continue
        if ':' in line:
            key, value = line.split(':', 1)
            frontmatter[key.strip()] = value.strip()
    return frontmatter


def extract_links(content: str) -> list[dict]:
    """Extract all markdown links from content.

    Returns a list of dicts with 'text', 'uri', and 'line' keys.
    """
    links = []
    for i, line in enumerate(content.splitlines(), 1):
        # Match [text](uri) pattern, excluding image references
        for match in re.finditer(r'(?<!!)\[([^\]]*)\]\(([^)]+)\)', line):
            links.append({
                'text': match.group(1),
                'uri': match.group(2),
                'line': i
            })
    return links


def check_r7_links(content: str) -> list[dict]:
    """R7: Verify all markdown links use [name](uri) format.

    Returns a list of violations.
    """
    violations = []
    lines = content.splitlines()

    for i, line in enumerate(lines, 1):
        # Skip lines that are not link-like
        # Check for bare URLs (not wrapped in link syntax)
        # Pattern: URL not preceded by [ or ](
        for match in re.finditer(r'(?<!\])\((https?://[^\s)]+)\)', line):
            # Check if this is inside a link syntax [text](url)
            before = line[:match.start()]
            if not re.search(r'\[[^\]]*\]$', before):
                violations.append({
                    'rule': 'R7',
                    'line': i,
                    'message': f'Bare URL found: {match.group(1)}',
                    'fix': f'Wrap in link syntax: [descriptive name]({match.group(1)})'
                })

        # Check for bare URLs at end of line or before whitespace
        for match in re.finditer(r'(?:^|\s)(https?://[^\s]+)', line):
            url = match.group(1)
            # Check if this URL is already part of a link
            pos = match.start()
            before = line[:pos]
            after = line[pos:]

            # If preceded by ]( it's part of a link
            if re.search(r'\]\($', before):
                continue
            # If followed by ) it's part of a link
            if re.search(r'^[^\s]*\)', after):
                # Check if it's [text](url)
                if re.search(r'\]\([^\s]*\)', after):
                    continue

            violations.append({
                'rule': 'R7',
                'line': i,
                'message': f'Bare URL found: {url}',
                'fix': f'Wrap in link syntax: [descriptive name]({url})'
            })

    return violations


def check_r8_frontmatter(content: str, filepath: Path) -> list[dict]:
    """R8: Verify INDEX.md has YAML frontmatter with tags and description.

    Returns a list of violations.
    """
    violations = []
    frontmatter = parse_frontmatter(content)

    if frontmatter is None:
        violations.append({
            'rule': 'R8',
            'line': 1,
            'message': 'Missing YAML frontmatter (expected --- delimited block at start of file)',
            'fix': 'Add YAML frontmatter with tags and description fields'
        })
        return violations

    if 'tags' not in frontmatter:
        violations.append({
            'rule': 'R8',
            'line': 1,
            'message': 'Frontmatter missing required "tags" field',
            'fix': 'Add tags: [index] to frontmatter'
        })

    if 'description' not in frontmatter:
        violations.append({
            'rule': 'R8',
            'line': 1,
            'message': 'Frontmatter missing required "description" field',
            'fix': 'Add description: <brief description> to frontmatter'
        })

    return violations


def check_r8_table(content: str) -> list[dict]:
    """R8: Verify INDEX.md has a table with Link and Description columns.

    Returns a list of violations.
    """
    violations = []
    lines = content.splitlines()

    # Look for a table with Link and Description columns
    found_table = False
    for i, line in enumerate(lines, 1):
        # Check for table header row
        if '|' in line and ('Link' in line or 'link' in line.lower()):
            # Check if this is a table header (followed by separator row)
            if i < len(lines):
                next_line = lines[i]  # 0-indexed, so lines[i] is the next line
                if re.match(r'^[\s|:-]+$', next_line):
                    # This is a table header with separator
                    # Check for Description column
                    if 'Description' in line or 'description' in line.lower():
                        found_table = True
                        break

    if not found_table:
        violations.append({
            'rule': 'R8',
            'line': 1,
            'message': 'No table with "Link" and "Description" columns found',
            'fix': 'Add a table: | Link | Description |'
        })

    return violations


def check_r8_scope(content: str, filepath: Path, docs_root: Path) -> list[dict]:
    """R8: Verify INDEX.md only references files in scope.

    Scope: own folder + one subfolder deep.
    Exception: docs/ROUTING.md may reference files outside its parent folder.

    Returns a list of violations.
    """
    violations = []
    links = extract_links(content)
    file_dir = filepath.parent

    # Determine if this is the special ROUTING.md file
    is_routing = filepath.name == 'ROUTING.md'

    for link in links:
        uri = link['uri']

        # Skip non-relative links (http, https, mailto, anchors, etc.)
        if not uri or uri.startswith(('http://', 'https://', 'mailto:', '#', 'ftp://')):
            continue

        # Skip image references and non-file links
        if uri.startswith(('data:', 'javascript:')):
            continue

        # Resolve the target path relative to the file's directory
        try:
            target = (file_dir / uri).resolve()
        except (ValueError, OSError):
            violations.append({
                'rule': 'R8',
                'line': link['line'],
                'message': f'Invalid link target: {uri}',
                'fix': 'Use a valid relative path'
            })
            continue

        # Check if target is within the allowed scope
        # Allowed: same directory or one subdirectory deep
        try:
            rel_to_file = target.relative_to(file_dir.resolve())
        except ValueError:
            # Target is outside the file's directory
            if not is_routing:
                violations.append({
                    'rule': 'R8',
                    'line': link['line'],
                    'message': f'Link references file outside parent folder: {uri}',
                    'fix': 'Only docs/ROUTING.md may reference files outside its parent folder'
                })
            continue

        # Check depth: allowed up to 1 subfolder deep
        parts = rel_to_file.parts
        if len(parts) > 2:  # e.g., ['subfolder', 'file.md'] is depth 2
            violations.append({
                'rule': 'R8',
                'line': link['line'],
                'message': f'Link references file more than one subfolder deep: {uri}',
                'fix': 'INDEX.md may only reference files in its own folder and one subfolder deep'
            })

    return violations


def validate_file(filepath: Path, docs_root: Path) -> dict:
    """Validate a single file for R7/R8 compliance.

    Returns a dict with file path, pass/fail status, and violations.
    """
    result = {
        'file': str(filepath),
        'passed': True,
        'violations': []
    }

    try:
        content = filepath.read_text(encoding='utf-8')
    except Exception as e:
        result['passed'] = False
        result['violations'].append({
            'rule': 'SYSTEM',
            'line': 0,
            'message': f'Failed to read file: {e}',
            'fix': 'Check file permissions and encoding'
        })
        return result

    violations = []

    # R7: Check link format (applies to all markdown files)
    violations.extend(check_r7_links(content))

    # R8: Check INDEX.md specific requirements
    if filepath.name == 'INDEX.md':
        violations.extend(check_r8_frontmatter(content, filepath))
        violations.extend(check_r8_table(content))
        violations.extend(check_r8_scope(content, filepath, docs_root))

    if violations:
        result['passed'] = False
        result['violations'] = violations

    return result


def find_markdown_files(path: Path) -> list[Path]:
    """Find all markdown files in the given path.

    If path is a file, returns [path].
    If path is a directory, returns all .md files recursively.
    """
    if path.is_file():
        return [path]
    elif path.is_dir():
        return sorted(path.rglob('*.md'))
    else:
        return []


def main():
    parser = argparse.ArgumentParser(
        description='Validate R7/R8 compliance for documentation files.',
        epilog='''
Examples:
  python3 scripts/validate-index-standards.py docs/
  python3 scripts/validate-index-standards.py docs/standards/INDEX.md
  python3 scripts/validate-index-standards.py docs/ docs/solutions/

Rules checked:
  R7: All markdown links must use [name](uri) format
  R8: INDEX.md files must have YAML frontmatter with tags and description,
      a table with Link and Description columns, and scoped references
      (own folder + one subfolder deep)
'''
    )
    parser.add_argument(
        'paths',
        nargs='+',
        help='Files or directories to validate (recursive for directories)'
    )

    args = parser.parse_args()

    # Find docs root (directory containing the validated files)
    docs_root = None
    for path_str in args.paths:
        p = Path(path_str).resolve()
        if p.is_dir():
            docs_root = p
            break
    if docs_root is None:
        docs_root = Path.cwd()

    # Collect all markdown files
    all_files = []
    for path_str in args.paths:
        p = Path(path_str)
        if not p.exists():
            print(json.dumps({
                'error': f'Path not found: {path_str}'
            }), file=sys.stderr)
            sys.exit(1)
        all_files.extend(find_markdown_files(p))

    if not all_files:
        print(json.dumps({
            'error': 'No markdown files found in specified paths'
        }), file=sys.stderr)
        sys.exit(1)

    # Validate each file
    results = []
    all_passed = True

    for filepath in all_files:
        result = validate_file(filepath, docs_root)
        results.append(result)
        if not result['passed']:
            all_passed = False

    # Output results as JSON to stderr
    output = {
        'files_checked': len(results),
        'files_passed': sum(1 for r in results if r['passed']),
        'files_failed': sum(1 for r in results if not r['passed']),
        'results': results
    }

    print(json.dumps(output, indent=2), file=sys.stderr)

    sys.exit(0 if all_passed else 1)


if __name__ == '__main__':
    main()
