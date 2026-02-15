#!/bin/bash
# glm5-subagent-stop.sh - Handle GLM-5 subagent completion
#
# VERSION: 2.84.1
#
# This hook is triggered when a GLM-5 teammate subagent stops.
# Uses the SubagentStop event which EXISTS in Claude Code v2.1.39.
#
# Triggered by: SubagentStop hook event
# Matcher: * (all subagents) or specific agent pattern

set -euo pipefail

# Project root detection
PROJECT_ROOT="${PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
RALPH_DIR="${PROJECT_ROOT}/.ralph"

# Log function
log() {
    mkdir -p "${RALPH_DIR}/logs"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "${RALPH_DIR}/logs/glm5-subagent.log"
}

# SEC-111: Read input from stdin with length limit (100KB max)
stdin_data=""
if [[ -t 0 ]]; then
    log "No stdin data available"
else
    stdin_data=$(head -c 100000)
fi

log "SubagentStop triggered"
log "Stdin: ${stdin_data:-empty}"

# Extract agent info from stdin if available
agent_id=$(echo "$stdin_data" | jq -r '.agentId // .agent_id // "unknown"' 2>/dev/null || echo "unknown")
agent_type=$(echo "$stdin_data" | jq -r '.agentType // .agent_type // "unknown"' 2>/dev/null || echo "unknown")
task_id=$(echo "$stdin_data" | jq -r '.taskId // .task_id // "unknown"' 2>/dev/null || echo "unknown")

log "Agent: ${agent_id} (${agent_type}), Task: ${task_id}"

# Check if this is a GLM-5 agent
if [[ "$agent_type" == *"glm5"* ]] || [[ "$agent_id" == *"glm5"* ]]; then
    log "GLM-5 subagent stopped: ${agent_id}"

    # Update team status if team-status.json exists
    team_status_file="${RALPH_DIR}/team-status.json"
    if [[ -f "$team_status_file" ]]; then
        # Mark agent as completed
        tmp_file=$(mktemp)
        jq --arg agent "$agent_id" --arg time "$(date -Iseconds)" '
            if .teammates then
                .teammates[$agent].status = "completed" |
                .teammates[$agent].completed_at = $time
            else
                .
            end |
            .last_updated = $time
        ' "$team_status_file" > "$tmp_file" && mv "$tmp_file" "$team_status_file"

        log "Updated team status for ${agent_id}"
    fi

    # Check if reasoning file exists
    reasoning_file="${RALPH_DIR}/reasoning/${task_id}.txt"
    if [[ -f "$reasoning_file" ]]; then
        reasoning_size=$(wc -c < "$reasoning_file")
        log "Reasoning file exists: ${reasoning_file} (${reasoning_size} bytes)"
    fi
fi

# Output for Claude Code - SubagentStop expects this format
cat <<EOF
{"decision": "approve", "reason": "GLM-5 subagent completion handled"}
EOF
