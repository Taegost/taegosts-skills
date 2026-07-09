---
tags: [standards, scripts, extraction]
description: Canonical reference for when inline bash blocks in skills should be extracted to standalone scripts.
---

# Script Extraction Standards

Canonical reference for when inline bash blocks in skills should be extracted to standalone scripts.

## When to extract

Inline bash blocks in skills should be extracted to standalone scripts when:

- The block is duplicated across multiple skills
- The block contains complex fallback chains or error handling
- Extraction enables unit testing

## Requirements for extracted scripts

Extracted scripts must:

- Follow the frontmatter standard (`docs/standards/script-frontmatter-convention.md`)
- Be executable (`chmod +x`)
- Have corresponding tests in `tests/scripts/`

Trivial one-liners (e.g., `git status`, `gh pr view`) that are not duplicated may remain inline.
