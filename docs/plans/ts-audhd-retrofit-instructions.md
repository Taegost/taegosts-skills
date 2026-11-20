# ts-plan / ts-doc-review Accessibility Retrofit — Implementation Instructions

**For:** a coding agent working in `taegost/taegosts-skills` (clone: https://github.com/taegost/taegosts-skills)
**Skills touched:** `ts-plan`, `ts-doc-review` (primarily their SKILL.md and `references/` files)
**Out of scope:** `ts-work`, `ts-brainstorm`, `ts-debug`, `scripts/`, `tests/` (except where a rule below names them — `agents/` under ts-doc-review is in scope ONLY for the sentence that change C5 (constraint guard) adds and the sentence that change C7 (walkthrough logging) adds, nothing else)

## Why this work exists (read first — you will not guess these rules correctly)

This retrofit fixes three distinct problems. Keep all three in mind; several changes serve more than one.

**Problem 1 — the executing model ignores the findings presentation template.** The model running `ts-doc-review` (Claude Sonnet) repeatedly ignores the presentation-format instructions: paraphrasing tables, inventing layouts, collapsing severity sections. Change C1 (findings presentation as a hard compliance contract) is the fix.

**Problem 2 — plan documents are hard to read for the primary reader.** The primary reader of plan and review documents reads with a reduced working-memory budget. Two effects drive every rule in Part A:

1. **Working-memory limits.** Cross-references that require flipping between sections ("U3 advances R2, see KTD4") cost the reader a round-trip they will not make — especially when tired, which is when plans get read most. A sentence that requires holding two identifiers in mind while resolving a third is not readable; it is a puzzle.
2. **Dense undifferentiated text triggers avoidance.** Walls of undifferentiated text read as "you should be able to keep up." They trigger avoidance, not effort. Structure is not decoration here; it is the accommodation that makes the document usable at all.

**The known failure mode (this is what we are fixing):** plans are currently written with a web of bare short IDs (`R2` requirement, `U3` unit, `KTD4` key technical decision, `F1` review finding, `AE3` acceptance example) that cross-reference each other. The primary reader cannot resolve `U3 advances R2` (a reference to implementation unit 3 and requirement 2) without holding both IDs, flipping back to two sections, and reassembling meaning. Result: **the plan does not get read.** Later, execution cites a decision ("you approved this in the plan") the reader never actually saw. This silently converts an approval artifact into a rubber stamp — the worst outcome for a planning system, because it *looks* like consent happened.

A second failure mode rides on top: **rationale loss.** The user's mid-edit corrections land in the document as WHAT changed while the WHY lives only in the conversation. A later review pass sees an unexplained constraint, judges it a flaw, and reverts it as a "minor" edit — textual diff size is not semantic severity. The decision-log rules — rule A3 (decisions carry their reasons) and change B1 (decision log) — with the guard in change C5 (constraint guard) and change C7 (walkthrough logging), exist to stop this cascade.

**Problem 3 — the conversation about the plan is equally hard.** The back-and-forth chat while creating, revising, and reviewing a plan has the same failures as the documents: bare IDs in messages, unnumbered question piles, walls of text, no restated state between turns, full re-dumps of artifacts that changed by three lines. Part F (conversational output rules) is the fix.

A technical reader might call the document half an ID-locality problem: **identifiers must be resolvable where they are used, without random access to the rest of the document.** The conversation half is the same problem in a different medium.

## Global rules (apply to everything you do here)

**Stop on drift.** This document describes the current contents of specific files (phase numbers like 0.1, 3.4, 3.5, 5.1, 5.3.8; step 3.7; "IMPORTANT" paragraphs; P0/P1/P2 tiers; the Tier column; Apply/Edit/Defer/Skip options; the routing menu). **If a file does not match how this document describes it, do not change the file to match the description.** Note the mismatch in the PR and proceed only with changes that do not depend on the mismatched part. This rule is not optional: an agent that "fixes" a mismatched file rewrites working code to match a stale description.

**Terminology in outputs (hard rule).** Generated plan/review documents use neutral, professional language ("working memory limits," "reference resolvable in place," "user-sourced decision"). Do NOT use ADHD-specific vocabulary, creator names, or framework names in generated artifacts — **except** (a) a plan whose subject is itself ADHD-related, or (b) a spot where the concept genuinely cannot be explained without the term. **Skill source files (SKILL.md, references/) also never name the condition**: they explain mechanisms in neutral terms only ("working-memory limits," "re-orientation cost"). The condition-specific context lives exclusively in this instruction document and in the PR descriptions — rationale phrased as "because the reader has ADHD" inside a skill file leaks into the plans that skill generates, violating rule A8 (neutral language) from the inside.

#### Global.D1. Skill source files never name the condition
**Decision:** SKILL.md and references/ describe mechanisms in neutral terms only ("working-memory limits," "re-orientation cost"); the condition-specific context lives exclusively in this instruction document and the PR descriptions.
**Why:** Rationale naming the condition inside a skill file leaks into the plans that skill generates, defeating the neutral-language rule from the inside; a future maintainer finds the full why one hop away, in the PR.
**Source:** user, 2026-11-19 — "I accept your recommendation."

**Execution order (two PRs, in this order).** Change C5 (constraint guard) and C7 (walkthrough logging) depend on the D-entry format that change B1 (decision log) installs — doing Part C first would force the agent to invent its own format.

- **PR 1:** Part A (shared principles) + Part B (ts-plan changes) + B6 (the ts-plan half of the conversational rules) + the Part D checks that cover them.
- **PR 2:** Part C (ts-doc-review changes) + change C7 (walkthrough logging) + change C8 (conversational output rules, ts-doc-review half) + the remaining Part D checks.

State this split and the dependency in both PR descriptions.

#### Global.D2. Two PRs, in dependency order
**Decision:** PR 1 delivers Part A (shared principles) + Part B (ts-plan) + change B6 (conversational output rules, ts-plan half); PR 2 delivers Part C (ts-doc-review) + change C7 (walkthrough logging) + change C8 (conversational output rules, ts-doc-review half). Never Part C first.
**Why:** The constraint guard (change C5) and walkthrough logging (change C7) depend on the D-entry format that change B1 (decision log) installs; Part C first would force the agent to invent its own format.
**Source:** user, 2026-11-19 — "I accept your recommendation."

#### Global.D3. Plans are mutable: decisions append as they arrive
**Decision:** Plans are no longer read-only artifacts; decisions made during execution and review are appended to the plan as D-entries in the same pass, per rule A3.
**Why:** A plan whose later decisions live only in conversation re-opens the rationale-loss cascade this retrofit exists to stop; the ledger in the plan is the record.
**Source:** user, 2026-11-20 — "Plans are no longer read-only, they must have the Decisions updated in them as we go along."

#### Global.D4. Scripts and tests are never out of scope
**Decision:** The Out-of-scope line's `scripts/` and `tests/` exclusions are overridden: any change that alters what a script consumes or a test guards updates that script and its tests in the same change — safety nets are never sidelined.
**Why:** Stale scripts and tests break every safety net downstream; the extractor's D-entry absorption (found in PR 225 review) shipped only because the plan sidelined them.
**Source:** user, 2026-11-20 — "ALWAYS update scripts, if we don't all of our safety nets are going to break."

## Non-goals

- Do not rename accessibility concepts into cutesy substitutes, and do not remove technical rigor. Dense technical content stays; what changes is how it is structured and referenced.
- Do not rewrite plan *content semantics* — the section contract (what a plan must contain) stays as defined in `skills/ts-plan/references/plan-sections.md`. You are changing presentation, reference style, and conversational output, not what planning means.
- Do not touch the `ts-work` consumption contract: U-IDs remain stable per the existing stability rule, headings remain `### U1. Name` format, and progress continues to be derived from git (never written into the plan body as checkboxes).
- Do not repurpose the KTD (key technical decisions) section. Its relationship to D-entries is defined in rule A3 (decisions carry their reasons) and change B1 (decision log); full repurposing is a later, separate pass.

---

# PART A — Shared principles (apply to both skills)

Rule IDs are stable; gaps from removed rules are intentional — do not renumber. Each rule has the shape: **mechanism → rule → acceptance check.** The mechanism is the reason; if you think a rule can be simplified away, re-read the mechanism — a rule that loses its reason will be "optimized" out by a future maintainer and the failure mode returns.

**A1. Resolve references in place.**
Mechanism: working-memory limits (fact 1 in "Why this work exists").
Rule: when a plan or review document **references** another item (points at it), the reference carries enough words to be understood WITHOUT navigating: `U3 (payment retry loop)`, not `U3`; `R2 (offline support requirement)`, not `R2`. This is the *reference* format: ID first, meaning in parentheses. It is distinct from the *decision* format of rule A2 (the decision, then the pointer) — see A2 for the side-by-side. Bare IDs are only acceptable within the same section where the item is defined, within 10 source-markdown lines of that item's definition (the item's own heading starts the count). "Section" means the nearest enclosing `##` or `###` heading. The ID set this applies to: `R#`, `U#`, `KTD#`, `F#`, `AE#`, and scoped decision IDs (`U3.D2` form).
Acceptance: scan any generated plan; no bare `R#`/`U#`/`KTD#`/`F#`/`AE#` token — and no bare scoped-decision ID (an `<section>.D<sequence>` reference without its parenthetical gloss) — appears more than 10 source lines away from that item's own definition. ID-and-title format `U3. Payment retry loop` continues to satisfy this where the title is adjacent. A decision sentence in the rule A2 format satisfies this — the sentence is the gloss; the ID pointer is supplementary (A1.D1, decision sentence is the gloss).

