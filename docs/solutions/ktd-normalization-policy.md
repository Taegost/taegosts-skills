# KTD Normalization Policy

This document defines the normalization rules for comparing `[literal]` KTD specifications against implementations. These rules are applied by `scripts/verify-ktd-literal.py` and by the Completeness/Correctness subagents in `ts-verify-implementation`.

## Purpose

Literal KTDs require exact string matching. However, minor formatting differences (whitespace, quoting style) can cause false positives if not normalized. This policy defines what constitutes a meaningful difference vs. acceptable formatting variation.

## Rules

### 1. Leading/Trailing Whitespace

**Rule:** Strip leading and trailing whitespace from both the KTD spec and the implementation before comparison.

**Rationale:** Indentation context varies between plan documents and implementation files. Leading whitespace is structural formatting, not content.

**Example:**
```
KTD spec:    "  ^[a-z][a-z0-9_-]*$  "
Implementation: "^[a-z][a-z0-9_-]*$"
Result: MATCH (leading/trailing whitespace stripped)
```

### 2. Per-Line Trailing Whitespace

**Rule:** For multi-line snippets, strip trailing whitespace from each line before comparison.

**Rationale:** Editors and formatters may add/remove trailing whitespace. This is formatting noise, not content.

**Example:**
```
KTD spec (line):    "  pattern: foo  "
Implementation (line): "  pattern: foo"
Result: MATCH (trailing whitespace stripped per line)
```

### 3. Indentation Preservation

**Rule:** Relative indentation within multi-line snippets is preserved. Only leading whitespace on the first line and trailing whitespace on each line are normalized.

**Rationale:** Indentation within a snippet carries structural meaning (e.g., nested YAML, indented code blocks). Stripping all indentation would lose this information.

**Example:**
```
KTD spec:
  outer:
    inner: value

Implementation:
  outer:
    inner: value

Result: MATCH (relative indentation preserved)
```

### 4. ANSI-C Quoting Normalization

**Rule:** ANSI-C quoting (`$'...'`) is normalized to its double-quote equivalent for comparison. Escape sequences are converted: `\n` → newline, `\t` → tab, `\\` → backslash, `\'` → single quote, `\"` → double quote.

**Rationale:** Different quoting styles produce the same runtime string. A KTD specifying `$'\n'` and an implementation using `"\n"` are semantically identical.

**Example:**
```
KTD spec:    $'hello\nworld'
Implementation: "hello\nworld"  (where \n is a literal newline)
Result: MATCH (both resolve to "hello" + newline + "world")
```

**Important:** Quoting style differences that change escape semantics are NOT normalized. For example, `$'\n'` (ANSI-C, newline) vs `'\n'` (single-quoted, literal backslash-n) are different strings and should FAIL comparison.

### 5. Inline Code Spans

**Rule:** Inline code spans (backtick-wrapped text in markdown) are compared verbatim after stripping the backticks.

**Rationale:** Backticks in plan documents are markdown formatting, not part of the spec content. The content inside backticks is the actual specification.

**Example:**
```
KTD spec:    "Use `^[a-z]+$` for validation"
After backtick stripping: "Use ^[a-z]+$ for validation"
Implementation: "Use ^[a-z]+$ for validation"
Result: MATCH
```

### 6. Multi-Line Snippet Comparison

**Rule:** Multi-line snippets are compared after normalizing each line individually (rules 1-2), then joining with a single newline.

**Rationale:** Plan documents may use different line ending conventions. Normalizing to single newlines ensures consistent comparison.

**Example:**
```
KTD spec:
  line1
  line2

Implementation:
  line1
  line2

Result: MATCH (lines normalized individually, joined with newline)
```

### 7. Unnormalized Differences

**Rule:** The following differences are ALWAYS meaningful and must FAIL comparison:

- Different regex patterns (e.g., `[a-z]` vs `[a-zA-Z]`)
- Different character classes (e.g., `\w` vs `[a-zA-Z0-9_]`)
- Different quantifiers (e.g., `*` vs `+`)
- Different anchors (e.g., `^` vs `\A`)
- Different escape sequences (e.g., `\n` vs `\r\n`)
- Different function signatures (e.g., `def foo(x)` vs `def foo(x, y)`)
- Different config keys or values
- Different string literals (content, not quoting style)

**Rationale:** These represent actual implementation differences, not formatting variations.

## Application

### In `verify-ktd-literal.py`

The script applies all normalization rules before comparing the KTD spec against the target file content. It returns:
- `match: true` if the normalized KTD appears in the normalized file content
- `match: false` with a diff showing the normalized vs actual content

### In Subagent Context

When the Completeness/Correctness subagents receive a `[literal]` KTD, they apply these normalization rules mentally (the rules are included in their context). For deterministic verification, they should prefer calling `verify-ktd-literal.py` over manual comparison.

## Precedence

If two rules conflict, the more specific rule takes precedence. For example, rule 4 (ANSI-C normalization) overrides rule 1 (whitespace stripping) for the content inside `$'...'` quotes.
