#!/usr/bin/env bash
# Test: scripts/lib/input-validation.sh
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LIB="$REPO_ROOT/scripts/lib/input-validation.sh"

pass=0
fail=0
ok() { pass=$((pass + 1)); echo "  PASS: $1"; }
die() { fail=$((fail + 1)); echo "  FAIL: $1"; }

echo "=== test-input-validation.sh ==="

# shellcheck source=../../scripts/lib/input-validation.sh
source "$LIB"

# --- validate_no_metachars ---------------------------------------------

if validate_no_metachars "clean-value123"; then
  ok "no_metachars: clean value passes"
else
  die "no_metachars: clean value should pass"
fi

if ! validate_no_metachars "bad;value"; then
  ok "no_metachars: semicolon rejected"
else
  die "no_metachars: semicolon should be rejected"
fi

if ! validate_no_metachars 'bad`value'; then
  ok "no_metachars: backtick rejected"
else
  die "no_metachars: backtick should be rejected"
fi

if ! validate_no_metachars 'bad$(cmd)'; then
  ok "no_metachars: command substitution rejected"
else
  die "no_metachars: command substitution should be rejected"
fi

if ! validate_no_metachars "has space"; then
  ok "no_metachars: space rejected"
else
  die "no_metachars: space should be rejected"
fi

if ! validate_no_metachars "has/slash"; then
  ok "no_metachars: slash rejected by default"
else
  die "no_metachars: slash should be rejected by default"
fi

if validate_no_metachars "owner/repo" --allow-slash; then
  ok "no_metachars: slash allowed with --allow-slash"
else
  die "no_metachars: slash should be allowed with --allow-slash"
fi

if ! validate_no_metachars "owner/repo;rm -rf" --allow-slash; then
  ok "no_metachars: metachar still rejected with --allow-slash"
else
  die "no_metachars: metachar should still be rejected with --allow-slash"
fi

# --- validate_repo_format -----------------------------------------------

if validate_repo_format "owner/repo"; then
  ok "repo_format: valid owner/repo"
else
  die "repo_format: valid owner/repo should pass"
fi

if ! validate_repo_format "invalid"; then
  ok "repo_format: missing slash rejected"
else
  die "repo_format: missing slash should be rejected"
fi

if ! validate_repo_format "owner/repo/extra"; then
  ok "repo_format: extra path segment rejected"
else
  die "repo_format: extra path segment should be rejected"
fi

# --- validate_pr_number_format -------------------------------------------

if validate_pr_number_format "123"; then
  ok "pr_number: valid digits"
else
  die "pr_number: valid digits should pass"
fi

if ! validate_pr_number_format "abc"; then
  ok "pr_number: non-numeric rejected"
else
  die "pr_number: non-numeric should be rejected"
fi

if ! validate_pr_number_format "12a"; then
  ok "pr_number: mixed alphanumeric rejected"
else
  die "pr_number: mixed alphanumeric should be rejected"
fi

# --- validate_pr_url_format ----------------------------------------------

if validate_pr_url_format "https://github.com/owner/repo/pull/123"; then
  ok "pr_url: full GitHub PR URL valid"
else
  die "pr_url: full GitHub PR URL should pass"
fi

if validate_pr_url_format "123"; then
  ok "pr_url: bare PR number valid (fallthrough path)"
else
  die "pr_url: bare PR number should pass"
fi

if ! validate_pr_url_format "not-a-url"; then
  ok "pr_url: invalid string rejected"
else
  die "pr_url: invalid string should be rejected"
fi

if ! validate_pr_url_format "https://example.com/owner/repo/pull/123"; then
  ok "pr_url: non-GitHub host rejected"
else
  die "pr_url: non-GitHub host should be rejected"
fi

# --- validate_reviewer_name -----------------------------------------------

if validate_reviewer_name "alice"; then
  ok "reviewer: simple name valid"
else
  die "reviewer: simple name should pass"
fi

if validate_reviewer_name "alice-bob"; then
  ok "reviewer: hyphenated name valid"
else
  die "reviewer: hyphenated name should pass"
fi

if ! validate_reviewer_name "-alice"; then
  ok "reviewer: leading hyphen rejected"
else
  die "reviewer: leading hyphen should be rejected"
fi

if ! validate_reviewer_name "alice-"; then
  ok "reviewer: trailing hyphen rejected"
else
  die "reviewer: trailing hyphen should be rejected"
fi

if ! validate_reviewer_name "alice;rm"; then
  ok "reviewer: metacharacter rejected"
else
  die "reviewer: metacharacter should be rejected"
fi

# --- validate_thread_id_format ---------------------------------------------

if validate_thread_id_format "PRRT_test123"; then
  ok "thread_id: valid PRRT_ format"
else
  die "thread_id: valid PRRT_ format should pass"
fi

if ! validate_thread_id_format "bad id"; then
  ok "thread_id: space rejected"
else
  die "thread_id: space should be rejected"
fi

if ! validate_thread_id_format 'bad;id'; then
  ok "thread_id: metacharacter rejected"
else
  die "thread_id: metacharacter should be rejected"
fi

# --- validate_gh_environment -----------------------------------------------
# Environment-dependent (gh may or may not be installed/authenticated here),
# so only assert the contract: exactly one of 0/1/2, and the safe `||`
# calling convention doesn't abort the script under set -e.

gh_rc=0
validate_gh_environment || gh_rc=$?
if [[ $gh_rc -eq 0 || $gh_rc -eq 1 || $gh_rc -eq 2 ]]; then
  ok "gh_environment: returns a code in {0,1,2} ($gh_rc)"
else
  die "gh_environment: unexpected code ($gh_rc)"
fi

# Regression guard: the safe `||` calling convention must not trigger
# `set -e` and abort the script -- if it did, this line would never run.
ok "gh_environment: safe calling convention did not abort under set -e"

# --- Library file conventions -----------------------------------------------

if [[ -f "$LIB" ]]; then
  ok "library file exists"
else
  die "library file does not exist"
fi

if head -1 "$LIB" | grep -q "^#!/usr/bin/env bash"; then
  ok "library has bash shebang"
else
  die "library missing bash shebang"
fi

if grep -q "set -euo pipefail" "$LIB"; then
  ok "library uses set -euo pipefail"
else
  die "library missing set -euo pipefail"
fi

echo ""
echo "Results: $pass passed, $fail failed"
[[ $fail -eq 0 ]] && exit 0 || exit 1
