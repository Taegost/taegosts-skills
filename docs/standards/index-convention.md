# Index Convention

Canonical standard for INDEX.md files across all documentation in taegosts-skills.

## Rule (R8)

Every directory containing documentation should have an INDEX.md that catalogs the files it contains and references its immediate children's indexes.

## Scoping Rules

Each INDEX.md is scoped to:

1. **Its own folder** — all markdown files directly in the same directory.
2. **One subfolder deep** — INDEX.md files in immediate subdirectories (e.g., `docs/INDEX.md` may reference `docs/solutions/INDEX.md` but not `docs/solutions/conventions/INDEX.md`).

### Exception: ROUTING.md

Only `docs/ROUTING.md` may reference files outside its parent folder. No other INDEX.md may reference files that are not in its own folder or one subfolder deep.

## Required Structure

Every INDEX.md must include:

### 1. YAML Frontmatter

```yaml
---
tags: [index]
description: Brief description of what this index catalogs.
---
```

### 2. Heading

A top-level heading (`# Index Name`) that describes the section.

### 3. Reference Table

A markdown table with at minimum a **Link** and **Description** column.

```markdown
| Link | Description |
|------|-------------|
| [agent-standards.md](agent-standards.md) | Agent definition format and frontmatter schema |
| [solutions/INDEX.md](solutions/INDEX.md) | Solution documents index |
```

## Full Example

```markdown
---
tags: [index]
description: Index of standards for the taegosts-skills repository.
---

# Standards Index

Canonical standards for the taegosts-skills repository.

| Link | Description |
|------|-------------|
| [agent-standards.md](agent-standards.md) | Agent definition format: frontmatter schema, heading sub-templates, dispatch patterns |
| [link-convention.md](link-convention.md) | Standard for markdown link format across all documentation |
| [index-convention.md](index-convention.md) | Standard for INDEX.md file structure and scoping |
```

## Validation

Use `scripts/validate-index-standards.py` to check R8 compliance. The script verifies:

- YAML frontmatter contains `tags` and `description`.
- A table with **Link** and **Description** columns is present.
- All referenced files are within scope (own folder or one subfolder deep).
- Only `docs/ROUTING.md` references files outside its parent folder.
