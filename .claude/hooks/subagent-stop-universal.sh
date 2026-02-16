#!/usr/bin/env bash
# subagent-stop-universal.sh - Universal quality gate for ALL subagent termination
# VERSION: 2.90.1
# Event: SubagentStop
# Matcher: * (all subagents, model-agnostic)
#
# Replaces: glm5-subagent-stop.sh (which was GLM-5 specific)
# Companion: ralph-subagent-stop.sh (ralph-* specific quality gates)
#
# This hook applies to ALL subagents regardless of model (glm5, claude-opus,
# minimax, sonnet, etc). It handles:
#   1. Logging subagent completion
#   2. Updating team status
#   3. Basic quality verification
#
# Exit codes:
#   0 - Approve stop
#   2 - Block stop with feedback

set -euo pipefail

# Project root detection
PROJECT_ROOT="${PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
RALPH_DIR="${HOME}/.ralph"
LOG_DIR="${RALPH_DIR}/logs"

mkdir -p "$LOG_DIR"

# Log function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [subagent-stop-universal] $*" >> "${LOG_DIR}/hooks.log"
}

# SEC-111: Read input from stdin with length limit (100KB max)
stdin_data=""
if [[ -t 0 ]]; then
    log "No stdin data available"
else
    stdin_data=$(head -c 100000)
fi

log "SubagentStop triggered"

# Extract agent info from stdin - support multiple field name conventions
agent_id=$(echo "$stdin_data" | jq -r '.agentId // .agent_id // .subagentId // .teammate_name // "unknown"' 2>/dev/null || echo "unknown")
agent_type=$(echo "$stdin_data" | jq -r '.agentType // .agent_type // .subagentType // "unknown"' 2>/dev/null || echo "unknown")
task_id=$(echo "$stdin_data" | jq -r '.taskId // .task_id // ""' 2>/dev/null || echo "")
session_id=$(echo "$stdin_data" | jq -r '.sessionId // .session_id // "default"' 2>/dev/null || echo "default")

log "Agent: ${agent_id} (${agent_type}), Task: ${task_id}, Session: ${session_id}"

# ============================================
# CHECK 1: Update team status (model-agnostic)
# ============================================

team_status_file="${RALPH_DIR}/team-status.json"
if [[ -f "$team_status_file" ]]; then
    tmp_file=$(mktemp)
    if jq --arg agent "$agent_id" --arg time "$(date -Iseconds)" --arg type "$agent_type" '
        if .teammates then
            .teammates[$agent].status = "completed" |
            .teammates[$agent].completed_at = $time |
            .teammates[$agent].type = $type
        else
            .
        end |
        .last_updated = $time
    ' "$team_status_file" > "$tmp_file" 2>/dev/null; then
        mv "$tmp_file" "$team_status_file"
        log "Updated team status for ${agent_id}"
    else
        rm -f "$tmp_file"
    fi
fi

# ============================================
# CHECK 2: Verify subagent state (if tracked)
# ============================================

subagent_state="${RALPH_DIR}/state/${session_id}/subagents/${agent_id}.json"
if [[ -f "$subagent_state" ]]; then
    status=$(jq -r '.status // "unknown"' "$subagent_state" 2>/dev/null || echo "unknown")
    if [[ "$status" == "working" ]]; then
        log "BLOCK: Subagent $agent_id still has status 'working'"
        echo "Subagent still has active work - complete your tasks before stopping" >&2
        exit 2
    fi

    # Update state to completed
    jq --arg time "$(date -Iseconds)" '. + {status: "completed", stopped_at: $time}' \
        "$subagent_state" > "${subagent_state}.tmp" && mv "${subagent_state}.tmp" "$subagent_state"
    log "Subagent state updated to completed"
fi

# ============================================
# CHECK 3: Check reasoning/output artifacts
# ============================================

if [[ -n "$task_id" ]]; then
    reasoning_file="${RALPH_DIR}/reasoning/${task_id}.txt"
    if [[ -f "$reasoning_file" ]]; then
        reasoning_size=$(wc -c < "$reasoning_file")
        log "Reasoning file exists: ${reasoning_file} (${reasoning_size} bytes)"
    fi
fi

# ============================================
# All checks passed - approve stop
# ============================================

log "APPROVE: Subagent ${agent_id} (${agent_type}) can stop"
cat <<EOF
{"decision": "approve", "reason": "Subagent completion verified (model-agnostic)"}
EOF
exit 0
