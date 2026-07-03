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

### Non-path inputs (repo names, slugs, numbers)

```bash
if [[ "$input" =~ [\;\|\&\$\`\!\>\<\(\)\{\}\~\*\?/] ]]; then
  echo '{"ok":false,"error":"--input contains shell metacharacters"}' >&2
  exit 1
fi
```

### File-path inputs

File paths naturally contain `/`, so exclude it from the blocklist:

```bash
if [[ "$path" =~ [\;\|\&\$\`\!\>\<\(\)\{\}\~\*\?] ]]; then
  echo '{"ok":false,"error":"--path contains shell metacharacters"}' >&2
  exit 1
fi
```

### Blocked characters

The blocklist includes:
- Control characters: `\x00-\x1f`, `\x7f`
- Shell operators: `;`, `|`, `&`, `$`, `` ` ``
- Redirect/subshell: `<`, `>`, `(`, `)`
- Brace expansion: `{`, `}`
- Other metacharacters: `~`, `*`, `?`, `!`, `\`
- Path separator: `/` (non-path inputs only)

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

## References

- [ShellCheck](https://www.shellcheck.net/) for static analysis
- [bash strict mode](http://redsymbol.net/articles/unofficial-bash-strict-mode/)
