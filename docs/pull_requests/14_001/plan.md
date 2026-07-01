# PR #14 Fix Plan — Iteration 001

## Finding Dispositions (confirmed by user)

| # | Sev | File | Finding | Fix |
|---|-----|------|---------|-----|
| 1 | 🔴 High | `coding-workflow/SKILL.md` L24 | Quoted glob `skills/*/scripts` doesn't expand in PATH | Replace single export with loop pattern |
| 2 | 🔴 High | `script-index/SKILL.md` L19 | Same — quoted glob in PATH | Same loop pattern |
| 3 | 🟡 Mod | `verify-fix.sh` L47-67 | `--file` not validated before checks; `--should-match` needs `--` guard | Add `--file` validation before loop; add `--` to grep |
| 4 | 🟡 Mod | `verify-scripts.sh` L103-104 | `--file` branch doesn't validate `$2` exists | Add guard for missing `$2` |
| 5 | 🟡 Mod | `to-json.sh` L41-59 | Object-mode coerces unquoted values to bool/int/float | Rewrite internals to use `jq -n` wrapper |
| 6 | 🟡 Minor | `verify-scripts.sh` L108-111 | Unknown flags treated as "no files" instead of erroring | Add `-` prefix detection before file/dir checks |
| 7 | 🔵 Trivial | `coding-workflow/SKILL.md` L22 | MD031: missing blank line before fenced block | Add blank line |
| 8 | 🔵 Trivial | `script-index/SKILL.md` L17 | MD031: missing blank line before fenced block | Add blank line |
| 9 | 🟡 Minor | `script-index/SKILL.md` L81 | MD056: table has 4 columns, header has 3 | Fix table structure |
| 10 | 🔵 Trivial | `test-verify-scripts.sh` | Missing test coverage + brittle `A && B || C` chaining | Refactor to if/then/else + add test cases |
| 11 | 🟡 Minor | `verify-scripts.sh` L57 | `--file` guard missing in else branch | Same as #4 — unified fix |

## Merge Conflicts

`skills/coding-workflow/SKILL.md` and `skills/script-index/SKILL.md` have conflicts with main.
Resolve by keeping the PR branch version and applying our fixes on top.

## Files Modified

1. `skills/coding-workflow/SKILL.md` — findings #1, #7
2. `skills/script-index/SKILL.md` — findings #2, #8, #9
3. `scripts/verify-fix.sh` — finding #3
4. `scripts/verify-scripts.sh` — findings #4, #6, #11
5. `scripts/to-json.sh` — finding #5
6. `tests/scripts/test-verify-scripts.sh` — finding #10

## Notes

- Finding #5: User approved rewriting to-json.sh as a jq wrapper. Keep `key=value` interface, replace Python internals with `jq -n --arg`/`--argjson`.
- Finding #3: `--file` check added before any check runs. `--should-match` gets `--` guard to prevent pattern starting with `-` being interpreted as flag.
- Finding #10: Also needs test for to-json.sh changes (jq wrapper).
