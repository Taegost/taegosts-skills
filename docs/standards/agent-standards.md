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
model: <model>
tools: <comma-separated list of tools the agent may use>
effort: <low | medium | high | xhigh | max>
---
```

### Field Definitions

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Short kebab-case identifier derived from the filename (without `.md`). Used for dispatch references and logging. |
| `description` | Yes | One-line description of when to activate this agent. The orchestrator uses this to decide which agents to dispatch for a given task. |
| `model` | Yes | The Claude Code model level to use. Defaults to "haiku" |
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

**Bootstrap is the only allowed dispatch pattern.** All skills that dispatch subagents must use Bootstrap. The two legacy patterns (Template-Wrapped and Direct-Seed) are deprecated and must not be used in new work.

### Bootstrap (required — all skills)

The orchestrator passes file paths instead of inline content. The subagent reads its own operating contract, role prompt, and schema from disk. This reduces orchestrator dispatch output from ~10k tokens to ~150-300 tokens per reviewer.

```text
Read these files IN FULL before starting:
1. references/subagent-template.md (your operating contract)
2. references/agents/<reviewer-name>.md (your role)
3. references/findings-schema.json (output schema)
4. <document_path> (document under review)
```

**Bootstrap-ack requirement:** After reading all files, the agent emits a plain-text acknowledgment listing each file path and its line count (one line per file, `<path> (<N> lines)`). The orchestrator verifies each expected path appears in the ack before accepting findings. Missing files or mismatched counts trigger re-dispatch with an admonition to read all files (up to 3 attempts). If all 3 attempts fail, the orchestrator falls back to inline-content dispatch for that reviewer.

**Schema-as-guidance:** The bootstrap prompt includes: "Schema `description` fields contain behavioral guidance — read them as instructions, not metadata." This ensures agents process rubric descriptions as behavioral rules, not passive documentation.

See `docs/solutions/conventions/subagent-bootstrap-dispatch.md` for the full pattern, prompt shapes, and examples.

### Template-Wrapped (deprecated — not a fallback)

The orchestrator injects agent file content into a subagent template via `{agent_file}` variable substitution. This pattern is **deprecated and must not be used for new skills or migrations.** It exists only as documentation of a pattern that predates this standard.

```
<agent>
{agent_file}
</agent>
```

**Why deprecated:** Inline content inflates orchestrator dispatch tokens (~10k per reviewer) and couples agent identity to the orchestrator's context window. Bootstrap eliminates both problems.

### Direct-Seed (deprecated — only with explicit owner approval)

The orchestrator seeds agent file content directly into a generic subagent prompt. The agent file carries the full context including output contract. This pattern is **deprecated.** Skills still using it must migrate to Bootstrap. The only exception: a skill owner may request a temporary deferral if the skill's dispatch mechanism cannot support file-path passing (e.g., a platform harness without file-read tools). Such deferrals require explicit owner approval and a tracked migration issue.

**Why deprecated:** Same token-inflation problem as Template-Wrapped, plus the agent's operating contract is not separated from its task prompt, making updates fragile.

## Migration to Bootstrap

Skills still using Template-Wrapped or Direct-Seed dispatch must migrate to Bootstrap. The migration steps are:

1. **Identify the current dispatch pattern.** Read the skill's SKILL.md for how subagents are spawned. Look for `{agent_file}` substitution (Template-Wrapped) or inline agent content in the dispatch prompt (Direct-Seed).

2. **Replace inline content with file paths.** Instead of injecting the agent file's content into the dispatch prompt, pass the file path. The subagent reads the file itself.

3. **Add bootstrap-ack to the dispatch prompt.** Include the ack instruction: "After reading all files, emit acknowledgment: one line per file, `<path> (<N> lines)`."

4. **Add ack verification to the orchestrator.** After the subagent returns, verify the ack contains all expected file paths. Implement the 3-attempt retry with admonition, then inline-content fallback.

5. **Remove `{agent_file}` substitution.** Delete any template variable substitution logic from the orchestrator.

6. **Test the migration.** Run the skill end-to-end. Verify the subagent reads its own files and the ack is present and correct.

### Skills requiring migration

| Skill | Current pattern | Status |
|-------|----------------|--------|
| (none) | — | All skills migrated to Bootstrap |

Skills already on Bootstrap: `ts-code-review`, `ts-doc-review`, `ts-work`, `ts-verify-implementation`, `ts-plan`, `ts-compound`, `ts-compound-refresh`.

## File Placement

Agent files live in skill-local directories:

| Location | Purpose |
|----------|---------|
| `skills/<skill>/references/agents/` | Skill-specific agents dispatched by that skill |
| `agents/` | Staging area for agents being developed before placement |

Each skill dispatches from its own `references/agents/` directory. Cross-skill deduplication is a separate concern — see the deferred work in Issue #83.

## Conformance Checklist

An agent file is conformant when:

- [ ] YAML frontmatter contains all required fields
- [ ] Identity text follows the frontmatter (1-2 paragraphs)
- [ ] Heading structure matches one of the two sub-templates (implementer or reviewer) or a recognized specialized template
- [ ] All headings from the chosen sub-template are present
- [ ] No references to "persona" remain in the file
- [ ] Filename uses kebab-case and matches the `name` field
