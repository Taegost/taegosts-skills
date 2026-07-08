---
tags: [standards, dispatch, bootstrap]
description: Canonical reference for dispatch patterns across all taegosts-skills.
---

# Dispatch Standards

Canonical reference for how skills dispatch subagents and delegate to other skills.

## Rule IDs

### DS-001: bootstrap-only

**Requirement:** Skills MUST use the bootstrap dispatch pattern — pass file paths, not inline content. The subagent reads its own operating contract, role prompt, and schema from disk.

**Rationale:** Reduces orchestrator dispatch output from ~10k tokens to ~150-300 tokens per reviewer (~97% savings). Self-contained agents survive missed notifications because their operating context lives on disk.

**Pattern:**

```text
Read these files IN FULL before starting:
1. references/subagent-template.md (your operating contract)
2. references/agents/<reviewer-name>.md (your role)
3. references/findings-schema.json (output schema)
4. <document_path> (document under review)
```

**See:** `docs/solutions/conventions/subagent-bootstrap-dispatch.md`

### DS-002: no-subagent-spawning

**Requirement:** Skills MUST NOT use the `Agent` tool or spawn subagents directly. Instead, delegate by loading the target skill via its file path. The skill file path is the single source of truth — load, don't re-derive.

**Rationale:** Direct subagent spawning bypasses the bootstrap pattern, wastes tokens, and creates tight coupling to platform-specific agent APIs.

**Prohibited patterns:**

- `Agent(subagent_type="...")` calls
- `spawn_agent(...)` calls
- References to "Agent tool" for dispatch
- Model selection logic for subagents (haiku/sonnet/opus)

### DS-003: file-path-delegation

**Requirement:** When one skill needs to invoke another, it MUST load the target skill by its file path. The file path IS the dispatch — no intermediate derivation needed.

**Pattern:**

```text
Delegate to the target skill by loading it via its file path.
The skill file path is the single source of truth — load, don't re-derive.
Bootstrap pattern: load skill → execute → return result
```

### DS-004: script-via-index

**Requirement:** Skills MUST locate scripts via `scripts/INDEX.md` or skill-local `scripts/INDEX.md`, not by hardcoding paths. The INDEX.md is the canonical script registry.

**Rationale:** Script paths change. INDEX.md provides a stable lookup layer that prevents broken references when scripts are reorganized.

### DS-005: routing-first

**Requirement:** When resolving targets (file paths, plan paths, PR URLs), consult `docs/ROUTING.md` first. If the target is a Map of Content, follow it to the actual files. If the target is an INDEX.md, follow it to the actual files. If the target is a direct file path, use it as-is.

**Rationale:** ROUTING.md is the central navigation hub. Using it prevents duplicate resolution logic across skills and ensures consistent path resolution.

## Conformance

A skill file is dispatch-conformant when:

- [ ] No references to `Agent` tool for dispatch
- [ ] No references to `spawn_agent` or similar platform-specific spawning
- [ ] No model selection logic for subagents (haiku/sonnet/opus selection)
- [ ] Uses file path delegation for cross-skill invocation
- [ ] References scripts via INDEX.md, not hardcoded paths
- [ ] Consults ROUTING.md for target resolution when applicable
