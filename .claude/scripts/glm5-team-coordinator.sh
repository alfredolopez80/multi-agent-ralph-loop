#!/bin/bash
# .claude/scripts/glm5-team-coordinator.sh
# Coordinates GLM-5 teammates via project-scoped file-based status
# Version: 2.84.0

set -e

# === Configuration ===
TEAM_NAME="${1:-ralph-team-$(date +%Y%m%d-%H%M%S)}"
TASK_FILE="${2:-}"
COMMAND="${3:-init}"

# Validate MAX_TEAMMATES is a number (default to 4)
if [[ "$COMMAND" =~ ^[0-9]+$ ]]; then
    MAX_TEAMMATES="$COMMAND"
    COMMAND="init"
else
    MAX_TEAMMATES="${4:-4}"
fi

# Ensure MAX_TEAMMATES is a valid number
if ! [[ "$MAX_TEAMMATES" =~ ^[0-9]+$ ]]; then
    MAX_TEAMMATES=4
fi

# === Get Project Root ===
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || echo ".")}"

# === Directories ===
RALPH_DIR="${PROJECT_ROOT}/.ralph"
STATUS_DIR="${RALPH_DIR}/teammates"
TEAM_STATUS="${RALPH_DIR}/team-status.json"
LOGS_DIR="${RALPH_DIR}/logs"

mkdir -p "$STATUS_DIR" "$LOGS_DIR"

# === Logging ===
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [Coordinator] $1" >> "${LOGS_DIR}/coordinator.log"
}

# === Initialize Team Status ===
init_team() {
    cat > "$TEAM_STATUS" << EOF
{
  "team_name": "${TEAM_NAME}",
  "project": "${PROJECT_ROOT}",
  "created": "$(date -Iseconds)",
  "status": "initializing",
  "completed_tasks": [],
  "pending_tasks": [],
  "active_teammates": 0,
  "max_teammates": ${MAX_TEAMMATES},
  "version": "2.84.0"
}
EOF
    log "Team initialized: ${TEAM_NAME}"
}

# === Add Task to Queue ===
add_task() {
    local task_id="$1"
    local description="$2"
    local agent_type="$3"

    if [ -f "$TEAM_STATUS" ]; then
        jq --arg id "$task_id" \
           --arg desc "$description" \
           --arg agent "$agent_type" \
           '.pending_tasks += [{
               "id": $id,
               "description": $desc,
               "agent_type": $agent,
               "status": "pending",
               "created": (now | todate)
           }]' "$TEAM_STATUS" > /tmp/ts.json && mv /tmp/ts.json "$TEAM_STATUS"
        log "Task added: ${task_id} (${agent_type})"
    fi
}

# === Spawn Teammate ===
spawn_teammate() {
    local task_id="$1"
    local agent_type="$2"
    local task_description="$3"

    local script="${PROJECT_ROOT}/.claude/scripts/glm5-teammate.sh"

    if [ -x "$script" ]; then
        log "Spawning teammate: ${agent_type} for task ${task_id}"

        # Run teammate in background
        "$script" "$agent_type" "$task_description" "$task_id" &
        local pid=$!

        # Update team status
        if [ -f "$TEAM_STATUS" ]; then
            jq --arg pid "$pid" \
               --arg task "$task_id" \
               '.active_teammates += 1' "$TEAM_STATUS" > /tmp/ts.json && mv /tmp/ts.json "$TEAM_STATUS"
        fi

        echo "Spawned ${agent_type} (PID: ${pid}, Task: ${task_id})"
    else
        log "ERROR: Teammate script not executable: ${script}"
        return 1
    fi
}

# === Check Team Status ===
check_status() {
    if [ -f "$TEAM_STATUS" ]; then
        local pending=$(jq '.pending_tasks | length' "$TEAM_STATUS")
        local completed=$(jq '.completed_tasks | length' "$TEAM_STATUS")
        local active=$(jq '.active_teammates' "$TEAM_STATUS")

        echo "Team: ${TEAM_NAME}"
        echo "  Pending tasks: ${pending}"
        echo "  Completed tasks: ${completed}"
        echo "  Active teammates: ${active}"
    else
        echo "Team status file not found"
    fi
}

# === Parse Tasks from File ===
parse_tasks() {
    if [ -n "$TASK_FILE" ] && [ -f "$TASK_FILE" ]; then
        local task_num=0
        jq -c '.subtasks[]' "$TASK_FILE" | while read -r subtask; do
            task_num=$((task_num + 1))
            local task_id="${TEAM_NAME}-task-${task_num}"
            local description=$(echo "$subtask" | jq -r '.description')
            local agent_type=$(echo "$subtask" | jq -r '.agent_type // "coder"')

            add_task "$task_id" "$description" "$agent_type"
        done
        log "Parsed tasks from: ${TASK_FILE}"
    fi
}

# === Main ===
main() {
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║         GLM-5 Team Coordinator v2.84.0                       ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
    echo "📁 Project: ${PROJECT_ROOT}"
    echo "🏷️  Team: ${TEAM_NAME}"
    echo "👥 Max teammates: ${MAX_TEAMMATES}"
    echo ""

    # Initialize team
    init_team

    # Parse tasks if file provided
    if [ -n "$TASK_FILE" ]; then
        parse_tasks
    fi

    # Show status
    check_status

    echo ""
    echo "✅ Team coordinator initialized"
    echo ""
    echo "Usage:"
    echo "  Add task:    ralph team add-task <task_id> <description> <agent_type>"
    echo "  Spawn:       ralph team spawn <task_id> <agent_type> <description>"
    echo "  Status:      ralph team status"
}

# Handle subcommands
case "${COMMAND:-}" in
    "add-task")
        add_task "$2" "$3" "$4"
        ;;
    "spawn")
        spawn_teammate "$2" "$3" "$4"
        ;;
    "status")
        check_status
        ;;
    "init")
        init_team
        check_status
        ;;
    *)
        main "$@"
        ;;
esac
