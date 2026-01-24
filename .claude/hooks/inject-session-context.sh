#!/bin/bash
# inject-session-context.sh - PreToolUse Hook for Ralph v2.62.3
# Hook: PreToolUse (Task)
# Injects session context before Task tool calls
#
# Input (JSON via stdin):
#   - hook_event_name: "PreToolUse"
#   - tool_name: Name of tool being called
#   - tool_input: Tool parameters
#   - session_id: Current session identifier
#
# Output (JSON):
#   - {"decision": "allow"} - Standard hook response format
#   - Note: hookSpecificOutput is ONLY for SessionStart hooks
#
# Part of Ralph v2.43 Context Engineering

# VERSION: 2.68.10
# v2.68.10: HIGH-002 FIX - Removed 43 lines of dead code (context building never used)
# v2.68.1: FIX CRIT-002 - Clear EXIT trap before explicit JSON output to prevent duplicate JSON
# Note: Not using set -e because we need graceful fallback on errors
set -uo pipefail

# Error trap: Always output valid JSON for PreToolUse
trap 'echo "{\"decision\": \"allow\"}"' ERR EXIT

# Configuration
LOG_FILE="${HOME}/.ralph/logs/inject-context.log"
FEATURES_FILE="${HOME}/.ralph/config/features.json"
CONTEXT_CACHE="${HOME}/.ralph/cache/session-context.json"

# Ensure directories exist
mkdir -p "${HOME}/.ralph/logs" "${HOME}/.ralph/cache"

# Logging function
log() {
    local level="$1"
    shift
    echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] [$level] $*" >> "$LOG_FILE" 2>/dev/null || true
}

# Safe JSON output - PreToolUse hooks use {"decision": "allow"} format
# SEC-039: PreToolUse hooks MUST use {"decision": "allow/block"}, NOT {"continue": true}
# SEC-043: Use jq for JSON construction to prevent injection
output_json() {
    local context="${1:-}"
    local message="${2:-}"

    # SEC-039 FIXED: PreToolUse hooks use {"decision": "allow"}, NOT {"continue": true}
    # SEC-043 FIXED: Use jq --arg to safely escape message content
    if [[ -n "$message" ]]; then
        # Use jq for safe JSON construction (prevents JSON injection)
        jq -n --arg ctx "$message" '{"decision": "allow", "additionalContext": $ctx}'
    else
        echo '{"decision": "allow"}'
    fi
}

# Check feature flags
check_feature_enabled() {
    local feature="$1"
    local default="$2"

    if [[ -f "$FEATURES_FILE" ]]; then
        local value
        value=$(jq -r ".$feature // \"$default\"" "$FEATURES_FILE" 2>/dev/null || echo "$default")
        [[ "$value" == "true" ]]
    else
        [[ "$default" == "true" ]]
    fi
}

# Read input from stdin
INPUT=$(cat)

# Parse input JSON
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null || echo "")
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null || echo "unknown")

log "INFO" "PreToolUse hook triggered - tool: $TOOL_NAME, session: $SESSION_ID"

# Only inject context for Task tool calls
if [[ "$TOOL_NAME" != "Task" ]]; then
    log "DEBUG" "Skipping non-Task tool: $TOOL_NAME"
    trap - EXIT  # CRIT-002: Clear trap before explicit output
    echo '{"decision": "allow"}'
    exit 0
fi

# Check if context injection is enabled
if ! check_feature_enabled "RALPH_INJECT_CONTEXT" "true"; then
    log "INFO" "Context injection disabled via features.json"
    trap - EXIT  # CRIT-002: Clear trap before explicit output
    echo '{"decision": "allow"}'
    exit 0
fi

# HIGH-002 FIX: Removed 43 lines of dead code that built context but never used it
# PreToolUse hooks can only return {"decision": "allow/block"}, they CANNOT inject context
# Context injection is ONLY available for SessionStart hooks
# The removed code was:
#   - Reading progress.md (goal, recent progress)
#   - Reading CLAUDE.md (project name)
#   - Building $CONTEXT variable
#   - All of which was discarded since PreToolUse cannot inject

log "INFO" "PreToolUse hook allowing Task tool"
trap - EXIT  # CRIT-002: Clear trap before explicit output
echo '{"decision": "allow"}'
exit 0
