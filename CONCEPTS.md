# Concepts

Shared domain vocabulary for this project — entities, named processes, and status concepts with project-specific meaning. Seeded with core domain vocabulary, then accretes as ts-compound and ts-compound-refresh process learnings; direct edits are fine. Glossary only, not a spec or catch-all.

## KTD (Key Technical Decision)

A labeled specification in a plan document's "Key Technical Decisions" section. Each KTD has a type marker (`[literal]` or `[behavioral]`), a title, and spec text. Unmarked KTDs default to `[literal]`.

## Literal KTD

A KTD whose specification requires exact string matching — regex patterns, code snippets, and exact strings. Verified deterministically by `verify-ktd-literal.py` using normalization rules from `docs/solutions/ktd-normalization-policy.md`.

## Behavioral KTD

A KTD whose specification requires intent matching — patterns, approaches, and constraints. Verified by LLM subagent judgment using criteria from `docs/solutions/behavioral-ktd-verification.md`.

## Normalization Policy

The rules for comparing literal KTD specs against implementations. Covers whitespace stripping, ANSI-C quoting normalization, inline code backtick removal, and multi-line comparison. Defined in `docs/solutions/ktd-normalization-policy.md`.

## Agent

A subagent prompt file that defines a specialist's identity, scope, and output contract. Used as the canonical term; "persona" is deprecated. Each agent file lives in a skill's `references/agents/` directory and is dispatched by the skill's orchestrator. See `docs/standards/agent-standards.md` for the full definition format.

## Agent Profile

An agent file that conforms to the standard frontmatter schema (`name`, `description`, `tools`, `effort`) and follows one of the heading sub-templates (such as implementer or reviewer). The term distinguishes conformant files from legacy agent files that lack frontmatter or use non-standard headings.

## Bootstrap Dispatch

The dispatch pattern where an orchestrator hands a subagent a read-list of file paths so it reads its own operating contract, role, and schema from disk, instead of embedding their contents in the spawn prompt.

## Plan Discovery

The mechanism by which skills locate and load plan documents. Implemented by `skills/load-plan/` and `scripts/locate-plan.py`.

## Plugin Cache

The local copy of an installed plugin that Claude Code executes skills from, keyed by marketplace, plugin name, and version. Marketplace installs copy the entire plugin repository root into it, so a "script not found" failure is almost never a distribution problem — the copy is complete; the reference is what's wrong.

## Script Reference Tiers

The three canonical ways a skill references a bundled script at runtime: the plugin-shared tier (scripts usable by every skill), the skill-local tier (a skill's own scripts), and cross-skill references (another skill's scripts). Each tier has exactly one correct reference form, chosen so the path resolves at skill-load time regardless of the working directory the script executes from.

## Guarded Fallback

The required pattern for consuming a bundled script on platforms where the Claude Code substitution variables are unset: attempt resolution from the loaded skill directory or a repository checkout, and if still unresolvable, emit a visible error and use the documented manual fallback — never silently skip the step.

## Content-Idempotent Regeneration

The property that re-running an index generator on unchanged content leaves the file completely untouched, including hand-maintained frontmatter and sections. Required because the generators run automatically on every commit; without it the automation itself becomes the source of drift.

## Check Class

The scope tier a compliance gate assigns to a file based on its repo-relative path, determining which checks run against it. Three tiers: full (all checks), lib (syntax and control-character checks only), skip (out of scope entirely).

Classification happens at a single choke point inside the per-file check function, never in each scan mode's file-list builder, so every invocation mode applies the same policy. Skipped files are counted in a skip summary and never counted as passed.

## Command-Surface Script

A script invoked directly as a command, as opposed to a sourced or imported library file or a test script. Only command-surface scripts owe a `--help` branch and an executable bit; compliance means help is answered before any argument validation or side effect, not that the string `--help` appears in the file.

## Anchor

The confidence value a reviewer attaches to a finding, drawn from a fixed ladder of steps. Distinct from severity, which ranks impact; the anchor ranks how sure the reviewer is. Merge rules act on the anchor — agreement across reviewers promotes it one step, and low anchors are suppressed late in the merge except for the most severe findings.

## Self-Contained Question

A blocking decision question that carries all information needed to make the decision inside its own question text — position, severity, explanation, and proposed fix — never relying on terminal output printed before it, which Claude Code collapses while the dialog is open. Codified in `docs/standards/question-standards.md`.

