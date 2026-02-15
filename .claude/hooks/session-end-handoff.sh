#!/bin/bash
# session-end-handoff.sh - SessionEnd Hook for Ralph v2.85.0
# Hook: SessionEnd
# Auto-saves state BEFORE session terminates to enable seamless continuation
#
# DIFFERENCE FROM PreCompact:
#   - PreCompact: Session continues after compaction (restore needed)
#   - SessionEnd: Session terminates (prepare for NEXT session)
#
# MATCHERS:
#   - clear: User runs /clear
#   - logout: User logs out
#   - prompt_input_exit: User exits prompt
#   - bypass_permissions_disabled: Bypass mode disabled
#   - other: Other termination cases
#
# Input (JSON via stdin):
#   - hook_event_name: "SessionEnd"
#   - session_id: Current session identifier
#   - reason: Why session is ending (matcher that triggered)
#   - transcript_path: Path to current transcript
#
# Output (JSON):
#   - {"continue": true} - Standard format (cannot block session end)
#   - hookSpecificOutput.additionalContext: Context for next session (via SessionStart)
#
# Part of Ralph v2.85 Agent Teams Integration

# SEC-111: Read input from stdin with length limit (100KB max)
INPUT=$(head -c 100000)

# VERSION: 2.86.2
set -euo pipefail

# CRITICAL: Redirect all stderr to log to prevent external messages from contaminating JSON output
# Save original stderr for final JSON output
exec 3>&2 2>> "${HOME}/.ralph/logs/session-end.log"

# Error trap: Only on ERR, NOT on EXIT (EXIT would duplicate output)
trap 'exec 2>&3 3>&-; echo "{\"continue\": true}"; exit 0' ERR

# Configuration
LEDGER_DIR="${HOME}/.ralph/ledgers"
HANDOFF_DIR="${HOME}/.ralph/handoffs"
SCRIPTS_DIR="${HOME}/.claude/scripts"
HOOKS_DIR="${HOME}/.claude/hooks"
FEATURES_FILE="${HOME}/.ralph/config/features.json"
LOG_FILE="${HOME}/.ralph/logs/session-end.log"
TEMP_CONTEXT_DIR="${HOME}/.ralph/temp"
NEXT_SESSION_FILE="${HOME}/.ralph/.next-session-context"

# Ensure directories exist
mkdir -p "$LEDGER_DIR" "$HANDOFF_DIR" "${HOME}/.ralph/logs" "$TEMP_CONTEXT_DIR"

# Logging function
log() {
    local level="$1"
    shift
    echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] [$level] $*" >> "$LOG_FILE" 2>/dev/null || true
}

# Source environment detection
if [[ -f "${HOOKS_DIR}/detect-environment.sh" ]]; then
    source "${HOOKS_DIR}/detect-environment.sh" 2>/dev/null || true
fi

# SEC-2.1: Source integrity library for checksum creation
INTEGRITY_LIB="${HOOKS_DIR}/handoff-integrity.sh"
if [[ -f "$INTEGRITY_LIB" ]]; then
    source "$INTEGRITY_LIB" 2>/dev/null || true
fi

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

# Parse input JSON
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null || echo "unknown")
SESSION_ID=$(echo "$SESSION_ID" | tr -cd 'a-zA-Z0-9_-' | head -c 64)
[[ -z "$SESSION_ID" ]] && SESSION_ID="unknown"

END_REASON=$(echo "$INPUT" | jq -r '.reason // .hook_event_name // "unknown"' 2>/dev/null || echo "unknown")
TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // ""' 2>/dev/null || echo "")
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

log "INFO" "SessionEnd hook triggered - session: $SESSION_ID, reason: $END_REASON"

# Check if handoff feature is enabled
if ! check_feature_enabled "RALPH_ENABLE_HANDOFF" "true"; then
    log "INFO" "Handoff feature disabled via features.json"
    trap - ERR
    exec 2>&3 3>&-  # Restore stderr
    echo '{"continue": true}'
    exit 0
fi

# Create session-specific handoff directory
SESSION_HANDOFF_DIR="${HANDOFF_DIR}/${SESSION_ID}"
mkdir -p "$SESSION_HANDOFF_DIR"

# Determine project directory
PROJECT_DIR="${HOME}"
PROJECT_NAME="unknown"
if [[ -n "$TRANSCRIPT_PATH" ]] && [[ -f "$TRANSCRIPT_PATH" ]]; then
    EXTRACTED_DIR=$(jq -r 'select(.cwd != null) | .cwd' "$TRANSCRIPT_PATH" 2>/dev/null | tail -1 || true)
    if [[ -n "$EXTRACTED_DIR" ]] && [[ -d "$EXTRACTED_DIR" ]]; then
        PROJECT_DIR="$EXTRACTED_DIR"
        PROJECT_NAME=$(basename "$PROJECT_DIR")
    fi
