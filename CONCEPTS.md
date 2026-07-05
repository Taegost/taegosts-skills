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

A subagent prompt file that defines a specialist's identity, scope, and output contract. Used as the canonical term; "persona" is deprecated. Agent files may live in a skill's `references/agents/` directory (dispatched by the skill's orchestrator) or in a root `agents/` staging area (awaiting placement). See `docs/standards/agent-standards.md` for the full definition format.

## Agent Profile

An agent file that conforms to the standard frontmatter schema (`name`, `description`, `tools`, `effort`, and optionally `disallowedTools`) and follows one of the two heading sub-templates (implementer or reviewer). The term distinguishes conformant files from legacy agent files that lack frontmatter or use non-standard headings.

## Plan Discovery

The mechanism by which skills locate and load plan documents. Uses three-tier discovery: explicit path, PR body scanning, and branch-name keyword extraction. Implemented by `skills/load-plan/` and `scripts/locate-plan.py`.
