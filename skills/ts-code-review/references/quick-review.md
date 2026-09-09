# Quick Review Short-Circuit

Loaded on demand by `SKILL.md` — read when `$ARGUMENTS` indicates the user wants a quick, fast, or light code review and **`mode:agent` is not active**, before any other review work.

If `$ARGUMENTS` indicates the user wants a quick, fast, or light code review — and **`mode:agent` is not active** — do not dispatch the multi-agent flow.

**Announce the chosen path** before any other work (Quick review vs Multi-agent review). Skip this announcement when `mode:agent` is active.

Sequence:

1. **Run the harness's built-in code review.** Forward any review target after stripping tokens. Then stop — do not dispatch the multi-agent pipeline.
2. **Exemption:** If no built-in review exists, continue into the full multi-agent review.
3. **`mode:agent` bypasses this short-circuit** — always run the full multi-agent review and return JSON.

**Deprecated:** `mode:autofix` is no longer supported — there is no apply *mode*. If passed, ignore the token and proceed with the normal flow (default applies safe fixes via Stage 5c; `mode:agent` reports and the caller applies).