fi

# Try to get project from git if available
if [[ "$PROJECT_NAME" == "unknown" ]] && command -v git &>/dev/null; then
    GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || true)
    if [[ -n "$GIT_ROOT" ]] && [[ -d "$GIT_ROOT" ]]; then
        PROJECT_DIR="$GIT_ROOT"
        PROJECT_NAME=$(basename "$PROJECT_DIR")
    fi
fi

# Generate ledger (reuse pre-compact-handoff logic)
if check_feature_enabled "RALPH_ENABLE_LEDGER" "true"; then
    LEDGER_SCRIPT="${SCRIPTS_DIR}/ledger-manager.py"
    CONTEXT_EXTRACTOR="${SCRIPTS_DIR}/context-extractor.py"
    CONTEXT_JSON="${TEMP_CONTEXT_DIR}/context-${SESSION_ID}.json"

    if [[ -x "$LEDGER_SCRIPT" ]]; then
        log "INFO" "Generating end-of-session ledger for: $SESSION_ID"

        if check_feature_enabled "RALPH_ENABLE_CONTEXT_EXTRACTOR" "true" && [[ -x "$CONTEXT_EXTRACTOR" ]]; then
            if python3 "$CONTEXT_EXTRACTOR" \
                --project "$PROJECT_DIR" \
                --transcript "$TRANSCRIPT_PATH" \
                --goal "Session end handoff (SessionEnd hook)" \
                --output "$CONTEXT_JSON" 2>> "$LOG_FILE"; then

                python3 "$LEDGER_SCRIPT" save \
                    --session "$SESSION_ID" \
                    --json "$CONTEXT_JSON" \
                    --output "${LEDGER_DIR}/CONTINUITY_RALPH-${SESSION_ID}.md" \
                    >> "$LOG_FILE" 2>&1 || {
                        log "ERROR" "Failed to generate ledger with context"
                    }

                rm -f "$CONTEXT_JSON" 2>/dev/null || true
            else
                # Fallback to basic ledger
                python3 "$LEDGER_SCRIPT" save \
                    --session "$SESSION_ID" \
                    --goal "Session end handoff (SessionEnd hook)" \
                    --output "${LEDGER_DIR}/CONTINUITY_RALPH-${SESSION_ID}.md" \
                    >> "$LOG_FILE" 2>&1 || {
                        log "ERROR" "Failed to generate basic ledger"
                    }
            fi
        else
            python3 "$LEDGER_SCRIPT" save \
                --session "$SESSION_ID" \
                --goal "Session end handoff (SessionEnd hook)" \
                --output "${LEDGER_DIR}/CONTINUITY_RALPH-${SESSION_ID}.md" \
                >> "$LOG_FILE" 2>&1 || {
                    log "ERROR" "Failed to generate ledger"
                }
        fi

        log "INFO" "Ledger saved to: ${LEDGER_DIR}/CONTINUITY_RALPH-${SESSION_ID}.md"

        # SEC-2.1: Create checksum for ledger integrity validation
        if type handoff_create_checksum &>/dev/null; then
            handoff_create_checksum "${LEDGER_DIR}/CONTINUITY_RALPH-${SESSION_ID}.md" && \
                log "INFO" "Checksum created for ledger" || \
                log "WARN" "Failed to create ledger checksum"
        fi
    fi
fi

# Generate handoff
HANDOFF_SCRIPT="${SCRIPTS_DIR}/handoff-generator.py"
if [[ -x "$HANDOFF_SCRIPT" ]]; then
    log "INFO" "Generating handoff for session: $SESSION_ID"

    python3 "$HANDOFF_SCRIPT" create \
        --session "$SESSION_ID" \
        --trigger "SessionEnd (${END_REASON})" \
        --project "$PROJECT_DIR" \
        --output "${SESSION_HANDOFF_DIR}/handoff-${TIMESTAMP}.md" \
        >> "$LOG_FILE" 2>&1 || {
            log "ERROR" "Failed to generate handoff"
        }

    log "INFO" "Handoff saved to: ${SESSION_HANDOFF_DIR}/handoff-${TIMESTAMP}.md"

    # SEC-2.1: Create checksum for handoff integrity validation
    if type handoff_create_checksum &>/dev/null; then
        handoff_create_checksum "${SESSION_HANDOFF_DIR}/handoff-${TIMESTAMP}.md" && \
            log "INFO" "Checksum created for handoff" || \
            log "WARN" "Failed to create handoff checksum"
    fi
