#!/usr/bin/env python3
"""
U14: detect-overlap.py - fuzzy overlap scoring for solutions
Given a proposed solution title and tags, search existing solutions for overlap.

Input: --title <string> --tags <comma-separated> --solutions-dir <path>
Output: JSON with {matches: [{path, overlap_score, matching_dimensions}]}
Exit codes: 0 (matches found), 1 (error), 2 (no matches)
"""

import argparse
import json
import os
import re
import sys
from difflib import SequenceMatcher
from pathlib import Path


def parse_frontmatter(filepath):
    """Parse YAML frontmatter from a markdown file."""
    try:
        with open(filepath, "r", encoding="utf-8") as f:
            content = f.read()
    except (OSError, UnicodeDecodeError):
        return None

    if not content.startswith("---"):
        return None

    end = content.find("---", 3)
    if end == -1:
        return None

    fm_text = content[3:end].strip()
    result = {}
    in_tags_list = False

    for line in fm_text.split("\n"):
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            in_tags_list = False
            continue

        if in_tags_list and stripped.startswith("- "):
            tag = stripped[2:].strip().strip("\"'")
            if tag:
                result.setdefault("tags", []).append(tag)
            continue

        in_tags_list = False

        m = re.match(r'^title:\s*"?(.+?)"?\s*$', stripped)
        if m:
            result["title"] = m.group(1).strip()
            continue

        m = re.match(r"^tags:\s*\[(.+)\]\s*$", stripped)
        if m:
            tags_str = m.group(1)
            result["tags"] = [t.strip().strip("\"'") for t in tags_str.split(",")]
            continue

        if stripped == "tags:" or stripped == "tags: []":
            in_tags_list = True
            if stripped == "tags: []":
                result["tags"] = []
            continue

    return result if "title" in result else None


def title_similarity(a, b):
    """Compute title similarity (0-1) using SequenceMatcher + word overlap."""
    a_lower = a.lower()
    b_lower = b.lower()

    seq_ratio = SequenceMatcher(None, a_lower, b_lower).ratio()

    a_words = set(re.findall(r"\w+", a_lower))
    b_words = set(re.findall(r"\w+", b_lower))
    if a_words and b_words:
        word_overlap = len(a_words & b_words) / len(a_words | b_words)
    else:
        word_overlap = 0.0

    return (seq_ratio + word_overlap) / 2.0


def tag_overlap(a_tags, b_tags):
    """Compute tag overlap (0-1): intersection / total unique tags."""
    a_set = set(t.lower() for t in a_tags)
    b_set = set(t.lower() for t in b_tags)
    union = a_set | b_set
    if not union:
        return 0.0
    return len(a_set & b_set) / len(union)


def main():
    parser = argparse.ArgumentParser(
        description="Detect overlap between a proposed solution and existing solutions."
    )
    parser.add_argument("--title", required=True, help="Proposed solution title")
    parser.add_argument("--tags", required=True, help="Comma-separated tags")
    parser.add_argument("--solutions-dir", required=True, help="Path to solutions directory")
    args = parser.parse_args()

    if not args.title.strip():
        print('{"error":"title cannot be empty"}', file=sys.stderr)
        sys.exit(1)

    solutions_dir = Path(args.solutions_dir)
    if not solutions_dir.is_dir():
        err = json.dumps({"error": "solutions directory not found: " + args.solutions_dir})
        print(err, file=sys.stderr)
        sys.exit(1)

    proposed_tags = [t.strip() for t in args.tags.split(",") if t.strip()]
    matches = []

    for md_file in sorted(solutions_dir.rglob("*.md")):
        fm = parse_frontmatter(md_file)
        if fm is None:
            continue

        existing_title = fm.get("title", "")
        existing_tags = fm.get("tags", [])

        t_sim = title_similarity(args.title, existing_title)
        t_ovl = tag_overlap(proposed_tags, existing_tags)

        composite = 0.6 * t_sim + 0.4 * t_ovl

        if composite > 0.3:
            dims = []
            if t_sim > 0.3:
                dims.append("title")
            if t_ovl > 0.1:
                dims.append("tags")
            if not dims:
                dims.append("composite")

            matches.append({
                "path": str(md_file),
                "overlap_score": round(composite, 3),
                "matching_dimensions": dims,
            })

    matches.sort(key=lambda m: m["overlap_score"], reverse=True)

    result = {"matches": matches}
    print(json.dumps(result, indent=2))

    if matches:
        sys.exit(0)
    else:
        sys.exit(2)


if __name__ == "__main__":
    main()
