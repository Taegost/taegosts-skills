#!/usr/bin/env bats

# Test suite for scripts/load-dispatch-standards.sh

setup() {
    REPO_ROOT="$(git rev-parse --show-toplevel)"
    SCRIPT_PATH="${REPO_ROOT}/scripts/load-dispatch-standards.sh"
    STANDARDS_FILE="${REPO_ROOT}/docs/standards/dispatch-standards.md"

    # Create a temporary directory for mock skill files
    export TEST_TEMP_DIR="$(mktemp -d)"
}

teardown() {
    # Clean up temporary directory
    rm -rf "$TEST_TEMP_DIR"
}

@test "script is executable" {
    [ -x "$SCRIPT_PATH" ]
}

@test "script has description in header comment" {
    # R3 frontmatter format: line 2 is "# name -- description"
    grep -q 'load-dispatch-standards.sh -- Sourceable validation library' "$SCRIPT_PATH"
}

@test "script documents inputs in header comment" {
    # Inputs are documented in the PURPOSE/INPUTS block of the header
    grep -q 'INPUTS:' "$SCRIPT_PATH"
    grep -q 'get_rule <id>' "$SCRIPT_PATH"
    grep -q 'validate <skill-path>' "$SCRIPT_PATH"
}

@test "get_dispatch_rule returns text for bootstrap-only rule" {
    run bash "$SCRIPT_PATH" get_rule bootstrap-only
    [ "$status" -eq 0 ]
    [[ "$output" == *"file path"* ]]
}

@test "get_dispatch_rule returns text for no-subagent-spawning rule" {
    run bash "$SCRIPT_PATH" get_rule no-subagent-spawning
    [ "$status" -eq 0 ]
    [[ "$output" == *"Agent"* ]]
}

@test "get_dispatch_rule returns error for unknown rule" {
    run bash "$SCRIPT_PATH" get_rule nonexistent-rule
    [ "$status" -eq 1 ]
    [[ "$output" == *"not found"* ]]
}

@test "validate_dispatch_invocation succeeds for compliant skill" {
    # Create a mock compliant skill file
    cat > "$TEST_TEMP_DIR/compliant-skill.md" << 'EOF'
---
name: test-skill
description: A test skill
---

# Test Skill

This skill delegates to other skills by loading them via file paths.
The skill file path is the single source of truth — load, don't re-derive.
Bootstrap pattern: load skill → execute → return result.
EOF

    run bash "$SCRIPT_PATH" validate "$TEST_TEMP_DIR/compliant-skill.md"
    [ "$status" -eq 0 ]
    [[ "$output" == *"PASS"* ]]
}

@test "validate_dispatch_invocation fails for skill with Agent tool usage" {
    # Create a mock non-compliant skill file with Agent tool usage
    cat > "$TEST_TEMP_DIR/noncompliant-skill.md" << 'EOF'
---
name: bad-skill
description: A skill that uses Agent tool
---

# Bad Skill

This skill spawns subagents directly using the Agent tool.
Agent(subagent_type="reviewer")
EOF

    run bash "$SCRIPT_PATH" validate "$TEST_TEMP_DIR/noncompliant-skill.md"
    [ "$status" -eq 1 ]
    [[ "$output" == *"FAIL"* ]]
}

@test "validate_dispatch_invocation fails for skill with spawn_agent" {
    # Create a mock non-compliant skill file with spawn_agent
    cat > "$TEST_TEMP_DIR/spawn-skill.md" << 'EOF'
---
name: spawn-skill
description: A skill that uses spawn_agent
---

# Spawn Skill

This skill uses spawn_agent to dispatch subagents.
spawn_agent("reviewer", context)
EOF

    run bash "$SCRIPT_PATH" validate "$TEST_TEMP_DIR/spawn-skill.md"
    [ "$status" -eq 1 ]
    [[ "$output" == *"FAIL"* ]]
}

@test "validate_dispatch_invocation returns error for missing file" {
    run bash "$SCRIPT_PATH" validate "/nonexistent/path/skill.md"
    [ "$status" -eq 1 ]
    [[ "$output" == *"not found"* ]]
}

@test "no arguments shows usage" {
    run bash "$SCRIPT_PATH"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Usage"* ]]
}
