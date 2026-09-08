#!/usr/bin/env python3
"""
index-scripts.py -- Generate INDEX.md files for script directories.

Scans scripts/ and skills/*/scripts/ for .sh and .py files, extracts R3
frontmatter descriptions, and generates INDEX.md files in R8 format.

R3 frontmatter formats:
  Shell (.sh): line 2 is "# script-name -- description"
  Python (.py): first line of module docstring (after shebang)

Regeneration is content-idempotent: an existing INDEX.md keeps its
"created:" date and its hand-maintained "owner:" field, and is left
completely untouched when the regenerated content differs only in the
"last-updated:" line.

Hand-maintained content between the resolution note and the link table,
and any content after the table, is preserved across regeneration. A
generated-looking INDEX.md without a link table aborts regeneration
with a diagnostic instead of being silently overwritten.

Usage:
    python3 scripts/index-scripts.py
    python3 scripts/index-scripts.py --dry-run
    python3 scripts/index-scripts.py --dir <path>

Exit codes:
    0 - Success (INDEX.md files generated)
    1 - Error (invalid arguments, unreadable directory, unpreservable
        existing INDEX.md)

Output: Prints generated file paths to stdout.
"""

import argparse
import re
import sys
from datetime import date
from pathlib import Path

# Import bootstrap: the generators run as standalone scripts, so
# scripts/lib/ is not on sys.path. Mirror how shell scripts source lib/
# by adding this script's own lib/ directory before the shared-module
# import below.
_LIB_DIR = str(Path(__file__).resolve().parent / "lib")
if _LIB_DIR not in sys.path:
    sys.path.insert(0, _LIB_DIR)

from index_common import (
    DEFAULT_OWNER,
    RESOLUTION_NOTE,
    TABLE_HEADER,
    IndexStructureError,
    differs_only_by_last_updated,
    extract_extra_sections,
    read_frontmatter_field,
)


def extract_shell_description(filepath: Path) -> str | None:
    """Extract R3 description from a shell script (line 2).

    Expected format on line 2:
        # script-name -- description text

    Returns the description text, or None if not found.
    """
    try:
        with open(filepath, encoding="utf-8") as f:
            lines = f.readlines()
    except (OSError, UnicodeDecodeError):
        return None

    if len(lines) < 2:
        return None

    line = lines[1].strip()
    # Match: # name -- description
    match = re.match(r"^#\s+\S+\s+--\s+(.+)$", line)
    if match:
        return match.group(1).strip()

    return None


def extract_python_description(filepath: Path) -> str | None:
    """Extract description from a Python script's module docstring.

    Looks for a triple-quoted docstring starting on line 2 or 3
    (after shebang). Returns the first non-empty line of the docstring.

    Returns the description text, or None if not found.
    """
    try:
        with open(filepath, encoding="utf-8") as f:
            content = f.read()
    except (OSError, UnicodeDecodeError):
        return None

    # Match module docstring: optional shebang + """..."""
    # The opening triple-quote must be within the first 5 lines
    lines = content.splitlines()
    head_text = "\n".join(lines[:5])

    # Find where the docstring opens (must be in first 5 lines)
    open_match = re.search(r'"""', head_text)
    if not open_match:
        open_match = re.search(r"'''", head_text)
    if not open_match:
        return None

    # Now find the closing triple-quote in the full content
    quote_char = head_text[open_match.start():open_match.start() + 3]
    # Search from the opening quote for the closing quote
    rest = content[open_match.start():]
    close_pos = rest.find(quote_char, 3)
    if close_pos == -1:
        return None

    docstring = rest[3:close_pos].strip()

    # Return the first non-empty line
    for line in docstring.splitlines():
        line = line.strip()
        if not line:
            continue
        # Strip "name -- " or "name - " prefix if present (R3-style docstring)
        # Also handles "U11: name -- description" prefix pattern
        prefix_match = re.match(
            r"^(?:U\d+:\s*)?[\w.-]+\s+--?\s+(.+)$", line
        )
        if prefix_match:
            return prefix_match.group(1).strip()
        return line

    return None


