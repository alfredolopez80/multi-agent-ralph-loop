#!/bin/bash
# pre-compact-handoff.sh - PreCompact Hook for Ralph v2.35
# Auto-saves state BEFORE context compaction to prevent information loss
#
# Input (JSON via stdin):
#   - hook_event_name: "PreCompact"
#   - session_id: Current session identifier
#   - transcript_path: Path to current transcript
#
# Output (JSON):
#   - continue: true (PreCompact cannot block)
#
# NOTE: PreCompact hooks CANNOT prevent compaction - they only receive
# notification that it's about to happen. Use this to save state.
#
# Part of Ralph v2.35 Context Engineering Optimization

# VERSION: 2.43.0
set -euo pipefail

# Configuration
LEDGER_DIR="${HOME}/.ralph/ledgers"
HANDOFF_DIR="${HOME}/.ralph/handoffs"
SCRIPTS_DIR="${HOME}/.claude/scripts"
FEATURES_FILE="${HOME}/.ralph/config/features.json"
LOG_FILE="${HOME}/.ralph/logs/pre-compact.log"

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
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null || echo "unknown")
TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // ""' 2>/dev/null || echo "")
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

log "INFO" "PreCompact hook triggered - session: $SESSION_ID, transcript: $TRANSCRIPT_PATH"

# Check if handoff feature is enabled (default: true)
if ! check_feature_enabled "RALPH_ENABLE_HANDOFF" "true"; then
    log "INFO" "Handoff feature disabled via features.json"
    echo '{"continue": true}'
    exit 0
fi

# Create session-specific handoff directory
SESSION_HANDOFF_DIR="${HANDOFF_DIR}/${SESSION_ID}"
mkdir -p "$SESSION_HANDOFF_DIR"

# Determine current working directory (project context)
# Try to get it from the transcript or use HOME
PROJECT_DIR="${HOME}"
if [[ -n "$TRANSCRIPT_PATH" ]] && [[ -f "$TRANSCRIPT_PATH" ]]; then
    # Try to extract working directory from transcript
    EXTRACTED_DIR=$(jq -r 'select(.cwd != null) | .cwd' "$TRANSCRIPT_PATH" 2>/dev/null | tail -1 || true)
    if [[ -n "$EXTRACTED_DIR" ]] && [[ -d "$EXTRACTED_DIR" ]]; then
        PROJECT_DIR="$EXTRACTED_DIR"
    fi
fi

# Generate ledger using ledger-manager.py
if check_feature_enabled "RALPH_ENABLE_LEDGER" "true"; then
    LEDGER_SCRIPT="${SCRIPTS_DIR}/ledger-manager.py"
    if [[ -x "$LEDGER_SCRIPT" ]]; then
        log "INFO" "Generating ledger for session: $SESSION_ID"

        # Create a basic ledger (the script handles content generation)
        python3 "$LEDGER_SCRIPT" save \
            --session "$SESSION_ID" \
            --goal "Session state before compaction (auto-saved)" \
            --output "${LEDGER_DIR}/CONTINUITY_RALPH-${SESSION_ID}.md" \
            >> "$LOG_FILE" 2>&1 || {
                log "ERROR" "Failed to generate ledger"
            }

        log "INFO" "Ledger saved to: ${LEDGER_DIR}/CONTINUITY_RALPH-${SESSION_ID}.md"
    else
        log "WARN" "Ledger manager script not found or not executable: $LEDGER_SCRIPT"
    fi
fi

# Generate handoff using handoff-generator.py
HANDOFF_SCRIPT="${SCRIPTS_DIR}/handoff-generator.py"
if [[ -x "$HANDOFF_SCRIPT" ]]; then
    log "INFO" "Generating handoff for session: $SESSION_ID"

    python3 "$HANDOFF_SCRIPT" create \
        --session "$SESSION_ID" \
        --trigger "PreCompact (auto)" \
        --project "$PROJECT_DIR" \
        --output "${SESSION_HANDOFF_DIR}/handoff-${TIMESTAMP}.md" \
        >> "$LOG_FILE" 2>&1 || {
            log "ERROR" "Failed to generate handoff"
        }

    log "INFO" "Handoff saved to: ${SESSION_HANDOFF_DIR}/handoff-${TIMESTAMP}.md"
else
    log "WARN" "Handoff generator script not found or not executable: $HANDOFF_SCRIPT"
fi

# Index in Memvid if available and enabled
if command -v ralph &>/dev/null; then
    # Check if memvid feature exists in ralph
    if ralph memvid status >> "$LOG_FILE" 2>&1; then
        log "INFO" "Indexing checkpoint in Memvid"
        ralph memvid save "Pre-compact checkpoint: ${SESSION_ID} at ${TIMESTAMP}" >> "$LOG_FILE" 2>&1 || {
            log "WARN" "Memvid indexing failed (non-critical)"
        }
    fi
fi

# Clean up old handoffs (keep last 20 per session, older than 7 days)
python3 "$HANDOFF_SCRIPT" cleanup --days 7 --keep-min 20 >> "$LOG_FILE" 2>&1 || {
    log "WARN" "Handoff cleanup failed (non-critical)"
}

log "INFO" "PreCompact hook completed successfully"

# Return success (PreCompact cannot block)
echo '{"continue": true}'
