---
title: "Conventions Index"
description: "Index of documentation in docs/solutions/conventions/."
status: active
version: "1.0"
created: 2026-07-08
last-updated: 2026-07-08
owner: wave-2-dispatch-index-automation
dependencies: []
tags: [index]
---

# Conventions Index

Index of documentation in docs/solutions/conventions/.

## Relationship to docs/standards/

This directory is not a duplicate of `docs/standards/` (see Issue #96) — the split is by document kind, not an accident of history:

- **This directory** — organic learnings captured by `ts-compound`, following the `Context / Guidance / Why This Matters / When to Apply / Examples / Related` template (`skills/ts-compound/assets/resolution-template.md`), carrying `ts-compound`'s YAML frontmatter (`problem_type: convention`, `applies_when`, etc.). Subject to `ts-compound-refresh`'s Keep/Update/Consolidate/Replace/Delete maintenance lifecycle.
- **`docs/standards/`** — authored, enforced policy: rules stated directly ("MUST", "is the only allowed pattern"), often with rule IDs and a Conformance section. Not maintained via `ts-compound-refresh`.

New convention docs from `ts-compound` belong here. A new *enforced rule* the repo validates against belongs in `docs/standards/` instead.

| Link | Description |
|------|-------------|
| [agent-definition-convention.md](./agent-definition-convention.md) | This repository (taegosts-skills) contains multiple Claude Code skills, each dispatching subagents to perform specialized work. Before standardization, three distinct patterns existed side by side: |
| [automatic-test-dispatch.md](./automatic-test-dispatch.md) | When `ts-work` implements a plan that changes scripts, no tests are created or updated. The `implementer-general` agent explicitly refuses to touch tests. The `implementer-tests` agent only writes ... |
| [skill-namespace-prefix-convention.md](./skill-namespace-prefix-convention.md) | A Claude Code plugin repository originally shipped 13 skills with the `ce-` prefix (inherited from the Compound Engineering plugin). When multiple plugins in the same `.claude/plugins/cache/` direc... |
| [subagent-bootstrap-dispatch.md](./subagent-bootstrap-dispatch.md) | When an orchestrator skill dispatches subagents, it must provide the subagent with its operating contract (template/agent file), output schema, and target document. The original pattern (inline-con... |