def extract_description(filepath: Path) -> str | None:
    """Extract description from a script file based on its extension."""
    if filepath.suffix == ".sh":
        return extract_shell_description(filepath)
    elif filepath.suffix == ".py":
        return extract_python_description(filepath)
    return None


def scan_scripts(directory: Path) -> list[dict]:
    """Scan a directory for .sh and .py scripts and extract metadata.

    Returns a sorted list of dicts with keys: name, description, path.
    Scripts without extractable descriptions get an empty description.
    """
    scripts = []

    if not directory.is_dir():
        return scripts

    for filepath in sorted(directory.iterdir()):
        # Recurse into helper-library subdirectories (e.g. scripts/lib/),
        # indexing them under their relative path (e.g. lib/input-validation.sh)
        if filepath.is_dir():
            if filepath.name == "lib":
                for libfile in sorted(filepath.iterdir()):
                    if not libfile.is_file() or libfile.suffix not in (".sh", ".py"):
                        continue
                    description = extract_description(libfile) or ""
                    scripts.append({
                        "name": f"{filepath.name}/{libfile.name}",
                        "description": description,
                        "path": libfile,
                    })
            continue

        if filepath.suffix not in (".sh", ".py"):
            continue
        # Skip INDEX.md and other non-script files
        if filepath.name == "INDEX.md":
            continue

        description = extract_description(filepath) or ""
        scripts.append({
            "name": filepath.name,
            "description": description,
            "path": filepath,
        })

    scripts.sort(key=lambda s: s["name"])
    return scripts


def generate_index_md(scripts: list[dict], title: str, description: str,
                      rel_dir: Path,
                      owner: str = DEFAULT_OWNER,
                      created: str | None = None,
                      last_updated: str | None = None,
                      extra_sections: str | None = None,
                      trailing_content: str | None = None) -> str:
    """Generate INDEX.md content in R3/R8 format.

    Args:
        scripts: List of script metadata dicts.
        title: Top-level heading text.
        description: Frontmatter description text.
        rel_dir: Directory relative to repo root (for link paths).
        owner: Plan or project identifier (pass a pre-existing index's owner
            to preserve it across regeneration).
        created: Frontmatter created date (defaults to today for new files).
        last_updated: Frontmatter last-updated date (defaults to today).
        extra_sections: Hand-maintained content carried over from the
            existing INDEX.md, inserted between the resolution note and the
            link table.
        trailing_content: Hand-maintained content carried over from after
            the existing link table, appended after the regenerated rows.

    Returns:
        Markdown content string.
    """
    today = date.today().isoformat()
    created = created or today
    last_updated = last_updated or today

    lines = [
        "---",
        f'title: "{title}"',
        f'description: "{description}"',
        "status: active",
        'version: "1.0"',
        f"created: {created}",
        f"last-updated: {last_updated}",
        f"owner: {owner}",
        "dependencies: []",
        "tags: [index, scripts]",
        "---",
        "",
        f"# {title}",
        "",
        f"{description}",
        "",
        RESOLUTION_NOTE,
        "",
    ]

    if extra_sections:
        lines.extend([extra_sections, ""])

    lines.extend([
        TABLE_HEADER,
        "|------|-------------|",
    ])

    for script in scripts:
        name = script["name"]
        desc = script["description"] or "(no description)"
        lines.append(f"| [{name}](./{name}) | {desc} |")

    if trailing_content:
        lines.extend(["", trailing_content, ""])
    else:
        lines.append("")  # trailing newline
    return "\n".join(lines)


