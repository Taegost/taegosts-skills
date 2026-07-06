---
title: "Notification resilience via disk-first state and Monitor-based file watching"
date: 2026-07-05
category: docs/solutions/workflow-issues
module: skills/plugin
problem_type: workflow-issue
component: documentation
severity: high
applies_when:
  - Dispatching subagents that may complete while the orchestrator is mid-generation
  - Recovering from missed task-notification events
  - Building reliable multi-agent workflows
tags:
  - notification-resilience
  - disk-first-state
  - monitor
  - file-watching
  - recovery
---

# Notification resilience via disk-first state and Monitor-based file watching

## Context

Background agent completions are lost ~40-50% of the time when the orchestrator is mid-generation. The harness-level notification (`<task-notification>`) is unreliable — it can be missed when the orchestrator is busy, the context window is full, or the session is between turns. This makes multi-agent workflows fragile: the orchestrator dispatches agents but may never learn they finished.

## Guidance

### Disk-first state

Agents write structured output to files on disk as their primary state mechanism. The file is the authoritative completion signal — not the notification. When a file appears, the orchestrator reads it and processes the results. This works regardless of whether the `<task-notification>` arrives.

Output file format conventions per skill:
- `ts-doc-review`: findings JSON matching `findings-schema.json`
- `ts-work`: completion status (exit code + summary)
- `ts-plan`: the plan document (markdown)

### Monitor-based detection

The orchestrator uses Monitor with `inotifywait` to watch the output directory for new files. When a file appears, Monitor emits a notification to the orchestrator.

**Setup flow:**
1. Check `command -v inotifywait`. If available, arm Monitor with `inotifywait -m <dir> -e close_write`.
2. If unavailable, fall back to polling with `scripts/wait-for-file.sh`.
3. Dispatch agents and record expected output file paths.
4. Reconcile any files already present (fast agents may complete before dispatch returns).
5. When a new file appears, read it and process results.
6. If a `<task-notification>` also arrives, it's redundant — deduplicate.

### Polling fallback (`scripts/wait-for-file.sh`)

When `inotifywait` is unavailable, use `scripts/wait-for-file.sh`:

```bash
scripts/wait-for-file.sh <file_path> [timeout_seconds] [poll_interval_seconds]
```

Default timeout: 180s (3 minutes). Default poll interval: 10s. Returns 0 when file appears, 1 after timeout.

If the subagent is still running after timeout, re-run the script up to a maximum of 5 retries (15 minutes total) or until the subagent completes, whichever comes first.

### Hang detection

If an agent crashes before writing any output file, `wait-for-file.sh` returns false after its 3-minute timeout. The orchestrator then checks whether the subagent is still running. If exited, treat as failure and continue. If still running, re-run the polling script. This bounds the maximum wait to 3 minutes per check cycle.

## Why This Matters

- **Reliability:** Disk-first design means the orchestrator can recover by watching for output files, even when notifications are lost
- **No double-processing:** When both Monitor and notification fire, the orchestrator deduplicates
- **Self-contained agents:** The bootstrap dispatch pattern (agents read their own instructions from disk) means a missed notification doesn't lose the agent's operating context

## When to Apply

- Any multi-agent workflow where agents run in the background
- When the orchestrator needs to detect agent completion reliably
- For ts-doc-review, ts-work, and ts-plan dispatch flows

## Limitations

This is a recovery mechanism, not a fix for notification reliability. The harness-level notification problem (Issue #98) requires an upstream fix in Claude Code. Monitor-based detection works around the symptom but doesn't address the root cause.

## Related

- `docs/solutions/conventions/subagent-bootstrap-dispatch.md` — bootstrap dispatch pattern
- `scripts/wait-for-file.sh` — polling fallback script
- Issue #98 — harness notification reliability
