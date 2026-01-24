#!/bin/bash
# Reflection Engine - Cold Path Processing (v2.49.0)
# Hook: Stop
# Purpose: Extract patterns and update memory after session ends
#
# Runs asynchronously to not block session exit.
# Processes:
# 1. Extract episode from session transcript
# 2. Detect behavioral patterns
# 3. Update procedural rules
# 4. Cleanup old episodes
#
# VERSION: 2.49.0

set -euo pipefail
umask 077

# Parse input
INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null || echo "unknown")

# Config check
CONFIG_FILE="$HOME/.ralph/config/memory-config.json"
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo '{"decision": "continue"}'
    exit 0
fi

# Check if cold path is enabled
COLD_PATH_ENABLED=$(jq -r '.cold_path.enabled // true' "$CONFIG_FILE" 2>/dev/null || echo "true")
REFLECTION_ON_STOP=$(jq -r '.cold_path.reflection_on_stop // true' "$CONFIG_FILE" 2>/dev/null || echo "true")

if [[ "$COLD_PATH_ENABLED" != "true" ]] || [[ "$REFLECTION_ON_STOP" != "true" ]]; then
    echo '{"decision": "continue"}'
    exit 0
fi

# Log directory
LOG_DIR="$HOME/.ralph/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/reflection-$(date +%Y%m%d).log"

# Reflection script
REFLECTION_SCRIPT="$HOME/.claude/scripts/reflection-executor.py"
if [[ ! -f "$REFLECTION_SCRIPT" ]]; then
    echo '{"decision": "continue"}'
    exit 0
fi

# Find session transcript
# Claude Code stores transcripts in ~/.claude/projects/<project-hash>/<session-id>.jsonl
PROJECT_DIR="$HOME/.claude/projects"
TRANSCRIPT=""

# Try to find matching transcript
if [[ -d "$PROJECT_DIR" ]] && [[ "$SESSION_ID" != "unknown" ]]; then
    TRANSCRIPT=$(find "$PROJECT_DIR" -name "${SESSION_ID}*.jsonl" -type f 2>/dev/null | head -1 || echo "")
fi

# Run reflection in background (non-blocking)
{
    echo "[$(date -Iseconds)] Starting reflection for session: $SESSION_ID"

    # Set environment for reflection
    export SESSION_ID
    export PROJECT="${PWD##*/}"

    if [[ -n "$TRANSCRIPT" ]] && [[ -f "$TRANSCRIPT" ]]; then
        echo "[$(date -Iseconds)] Extracting episode from: $TRANSCRIPT"
        python3 "$REFLECTION_SCRIPT" extract "$TRANSCRIPT" 2>&1 || true
    else
        echo "[$(date -Iseconds)] No transcript found, skipping episode extraction"
    fi

    # Pattern detection (runs regardless of transcript)
    echo "[$(date -Iseconds)] Detecting patterns..."
    python3 "$REFLECTION_SCRIPT" patterns 2>&1 || true

    # Cleanup old episodes (weekly check)
    CLEANUP_MARKER="$HOME/.ralph/state/.last-cleanup"
    WEEK_AGO=$(date -v-7d +%Y%m%d 2>/dev/null || date -d "7 days ago" +%Y%m%d 2>/dev/null || echo "0")
    LAST_CLEANUP="0"
    [[ -f "$CLEANUP_MARKER" ]] && LAST_CLEANUP=$(cat "$CLEANUP_MARKER" 2>/dev/null || echo "0")

    if [[ "$LAST_CLEANUP" < "$WEEK_AGO" ]]; then
        echo "[$(date -Iseconds)] Running weekly cleanup..."
        python3 "$REFLECTION_SCRIPT" cleanup 2>&1 || true
        mkdir -p "$HOME/.ralph/state"
        date +%Y%m%d > "$CLEANUP_MARKER"
    fi

    echo "[$(date -Iseconds)] Reflection complete"
} >> "$LOG_FILE" 2>&1 &

# Return immediately (don't block session exit)
echo '{"decision": "continue", "reflection": {"triggered": true, "session_id": "'"$SESSION_ID"'"}}'
