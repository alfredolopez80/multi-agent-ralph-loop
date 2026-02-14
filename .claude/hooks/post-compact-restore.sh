#!/bin/bash
# VERSION: 2.85.0
# post-compact-restore.sh - Multi-Agent Ralph v2.85.0
# Restores context and plan state after compaction
# Triggered by: SessionStart hook with matcher="compact"
#
# v2.85.0: CRITICAL FIX
#   - PostCompact event does NOT exist in Claude Code
#   - Must use SessionStart with matcher="compact" instead
#   - This hook now uses SessionStart format
#
# v2.81.0: MAJOR REFACTOR
#   - Proper plan state restoration
#   - Context injection via hookSpecificOutput
#   - Plan survival across compaction
#   - Continuity preservation
#
# Input (JSON via stdin):
#   - session_id: Current session identifier
#   - source: "compact" (matcher that triggered this)
#   - transcript_path: Path to current transcript
#
# Output (JSON):
#   - {"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": "..."}}
#
# NOTE: SessionStart with matcher="compact" fires AFTER compaction when session resumes
# This is the right time to restore context for immediate use

# SEC-111: Read input from stdin with length limit (100KB max)
INPUT=$(head -c 100000)

set -euo pipefail

# SEC-006: Guaranteed JSON output on any error (ERR only, not EXIT)
trap 'echo "{\"hookSpecificOutput\": {\"hookEventName\": \"SessionStart\", \"additionalContext\": \"Error during context restoration\"}}"' ERR

LOG_FILE="${HOME}/.ralph/logs/post-compact.log"
SESSION_FILE="${HOME}/.ralph/.current-session"
LEDGER_DIR="${HOME}/.ralph/ledgers"
PLAN_STATE_FILE=".claude/plan-state.json"
PROJECT_DIR="$(pwd)"

log() {
    echo "[$(date -Iseconds)] $*" >> "$LOG_FILE"
}

log "PostCompact hook triggered for project: $(basename "$PROJECT_DIR")"

# Get current session ID
SESSION_ID=""
if [[ -f "$SESSION_FILE" ]]; then
    SESSION_ID=$(cat "$SESSION_FILE")
    log "Session ID: $SESSION_ID"
fi

# Initialize context for injection
CONTEXT="## Context Restored After Compaction\n\n"
CONTEXT+="**Time**: $(date -u +"%Y-%m-%dT%H:%M:%SZ")\n"
CONTEXT+="**Project**: $(basename "$PROJECT_DIR")\n\n"

# Flag to track if we found context
FOUND_CONTEXT=false

# 1. Check and restore plan state if exists
if [[ -f "${PROJECT_DIR}/${PLAN_STATE_FILE}" ]]; then
    log "Found plan-state.json - reading plan status"

    PLAN_STATUS=$(jq -r '.plan.status // "unknown"' "${PROJECT_DIR}/${PLAN_STATE_FILE}" 2>/dev/null || echo "unknown")

    if [[ "$PLAN_STATUS" == "in_progress" ]]; then
        CONTEXT+="### Active Plan Restored\n\n"
        CONTEXT+="Your active plan has survived the compaction and is ready to continue.\n\n"

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
            if [[ "$TOTAL_STEPS" -gt 0 ]]; then
                PROGRESS=$((COMPLETED_STEPS * 100 / TOTAL_STEPS))
            else
                PROGRESS=0
            fi
            CONTEXT+="**Progress**: ${COMPLETED_STEPS}/${TOTAL_STEPS} steps completed (${PROGRESS}%)\n\n"
        fi

        FOUND_CONTEXT=true
        log "Plan state restored - status: $PLAN_STATUS, progress: ${COMPLETED_STEPS}/${TOTAL_STEPS}"
    else
        log "Plan exists but not in progress - status: $PLAN_STATUS"
    fi
fi

# 2. Include compact ledger if available
if [[ -n "$SESSION_ID" ]]; then
    LEDGER_FILE="${LEDGER_DIR}/CONTINUITY_RALPH-${SESSION_ID}.md"

    if [[ -f "$LEDGER_FILE" ]]; then
        log "Loading ledger for session: $SESSION_ID"

        CONTEXT+="### Session Ledger\n\n"
        CONTEXT+="Context from before compaction:\n\n"

        # Add first 100 lines of ledger
        LEDGER_SUMMARY=$(head -100 "$LEDGER_FILE" 2>/dev/null || echo "Unable to read ledger")
        CONTEXT+="\`\`\`\n${LEDGER_SUMMARY}\n\`\`\`\n\n"

        FOUND_CONTEXT=true
        log "Ledger loaded and added to context"
    else
        log "No ledger found for session: $SESSION_ID"
    fi
fi

# 3. Check for most recent ledger (fallback)
if [[ "$FOUND_CONTEXT" == "false" ]]; then
    RECENT_LEDGER=$(ls -t "$LEDGER_DIR"/CONTINUITY_RALPH-*.md 2>/dev/null | head -1)

    if [[ -n "$RECENT_LEDGER" && -f "$RECENT_LEDGER" ]]; then
        log "Loading most recent ledger: $RECENT_LEDGER"

        CONTEXT+="### Recent Session Context\n\n"
        CONTEXT+="Context from most recent session:\n\n"

        LEDGER_SUMMARY=$(head -100 "$RECENT_LEDGER" 2>/dev/null || echo "Unable to read ledger")
        CONTEXT+="\`\`\`\n${LEDGER_SUMMARY}\n\`\`\`\n\n"

        FOUND_CONTEXT=true
        log "Recent ledger loaded"
    fi
fi

# 4. Add continuation guidance
if [[ "$FOUND_CONTEXT" == "true" ]]; then
    CONTEXT+="---\n\n"
    CONTEXT+="### Continue Working\n\n"
    CONTEXT+="The conversation has been compacted to free up space, but your work progress has been preserved.\n\n"
    CONTEXT+="**Next Steps**:\n"
    CONTEXT+="- Use `/plan show` to see the current plan status\n"
    CONTEXT+="- Use `/context` to check current context usage\n"
    CONTEXT+="- Continue with the task at hand\n\n"

    if [[ "$PLAN_STATUS" == "in_progress" ]]; then
        CONTEXT+="**Plan Status**: Your active plan has been restored and is ready to continue.\n\n"
    fi
else
    CONTEXT+="### No Previous Context\n\n"
    CONTEXT+="No previous context found. Starting fresh.\n\n"
fi

# Output the context via hookSpecificOutput (SessionStart format)
# v2.87.0 FIX: SessionStart hooks MUST use hookSpecificOutput for context injection
# Clear error trap and output proper JSON
trap - ERR EXIT

# Escape context for JSON using jq
ESCAPED_CONTEXT=$(echo -e "$CONTEXT" | jq -Rs '.' 2>/dev/null || echo '""')

# Output with hookSpecificOutput wrapper for SessionStart
echo "{\"hookSpecificOutput\": {\"hookEventName\": \"SessionStart\", \"additionalContext\": $ESCAPED_CONTEXT}}"

# Log completion
log "PostCompact hook completed - context restored: $FOUND_CONTEXT"
