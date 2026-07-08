#!/usr/bin/env bash
# load-dispatch-standards.sh -- Sourceable validation library for dispatch pattern standards
#
# PURPOSE:
#   This is a sourceable validation library, not a standalone script.
#   It provides functions to load dispatch standards and validate skills
#   against required patterns (DS-002: no-subagent-spawning).
#
# INPUTS:
#   get_rule <id>                    - Fetch a specific dispatch rule by ID
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

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo "${REPO_ROOT:-.}")"
STANDARDS_FILE="${REPO_ROOT}/docs/standards/dispatch-standards.md"

# Validate that the standards file exists
_validate_standards_file() {
    if [[ ! -f "$STANDARDS_FILE" ]]; then
        echo "ERROR: Dispatch standards file not found: $STANDARDS_FILE" >&2
        return 1
    fi
}

# Get a specific rule by ID (e.g., "bootstrap-only", "no-subagent-spawning")
get_dispatch_rule() {
    local rule_id="$1"
    _validate_standards_file || return 1

    # Extract the rule section between ### DS-NNN: <rule-id> and the next ### or ##
    local in_rule=0
    local rule_text=""

    while IFS= read -r line; do
        # Check if we're entering the target rule section
        if [[ "$line" =~ ^###\ DS-[0-9]+:\ ${rule_id}$ ]]; then
            in_rule=1
            continue
        fi

        # Check if we're leaving the rule section (next heading at same or higher level)
        if [[ $in_rule -eq 1 ]] && [[ "$line" =~ ^##[#]?\  ]]; then
            break
        fi

        # Collect rule text
        if [[ $in_rule -eq 1 ]]; then
            rule_text+="${line}"$'\n'
        fi
    done < "$STANDARDS_FILE"

    if [[ -z "$rule_text" ]]; then
        echo "ERROR: Rule '$rule_id' not found in dispatch standards" >&2
        return 1
    fi

    echo "$rule_text"
}

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

    case "$action" in
        get_rule)
            local rule_id="${2:-}"
            if [[ -z "$rule_id" ]]; then
                echo "Usage: $0 get_rule <rule-id>" >&2
                return 1
            fi
            get_dispatch_rule "$rule_id"
            ;;
        validate)
            local skill_path="${2:-}"
            if [[ -z "$skill_path" ]]; then
                echo "Usage: $0 validate <skill-path>" >&2
                return 1
            fi
            validate_dispatch_invocation "$skill_path"
            ;;
        *)
            echo "Usage: $0 {get_rule <id> | validate <skill-path>}" >&2
            return 1
            ;;
    esac
}

# Only run main if not being sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
