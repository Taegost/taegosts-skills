---
title: "Agent definition convention — standardizing subagent prompt file format"
date: 2026-07-04
category: docs/solutions/conventions
module: skills/plugin
problem_type: convention
component: documentation
severity: medium
applies_when:
  - Creating new agent files for Claude Code skills
  - Migrating existing persona files to the agent format
  - Updating catalogs or orchestrator prompts that reference agents
  - Adding agents to a new skill
tags:
  - agent-standards
  - frontmatter
  - yaml
  - convention
  - subagent
  - persona-migration
---

# Agent definition convention — standardizing subagent prompt file format

## Context

This repository (taegosts-skills) contains multiple Claude Code skills, each dispatching subagents to perform specialized work. Before standardization, three distinct patterns existed side by side:

1. **Personas** (no frontmatter) in `ts-code-review` and `ts-doc-review` — agent prompt files that started directly with prose, relying on the orchestrator template to provide structure.
2. **Agents** (no frontmatter) in `ts-compound`, `ts-plan`, `ts-work` — agent prompt files that began with identity text but lacked any machine-readable metadata.
3. **Agent profiles** (with YAML frontmatter) in a root `agents/` directory — the newest pattern, used by `ts-work`-style skills that seed agent content directly into subagent prompts.

Each pattern made different assumptions about how the orchestrator would find, select, and inject agent content. There was no shared contract for what an agent file must contain, how its fields were named, or what heading structure it should follow. When a new skill needed agents, authors copied the nearest existing file and guessed at the format. This produced drift: some agents had a "Scope Boundary" section, others had "What You Are Responsible For"; some used "persona" terminology, others used "agent"; and frontmatter fields (when present) varied between skills.

The standardization effort produced `docs/standards/agent-standards.md`, a canonical reference that defines the frontmatter schema, two heading sub-templates, terminology conventions, and dispatch patterns. The work spanned five PR review rounds, each surfacing a different category of error that the standard needed to prevent.

## Guidance

The canonical standard is `docs/standards/agent-standards.md`. This section summarizes the key conventions; see the standard for the full specification.

### Terminology

Use "agent" everywhere. Never "persona." The word "agent" aligns with Claude Code's runtime model (subagents are launched by orchestrators). "Persona" is a legacy term that creates ambiguity when grep-ing the codebase or searching documentation.

When renaming, watch for grammar: "a persona" becomes "an agent" (not "a agent"), and "persona agents" collapses to "agents" (not "agent agents"). These are easy to miss in bulk find-replace operations.

### Frontmatter Schema

Every agent file must begin with YAML frontmatter containing the following required fields:

```yaml
---
name: <short-kebab-case-slug>
description: <one-line activation trigger>
tools: <comma-separated tool list>
effort: <low | medium | high | xhigh | max>
---
```

Field rules:

- `name` must match the filename without `.md`. This is how orchestrators resolve agent references.
- `description` must be a single line. Multi-sentence descriptions break YAML parsing in some contexts and clutter catalog views. Compress to one clause: "Reviews code changes for security vulnerabilities, injection risks, and authentication gaps."
- `tools` is comma-separated with spaces after commas. Common values: `Read, Grep, Glob` for read-only reviewers, `Read, Grep, Glob, WebSearch, WebFetch` for research agents, `Read, Edit, Write, Bash, Grep, Glob` for implementers.
- `effort` is a tier, not a number. Use `low` for mechanical tasks, `medium` for standard analysis, `high` for complex reasoning, `xhigh` or `max` for adversarial review or deep research.
- `disallowedTools` (optional) — comma-separated list of tools the agent must NOT use. Used when an agent should be explicitly prevented from certain actions (e.g., `Write, Edit` for read-only reviewers).

### Heading Sub-Templates

Agent files use one of two heading structures depending on their role:

**Implementer template** (for agents that produce artifacts, called by `ts-work`):
- Scope Boundary
- Fidelity to the Plan
- What "Done" Looks Like
- What You Don't Do
- Failure Handling

**Reviewer template** (for agents that analyze and report, called by `ts-doc-review`):
- Document Type Adaptation
- What You Check
- Confidence Calibration
- What You Don't Flag
- Output Format

Specialized skills may adapt these headings (e.g., "What You Verify" instead of "What You Check" for verification agents), but the adapted headings should map clearly back to the base template's purpose.

### Dispatch Patterns

Two dispatch patterns coexist:

1. **Template-wrapped** (`ts-code-review`, `ts-doc-review`): The orchestrator injects agent file content into a template via `{agent_file}` substitution. The template provides shared structure (output contract, confidence rubric, schema) and the agent file provides domain-specific identity and scope.

2. **Direct-seed** (`ts-work`, `ts-compound`, `ts-plan`): The orchestrator seeds agent file content directly into a generic subagent prompt. The agent file carries the full context including output contract.

Both patterns require the agent file to be self-contained in terms of identity and scope. When adding a new agent, check which dispatch pattern the parent skill uses.

### File Placement

Agent files live in skill-local directories:

- `skills/<skill>/references/agents/` — skill-specific agents dispatched by that skill
- `agents/` — staging area for agents being developed before placement

Each skill dispatches from its own `references/agents/` directory. When cataloging agents, verify that every referenced agent file actually exists in the expected directory.

