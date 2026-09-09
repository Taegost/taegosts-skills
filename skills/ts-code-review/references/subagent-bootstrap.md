# Code Review Sub-agent Bootstrap Prompt

This is the dispatch-time prompt shape the ts-code-review orchestrator sends to each reviewer sub-agent (Stage 4) and each validator sub-agent (Stage 5b). Dynamic slots are filled at dispatch time; everything else is read by the sub-agent from disk.

**Bootstrap dispatch.** The orchestrator passes file paths instead of inline content. Each reviewer reads its own operating contract (`references/subagent-template.md`), role prompt (`references/agents/<name>.md`), output schema (`references/findings-schema.json`), scope rules (`references/diff-scope.md`), and routing rubric (`references/action-class-rubric.md`) from disk. This keeps ~4.8k words of template/schema/rubric content per reviewer off the orchestrator's dispatch output and context — the orchestrator never needs it unless the fallback path below fires. Paths are skill-relative: resolve them under the ts-code-review skill directory (`${CLAUDE_PLUGIN_ROOT}/skills/ts-code-review/` when installed as a plugin).

---

## Reviewer bootstrap prompt (Stage 4 — orchestrator sends this)

```
Read these files IN FULL before starting. Do not begin analysis until all five are read:
1. references/subagent-template.md (your operating contract)
2. references/agents/{reviewer_name}.md (your role)
3. references/findings-schema.json (output schema)
4. references/diff-scope.md (scope rules)
5. references/action-class-rubric.md (autofix_class/owner routing rubric)

Schema `description` fields contain behavioral guidance — read them as instructions, not metadata.

After reading all files, emit a brief acknowledgment listing files read (paths + line counts) before starting analysis. Format: one line per file, `<path> (<N> lines)`.

<agent-file-path>references/agents/{reviewer_name}.md</agent-file-path>
<schema-path>references/findings-schema.json</schema-path>

<review-context>
Run ID: {run_id}
Reviewer name: {reviewer_name}

Intent: {intent_summary}

<pr-context>
{pr_metadata}
</pr-context>

<pr-scope-mode>{scope_mode}</pr-scope-mode>
<pr-head-ref>{pr_head_ref}</pr-head-ref>
<branch-head-ref>{branch_head_ref}</branch-head-ref>
<pr-base-ref>{pr_base_ref}</pr-base-ref>
{standards_paths}
{review_base}

Changed files: {file_list}

Diff:
{diff}
</review-context>
```

## Dynamic slots (reviewer dispatch)

| Slot | Source | Notes |
|------|--------|-------|
| Run ID | Stage 4 | Scopes the artifact directory. Empty or absent means the reviewer writes no artifact file |
| Reviewer name | Stage 3 | Maps to `references/agents/<name>.md` in the read list and to the artifact filename stem |
| Intent | Stage 2 | 2-3 line summary of what the change is trying to accomplish |
| `<pr-context>` | Stage 1 | PR title, body, and URL. Always present; empty content when not reviewing a PR |
| `<pr-scope-mode>` | Stage 1 | `local-aligned` \| `pr-remote` \| `branch-remote` |
| `<pr-head-ref>` | Stage 1 | `pr-remote` only, when the PR head fetch succeeded; omit when it failed |
| `<branch-head-ref>` | Stage 1 | `branch-remote` only |
| `<pr-base-ref>` | Stage 1 | `pr-remote` file-level diffs — a real git base SHA. Omit when the base fetch failed |
| `<review-base>` | Stage 1 | `data-migration` reviewer only — the resolved review base ref so schema drift checks never assume `main`; omit for other reviewers |
| `<standards-paths>` | Stage 3b | `project-standards` reviewer only — standards file path list; omit for other reviewers |
| Changed files / Diff | Stage 1 | Inline for small diffs. For large shared context, staged paths (`full.diff`, `files.txt` in the run dir) instead of inline content — the subagent template tells the reviewer to Read a staged path |

Omit slots that do not apply to the current scope mode or reviewer (e.g. no `<pr-head-ref>` outside `pr-remote`) rather than sending empty tags.

## Validator bootstrap prompt (Stage 5b — orchestrator sends this)

```
Read these files IN FULL before starting:
1. references/validator-template.md (your operating contract)

After reading, emit a brief acknowledgment listing files read (paths + line counts). Format: one line per file, `<path> (<N> lines)`.

<review-context>
<pr-scope-mode>{scope_mode}</pr-scope-mode>
<pr-head-ref>{pr_head_ref}</pr-head-ref>
<branch-head-ref>{branch_head_ref}</branch-head-ref>

Diff:
{diff}
</review-context>

<finding-to-validate>
Title: {finding_title}
Severity: {finding_severity}
File: {finding_file}
Line: {finding_line}
Why it matters: {finding_why_it_matters}
Suggested fix: {finding_suggested_fix}
Original reviewer: {finding_reviewer}
Confidence anchor: {finding_confidence}
</finding-to-validate>
```

The validator read list is a single file (`references/validator-template.md`), which the validator reads itself. The finding fields (title, severity, file, line, `suggested_fix`, original reviewer name, confidence anchor, and `why_it_matters` when available), the scope-mode tags, and the diff (inline, or the staged `full.diff` path for a large shared context) are the dynamic slots. Load `why_it_matters` from the per-agent artifact file at `/tmp/taegosts-skills/ts-code-review/{run_id}/{reviewer_name}.json`; omit the line when the file is absent or the artifact write failed — the validator proceeds using the diff and cited code directly.

## Bootstrap-ack verification

The orchestrator checks that each expected path appears in the ack before accepting the sub-agent's output. If the ack is missing expected files, reject the output and re-dispatch with an admonition to read all files. Up to 3 attempts total.

## Fallback: inline-content dispatch

If all 3 attempts fail, or the harness's subagent primitive has no file-read tools at all, the orchestrator falls back to the legacy inline-content pattern: read `references/subagent-template.md` (or `references/validator-template.md`) on demand with its own Read — not pre-loaded — then dispatch that reviewer or validator by inlining the agent file, diff-scope rules, and findings-schema.json content directly into the spawn prompt, in that order (agent identity first, then the scope rules, then the output schema).
