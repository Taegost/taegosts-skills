#!/usr/bin/env bats

# Test suite for dispatch-standards enforcement logic
# Tests that load-dispatch-standards.sh correctly validates skills against dispatch standards

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

@test "load-dispatch-standards.sh successfully loads the standards" {
    run bash "$SCRIPT_PATH" get_rule bootstrap-only
    [ "$status" -eq 0 ]
    [ -n "$output" ]
}

@test "standards contain a rule about file path dispatch" {
    run bash "$SCRIPT_PATH" get_rule bootstrap-only
    [ "$status" -eq 0 ]
    [[ "$output" == *"file path"* ]]
}

@test "standards contain a rule about no subagent spawning" {
    run bash "$SCRIPT_PATH" get_rule no-subagent-spawning
    [ "$status" -eq 0 ]
    [[ "$output" == *"Agent"* ]]
}

@test "validate_dispatch_invocation correctly identifies a compliant skill" {
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

@test "validate_dispatch_invocation correctly identifies a non-compliant skill with Agent tool" {
    # Create a mock non-compliant skill file with Agent tool usage
    cat > "$TEST_TEMP_DIR/noncompliant-agent.md" << 'EOF'
---
name: bad-skill
description: A skill that uses Agent tool
---

# Bad Skill

This skill spawns subagents directly using the Agent tool.
Agent(subagent_type="reviewer")
EOF

    run bash "$SCRIPT_PATH" validate "$TEST_TEMP_DIR/noncompliant-agent.md"
    [ "$status" -eq 1 ]
    [[ "$output" == *"FAIL"* ]]
}

@test "validate_dispatch_invocation correctly identifies a non-compliant skill with spawn_agent" {
    # Create a mock non-compliant skill file with spawn_agent
    cat > "$TEST_TEMP_DIR/noncompliant-spawn.md" << 'EOF'
---
name: spawn-skill
description: A skill that uses spawn_agent
---

# Spawn Skill

This skill uses spawn_agent to dispatch subagents.
spawn_agent("reviewer", context)
EOF

    run bash "$SCRIPT_PATH" validate "$TEST_TEMP_DIR/noncompliant-spawn.md"
    [ "$status" -eq 1 ]
    [[ "$output" == *"FAIL"* ]]
}

@test "validate_dispatch_invocation correctly identifies a non-compliant skill with subagent_type" {
    # Create a mock non-compliant skill file with subagent_type
    cat > "$TEST_TEMP_DIR/noncompliant-type.md" << 'EOF'
---
name: type-skill
description: A skill that uses subagent_type
---

# Type Skill

This skill uses subagent_type for dispatch.
subagent_type="reviewer"
EOF

    run bash "$SCRIPT_PATH" validate "$TEST_TEMP_DIR/noncompliant-type.md"
    [ "$status" -eq 1 ]
    [[ "$output" == *"FAIL"* ]]
}

@test "validate_dispatch_invocation returns error for missing file" {
    run bash "$SCRIPT_PATH" validate "/nonexistent/path/skill.md"
    [ "$status" -eq 1 ]
    [[ "$output" == *"not found"* ]]
}

@test "standards contain rule about file-path-delegation" {
    run bash "$SCRIPT_PATH" get_rule file-path-delegation
    [ "$status" -eq 0 ]
    [[ "$output" == *"file path"* ]]
}

@test "standards contain rule about script-via-index" {
    run bash "$SCRIPT_PATH" get_rule script-via-index
    [ "$status" -eq 0 ]
    [[ "$output" == *"INDEX.md"* ]]
}

@test "standards contain rule about routing-first" {
    run bash "$SCRIPT_PATH" get_rule routing-first
    [ "$status" -eq 0 ]
    [[ "$output" == *"ROUTING.md"* ]]
}
