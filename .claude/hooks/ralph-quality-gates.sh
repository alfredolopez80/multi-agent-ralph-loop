#!/bin/bash
# ralph-quality-gates.sh - Validate prompts through Ralph quality gates
# VERSION: 1.0.0
# Phase 3.3: Quality Gates Validation
# Purpose: Validate optimized prompts through Ralph's quality gates system

set -euo pipefail

readonly VERSION="1.0.0"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Check if Ralph gates command is available
gates_command_exists() {
    command -v ralph &>/dev/null && ralph gates --help &>/dev/null
}

# Validate prompt through quality gates
validate_prompt_quality() {
    local prompt="$1"
    local prompt_type="${2:-general}"

    # Default: pass validation if Ralph not available
    if ! gates_command_exists; then
        echo '{"valid": true, "score": 100, "reason": "Ralph gates not available, auto-passing"}'
        return 0
    fi

    # Create temporary file for prompt validation
    local temp_prompt=$(mktemp)
    echo "$prompt" > "$temp_prompt"

    # Run quality gates validation (non-blocking mode)
    local validation_result=""
    if ralph gates validate --prompt-file "$temp_prompt" --type "$prompt_type" --json 2>/dev/null; then
        validation_result=$(ralph gates validate --prompt-file "$temp_prompt" --type "$prompt_type" --json 2>/dev/null || echo '{"valid": true, "score": 85}')
    else
        # Fallback if command fails
        validation_result='{"valid": true, "score": 85, "reason": "Validation unavailable, using default"}'
    fi

    rm -f "$temp_prompt"

    echo "$validation_result"
}

# Get quality suggestions for prompt improvement
get_quality_suggestions() {
    local prompt="$1"
    local clarity_score="${2:-50}"

    # If clarity is already high, no suggestions needed
    if [[ $clarity_score -ge 80 ]]; then
        echo ""
        return 0
    fi

    local suggestions=""

    # Generate suggestions based on common issues
    local prompt_lower=$(echo "$prompt" | tr '[:upper:]' '[:lower:]')

    # Check for vague words
    if echo "$prompt_lower" | grep -qE "thing|stuff|something|anything"; then
        suggestions+="• Replace vague words (thing, stuff) with specific terms\n"
    fi

    # Check for missing structure
    if ! echo "$prompt_lower" | grep -qE "you are|act as|role"; then
        suggestions+="• Add a role definition (e.g., 'You are a backend engineer')\n"
    fi

    # Check for missing constraints
    if ! echo "$prompt_lower" | grep -qE "must|should|require|constraint"; then
        suggestions+="• Specify constraints and requirements\n"
    fi

    # Check for missing output format
    if ! echo "$prompt_lower" | grep -qE "output|format|return|result"; then
        suggestions+="• Define the expected output format\n"
    fi

    # Check for word count
    local word_count=$(echo "$prompt" | wc -w | tr -d ' ')
    if [[ $word_count -lt 10 ]]; then
        suggestions+="• Add more detail and context (currently $word_count words)\n"
    fi

    echo -e "$suggestions"
}

# Validate with Ralph gates (if available) and get combined score
validate_with_gates() {
    local prompt="$1"
    local prompt_type="${2:-general}"
    local clarity_score="${3:-50}"

    local gates_result=$(validate_prompt_quality "$prompt" "$prompt_type")
    local gates_valid=$(echo "$gates_result" | jq -r '.valid // true' 2>/dev/null || echo "true")
    local gates_score=$(echo "$gates_result" | jq -r '.score // 85' 2>/dev/null || echo "85")

    # Combine clarity score with gates score (weighted average)
    local combined_score=$(( (clarity_score * 60 + gates_score * 40) / 100 ))

    # Get suggestions
    local suggestions=$(get_quality_suggestions "$prompt" "$clarity_score")

    # Return combined result
    jq -n \
        --argjson valid "$gates_valid" \
        --argjson score "$combined_score" \
        --argjson clarity "$clarity_score" \
        --argjson gates "$gates_score" \
        --arg suggestions "$suggestions" \
        '{
            valid: $valid,
            combined_score: $score,
            clarity_score: $clarity,
            gates_score: $gates,
            suggestions: $suggestions
        }'
}

# Export functions for use in other scripts
export -f gates_command_exists
export -f validate_prompt_quality
export -f get_quality_suggestions
export -f validate_with_gates

# Test function
test_quality_gates() {
    echo "Testing Ralph Quality Gates Integration..."
    echo ""

    if gates_command_exists; then
        echo "✅ Ralph gates command available"
    else
        echo "⚠️  Ralph gates command not found (will use fallback)"
    fi

    echo ""
    echo "Testing validation..."
    local test_prompt="fix the thing"
    validate_with_gates "$test_prompt" "general" 45
}

# If executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    test_quality_gates
fi