fi

# Backup plan state if exists
PLAN_STATE_FILE="${PROJECT_DIR}/.claude/plan-state.json"
PLAN_BACKUP_DIR="${LEDGER_DIR}/plan-states"

if [[ -f "$PLAN_STATE_FILE" ]]; then
    log "INFO" "Backing up plan state before session end"

    mkdir -p "$PLAN_BACKUP_DIR"

    cp "$PLAN_STATE_FILE" "${PLAN_BACKUP_DIR}/plan-state-${SESSION_ID}-${TIMESTAMP}.json" && {
        log "INFO" "Plan state backed up: ${PLAN_BACKUP_DIR}/plan-state-${SESSION_ID}-${TIMESTAMP}.json"

        # Create symlink to latest
        LATEST_LINK="${PLAN_BACKUP_DIR}/latest-${PROJECT_NAME}.json"
        ln -sf "plan-state-${SESSION_ID}-${TIMESTAMP}.json" "$LATEST_LINK" 2>/dev/null || true
    } || {
        log "ERROR" "Failed to backup plan state"
    }
fi

# Prepare context for next session
# This will be picked up by SessionStart hook
NEXT_CONTEXT=""
NEXT_CONTEXT+="## Session End Handoff - ${SESSION_ID}\n\n"
NEXT_CONTEXT+="**Ended**: $(date -u +"%Y-%m-%dT%H:%M:%SZ")\n"
NEXT_CONTEXT+="**Reason**: ${END_REASON}\n"
NEXT_CONTEXT+="**Project**: ${PROJECT_NAME}\n\n"

# Add plan status if available
if [[ -f "$PLAN_STATE_FILE" ]]; then
    PLAN_STATUS=$(jq -r '.plan.status // "unknown"' "$PLAN_STATE_FILE" 2>/dev/null || echo "unknown")
    PLAN_SUMMARY=$(jq -r '.plan.summary // "No summary"' "$PLAN_STATE_FILE" 2>/dev/null || echo "No summary")

    NEXT_CONTEXT+="### Active Plan\n"
    NEXT_CONTEXT+="**Status**: ${PLAN_STATUS}\n"
    NEXT_CONTEXT+="**Summary**: ${PLAN_SUMMARY}\n\n"
fi

# Add ledger location
if [[ -f "${LEDGER_DIR}/CONTINUITY_RALPH-${SESSION_ID}.md" ]]; then
    NEXT_CONTEXT+="### Ledger Available\n"
    NEXT_CONTEXT+="Location: \`${LEDGER_DIR}/CONTINUITY_RALPH-${SESSION_ID}.md\`\n\n"
fi

# Add handoff location
if [[ -f "${SESSION_HANDOFF_DIR}/handoff-${TIMESTAMP}.md" ]]; then
    NEXT_CONTEXT+="### Handoff Available\n"
    NEXT_CONTEXT+="Location: \`${SESSION_HANDOFF_DIR}/handoff-${TIMESTAMP}.md\`\n\n"
fi

NEXT_CONTEXT+="---\n"
NEXT_CONTEXT+="Use \`/smart-fork\` to continue from this session.\n"

# Save next session context for SessionStart hook
echo -e "$NEXT_CONTEXT" > "$NEXT_SESSION_FILE"

log "INFO" "Next session context saved to: $NEXT_SESSION_FILE"

# Clean up old handoffs
if [[ -x "$HANDOFF_SCRIPT" ]]; then
    python3 "$HANDOFF_SCRIPT" cleanup --days 7 --keep-min 20 >> "$LOG_FILE" 2>&1 || {
        log "WARN" "Handoff cleanup failed (non-critical)"
    }
fi

log "INFO" "SessionEnd hook completed successfully"

# Output JSON with additionalContext for SessionStart to pick up
# Note: SessionEnd additionalContext may be used by SessionStart in next session
# CRITICAL: Only JSON to stdout, everything else to stderr/log

# Clear any traps that might interfere
trap - ERR

# Restore stderr to original before final output (in case JSON needs to report errors)
exec 2>&3 3>&-

# Build JSON in variable, then output at the very end (single echo to stdout)
# NOTE: SessionEnd does NOT support hookSpecificOutput in Claude Code schema.
# Only PreToolUse, UserPromptSubmit, and PostToolUse support hookSpecificOutput.
# Context is saved to $NEXT_SESSION_FILE for SessionStart to pick up.
JSON_OUTPUT='{"continue": true}'

# Final output - single write to stdout, nothing else
echo "$JSON_OUTPUT"
