#!/usr/bin/env bash
# input-validation.sh -- Sourceable validation helpers for GitHub API interactions
#
# PURPOSE:
#   Deduplicates the shell-metacharacter regex and gh-CLI/format validation
#   logic that was independently copy-pasted across 10 scripts (see Issue
#   #109). Functions return status codes; they do NOT print error messages
#   or exit -- each caller keeps its own message text and exit behavior so
#   this library is a drop-in for existing scripts without changing their
#   observable output.
#
# INPUTS:
#   validate_gh_environment          - 0 if gh installed+authenticated, 1 if
#                                       missing, 2 if not authenticated
#   validate_no_metachars <value> [--allow-slash]
#                                     - 0 if clean, 1 if it contains shell
#                                       metacharacters. Blocks '/' unless
#                                       --allow-slash is passed.
#   validate_repo_format <value>     - 0 if "owner/repo" shaped, 1 otherwise
#   validate_pr_number_format <val>  - 0 if all-digits, 1 otherwise
#   validate_pr_url_format <value>   - 0 if a GitHub PR URL or bare PR
#                                       number, 1 otherwise
#   validate_reviewer_name <value>   - 0 if a valid GitHub username shape
#                                       (alphanumeric + hyphens, no leading/
#                                       trailing hyphen), 1 otherwise
#   validate_thread_id_format <val>  - 0 if a GraphQL node-ID shape, 1
#                                       otherwise
#
# PRIMARY CONSUMERS:
#   - scripts/gh-get-pr-state.sh
#   - skills/ts-pr-fix-findings/scripts/*.sh
#   - skills/ts-plan/scripts/generate-plan-filename.sh
#   - skills/ts-verify-implementation/scripts/detect-file-status.sh
#   - skills/ts-work/scripts/detect-missing-artifacts.sh
#
# USAGE:
#   source "$(dirname "$0")/../../../scripts/lib/input-validation.sh"  # adjust depth
#   if ! validate_no_metachars "$pr_url"; then
#     echo '{"ok":false,"error":"--pr-url contains shell metacharacters"}' >&2
#     exit 1
#   fi
#
#   All consuming scripts use `set -euo pipefail`. validate_gh_environment
#   returns 0/1/2 (not a plain boolean), so NEVER call it as a bare
#   statement -- under `set -e` a bare failing call aborts the script before
#   you can inspect $?. Capture the code via `||` (exempt from -e) instead:
#     gh_rc=0
#     validate_gh_environment || gh_rc=$?
#     case $gh_rc in
#       1) echo '{"ok":false,"error":"gh CLI not available"}' >&2; exit 1 ;;
#       2) echo '{"ok":false,"error":"gh CLI not authenticated"}' >&2; exit 1 ;;
#     esac
#   The boolean-style functions (validate_no_metachars, validate_repo_format,
#   etc.) are safe to call directly inside `if`/`if !` -- that context is
#   itself exempt from -e.

set -euo pipefail

# Non-slash metacharacter regex (KTD1: blocks control chars, shell
# metacharacters, quotes, whitespace, and '/'). Use for values that must
# never contain a path separator (PR numbers, thread IDs, reviewer names).
_IV_NO_SLASH_METACHAR_RE=$'[\x01-\x1f\x7f;<>(){}~\\`!$&\'"|*?/ \n\t]'

# Path-permitting metacharacter regex (same as above but allows '/'). Use
# for values that legitimately contain a slash (owner/repo, file paths,
# PR URLs).
_IV_PATH_METACHAR_RE=$'[\x01-\x1f\x7f;<>(){}~\\`!$&\'"|*? \n\t]'

# validate_gh_environment
# Returns: 0 if gh is installed and authenticated, 1 if gh is not
# installed, 2 if gh is installed but not authenticated.
validate_gh_environment() {
  if ! command -v gh &>/dev/null; then
    return 1
  fi
  if ! gh auth status >/dev/null 2>&1; then
    return 2
  fi
  return 0
}

# validate_no_metachars <value> [--allow-slash]
# Returns: 0 if the value contains no shell metacharacters, 1 otherwise.
# By default '/' is treated as a metacharacter (blocked); pass
# --allow-slash for values that legitimately contain a path separator.
validate_no_metachars() {
  local value="$1"
  local allow_slash="${2:-}"
  if [[ "$allow_slash" == "--allow-slash" ]]; then
    [[ "$value" =~ $_IV_PATH_METACHAR_RE ]] && return 1
  else
    [[ "$value" =~ $_IV_NO_SLASH_METACHAR_RE ]] && return 1
  fi
  return 0
}

# validate_repo_format <value>
# Returns: 0 if the value is "owner/repo" shaped, 1 otherwise.
validate_repo_format() {
  [[ "$1" =~ ^[a-zA-Z0-9._-]+/[a-zA-Z0-9._-]+$ ]]
}

# validate_pr_number_format <value>
# Returns: 0 if the value is all-digits, 1 otherwise.
validate_pr_number_format() {
  [[ "$1" =~ ^[0-9]+$ ]]
}

# validate_pr_url_format <value>
# Returns: 0 if the value is a full GitHub PR URL
# (https://github.com/<owner>/<repo>/pull/<number>) or a bare numeric PR
# number, 1 otherwise.
validate_pr_url_format() {
  [[ "$1" =~ ^https://github\.com/[a-zA-Z0-9._-]+/[a-zA-Z0-9._-]+/pull/[0-9]+$ ]] && return 0
  [[ "$1" =~ ^[0-9]+$ ]]
}

# validate_reviewer_name <value>
# Returns: 0 if the value is a valid GitHub username shape (alphanumeric
# and hyphens, cannot start or end with a hyphen), 1 otherwise.
validate_reviewer_name() {
  [[ "$1" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?$ ]]
}

# validate_thread_id_format <value>
# Returns: 0 if the value matches GitHub GraphQL node-ID shape
# (alphanumeric, underscore, hyphen, plus, equals, slash, dot -- e.g.
# PRRT_xxx, PRRC_xxx), 1 otherwise.
validate_thread_id_format() {
  [[ "$1" =~ ^[A-Za-z0-9_+=/.-]+$ ]]
}
