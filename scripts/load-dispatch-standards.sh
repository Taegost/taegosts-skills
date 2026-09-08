#!/usr/bin/env bash
# load-dispatch-standards.sh -- Sourceable validation library for dispatch pattern standards
#
# PURPOSE:
#   This is a sourceable validation library, not a standalone script.
#   It validates skill files against required dispatch patterns
#   (DS-002: no-subagent-spawning).
#
# INPUTS:
#   validate <skill-path>            - Validate a skill file follows dispatch patterns
#
# PRIMARY CONSUMERS:
#   - tests/scripts/test-load-dispatch-standards.bats
#   - tests/scripts/test-dispatch-standards-enforcement.bats
#   - Future CI/dispatch validation tooling
#
# USAGE:
#   source "$(dirname "$0")/load-dispatch-standards.sh"
#   validate_dispatch_invocation "skills/ts-work/SKILL.md"

set -euo pipefail

# Validate whether a skill file follows the bootstrap dispatch pattern
validate_dispatch_invocation() {
    local skill_path="$1"

    if [[ ! -f "$skill_path" ]]; then
        echo "ERROR: Skill file not found: $skill_path" >&2
        return 1
    fi

    local violations=0
    local violation_messages=()

    # Check for prohibited patterns (DS-002: no-subagent-spawning)
    # Exclude documentation/examples/references — only flag actual dispatch logic
    local has_prohibited=false
    if grep -qiE '(Agent\s*\(|spawn_agent|subagent_type)' "$skill_path" 2>/dev/null; then
        # Check if it's documentation/example/reference (not actual dispatch)
        if ! grep -qiE '(example|documentation|reference|legacy|deprecated|comment|inline)' "$skill_path" 2>/dev/null; then
            # Additional check: ensure it's not in a comment or docstring context
            # Look for actual code lines (not starting with # or in heredocs)
            if grep -E '^[^#]*\b(Agent\s*\(|spawn_agent|subagent_type)' "$skill_path" 2>/dev/null | grep -qvE '(#|```|<!--)'; then
                has_prohibited=true
            fi
        fi
    fi

    if [[ "$has_prohibited" == "true" ]]; then
        violations=$((violations + 1))
        violation_messages+=("Contains direct subagent spawning in code (Agent tool, spawn_agent, or subagent_type)")
    fi

    # Check for model selection logic for subagents
    # Exclude documentation/examples/references — only flag actual dispatch logic
    local has_model_logic=false
    if grep -qiE '(model.*haiku|model.*sonnet|model.*opus|subagent.*model)' "$skill_path" 2>/dev/null; then
        # Check if it's documentation/example/reference (not actual dispatch)
        if ! grep -qiE '(example|documentation|reference|legacy|deprecated|comment|inline)' "$skill_path" 2>/dev/null; then
            # Additional check: ensure it's not in a comment or docstring context
            if grep -E '^[^#]*\bmodel.*haiku' "$skill_path" 2>/dev/null | grep -qvE '(#|```|<!--)'; then
                has_model_logic=true
            elif grep -E '^[^#]*\bsubagent.*model' "$skill_path" 2>/dev/null | grep -qvE '(#|```|<!--)'; then
                has_model_logic=true
            fi
        fi
    fi

    if [[ "$has_model_logic" == "true" ]]; then
        violations=$((violations + 1))
        violation_messages+=("Contains model selection logic in code")
    fi

    # Report results
    if [[ $violations -eq 0 ]]; then
        echo "PASS: $skill_path is dispatch-conformant"
        return 0
    else
        echo "FAIL: $skill_path has $violations dispatch violation(s):"
        for msg in "${violation_messages[@]}"; do
            echo "  - $msg"
        done
        return 1
    fi
}

# Main entry point
main() {
    local action="${1:-}"

    if [[ "$action" == "--help" || "$action" == "-h" ]]; then
        cat <<'EOF'
Usage: load-dispatch-standards.sh validate <skill-path>

Sourceable validation library for dispatch pattern standards. Source it to
get validate_dispatch_invocation(); when invoked directly, it supports:

  validate <skill-path>  Validate a skill file follows dispatch patterns
                         (DS-002: no-subagent-spawning)

Exit codes: 0 (success), 1 (skill file missing or violations found)
EOF
        return 0
    fi

    case "$action" in
        validate)
            local skill_path="${2:-}"
            if [[ -z "$skill_path" ]]; then
                echo "Usage: $0 validate <skill-path>" >&2
                return 1
            fi
            validate_dispatch_invocation "$skill_path"
            ;;
        *)
            echo "Usage: $0 validate <skill-path>" >&2
            return 1
            ;;
    esac
}

# Only run main if not being sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
