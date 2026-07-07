---
tags: [index]
description: Index of documentation in docs/solutions/conventions/.
---

# Conventions Index

Index of documentation in docs/solutions/conventions/.

| Link | Description |
|------|-------------|
| [agent-definition-convention.md](agent-definition-convention.md) | This repository (taegosts-skills) contains multiple Claude Code skills, each dispatching subagents to perform specialized work. Before standardization, three distinct patterns existed side by side: |
| [automatic-test-dispatch.md](automatic-test-dispatch.md) | When `ts-work` implements a plan that changes scripts, no tests are created or updated. The `implementer-general` agent explicitly refuses to touch tests. The `implementer-tests` agent only writes ... |
| [skill-namespace-prefix-convention.md](skill-namespace-prefix-convention.md) | A Claude Code plugin repository originally shipped 13 skills with the `ce-` prefix (inherited from the Compound Engineering plugin). When multiple plugins in the same `.claude/plugins/cache/` direc... |
| [subagent-bootstrap-dispatch.md](subagent-bootstrap-dispatch.md) | When an orchestrator skill dispatches subagents, it must provide the subagent with its operating contract (template/agent file), output schema, and target document. The original pattern (inline-con... |
