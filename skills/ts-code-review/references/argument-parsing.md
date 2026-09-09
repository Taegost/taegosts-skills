# Argument-Parsing Edge Rules

Loaded on demand by `SKILL.md` (Argument Parsing) — the conflict-matrix details behind the token table and the conflict rule summary there.

**Grouping is presentation, not a mode.** The `grouping:` tokens change how the finding set is organized for triage — never reviewer selection, merge logic, scope rules, or the Stage 5c apply decision.

**Mode alias:** `mode:headless` normalizes to `mode:agent`. `mode:agent` + `mode:headless` is not a conflict.

**Conflicting arguments:** Stop without dispatching reviewers when:
- Multiple incompatible scope selectors appear together (e.g. `base:` **and** a PR number/branch target — `base:` means "review the current checkout against this base")
- Multiple distinct `mode:` tokens other than the `mode:agent`/`mode:headless` alias pair
- Multiple distinct `grouping:` tokens (e.g. `grouping:off` **and** `grouping:always`)

Deprecated `mode:autofix` is **not** a conflict — ignore the token and proceed with the normal flow (default applies safe fixes via Stage 5c; `mode:agent` reports and the caller applies).

On a conflict, emit a one-line failure reason. In `mode:agent`, return JSON: `{"status":"failed","reason":"..."}`.