#### A1.D1. A decision sentence satisfies the gloss requirement
**Decision:** A decision sentence in the rule A2 format (meaning first, ID pointer in parentheses) satisfies rule A1's gloss requirement — the sentence is the gloss; the ID pointer is supplementary. A bare `(U1.D2)` pointer in a sentence that does not state the decision's substance still requires a gloss.
**Why:** The A1 acceptance scan, read literally, flagged the A2 example's `(U1.D2)` as a bare ID — a plan following the taught format failed the check; the two rules contradicted each other.
**Source:** user, 2026-11-20 PR 225 review walkthrough — chose the reconciliation clause for both copies.

**A2. The decision, then the pointer.**
Mechanism: an approval artifact unread is a rubber stamp (the known failure mode).
Rule: wherever a **decision** is made or honored (KTDs, unit Approaches, review findings), state the decision's substance in the sentence itself; the ID pointer is supplementary, in parentheses, never the carrier of meaning. This is the *decision* format: meaning first, ID in parentheses. Side by side:

- Reference (rule A1, resolve references in place): `U3 (payment retry loop)` — the ID is the subject; the parenthesis is the meaning.
- Decision (rule A2, the decision then the pointer): `Use an alphanumeric-only alphabet (U1.D2)` — the meaning is the sentence; the ID is the pointer. This format satisfies rule A1's gloss requirement — the sentence is the gloss (A1.D1).

Test: delete every ID token — `U3`, `(U1.D2)`, `KTD4` — keeping the surrounding words. The document must still make its decisions understandable.
Acceptance: the deletion test, performed on the section that matters (KTDs, Requirements, units).

**A3. Decisions carry their reasons, inline, at the point of application.**
Mechanism: rationale loss across editing passes — the user's mid-edit corrections land as WHAT while the WHY lives only in the conversation; a later pass reverts the constraint as a "minor" edit. Known concrete case: plan says "randomly generated password"; user corrects to alphanumeric-only because special characters break the bash deployment scripts; a later doc-review pass flags the restricted alphabet as an entropy regression and silently reverts it — correctly detecting the entropy problem, but the right synthesis (a longer alphanumeric password) is unreachable because the bash constraint never entered the document.
Rule — **what gets a D-entry (single trigger, everywhere):** a D-entry is REQUIRED for (a) every decision that came from the user (constraints, corrections, walkthrough decisions) (b) every fix a reviewer agent auto-applied that changes meaning — not typo, spelling, or formatting fixes, which git history already records — and (c) any other decision whose reason is non-obvious. Optional otherwise. This one trigger is the rule everywhere it appears (this rule, change B1 (decision log), and the Phase 5.1 checklist) — do not create local variants.

