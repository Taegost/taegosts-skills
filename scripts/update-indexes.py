#!/usr/bin/env python3
"""
update-indexes.py -- Generate INDEX.md files for documentation directories.

Recursively scans docs/ subdirectories and creates/updates INDEX.md files
following R8 format. Each INDEX.md lists markdown files in its directory
with title (from first # heading) and description (from first paragraph).

Delegates to scripts/index-scripts.py for script directory indexing.

Usage:
    python3 scripts/update-indexes.py
    python3 scripts/update-indexes.py --dry-run
    python3 scripts/update-indexes.py --dir docs/plans

Exit codes:
    0 - Success (INDEX.md files generated or nothing to do)
    1 - Error (invalid arguments, unreadable directory)

Output: Prints generated file paths to stdout.
"""

import argparse
import re
import subprocess
import sys
from pathlib import Path


def extract_title(filepath: Path) -> str | None:
    """Extract the first # heading from a markdown file.

    Properly tracks YAML frontmatter boundaries (opening `---` to closing `---`)
    to avoid returning headings that appear inside frontmatter content.

    Returns the heading text (without the # prefix), or None if not found.
    """
    try:
        with open(filepath, encoding="utf-8") as f:
            in_frontmatter = False
            frontmatter_started = False
            for line in f:
                stripped = line.strip()
                # Track frontmatter state: first --- starts it, second --- ends it
                if stripped == "---":
                    if not frontmatter_started:
                        frontmatter_started = True
                        in_frontmatter = True
                    else:
                        in_frontmatter = False
                    continue
                    continue
                # Skip any line inside frontmatter
                if in_frontmatter:
                    continue
                # Match first heading outside frontmatter
                match = re.match(r"^#\s+(.+)$", stripped)
                if match:
                    return match.group(1).strip()
    except (OSError, UnicodeDecodeError):
        return None
    return None


def extract_description(filepath: Path) -> str | None:
    """Extract the first non-empty paragraph from a markdown file.

    Skips YAML frontmatter and headings, returns the first paragraph
    of body text (up to 200 chars). Returns None if not found.
    """
    try:
        with open(filepath, encoding="utf-8") as f:
            content = f.read()
    except (OSError, UnicodeDecodeError):
        return None

    # Strip YAML frontmatter
    content = re.sub(r"^---\s*\n.*?\n---\s*\n", "", content, count=1, flags=re.DOTALL)

    # Find first non-empty paragraph after skipping headings
    lines = content.splitlines()
    paragraph_lines = []
    in_paragraph = False

    for line in lines:
        stripped = line.strip()
        # Skip blank lines before paragraph starts
        if not stripped and not in_paragraph:
            continue
        # Skip headings
        if stripped.startswith("#"):
            if in_paragraph:
                break
            continue
        # Skip table rows, horizontal rules, code fences
        if stripped.startswith("|") or stripped.startswith("---") or stripped.startswith("```"):
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

    if not paragraph_lines:
        return None

    description = " ".join(paragraph_lines)
    # Truncate to 200 chars
    if len(description) > 200:
        description = description[:197] + "..."
    return description


def collect_docs(directory: Path) -> list[dict]:
    """Collect markdown files and subdirectory INDEX.md references.

    Returns a sorted list of dicts with keys: name, description, is_index.
    """
    entries = []

    if not directory.is_dir():
        return entries

    for filepath in sorted(directory.iterdir()):
        if not filepath.is_file():
            continue
        if filepath.suffix != ".md":
            continue
        # Skip existing INDEX.md (we're regenerating it)
        if filepath.name == "INDEX.md":
            continue

        title = extract_title(filepath) or filepath.stem
        description = extract_description(filepath) or "(no description)"
        entries.append({
            "name": filepath.name,
            "description": description,
            "is_index": False,
        })

    # Also reference INDEX.md files in immediate subdirectories (R8 scoping)
    for subdir in sorted(directory.iterdir()):
        if not subdir.is_dir():
            continue
        sub_index = subdir / "INDEX.md"
        if sub_index.exists():
            title = extract_title(sub_index) or subdir.name
            description = extract_description(sub_index) or f"Index of {subdir.name}/."
            entries.append({
                "name": f"{subdir.name}/INDEX.md",
                "description": description,
                "is_index": True,
            })

    return entries


