# Persona Catalog

11 reviewer personas + 2 local prompt assets organized into always-on, cross-cutting conditional, and migration-specific layers. The orchestrator uses this catalog to select which reviewers to spawn for each review.

## Always-on (4 structured personas + 1 local prompt asset)

Spawned on every review regardless of diff content.

**Structured persona prompt assets:**

| Persona | Prompt asset | Focus |
|---------|-------|-------|
| `correctness` | `correctness-reviewer` | Logic errors, edge cases, state bugs, error propagation, intent compliance |
| `testing` | `testing-reviewer` | Coverage gaps, weak assertions, brittle tests, missing edge case tests |
| `maintainability` | `maintainability-reviewer` | Structural quality, complexity deletion, 1k-line regressions, coupling, type-boundary leaks, dead code, premature abstraction |
| `project-standards` | `project-standards-reviewer` | CLAUDE.md and AGENTS.md compliance -- frontmatter, references, naming, cross-platform portability, tool selection |

**CE local prompt assets (unstructured output, synthesized separately):**

| Prompt asset | Focus |
|-------|-------|
| `learnings-researcher` | Search docs/solutions/ for past issues related to this PR's modules and patterns |

## Conditional (7 personas)

Spawned when the orchestrator identifies relevant patterns in the diff. The orchestrator reads the full diff and reasons about selection -- this is agent judgment, not keyword matching.

| Persona | Agent | Select when diff touches... |
|---------|-------|---------------------------|
| `security` | `security-reviewer` | Auth middleware, public endpoints, user input handling, permission checks, secrets management |
| `performance` | `performance-reviewer` | Database queries, ORM calls, loop-heavy data transforms, caching layers, async/concurrent code |
| `api-contract` | `api-contract-reviewer` | Route definitions, serializer/interface changes, event schemas, exported type signatures, API versioning |
| `data-migration` | `data-migration-reviewer` | Migration files, schema dumps (`db/schema.rb`, `structure.sql`), backfill scripts, data transformations — **not** model/query-only changes without migration artifacts |
| `reliability` | `reliability-reviewer` | Error handling, retry logic, circuit breakers, timeouts, background jobs, async handlers, health checks |
| `adversarial` | `adversarial-reviewer` | Diff has >=50 changed non-test, non-generated, non-lockfile lines, OR touches auth, payments, data mutations, external API integrations, or other high-risk domains |
| `previous-comments` | `previous-comments-reviewer` | **PR-only AND comment-gated.** Reviewing a PR that has existing review comments or review threads from prior review rounds. Skip entirely when no PR metadata was gathered in Stage 1, OR when Stage 1's `hasPriorComments` flag is false (no `reviews` and no `comments` on the PR). |

## CE Conditional Local Prompt Assets (migration-specific)

Use `deployment-verification-agent` when the migration-artifact gate applies **and** the change is risky (destructive DDL, backfills, NOT NULL without default, column renames/drops). Schema drift and migration safety live in the `data-migration` persona — not a separate typed agent.

| Prompt asset | Focus |
|-------|-------|
| `deployment-verification-agent` | Go/No-Go deployment checklist with SQL verification queries and rollback procedures |

## Selection rules

1. **Always spawn all 4 always-on personas** plus the always-on local prompt asset (`learnings-researcher`).
2. **For each cross-cutting conditional persona**, the orchestrator reads the diff and decides whether the persona's domain is relevant. This is a judgment call, not a keyword match.
3. **For `data-migration`**, spawn only when the diff includes migration or schema artifacts (`db/migrate/*`, `db/schema.rb`, `db/structure.sql`, Alembic/Flyway/Liquibase paths, or explicit backfill/data-transform scripts). Do **not** spawn for model-only or query-only changes without those files.
4. **For CE conditional prompt assets**, use `deployment-verification-agent` when the migration-artifact gate applies and the change is risky (see above).
5. **Announce the team** before spawning with a one-line justification per conditional reviewer selected.
