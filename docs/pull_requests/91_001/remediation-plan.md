# PR #91 Remediation Plan — Iteration 001

## Group 1: SKILL.md (Findings 1-9)

All findings target `skills/ts-pr-fix-findings/SKILL.md`. Fixes are interdependent and will be applied as a single pass.

### F1 (High) — Add Kanban card creation to Step 6b
- Add instruction: "Create new Kanban cards for verification findings (same format as Step 2c), tagged with `[verification-round-N]` to distinguish from original review findings"
- Insert before the disposition model mention

### F2 (High) — Fix output format description
- Change "Parse the verification output for failing dimensions (correctness, completeness, scope, standards)" to describe the actual consolidated table format: "Parse the verification summary table (columns: #, Severity, File, Issue) for FAIL/PARTIAL findings"

### F3 (High) — Bridge format gap to Step 3
- Add instruction: "Map each verification finding to Step 3's expected input format: file path, line reference (if available), the verification concern as the reviewer note, and mark source as `[verification-round-N]`"

### F4 (High) — Add user-confirmation gate
- Add: "Present proposed dispositions (fix/decline/needs-input) to the user. Do not proceed to fix planning until the user confirms." (mirrors Step 2b's gate language)

### F5 (High) — Non-blocking iteration cap
- Change "report the remaining findings to the user and ask whether to continue iterating" to: "Report remaining findings to the user. Continue to Step 7 without blocking — the user can address remaining findings in a follow-up session."

### F6 (Moderate) — Filename extraction in Step 6a
- Add: "Extract the filename from Step 0a's plan path: use `basename <plan-path>` to strip the `docs/plans/` prefix."

### F7 (Moderate) — Iteration tracking
- Add: "Track the iteration count on the Kanban board: create or update a card titled `verification-loop-tracker` with the current iteration number. Read this card before each iteration to determine whether the cap has been reached."

### F8 (Moderate) — Update Step 6 loop guard
- Update the loop condition text to note that resolution verification failures are more stringent and may require escalation to the user for KTD conflicts.

### F9 (Minor) — Short-circuit for unresolvable findings
- Add after item 4: "If the concern is unresolvable (KTD conflict or out of scope), do not loop back to Step 3. Instead, surface it to the user as a known residual and continue."

## Group 2: CONCEPTS.md (Finding 10)

- Update Agent definition to clarify it covers both staged and dispatched subagent prompt files
- Update Agent Profile to mention optional `disallowedTools` alongside the four required fields

## Group 3: agent-definition-convention.md (Finding 11)

- Change "exactly these fields" to "the following required fields" (or similar)
