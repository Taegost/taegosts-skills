#!/usr/bin/env python3
"""
Non-interactive plan location script.

Given an optional path, returns the plan path or empty string.
Uses keyword extraction from the branch name to match plans in docs/plans/.

Usage:
    python3 scripts/locate-plan.py [path]
    python3 scripts/locate-plan.py  # blank: auto-discover from branch name

Exit codes:
    0 - Success (plan found or empty result)
    1 - Error (unreadable file, detached HEAD, etc.)

Output: JSON with keys:
    path: plan file path (empty string if not found)
    error: error message (empty string if no error)
"""

import json
import os
import re
import subprocess
import sys
from pathlib import Path


def get_current_branch() -> str | None:
    """Get the current git branch name."""
    try:
        result = subprocess.run(
            ['git', 'symbolic-ref', '--short', 'HEAD'],
            capture_output=True,
            text=True,
            timeout=10
        )
        if result.returncode == 0:
            return result.stdout.strip()
    except Exception:
        pass

    return None


def extract_keywords_from_branch(branch_name: str) -> list[str]:
    """Extract meaningful keywords from a branch name.

    Branch naming conventions:
    - feature/description-keywords
    - fix/issue-description
    - 123-ticket-description

    Returns list of lowercase keywords.
    """
    if not branch_name:
        return []

    # Remove common prefixes
    name = re.sub(r'^(feature|fix|bugfix|hotfix|chore|docs|refactor|test)/', '', branch_name)

    # Remove ticket numbers (e.g., 123-)
    name = re.sub(r'^\d+-', '', name)

    # Split on hyphens and underscores
    keywords = re.split(r'[-_]', name)

    # Filter out short words and common stop words
    stop_words = {'a', 'an', 'the', 'is', 'are', 'was', 'were', 'be', 'been', 'being',
                  'have', 'has', 'had', 'do', 'does', 'did', 'will', 'would', 'could',
                  'should', 'may', 'might', 'shall', 'can', 'to', 'of', 'in', 'for',
                  'on', 'with', 'at', 'by', 'from', 'as', 'into', 'through', 'during',
                  'before', 'after', 'above', 'below', 'between', 'out', 'off', 'over',
                  'under', 'again', 'further', 'then', 'once'}

    keywords = [kw.lower() for kw in keywords if len(kw) >= 3 and kw.lower() not in stop_words]

    return keywords


def find_plan_by_keywords(keywords: list[str], plans_dir: Path) -> str | None:
    """Find the best matching plan file based on keywords.

    Returns the path to the best match, or None if no match.
    """
    if not keywords or not plans_dir.exists():
        return None

    # Get all plan files
    plan_files = list(plans_dir.glob('*.md')) + list(plans_dir.glob('*.html'))
    if not plan_files:
        return None

    # Score each plan file based on keyword matches
    scores = []
    for plan_file in plan_files:
        filename = plan_file.stem.lower()
        # Extract keywords from filename (remove date prefix)
        filename_keywords = re.split(r'[-_]', re.sub(r'^\d{4}-\d{2}-\d{2}-\d{3}-', '', filename))

        # Count matching keywords
        matches = sum(1 for kw in keywords if kw in filename_keywords or kw in filename)
        if matches > 0:
            scores.append((matches, plan_file))

    if not scores:
        return None

    # Sort by match count (descending), then by filename (descending for recency)
    scores.sort(key=lambda x: (x[0], x[1].name), reverse=True)

    # Return the best match
    return str(scores[0][1])


def main():
    # Get the explicit path argument (if any)
    explicit_path = sys.argv[1] if len(sys.argv) > 1 else None

    # If explicit path provided, validate and return it
    if explicit_path:
        path = Path(explicit_path)
        if path.exists():
            print(json.dumps({
                'path': str(path),
                'error': ''
            }))
            sys.exit(0)
        else:
            print(json.dumps({
                'path': '',
                'error': f'File not found: {explicit_path}'
            }))
            sys.exit(1)

    # No explicit path — auto-discover from branch name
    branch = get_current_branch()
    if not branch:
        print(json.dumps({
            'path': '',
            'error': 'Could not determine current branch (detached HEAD?)'
        }))
        sys.exit(1)

    # Extract keywords from branch name
    keywords = extract_keywords_from_branch(branch)
    if not keywords:
        # No meaningful keywords is a "not found" condition, not an error
        print(json.dumps({
            'path': '',
            'error': ''
        }))
        sys.exit(0)

    # Find matching plan (anchor to repo root, not CWD)
    script_dir = Path(__file__).parent
    repo_root = script_dir.parent
    plans_dir = repo_root / 'docs' / 'plans'
    plan_path = find_plan_by_keywords(keywords, plans_dir)

    if plan_path:
        print(json.dumps({
            'path': plan_path,
            'error': ''
        }))
        sys.exit(0)
    else:
        print(json.dumps({
            'path': '',
            'error': ''
        }))
        sys.exit(0)


if __name__ == '__main__':
    main()
