# Plan Sections

This reference describes what makes a great implementation plan. It does NOT
prescribe how the plan looks on the page — rendering is handled by
`references/markdown-rendering.md`.

## The outcome

A great plan enables three audiences to act:

- **The implementing agent** (`ts-work` or a human) starts from an informed
  baseline — load-bearing decisions are named, research breadcrumbs orient
  their own investigation, unit boundaries are clear. The plan gives the
  implementer a starting point, not a substitute for their own investigation.
- **The reviewer** identifies the load-bearing decisions and the boundaries
  of what's being changed in one pass.
- **The future reader** (anyone returning months later) traces why the work
  was done, what shaped it, and where the artifacts live.

Sections earn their place by serving one of these audiences. Omit padding.

## Decide whether a plan doc is warranted at all

Not every invocation of `ts-plan` should produce a plan document. For
genuinely atomic work, the doc is ceremony — the implementer (whether
`ts-work` or a human) can act directly without IDed units, KTDs, or
Requirements as a checklist.

**Bias toward producing a plan.** The risk asymmetry favors writing one:
a thin plan doc for small work is mild ceremony, but skipping a plan when
one was warranted costs the implementer real time (reinvented decisions,
lost unit boundaries, no IDed requirements to verify against). When unsure,
write the plan.

**Skip plan creation only when ALL of these hold:**

- The work is **atomic** — fits in one commit, no meaningful unit boundaries
  to break out independently.
- There are **no design choices that constrain implementation** — no
  Key Technical Decisions worth recording. If the work needs the implementer
  to make a choice between two approaches, those approaches are KTDs and
  a plan is warranted.
- There are **no scope boundaries worth pinning** in writing — the work
  scope is self-evident from the user's request.
- **No upstream artifact** (a brainstorm with R-IDs, an incident report,
  a deferred-follow-up item from a prior plan) needs traceability through
  this plan.

**Stress test the "looks atomic" case.** Many requests look atomic at first
glance but hide design decisions:

- *"Add caching to this endpoint"* — sounds atomic, but TTL, invalidation,
  cache key shape, and backend selection are all KTDs. Write the plan.
- *"Migrate from package A to package B"* — sounds mechanical, but
  semantic differences between the packages create migration KTDs. Write
  the plan.
- *"Add rate limiting"* — sounds small, but algorithm, scope, and
  configurability are all KTDs. Write the plan.

vs. genuine skip cases:

- *"Fix typo in README line 47"* — atomic, no KTDs, skip the plan.
- *"Rename `oldFn` to `newFn` across the repo"* — mechanical, no design
  choices, skip the plan.
- *"Bump dependency X to v2.3.1"* — mechanical, skip the plan (unless the
  bump introduces breaking changes that warrant unit-by-unit migration).

When skipping the plan doc, the work proceeds directly to `ts-work` or to
implementation, and any decisions made along the way land in the commit
message or `docs/solutions/` if they're worth carrying forward.

## Hard floor

When a plan doc is warranted, these sections are present. They carry the
contracts downstream consumers depend on.

- **Summary** — what the plan proposes, in 1-3 lines. Forward-looking; orients
  the reader before they invest in detail.
- **Problem Frame** — why the work is being done. Backward-looking /
  situational. May merge with Summary for compact plans where the motivation
  is a single sentence.
- **Requirements** (with stable R-IDs) — what must be true after the work
  ships. Reviewer's checklist; downstream code review verifies against these.
- **Key Technical Decisions** (KTDs) — the load-bearing choices that constrain
  implementation. Each entry is `<decision>: <rationale>`. Without these, the
  implementer can't tell which design choices are open and which are pinned.
- **Implementation Units** (with stable U-IDs) — the discrete units of work,
  sized so each is independently landable. `ts-work` consumes these to
  execute. For trivial single-step plans the work may collapse into Summary
  prose and U-IDs may be omitted; this is rare.

## Include when material

These sections are present when they carry information that isn't covered
elsewhere. The test is not "is this a substantial plan?" — it is
*"does this specific plan have content this section would surface?"* Filling
a section with placeholder prose is worse than omitting it.

- **High-Level Technical Design** — include when the technical approach has
  shape that prose alone doesn't carry well: architecture across components,
  sequencing across processes, state machines, branching gates.
  Visualizations (component topology, sequence, swim lane, flowchart,
  data-flow) typically live here. Skip when the approach is a one-paragraph
  pattern application that the prose itself conveys.

- **Scope Boundaries** — include when scope is contested, when there are
  tempting non-goals worth naming explicitly, or when "deferred for later"
  needs distinguishing from "outside the product's identity." Skip when scope
  is obvious from Requirements alone.

