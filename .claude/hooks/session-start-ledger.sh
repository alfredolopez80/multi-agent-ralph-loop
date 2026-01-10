#!/bin/bash
# session-start-ledger.sh - SessionStart Hook for Ralph v2.35
# Auto-loads ledger and handoff at session start for context preservation
#
# Input (JSON via stdin):
#   - hook_event_name: "SessionStart"
#   - session_id: Current session identifier
#   - source: "startup" | "resume" | "clear" | "compact"
#
# Output (JSON):
#   - hookSpecificOutput.additionalContext: Content to inject into context
#
# Part of Ralph v2.35 Context Engineering Optimization

set -euo pipefail

# Configuration
LEDGER_DIR="${HOME}/.ralph/ledgers"
HANDOFF_DIR="${HOME}/.ralph/handoffs"
SCRIPTS_DIR="${HOME}/.claude/scripts"
FEATURES_FILE="${HOME}/.ralph/config/features.json"
LOG_FILE="${HOME}/.ralph/logs/session-start.log"

# Ensure directories exist
mkdir -p "$LEDGER_DIR" "$HANDOFF_DIR" "${HOME}/.ralph/logs"

# Logging function
log() {
    local level="$1"
    shift
    echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] [$level] $*" >> "$LOG_FILE" 2>/dev/null || true
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
SOURCE=$(echo "$INPUT" | jq -r '.source // "startup"' 2>/dev/null || echo "startup")
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null || echo "unknown")

log "INFO" "SessionStart hook triggered - source: $SOURCE, session: $SESSION_ID"

# Check if ledger feature is enabled (default: true)
if ! check_feature_enabled "RALPH_ENABLE_LEDGER" "true"; then
    log "INFO" "Ledger feature disabled via features.json"
    echo '{"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": ""}}'
    exit 0
fi

# Find the most recent ledger
LEDGER=""
if [[ -d "$LEDGER_DIR" ]]; then
    LEDGER=$(ls -t "$LEDGER_DIR"/CONTINUITY_RALPH-*.md 2>/dev/null | head -1 || true)
fi

# Find the most recent handoff
HANDOFF=""
if [[ -d "$HANDOFF_DIR" ]]; then
    HANDOFF=$(find "$HANDOFF_DIR" -name "handoff-*.md" -type f 2>/dev/null | \
              xargs ls -t 2>/dev/null | head -1 || true)
fi

# Build context to inject
CONTEXT=""

# Add ledger content if found
if [[ -n "$LEDGER" ]] && [[ -f "$LEDGER" ]]; then
    LEDGER_CONTENT=$(cat "$LEDGER" 2>/dev/null || true)
    if [[ -n "$LEDGER_CONTENT" ]]; then
        CONTEXT+="## Session Ledger (auto-loaded)\n"
        CONTEXT+="$LEDGER_CONTENT"
        CONTEXT+="\n\n"
        log "INFO" "Loaded ledger: $LEDGER"
    fi
fi

# Add handoff content if found and enabled
if check_feature_enabled "RALPH_ENABLE_HANDOFF" "true"; then
    if [[ -n "$HANDOFF" ]] && [[ -f "$HANDOFF" ]]; then
        HANDOFF_CONTENT=$(cat "$HANDOFF" 2>/dev/null || true)
        if [[ -n "$HANDOFF_CONTENT" ]]; then
            CONTEXT+="## Last Handoff (auto-loaded)\n"
            CONTEXT+="$HANDOFF_CONTENT"
            log "INFO" "Loaded handoff: $HANDOFF"
        fi
    fi
fi

# If no context to inject, return empty
if [[ -z "$CONTEXT" ]]; then
    log "INFO" "No ledger or handoff found to inject"
    echo '{"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": ""}}'
    exit 0
fi

# Escape the context for JSON
# Use Python for reliable JSON escaping
ESCAPED_CONTEXT=$(python3 -c "
import json
import sys
content = sys.stdin.read()
print(json.dumps(content))
" <<< "$CONTEXT")

# Output JSON with context to inject
cat << EOF
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": $ESCAPED_CONTEXT
  }
}
EOF

log "INFO" "SessionStart hook completed successfully"
