---
tags: [standards, questions, interactive, decision-questions, user-experience]
description: Canonical rule for blocking decision questions across all taegosts-skills — the question text must carry everything needed to make the decision.
---

# Question standards — self-contained decision questions

Blocking decision questions must be self-contained: a question that asks the user to decide must carry the complete information needed to make that decision inside its own question text.

## Why

Claude Code collapses text printed before a blocking question while the question dialog is open — the user sees the question and nothing else. Any decision-relevant context that lives only in pre-question terminal output is unreadable at the moment of decision (Issue #222: ts-doc-review printed each finding as a terminal markdown block, then asked the user to decide on a two-line stem referring to it).

## Scope

Applies to every skill in this repo that fires blocking questions. It fires on **decision questions** — questions asking the user to choose an action or make a call. Print-only informational output (FYI observations, residual concerns, deferred items with no decision attached) is out of scope.

## Rules

1. **The question text is the single authoritative carrier of decision information.** Anything printed before the question is at most a transcript duplicate — it may repeat the question's content, never hold the only copy of it.
2. **Decision-relevant context lives in the question text:** what is being decided, why a decision is needed, and what each option does.
3. **Question text renders as plain text:** labeled lines (`What's wrong:`, `Proposed fix:`), not markdown emphasis — the blocking-question tool renders plain text.
4. **Option descriptions state the effect each action has** (e.g., `Defer — appends the finding to the document's Open Questions section now; no fix is applied`), not just a label.
5. **Unexplained terms get a short inline explanation** at first use in the question text. Only an explanation that appeared inside an earlier question's own text counts as already explained — anything printed outside a question is unreadable at decision time.
6. **Length discipline:** each section of the question is 1–3 sentences and each option description is one clause, so questions stay renderable. When a set is too long to print (e.g., a list above 4 items), the question says so and asks how to handle the set instead of printing it. The cap applies to question text only — the full set belongs in a standard response (the transcript duplicate), printed uncapped.

## Reference implementation

`skills/ts-doc-review/` implements this standard for its interactive walk-through — the per-finding questions, cascade confirmation, no-fix sub-question, routing question, bulk-preview Proceed/Cancel, Phase 5 terminal question, and Phase-4 write-access gate. See `references/walkthrough.md`, `references/bulk-preview.md`, and `references/synthesis-and-presentation.md`.

## Conformance checklist

A blocking question site is conformant when:

- [ ] The question text contains everything needed to decide: what is being decided, the finding or summary it concerns, and what each option does
- [ ] No decision-relevant information exists only in pre-question output
- [ ] Question text is plain text (labeled lines, no markdown emphasis)
- [ ] Each option description states its effect on the document or workflow
- [ ] Terms get a short inline explanation at first use in question text; only explanations inside earlier question text count
- [ ] Sections stay 1–3 sentences; sets too long for question text are capped in the question and printed in full in the accompanying standard response

## Related

- `skills/ts-doc-review/references/walkthrough.md` — reference implementation (per-finding, cascade, routing questions)
- `skills/ts-doc-review/references/bulk-preview.md` — reference implementation (Proceed/Cancel carries the execution summary)
- `skills/ts-doc-review/SKILL.md` — interactive-mode rule citing this standard
- Issue #222 — motivating incident (per-finding question referring to collapsed output)
