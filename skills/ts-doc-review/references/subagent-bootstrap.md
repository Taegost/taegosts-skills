# Document Review Sub-agent Bootstrap Prompt

This is the dispatch-time prompt shape the ts-doc-review orchestrator sends to each reviewer sub-agent. Variable substitution slots are filled at dispatch time.

**Bootstrap dispatch.** The orchestrator passes file paths instead of inline content. The agent reads its own files from disk, including `references/subagent-template.md` (its full operating contract — output format, autofix classification, false-positive catalog, confidence rubric, `why_it_matters` guidance). This reduces orchestrator dispatch output from ~10k tokens to ~150-300 tokens per reviewer, and keeps that operating-contract content off the orchestrator's own context — the orchestrator never needs it unless the fallback path below fires.

---

## Bootstrap Prompt (orchestrator sends this)

```
Read these files IN FULL before starting. Do not begin analysis until all four are read:
1. references/subagent-template.md (your operating contract)
2. references/agents/{reviewer_name}.md (your role)
3. references/findings-schema.json (output schema)
4. {document_path} (document under review)

Schema `description` fields contain behavioral guidance — read them as instructions, not metadata.

After reading all files, emit a brief acknowledgment listing files read (paths + line counts) before starting analysis. Format: one line per file, `<path> (<N> lines)`.

<agent-file-path>references/agents/{reviewer_name}.md</agent-file-path>
<schema-path>references/findings-schema.json</schema-path>

document_type: {document_type}
origin_path: {origin_path}

{decision_primer}

{supplementary_context}

Document content:
{document_content}
```

**`{supplementary_context}`** carries reviewer-specific evidence gathered before dispatch — e.g. the convention excerpts SKILL.md's "Cross-check against repo conventions" step passes to feasibility-reviewer, or the K8s security scan findings SKILL.md's "K8s security scan" step passes to security-lens-reviewer. Only the reviewers that step targets receive non-empty content in this slot; every other reviewer gets it empty (omit the slot entirely from their prompt rather than sending a blank line). Label the content so the reviewer knows what it's looking at, e.g.:

```
Supplementary context (repo convention excerpts):
{excerpts}
```

or

```
Supplementary context (K8s security scan findings):
{scan_findings_json}
```

**Bootstrap-ack verification.** The orchestrator checks that each expected path appears in the ack before accepting findings. If ack is missing expected files, reject and re-dispatch (up to 3 attempts).

**Fallback path.** If all 3 attempts fail, or the harness's subagent primitive has no file-read tools at all, read `references/subagent-template.md` now (the orchestrator's own Read, on-demand — not pre-loaded) and dispatch that reviewer using its "Template (fallback — inline content)" section instead, inlining the agent file and schema content directly into the prompt per that section's instructions.