def process_directory(directory: Path, title: str, description: str,
                      dry_run: bool = False) -> Path | None:
    """Scan a directory and generate its INDEX.md.

    Idempotent: an existing INDEX.md keeps its "created:" date and its
    hand-maintained "owner:" field, and is left completely untouched when
    the regenerated content differs only in the "last-updated:" line.
    Hand-maintained content between the resolution note and the link
    table, and any content after the table, is carried over unchanged.

    Aborts the run (diagnostic on stderr, exit 1, no write) when the
    existing INDEX.md looks generator-maintained but has no link table,
    since its hand-maintained content could not be safely preserved.

    Returns the path to the written INDEX.md, or None if no scripts found or
    nothing changed.
    """
    scripts = scan_scripts(directory)

    if not scripts:
        return None

    index_path = directory / "INDEX.md"
    existing: str | None = None
    if index_path.exists():
        try:
            existing = index_path.read_text(encoding="utf-8")
        except (OSError, UnicodeDecodeError):
            existing = None

    created = (read_frontmatter_field(existing, "created")
               if existing else None) or date.today().isoformat()
    owner = (read_frontmatter_field(existing, "owner")
             if existing else None) or DEFAULT_OWNER
    extra_sections = trailing_content = None
    if existing:
        try:
            extra_sections, trailing_content = extract_extra_sections(existing)
        except IndexStructureError as e:
            print(f"Error: refusing to regenerate {index_path}: {e}",
                  file=sys.stderr)
            sys.exit(1)
    content = generate_index_md(scripts, title, description, directory,
                                owner=owner,
                                created=created,
                                last_updated=date.today().isoformat(),
                                extra_sections=extra_sections,
                                trailing_content=trailing_content)

    if dry_run:
        print(f"[dry-run] Would write {index_path}", file=sys.stderr)
        print(content)
        return index_path

    if existing is not None and differs_only_by_last_updated(existing, content):
        return None

    index_path.write_text(content, encoding="utf-8")
    return index_path


def main():
    parser = argparse.ArgumentParser(
        description="Generate INDEX.md files for script directories.",
        epilog="""
Examples:
  python3 scripts/index-scripts.py
  python3 scripts/index-scripts.py --dry-run
  python3 scripts/index-scripts.py --dir scripts/

Generates INDEX.md in scripts/ and skills/*/scripts/ using R8 format.
""",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print generated content without writing files",
    )
    parser.add_argument(
        "--dir",
        type=str,
        default=None,
        help="Process only this directory (default: scripts/ and skills/*/scripts/)",
    )

    args = parser.parse_args()

    repo_root = Path(__file__).resolve().parent.parent
    generated = []

    if args.dir:
        # Process a single directory
        target = Path(args.dir)
        if not target.is_absolute():
            target = repo_root / target
        if not target.is_dir():
            print(f"Error: Directory not found: {target}", file=sys.stderr)
            sys.exit(1)

        title = f"{target.name.title()} Scripts"
        try:
            rel = target.relative_to(repo_root)
        except ValueError:
            rel = target
        desc = f"Index of all scripts in {rel}/."
        result = process_directory(target, title, desc, args.dry_run)
        if result:
            generated.append(result)
    else:
        # Process scripts/
        scripts_dir = repo_root / "scripts"
        if scripts_dir.is_dir():
            result = process_directory(
                scripts_dir,
                "Scripts Index",
                "Index of all scripts in scripts/.",
                args.dry_run,
            )
            if result:
                generated.append(result)

        # Process skills/*/scripts/
        skills_dir = repo_root / "skills"
        if skills_dir.is_dir():
            for skill_dir in sorted(skills_dir.iterdir()):
                if not skill_dir.is_dir():
                    continue
                # Skip _deprecated directories
                if skill_dir.name.startswith("_"):
                    continue
                skill_scripts_dir = skill_dir / "scripts"
                if not skill_scripts_dir.is_dir():
                    continue

                skill_name = skill_dir.name
                result = process_directory(
                    skill_scripts_dir,
                    f"{skill_name} Scripts",
                    f"Index of scripts in skills/{skill_name}/scripts/.",
                    args.dry_run,
                )
                if result:
                    generated.append(result)

    if not generated:
        print("No script directories found or no scripts to index.",
              file=sys.stderr)
        sys.exit(0)

    for path in generated:
        print(path)

    sys.exit(0)


if __name__ == "__main__":
    main()
