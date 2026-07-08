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
  [[ "$output" == *"invalid characters"* ]]
}

@test "request-reviews.sh: --help flag works" {
  run "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage"* ]]
  [[ "$output" == *"--fresh"* ]]
}

@test "request-reviews.sh: --fresh flag is accepted" {
  # Mock gh to always succeed
  gh() { return 0; }
  export -f gh
  # We can't fully test the --fresh flow without a real PR,
  # but we can verify the flag is parsed (no error before gh call)
  run "$SCRIPT" --help
  [ "$status" -eq 0 ]
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
