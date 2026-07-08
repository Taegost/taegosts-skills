#!/usr/bin/env bats
# tests/scripts/test-git-context.bats
# Tests for scripts/git-context.sh — verifies JSON output contains
# the same information as the inline context blocks in ts-commit and ts-commit-push-pr.

SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/git-context.sh"

setup() {
  # Ensure we run from the repo root for consistent git state
  cd "$REPO_ROOT"
}

@test "git-context.sh: exits 0 in a git repo" {
  run "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "git-context.sh: output is valid JSON" {
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -m json.tool > /dev/null 2>&1
}

@test "git-context.sh: JSON contains current_branch field" {
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert 'current_branch' in d"
}

@test "git-context.sh: JSON contains default_branch field" {
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert 'default_branch' in d"
}

@test "git-context.sh: JSON contains dirty_files field" {
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert 'dirty_files' in d"
}

@test "git-context.sh: JSON contains staged_files field" {
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert 'staged_files' in d"
}

@test "git-context.sh: JSON contains recent_commits field" {
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert 'recent_commits' in d"
}

@test "git-context.sh: default_branch is a valid branch name" {
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  default_branch=$(echo "$output" | python3 -c "import json,sys; print(json.load(sys.stdin)['default_branch'])")
  # Must be one of the common default branch names or a reasonable value
  [[ "$default_branch" =~ ^(main|master|develop|trunk|unknown)$ ]]
}

@test "git-context.sh: current_branch matches git rev-parse" {
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  actual_branch=$(git symbolic-ref --short HEAD 2>/dev/null || echo "HEAD")
  json_branch=$(echo "$output" | python3 -c "import json,sys; print(json.load(sys.stdin)['current_branch'])")
  [ "$json_branch" = "$actual_branch" ]
}

@test "git-context.sh: is_detached is a boolean" {
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert isinstance(d['is_detached'], bool)"
}

@test "git-context.sh: dirty_files is a list" {
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert isinstance(d['dirty_files'], list)"
}

@test "git-context.sh: staged_files is a list" {
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert isinstance(d['staged_files'], list)"
}

@test "git-context.sh: recent_commits is a list" {
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert isinstance(d['recent_commits'], list)"
}

@test "git-context.sh: has_unpushed is a boolean" {
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert isinstance(d['has_unpushed'], bool)"
}

@test "git-context.sh: repo_root is an absolute path" {
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  repo_root=$(echo "$output" | python3 -c "import json,sys; print(json.load(sys.stdin)['repo_root'])")
  [[ "$repo_root" == /* ]]
}

@test "git-context.sh: exits 1 outside a git repo" {
  tmpdir=$(mktemp -d)
  cd "$tmpdir"
  run "$SCRIPT"
  [ "$status" -eq 1 ]
  rm -rf "$tmpdir"
}

@test "git-context.sh: --help flag works" {
  run "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage"* ]]
}
