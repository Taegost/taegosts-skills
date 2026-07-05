# Link Convention

Canonical standard for markdown links across all documentation in taegosts-skills.

## Rule (R7)

All markdown links must use the standard `[name](uri)` format.

### Format

```
[descriptive-name](relative-or-absolute-uri)
```

### Requirements

- **Display text** must be descriptive and human-readable (e.g., `[KTD Normalization Policy](ktd-normalization-policy.md)` not `[click here](ktd-normalization-policy.md)`).
- **URI** must be a relative path for in-repo references (e.g., `../solutions/ktd-normalization-policy.md`).
- Bare URLs (e.g., `https://example.com/file.md`) are not permitted as standalone references — they must be wrapped in link syntax.
- Image links follow the same convention: `![alt text](uri)`.

### Examples

```markdown
See the [KTD Normalization Policy](../solutions/ktd-normalization-policy.md) for details.

The [agent standards](agent-standards.md) define the frontmatter schema.
```

### Validation

Use `scripts/validate-index-standards.py` to check R7 compliance. The script verifies that all markdown links in a file use the `[name](uri)` format.
