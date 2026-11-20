---
title: "Blocking questions must carry their full decision context"
date: 2026-11-19
category: docs/solutions/developer-experience
module: ts-doc-review
problem_type: developer_experience
component: development_workflow
severity: high
applies_when:
  - "Designing blocking questions in interactive skill walkthroughs"
  - "When a decision question depends on content printed earlier in terminal output"
  - "Any skill that asks per-item Apply/Defer/Skip decisions in Claude Code"
  - "Codifying question-design rules as repo-wide standards"
symptoms:
  - "Claude Code collapses terminal output printed before a blocking question while the question dialog is open"
  - "Users confirmed Apply/Defer/Skip on finding content they could not read"
  - "Question stems referenced prior output with short handles instead of carrying decision information"
  - "Same print-then-ask defect at four decision points: per-finding, routing, bulk-preview, Phase 5"
root_cause: logic_error
resolution_type: documentation_update
related_components:
  - documentation
tags: [claude-code, blocking-questions, interactive-walkthrough, question-standards, ux-design, skill-prompt-assets]
---

# Blocking questions must carry their full decision context

## Context

`ts-doc-review`'s interactive walkthrough printed each finding as a terminal markdown block, then fired a short two-line blocking question asking the user to Apply / Defer / Skip that finding (Issue #222, repo Taegost/taegosts-skills). Claude Code collapses text printed before a blocking question while the question dialog is open, so at the moment of decision the user saw only the two-line stem referring to content they could not read. The same print-then-ask shape existed at three more decision points: the routing question (A/B/C/D entry point), the bulk-preview Proceed/Cancel, and the Phase 5 terminal question.

Observable friction:

- User is asked `Apply / Defer / Skip?` for a finding whose title, severity, and proposed fix are collapsed behind the open question dialog — decisions made on invisible content.
- Routing question offers "Review each finding one by one" without the question text saying what the findings are.
- Bulk-preview Proceed/Cancel and the Phase 5 terminal question both reference a report printed just before them, which the collapse makes unreadable.
- Every question in the flow repeats the same failure because they all share one design assumption, so fixing one site leaves the others broken.

Two earlier approaches failed and are worth recording:

1. **The original skill design's "Never merge the two" rule.** The spec deliberately separated the terminal block (explanation) from the question (decision), on the assumption that pre-question text stays visible while the dialog is open. That rule was the bug's anchor: the separation is correct only when both halves are readable, and Claude Code's collapse behavior breaks that condition. The fix had to remove the assumption, not reword the question stem.
2. **A forbidden-words list for question text.** A plan-review round proposed banning internal enum/tier names (e.g. `gated_auto`) from question text via a new forbidden-words list. Rejected: the repo's existing vocabulary rule already bans internal enums from user-facing output, and a second overlapping ban added confusion without new coverage.
3. **Capping the routing inline list at 12 findings.** An early plan draft set the routing question's inline findings list cap at 12. Question-rendering limits bite far earlier than 12, so the cap was cut to 4, with a mandatory total-count line and an above-cap handback instead of an oversized list.

## Guidance

**The question text is the single authoritative carrier of decision information.** Anything printed before a question is at most a transcript duplicate — it may repeat the question's content, never hold the only copy of it. Since the collapse is a platform property, the fix is to make the collapse harmless by moving all decision-relevant content inside the question.

Rules that make question text survive the blocking-question tool's renderer:

- **Plain text, labeled lines — never markdown emphasis.** The question tool renders plain text; `**bold**` labels print as literal asterisks. Identifiers are quoted with double quotes, not backticks (at most 2 short quoted spans per sentence).
- **Severity as plain-English words** in place of the `[P0]`–`[P3]` tags: `must fix` / `should fix` / `consider fixing` / `worth noting`. Internal enum values (`safe_auto`, `gated_auto`, `manual`, `FYI`) never appear in question text.
- **Each option description states its effect on the document in one clause**, not just a label.
- **Unexplained terms get a short inline explanation** at first use (e.g., "the doc's Open Questions section — unresolved items recorded in the document for a later pass").
- **Length budgets:** 1–3 sentences per section, one clause per option. If a finding overflows, the sections are tightened — nothing moves back out of the question into pre-question print.

Apply the same self-containment at every decision site:

- **Routing question** always carries the finding set: `There are a total of {N} findings:`, then at most 4 findings inline in a compressed one-line format (`{severity word} {section} — {one-line summary}`). Above 4, no list — the count line is followed by `A summary is too long to print here — how do you want to handle this?` as the stem.
- **Bulk-preview Proceed/Cancel** carries the execution summary in the question text (counts plus the sections each bucket touches, at most 4 section names per bucket before `and {K} more sections`), with counts inline in the stem.
- **Phase 5 terminal question** carries the completion summary: `Review complete — {A} applied, {D} deferred, {S} skipped.` (zero-count buckets omitted, `{K} acknowledged` appended when non-zero).
- **Terminal markdown blocks remain**, shrunk to duplicates: they repeat the question's content rendered in markdown for transcript readability, and add, drop, and rewrite nothing.

## Why This Matters

Claude Code's collapse of pre-question text is a platform property — no skill-side wording can make collapsed text readable. The failure was never the question's wording; it was the architecture that placed decision-relevant content outside the question. Moving the complete finding into the question text makes the collapse harmless: whatever is hidden behind the dialog is, by construction, a duplicate.

Two design-rule heuristics generalize from the false starts: when a spec separates explanation from decision, check what the platform does to pre-dialog output before ratifying the separation; and before adding a second enforcement mechanism (the forbidden-words list), check whether an existing rule already covers the violation.

Verified PASS by 4-agent implementation verification, with `verify-script-refs.sh` passing, 153 pytest + 47 bats tests passing, and `update-indexes.py` content-idempotent. A live worst-case dry run confirmed a maximum-length question (~1,100 chars) renders fully with no truncation.

## When to Apply

- Designing blocking questions in interactive skill walkthroughs
- When a decision question depends on content printed earlier in terminal output
- Any skill that asks per-item Apply/Defer/Skip decisions in Claude Code
- Codifying question-design rules as repo-wide standards

## Examples

Per-finding question shape (assembled plain text, in this order — `skills/ts-doc-review/references/walkthrough.md`, "Per-finding presentation"):

```
Finding {N} of {M} — {severity word} — {plain-English title}
What's wrong: {why_it_matters}          (1–3 sentences)
Proposed fix: {suggested_fix as prose}  (1–3 sentences)
Why it works: {short reasoning}         (1–3 sentences)
Trade-off: {...}        (only when applicable)
Overlap: {...}          (only when applicable; conflicts surface here too)
Apply the rename?       (one-phrase yes/no stem naming the recommended action)
```

Option set with one-clause effect descriptions:

```
A. Apply the proposed fix  (recommended) — stages the fix; the document is edited in the end-of-walk-through batch
B. Defer — adds the finding to the doc's Open Questions section; changes nothing now
C. Skip — leaves the document unchanged and records no follow-up
D. Auto-resolve with best judgment on the rest — routes this and every remaining finding through the bulk preview for one approval
```

## Related

- `docs/standards/question-standards.md` — the codified repo-wide rule (MUST rules + conformance checklist); this learning's prevention layer
- `skills/ts-doc-review/references/walkthrough.md` — reference implementation (per-finding, cascade, routing questions)
- `skills/ts-doc-review/references/bulk-preview.md` — reference implementation (Proceed/Cancel carries the execution summary)
- Issue #222 — motivating incident
- Issue #223 — companion audit of the same pattern across the repo's other skills
- Issue #190 — related: moving blocking-question tool guidance into a shared reference
