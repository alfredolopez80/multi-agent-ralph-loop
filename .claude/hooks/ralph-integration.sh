#!/bin/bash
# ralph-integration.sh - Main Ralph integration script for Promptify
# VERSION: 1.0.0
# Phase 3: Complete Ralph Integration
# Purpose: Coordinate context injection, memory patterns, and quality gates

set -euo pipefail

readonly VERSION="1.0.0"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
readonly CONFIG_FILE="$HOME/.ralph/config/promptify.json"

# Source integration components
source "${SCRIPT_DIR}/ralph-context-injector.sh" 2>/dev/null || true
source "${SCRIPT_DIR}/ralph-memory-integration.sh" 2>/dev/null || true
source "${SCRIPT_DIR}/ralph-quality-gates.sh" 2>/dev/null || true

# Get configuration value
get_config() {
    local key="$1"
    local default="${2:-true}"

    if [[ -f "$CONFIG_FILE" ]]; then
        jq -r "${key} // \"${default}\"" "$CONFIG_FILE" 2>/dev/null || echo "$default"
    else
        echo "$default"
    fi
}

# Enhance prompt with Ralph context and memory
enhance_prompt_with_ralph() {
    local original_prompt="$1"
    local enhanced_prompt="$original_prompt"

    # Get configuration
    local inject_context=$(get_config '.integration.inject_ralph_context' 'true')
    local use_memory=$(get_config '.integration.use_ralph_memory' 'true')

    # Add Ralph context if enabled
    if [[ "$inject_context" == "true" ]]; then
        local ralph_context=$(get_ralph_context)
        if [[ -n "$ralph_context" ]]; then
            enhanced_prompt="$original_prompt"$'\n\n<ralph_active_context>\n'"$ralph_context"$'\n</ralph_active_context>'
        fi
    fi

    # Add Ralph memory patterns if enabled
    if [[ "$use_memory" == "true" ]]; then
        # Detect prompt type
        local prompt_type=""
        local prompt_lower=$(echo "$original_prompt" | tr '[:upper:]' '[:lower:]')

        if echo "$prompt_lower" | grep -qE "(implement|create|build|add|write)"; then
            prompt_type="implementation"
        elif echo "$prompt_lower" | grep -qE "(fix|debug|error|issue|fail)"; then
            prompt_type="debugging"
        elif echo "$prompt_lower" | grep -qE "(test|spec|validate|check)"; then
            prompt_type="testing"
        elif echo "$prompt_lower" | grep -qE "(refactor|improve|optimize|clean)"; then
            prompt_type="refactoring"
        else
            prompt_type="general"
        fi

        local enhanced_with_memory=$(apply_procedural_patterns "$enhanced_prompt" "$prompt_type")
        if [[ "$enhanced_with_memory" != "$enhanced_prompt" ]]; then
            enhanced_prompt="$enhanced_with_memory"
        fi
    fi

    echo "$enhanced_prompt"
}

# Validate enhanced prompt through quality gates
validate_enhanced_prompt() {
    local prompt="$1"
    local clarity_score="${2:-50}"
    local use_gates=$(get_config '.integration.validate_with_quality_gates' 'true')

    if [[ "$use_gates" != "true" ]]; then
        jq -n '{valid: true, score: '"$clarity_score"', reason: "Quality gates disabled"}'
        return 0
    fi

    # Detect prompt type for validation
    local prompt_type="general"
    local prompt_lower=$(echo "$prompt" | tr '[:upper:]' '[:lower:]')

    if echo "$prompt_lower" | grep -qE "(implement|create|build|add|write)"; then
        prompt_type="implementation"
    elif echo "$prompt_lower" | grep -qE "(fix|debug|error|issue|fail)"; then
        prompt_type="debugging"
    elif echo "$prompt_lower" | grep -qE "(test|spec|validate|check)"; then
        prompt_type="testing"
    elif echo "$prompt_lower" | grep -qE "(refactor|improve|optimize|clean)"; then
        prompt_type="refactoring"
    fi

    validate_with_gates "$prompt" "$prompt_type" "$clarity_score"
}

# Main enhancement function
enhance_and_validate() {
    local original_prompt="$1"
    local clarity_score="${2:-50}"

    # Step 1: Enhance with Ralph context and memory
    local enhanced_prompt=$(enhance_prompt_with_ralph "$original_prompt")

    # Step 2: Validate through quality gates
    local validation_result=$(validate_enhanced_prompt "$enhanced_prompt" "$clarity_score")

    # Return combined result
    jq -n \
        --arg original "$original_prompt" \
        --arg enhanced "$enhanced_prompt" \
        --argjson validation "$validation_result" \
        '{
            original_prompt: $original,
            enhanced_prompt: $enhanced,
            validation: $validation
        }'
}

# Export functions
export -f get_config
export -f enhance_prompt_with_ralph
export -f validate_enhanced_prompt
export -f enhance_and_validate

# Test function
test_ralph_integration() {
    echo "Ralph Integration Test v${VERSION}"
    echo "================================"
    echo ""

    echo "Configuration:"
    echo "  - Inject context: $(get_config '.integration.inject_ralph_context')"
    echo "  - Use memory: $(get_config '.integration.use_ralph_memory')"
    echo "  - Use quality gates: $(get_config '.integration.validate_with_quality_gates')"
    echo ""

    echo "Testing enhancement..."
    local test_prompt="Implement user authentication"
    local result=$(enhance_and_validate "$test_prompt" 60)

    echo ""
    echo "Result:"
    echo "$result" | jq '.'
}

# If executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Check for quiet mode (for testing)
    if [[ "${1:-}" == "--quiet" ]]; then
        # Output JSON only
        test_prompt="Implement user authentication"
        result=$(enhance_and_validate "$test_prompt" 60)
        echo "$result"
    else
        test_ralph_integration
    fi
fi
