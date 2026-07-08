# CLAUDE.md — Project Instructions

This file contains project-level instructions for Claude Code when working in this repository.

---

## Script Extraction Policy

Inline bash blocks in skills should be extracted to standalone scripts when:
- The block is duplicated across multiple skills (>15 lines each)
- The block contains complex fallback chains or error handling
- Extraction enables unit testing

Extracted scripts must:
- Follow R3 frontmatter standard
- Be executable (`chmod +x`)
- Have corresponding tests in `tests/scripts/`
- Be listed in the extraction enumeration (`docs/plans/2026-07-05-001-extraction-enumeration.md`)

Trivial one-liners (e.g., `git status`, `gh pr view`) that are not duplicated may remain inline.
