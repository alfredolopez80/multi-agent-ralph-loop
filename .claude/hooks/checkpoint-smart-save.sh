#!/bin/bash
# checkpoint-smart-save.sh - Smart checkpoint based on risk/complexity
# VERSION: 2.68.23
# v2.68.10: SEC-105 FIX - Atomic noclobber (O_EXCL) eliminates TOCTOU gap completely
# v2.68.1: FIX CRIT-003 - Clear EXIT trap before explicit JSON output to prevent duplicate JSON
# v2.66.8: HIGH-003 version sync, RACE-001 atomic mkdir already implemented
#
# Purpose: Automatically save checkpoints before risky operations
#
# Trigger: PreToolUse (Edit|Write)
#
# Smart Triggers:
# - high_complexity: Plan complexity >= 7, first edit of file
# - high_risk_step: Current step involves auth/security/payment
# - critical_file: Core config, security, database, API files
# - security_file: Files with auth/secret/credential in name
#
# Features:
# - Cooldown of 120 seconds between checkpoints
# - Only triggers on first edit of each file per session
# - Auto-cleanup keeps last 20 smart checkpoints

# SEC-111: Read input from stdin with length limit (100KB max)
# Prevents DoS from malicious input
INPUT=$(head -c 100000)


set -euo pipefail

# Error trap for guaranteed JSON output (v2.62.3)
trap 'echo "{\"decision\": \"allow\"}"' ERR EXIT


PLAN_STATE=".claude/plan-state.json"
CHECKPOINT_DIR="${HOME}/.ralph/checkpoints"
TRACKING_DIR="${HOME}/.ralph/cache/checkpoint-tracking"
LOG_FILE="${HOME}/.ralph/logs/checkpoint-smart.log"
COOLDOWN_SECONDS=120
MAX_SMART_CHECKPOINTS=20

# Check if disabled
if [[ "${RALPH_CHECKPOINT_SMART:-true}" == "false" ]]; then
    trap - EXIT  # CRIT-003: Clear trap before explicit output
    echo '{"decision": "allow"}'
    exit 0
fi

mkdir -p "$CHECKPOINT_DIR"
mkdir -p "$TRACKING_DIR"
mkdir -p "$(dirname "$LOG_FILE")"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null || echo "")

# Only process Edit, Write
case "$TOOL_NAME" in
    Edit|Write) ;;
    *)
        trap - EXIT  # CRIT-003: Clear trap before explicit output
        echo '{"decision": "allow"}'
        exit 0
        ;;
esac

# Get file path being edited
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""' 2>/dev/null || echo "")

if [[ -z "$FILE_PATH" ]]; then
    trap - EXIT  # CRIT-003: Clear trap before explicit output
    echo '{"decision": "allow"}'
    exit 0
fi

log "Checking: $TOOL_NAME on $FILE_PATH"

# Check cooldown
LAST_CHECKPOINT_FILE="$TRACKING_DIR/last-checkpoint-time"
NOW=$(date +%s)
if [[ -f "$LAST_CHECKPOINT_FILE" ]]; then
    LAST_TIME=$(cat "$LAST_CHECKPOINT_FILE" 2>/dev/null || echo "0")
    ELAPSED=$((NOW - LAST_TIME))
    if [[ "$ELAPSED" -lt "$COOLDOWN_SECONDS" ]]; then
        log "Cooldown active ($ELAPSED < $COOLDOWN_SECONDS)"
        trap - EXIT  # CRIT-003: Clear trap before explicit output
        echo '{"decision": "allow"}'
        exit 0
    fi
fi

# Check if file was already edited this session
# FIX RACE-001: Use atomic mkdir for check-and-set to prevent race condition
# SEC-104: Use SHA-256 instead of MD5 for cryptographic hash
FILE_HASH=$(echo "$FILE_PATH" | shasum -a 256 | cut -d' ' -f1)
EDITED_FLAG="$TRACKING_DIR/edited-$FILE_HASH"
LOCK_DIR="${EDITED_FLAG}.lock.d"

# Atomic check-and-set using mkdir (atomic on POSIX)
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    # Another process is handling this or already edited
    log "File already being processed or edited: $FILE_PATH"
    trap - EXIT  # CRIT-003: Clear trap before explicit output
    echo '{"decision": "allow"}'
    exit 0
fi
# CRIT-003: Update trap to clean lock AND clear on exit
trap 'rmdir "$LOCK_DIR" 2>/dev/null || true' EXIT

# SEC-105: Atomic check-and-create using noclobber (O_EXCL)
# This eliminates TOCTOU gap - single syscall for check+create
# noclobber translates to open(path, O_CREAT | O_EXCL | O_WRONLY, 0666)
if ! (set -C; echo "$$" > "$EDITED_FLAG") 2>/dev/null; then
    # File already exists - another process beat us to it
    log "File already edited this session (atomic check): $FILE_PATH"
    rmdir "$LOCK_DIR" 2>/dev/null || true  # Clean lock before exit
    trap - EXIT  # CRIT-003: Clear trap before explicit output
    echo '{"decision": "allow"}'
    exit 0
