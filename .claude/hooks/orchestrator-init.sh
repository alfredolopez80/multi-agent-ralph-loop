#!/bin/bash
# orchestrator-init.sh - Orchestrator Initialization Hook
# Hook: SessionStart
# Purpose: Initialize orchestrator state, memory buffers, and plan-state
#
# When: Triggered at session start (auto via SessionStart hook)
# What: Ensures all orchestrator components are ready
#
# v2.57.0: Created as part of Memory System Reconstruction
# - Initializes agent memory buffers
# - Sets up plan-state if not exists
# - Validates procedural memory accessibility
#
# VERSION: 2.69.0
# SECURITY: SEC-006 compliant

# SEC-111: Read input from stdin with length limit (100KB max)
# Prevents DoS from malicious input
INPUT=$(head -c 100000)


set -euo pipefail

# Error trap: only on ERR, not EXIT (EXIT would print text after JSON output)
trap 'echo "SessionStart orchestrator-init recovery"' ERR

umask 077

# Paths - Initialize all variables before use
RALPH_DIR="${HOME}/.ralph"
LOG_DIR="${RALPH_DIR}/logs"

# MemPalace v3.0: plan-state is LOCAL (repo-specific), always
CWD=$(echo "$INPUT" | jq -r '.cwd // "."' 2>/dev/null || echo ".")
PLAN_STATE="${CWD}/.claude/plan-state.json"
# If local doesn't exist, create a clean empty plan-state
if [[ ! -f "$PLAN_STATE" ]]; then
    mkdir -p "$(dirname "$PLAN_STATE")"
    cat > "$PLAN_STATE" << 'PLANEOF'
{
  "version": "3.0.0",
  "plan_name": null,
  "plan_file": null,
  "current_phase": null,
  "active_agent": "",
  "classification": { "workflow_route": null, "adaptive_mode": null },
  "phases": [], "barriers": {}, "steps": [],
  "metadata": { "session_id": null, "started_at": null }
}
PLANEOF
fi

SESSION_ID=""
START_TIME=""

# Create directories FIRST (critical for set -e)
mkdir -p "$LOG_DIR"

# Logging function
log() {
    echo "[orchestrator-init] $(date -Iseconds): $1" >> "${LOG_DIR}/orchestrator-init.log" 2>&1 || true
}

log "=== Orchestrator Session Initialization ==="

# 1. [MemPalace v3.0] Agent memory is now in Obsidian Vault:
#    ~/Documents/Obsidian/MiVault/agents/{agent-name}/diary/
#    No local buffer creation needed — removed in Wave 5 cleanup.

# 2. [MemPalace v3.0] Procedural memory is now in .claude/rules/learned/
#    (halls/rooms/wings taxonomy). No separate init needed — removed in Wave 5 cleanup.

# 3. Initialize or migrate plan-state (LOCAL path — MemPalace v3.0)
if [[ ! -f "$PLAN_STATE" ]]; then
    log "Creating new plan-state at: $PLAN_STATE"
    mkdir -p "$(dirname "$PLAN_STATE")"
    # SEC-2.2: Acquire lock before writing plan-state
    _ps_lock="${PLAN_STATE}.lock"
    _ps_attempt=0
    while ! mkdir "$_ps_lock" 2>/dev/null; do
        _ps_attempt=$((_ps_attempt + 1))
        [[ $_ps_attempt -ge 50 ]] && break
        sleep 0.1
    done
    cat > "$PLAN_STATE" << 'EOF'
{
  "version": "3.0.0",
  "plan_name": null,
  "plan_file": null,
  "current_phase": null,
  "active_agent": "",
  "classification": {
    "workflow_route": null,
    "adaptive_mode": null
  },
  "phases": [],
  "barriers": {},
  "steps": [],
  "metadata": {
    "session_id": null,
    "started_at": null
  }
}
EOF
    # SEC-2.2: Release lock
    rmdir "$_ps_lock" 2>/dev/null || true
else
    # Validate existing plan-state
    if jq empty "$PLAN_STATE" 2>/dev/null; then
        log "Existing plan-state validated: $PLAN_STATE"
    else
        log "WARNING: Invalid plan-state JSON, backing up and resetting"
        cp "$PLAN_STATE" "${PLAN_STATE}.backup.$(date +%Y%m%d%H%M%S)" 2>/dev/null || true
    fi
fi

# 4. Record session start
SESSION_ID=$(openssl rand -hex 16 2>/dev/null || echo "session_$$")
START_TIME=$(date -Iseconds)

log "Session ID: $SESSION_ID"
log "Start Time: $START_TIME"

# Update plan-state with session info if it exists
if [[ -f "$PLAN_STATE" ]]; then
    # Update metadata using temporary file
    TEMP_PLAN="${PLAN_STATE}.tmp.$$"
    jq --arg session_id "$SESSION_ID" \
       --arg started_at "$START_TIME" \
       '
       .metadata.session_id = $session_id |
       .metadata.started_at = $started_at
       ' "$PLAN_STATE" > "$TEMP_PLAN" 2>/dev/null && mv "$TEMP_PLAN" "$PLAN_STATE"
fi

# 5. Clean old logs (keep last 7 days)
find "$LOG_DIR" -name "orchestrator-*.log" -mtime +7 -delete 2>/dev/null || true

log "=== Initialization Complete ==="

# SessionStart hook output format (per CLAUDE.md conventions)
echo "{\"hookSpecificOutput\": {\"hookEventName\": \"SessionStart\", \"initialized\": true, \"session_id\": \"$SESSION_ID\"}}"
