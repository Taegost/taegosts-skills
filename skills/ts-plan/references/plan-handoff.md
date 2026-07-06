# Plan Handoff

This file contains post-plan-writing instructions: document review, post-generation options, and issue creation. Load it after the plan file has been written and the confidence check (5.3.1-5.3.7) is complete.

## 5.3.8 Document Review

Run the `ts-doc-review` skill with `mode:headless` on the plan file. Pass `mode:headless <plan-path>` as the skill arguments. When this step is reached, it is mandatory — do not skip it because the confidence check already ran. The two tools catch different classes of issues.

Headless is the default at this phase because most users want to start work after planning, not adjudicate every reviewer concern up front. Headless applies `safe_auto` fixes silently and returns structured findings text — no walkthrough, no per-finding routing, no blocking prompts. The post-generation menu (see 5.4) offers `Run deeper doc review` as a first-class option so users can opt into the full interactive walkthrough when they want it.

The confidence check and ts-doc-review are complementary:
- The confidence check strengthens rationale, sequencing, risk treatment, and grounding
- Document-review checks coherence, feasibility, scope alignment, and surfaces role-specific issues

Capture the headless envelope so it can drive the contextual summary above the post-generation menu:
- The number of fixes auto-applied
- The count of remaining findings, broken out by user-facing bucket (proposed fixes, decisions, FYI observations)
- The severity breakdown of decisions and proposed fixes (specifically the P0/P1 count, since those benefit from explicit user attention)

When ts-doc-review returns "Review complete", proceed to Final Checks.

**Pipeline mode:** Pipeline runs (LFG or any `disable-model-invocation` context) always invoke `ts-doc-review` with `mode:headless` and the plan path — the headless mode is identical to the interactive default at this phase. No further routing is offered in pipeline mode; the caller decides what to do with the returned findings. Address any P0/P1 findings before returning control to the caller.

## 5.3.9 Final Checks and Cleanup

Before proceeding to post-generation options:
- Confirm the plan is stronger in specific ways, not merely longer
- Confirm the planning boundary is intact
- Confirm origin decisions were preserved when an origin document exists

If artifact-backed mode was used:
- Clean up the temporary scratch directory after the plan is safely updated
- If cleanup is not practical on the current platform, note where the artifacts were left

Write the markdown directly per `references/markdown-rendering.md`.

After all mutations in this run have settled (initial write, deepening synthesis, ts-doc-review `safe_auto` fixes), the artifact at its single path reflects the final state.

## 5.4 Post-Generation Options

**Pipeline mode:** If invoked from an automated workflow such as LFG or any `disable-model-invocation` context, skip the interactive menu below and return control to the caller immediately. The plan file has already been written, the confidence check has already run, and ts-doc-review has already run — the caller (e.g., lfg) determines the next step.

**Path format:** Use absolute paths for chat-output file references — relative paths are not auto-linked as clickable in most terminals.

**Summary line above the menu (always):** Print a single concise line summarizing the headless review state — e.g., `Doc review applied 3 fixes. 2 decisions, 1 proposed fix, 4 FYI observations remain (1 at P1).` When no fixes were applied and no findings remain, print `Doc review clean — no fixes needed.` This line establishes what the autofix pass did (or didn't) so the user has the context to choose between the menu options below.

**Question:** "Plan ready at `<absolute path to plan>`. What would you like to do next?"

**Options:**
1. **Start `/ts-work`** (recommended) - Begin implementing this plan in the current session
2. **Run deeper doc review** - Walk through the remaining findings interactively (full ts-doc-review walkthrough)
3. **Create Issue** - Create a tracked issue from this plan in your configured issue tracker (e.g., GitHub Issues, Linear, Jira)
4. **Done for now** - Pause; the plan file is saved and can be resumed later

**Menu rendering:** 4 options fits `AskUserQuestion` on Claude Code. On platforms with no option cap (Codex `request_user_input`, Pi `ask_user`), use the platform's blocking tool. When unavailable or errors, render as a numbered list in chat with "Pick a number or describe what you want." Never silently skip.

**Hide `Run deeper doc review` when no actionable findings remain.** Show option 2 only when the headless envelope reports `proposed_fixes_count + decisions_count > 0`. Drop when only FYIs remain — ts-doc-review's walkthrough is gated to actionable findings. When dropped, renumber 1-3.

Based on selection:
- **Start `/ts-work`** -> Invoke `ts-work` via the platform's skill-invocation primitive, passing the plan path. Fire the invocation now — do not merely tell the user to type `/ts-work`.
- **Run deeper doc review** -> Re-invoke `ts-doc-review` on the plan path without `mode:headless`. The headless pass's R29 suppression prevents re-raising prior-round Skipped/Deferred entries. Re-render this menu after.
- **Create Issue** -> Follow the Issue Creation section below.
- **Done for now** -> Confirm the plan file is saved and end the turn.
- **Free-form prompts targeting findings** (e.g., "review", "walk through") -> route as `Run deeper doc review`.
- **Other free-form input** -> Accept revisions and loop back to options.

## Issue Creation

When the user selects "Create Issue":

1. **Identify the project's issue tracker from the active instructions and conventions already in your context** — the issue / project-management tool the project uses (e.g., GitHub Issues, Linear, Jira). Don't open or name specific instruction files to do this; the project's instructions are already available to you. Look for an explicit `project_tracker:` declaration (`github`, `linear`, …) or any documented tracker convention. Only if your context doesn't already carry the project's instructions (e.g., you're a fresh subagent) or they're silent, consult supplementary signals: `README.md`, `CONTRIBUTING.md`, PR templates under `.github/`, or visible tracker URLs.