- **Open Questions** — include when there are genuinely unresolved items that
  block planning or implementation. Skip when the plan is complete; an empty
  "Open Questions: none" section signals false uncertainty.

- **System-Wide Impact** — include when the change affects cross-cutting
  concerns (data lifecycles, auth boundaries, performance posture, cardinal
  rules, shared infrastructure, agent/tool parity, prompt context, shared
  workspaces). Skip for changes localized to one component where the impact is
  self-evident.

- **Risks & Dependencies** — include when there are real risks worth flagging
  (external service changes, version pins under churn, behavioral assumptions
  worth highlighting) or material upstream dependencies. Skip for low-risk
  localized work.

- **Acceptance Examples** — include when any requirement has a state-dependent
  or conditional shape ("When X, Y") where the prose alone leaves ambiguity
  about edge cases. Skip when all requirements are unconditional and
  unambiguous.

- **Documentation / Operational Notes** — include when documentation,
  monitoring, runbooks, or rollout steps need explicit notes. Skip when the
  work is purely internal and uses existing operational scaffolding without
  modification.

- **Sources / Research** — surface the research that orients the implementer
  or justifies load-bearing choices. The test: *"if I were the implementer
  reading this cold, would this breadcrumb help me make better choices?"*
  Yes → surface (code locations like `services/convex/reports.ts:174-176`,
  external docs, RFCs, constraints, prior plans — the category is inclusive,
  not enumerated). Process exhaust (reading the user's prompt, glancing at
  obvious entry points, restating prose) → omit. Surface inline next to the
  KTD or unit it justifies, or as a dedicated section — both shapes work.

## Agent agency

The catalog is a floor, not a ceiling. When the plan's content doesn't fit
any catalog section, introduce a new one — don't force the content into a
section it doesn't belong in. Content drives section choices, not vice
versa.

The agent also picks per artifact:

- Whether Problem Frame merges into Summary
- Sub-groupings (Requirements by capability, KTDs by component, Units phased
  into milestones)
- How much detail each section carries
- Whether HTD has one diagram, several, or none — and whether visualizations
  live in HTD or embedded in other sections

## Prose economy

"Include when material" sizes *which* sections appear; this sizes *how the kept
prose reads*. A section can be material and still be written loosely — the
failure mode is a material section padded into a wall of text where
contradictions hide and the implementing agent loses the thread. A deep plan
earns length through coverage (more units, more traced requirements, real
risks), never through wordiness around that coverage.

Hold every kept section to these:

- **One idea per sentence.** A Summary is a handful of sentences, not one
  sentence with five semicolons and four parentheticals. A KTD's rationale is
  the load-bearing reason, not every reason.
