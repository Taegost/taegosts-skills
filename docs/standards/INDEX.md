---
title: "Standards Index"
description: "Index of documentation in docs/standards/."
status: active
version: "1.0"
created: 2026-07-08
last-updated: 2026-07-09
owner: wave-2-dispatch-index-automation
dependencies: []
tags: [index]
---

# Standards Index

Index of documentation in docs/standards/.

## Relationship to docs/solutions/conventions/

`docs/standards/` and `docs/solutions/conventions/` are not a duplicate split — they hold two different kinds of document, distinguished by structure, not just topic (see Issue #96):

- **`docs/standards/`** — authored, enforced policy. Documents here state rules directly ("MUST", "is the only allowed pattern"), often with rule IDs (e.g. `DS-001`) and a **Conformance** or **Conformance Checklist** section. They are the canonical spec a skill or script is validated against.
- **`docs/solutions/conventions/`** — organic learnings captured by `ts-compound`, following the `Context / Guidance / Why This Matters / When to Apply / Examples / Related` template (`skills/ts-compound/assets/resolution-template.md`). They document a convention the team arrived at while solving a specific problem, carry `ts-compound`'s YAML frontmatter (`problem_type: convention`, `applies_when`, etc.), and are subject to `ts-compound-refresh`'s Keep/Update/Consolidate/Replace/Delete maintenance lifecycle — `docs/standards/` documents are not.

When adding a new document, ask: is this a rule the repo enforces (→ `docs/standards/`), or a lesson learned while solving a problem, worth revisiting as the codebase evolves (→ `docs/solutions/conventions/`, via `ts-compound`)? `testing-standards.md` previously used the `docs/solutions/` frontmatter schema despite being structurally a `docs/standards/` policy document (Conformance Checklist, no `ts-compound-refresh` lifecycle) — normalized as part of this decision.

| Link | Description |
|------|-------------|
| [agent-standards.md](./agent-standards.md) | Canonical reference for agent definition format across all taegosts-skills. |
| [dispatch-standards.md](./dispatch-standards.md) | Canonical reference for how skills dispatch subagents and delegate to other skills. |
| [index-convention.md](./index-convention.md) | Canonical standard for INDEX.md files across all documentation in taegosts-skills. |
| [index-standards.md](./index-standards.md) | Every INDEX.md file MUST have YAML frontmatter with: |
| [link-convention.md](./link-convention.md) | Canonical standard for markdown links across all documentation in taegosts-skills. |
| [script-extraction-standards.md](./script-extraction-standards.md) | Canonical reference for when inline bash blocks in skills should be extracted to standalone scripts. |
| [script-frontmatter-convention.md](./script-frontmatter-convention.md) | Canonical reference for the description comment format used in all shell scripts across the repository. |
| [testing-standards.md](./testing-standards.md) | If a script exists and was changed, it needs a corresponding test file. No line threshold. |
