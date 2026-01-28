#!/bin/bash
# Reflection Engine - Cold Path Processing (v2.68.12)
# v2.68.12: BUG-001 FIX - Integer comparison (< → -lt) for date strings
# Hook: Stop
# Purpose: Extract patterns and update memory after session ends
#
# Runs asynchronously to not block session exit.
# Processes:
# 1. Extract episode from session transcript (multi-source fallback)
# 2. Detect behavioral patterns
# 3. Update procedural rules
# 4. Cleanup old episodes
#
# VERSION: 2.69.0
# v2.55: Multi-source transcript fallback (claude-projects → ralph-ledger → ralph-handoff)
#        Added content verification (-s flag) to skip empty files
# v2.53: FIXED - Stop hooks use {"decision": "approve|block"} per official Claude Code docs
# SECURITY: Added ERR trap for guaranteed JSON output, SESSION_ID escaping

# SEC-111: Read input from stdin with length limit (100KB max)
# Prevents DoS from malicious input
INPUT=$(head -c 100000)


set -euo pipefail
umask 077

# Guaranteed JSON output on any error (SEC-006)
# v2.53.0 FIX: Stop hooks use {"decision": "approve|block"}, NOT {"continue": bool}
output_json() {
    echo '{"decision": "approve"}'
}
trap 'output_json' ERR EXIT

# Helper: Escape string for JSON (SEC-001)
escape_json() {
    local str="$1"
    # Remove control characters and escape quotes/backslashes
    printf '%s' "$str" | tr -d '\000-\037' | sed 's/\\/\\\\/g; s/"/\\"/g'
}

# Parse input
# CRIT-001 FIX: Removed duplicate stdin read - SEC-111 already reads at top
RAW_SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null || echo "unknown")
# Validate and sanitize SESSION_ID (alphanumeric, dash, underscore only)
SESSION_ID=$(echo "$RAW_SESSION_ID" | tr -cd 'a-zA-Z0-9_-' | head -c 64)

# Config check
CONFIG_FILE="$HOME/.ralph/config/memory-config.json"
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo '{"decision": "approve"}'
    exit 0
fi

# Check if cold path is enabled
COLD_PATH_ENABLED=$(jq -r '.cold_path.enabled // true' "$CONFIG_FILE" 2>/dev/null || echo "true")
REFLECTION_ON_STOP=$(jq -r '.cold_path.reflection_on_stop // true' "$CONFIG_FILE" 2>/dev/null || echo "true")

if [[ "$COLD_PATH_ENABLED" != "true" ]] || [[ "$REFLECTION_ON_STOP" != "true" ]]; then
    echo '{"decision": "approve"}'
    exit 0
fi

# Log directory
LOG_DIR="$HOME/.ralph/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/reflection-$(date +%Y%m%d).log"

# Reflection script
REFLECTION_SCRIPT="$HOME/.claude/scripts/reflection-executor.py"
if [[ ! -f "$REFLECTION_SCRIPT" ]]; then
    echo '{"decision": "approve"}'
    exit 0
fi

# Find session transcript (v2.55: Multiple source fallback)
# Sources checked in order:
# 1. Claude Code transcripts: ~/.claude/projects/<project-hash>/<session-id>.jsonl
# 2. Ralph ledgers: ~/.ralph/ledgers/CONTINUITY_RALPH-<session>.md
# 3. Ralph handoffs: ~/.ralph/handoffs/<session>/
PROJECT_DIR="$HOME/.claude/projects"
RALPH_LEDGERS="$HOME/.ralph/ledgers"
RALPH_HANDOFFS="$HOME/.ralph/handoffs"
TRANSCRIPT=""
TRANSCRIPT_SOURCE=""

