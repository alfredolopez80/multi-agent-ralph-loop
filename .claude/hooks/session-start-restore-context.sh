#!/bin/bash
# session-start-restore-context.sh - SessionStart Hook for Ralph v2.81.0
# Hook: SessionStart
# Restores context and plan state when a new session starts
#
# Input (JSON via stdin):
#   - hook_event_name: "SessionStart"
#   - session_id: New session identifier
#   - project_dir: Current working directory
#
# Output (JSON with hookSpecificOutput):
#   - additionalContext: Context to inject into the new session
#
# This hook ensures continuity across compaction boundaries by:
# 1. Detecting if this is a continuation session
# 2. Loading the most recent ledger
# 3. Restoring plan state if exists
# 4. Injecting context into the new session

# VERSION: 2.81.0
set -euo pipefail

# Configuration
LOG_FILE="${HOME}/.ralph/logs/session-start-restore.log"
LEDGER_DIR="${HOME}/.ralph/ledgers"
HANDOFF_DIR="${HOME}/.ralph/handoffs"
PLAN_STATE_FILE=".claude/plan-state.json"
FEATURES_FILE="${HOME}/.ralph/config/features.json"
MAX_SUMMARY_LINES=50

# Ensure directories exist
mkdir -p "${HOME}/.ralph/logs" "$HANDOFF_DIR"

# Logging function
log() {
    echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] $*" >> "$LOG_FILE" 2>/dev/null || true
}

# Check feature flags
check_feature_enabled() {
    local feature="$1"
    local default="${2:-true}"

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

# Parse input
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null || echo "unknown")
# SEC-029: Sanitize session_id
SESSION_ID=$(echo "$SESSION_ID" | tr -cd 'a-zA-Z0-9_-' | head -c 64)
[[ -z "$SESSION_ID" ]] && SESSION_ID="unknown"

# Get project directory
PROJECT_DIR="$(pwd)"
PROJECT_NAME="$(basename "$PROJECT_DIR")"

log "INFO" "SessionStart hook triggered - session: $SESSION_ID, project: $PROJECT_NAME"

# Check if context restoration is enabled
if ! check_feature_enabled "RALPH_RESTORE_CONTEXT" "true"; then
    log "INFO" "Context restoration disabled via features.json"
    # SessionStart hooks don't need JSON output when no context
    exit 0
fi

# Build context injection
CONTEXT="## Session Context Restored\n\n"
CONTEXT+="**Session ID**: ${SESSION_ID}\n"
CONTEXT+="**Project**: ${PROJECT_NAME}\n"
CONTEXT+="**Time**: $(date -u +"%Y-%m-%dT%H:%M:%SZ")\n\n"

# Flag to track if we found any context
FOUND_CONTEXT=false

# 1. Check for plan state in current project
if [[ -f "${PROJECT_DIR}/${PLAN_STATE_FILE}" ]]; then
    log "INFO" "Found plan-state.json in project"

    PLAN_STATUS=$(jq -r '.plan.status // "unknown"' "${PROJECT_DIR}/${PLAN_STATE_FILE}" 2>/dev/null || echo "unknown")

    if [[ "$PLAN_STATUS" == "in_progress" ]]; then
        CONTEXT+="### Active Plan\n\n"
        CONTEXT+="There is an **active plan** in progress for this project.\n\n"

        # Extract plan summary
        PLAN_SUMMARY=$(jq -r '.plan.summary // "No summary available"' "${PROJECT_DIR}/${PLAN_STATE_FILE}" 2>/dev/null || echo "No summary")
        CONTEXT+="**Summary**: ${PLAN_SUMMARY}\n\n"

        # Extract current step
        CURRENT_STEP=$(jq -r '.current_step // "unknown"' "${PROJECT_DIR}/${PLAN_STATE_FILE}" 2>/dev/null || echo "unknown")
        if [[ "$CURRENT_STEP" != "unknown" && "$CURRENT_STEP" != "null" ]]; then
            CONTEXT+="**Current Step**: ${CURRENT_STEP}\n\n"
        fi

        # Extract progress
        TOTAL_STEPS=$(jq -r '.steps | length' "${PROJECT_DIR}/${PLAN_STATE_FILE}" 2>/dev/null || echo "0")
        COMPLETED_STEPS=$(jq -r '[.steps[] | select(.status == "completed")] | length' "${PROJECT_DIR}/${PLAN_STATE_FILE}" 2>/dev/null || echo "0")

        if [[ "$TOTAL_STEPS" -gt 0 ]]; then
            PROGRESS=$((COMPLETED_STEPS * 100 / TOTAL_STEPS))
            CONTEXT+="**Progress**: ${COMPLETED_STEPS}/${TOTAL_STEPS} steps completed (${PROGRESS}%)\n\n"
        fi

        FOUND_CONTEXT=true
        log "INFO" "Plan context added - status: $PLAN_STATUS, step: $CURRENT_STEP"
    fi
