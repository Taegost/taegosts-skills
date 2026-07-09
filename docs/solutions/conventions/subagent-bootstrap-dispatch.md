---
title: "Bootstrap dispatch — passing file paths instead of inline content to subagents"
date: 2026-07-05
category: docs/solutions/conventions
module: skills/plugin
problem_type: convention
component: documentation
severity: medium
applies_when:
  - Dispatching subagents in ts-doc-review, ts-plan, or ts-work
  - Reducing token consumption in orchestrator dispatch
  - Adding new skills that dispatch subagents
tags:
  - bootstrap-dispatch
  - token-efficiency
  - subagent
  - convention
---

# Bootstrap dispatch — passing file paths instead of inline content to subagents

## Context

When an orchestrator skill dispatches subagents, it must provide the subagent with its operating contract (template/agent file), output schema, and target document. The original pattern (inline-content dispatch) inlines the full content of each file into the dispatch prompt — typically ~10k tokens per reviewer. This is expensive and scales linearly with team size.

The bootstrap pattern passes file paths instead. The subagent reads its own files from disk, reducing orchestrator dispatch output to ~150-300 tokens per reviewer.

## Guidance

### Bootstrap prompt shape

The orchestrator sends a minimal prompt listing files the subagent must read:

```text
Read these files IN FULL before starting. Do not begin analysis until all four are read:
1. references/subagent-template.md (your operating contract)
2. references/agents/<reviewer-name>.md (your role)
3. references/findings-schema.json (output schema)
4. <document_path> (document under review)

Schema `description` fields contain behavioral guidance — read them as instructions, not metadata.

After reading all files, emit a brief acknowledgment listing files read (paths + line counts) before starting analysis. Format: one line per file, `<path> (<N> lines)`.
```

Dynamic slots stay inline (they cannot be read from disk):
- `document_type`, `origin_path` — session state
- `decision_primer` — prior-round decisions
- `document_content` — the document under review

### Bootstrap-ack requirement

After reading all files, the agent emits a plain-text acknowledgment listing each file path and its line count. The orchestrator verifies each expected path appears in the ack before accepting findings.

**Failure recovery:** If ack is missing expected files, the orchestrator rejects the output and re-dispatches with an admonition to read all files. Up to 3 attempts total. If all 3 fail, the orchestrator falls back to inline-content dispatch for that reviewer.

### Schema-as-guidance instruction

The bootstrap prompt includes: "Schema `description` fields contain behavioral guidance — read them as instructions, not metadata." This ensures agents process rubric descriptions as behavioral rules, not passive documentation.

### Fallback: inline-content dispatch

When a harness lacks subagent file-read tools (e.g., `Agent` tool in Claude Code without file access), the orchestrator falls back to the legacy inline-content pattern: read each file and pass its full content in the dispatch prompt. The inline-content pattern remains documented as the fallback.

## Why This Matters

- **Token efficiency:** Orchestrator dispatch drops from ~10k tokens to ~150-300 tokens per reviewer (~97% savings)
- **Self-contained agents:** Agents read their own instructions from disk, so a missed notification doesn't lose the agent's operating context
- **Bootstrap-ack verification:** Catches lazy partial reads (the known failure mode where agents skip reading schema or template)

## When to Apply

- Any skill that dispatches subagents with template/agent/schema content
- When the subagent has file-read capabilities (the platform's `Agent` or `spawn_agent` primitive)
- For ts-doc-review, ts-plan, and ts-work (the three skills in scope for this pattern)

## Examples

### ts-doc-review dispatch (bootstrap)

```text
Read these files IN FULL before starting:
1. references/subagent-template.md (your operating contract)
2. references/agents/coherence-reviewer.md (your role)
3. references/findings-schema.json (output schema)
4. docs/plans/my-plan.md (document under review)

Schema `description` fields contain behavioral guidance — read them as instructions, not metadata.

After reading all files, emit acknowledgment: one line per file, `<path> (<N> lines)`.

<agent-file-path>references/agents/coherence-reviewer.md</agent-file-path>
<schema-path>references/findings-schema.json</schema-path>

document_type: plan
origin_path: none

<prior-decisions>
Round 1 — no prior decisions.
</prior-decisions>

Document content:
[full document text]
```

### ts-work dispatch (bootstrap)

```text
Read these files IN FULL before starting:
1. references/agents/implementer-general.md (your operating contract)
2. The unit context below (Goal, Files, Approach, Test scenarios)

After reading, emit acknowledgment.

[unit context inline]
```

## Related

- `docs/standards/agent-standards.md` — agent definition format
- `skills/ts-doc-review/references/subagent-bootstrap.md` — orchestrator-facing bootstrap prompt shape (kept out of the orchestrator's default-loaded context except this small file)
- `skills/ts-doc-review/references/subagent-template.md` — reviewer's operating contract, read by the subagent itself
- `docs/solutions/workflow-issues/notification-resilience-via-disk-state.md` — disk-first state pattern