def generate_index_md(entries: list[dict], title: str, description: str,
                      owner: str = "wave-2-dispatch-index-automation") -> str:
    """Generate INDEX.md content in R3/R8 format.

    Args:
        entries: List of entry dicts (from collect_docs).
        title: Top-level heading text.
        description: Frontmatter description text.
        owner: Plan or project identifier.

    Returns:
        Markdown content string.
    """
    from datetime import date
    today = date.today().isoformat()

    lines = [
        "---",
        f'title: "{title}"',
        f'description: "{description}"',
        "status: active",
        'version: "1.0"',
        f"created: {today}",
        f"last-updated: {today}",
        f"owner: {owner}",
        "dependencies: []",
        "tags: [index]",
        "---",
        "",
        f"# {title}",
        "",
        description,
        "",
        "| Link | Description |",
        "|------|-------------|",
    ]

    for entry in entries:
        name = entry["name"]
        desc = entry["description"]
        # Build relative path from the INDEX.md location to the target file
        # For script directories, files live in the same dir as the INDEX.md
        # For docs directories, files also live in the same dir
        # Subdirectory INDEX.md files are referenced as "subdir/INDEX.md"
        if "/" in name:
            # Subdirectory reference — already relative path
            link_path = name
        else:
            # File in same directory
            link_path = f"./{name}"
        lines.append(f"| [{name}]({link_path}) | {desc} |")

    lines.append("")  # trailing newline
    return "\n".join(lines)


def derive_title(directory: Path) -> str:
    """Derive a human-readable title from a directory path.

    Examples:
        docs/standards -> Standards Index
        docs/plans -> Plans Index
        docs/solutions/conventions -> Conventions Index
    """
    dir_name = directory.name
    # Convert hyphens/underscores to spaces, title case
    human_name = dir_name.replace("-", " ").replace("_", " ").title()
    return f"{human_name} Index"


def derive_description(directory: Path, repo_root: Path) -> str:
    """Derive a description for the INDEX.md frontmatter."""
    try:
        rel = directory.relative_to(repo_root)
    except ValueError:
        rel = directory
    return f"Index of documentation in {rel}/."


def process_directory(directory: Path, repo_root: Path,
                      dry_run: bool = False) -> Path | None:
    """Scan a docs directory and generate its INDEX.md.

    Returns the path to the generated INDEX.md, or None if nothing to index.
    """
    entries = collect_docs(directory)

    if not entries:
        return None

    title = derive_title(directory)
    description = derive_description(directory, repo_root)
    index_path = directory / "INDEX.md"
    content = generate_index_md(entries, title, description)

    if dry_run:
        print(f"[dry-run] Would write {index_path}", file=sys.stderr)
        print(content)
        return index_path

    # Atomic write: write to temp file, then rename to target
    # This prevents partial writes if the process is interrupted
    import tempfile
    tmp_path = None
    try:
        with tempfile.NamedTemporaryFile(
            mode="w",
            encoding="utf-8",
            dir=directory,
            delete=False,
            suffix=".tmp",
        ) as tmp:
            tmp.write(content)
            tmp_path = Path(tmp.name)
        # os.replace is atomic on POSIX systems
        tmp_path.replace(index_path)
    except Exception as e:
        print(f"Error: Failed to write {index_path}: {e}", file=sys.stderr)
        # Clean up temp file if it still exists
        if tmp_path is not None and tmp_path.exists():
            tmp_path.unlink()
        sys.exit(1)

    return index_path


