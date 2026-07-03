#!/usr/bin/env python3
"""
Verify whether a [literal] KTD specification appears in a target file.

Applies normalization rules from docs/solutions/ktd-normalization-policy.md
before comparing the KTD spec against the file content.

Usage:
    python3 scripts/verify-ktd-literal.py --spec "KTD spec text" --file <target-file>
    python3 scripts/verify-ktd-literal.py --spec-file <spec-file> --file <target-file>

Exit codes:
    0 - Match found
    1 - Mismatch (KTD not found in file)
    2 - Error (file not found, invalid args)

Output: JSON with keys:
    match: true/false
    spec: normalized KTD spec
    file: target file path
    found_at: line number where match starts (if match)
    diff: unified diff showing normalized spec vs closest match (if mismatch)
"""

import argparse
import difflib
import json
import re
import sys
from pathlib import Path


def normalize_whitespace(text: str) -> str:
    """Apply whitespace normalization (rules 1-2, 6).

    - Strip leading/trailing whitespace
    - Strip trailing whitespace per line
    - Normalize line endings to single newline
    """
    lines = text.splitlines()
    normalized = []
    for line in lines:
        # Strip trailing whitespace (rule 2)
        normalized.append(line.rstrip())
    # Strip leading/trailing blank lines (rule 1)
    while normalized and not normalized[0].strip():
        normalized.pop(0)
    while normalized and not normalized[-1].strip():
        normalized.pop()
    return '\n'.join(normalized)


def normalize_ansi_quoting(text: str) -> str:
    """Apply ANSI-C quoting normalization (rule 4).

    Converts $'...' to double-quote equivalent by expanding escape sequences.
    """
    def replace_ansi_c(match):
        content = match.group(1)
        # Expand common escape sequences
        content = content.replace('\\n', '\n')
        content = content.replace('\\t', '\t')
        content = content.replace('\\\\', '\\')
        content = content.replace("\\'", "'")
        content = content.replace('\\"', '"')
        return content

    # Match $'...' patterns
    pattern = r"\$'([^']*(?:\\.[^']*)*)'"
    return re.sub(pattern, replace_ansi_c, text)


def strip_inline_code_backticks(text: str) -> str:
    """Strip backticks from inline code spans (rule 5).

    Converts `code` to code.
    """
    return re.sub(r'`([^`]+)`', r'\1', text)


def normalize_for_comparison(text: str) -> str:
    """Apply all normalization rules for comparison.

    Order: ANSI-C quoting → backtick stripping → whitespace normalization.
    """
    text = normalize_ansi_quoting(text)
    text = strip_inline_code_backticks(text)
    text = normalize_whitespace(text)
    return text


def find_normalized_match(normalized_spec: str, normalized_content: str) -> int | None:
    """Find where the normalized spec appears in the normalized content.

    Returns the line number (1-based) where the match starts, or None.
    """
    spec_lines = normalized_spec.splitlines()
    content_lines = normalized_content.splitlines()

    if not spec_lines:
        return None

    # For single-line specs, search for substring in any content line
    if len(spec_lines) == 1:
        spec_line = spec_lines[0]
        for i, content_line in enumerate(content_lines, 1):
            if spec_line in content_line:
                return i
        return None

    # For multi-line specs, search for consecutive lines
    for i in range(len(content_lines) - len(spec_lines) + 1):
        # Check if the spec lines match starting at position i
        match = True
        for j, spec_line in enumerate(spec_lines):
            if spec_line not in content_lines[i + j]:
                match = False
                break
        if match:
            return i + 1  # 1-based line number

    return None


def generate_diff(normalized_spec: str, normalized_content: str) -> str:
    """Generate a unified diff showing spec vs closest content match.

    Returns a string with the diff, or empty string if no meaningful diff.
    """
    spec_lines = normalized_spec.splitlines(keepends=True)
    content_lines = normalized_content.splitlines(keepends=True)

    # Find the best matching region using SequenceMatcher
    matcher = difflib.SequenceMatcher(None, spec_lines, content_lines)
    best_match = matcher.find_longest_match(0, len(spec_lines), 0, len(content_lines))

    if best_match.size == 0:
        # No matching lines at all
        diff = difflib.unified_diff(
            spec_lines, [],
            fromfile='ktd-spec', tofile='file-content',
            lineterm=''
        )
        return '\n'.join(diff)

    # Extract the matching region from the file
    file_start = max(0, best_match.b - 2)
    file_end = min(len(content_lines), best_match.b + best_match.size + 2)
    region_lines = content_lines[file_start:file_end]

    diff = difflib.unified_diff(
        spec_lines, region_lines,
        fromfile='ktd-spec', tofile=f'file-content (lines {file_start+1}-{file_end})',
        lineterm=''
    )
    return '\n'.join(diff)


def main():
    parser = argparse.ArgumentParser(
        description='Verify whether a [literal] KTD spec appears in a target file.'
    )
    parser.add_argument(
        '--spec', type=str,
        help='KTD spec text to search for'
    )
    parser.add_argument(
        '--spec-file', type=str,
        help='File containing the KTD spec text'
    )
    parser.add_argument(
        '--file', type=str, required=True,
        help='Target file to search in'
    )
    parser.add_argument(
        '--json', action='store_true', default=True,
        help='Output as JSON (default)'
    )

    args = parser.parse_args()

    # Get the spec text
    if args.spec:
        spec_text = args.spec
    elif args.spec_file:
        spec_path = Path(args.spec_file)
        if not spec_path.exists():
            print(json.dumps({
                'error': f'Spec file not found: {spec_path}',
                'match': False
            }))
            sys.exit(2)
        try:
            spec_text = spec_path.read_text(encoding='utf-8')
        except Exception as e:
            print(json.dumps({
                'error': f'Failed to read spec file: {e}',
                'match': False
            }))
            sys.exit(2)
    else:
        print(json.dumps({
            'error': 'Either --spec or --spec-file is required',
            'match': False
        }))
        sys.exit(2)

    # Read the target file
    target_path = Path(args.file)
    if not target_path.exists():
        print(json.dumps({
            'error': f'Target file not found: {target_path}',
            'match': False
        }))
        sys.exit(2)

    try:
        file_content = target_path.read_text(encoding='utf-8')
    except Exception as e:
        print(json.dumps({
            'error': f'Failed to read target file: {e}',
            'match': False
        }))
        sys.exit(2)

    # Normalize both texts
    normalized_spec = normalize_for_comparison(spec_text)
    normalized_content = normalize_for_comparison(file_content)

    # Find the match
    found_at = find_normalized_match(normalized_spec, normalized_content)

    if found_at is not None:
        result = {
            'match': True,
            'spec': normalized_spec,
            'file': str(target_path),
            'found_at': found_at
        }
        print(json.dumps(result, indent=2))
        sys.exit(0)
    else:
        diff = generate_diff(normalized_spec, normalized_content)
        result = {
            'match': False,
            'spec': normalized_spec,
            'file': str(target_path),
            'diff': diff
        }
        print(json.dumps(result, indent=2))
        sys.exit(1)


if __name__ == '__main__':
    main()
