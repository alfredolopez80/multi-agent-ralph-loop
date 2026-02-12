#!/bin/bash
# .claude/hooks/glm5-teammate-idle.sh
# Native TeammateIdle hook for GLM-5 teammate status tracking (project-scoped)
# Version: 2.84.0
# Fires when: An agent team teammate is about to go idle after finishing its turn

set -e

# Read hook input from stdin
read -r INPUT

# === Get Project Root ===
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || echo ".")}"

# === Extract Teammate Info ===
TEAMMATE_ID=$(echo "$INPUT" | jq -r '.teammate_id // empty')
TASK_STATUS=$(echo "$INPUT" | jq -r '.task_status // empty')
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')

# === Directories ===
RALPH_DIR="${PROJECT_ROOT}/.ralph"
STATUS_DIR="${RALPH_DIR}/teammates"
LOGS_DIR="${RALPH_DIR}/logs"
TEAM_STATUS="${RALPH_DIR}/team-status.json"

mkdir -p "$LOGS_DIR"

# === Logging Function ===
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [TeammateIdle] $1" >> "${LOGS_DIR}/teammates.log"
}

# === Find Latest Status File ===
LATEST_STATUS=$(find "$STATUS_DIR" -name "status.json" -mmin -5 2>/dev/null | head -1)

if [ -n "$LATEST_STATUS" ]; then
    # Read status
    STATUS=$(cat "$LATEST_STATUS")
    TASK_ID=$(echo "$STATUS" | jq -r '.task_id // empty')
    AGENT_TYPE=$(echo "$STATUS" | jq -r '.agent_type // empty')
    REASONING_FILE=$(echo "$STATUS" | jq -r '.reasoning_file // empty')

    # === Log Teammate Completion ===
    log "Teammate idle: ${AGENT_TYPE} (task: ${TASK_ID}, status: ${TASK_STATUS})"

    # === Update Team Status ===
    if [ -f "$TEAM_STATUS" ]; then
        jq --arg agent "$AGENT_TYPE" \
           --arg task "$TASK_ID" \
           --arg status "$TASK_STATUS" \
           --arg teammate "$TEAMMATE_ID" \
           '.completed_tasks += [{
               "agent": $agent,
               "task": $task,
               "status": $status,
               "teammate_id": $teammate,
               "timestamp": (now | todate)
           }]' "$TEAM_STATUS" > /tmp/ts.json 2>/dev/null && mv /tmp/ts.json "$TEAM_STATUS"

        log "Team status updated"
    fi

    # === Quality Gate Check (Optional) ===
    # Uncomment to enforce quality gates before allowing teammate to go idle
    # if [ -z "$REASONING_FILE" ] || [ ! -f "$REASONING_FILE" ]; then
    #     log "Blocking idle: No reasoning file found"
    #     echo '{"decision": "block", "reason": "No reasoning captured for this task"}'
    #     exit 0
    # fi

    # === Return Decision ===
    # Provide context to orchestrator about what was completed
    echo "{\"decision\": \"approve\", \"reason\": \"Teammate ${AGENT_TYPE} completed task ${TASK_ID}\", \"systemMessage\": \"GLM-5 teammate ${AGENT_TYPE} completed task ${TASK_ID}. Reasoning available at ${REASONING_FILE}.\"}"
else
    log "No status file found for teammate ${TEAMMATE_ID}"
    echo '{"decision": "approve"}'
fi