def run_index_scripts(repo_root: Path, dry_run: bool = False) -> list:
    """Delegate script indexing to index-scripts.py.

    Exits with error if index-scripts.py fails. Returns the list of
    generated file paths (one per non-dry-run stdout line) so the caller
    can stage them.
    """
    script = repo_root / "scripts" / "index-scripts.py"
    if not script.exists():
        print(f"Warning: {script} not found, skipping script indexing.",
              file=sys.stderr)
        return []

    cmd = [sys.executable, str(script)]
    if dry_run:
        cmd.append("--dry-run")

    result = subprocess.run(cmd, capture_output=True, text=True, check=False)
    if result.stdout:
        print(result.stdout, end="")
    if result.stderr:
        print(result.stderr, end="", file=sys.stderr)

    # Check return code - don't silently ignore failures
    if result.returncode != 0:
        print(f"Error: index-scripts.py failed with exit code {result.returncode}",
              file=sys.stderr)
        sys.exit(result.returncode)

    if dry_run:
        return []
    return [Path(line) for line in result.stdout.splitlines() if line.strip()]


def stage_generated_files(repo_root: Path, paths: list) -> None:
    """Git-stage generated files so a pre-commit hook run picks them up
    automatically, without requiring the user to re-add and re-commit.

    Silently skips paths outside repo_root (e.g. when --dir points at a
    directory outside the repo, as in tests) since those can't be staged.
    """
    repo_root = repo_root.resolve()
    in_repo = []
    for p in paths:
        if not p.exists():
            continue
        try:
            p.resolve().relative_to(repo_root)
        except ValueError:
            continue
        in_repo.append(str(p))
    if not in_repo:
        return
    result = subprocess.run(
        ["git", "add", "--"] + in_repo,
        cwd=repo_root, capture_output=True, text=True, check=False,
    )
    if result.returncode != 0:
        print(f"Warning: failed to stage generated index files: {result.stderr}",
              file=sys.stderr)


def main():
    parser = argparse.ArgumentParser(
        description="Generate INDEX.md files for documentation directories.",
        epilog="""
Examples:
  python3 scripts/update-indexes.py
  python3 scripts/update-indexes.py --dry-run
  python3 scripts/update-indexes.py --dir docs/plans

Recursively scans docs/ and generates INDEX.md in each directory containing
markdown files. Also delegates to index-scripts.py for script indexing.
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
        help="Process only this directory (default: docs/ and scripts/)",
    )
    parser.add_argument(
        "--skip-scripts",
        action="store_true",
        help="Skip delegating to index-scripts.py",
    )

    args = parser.parse_args()

    repo_root = Path(__file__).resolve().parent.parent
    generated = []

    if args.dir:
        # Process a single directory (non-recursive)
        target = Path(args.dir)
        if not target.is_absolute():
            target = repo_root / target
        if not target.is_dir():
            print(f"Error: Directory not found: {target}", file=sys.stderr)
            sys.exit(1)

        result = process_directory(target, repo_root, args.dry_run)
        if result:
            generated.append(result)
    else:
        # Recursively scan docs/
        docs_dir = repo_root / "docs"
        if docs_dir.is_dir():
            # Walk bottom-up so parent INDEX.md can reference child INDEX.md
            for dirpath in sorted(
                [d for d in docs_dir.rglob("*") if d.is_dir()],
                key=lambda p: len(p.parts),
                reverse=True,
            ):
                result = process_directory(dirpath, repo_root, args.dry_run)
                if result:
                    generated.append(result)

            # Process docs/ itself last
            result = process_directory(docs_dir, repo_root, args.dry_run)
            if result:
                generated.append(result)

        # Delegate to index-scripts.py for script directories
        if not args.skip_scripts:
            generated.extend(run_index_scripts(repo_root, args.dry_run))

    if not generated and not args.skip_scripts:
        print("No documentation directories found to index.", file=sys.stderr)

    for path in generated:
        print(path)

    if not args.dry_run and generated:
        stage_generated_files(repo_root, generated)

    sys.exit(0)


if __name__ == "__main__":
    main()
