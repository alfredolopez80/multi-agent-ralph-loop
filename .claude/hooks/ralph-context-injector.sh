#!/bin/bash
# ralph-context-injector.sh - Inject Ralph context into Promptify
# VERSION: 1.0.0
# Phase 3.1: Ralph Context Injection
# Purpose: Enhance promptify with Ralph's active context and memory

set -euo pipefail

readonly VERSION="1.0.0"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Check if we're in a Ralph project
is_ralph_project() {
    # Check for Ralph indicators
    if [[ -f ".claude/plan-state.json" ]]; then
        return 0
    fi

    if command -v ralph &>/dev/null; then
        # Try to get Ralph status
        if ralph status --compact &>/dev/null; then
            return 0
        fi
    fi

    return 1
}

# Get Ralph context (active context)
get_ralph_context() {
    local context=""

    # Check if ralph command is available
    if ! command -v ralph &>/dev/null; then
        echo ""
        return 0
    fi

    # Try to get Ralph context
    if ralph context show &>/dev/null; then
        context=$(ralph context show 2>/dev/null || echo "")
    fi

    echo "$context"
}

# Get Ralph memory (recent patterns)
get_ralph_memory() {
    local query="${1:-recent patterns}"
    local memory=""

    # Check if ralph command is available
    if ! command -v ralph &>/dev/null; then
        echo ""
        return 0
    fi

    # Try to search memory
    if ralph memory-search "$query" --limit 5 2>/dev/null; then
        memory=$(ralph memory-search "$query" --limit 5 --format json 2>/dev/null || echo "{}")
    fi

    echo "$memory"
}

# Build context block for promptify
build_context_block() {
    local include_ralph_context="${1:-true}"
    local include_ralph_memory="${2:-true}"

    local context_block=""

    # Add Ralph context if available and requested
    if [[ "$include_ralph_context" == "true" ]] && is_ralph_project; then
        local ralph_context=$(get_ralph_context)

        if [[ -n "$ralph_context" ]]; then
            context_block+="<ralph_context>
$ralph_context
</ralph_context>

"
        fi
    fi

    # Add Ralph memory if available and requested
    if [[ "$include_ralph_memory" == "true" ]] && is_ralph_project; then
        local ralph_memory=$(get_ralph_memory "prompt patterns")

        if [[ -n "$ralph_memory" ]] && [[ "$ralph_memory" != "{}" ]]; then
            # Extract patterns from JSON
            local patterns=$(echo "$ralph_memory" | jq -r '.[] | .pattern' 2>/dev/null || echo "")

            if [[ -n "$patterns" ]]; then
                context_block+="<ralph_memory_patterns>
$patterns
</ralph_memory_patterns>

"
            fi
        fi
    fi

    echo "$context_block"
}

# Main context getter
get_enhanced_context() {
    local user_prompt="$1"

    # Default: just return empty (no enhancement)
    echo ""

    # Check if Ralph integration is enabled in config
    local config_file="$HOME/.ralph/config/promptify.json"
    if [[ -f "$config_file" ]]; then
        local inject_context=$(jq -r '.integration.inject_ralph_context // true' "$config_file" 2>/dev/null || echo "true")
        local use_memory=$(jq -r '.integration.use_ralph_memory // true' "$config_file" 2>/dev/null || echo "true")

        if [[ "$inject_context" == "true" ]] || [[ "$use_memory" == "true" ]]; then
            build_context_block "$inject_context" "$use_memory"
        fi
    fi
}

# Export function for use in other scripts
export -f is_ralph_project
export -f get_ralph_context
export -f get_ralph_memory
export -f build_context_block
export -f get_enhanced_context

# If executed directly, show context
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Ralph Context Injector v${VERSION}"
    echo ""
    echo "Testing Ralph integration..."

    if is_ralph_project; then
        echo "✅ Ralph project detected"
    else
        echo "⚠️  Not in a Ralph project"
    fi

    echo ""
    echo "Current Ralph Context:"
    get_ralph_context

    echo ""
    echo "Ralph Memory (recent patterns):"
    get_ralph_memory "prompt patterns"
fi
