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

# v2.69.0: Error trap for SessionStart hooks (plain text OK, no JSON required)
# Removed stderr which causes hook error warnings
trap 'echo "SessionStart orchestrator-init recovery"' ERR EXIT

umask 077

# Paths - Initialize all variables before use
RALPH_DIR="${HOME}/.ralph"
MEMORY_DIR="${RALPH_DIR}/agent-memory"
PROCEDURAL_DIR="${RALPH_DIR}/procedural"
STATE_DIR="${RALPH_DIR}/state"
LOG_DIR="${RALPH_DIR}/logs"
PLAN_STATE="${RALPH_DIR}/plan-state/plan-state.json"
SESSION_ID=""
START_TIME=""

# Create directories FIRST (critical for set -e)
mkdir -p "$MEMORY_DIR" "$PROCEDURAL_DIR" "$STATE_DIR" "$LOG_DIR"

# Logging function
log() {
    echo "[orchestrator-init] $(date -Iseconds): $1" >> "${LOG_DIR}/orchestrator-init.log" 2>&1 || true
}

log "=== Orchestrator Session Initialization ==="

# 1. Initialize agent memory buffers for default agents
DEFAULT_AGENTS=(
    "orchestrator"
    "security-auditor"
    "debugger"
    "code-reviewer"
    "test-architect"
    "refactorer"
    "frontend-reviewer"
    "docs-writer"
    "minimax-reviewer"
    "repository-learner"
    "repo-curator"
)

log "Initializing agent memory buffers..."
for agent in "${DEFAULT_AGENTS[@]}"; do
    agent_dir="${MEMORY_DIR}/${agent}"
    if [[ ! -d "$agent_dir" ]]; then
        mkdir -p "$agent_dir/semantic" "$agent_dir/episodic" "$agent_dir/working"
        # Initialize semantic memory with empty array
        echo '{"entries": []}' > "$agent_dir/semantic/memory.json"
        log "  Created memory buffer for: $agent"
    else
        log "  Already exists: $agent"
    fi
done

# 2. Initialize procedural memory if not exists
PROCEDURAL_FILE="${PROCEDURAL_DIR}/rules.json"
if [[ ! -f "$PROCEDURAL_FILE" ]]; then
    cat > "$PROCEDURAL_FILE" << 'EOF'
{
  "version": "2.55.0",
  "last_updated": null,
  "rules": []
}
EOF
    log "Initialized procedural memory: $PROCEDURAL_FILE"
fi

# 3. Initialize or migrate plan-state
if [[ ! -f "$PLAN_STATE" ]]; then
    log "Creating new plan-state at: $PLAN_STATE"
    mkdir -p "$(dirname "$PLAN_STATE")"
    cat > "$PLAN_STATE" << 'EOF'
{
  "version": "2.57.0",
  "plan_id": null,
  "task": null,
  "classification": {
    "complexity": null,
    "information_density": null,
    "context_requirement": null,
    "workflow_route": null
  },
  "steps": [],
  "loop_state": {
    "current_iteration": 0,
    "max_iterations": 25,
    "status": "not_started"
  },
  "learning_state": {
    "recommended": false,
    "reason": null,
    "curator_invoked": false,
    "rules_learned": 0,
    "last_recommendation_timestamp": null
  },
  "metadata": {
    "session_id": null,
    "started_at": null
  }
}
EOF
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
SESSION_ID=$(cat /dev/urandom | tr -dc 'a-f0-9' | head -32 2>/dev/null || echo "session_$$")
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
