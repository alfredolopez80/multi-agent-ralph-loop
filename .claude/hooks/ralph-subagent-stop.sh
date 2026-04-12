#!/bin/bash
# ralph-subagent-stop.sh - Quality gate for ralph-* subagent termination
# VERSION: 2.95.0
# Event: SubagentStop
# Matcher: ralph-*
#
# Validates that a ralph-* subagent can safely terminate:
# 1. All assigned tasks completed
# 2. No blocking issues in state files
# 3. Quality gates passed
# 4. Worktree cleanup (v2.95.0)
# 5. Merge conflict detection (v2.95.0)
#
# Exit codes:
#   0 - Approve stop
#   2 - Block stop with feedback

set -uo pipefail

_HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${_HOOK_DIR}/lib/worktree-utils.sh" 2>/dev/null || true

STATE_DIR="$HOME/.ralph/state"
LOG_DIR="$HOME/.ralph/logs"

# Ensure directories exist
mkdir -p "$LOG_DIR"

# SEC-111: Read stdin with length limit (100KB max) to prevent DoS
INPUT=$(head -c 100000)
SUBAGENT_ID=$(echo "$INPUT" | jq -r '.subagentId // "unknown"')
SUBAGENT_TYPE=$(echo "$INPUT" | jq -r '.subagentType // "unknown"')
SESSION_ID=$(echo "$INPUT" | jq -r '.sessionId // "default"')
TASK_ID=$(echo "$INPUT" | jq -r '.taskId // ""')

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ralph-subagent-stop] $1" >> "$LOG_DIR/hooks.log"
}

log "SubagentStop: ${SUBAGENT_ID} (${SUBAGENT_TYPE}) session=${SESSION_ID}"

# Check 1: Verify subagent has no incomplete tasks
SUBAGENT_STATE="$STATE_DIR/$SESSION_ID/subagents/${SUBAGENT_ID}.json"
if [[ -f "$SUBAGENT_STATE" ]]; then
    STATUS=$(jq -r '.status // "unknown"' "$SUBAGENT_STATE" 2>/dev/null || echo "unknown")
    if [[ "$STATUS" == "working" ]]; then
        log "BLOCK: Subagent $SUBAGENT_ID still working"
        cat <<EOF
{"decision": "block", "reason": "Subagent still has active work", "feedback": "Complete your assigned tasks before stopping"}
EOF
        exit 2
    fi
fi