2. **Create the issue through whatever interface that tracker actually exposes in this environment** — a platform connector/MCP tool, documented API/GraphQL credentials, or a documented CLI. First actively discover what's available: use the platform's tool-discovery primitive (e.g., `ToolSearch` in Claude Code) to look for a tracker connector or MCP tool before assuming none exists — lazy-loaded connectors and credentials stored outside the shell won't surface in a passive check. Do not assume a tracker means a particular CLI, and do not treat a missing binary, env var, or unloaded MCP server as proof the tracker is unavailable — those are false negatives when access comes through a connector or a raw API with credentials stored outside the shell. When using a direct API, never print secret values; read the plan body from disk and send it as the issue's markdown/description per the API contract. Worked examples for the common cases:
   - **GitHub** — `gh issue create --title "<type>: <title>" --body-file <plan_path>`
   - **Linear** (no guaranteed first-party CLI) — prefer, in order: a Linear connector or MCP tool that can create issues → documented direct API/GraphQL credentials and endpoint → a documented local Linear CLI, only when the project or user explicitly states it is installed and authenticated.

3. If no tracker is configured, ask the user which tracker they use with the platform's blocking question tool: `AskUserQuestion` in Claude Code (call `ToolSearch` with `select:AskUserQuestion` first if its schema isn't loaded), `request_user_input` in Codex, `ask_question` in Antigravity CLI (`agy`), `ask_user` in Pi (requires the `pi-ask-user` extension). Fall back to asking in chat only when no blocking tool exists or the call errors (e.g., Codex edit modes) — not because a schema load is required. Never silently skip. Offer three explicit options — `GitHub`, `Linear`, `Skip` — and let the user name a different tracker (Jira, etc.) through the tool's built-in free-form / "Other" input: `AskUserQuestion` always provides it, and `request_user_input` / `ask_user` supply their own. Don't add an explicit fourth `Other` option — that's redundant where the tool already offers free-form and can exceed the option cap on tools that accept only 2–3 explicit choices (e.g., Codex `request_user_input`). When the tool exposes no free-form path, capture the other-tracker name via the chat fallback. Then:
   - Proceed with the chosen tracker's creation path above
   - If the user names a different tracker through the free-form path, ask for its reachable interface if they didn't say, then create the issue via the capability path in step 2
   - Offer to persist the choice by adding a `project_tracker: <value>` declaration to the project's root agent-instructions file (e.g., `AGENTS.md`; if it `@`-includes another file, write to the substantive one). Use the lowercase tracker key (`github`, `linear`, `jira`, …) — not the display label — so future runs match step 1 and skip this prompt
   - If `Skip`, return to the options without creating an issue

4. If the detected tracker has no reachable interface after actively discovering available connector/MCP tools and following its documented access method — no working connector, MCP tool, CLI, or API path — surface a clear error (e.g., "`gh` CLI not found or not authenticated for GitHub Issues"; "Linear is documented for this project, but no connector, MCP tool, or API credentials were found") and return to the options. Do not silently fall back to a local issue-plan document unless the user explicitly asks for a local-only artifact.

After issue creation:
- Display the issue URL
- Ask whether to proceed to `/ts-work` using the platform's blocking question tool
