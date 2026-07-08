---
title: "INDEX.md Standards"
description: "Rules and requirements for INDEX.md file format, structure, and placement"
status: active
version: "1.0"
created: 2026-07-07
last-updated: 2026-07-07
owner: wave-2-u25-placement-rules
dependencies: []
tags: [standards, index, wave-2, r3, r7, r8]
---

# INDEX.md Standards

## Frontmatter Requirements (R3 Compliance)

Every INDEX.md file MUST have YAML frontmatter with:

```yaml
---
title: "Index of <Category/Tool/Script>"
description: "Brief description of what this index covers"
status: active
version: "1.0"
created: <YYYY-MM-DD>
last-updated: <YYYY-MM-DD>
owner: <plan-or-project-name>
dependencies: []
tags: [index, <category-specific-tags>]
---
```

**Required fields:**
- `title`: Descriptive title
- `description`: What this index covers (MUST NOT be empty)
- `status`: Usually "active"
- `version`: Semantic version string (quoted)
- `created`: ISO 8601 date
- `last-updated`: ISO 8601 date
- `owner`: Plan name or project identifier
- `tags`: Must include "index"

## Table Structure Requirements

INDEX.md files MUST use a markdown table with these columns:

| Link | Description |
|------|-------------|
| [file1.md](./file1.md) | One-line description of file1 |
| [file2.md](./file2.md) | One-line description of file2 |

**Column requirements:**
- **Link**: Markdown link with the filename as display text and a relative path from INDEX.md location (e.g. `[file.md](./file.md)`). This is the Wave 1 format and the authoritative standard — generators (index-scripts.py, update-indexes.py) produce this format.
- **Description**: One-line description (MUST NOT be empty or vague like "Documentation file")

**Description guidelines:**
- Be specific and useful
- Mention key purpose or audience
- Keep to one line
- Avoid generic phrases like "Contains information about"

## Link Validation Requirements

**All links MUST be valid:**
- Use filesystem paths, not URLs
- Validate with `find`/`ls`, not HTTP status checks
- Relative paths from INDEX.md location
- No trailing slashes on file paths

**Validation script behavior:**

```bash
# Correct validation
test -f "$path" && echo "VALID" || echo "BROKEN"

# Do NOT use HTTP-based validation
curl -I "$url"  # WRONG for local files
```

## Placement Rules

**When to create INDEX.md:**
- Directory with 2+ related files that form a logical grouping
- Entry points for navigation (scripts/, docs/plans/, skills/*/scripts/)
- Categories that benefit from overview and discovery

**When NOT to create INDEX.md:**
- Single file in a directory
- Files with no logical relationship
- Temporary, scratch, or archive directories
- Root directories (use ROUTING.md for top-level navigation)
- Directories where all files are already referenced in another INDEX.md

**Placement decision framework:**

```bash
# Should this directory have an INDEX.md?
count=$(ls -1 "$dir"/*.{md,py,sh} 2>/dev/null | wc -l)
has_grouping=$(check_if_files_are_related "$dir")

if [[ $count -ge 2 ]] && [[ "$has_grouping" == "true" ]]; then
  echo "Create INDEX.md"
else
  echo "Skip INDEX.md"
fi
```

**Examples of good placement:**
- `scripts/INDEX.md` -- Lists all utility scripts (20+ files)
- `docs/plans/INDEX.md` -- Lists all plan documents (10+ files)
- `skills/ts-commit/scripts/INDEX.md` -- Lists skill-specific scripts (5+ files)

**Examples of bad placement:**
- `notes/INDEX.md` -- Single unrelated note file
- `archive/INDEX.md` -- Archive directory, not for active navigation
- `skills/ts-work/INDEX.md` -- Skill with no scripts/ subdirectory (skip scripts index)

## Script Automation Requirements

`scripts/update-indexes.py` and `scripts/index-scripts.py` MUST:
1. Read standards from `standards/index-standards.md`
2. Generate R3-compliant frontmatter
3. Generate tables with Path and Description columns
4. Validate existing INDEX.md files against standards
5. Exit with non-zero status on validation failure

## Examples

**Good example:**
```markdown
---
title: "Index of Dispatch Standards"
description: "Documents related to bootstrap dispatch pattern and subagent standards"
status: active
version: "1.0"
created: 2026-07-07
last-updated: 2026-07-07
owner: wave-2-dispatch-index-automation
dependencies: []
tags: [index, dispatch, standards]
---

# Dispatch Standards Index

| Path | Description |
|------|-------------|
| bootstrap-dispatch-standard.md | Core bootstrap dispatch pattern specification |
| subagent-classifiertype-standard.md | Subagent type definitions and use cases |
| model-selection-hierarchy.md | Model selection rules (fable/sonnet/opus) |
```

**Bad example (violations marked):**
```markdown
---
title: "Index"  # ❌ Too vague
description: ""  # ❌ Empty description
status: active
version: 1.0  # ❌ Unquoted version
created: 2026-07-07
last-updated: 2026-07-07
owner: wave-2
tags: index  # ❌ Should be array
---

# Index

| File | Info |  # ❌ Wrong column names
|------|------|
| ./bootstrap-dispatch-standard.md | Docs  # ❌ Leading ./, vague description
| subagent-standard.md |  # ❌ Missing description
```

## Validation Checklist

Before marking an INDEX.md as complete, verify:
- [ ] Frontmatter has all required fields
- [ ] Description is non-empty and specific
- [ ] Table has Link and Description columns (Link column contains markdown links: `[name](path)`)
- [ ] All link paths are relative from INDEX.md location
- [ ] All descriptions are non-empty
- [ ] All links validate with filesystem checks
- [ ] Placement rules satisfied (2+ related files, not root, not archive)
- [ ] No duplicate coverage with another INDEX.md
- [ ] Follows R3 frontmatter standard
