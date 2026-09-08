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

An agent file that conforms to the standard frontmatter schema (`name`, `description`, `tools`, `effort`) and follows one of the two heading sub-templates (implementer or reviewer). The term distinguishes conformant files from legacy agent files that lack frontmatter or use non-standard headings.

## Plan Discovery

The mechanism by which skills locate and load plan documents. Uses three-tier discovery: explicit path, PR body scanning, and branch-name keyword extraction. Implemented by `skills/load-plan/` and `scripts/locate-plan.py`.

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

Classification happens at a single choke point inside the per-file check function, never in each scan mode's file-list builder, so every invocation mode applies the same policy. Skipped files are counted in a skip summary and never counted as passed; library-tier files keep the cheap checks because a syntax-broken library breaks every importer.

## Command-Surface Script

A script invoked directly as a command, as opposed to a sourced or imported library file or a test script. Only command-surface scripts owe a `--help` branch and an executable bit; compliance means help is answered before any argument validation or side effect, not that the string `--help` appears in the file.
