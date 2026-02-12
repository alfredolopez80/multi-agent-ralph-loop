#!/bin/bash
# .claude/hooks/glm5-task-completed.sh
# Native TaskCompleted hook for GLM-5 task completion tracking (project-scoped)
# Version: 2.84.0
# Fires when: A task is being marked as completed

set -e

# Read hook input from stdin
read -r INPUT

# === Get Project Root ===
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || echo ".")}"

# === Extract Task Info ===
TASK_ID=$(echo "$INPUT" | jq -r '.task_id // empty')
COMPLETED_BY=$(echo "$INPUT" | jq -r '.completed_by // empty')
RESULT=$(echo "$INPUT" | jq -r '.result // empty')
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')

# === Directories ===
RALPH_DIR="${PROJECT_ROOT}/.ralph"
LOGS_DIR="${RALPH_DIR}/logs"
TEAM_STATUS="${RALPH_DIR}/team-status.json"

mkdir -p "$LOGS_DIR"

# === Logging Function ===
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [TaskCompleted] $1" >> "${LOGS_DIR}/tasks.log"
}

# === Log Task Completion ===
log "Task completed: ${TASK_ID} by ${COMPLETED_BY} (result: ${RESULT})"

# === Check for Reasoning File ===
REASONING_FILE="${RALPH_DIR}/reasoning/${TASK_ID}.txt"
if [ -f "$REASONING_FILE" ]; then
    REASONING_CONTENT=$(cat "$REASONING_FILE")
    REASONING_CHARS=${#REASONING_CONTENT}
    log "Reasoning captured: ${REASONING_CHARS} chars"

    # Also log to reasoning log
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Reasoning for task ${TASK_ID}: ${REASONING_CHARS} chars" >> "${LOGS_DIR}/reasoning.log"
else
    log "No reasoning file found for task ${TASK_ID}"
fi

# === Update Team Status ===
if [ -f "$TEAM_STATUS" ]; then
    jq --arg task "$TASK_ID" \
       --arg agent "$COMPLETED_BY" \
       --arg result "$RESULT" \
       --arg reasoning "$REASONING_FILE" \
       '.completed_tasks += [{
           "task_id": $task,
           "agent": $agent,
           "result": $result,
           "reasoning_file": $reasoning,
           "timestamp": (now | todate)
       }]' "$TEAM_STATUS" > /tmp/ts.json 2>/dev/null && mv /tmp/ts.json "$TEAM_STATUS"

    log "Team status updated"
fi

# === Quality Gate Check (Optional) ===
# Uncomment to block task completion if quality gates not met
# if [ "$RESULT" != "SUCCESS" ]; then
#     log "Blocking completion: Task result is not SUCCESS"
#     echo '{"decision": "block", "reason": "Task did not complete successfully"}'
#     exit 0
# fi

# === Approve Task Completion ===
echo "{\"decision\": \"approve\", \"reason\": \"Task ${TASK_ID} completed by ${COMPLETED_BY}\", \"systemMessage\": \"Task ${TASK_ID} marked as completed. Result: ${RESULT}.\"}"