Rule — **format:** the decision is recorded in the section it governs, in the same editing pass as the change (deferring the log write is how reasons die):

    #### <section>.D<sequence>. <decision title>
    **Status:** <required ONLY on superseded entries, always the FIRST line: "superseded by <section>.D<sequence> (<one-line subject>)">
    **Decision:** <what was decided, one sentence>
    **Why:** <the reason in plain words — including reasons stated only in conversation>
    **Source:** <value>, YYYY-MM-DD <context phrase — a plain phrase (`plan discussion`) or a short quote of the user's words (— "drop the governs wording")>

D-entry IDs are **scoped**, not flat: `<section>.D<sequence>` — the prefix is the ID of the governing item when it has one (a unit `U3`, a rule `A3`, a KTD item `KTD1`), otherwise a one-word section name as you would say it in conversation (`Overview.D1`, `Risks.D2`, `Requirements.D1`); the sequence restarts at 1 within each section (`U3.D1`, `U3.D2`). A D-entry never interrupts a bulleted list: when it decides a list item (a requirement, a risk), it goes after the list ends, and its Decision line names the item with a gloss — a heading inside a list breaks the list's rendering. Why scoped, and why the section comes FIRST: a flat `D7` carries no address — out-of-order display confuses, inserts renumber everything; a scoped ID carries its own location, survives inserts, and is greppable by section. Section-first (`A3.D1`, not `D.A3.1`) reads as ownership — decision 1 *of* A3 — and makes the ID sort next to its section in any mixed list (a spreadsheet column of IDs), so decisions travel with their parent instead of quarantining to the bottom of a sort. Known minor gap, accepted: plain string sort puts `A3.D10` before `A3.D2`; per-section sequences stay small, and zero-padding (`A3.D01`) is the fix if one ever exceeds 9. Global/plan-wide decisions attach to a KTD *item* (`KTD1.D1`): a global decision with no matching KTD gets a new KTD entry (the decision text) with its D-entry (the why and source) beneath it. Supersession pointers use the full scoped ID.

D-entries use level-4 headings (`####`) unconditionally: implementation units are level-3 (`### U1. ...`), and a level-3 D-entry would sit BESIDE the unit, ending it — level-4 nests the entry INSIDE the section it governs, which is the entire point.

