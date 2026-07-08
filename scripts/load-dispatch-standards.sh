#!/usr/bin/env bash
# ---
# description: "Load and query dispatch standards from standards/dispatch-standards.md"
# triggers: []
# inputs:
#   - name: action
#     type: string
#     description: "get_rule <id> | validate <skill-path>"
# ---

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
    if grep -qiE '(Agent\s*\(|spawn_agent|subagent_type)' "$skill_path" 2>/dev/null; then
        violations=$((violations + 1))
        violation_messages+=("Contains direct subagent spawning (Agent tool, spawn_agent, or subagent_type)")
    fi

    # Check for model selection logic for subagents
    if grep -qiE '(model.*haiku|model.*sonnet|model.*opus|subagent.*model)' "$skill_path" 2>/dev/null; then
        # Exclude references that are documentation/examples, not dispatch logic
        if ! grep -qiE '(example|documentation|reference|legacy|deprecated)' "$skill_path" 2>/dev/null; then
            violations=$((violations + 1))
            violation_messages+=("Contains model selection logic for subagents")
        fi
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