- **A requirement or unit is one sentence of intent plus at most one
  qualifier.** When it would specify two outcomes ("either A or B, the
  implementer decides"), state the intent and send the fork to Open Questions —
  don't write both arms in full inside the item.
- **Cut hedges and intensifiers.** "Critically", "deliberately", "explicitly",
  "genuinely", "actually", "simply" carry nothing the implementer acts on.
- **Prefer the verb to the nominalization.** "Demote the grid", not "the
  demotion of the grid is the deliberate change in this plan".

Precision is not padding: keep file paths, IDs, conditionals, and exact
thresholds verbatim. Economy targets the connective tissue around them, never
the precision itself.

**Resolve in place; don't stratify.** When deepening, a doc-review pass, or a
later decision supersedes earlier text, rewrite or remove the original — don't
leave it standing as strikethrough or stack a separate "resolutions" layer on
top of it. Version control holds the history. Stacked strata double the reading
surface and hide which text is live. One recorded exception: the decision log
(see "Decision log (D-entries)" under ID and content rules). Superseded D-entries
stay in place, struck through, with a Status line naming their replacement — the
ledger's reason trail is content, not strata; deleting it is how constraints get
silently reverted.

**Named test, run before the plan is declared written:** could the implementer
find a contradiction in each section in one pass? A sentence carrying more than
one parenthetical *aside*, or an item specifying two outcomes, fails the test —
split it or defer it. ID glosses (`R2 (offline support)`) are not asides —
glossing is reference resolution, not digression; a sentence may carry several.

## Plan metadata fields

Every plan carries a small set of stable metadata fields that downstream
tooling depends on. The contract is format-independent: in markdown these
fields appear as YAML frontmatter at the top of the file; in HTML they
appear as visible header text (typically a `<dl>` of `<dt>`/`<dd>` pairs or
a stats strip). Field names and semantics are the same across both formats
so consumers can locate them without knowing which format produced the
plan.

### Required

- **`title`** — verbatim plan title. Matches the H1 (markdown) or document
  `<h1>` (HTML) so file metadata and visible heading don't drift.
- **`type`** — conventional-commit-prefix-aligned classification (`feat`,
  `fix`, `refactor`, `chore`, `docs`, `perf`, `test`, etc.). Carries the
  intent the eventual commit message should reflect.
- **`date`** — creation date in ISO 8601 (`YYYY-MM-DD`), ASCII digits only.

Plans carry **no `status` field** — a plan is a decision artifact, not a
tracked work item. `ts-work` does not mutate the plan at ship time;
whether a plan shipped is derived from git, not stored in the doc. Do not
add a `status` field or an `active → completed` lifecycle.

### Optional but well-known

These fields are not required, but when set they have fixed names and
semantics so downstream tooling can rely on them:

- **`origin`** — repo-relative path to an upstream brainstorm requirements
  doc (e.g., `docs/brainstorms/2026-05-12-pagination-requirements.md`).
  Set when planning from an upstream brainstorm; carried for traceability
  and re-resolved when `ts-plan` re-deepens.
- **`deepened`** — ISO 8601 date marking the first time the confidence
  check substantively strengthened the plan. Presence affects Phase 0.1
  resume fast-path logic (see `references/deepening-workflow.md`).
- **`execution`** — execution domain for downstream routing: `code`
  (the default when absent) or `knowledge-work`. `ts-work`'s input triage
  reads this: a plan marked `execution: knowledge-work` routes to the
  non-code carve-out (read sources, synthesize, produce a deliverable —
  skipping the branch/test/commit/CI lifecycle); absent or `code` routes
  to the normal code path. Written by `ts-plan`'s approach-altitude flow
  (`references/approach-altitude.md`) when a non-code deliverable is
  persisted for execution.

Field names are stable across plan revisions — never rename a field or
repurpose its semantics. Agents composing new plans MUST use these exact
names; adding new fields is fine, but renaming `origin` to `source` or
`date` to `created` breaks the downstream consumers above.

## ID and content rules

These apply regardless of rendering format.

- **Stable IDs.** R-IDs (Requirements), U-IDs (Implementation Units), A-IDs
  (if Actors fire), F-IDs (if Flows fire), AE-IDs (if Acceptance Examples
  fire). IDs are stable across plan revisions — never renumber to "clean
  up gaps."
- **Plain prefix.** `R1.`, `U1.` as bullet prefixes. Do not bold; the prefix
  is visually distinctive on its own.
- **Glossed references.** When the plan references an item it defines
  elsewhere, the reference carries a parenthetical gloss naming the item —
  `U3 (payment retry loop)`, not `U3`; `R2 (offline support requirement)`,
  not `R2`. A bare ID costs the reader a document round-trip they will not
  make. Bare IDs are acceptable only within 10 source-markdown lines of the
  item's own definition (the item's heading starts the count), inside the
  same `##`/`###` section that defines it. Applies to `R#`, `U#`, `KTD#`,
  `F#`, `AE#`, and scoped decision IDs (`U3.D2`); a decision sentence stating
  its substance satisfies this requirement (see the next bullet); the
  ID-and-title heading format `U3. Payment retry loop` satisfies this where
  the title is adjacent.
- **Decisions state substance; IDs are pointers.** Wherever a decision is
  made or honored (KTDs, unit Approaches, D-entries), the sentence itself
  carries the decision's meaning; the ID pointer sits in parentheses and
  never carries the meaning — `Use an alphanumeric-only alphabet (U1.D2)`.
  A decision sentence in this format satisfies the glossed-reference rule —
  the sentence is the gloss; the ID pointer is supplementary.
  Test: delete every ID token; every decision must remain understandable.
  An approval artifact whose decisions read only as IDs is a rubber stamp.
- **Repo-relative paths.** Always. Never absolute paths in plan content;
  they break portability across machines, worktrees, teammates.
- **No process exhaust.** No "captured at Phase X" notes, no `## Next Steps`
  pointing to the next skill, no italic provenance lines. Engineering process
  metadata belongs in commit messages and tool output, not the artifact.
- **Group Requirements by concern when they span distinct logical areas.**
  The trigger is distinct concerns, not item count — even four requirements
  benefit from grouping if they cover three different topics. Skip grouping
  only when all requirements are genuinely about the same thing; a long flat
  list is a smell that subgroups were missed. Group by capability (e.g.,
  "Packaging", "Migration and compatibility", "Contributor workflow"), not by
  the order requirements were discussed. R-IDs stay continuous across groups
  (R1, R2 in the first group; R3, R4 in the second; never restart at R1 per
  group).

