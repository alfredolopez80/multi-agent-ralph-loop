#!/bin/bash
# statusline-ralph-debug.sh - Debug version with logging
# VERSION: 2.75.1-debug

# Source all functions from original script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${HOME}/ralph-statusline-debug.log"

# Read stdin
stdin_data=$(cat)

# Debug logging
log_debug() {
    echo "[$(date '+%H:%M:%S')] $*" >> "$LOG_FILE"
}

log_debug "=== Statusline Called ==="
log_debug "Context window data:"
echo "$stdin_data" | jq '.context_window' >> "$LOG_FILE" 2>&1

# Extract context info
context_info=$(echo "$stdin_data" | jq -r '.context_window // "{}"' 2>/dev/null)

log_debug "Extracted context_info: $context_info"

# Test each field
log_debug "Testing fields:"
USED_PCT=$(echo "$context_info" | jq -r '.used_percentage // "NULL"')
CURR_USAGE=$(echo "$context_info" | jq -r '.current_usage // "NULL"')
TOTAL_IN=$(echo "$context_info" | jq -r '.total_input_tokens // "NULL"')
TOTAL_OUT=$(echo "$context_info" | jq -r '.total_output_tokens // "NULL"')
CTX_SIZE=$(echo "$context_info" | jq -r '.context_window_size // "NULL"')

log_debug "  used_percentage: $USED_PCT"
log_debug "  current_usage: $CURR_USAGE"
log_debug "  total_input_tokens: $TOTAL_IN"
log_debug "  total_output_tokens: $TOTAL_OUT"
log_debug "  context_window_size: $CTX_SIZE"

# Calculate context_usage
context_usage=""

# Try current_usage first
if [[ "$CURR_USAGE" != "NULL" ]] && [[ "$CURR_USAGE" != "null" ]]; then
    log_debug "Using current_usage"
    CURRENT_TOKENS=$(echo "$context_info" | jq '
        .current_usage.input_tokens +
        (.current_usage.cache_creation_input_tokens // 0) +
        (.current_usage.cache_read_input_tokens // 0)
    ')
    log_debug "  CURRENT_TOKENS: $CURRENT_TOKENS"

    if [[ "$CTX_SIZE" != "NULL" ]] && [[ "$CTX_SIZE" != "null" ]] && [[ "$CTX_SIZE" -gt 0 ]]; then
        context_usage=$((CURRENT_TOKENS * 100 / CTX_SIZE))
        log_debug "  Calculated context_usage: $context_usage"
    fi
fi

# Try used_percentage
if [[ -z "$context_usage" ]] && [[ "$USED_PCT" != "NULL" ]] && [[ "$USED_PCT" != "null" ]] && [[ "$USED_PCT" != "0" ]]; then
    log_debug "Using used_percentage: $USED_PCT"
    context_usage=$USED_PCT
fi

# Try total_*_tokens
if [[ -z "$context_usage" ]]; then
    log_debug "Using total_*_tokens"
    if [[ "$TOTAL_IN" != "NULL" ]] && [[ "$TOTAL_OUT" != "NULL" ]]; then
        if [[ "$CTX_SIZE" != "NULL" ]] && [[ "$CTX_SIZE" != "null" ]] && [[ "$CTX_SIZE" -gt 0 ]]; then
            TOTAL_USED=$((TOTAL_IN + TOTAL_OUT))
            context_usage=$((TOTAL_USED * 100 / CTX_SIZE))
            log_debug "  TOTAL_USED: $TOTAL_USED"
            log_debug "  Calculated context_usage: $context_usage"
        fi
    fi
fi

# Default to 0
if [[ -z "$context_usage" ]]; then
    log_debug "All methods failed, defaulting to 0"
    context_usage=0
fi

log_debug "Final context_usage: $context_usage"
log_debug "====================="

# Output normal statusline (pass through to original script)
echo "$stdin_data" | "$SCRIPT_DIR/statusline-ralph.sh"