### Catalog and Count References

Never hardcode agent counts in documentation or orchestrator prompts. Rosters change as agents are added or removed. Instead of "The 6 agents in ts-compound," write "The agents in ts-compound." If you need to enumerate them, reference the directory listing or a generated catalog rather than a static list.

## Why This Matters

**Discoverability.** When every agent file has a consistent `name` and `description` in frontmatter, orchestrators can programmatically enumerate available agents, build dispatch tables, and present them in catalogs. Inconsistent formats force manual inspection of each file.

**Dispatch reliability.** The orchestrator resolves agents by filename. If the `name` field does not match the filename, or if the file does not exist where the catalog says it does, dispatch fails silently or throws cryptic errors. Standardized placement and naming make dispatch predictable.

**Review efficiency.** When all agents follow the same heading template, reviewers can evaluate agent files against the standard checklist rather than inventing criteria per file.

**Maintenance burden.** Every deviation from the standard is a special case that future contributors must discover and accommodate. Hardcoded counts go stale. Non-standard heading names prevent shared tooling. Terminology inconsistencies make grep unreliable.

**The PR review trap.** The five-round review cycle that produced this standard was dominated by mechanical errors — grammar from find-replace, stale counts, broken file references, non-ASCII characters from IME input. These are not reasoning errors; they are formatting errors that a standard and its checklist are designed to prevent.

## When to Apply

- **Creating a new agent file**: Start from the frontmatter schema and the appropriate heading template. Fill in all four required fields. Do not copy an existing agent and modify it without verifying the frontmatter matches the current schema.

- **Migrating an existing agent**: Add frontmatter if missing. Rename "persona" references to "agent." Verify the `name` field matches the filename. Check that all headings from the chosen sub-template are present. Run the conformance checklist in `docs/standards/agent-standards.md`.

- **Updating a catalog or orchestrator prompt**: Verify that every agent referenced actually exists on disk. Replace hardcoded counts with directory-aware references. Ensure dispatch variable names match the agent file's `name` field.

- **Adding agents to a new skill**: Choose the dispatch pattern (template-wrapped or direct-seed) based on whether shared structure is needed. Place agents in `skills/<new-skill>/references/agents/`. Follow the implementer or reviewer template based on the agent's role.

## Examples

### Before/After: Frontmatter

**Before** (no frontmatter, legacy persona format):

```markdown
# Adversarial Document Reviewer

You are a technical editor who reads documents with a adversarial mindset...
```

**After** (conformant frontmatter):

```markdown
---
name: adversarial-document-reviewer
description: Reads documents adversarially to surface unstated assumptions and failure modes.
tools: Read, Grep, Glob
effort: high
---

You are a technical editor who reads documents with an adversarial mindset...
```

### Before/After: Terminology Fix

**Before** (mechanical find-replace produced grammar errors):

```markdown
This persona is an agent that reviews code.
The agent agents are dispatched by the orchestrator.
```

**After** (corrected grammar):

```markdown
This agent reviews code.
The agents are dispatched by the orchestrator.
```

### Common Pitfalls

**Pitfall 1: Broken file reference in catalog.**

An orchestrator prompt lists `agent-native-reviewer` as an always-on agent, but no file `agent-native-reviewer.md` exists in the referenced directory. Dispatch silently skips this agent.

Fix: Before adding an agent name to a catalog, verify the file exists: `ls skills/<skill>/references/agents/<name>.md`.

**Pitfall 2: Stale count in documentation.**

Documentation says "ts-compound has 6 agents" but a subsequent PR added two more. Readers trust the count and assume it is authoritative.

Fix: Write "The agents in ts-compound are enumerated in `skills/ts-compound/references/agents/`" or reference a generated listing. Never hardcode a count.

**Pitfall 3: Non-ASCII characters from IME input.**

During editing, Chinese characters (e.g., from the IME composition window) can slip into the file. These are invisible in most editors but break YAML parsing and grep.

Fix: After editing, run `grep -P '[^\x00-\x7F]' <file>` to detect non-ASCII characters.

**Pitfall 4: Section numbering breaks when items are removed.**

If a numbered list has items removed mid-PR, surviving items retain their original numbers with gaps. This confuses readers and breaks cross-references.

Fix: Renumber after any removal. Do not leave gaps in numbered lists.

**Pitfall 5: Consolidation severity mismatch.**

An agent defines severity levels (Critical/Major/Minor) but the orchestrator expects different levels (P0/P1/P2/P3). Findings at one scale do not map cleanly to the other.

Fix: Align severity scales between agent definitions and orchestrator expectations. Reference the shared rubric in the standard rather than defining a local scale.

## Related

- `docs/standards/agent-standards.md` — the canonical standard defining the full frontmatter schema, heading templates, and conformance checklist
- `docs/solutions/tooling-decisions/ce-skills-extraction.md` — historical origin of the persona/agent pattern (still uses "persona" terminology)
- `docs/solutions/conventions/skill-namespace-prefix-convention.md` — precedent for large-scale naming conventions in this repo
- GitHub Issue #74 — the parent issue for this standardization effort
- GitHub Issue #83 — deferred items (cross-skill deduplication, dispatch pattern unification, severity scale standardization)