fi

# File successfully created with our PID - we're the first editor
# No need for touch - noclobber already created the file

# Determine if checkpoint is needed
TRIGGER_REASON=""
SHOULD_CHECKPOINT="false"

# Check 1: Plan complexity >= 7
if [[ -f "$PLAN_STATE" ]]; then
    COMPLEXITY=$(jq -r '.classification.complexity // 5' "$PLAN_STATE" 2>/dev/null || echo "5")
    if [[ "$COMPLEXITY" -ge 7 ]]; then
        SHOULD_CHECKPOINT="true"
        TRIGGER_REASON="high_complexity"
        log "Trigger: high_complexity ($COMPLEXITY)"
    fi

    # Check 2: High risk step (auth/security/payment)
    CURRENT_STEP=$(jq -r '[.steps | to_entries[] | select(.value.status == "in_progress")] | .[0].value.name // ""' "$PLAN_STATE" 2>/dev/null || echo "")
    if echo "$CURRENT_STEP" | grep -qiE '(auth|security|payment|credential|secret|encrypt|decrypt|password)'; then
        SHOULD_CHECKPOINT="true"
        TRIGGER_REASON="high_risk_step"
        log "Trigger: high_risk_step ($CURRENT_STEP)"
    fi
fi

# Check 3: Critical file patterns
FILENAME=$(basename "$FILE_PATH")
FILEPATH_LOWER=$(echo "$FILE_PATH" | tr '[:upper:]' '[:lower:]')

# Critical files
if echo "$FILEPATH_LOWER" | grep -qE '(config|settings|\.env|database|schema|migration|api|route)'; then
    SHOULD_CHECKPOINT="true"
    TRIGGER_REASON="${TRIGGER_REASON:-critical_file}"
    log "Trigger: critical_file ($FILENAME)"
fi

# Check 4: Security files
if echo "$FILEPATH_LOWER" | grep -qE '(auth|secret|credential|password|token|key|cert|pem)'; then
    SHOULD_CHECKPOINT="true"
    TRIGGER_REASON="${TRIGGER_REASON:-security_file}"
    log "Trigger: security_file ($FILENAME)"
fi

if [[ "$SHOULD_CHECKPOINT" == "true" ]]; then
    # Create checkpoint
    CHECKPOINT_NAME="smart-$(date +%Y%m%d-%H%M%S)"
    CHECKPOINT_PATH="$CHECKPOINT_DIR/$CHECKPOINT_NAME"
    mkdir -p "$CHECKPOINT_PATH"

    log "Creating checkpoint: $CHECKPOINT_NAME (reason: $TRIGGER_REASON)"

    # Save plan-state
    if [[ -f "$PLAN_STATE" ]]; then
        cp "$PLAN_STATE" "$CHECKPOINT_PATH/plan-state.json"
    fi

    # Save orchestrator analysis if exists
    if [[ -f ".claude/orchestrator-analysis.md" ]]; then
        cp ".claude/orchestrator-analysis.md" "$CHECKPOINT_PATH/"
    fi

    # Save git status
    git status --porcelain > "$CHECKPOINT_PATH/git-status.txt" 2>/dev/null || true

    # Save unstaged diff
    git diff > "$CHECKPOINT_PATH/git-diff.patch" 2>/dev/null || true

    # Create metadata - SEC-002: Use jq for safe JSON construction
    jq -n \
        --arg name "$CHECKPOINT_NAME" \
        --arg created_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        --arg trigger "$TRIGGER_REASON" \
        --arg file_path "$FILE_PATH" \
        --arg tool "$TOOL_NAME" \
        --arg complexity "${COMPLEXITY:-unknown}" \
        '{name: $name, created_at: $created_at, trigger: $trigger,
          file_path: $file_path, tool: $tool, complexity: $complexity, type: "smart"}' \
        > "$CHECKPOINT_PATH/metadata.json"

    # Update last checkpoint time
    echo "$NOW" > "$LAST_CHECKPOINT_FILE"

    # Cleanup old smart checkpoints (keep last N)
    SMART_CHECKPOINTS=$(ls -dt "$CHECKPOINT_DIR"/smart-* 2>/dev/null | tail -n +$((MAX_SMART_CHECKPOINTS + 1)))
    if [[ -n "$SMART_CHECKPOINTS" ]]; then
        echo "$SMART_CHECKPOINTS" | xargs rm -rf
        log "Cleaned old checkpoints"
    fi

    log "Checkpoint saved: $CHECKPOINT_NAME"
fi

# CRIT-003: Clean lock and clear trap before explicit JSON output
rmdir "$LOCK_DIR" 2>/dev/null || true
trap - EXIT
echo '{"decision": "allow"}'