Rule — **Source values (closed list):** `Source` names **who made the decision** — not who found the issue or proposed the fix. `user` (a decision the user made or dictated), `plan` (an original plan-time decision), `review agent <Name>` (a fix auto-applied by a named reviewer agent with NO user decision involved — use the agent's actual name, never a bare "review"), `research` (external material). When a reviewer proposes and the user approves, Source is `user` and the context phrase names the proposing agent, e.g. `user, 2026-11-19 approved review agent Feasibility's proposal`. Every Source carries a date in `YYYY-MM-DD` form plus a short context phrase, e.g. `user, 2026-11-17 plan discussion` or `review agent Coherence, 2026-11-19 safe_auto fix`. Get the date from the system (`date +%F`), never infer it. The context phrase may be a short quote of the user's words — the quote anchors the reason against later argument.

Rule — **log discipline:** D-IDs (scoped, above) are stable and append-only — a superseded decision keeps its heading, struck through (`~~...~~`), and gains the required `Status:` line naming its replacement by full scoped ID; it is never deleted, and its Decision/Why lines stay legible so the history reads coherently. `Source: user` entries are constraints, not suggestions. Superseding one is itself a change to a user decision: it requires the user, and the replacement entry also carries `Source: user` — so protection transfers down the chain and only the live entry needs to trigger the constraint guard (change C5). A superseded entry never fires the guard; its replacement already holds the protection. Entries live INSIDE the section they govern so a subagent handed a single section receives every constraint that binds it.

Rule — **relationship to KTDs:** the KTD section remains the record of original plan-time technical decisions; D-entries record changes, constraints, and corrections that arrive later. Do not convert KTDs into D-entries or duplicate a decision in both. When a D-entry changes what a KTD says, update the KTD text and add a glossed pointer: `KTD3 (database choice) — amended by KTD3.D1 (stay on Postgres, user constraint)`. Plan-wide decisions (no single governing section, e.g. "use Postgres everywhere") get their D-entry in the KTD section, and each affected unit carries a one-line pointer: `Bound by KTD3.D1 (Postgres only, plan-wide)`.

**Worked example (the password case above, as it should appear in the plan):**

```markdown
### U1. Provision service credentials
**Goal:** Service account gets a generated credential written to the env file.
**Approach:** Generate a random alphanumeric password (see U1.D2 below for why
alphanumeric) and write it to `.env.service`.

#### U1.D1. ~~Create a randomly generated password~~
**Status:** superseded by U1.D2 (alphanumeric only)
**Decision:** Generate a random password for the service account.
**Why:** Initial plan-time approach; no alphabet constraint was known yet.
**Source:** plan, 2026-11-17 initial draft

#### U1.D2. Random alphanumeric password only
**Decision:** Generated passwords use `[a-zA-Z0-9]` only.
**Why:** Special characters break quoting in the bash deployment scripts.
**Source:** user, 2026-11-17 plan discussion
```

Note what the example demonstrates: U1.D1 is struck through in its title AND carries `Status: superseded by U1.D2 (alphanumeric only)` directly under its heading — a subagent skimming D1 cannot act on the dead decision, because the Status line arrives before the Decision line. D2 carries `Source: user`, so under change C5 (constraint guard) a later review finding that wants to restore special characters can never auto-apply — it presents the conflict to the user instead. And because both entries live inside U1 (the unit that generates passwords), an orchestrator handing U1 to a subagent delivers the constraint along with it.

Acceptance: every user correction and review-driven change made in conversation appears in the doc as a D-entry with a Why; for any section, its binding constraints are readable without leaving that section; every superseded entry carries a Status line.

This document eats its own dogfood: its design decisions are recorded as D-entries (rule A3, decisions carry their reasons) under the headings they govern, so a future editor inherits the rationale instead of re-arguing it.

#### A3.D1. ~~Single D-entry trigger — the union, not the narrowest~~
**Status:** superseded by A3.D7 (auto-applied review fixes logged only when they change meaning)
**Decision:** A D-entry is required for every decision from the user, every decision from a reviewer or review pass, and any other decision with a non-obvious reason; optional otherwise. This trigger is the only one used anywhere.
**Why:** Three locations in the v1 doc disagreed (any decision / user-or-review only / non-obvious only); the union matches what actually needs a recorded reason without logging everything.
**Source:** user, 2026-11-19 — "It should be any decisions from a user or reviewer, or one that has a non-obvious reason."

#### A3.D2. KTDs and D-entries are two records, linked by pointers on change
**Decision:** The KTD section keeps original plan-time technical decisions; D-entries record later changes, constraints, corrections. A D-entry that changes a KTD updates the KTD text and adds a glossed pointer; never convert, never duplicate.
**Why:** Converting KTDs breaks the preserve-section-contract non-goal; duplicating decisions in both places doubles maintenance and drifts.
**Source:** user, 2026-11-19 — "I agree with your recommendation."

#### A3.D3. Plan-wide decisions live in the KTD section with unit pointers
**Decision:** A decision binding the whole plan (no single governing section) gets its D-entry in the KTD section; every affected unit carries a one-line glossed pointer, e.g. "Bound by KTD3.D1 (Postgres only, plan-wide)".
**Why:** A subagent handed one unit must still see the constraint exists; the pointer keeps it visible without duplicating the entry per unit.
**Source:** user, 2026-11-19 — "I accept your recommendation."

#### A3.D4. Supersession chains preserve user-sourced protection
**Decision:** Superseding a `Source: user` entry requires the user; the replacement also carries `Source: user` (the user-approved supersession of a reviewer's proposal logs as `Source: user`, the proposing agent named in the context phrase). Only the live entry triggers the guard.
**Why:** The user is the only path to superseding a user decision, so every replacement in the chain is user-sourced by construction — protection transfers instead of lapsing.
**Source:** user, 2026-11-19 — "the only way to supersede a Decision whose Source = user would be for the user to approve it, meaning that the latest entry would also have the user as the Source."

#### A3.D5. Source context phrase may be a user quote
**Decision:** `<value>, YYYY-MM-DD <context phrase>` where the phrase may be the user's own short quote: `user, 2026-11-19 — "drop the governs wording"`.
**Why:** The user's words make the reason harder to argue away later — the exact rationale-loss failure this log stops.
**Source:** user, 2026-11-19 — "Option B."

#### A3.D6. Source means who made the decision
**Decision:** `Source` names who made the decision, not who found or proposed it. A reviewer's proposal the user approves is `Source: user`, with the agent named in the context phrase; a reviewer agent is the Source only for auto-applied fixes.
**Why:** A proposal is not a decision. Crediting the proposer hides that the user decided, which would strip the user's protection under change C5 (constraint guard).
**Source:** user, 2026-11-19 — "'Source' means 'the source of the decision', NOT 'the source of the finding'."

#### A3.D7. Auto-applied review fixes get a D-entry only when they change meaning
**Decision:** A D-entry is required for every user decision, every fix a reviewer agent auto-applied that changes meaning, and any other decision with a non-obvious reason; typo, spelling, and formatting auto-fixes get none. This trigger is the only one used anywhere.
**Why:** Logging every trivial auto-fix would add a dozen entries per review pass and bury the decisions that matter; git history already records trivial fixes.
**Source:** user, 2026-11-20 approved Claude's review proposal — "I like your option A."

**A5. Scannable structure over prose walls.**
Mechanism: avoidance under dense undifferentiated text (fact 2); also plain readability.
Rule: sections of 300+ words get a leading one-line bolded summary (`**In short:** ...`). Implementation units are exempt — their Goal field already serves as the lead line. Tables get descriptive headers, not bare IDs. Sentence-length discipline: if a sentence needs more than two identifiers, split it.
Acceptance: no 300+ word section (other than implementation units) without a bolded lead line.

#### A5.D1. One threshold for the bolded lead line: 300 words
**Decision:** Sections of 300+ words get the "In short" lead line; implementation units are exempt because their Goal field already is the lead line. The ~2-paragraphs wording is dead.
**Why:** Nearly every unit exceeds two paragraphs, so that threshold would give every unit a lead line duplicating its Goal — noise defeating rule A5 (scannable structure).
**Source:** user, 2026-11-19 — "I agree with your recommendation."

**A6. Explain, don't just instruct (for skill files).**
Mechanism: rules without reasons get optimized away by future maintainers and by models under context pressure.
Rule: every behavioral rule added to SKILL.md/references by this retrofit includes a rationale clause, capped at one sentence of at most 25 words ("because a bare ID costs the reader a document round-trip they will not make"). The cap is the point: whole mechanism paragraphs pasted into skill files add context pressure, which is what makes models drop rules.
Acceptance: no new bare imperative in the diff lacks a rationale clause; no rationale clause exceeds one sentence / 25 words.

**A8. Neutral language (restated as an operational rule).**
Mechanism: artifacts circulate beyond the primary reader; skill-file language leaks into generated artifacts.
Rule: skill-written documents never attribute structure choices to disability; they present the same structure as good practice. Skill source files themselves never name the condition (see the Terminology hard rule above). The reasons live in this document, not in the artifacts or the skill files.
Acceptance: grep generated artifacts AND modified skill files for "ADHD," "neuro," "disability" → zero hits unless the plan's subject is ADHD.

---

# PART B — ts-plan changes

`ts-plan` creates plans. Its SKILL.md is a five-phase workflow; its templates and rules live in `skills/ts-plan/references/`. Change IDs are stable; the gap at B5 is intentional — do not renumber. Make these changes:

**B1. Decision log: format, placement, and write discipline.**
Files: `skills/ts-plan/references/plan-sections.md` (ID/content rules subsection) and `skills/ts-plan/SKILL.md` (Phase 3.4/3.5 unit writing, Phase 5.1 checklist, Phase 0.1 resume path).
Add to the section contract's ID rules: D-entries (`#### <section>.D<sequence>. <title>` — prefix = the governing item's ID if it has one, else a one-word section name; Decision/Why/Source/Status-on-supersession fields, Status first on superseded entries — level-4 always, never inside a bulleted list; canonical format and worked example in rule A3, decisions carry their reasons) are the record of later changes, constraints, and corrections (KTDs remain the plan-time record — see A3 for the relationship), placed inside the section they govern; stable, append-only; strike-through plus required Status line on supersession, never delete; `Source: user` marks user-stated constraints; `Source: review agent <Name>` marks fixes auto-applied by a reviewer agent without a user decision. Then apply the single A3 trigger at each hook point:
- Phase 3.4/3.5: decisions from the user, meaning-changing fixes auto-applied by a reviewer agent, or decisions with a non-obvious reason get a D-entry rather than bare prose, so the reason is inseparable from the text it governs.
- Phase 0.1 (resume/edit): any user correction applied to the plan MUST be logged as a D-entry in the same pass. Add to the resume flow: "before finishing an editing session, verify every user correction from this session has a D-entry with a Why."
- Phase 5.1 checklist: replace any existing trigger wording with the single trigger — "every user decision and every meaning-changing auto-applied review fix from this session is logged as a D-entry; every decision with a non-obvious reason carries a Why; no user correction is unlogged."

**B2. Make reference resolution a content rule.**
Files: `skills/ts-plan/references/plan-sections.md` (ID/content rules subsection) and `skills/ts-plan/SKILL.md` Phase 3.5 (unit definitions).
Add to both, in the ID rules: every cross-reference carries a parenthetical gloss naming the item — `U3 (payment retry loop)`; bare IDs allowed only within 10 source lines of the item's own definition (shared rule A1, resolve references in place). In Phase 3.5's Requirements field guidance, change the example style from "cite R-IDs" to "cite R-IDs with glosses." In Phase 5.1's review checklist add the deletion test from rule A2 (the decision, then the pointer): "delete every ID token from a KTD — is the decision still understandable? If not, rewrite." Cross-reference D-entries where they apply (see change B1, decision log) — reviewers and downstream passes must be able to see that a finding would change, remove, or contradict a D-entry with `Source: user`.

**B3. Scannability rules in rendering guidance.**
File: `skills/ts-plan/references/markdown-rendering.md`.
Add: sections of 300+ words open with a `**In short:**` bolded line; implementation units are exempt (their Goal field is the lead line); tables use descriptive headers; the unit heading convention (`### U1. Name`) is unchanged. Include the rule A5 (scannable structure) rationale line so future editors keep it.

**B4. Leave intact (do not "fix" these).**
Phase 5.3 confidence/deepening machinery, approach-altitude, U-ID stability rules, the markdown-always decision, headless-mode behavior, and the reference/agent prompts under ts-plan. If a change in Part B — B1 (decision log), B2 (reference resolution), B3 (scannability), or B6 (conversational output rules, ts-plan half) — seems to require touching these, stop and note it in the PR description instead of proceeding. Exception: the conversational rules from change B6 may be stated in SKILL.md's phase instructions themselves (they govern how the skill converses); they still do not touch the 5.3 machinery.

#### B4.D1. Deepening 5.3.7 gains the D-entry carve-out in PR 225
**Decision:** The B4 freeze on the deepening machinery is lifted for one wording change: deepening-workflow.md 5.3.7's "delete superseded text outright" instruction and its allowed-changes bullet carry the decision-log exception, landed in PR 225 rather than deferred.
**Why:** 5.3.7 governs the editing passes where supersessions concentrate; without the carve-out it deletes struck-through D-entries — the exact rationale-loss cascade this retrofit stops, executed by its own machinery.
**Source:** user, 2026-11-20 PR 225 review walkthrough — approved amending within the PR.

**B6. Conversational output rules (the ts-plan half of Part F).**
Files: `skills/ts-plan/SKILL.md` — the interviewing phase (clarifying questions), the plan-presentation moment (presenting a plan or revision for approval), and the post-edit moment (summarizing what changed).
Add the rules from Part F1 (the five conversational rules), scoped to ts-plan's three conversational moments, each with its one-line rationale per rule A6 (explain, don't just instruct). Specifically: clarifying questions are numbered, listed together, blocking question first, no cap on count; presenting a plan or revision shows a summary of what changed since the user's last look, then the ask — never the full document (first presentation: the summary covers the whole plan); after an applied edit, one line stating what changed and where; every ID in a chat message carries its gloss; each turn of an ongoing session opens with a one-line state recap.