# Check 2: Check team task status if this subagent was assigned a task
if [[ -n "$TASK_ID" ]]; then
    TEAMS_DIR="$HOME/.claude/teams"
    for team_config in "$TEAMS_DIR"/*/config.json; do
        [[ -f "$team_config" ]] || continue
        TEAM_NAME=$(jq -r '.name // "unknown"' "$team_config" 2>/dev/null)
        TASK_FILE="$HOME/.claude/tasks/$TEAM_NAME/${TASK_ID}.json"

        if [[ -f "$TASK_FILE" ]]; then
            TASK_STATUS=$(jq -r '.status // "unknown"' "$TASK_FILE" 2>/dev/null)
            if [[ "$TASK_STATUS" == "pending" || "$TASK_STATUS" == "in_progress" ]]; then
                log "BLOCK: Task $TASK_ID not completed (status: $TASK_STATUS)"
                cat <<EOF
{"decision": "block", "reason": "Assigned task not completed", "feedback": "Task $TASK_ID is still $TASK_STATUS. Mark it complete or report blockers."}
EOF
                exit 2
            fi
        fi
    done
fi

# Check 3: Check for quality gate failures
QUALITY_STATE="$STATE_DIR/$SESSION_ID/quality-gate.json"
if [[ -f "$QUALITY_STATE" ]]; then
    GATE_PASSED=$(jq -r '.passed // true' "$QUALITY_STATE" 2>/dev/null)
    if [[ "$GATE_PASSED" == "false" ]]; then
        GATE_REASON=$(jq -r '.reason // "Unknown quality issue"' "$QUALITY_STATE" 2>/dev/null)
        log "BLOCK: Quality gate failed - $GATE_REASON"
        cat <<EOF
{"decision": "block", "reason": "Quality gate failed", "feedback": "$GATE_REASON - Fix quality issues before stopping"}
EOF
        exit 2
    fi
fi

# Check 4: Update subagent state to completed
if [[ -f "$SUBAGENT_STATE" ]]; then
    jq --arg time "$(date -Iseconds)" '. + {status: "completed", stopped_at: $time}' "$SUBAGENT_STATE" > "${SUBAGENT_STATE}.tmp" && mv "${SUBAGENT_STATE}.tmp" "$SUBAGENT_STATE"
    log "Subagent state updated to completed"
fi

# All checks passed - approve stop
log "APPROVE: Subagent $SUBAGENT_ID can stop"

# ============================================
# v2.95.0: Worktree cleanup for write-capable agents
# ============================================
CLEANUP_INFO=""

is_write_agent() {
  case "$SUBAGENT_TYPE" in
    ralph-coder|ralph-frontend|ralph-tester) return 0 ;;
    *) return 1 ;;
  esac
}

if is_write_agent; then
  # Reconstruct slug from subagent ID (same logic as start hook)
  WT_SLUG=$(echo "$SUBAGENT_ID" | sed "s/[^a-zA-Z0-9_-]//g" | cut -c1-64)
  if [[ -n "$WT_SLUG" ]]; then
    WT_DIR="$(get_main_repo)/.claude/worktrees/$WT_SLUG"
    if [[ -d "$WT_DIR" ]]; then
      # v2.95.0: Merge-conflict detection (dry-run)
      MERGE_CONFLICTS=""
      if (cd "$WT_DIR" && git log --oneline -1 2>/dev/null | grep -q . 2>/dev/null); then
        MAIN_REPO="$(get_main_repo)"
        CONFLICT_OUTPUT=$(cd "$MAIN_REPO" && git merge --no-commit --no-ff "worktree-$WT_SLUG" 2>&1) || true
        if echo "$CONFLICT_OUTPUT" | grep -q "CONFLICT"; then
          CONFLICT_FILES=$(cd "$MAIN_REPO" && git diff --name-only --diff-filter=U 2>/dev/null || echo "")
          MERGE_CONFLICTS="$CONFLICT_FILES"
          log "MERGE CONFLICT detected in worktree $WT_SLUG: $CONFLICT_FILES"
          # Abort the merge dry-run
          (cd "$MAIN_REPO" && git merge --abort 2>/dev/null || true)
        else
          # No conflicts — abort the dry-run merge
          (cd "$MAIN_REPO" && git merge --abort 2>/dev/null || true)
        fi
      fi

      # Check for uncommitted changes before cleanup
      if (cd "$WT_DIR" && git diff --quiet 2>/dev/null && git diff --cached --quiet 2>/dev/null); then
        removeWorktree "$WT_SLUG" 2>/dev/null || true
        log "Worktree cleaned up: $WT_SLUG"
        CLEANUP_INFO="worktree_cleaned"
      else
        # Has uncommitted changes — log warning but don't block stop
        log "WARNING: Worktree $WT_SLUG has uncommitted changes, preserving"
        CLEANUP_INFO="worktree_preserved_uncommitted"
      fi

      # Append conflict info to cleanup
      if [[ -n "$MERGE_CONFLICTS" ]]; then
        CLEANUP_INFO="${CLEANUP_INFO}|merge_conflicts:${MERGE_CONFLICTS}"
      fi
    else
      CLEANUP_INFO="no_worktree_found"
    fi
  fi
fi

# Output approval with cleanup info
if [[ -n "$CLEANUP_INFO" ]]; then
  echo "{\"decision\": \"approve\", \"reason\": \"All subagent tasks completed and quality gates passed\", \"cleanup\": \"$CLEANUP_INFO\"}"
else
  echo "{\"decision\": \"approve\", \"reason\": \"All subagent tasks completed and quality gates passed\"}"
fi
exit 0