## Transcript Duplicate

Terminal output printed before a blocking question that repeats the question's own content for transcript readability. It may mirror a Self-Contained Question's text but never holds the only copy of any decision information — markdown rendering lives here, not in the question.

## Linemap

The mapping of every added line in a pull-request diff to its head-side file and line number, computed before review findings are posted. An inline PR review comment is only valid at a line present in the linemap; findings that land anywhere else route to a flat PR comment instead of being dropped.

## D-entry

A decision-log entry recorded inside the plan section it governs, as a level-4 heading (`#### <section>.D<sequence>.`) with Decision, Why, and Source lines. Captures decisions arriving after the first draft: user decisions, meaning-changing auto-applied review fixes, and non-obvious decisions. Contract owned by `skills/ts-plan/references/plan-sections.md`; consumed by ts-plan and ts-doc-review.

## safe_auto

The autofix classification for findings whose fix ts-doc-review applies silently in its Phase 4 pass, without user gating. Contrast `gated_auto` (previewed before applying) and `manual` (user decision required).

## Gloss

The brief parenthetical meaning carried beside a plan-item ID where it appears — `R4 (explicit version tag)` — so a reader decodes the reference without round-tripping to the source document. The glossed-references rule lives in the plan-sections contract; at render time, glossing fires only on un-glossed tokens and never invents a meaning the document cannot resolve.

## ID-to-gloss map

The per-round lookup table mapping each plan-item ID to the item's name, derived from the document under review before rendering — from its headings and its bullet-prefix IDs, since requirements documents carry their IDs as bullet prefixes rather than headings.

Travels as orchestrator context to each rendering step, never as an output-schema field. Re-derived each review round against the changed document, and extended mid-run with the D-entry IDs emitted by applied fixes; composite tokens resolve via their parent ID.

## Pre-fire audit

The named check that runs the gloss procedure over assembled user-facing text before it renders, with every rendering surface enumerated explicitly so coverage does not depend on routing choice.

One self-healing pass, bounded by gloss idempotence — a second application would double-gloss. Unresolvable tokens pass bare; the audit completes before any question or its transcript duplicate renders.

## Front block

The group of decision-forcing plan sections — Scope Boundaries, Risks & Dependencies, Open Questions, Assumptions — that render immediately after Key Technical Decisions.

When Key Technical Decisions is absent, the block anchors after the last present section among Requirements, Problem Frame, and Summary; no front-block section renders below Implementation Units.

## De-facto-ordering carrier

Any list that enumerates items in order — a catalog, a summary enumeration, an anatomy list — and thereby silently becomes a second copy of an order rule. Introducing a canonical order requires aligning every enumeration of the ordered set, or the enumeration contradicts the rule one line below its own pointer.

## Cross-read

The pattern where one skill reads a contract file owned by a sibling skill via the plugin-root-anchored path, instead of duplicating the contract text. The reading skill states the cross-read at the exact instruction site that needs the contract, with a visible error when the path does not resolve; the owner file marks the coupling with a consumer-declaration line so changes propagate knowingly to every consumer.

## Problem Frame

The plan section that states why the work is being done — the rationale every other section builds on. A problem frame is valid only when it traces to a real source (a why in the prompt, a problem-stating issue body, the origin document, the user's answer at the justification gate, or the recorded assumption noting its absence); a frame tracing to no source fails plan review.

## Justification Gate

The conditional check at a planning workflow's bootstrap entry that decides whether a rationale source exists before any problem frame is drafted. Checks three sources — a why stated in the prompt, a linked issue body that states the problem (a task-only body does not count), or the origin requirements document — and fires once; when no source exists it asks the user, while a decline or headless run records the missing rationale as an explicit assumption rather than inventing one.

## Fabrication Site

A workflow phase that instructs an agent to produce a framed artifact without conditioning it on any input source — a demand for content with no supply constraint, which completion pressure fills with invention. Remedied by the inverse pattern: a gate at phase entry, downstream consumption checks that cite the confirmed source, and explicit-unknown recording instead of synthesis.

## Assumptions Section

The plan section that records unvalidated bets and known unknowns explicitly, including a missing rationale the user declined to supply or a headless run could not ask for. It is the single destination for recorded unknowns, so downstream checks need to accept exactly one shape for them.
