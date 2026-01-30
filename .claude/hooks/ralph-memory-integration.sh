#!/bin/bash
# ralph-memory-integration.sh - Integrate Ralph procedural memory with Promptify
# VERSION: 1.0.0
# Phase 3.2: Memory Pattern Integration
# Purpose: Use Ralph's learned patterns to enhance prompt optimization

set -euo pipefail

readonly VERSION="1.0.0"
readonly PROCEDURAL_MEMORY="$HOME/.ralph/procedural/rules.json"
readonly CONFIG_FILE="$HOME/.ralph/config/promptify.json"

# Check if procedural memory exists
procedural_memory_exists() {
    [[ -f "$PROCEDURAL_MEMORY" ]]
}

# Get relevant patterns for a prompt type
get_patterns_for_prompt_type() {
    local prompt="$1"
    local prompt_type="${2:-general}"
    local limit="${3:-5}"

    if ! procedural_memory_exists; then
        echo ""
        return 0
    fi

    # Extract patterns based on category
    local patterns=$(jq -r --arg type "$prompt_type" --argjson limit "$limit" '
        map(select(.category == $type or .category == "general"))
        | sort_by(.confidence // 0) | reverse
        | .[0:.limit]
        | .pattern
        | join("\n")
    ' "$PROCEDURAL_MEMORY" 2>/dev/null || echo "")

    echo "$patterns"
}

# Apply procedural patterns to a prompt
apply_procedural_patterns() {
    local original_prompt="$1"
    local enhanced_prompt="$original_prompt"
    local prompt_type=""

    # Detect prompt type
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

    # Get patterns from procedural memory
    local patterns=$(get_patterns_for_prompt_type "$original_prompt" "$prompt_type" 5)

    if [[ -n "$patterns" ]]; then
        # Add patterns as context
        enhanced_prompt="$original_prompt"$'\n\n<procedural_patterns_from_ralph>\n'"$patterns"$'\n</procedural_patterns_from_ralph>'
    fi

    echo "$enhanced_prompt"
}

# Learn pattern from successful prompt
learn_pattern() {
    local pattern="$1"
    local category="${2:-general}"
    local confidence="${3:-80}"

    if ! procedural_memory_exists; then
        mkdir -p "$(dirname "$PROCEDURAL_MEMORY")"
        echo "[]" > "$PROCEDURAL_MEMORY"
    fi

    # Create new pattern entry
    local new_pattern
    new_pattern=$(jq -n \
        --arg pattern "$pattern" \
        --arg category "$category" \
        --argjson confidence "$confidence" \
        --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        '{
          pattern: $pattern,
          category: $category,
          confidence: $confidence,
          timestamp: $timestamp,
          source: "promptify-integration"
        }')

    # Add to procedural memory
    local updated_memory=$(jq ". += [$new_pattern]" "$PROCEDURAL_MEMORY")
    echo "$updated_memory" > "$PROCEDURAL_MEMORY"
}

# Auto-learn from successful executions
auto_learn_from_success() {
    local optimized_prompt="$1"
    local execution_result="${2:-success}"

    # Only learn if execution was successful
    if [[ "$execution_result" != "success" ]]; then
        return 0
    fi

    # Extract pattern from optimized prompt (simplified)
    # This is a placeholder - real implementation would use more sophisticated extraction
    local pattern="$optimized_prompt"

    # Learn with medium confidence
    learn_pattern "$pattern" "general" 70
}

# Get memory statistics
get_memory_stats() {
    if ! procedural_memory_exists; then
        echo '{"total_patterns": 0, "categories": {}}'
        return 0
    fi

    jq '{
        total_patterns: length,
        categories: map(group_by(.category) | {category: .[0].category, count: length})
    }' "$PROCEDURAL_MEMORY"
}

# Export functions
export -f procedural_memory_exists
export -f get_patterns_for_prompt_type
export -f apply_procedural_patterns
export -f learn_pattern
export -f auto_learn_from_success
export -f get_memory_stats

# Test function
test_memory_integration() {
    echo "Testing Ralph Memory Integration..."
    echo ""

    if procedural_memory_exists; then
        echo "✅ Procedural memory exists"
    else
        echo "⚠️  Procedural memory not found (will be created on first learn)"
    fi

    echo ""
    echo "Memory Statistics:"
    get_memory_stats
}

# If executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    test_memory_integration
fi
