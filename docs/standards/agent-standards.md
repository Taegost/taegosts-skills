# Agent Standards

Canonical reference for agent definition format across all taegosts-skills.

## Terminology

- **Agent** — a subagent prompt file that defines a specialist's identity, scope, and output contract. Use "agent" everywhere; never "persona."
- **Subagent** — the runtime instance launched by a skill orchestrator, seeded with an agent file's content.
- **Agent file** — the `.md` file on disk under `references/agents/`.

## Frontmatter Schema

Every agent file must begin with YAML frontmatter containing these fields:

```yaml
---
name: <short-kebab-case-slug>
description: <one-line activation trigger — when the orchestrator should dispatch this agent>
tools: <comma-separated list of tools the agent may use>
effort: <low | medium | high | xhigh | max>
---
```

### Field Definitions

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Short kebab-case identifier derived from the filename (without `.md`). Used for dispatch references and logging. |
| `description` | Yes | One-line description of when to activate this agent. The orchestrator uses this to decide which agents to dispatch for a given task. |
| `tools` | Yes | Comma-separated list of tools the agent may use. Common values: `Read, Grep, Glob` (read-only analysis), `Read, Grep, Glob, WebSearch, WebFetch` (research agents), `Read, Edit, Write, Bash, Grep, Glob` (implementers). |
| `effort` | Yes | Reasoning effort tier. `low` for mechanical tasks, `medium` for standard analysis, `high` for complex reasoning, `xhigh`/`max` for adversarial review or deep research. |
| `disallowedTools` | No | Comma-separated list of tools the agent must NOT use. Used when an agent should be explicitly prevented from certain actions (e.g., `Write, Edit` for read-only reviewers). |

### Example

```yaml
---
name: security-reviewer
description: Reviews code changes for security vulnerabilities, injection risks, and authentication gaps.
tools: Read, Grep, Glob
effort: high
---
```

## Identity Text

After the frontmatter, every agent file must include 1-2 paragraphs of identity text. This text defines the agent's identity, domain expertise, and analytical stance. The identity text is the agent's "who am I" — it shapes how the agent approaches the task.

## Heading Sub-Templates

Agent files use one of two heading sub-templates based on their role. The heading structure defines the agent's scope boundaries, calibration, and output contract.

### Implementer Template

Used by agents that produce code, configuration, or other artifacts (called by `ts-work`).

| Section | Purpose |
|---------|---------|
| **Scope Boundary** | What this agent is responsible for producing. Explicitly state what falls within and outside the agent's remit. |
| **Fidelity to the Plan** | How closely the agent must follow the plan's approach. Whether the agent may deviate from the plan when it discovers a better path, and under what conditions. |
| **What "Done" Looks Like** | Concrete completion criteria. When the agent can stop working and return results. |
| **What You Don't Do** | Explicit non-goals. Prevents scope creep by naming things the agent must not touch, even if they seem related. |
| **Failure Handling** | What to do when the agent encounters blockers, ambiguity, or conflicting signals. Whether to halt, ask, or make a judgment call. |

### Reviewer Template

Used by agents that analyze and report findings (called by `ts-doc-review`).

| Section | Purpose |
|---------|---------|
| **Document Type Adaptation** | How the agent adjusts its review strategy based on document type (plan, spec, runbook, ADR, etc.). |
| **What You Check** | The specific dimensions this agent reviews. Defines the agent's analytical focus. |
| **Confidence Calibration** | How the agent rates finding confidence. Anchored to the shared rubric (0/25/50/75/100) with domain-specific anchors. |
| **What You Don't Flag** | Explicit suppression conditions. Prevents false positives by naming patterns the agent must not report. |
| **Output Format** | The structure of the agent's output. Typically a structured findings list with severity, confidence, and evidence. |

### Specialized Templates

Some skills define specialized heading structures adapted from these base templates:

- **Verification agents** (ts-verify-implementation): Use "What You Verify" instead of "What You Check," with verification-specific calibration anchors. See the ts-verify-implementation skill for details.
- **Code review agents** (ts-code-review): Use domain-specific headings (e.g., "What you're hunting for") that predate this standard. These agents conform to the frontmatter schema but retain their existing heading patterns.

## Dispatch Patterns

Two dispatch patterns coexist in the codebase:

### Template-Wrapped (ts-code-review, ts-doc-review)

The orchestrator injects agent file content into a subagent template via `{agent_file}` variable substitution. The template provides shared structure (output contract, confidence rubric, schema) and the agent file provides domain-specific identity and scope.

```
<agent>
{agent_file}
</agent>
```

### Direct-Seed (ts-work, ts-compound, ts-plan)

The orchestrator seeds agent file content directly into a generic subagent prompt. The agent file carries the full context including output contract.

Both patterns produce the same result: a subagent running with the agent's identity and scope. The difference is whether shared structure lives in a template (template-wrapped) or in the agent file itself (direct-seed).

## File Placement

Agent files live in skill-local directories:

| Location | Purpose |
|----------|---------|
| `skills/<skill>/references/agents/` | Skill-specific agents dispatched by that skill |
| `agents/` | Staging area for agents being developed before placement |

Each skill dispatches from its own `references/agents/` directory. Cross-skill deduplication is a separate concern — see the deferred work in Issue #83.

## Conformance Checklist

An agent file is conformant when:

- [ ] YAML frontmatter contains all 4 required fields (`name`, `description`, `tools`, `effort`)
- [ ] Identity text follows the frontmatter (1-2 paragraphs)
- [ ] Heading structure matches one of the two sub-templates (implementer or reviewer) or a recognized specialized template
- [ ] All headings from the chosen sub-template are present
- [ ] No references to "persona" remain in the file
- [ ] Filename uses kebab-case and matches the `name` field
