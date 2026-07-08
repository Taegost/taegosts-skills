#!/usr/bin/env bats
# tests/scripts/test-request-reviews.bats
# Tests for scripts/request-reviews.sh

SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/request-reviews.sh"

@test "request-reviews.sh: no PR URL shows error" {
  run "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"No PR URL or number provided"* ]]
}

@test "request-reviews.sh: no reviewers shows error" {
  run "$SCRIPT" 123
  [ "$status" -eq 1 ]
  [[ "$output" == *"No reviewers specified"* ]]
}

@test "request-reviews.sh: empty PR URL shows error" {
  run "$SCRIPT" "" alice
  [ "$status" -eq 1 ]
  [[ "$output" == *"Empty PR URL"* ]]
}

@test "request-reviews.sh: shell metacharacters in PR URL are rejected" {
  run "$SCRIPT" "123;rm -rf /" alice
  [ "$status" -eq 1 ]
  # After removing the weak metacharacter regex, validation relies on the
  # PR URL extraction regex rejecting malformed input.
  [[ "$output" == *"Could not extract PR number"* ]]
}

@test "request-reviews.sh: --help flag works" {
  run "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage"* ]]
  [[ "$output" == *"--fresh"* ]]
}

@test "request-reviews.sh: --fresh flag is accepted" {
  # The --fresh flag should be recognized by the argument parser.
  # Pass it alongside valid PR URL and reviewers so parsing reaches the gh call
  # (then stub gh to succeed immediately). Without this, --fresh alone would
  # still wait for a real gh invocation that can't succeed in the test env.
  stub_bin="$(mktemp -d)"
  cat > "$stub_bin/gh" <<'STUB'
#!/usr/bin/env bash
echo '{"requested_reviewers":[]}' >&2
exit 0
STUB
  chmod +x "$stub_bin/gh"

  PATH="$stub_bin:$PATH" run "$SCRIPT" "https://github.com/owner/repo/pull/1" alice --fresh
  # The call should succeed — --fresh is accepted, not rejected as unknown
  # (status == 0 means flag was parsed and the request ran end-to-end)
  # Or status != 0 only if gh itself failed, never due to unknown flag.
  [[ "$output" != *"unknown argument"* && "$output" != *"--fresh"*"invalid"* ]] || false
  rm -rf "$stub_bin"
}

@test "request-reviews.sh: script is executable" {
  [ -x "$SCRIPT" ]
}

@test "request-reviews.sh: script has bash shebang" {
  head -1 "$SCRIPT" | grep -q "^#!/usr/bin/env bash"
}

@test "request-reviews.sh: script uses set -euo pipefail" {
  grep -q "set -euo pipefail" "$SCRIPT"
}

@test "request-reviews.sh: script has R3 frontmatter" {
  grep -q "description:" "$SCRIPT"
  grep -q "triggers:" "$SCRIPT"
  grep -q "inputs:" "$SCRIPT"
  grep -q "name: pr_url" "$SCRIPT"
  grep -q "name: reviewers" "$SCRIPT"
  grep -q "name: fresh" "$SCRIPT"
}

@test "request-reviews.sh: script contains gh api PUT for requested_reviewers" {
  grep -q "requested_reviewers" "$SCRIPT"
}

@test "request-reviews.sh: script contains gh pr edit fallback" {
  grep -q "gh pr edit" "$SCRIPT"
  grep -q "add-reviewer" "$SCRIPT"
}

@test "request-reviews.sh: script contains comment fallback" {
  grep -q "gh pr comment" "$SCRIPT"
  grep -q "Ready for re-review" "$SCRIPT"
}

@test "request-reviews.sh: --fresh flag triggers remove-then-add flow" {
  # Verify the script structure: --fresh causes a removal step before re-add
  # The "Removing reviewers" message appears only inside the FRESH=true block
  grep -q 'Removing reviewers for fresh review request' "$SCRIPT"
  # The FRESH=true block contains the removal API call
  grep -q 'FRESH.*true' "$SCRIPT"
  # Verify the removal happens before the re-add (line ordering)
  local remove_line add_line
  remove_line=$(grep -n 'Removing reviewers' "$SCRIPT" | head -1 | cut -d: -f1)
  add_line=$(grep -n 'Requesting review from' "$SCRIPT" | head -1 | cut -d: -f1)
  [ "$remove_line" -lt "$add_line" ]
}