### Decision log (D-entries)

Decisions that arrive after the first draft — user corrections, constraints,
review-driven changes — are recorded as D-entries: stable, append-only blocks
inside the section they govern. A decision whose reason lives only in
conversation gets reverted by a later pass that saw the constraint but not
the why. The KTD section remains the record of original plan-time decisions;
D-entries record what changed later. The trigger governs whenever a decision
arrives: original plan-time technical decisions are KTDs, but a user
constraint or non-obvious decision at any point — including initial drafting —
that is not recorded as a KTD gets a D-entry.

**Trigger (the single rule, used everywhere):** a D-entry is REQUIRED for
(a) every decision that came from the user (constraints, corrections,
walkthrough decisions), (b) every fix a reviewer agent auto-applied that
changes meaning — not typo, spelling, or formatting fixes, which git history
already records — and (c) any other decision whose reason is non-obvious.
Optional otherwise.

**Format:**

```
#### <section>.D<sequence>. <decision title>
**Status:** <superseded entries only — always the FIRST line: "superseded by <section>.D<sequence> (<one-line subject>)">
**Decision:** <what was decided, one sentence>
**Why:** <the reason in plain words — including reasons stated only in conversation>
**Source:** <value>, YYYY-MM-DD <context phrase or short user quote>
```

Rules:

- **Scoped IDs, not flat.** `<section>.D<sequence>` — the prefix is the
  governing item's ID when it has one (`U3`, `A3`, `KTD1`), otherwise a
  one-word section name as you would say it in conversation (`Overview.D1`,
  `Risks.D2`). The sequence restarts at 1 within each section. A scoped ID
  carries its location, survives inserts, and sorts next to its parent; a
  flat `D7` renumbers on every insert.
- **Level-4 headings, always.** Implementation units are level-3 (`### U1.
  ...`); a level-3 D-entry would sit beside the unit and end it. Level-4
  nests the entry inside the section it governs.
- **Never inside a bulleted list.** A heading inside a list breaks the list's
  rendering. When a D-entry decides a list item (a requirement, a risk), it
  goes after the list ends, and its Decision line names the item with a
  gloss.
- **Placement and timing.** The entry lives INSIDE the section it governs,
  written in the same editing pass as the change — deferring the log write
  is how reasons die. Entries travel with their section: an implementer
  handed one unit receives every constraint that binds it.
- **Source names who made the decision** — not who found the issue or
  proposed the fix. Closed list: `user` (a decision the user made or
  dictated), `plan` (an original plan-time decision), `review agent <Name>`
  (a fix auto-applied by a named reviewer agent with NO user decision
  involved — never a bare "review"), `research` (external material). Every
  Source carries a date taken from the system (`date +%F`), never inferred,
  plus a context phrase — a plain phrase (`plan discussion`) or a short
  quote of the user's words. When a reviewer proposes and the user approves,
  Source is `user` with the agent named in the context phrase
  (`user, 2026-11-19 approved review agent Feasibility's proposal`).
- **Stable and append-only.** Superseding an entry never deletes it: the old
  heading stays, struck through (`~~...~~`), and gains the required
  `Status:` line as its FIRST line naming the replacement by full scoped ID;
  its Decision/Why lines stay legible so the history reads coherently.
- **`Source: user` entries are constraints, not suggestions.** Superseding
  one is itself a change to a user decision: it requires the user, and the
  replacement also carries `Source: user` — protection transfers down the
  chain, so only the live entry needs guarding.
- **Relationship to KTDs.** Do not convert KTDs into D-entries or duplicate
  a decision in both. When a D-entry changes what a KTD says, update the KTD
  text and add a glossed pointer: `KTD3 (database choice) — amended by
  KTD3.D1 (stay on Postgres, user constraint)`. Plan-wide decisions (no
  single governing section) get their D-entry in the KTD section, and each
  affected unit carries a one-line pointer: `Bound by KTD3.D1 (Postgres
  only, plan-wide)`.
- **Not process exhaust.** A D-entry is a decision record with a Source, not
  a provenance note; the no-process-exhaust rule does not suppress it.
- **Cross-references to D-entries are glossed and flagged.** Any text or
  finding that would change, remove, or contradict a `Source: user` D-entry
  says so explicitly — a user-stated constraint must stay visible to every
  later pass.

**Worked example:**

````markdown
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
````

## Rendering

Rendering is handled by `references/markdown-rendering.md`.

This reference (`plan-sections.md`) is about WHAT the plan contains;
the rendering reference is about HOW markdown presents it.
