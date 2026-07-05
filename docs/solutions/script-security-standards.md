# Script Security Standards

This document defines the security and quality standards for all bash scripts in this repository.

## 1. Shell Flags

All scripts must use strict shell flags:

```bash
#!/usr/bin/env bash
set -euo pipefail
```

- `-e`: Exit immediately on command failure
- `-u`: Treat unset variables as errors
- `-o pipefail`: Return exit status of last failing command in pipeline

**Never use `set -uo pipefail` without `-e`.** The `-e` flag is critical for catching unexpected failures.

## 2. Metacharacter Validation

All user-supplied inputs must be validated against shell metacharacters before use.

**Important:** Bash `[[ =~ ]]` does not interpret `\n` or `\t` as escape sequences — they match literal two-character sequences. Use ANSI-C quoting (`$'...'`) for the regex variable to properly match control characters.

### Non-path inputs (repo names, slugs, numbers)

```bash
METACHAR_RE=$'[\x01-\x1f\x7f;<>(){}~\\`!$&\'"|*?/ \n\t]'
if [[ "$input" =~ $METACHAR_RE ]]; then
  echo '{"ok":false,"error":"--input contains shell metacharacters"}' >&2
  exit 1
fi
```

### File-path inputs

File paths naturally contain `/`, so exclude it from the blocklist:

```bash
METACHAR_RE=$'[\x01-\x1f\x7f;<>(){}~\\`!$&\'"|*? \n\t]'
if [[ "$path" =~ $METACHAR_RE ]]; then
  echo '{"ok":false,"error":"--path contains shell metacharacters"}' >&2
  exit 1
fi
```

### Blocked characters

The blocklist includes:
- Control characters: `\x01-\x1f` (including `\n`, `\t`), `\x7f` (`\x00` excluded — bash variables cannot hold null bytes)
- Shell operators: `;`, `|`, `&`, `$`, `` ` ``
- Redirect/subshell: `<`, `>`, `(`, `)`
- Brace expansion: `{`, `}`
- Other metacharacters: `~`, `*`, `?`, `!`
- Quotes: `"`, `'`
- Whitespace: space, newline, tab
- Path separator: `/` (non-path inputs only)

### Special cases

- **`--repo` inputs:** Allow `/` (required for `owner/repo` format). Block `/` only in `--pr` or similar numeric inputs.
- **Slug inputs:** Block `/` and `..` to prevent path traversal.

## 3. Path Traversal Blocking

Inputs that become filesystem paths must reject `..`:

```bash
if [[ "$input" == *".."* ]]; then
  echo '{"ok":false,"error":"--input must not contain path traversal (..)"}' >&2
  exit 1
fi
```

## 4. Argument Count Guards

When using `set -euo pipefail`, accessing `$2` when only 1 argument is provided causes an unbound variable crash. Guard against this:

```bash
if [[ $# -lt 2 ]]; then
  echo '{"ok":false,"error":"--flag1 and --flag2 are required"}' >&2
  exit 1
fi
```

Place this guard **before** the argument-parsing loop.

## 5. Error Format

All errors must be JSON objects written to stderr:

```bash
echo '{"ok":false,"error":"human-readable message"}' >&2
```

Optional `hint` field for remediation guidance:

```bash
echo '{"ok":false,"error":"--type must be feat, fix, or chore","hint":"valid values: feat, fix, chore"}' >&2
```

### Rules

- Use static strings preferred over interpolated values
- If interpolating, sanitize: `value="${value//\"/\\\"}"`
- Always include `"ok":false`
- Always write to stderr (`>&2`)
- Always exit with appropriate code (1 for errors, 2 for "not found" semantics)

## 6. Input Validation

### Repository format

```bash
if [[ ! "$repo" =~ ^[a-zA-Z0-9._-]+/[a-zA-Z0-9._-]+$ ]]; then
  echo '{"ok":false,"error":"--repo must be in owner/repo format"}' >&2
  exit 1
fi
```

### Numeric values

```bash
if [[ ! "$number" =~ ^[0-9]+$ ]]; then
  echo '{"ok":false,"error":"--number must be a number"}' >&2
  exit 1
fi
```

## 7. Safe Execution Context

After validation, all inputs must be consumed via double-quoted variable expansion:

```bash
# Correct
gh api "repos/${repo}/issues/${number}/comments"

# Wrong - never eval user input
eval "gh api repos/${repo}/issues/${number}/comments"
```

## 8. Unknown Argument Rejection

Argument parsers must reject unknown flags:

```bash
while [[ $# -gt 0 ]]; do
  case "$1" in
    --flag) value="$2"; shift 2 ;;
    *) echo '{"ok":false,"error":"unknown argument"}' >&2; exit 1 ;;
  esac
done
```

## 9. Credential Handling

GitHub API credentials are handled externally via the `gh` CLI. Do not implement custom token management:

```bash
gh auth status >/dev/null 2>&1 || { echo '{"ok":false,"error":"gh auth not configured"}' >&2; exit 1; }
```

## 10. Documentation

Each script must have:

- A header comment explaining purpose, input, output, and exit codes
- A `--help` flag that prints usage information
- Exit codes documented in the help text

## 11. Shellcheck Configuration

The repository uses [ShellCheck](https://www.shellcheck.net/) for static analysis of all shell scripts. Configuration lives in `.shellcheckrc` at the repo root.

### Running Shellcheck

Use the dedicated runner script:

```bash
scripts/run-shellcheck.sh
```

This scans `tests/`, `scripts/`, and `skills/*/scripts/` directories. The `.shellcheckrc` file sets `shell=bash` and disables checks that are false positives or intentional patterns in test code.

### Disabled checks

The following checks are disabled globally in `.shellcheckrc` with documented rationale:

| Code | Level | Rationale |
|------|-------|-----------|
| SC2015 | info | `A && B \|\| C` pattern used intentionally in test assertions and `|| true` guards |
| SC2016 | info | Single-quoted strings intentionally passed as literal arguments to grep/commands |
| SC2140 | warning | Escaped quotes inside double-quoted strings are intentional when embedding code |
| SC2155 | warning | Declare-and-assign-separately in test setup code where return value is not checked |
| SC2181 | style | `$?` exit code check is idiomatic in test setup code |
| SC2034 | warning | Variables assigned for intent clarity in test scripts |
| SC2317 | info | Function definitions called via traps appear unreachable to static analysis |

### Adding new scripts

All new scripts must pass `shellcheck` cleanly. If a check fires on a genuine false positive, add a targeted disable comment in the script rather than disabling globally:

```bash
# shellcheck disable=SC2015
cmd && do_something || true
```

## References

- [ShellCheck](https://www.shellcheck.net/) for static analysis
- [bash strict mode](http://redsymbol.net/articles/unofficial-bash-strict-mode/)