# Source 1: Claude Code transcripts
if [[ -d "$PROJECT_DIR" ]] && [[ "$SESSION_ID" != "unknown" ]]; then
    CANDIDATE=$(find "$PROJECT_DIR" -name "${SESSION_ID}*.jsonl" -type f 2>/dev/null | head -1 || echo "")
    # v2.55: Only use if file has content (>0 bytes)
    if [[ -n "$CANDIDATE" ]] && [[ -s "$CANDIDATE" ]]; then
        TRANSCRIPT="$CANDIDATE"
        TRANSCRIPT_SOURCE="claude-projects"
    fi
fi

# Source 2: Ralph ledgers (fallback)
if [[ -z "$TRANSCRIPT" ]] && [[ -d "$RALPH_LEDGERS" ]]; then
    CANDIDATE=$(find "$RALPH_LEDGERS" -name "*${SESSION_ID}*" -type f 2>/dev/null | head -1 || echo "")
    if [[ -n "$CANDIDATE" ]] && [[ -s "$CANDIDATE" ]]; then
        TRANSCRIPT="$CANDIDATE"
        TRANSCRIPT_SOURCE="ralph-ledger"
    fi
fi

# Source 3: Ralph handoffs (last resort)
if [[ -z "$TRANSCRIPT" ]] && [[ -d "$RALPH_HANDOFFS" ]]; then
    # Get the most recent handoff file
    CANDIDATE=$(find "$RALPH_HANDOFFS" -name "handoff-*.md" -type f 2>/dev/null | sort -r | head -1 || echo "")
    if [[ -n "$CANDIDATE" ]] && [[ -s "$CANDIDATE" ]]; then
        TRANSCRIPT="$CANDIDATE"
        TRANSCRIPT_SOURCE="ralph-handoff"
    fi
fi

# Run reflection in background (non-blocking)
{
    echo "[$(date -Iseconds)] Starting reflection for session: $SESSION_ID"

    # Set environment for reflection
    export SESSION_ID
    export PROJECT="${PWD##*/}"

    if [[ -n "$TRANSCRIPT" ]] && [[ -f "$TRANSCRIPT" ]]; then
        echo "[$(date -Iseconds)] Extracting episode from: $TRANSCRIPT (source: $TRANSCRIPT_SOURCE)"
        python3 "$REFLECTION_SCRIPT" extract "$TRANSCRIPT" --source "$TRANSCRIPT_SOURCE" 2>&1 || true
    else
        echo "[$(date -Iseconds)] No transcript found (checked: claude-projects, ralph-ledger, ralph-handoff)"
        echo "[$(date -Iseconds)] Session ID: $SESSION_ID"
        # Still run pattern detection from existing episodes
    fi

    # Pattern detection (runs regardless of transcript)
    echo "[$(date -Iseconds)] Detecting patterns..."
    python3 "$REFLECTION_SCRIPT" patterns 2>&1 || true

    # Cleanup old episodes (weekly check)
    CLEANUP_MARKER="$HOME/.ralph/state/.last-cleanup"
    WEEK_AGO=$(date -v-7d +%Y%m%d 2>/dev/null || date -d "7 days ago" +%Y%m%d 2>/dev/null || echo "0")
    LAST_CLEANUP="0"
    [[ -f "$CLEANUP_MARKER" ]] && LAST_CLEANUP=$(cat "$CLEANUP_MARKER" 2>/dev/null || echo "0")

    # BUG-001: Use -lt for numeric comparison (not < which is string comparison)
    if [[ "$LAST_CLEANUP" -lt "$WEEK_AGO" ]]; then
        echo "[$(date -Iseconds)] Running weekly cleanup..."
        python3 "$REFLECTION_SCRIPT" cleanup 2>&1 || true
        mkdir -p "$HOME/.ralph/state"
        date +%Y%m%d > "$CLEANUP_MARKER"
    fi

    echo "[$(date -Iseconds)] Reflection complete"
} >> "$LOG_FILE" 2>&1 &

# Return immediately (don't block session exit)
# v2.53.0 FIX: Stop hooks use {"decision": "approve|block"} per official Claude Code docs
# suppressOutput tells Claude not to display hook output to user
echo '{"decision": "approve", "suppressOutput": true}'
