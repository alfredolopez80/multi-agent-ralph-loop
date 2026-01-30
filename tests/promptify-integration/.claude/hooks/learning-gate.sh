#!/usr/bin/env bash
# learning-gate.sh - Auto-execute /curator when learning is critical
# Version 1.0.0 - v2.81.2 Implementation
# Part of Ralph Multi-Agent System
#
# CRITICAL HOOK for automatic learning integration
# Triggers: PreToolUse (Task)
# Purpose: Auto-execute /curator when procedural memory is empty
#
# Activation Conditions:
#  1. Task complexity >= 3 (medium+ complexity tasks need quality rules)
#  2. learning_state.is_critical == true (ZERO relevant rules)
#  3. NOT running in plan mode (avoid recursive triggers)
#
# Behavior:
#  - Recommend /curator execution with specific context
#  - Block execution if learning is critical (force learning first)
#  - Enable automatic learning integration

set -euo pipefail

VERSION="1.0.0"
RALPH_DIR="${HOME}/.ralph"
PROCEDURAL_RULES="${RALPH_DIR}/procedural/rules.json"
LEARNING_STATE="${RALPH_DIR}/learning/state.json"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${CYAN}[learning-gate]${NC} $1" >&2; }
log_warning() { echo -e "${YELLOW}[learning-gate]${NC} $1" >&2; }
log_error() { echo -e "${RED}[learning-gate]${NC} $1" >&2; }
log_success() { echo -e "${GREEN}[learning-gate]${NC} $1" >&2; }

# Check if learning is critical
check_learning_critical() {
    local complexity="${1:-0}"
    local task_context="${2:-}"

    # Skip if complexity too low
    if [ "$complexity" -lt 3 ]; then
        return 1  # Not critical
    fi

    # Check if rules.json exists
    if [ ! -f "$PROCEDURAL_RULES" ]; then
        log_warning "Procedural rules not found (first run?)"
        return 0  # Critical - no rules exist
    fi

    # Count relevant rules based on task context
    local relevant_count=0

    if [ -n "$task_context" ]; then
        # Count rules with matching domain or keywords
        relevant_count=$(jq -r --arg context "$task_context" '
            [.rules[] |
             select(
                 (.domain // "" | test($context; "i")) or
                 (.keywords // [] | map(. == $context)) | any
             )] | length
        ' "$PROCEDURAL_RULES" 2>/dev/null || echo "0")
    else
        # No specific context - check total count
        relevant_count=$(jq '.rules | length' "$PROCEDURAL_RULES" 2>/dev/null || echo "0")
    fi

    # Critical if ZERO relevant rules for medium+ complexity
    if [ "$relevant_count" -eq 0 ]; then
        return 0  # Critical
    fi

    return 1  # Not critical
}

# Extract task complexity from stdin
extract_complexity() {
    local stdin_data="$1"

    # Try to extract complexity from toolInput
    echo "$stdin_data" | jq -r '.toolInput.complexity // .toolInput.model // 0' 2>/dev/null || echo "0"
}

# Extract task context from stdin
extract_task_context() {
    local stdin_data="$1"

    # Try to extract task description
    local task
    task=$(echo "$stdin_data" | jq -r '.toolInput.prompt // .toolInput.task // ""' 2>/dev/null || echo "")

    if [ -z "$task" ]; then
        # Try to extract from subagent type
        task=$(echo "$stdin_data" | jq -r '.toolInput.subagent_type // ""' 2>/dev/null || echo "")
    fi

    echo "$task"
}

# Main hook logic
main() {
    # Read stdin
    local stdin_data
    stdin_data=$(cat)

    # Only process Task tool invocations
    local tool_name
    tool_name=$(echo "$stdin_data" | jq -r '.toolName // ""' 2>/dev/null || echo "")

    if [ "$tool_name" != "Task" ]; then
        # Return allow decision for non-Task tools
        echo '{"decision": "allow"}'
        return 0
    fi

    # Extract complexity and context
    local complexity
    local task_context

    complexity=$(extract_complexity "$stdin_data")
    task_context=$(extract_task_context "$stdin_data")

    log_info "Checking learning gate (complexity: $complexity)"

    # Check if learning is critical
    if check_learning_critical "$complexity" "$task_context"; then
        log_warning "Learning is CRITICAL - No relevant rules found for complexity $complexity task"

        # Build curator recommendation
        local curator_cmd="/curator"

        # Suggest specific curator type based on context
        if [ -n "$task_context" ]; then
            # Extract keywords from task context
            local suggested_type="backend"

            if echo "$task_context" | grep -qiE "frontend|ui|component|spa|react|vue"; then
                suggested_type="frontend"
            elif echo "$task_context" | grep -qiE "fullstack|full-stack"; then
                suggested_type="fullstack"
            elif echo "$task_context" | grep -qiE "library|sdk|toolkit"; then
                suggested_type="library"
            elif echo "$task_context" | grep -qiE "framework|framework"; then
                suggested_type="framework"
            fi

            curator_cmd="${curator_cmd} discovery --type ${suggested_type} --lang typescript"

            log_warning "Recommended: ${curator_cmd}"
        fi

        # Return decision with context
        cat >&2 << LEARNING_RECOMMENDATION

╔════════════════════════════════════════════════════════════════╗
║         🔴 LEARNING GATE: CRITICAL KNOWLEDGE GAP              ║
╚════════════════════════════════════════════════════════════════╝

Task Complexity: $complexity
Relevant Rules: 0
Status: CRITICAL - No quality patterns available

RECOMMENDED ACTION:
  $curator_cmd

This will:
  1. Discover quality repositories for this task type
  2. Extract best practices and patterns
  3. Generate procedural rules for future use

ALTERNATIVE: Proceed with current knowledge (lower quality expected)

LEARNING_RECOMMENDATION

        # Block execution for critical complexity (>=7)
        if [ "$complexity" -ge 7 ]; then
            log_error "BLOCKING execution - Learning REQUIRED for complexity $complexity"
            echo '{"decision": "block", "reason": "No relevant rules for high-complexity task. Please run /curator first."}' >&2
            return 1
        fi

        # Warn but allow for medium complexity (3-6)
        log_warning "Allowing execution with warning - Quality may be suboptimal"
        echo '{"decision": "allow", "warning": "No relevant rules found. Consider running /curator for better quality."}'
        return 0
    fi

    # Learning not critical - allow execution
    log_success "Learning check passed - Relevant rules available"
    echo '{"decision": "allow"}'
    return 0
}

main "$@"