fi

# 2. Look for recent ledger for this project
LEDGER_PATTERN="${LEDGER_DIR}/CONTINUITY_RALPH-*.md"
MOST_RECENT_LEDGER=$(ls -t $LEDGER_PATTERN 2>/dev/null | head -1)

if [[ -n "$MOST_RECENT_LEDGER" && -f "$MOST_RECENT_LEDGER" ]]; then
    log "INFO" "Found recent ledger: $MOST_RECENT_LEDGER"

    # Extract project from ledger if available
    LEDGER_PROJECT=$(grep "^## Project:" "$MOST_RECENT_LEDGER" 2>/dev/null | head -1 | sed 's/^## Project: //' || echo "")

    if [[ -z "$LEDGER_PROJECT" || "$LEDGER_PROJECT" == "$PROJECT_NAME" ]]; then
        CONTEXT+="### Recent Session Context\n\n"
        CONTEXT+="Context restored from most recent ledger:\n\n"

        # Add ledger summary (first MAX_SUMMARY_LINES lines)
        LEDGER_SUMMARY=$(head -n "$MAX_SUMMARY_LINES" "$MOST_RECENT_LEDGER" 2>/dev/null || echo "Unable to read ledger")
        CONTEXT+="\`\`\`\n${LEDGER_SUMMARY}\n\`\`\`\n\n"

        FOUND_CONTEXT=true
        log "INFO" "Ledger context added"
    else
        log "INFO" "Ledger project mismatch - ledger: $LEDGER_PROJECT, current: $PROJECT_NAME"
    fi
fi

# 3. Look for recent handoff
SESSION_HANDOFF_DIR="${HANDOFF_DIR}/${SESSION_ID}"
if [[ -d "$SESSION_HANDOFF_DIR" ]]; then
    MOST_RECENT_HANDOFF=$(ls -t "${SESSION_HANDOFF_DIR}"/handoff-*.md 2>/dev/null | head -1)

    if [[ -n "$MOST_RECENT_HANDOFF" && -f "$MOST_RECENT_HANDOFF" ]]; then
        log "INFO" "Found recent handoff: $MOST_RECENT_HANDOFF"

        CONTEXT+="### Previous Session Handoff\n\n"
        HANDOFF_CONTENT=$(cat "$MOST_RECENT_HANDOFF" 2>/dev/null || echo "Unable to read handoff")
        CONTEXT+="\`\`\`\n${HANDOFF_CONTENT}\n\`\`\`\n\n"

        FOUND_CONTEXT=true
        log "INFO" "Handoff context added"
    fi
fi

# 4. Add continuity guidance if context was found
if [[ "$FOUND_CONTEXT" == "true" ]]; then
    CONTEXT+="---\n\n"
    CONTEXT+="### Next Steps\n\n"
    CONTEXT+="1. Review the context above to understand what was being worked on\n"
    CONTEXT+="2. Continue with the current task or plan\n"
    CONTEXT+="3. Use `/plan show` to see the current plan status\n"
    CONTEXT+="4. Use `/context` to check current context usage\n\n"
    CONTEXT+="**Note**: Your work progress has been preserved. Focus on completing the current task.\n"

    log "INFO" "Context restoration complete - context injected"
else
    CONTEXT+="### New Session\n\n"
    CONTEXT+="No previous context found for this project. Starting fresh.\n\n"
    CONTEXT+="To get started:\n"
    CONTEXT+="- Use `/orchestrator` for complex tasks\n"
    CONTEXT+="- Use `/help` to see available commands\n"

    log "INFO" "No previous context found - starting fresh"
fi

# Output context for injection
# SessionStart hooks can use hookSpecificOutput to inject context
jq -n --arg ctx "$CONTEXT" '{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "permissionDecision": "allow",
    "additionalContext": $ctx
  }
}'

log "INFO" "SessionStart hook completed"