---

# PART C — ts-doc-review changes

`ts-doc-review` reviews requirements/plan docs via subagents, classifies findings, and presents them. Presentation files: `references/review-output-template.md`, `references/synthesis-and-presentation.md`, `references/walkthrough.md`, `references/bulk-preview.md`.

**C1. HARD RULE: findings presentation must follow the template exactly. (This section is the fix for problem 1, a live bug.)**
**First step, before editing:** a separate fix for this bug is in progress outside this retrofit and edits the same file. Check whether it has landed and how it changed `references/review-output-template.md`; if the two efforts overlap, stop and report in the PR instead of stacking edits.
Problem: the model executing this skill (Claude Sonnet) repeatedly ignores the presentation-format instructions in `references/review-output-template.md` — paraphrasing the tables, inventing its own layout, or collapsing the per-severity sections. For a reader with working-memory limits, an unexpected format is not a cosmetic issue: every presentation change forces re-orienting, and missing severity groupings mean real issues get skimmed past. The current "IMPORTANT" callouts are stylistic suggestions to a language model; they lose to the model's preference for "cleaner" output.
Required changes — `skills/ts-doc-review/references/review-output-template.md`:
- Replace the two "**IMPORTANT:**" paragraphs at the top with a single fenced **TEMPLATE COMPLIANCE** block stating: the fenced example below is the exact output contract. Presenting findings in ANY other structure — different columns, narrative paragraphs instead of tables, merged severity tiers, reordered sections — is a specification violation and a bug, not a formatting preference. Use the fenced example as a literal skeleton: same headings, same column order, same tier grouping.
- Add the draft-first self-check (replaces the unexecutable "check your output before presenting"): the executing model DRAFTS the findings block first (in reasoning or a scratch file, never shown to the user), runs the five checks against the draft, regenerates on any failure, presents only a draft that passed all five, and never mentions the check to the user. The five checks: (1) severity sections present in order P0/P1/P2, empty tiers omitted; (2) every finding row is a pipe table row with exactly the columns shown; (3) labels use the plain-language vocabulary (fixes / proposed fixes / decisions / FYI observations), Tier column shows the internal enum; (4) Confidence shows integer anchors only; (5) zero ASCII box-drawing, zero narrative-style finding lists.
- Add one line stating WHY (mechanism, per rule A6, explain don't just instruct): an unexpected layout forces the reader to rebuild their parsing model mid-review and reliably hides findings; the template is a stability contract, not a suggestion.
- Mirror the same compliance block briefly in `references/synthesis-and-presentation.md` Phase 4 section and `references/walkthrough.md` (the per-finding screens), since Sonnet reads those files during the same run.

#### C1.D1. This change stays; the separate fix is checked first
**Decision:** Keep the compliance block and self-check in this retrofit, preceded by the overlap check above.
**Why:** Both efforts edit the same file; removing this change leaves the bug unguarded if the outside fix stalls.
**Source:** user, 2026-11-19 — "I agree with your recommendation."

**C2. Findings rows carry meaning, not pointers.**
File: `skills/ts-doc-review/references/review-output-template.md` (and the findings-schema field docs in `references/findings-schema.json` if the description fields allow).
Every table row's `Section` and `Issue` cells must be written so the row is actionable without opening the reviewed document: name the section AND the item in words — `Implementation Unit 3 (payment retry) — test scenarios omit the double-charge case`, not `U3: scenarios incomplete`. Cross-IDs in findings get the same parenthetical gloss treatment as plans (shared rule A1, resolve references in place). Add this as a row-writing rule under the template.

**C3. Walk-through pacing.**
File: `skills/ts-doc-review/references/walkthrough.md`.
The per-finding walk-through is the best-structured part of the flow; keep its shape. Two adjustments: each finding screen opens with a one-line bolded summary of the finding before options (so a returning reader re-orients instantly), and the option letters/meanings (Apply / Edit / Defer / Skip) stay in a FIXED presentation order with the same letters every time — never renumbered, never renamed mid-session. Add the rationale clause (re-orientation cost). If the walkthrough's options are lettered A-D, they collide with the routing menu's A/B/C/D that change C6 (leave intact) preserves — same letters, different meanings, a re-orientation cost. Check; if the collision exists, report it in the PR; do not resolve it yourself.

**C4. Headless output gets the same compliance.**
File: `skills/ts-doc-review/references/synthesis-and-presentation.md` (headless envelope section).
The structured text handed to the caller (ts-plan's step 5.3.8) uses the same severity grouping and row format as interactive mode, just without the routing question. Add one sentence making that explicit, so headless findings don't degrade into a prose blob inside the calling skill's output. Before changing the envelope's format: read ts-plan SKILL.md step 5.3.8 and confirm it treats the envelope as text, not structured input to parse. If 5.3.8 parses the envelope, stop and report in the PR (changing the format would break ts-plan, and change B4 (leave intact) forbids touching its 5.3 machinery).

**C5. Constraint guard: user-sourced decisions are never auto-reverted.**
Files: `skills/ts-doc-review/references/synthesis-and-presentation.md` (classification step 3.7 area), `references/findings-schema.json` (autofix_class description fields), and `references/agents/*` (one sentence per reviewer prompt, see below).
Mechanism: a review finding that proposes changing, removing, or contradicting a D-entry whose Source is `user` is a user-decision event regardless of its textual size. Today's safe_auto classification keys on edit size/risk, so a two-word revert of a user decision sails through silently — the cascade this retrofit exists to stop. There is no separate "governance" concept and none is needed: a D-entry IS a decision with a Source; the test is simply whose decision the finding touches.
Rule: in the classification pipeline, before assigning `safe_auto`, check whether the finding's proposed edit would change, remove, or contradict any D-entry with `Source: user`. If yes: minimum classification is `manual` (decisions tier) no matter how small the proposed edit — EXCEPT the narrow carve-out where the finding proposes an edit that satisfies BOTH the finding and the logged decision (e.g. "longer alphanumeric password" satisfies both entropy and bash-compat), which may be `gated_auto` with the reconciliation shown in the preview. Add one sentence to each reviewer agent prompt in `references/agents/`: removing or relaxing a `Source: user` decision requires the user, full stop; if the constraint and the finding genuinely conflict, the finding presents the conflict and both options, it does not pick one.
Acceptance: a test finding that reverts a user-sourced decision is classified `manual`/`gated_auto`, never `safe_auto`.

#### C5.D1. No "governance" concept — the test is whose decision it is
**Decision:** Text is never "governed by" a source. A D-entry is a Decision with a Source; any finding that would change, remove, or contradict a D-entry whose Source is `user` is never `safe_auto` (minimum `manual`; the gated_auto both-satisfied carve-out stands).
**Why:** "Governed by" was an invented abstraction a model would interpret inconsistently; the direct test — whose decision the finding touches — needs no interpretation.
**Source:** user, 2026-11-19 — "Drop the 'governs' wording entirely… ANY Decision (D-entry) that has 'Source: user' can NEVER be marked as safe_auto."

**C6. Leave intact.**
The confidence-anchor system (0/25 dropped, 50 FYI, 75/100 actionable), the autofix classes for findings NOT touching user-sourced decisions (see change C5, constraint guard), dedup/premise-collapse machinery, and the routing menu A/B/C/D. Do not simplify the pipeline; presentation, row-content, and the constraint guard (change C5) are what change.

**C7. The walkthrough writes D-entries (closes the loop).**
Files: `skills/ts-doc-review/references/walkthrough.md` and `references/synthesis-and-presentation.md` (application step).
Mechanism: a decision the user makes during the walkthrough is a user decision — if it is not logged, the NEXT review pass sees an unexplained constraint and reverts it. The cascade, one pass later.
Rule: (a) every user decision made during the walkthrough (including Edit-option rewrites the user dictated) is written into the reviewed document as a D-entry with `Source: user` in the section the decision governs, in the same pass as the edit — never deferred to "later"; (b) a gated_auto fix the user approved is logged with `Source: user`, the proposing agent named in the context phrase, and the reconciliation stated in its Why; if the reconciliation satisfies both the finding and the existing user decision, the existing user entry stays live — the new entry sits beside it and does not supersede it. Only fixes applied without a user decision log as `Source: review agent <Name>`. Format and Source values: exactly as defined in rule A3 (decisions carry their reasons).

#### C7.D1. Review walkthroughs write D-entries, and review sources name the agent
**Decision:** Walkthrough decisions are logged `Source: user` in the same pass as the edit. A reviewer agent is named as Source only for auto-applied fixes; a proposal the user approves logs as `Source: user` with the agent named in the context phrase, e.g. `user, 2026-11-19 approved review agent Feasibility's proposal` — never a bare "review".
**Why:** An unlogged walkthrough decision is reverted by the next review pass — the cascade one pass later; naming the agent keeps which lens changed the text auditable.
**Source:** user, 2026-11-19 — "The Source from an agent reviewer should have its name in it, for example: 'Source: review agent Feasibility'."

**C8. Conversational output rules (the ts-doc-review half of Part F).**
Files: `skills/ts-doc-review/references/synthesis-and-presentation.md` (summary/routing presentation) and `references/walkthrough.md` (everything outside the per-finding screens).
Add the rules from Part F1 (the five conversational rules) to everything the skill says to the user outside the walkthrough screens: the findings summary, the routing menu presentation, follow-up questions between findings, and the closing summary. Each rule with its one-line rationale per rule A6 (explain, don't just instruct). The per-finding screens themselves already follow change C3 (walkthrough pacing) and need only the delta-not-redump rule when returning to a finding already discussed.

---

# PART F — Conversational output rules (both skills)

The conversation about a plan has the same failures as the documents: bare IDs, unnumbered question piles, walls of text, no restated state, full re-dumps of artifacts that changed by three lines. These rules apply the document mechanisms (resolve references in place, decision before pointer, scannable structure) to chat turns.

**Scope:** these rules govern messages a human reads directly. Headless and subagent output is exempt — machine consumers need parseability, not summaries — with one exception: headless output destined for the user (e.g. ts-doc-review's final summary handed to ts-plan) must reach the user complete; the calling skill passes it through, never summarizes it away. If ts-plan step 5.3.8 currently summarizes or filters ts-doc-review's output, stop and report in the PR — do not change step 5.3.8 (change B4, leave intact). Structured question tools (within the tool's limits) comply when used as designed; continue numbering across calls, and never compress or truncate a question's context to fit the tool — if it does not fit, ask in plain text. They are installed by change B6 (conversational output rules, ts-plan half) and change C8 (conversational output rules, ts-doc-review half) — this part is the shared definition.

#### F1.D1. Conversation is in scope, with these five rules
**Decision:** The retrofit covers chat output in both skills, not just documents: glossed IDs, numbered questions (blocking first, no cap), one-line state recap per turn, changed-things-summary presentations (first presentation summarizes the whole plan; never the full document), one-line edit confirmations.
**Why:** The back-and-forth has the same failures as the documents — bare IDs, walls of text, no restated state; the reader re-enters every conversation cold.
**Source:** user, 2026-11-19 — "Yes to all five."

#### F1.D2. Scope: human-read messages; headless pass-through; tools as designed
**Decision:** Part F governs messages a human reads directly; headless and subagent output is exempt, except user-destined headless summaries pass through complete; question tools comply when used as designed (within the tool's limits), numbering continued, never truncating context to fit.
**Why:** Machine consumers need parseability, not summaries — but a headless summary the user reads is human-facing, and losing it buries the completion.
**Source:** user, 2026-11-19 — "If the output is intended for the user to be read… all that information gets passed to the user."

**F1. The five conversational rules.**

1. **Gloss every ID in chat.** Every plan-item ID mentioned in a chat message carries its meaning in place — `U3 (payment retry loop)` — same mechanism as rule A1 (resolve references in place): a bare ID in chat costs the same round-trip it costs in a document.
2. **Questions are numbered, listed together, blocking first.** When asking multiple questions, number them and list them one after another, the blocking question first. No cap on how many — many clear questions beat few crammed ones. Same mechanism as rule A5 (scannable structure): interleaved multi-part prose buries the actual ask.
3. **Open every turn with a one-line state recap.** In an ongoing session, each turn opens with one line stating where the work is and what is pending. The reader re-enters the conversation cold; the recap replaces the scrolling they would otherwise do.
4. **Present the delta, not the artifact.** Presenting a plan or a revision for approval shows a summary of what changed since the reader's last look, then the ask — never the full document. On first presentation, everything is new, so the summary covers the whole plan; it is still a summary, not the full text. A re-read costs a round-trip the reader will not make; the delta is what they need to judge.
5. **Confirm applied edits in one line.** After an edit is applied, one line stating what changed and where, before any next question. Buried completions do not register as done.

Each rule lands in the skill files with its one-line rationale (per rule A6, explain don't just instruct), capped at one sentence of at most 25 words.

---

# PART D — Verification (how the coding agent proves it worked)

This repo has a tests/ directory and skills are plain markdown, so verification is mostly inspection plus targeted greps. Run ALL of these and include results in the PR. **Baseline first:** before making any change, run every grep below on the unmodified branch and record the results in the PR. After your changes, run them again and compare. A grep that already fails at baseline is a MISMATCH to report, not a failure to fix — never insert a phrase into a file just to make a grep pass, and never treat a baseline hit inside a "don't do this" example as a violation.

**D1. Diff hygiene.** `git diff --stat` touches only: `skills/ts-plan/SKILL.md`, `skills/ts-plan/references/plan-sections.md`, `skills/ts-plan/references/markdown-rendering.md`, `skills/ts-doc-review/SKILL.md` (if needed for C1 mirroring), `skills/ts-doc-review/references/review-output-template.md`, `synthesis-and-presentation.md`, `walkthrough.md`, `bulk-preview.md` (if touched), `skills/ts-doc-review/references/agents/*` (the constraint-guard sentence from change C5, constraint guard, and the logging sentence from change C7, walkthrough logging, only — nothing else in those prompts), and optionally `findings-schema.json` description fields. Anything outside that set → justify in the PR or revert.

**D2. Contract-preservation greps.**
- `grep -n "### U" skills/ts-plan/references/plan-sections.md` — unit heading format unchanged.
- `grep -rn "never renumbered" skills/ts-plan/` — U-ID stability rule still present.
- `grep -rn "derived from git" skills/ts-plan/` — the git-derived-progress rule is still present. Separately, `grep -rn "\- \[ \]" skills/ts-plan/` (compare hit count to baseline; instruction prose must add zero) checks that no checkbox/progress-tracker language was introduced.

**D3. New-rule greps (the retrofit actually landed).**
- `grep -n "Source: user" skills/ts-plan/SKILL.md skills/ts-plan/references/plan-sections.md` — same-pass decision-logging rule present.
- `grep -rn "parenthetical\|gloss" skills/ts-plan/` and `skills/ts-doc-review/references/review-output-template.md` — reference-resolution rule present.
- `grep -n "TEMPLATE COMPLIANCE" skills/ts-doc-review/references/review-output-template.md` — compliance block present.
- `grep -n "Source: user" skills/ts-doc-review/references/synthesis-and-presentation.md` — the constraint guard present.
- `grep -n "review agent" skills/ts-doc-review/references/walkthrough.md skills/ts-doc-review/references/synthesis-and-presentation.md` — change C7 (walkthrough logging) logging rule present.
- Every rule added in Part B (B1 decision log, B2 reference resolution, B3 scannability, B6 conversational) and Part C (C1-C8, the ts-doc-review changes) carries a rationale clause (spot-check 5, each ≤ one sentence / 25 words).

**D4. Simulated-output check (the strongest test).** Generate or hand-write ONE example plan skeleton and ONE example review-findings block that follow the new rules, put them in the PR description (not committed), and run the acceptance checks from Part A against them: bare-ID scan (rule A1, resolve references in place), deletion test (rule A2, the decision then the pointer), decision-log test — user decisions and meaning-changing auto-applied review fixes logged with Why, constraints readable in-section, superseded entries carry Status lines (rule A3, decisions carry their reasons) — bolded-lead scan (rule A5, scannable structure). If any fails, the rules aren't written clearly enough for a model to follow — tighten the rule text, not the example.

**D5. Existing tests.** Run whatever `tests/` covers (e.g., the validate-index scripts) and confirm no regressions: they should pass unchanged since nothing structural was modified.


**D6. Structural checks the greps can't do.**
- Read `ts-work`'s unit-parsing logic (read-only) and answer: would a `####` heading INSIDE an implementation unit break its parsing? If yes, stop and report in the PR — do not work around it.
- Check whether `tests/` runs markdownlint; if it does, check rule MD001 (heading levels increment by one): a `####` D-entry directly under a `##` section (e.g. Requirements) skips a level. Report what you find; do not work around it.
- If the walkthrough options use letters A-D, they collide with the routing menu A/B/C/D preserved by change C6 (leave intact) — same letters, different meanings. Check and report; do not resolve.

**D7. Live-model check (OPTIONAL, DEFERRED — not a PR 2 requirement).** The template bug's root cause was found separately and a fix is in progress outside this retrofit, so live-model verification is deferred until that fix lands. When run: execute `ts-doc-review` with the executing model against one small test document and confirm the presented findings follow the template exactly (the five checks of change C1, findings presentation as a hard compliance contract). (A deterministic renderer in `scripts/` — rendering the findings table from `findings-schema.json` output — remains a candidate follow-up PR; out of scope here because `scripts/` is out of scope.)

# PART E — One-paragraph summary for the coding agent

This retrofit fixes three problems in `taegosts-skills`' planning skills. (1) The model executing ts-doc-review (Claude Sonnet) ignores the findings presentation template — fix it with a hard compliance block plus a draft-first five-point self-check; live-model verification is deferred (step D7, live-model check) until the separate fix for the template bug lands. (2) The plan documents are unreadable to the primary reader, whose working memory cannot resolve the current bare-ID cross-reference web (`U3` → `R2` → `KTD4`), which silently converts plan approval into rubber-stamping — fix it with in-place reference resolution (rule A1, resolve references in place), decision-before-pointer (rule A2, the decision then the pointer), the inline decision log (rule A3, decisions carry their reasons, plus change B1, decision log: every user decision, every meaning-changing auto-applied review fix, and every non-obvious decision, recorded with its Why inside the section it governs; user-sourced decisions are never auto-revertible — the guard in change C5, constraint guard; walkthrough decisions get logged too — change C7, walkthrough logging), and scannable structure (rule A5). (3) The conversation about the plan is equally hard — bare IDs in chat, unnumbered question piles, no restated state, full re-dumps — fix it with the five conversational rules (Part F, installed by change B6 and change C8). Preserve every ts-work contract (stable U-IDs, heading format, git-derived progress) and every pipeline mechanic in ts-doc-review; stop and report on any drift between this document's description of a file and the file itself. Every rule you write carries a one-line reason (≤25 words), or a future maintainer strips it and reintroduces the failure. Two PRs, in order: Part A + Part B + B6 first, then Part C + C7 + C8 — Part C's guard depends on Part B's D-entry format.
