#!/bin/bash
# inject-session-context.sh - PreToolUse Hook for Ralph v2.43
# Injects session context before Task tool calls
#
# Input (JSON via stdin):
#   - hook_event_name: "PreToolUse"
#   - tool_name: Name of tool being called
#   - tool_input: Tool parameters
#   - session_id: Current session identifier
#
# Output (JSON):
#   - {"decision": "continue"} - Standard hook response format
#   - Note: hookSpecificOutput is ONLY for SessionStart hooks
#
# Part of Ralph v2.43 Context Engineering

# VERSION: 2.45.4
# Note: Not using set -e because we need graceful fallback on errors
set -uo pipefail

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

# Safe JSON output - PreToolUse hooks use {"decision": "continue"} format
output_json() {
    local context="${1:-}"
    local message="${2:-}"

    if [[ -n "$message" ]]; then
        echo "{\"decision\": \"continue\", \"additionalContext\": \"$message\"}"
    else
        echo '{"decision": "continue"}'
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
    echo '{"decision": "continue"}'
    exit 0
fi

# Check if context injection is enabled
if ! check_feature_enabled "RALPH_INJECT_CONTEXT" "true"; then
    log "INFO" "Context injection disabled via features.json"
    echo '{"decision": "continue"}'
    exit 0
fi

# Build context to inject
CONTEXT=""

# 1. Read current goal from progress.md if exists
# VULN-002: Sanitize all file-derived variables
GOAL=""
if [[ -f ".claude/progress.md" ]]; then
    GOAL=$(grep -A1 "## Current Goal" ".claude/progress.md" 2>/dev/null | tail -1 | head -c 500 || true)
    # Sanitize: remove shell metacharacters
    GOAL=$(echo "$GOAL" | tr -cd 'a-zA-Z0-9 ._:/-')
    if [[ -n "$GOAL" ]]; then
        CONTEXT+="**Current Goal**: $GOAL\\n"
        log "INFO" "Loaded goal from progress.md"
    fi
fi

# 2. Read recent progress (last 5 items)
# VULN-002/007: Sanitize + limit output size
if [[ -f ".claude/progress.md" ]]; then
    RECENT=$(grep -A10 "## Recent Progress" ".claude/progress.md" 2>/dev/null | head -6 | head -c 1000 || true)
    RECENT=$(echo "$RECENT" | tr -cd 'a-zA-Z0-9 ._:/-\n')
    if [[ -n "$RECENT" ]]; then
        CONTEXT+="**Recent Progress**:\\n$RECENT\\n"
        log "INFO" "Loaded recent progress"
    fi
fi

# 3. Add project context from CLAUDE.md header
# VULN-002: Sanitize header extraction
if [[ -f "CLAUDE.md" ]]; then
    # Get first 10 lines (header/version info)
    HEADER=$(head -10 "CLAUDE.md" 2>/dev/null | head -c 500 || true)
    if [[ -n "$HEADER" ]]; then
        PROJECT_NAME=$(echo "$HEADER" | grep -m1 "^#" | sed 's/^# //' | tr -cd 'a-zA-Z0-9 ._-' | head -c 100 || echo 'Unknown')
        CONTEXT+="**Project**: $PROJECT_NAME\\n"
        log "INFO" "Loaded project info from CLAUDE.md"
    fi
fi

# 4. Add session ID for traceability
CONTEXT+="**Session**: $SESSION_ID\\n"

# 5. Add claude-mem reminder
CONTEXT+="**Memory**: Use claude-mem MCP (search → timeline → get_observations) for persistent context.\\n"

# PreToolUse hooks should return {"decision": "continue"} to allow the tool call
# The context injection feature is deprecated - PreToolUse cannot inject context
# Context injection is only available for SessionStart hooks
log "INFO" "PreToolUse hook allowing Task tool (context injection not available for PreToolUse)"
output_json "" "Task tool allowed"
exit 0
