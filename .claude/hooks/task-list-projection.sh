#!/usr/bin/env bash
# task-list-projection.sh — Single source of truth for Claude Code TaskList
# VERSION: 1.0.0
# Events: TaskCreated, TaskCompleted
#
# Consolidates task tracking into ONE event-sourced projection at
# $CWD/.claude/tasks.json. Replaces task-plan-sync.sh (which duplicated
# tracking into plan-state.json). plan-state.json is reserved for
# orchestrator metadata (classification, workflow_route).
#
# Input stdin (Claude Code passes hook_event_name):
#   {
#     "hook_event_name": "TaskCreated" | "TaskCompleted",
#     "taskId": "...", "subject": "...", "status": "...", "owner": "..."
#   }
#
# Output stdout: {"continue": true}
#
# Projection schema ($CWD/.claude/tasks.json):
#   {
#     "version": "1.0",
#     "last_updated": "ISO-UTC",
#     "updated_at":   "ISO-UTC",
#     "total": N, "completed": M, "pct": 0-100,
#     "tasks": [
#       {"id","subject","status","owner","created_at","completed_at"}
#     ]
#   }

set -euo pipefail
umask 077

INPUT=$(head -c 100000)

trap 'echo "{\"continue\": true}"; exit 0' ERR

_HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1091
source "${_HOOK_DIR}/lib/plan-state-writer.sh"
# shellcheck disable=SC1091
source "${_HOOK_DIR}/lib/worktree-utils.sh" 2>/dev/null || {
    get_project_root() { git rev-parse --show-toplevel 2>/dev/null || echo "${CLAUDE_PROJECT_DIR:-$PWD}"; }
}

REPO_ROOT="$(get_project_root)"
TASKS_FILE="${REPO_ROOT}/.claude/tasks.json"
LOCK_DIR="${TASKS_FILE}.lock"
LOG_DIR="${HOME}/.ralph/logs"
mkdir -p "$LOG_DIR" "$(dirname "$TASKS_FILE")"
LOG_FILE="${LOG_DIR}/task-list-projection-$(date +%Y%m%d).log"

log() { echo "[$(date -Iseconds)] $*" >> "$LOG_FILE" 2>/dev/null || true; }

acquire_lock() {
    local timeout=10
    while [ $timeout -gt 0 ]; do
        if mkdir "$LOCK_DIR" 2>/dev/null; then return 0; fi
        sleep 1; timeout=$((timeout - 1))
    done
    return 1
}
release_lock() { rmdir "$LOCK_DIR" 2>/dev/null || true; }

EVENT=$(echo "$INPUT" | jq -r '.hook_event_name // empty')
TASK_ID=$(echo "$INPUT" | jq -r '.taskId // .task_id // empty')
SUBJECT=$(echo "$INPUT" | jq -r '.subject // ""')
STATUS=$(echo "$INPUT" | jq -r '.status // "pending"')
OWNER=$(echo "$INPUT" | jq -r '.owner // ""')

if [[ -z "$TASK_ID" ]]; then
    log "skip: no taskId (event=$EVENT)"
    echo '{"continue": true}'; exit 0
fi

# Create empty projection if missing
if [[ ! -f "$TASKS_FILE" ]]; then
    jq -n '{version:"1.0",last_updated:null,updated_at:null,total:0,completed:0,pct:0,tasks:[]}' > "$TASKS_FILE"
fi

acquire_lock || log "WARN: proceeding without lock"

case "$EVENT" in
    TaskCreated|"")
        # Upsert: if task exists, update; else append
        plan_state_update "$TASKS_FILE" '
            .tasks as $existing
            | (($existing | map(.id) | index($id)) // null) as $idx
            | if $idx == null then
                .tasks += [{id:$id, subject:$subj, status:$status, owner:$owner, created_at:(now|todate), completed_at:null}]
              else
                .tasks[$idx].status = $status
                | .tasks[$idx].subject = $subj
                | .tasks[$idx].owner = $owner
              end
            | .total = (.tasks | length)
            | .completed = ([.tasks[] | select(.status == "completed")] | length)
            | .pct = (if .total == 0 then 0 else ((.completed * 100) / .total | floor) end)
        ' --arg id "$TASK_ID" --arg subj "$SUBJECT" --arg status "$STATUS" --arg owner "$OWNER" \
        || log "ERROR: TaskCreated projection failed for $TASK_ID"
        ;;

    TaskCompleted)
        plan_state_update "$TASKS_FILE" '
            .tasks as $existing
            | (($existing | map(.id) | index($id)) // null) as $idx
            | if $idx == null then
                .tasks += [{id:$id, subject:$subj, status:"completed", owner:$owner, created_at:(now|todate), completed_at:(now|todate)}]
              else
                .tasks[$idx].status = "completed"
                | .tasks[$idx].completed_at = (now|todate)
                | (if $subj != "" then .tasks[$idx].subject = $subj else . end)
              end
            | .total = (.tasks | length)
            | .completed = ([.tasks[] | select(.status == "completed")] | length)
            | .pct = (if .total == 0 then 0 else ((.completed * 100) / .total | floor) end)
        ' --arg id "$TASK_ID" --arg subj "$SUBJECT" --arg owner "$OWNER" \
        || log "ERROR: TaskCompleted projection failed for $TASK_ID"
        ;;

    *)
        log "skip: unknown event=$EVENT"
        ;;
esac

release_lock

log "$EVENT $TASK_ID status=$STATUS"

echo '{"continue": true}'
exit 0
