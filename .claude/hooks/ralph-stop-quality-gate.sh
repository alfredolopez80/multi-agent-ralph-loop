#!/bin/bash
# ralph-stop-quality-gate.sh - Quality gate for Stop event
# VERSION: 2.88.0
# REPO: multi-agent-ralph-loop
#
# Triggered by: Stop hook event
# Purpose: Prevent Claude from stopping until VERIFIED_DONE conditions are met
#          Implements "Ralph Wiggum Loop" pattern
#
# Exit codes:
#   0 = Allow Claude to stop
#   2 = Block stop + send feedback to continue working
#
# Input (stdin JSON):
#   {
#     "session_id": "abc123",
#     "transcript_path": "~/.claude/projects/.../transcript.jsonl",
#     "cwd": "/Users/...",
#     "permission_mode": "default",
#     "hook_event_name": "Stop",
#     "stop_hook_active": false    // CRITICAL: Check this to prevent infinite loops!
#   }
#
# Output (stdout JSON):
#   {"decision": "approve", "reason": "All conditions met"}
#   {"decision": "block", "reason": "Specific issues to fix"}
#
# IMPORTANT:
#   - ALWAYS check stop_hook_active first to prevent infinite loops
#   - When stop_hook_active is true, MUST exit 0 to allow stop
#   - Provide actionable feedback in the reason field
#
# v2.88.0 Changes:
#   - Added teammate state verification (Finding #2)
#   - Added block state tracking with escalation (Finding #3)
#   - Added session isolation and cleanup (Finding #5)
#
# Reference: docs/hooks/STOP_HOOK_INTEGRATION_ANALYSIS.md

set -euo pipefail

# Configuration
REPO_ROOT="/Users/alfredolopez/Documents/GitHub/multi-agent-ralph-loop"
STATE_DIR="$HOME/.ralph/state"
LOG_DIR="$HOME/.ralph/logs"
BLOCK_STATE_DIR="$STATE_DIR"
SESSION_MAX_AGE=86400  # 24 hours in seconds
MAX_BLOCKS=5           # Max blocks before escalation
mkdir -p "$LOG_DIR"

# Read stdin
INPUT=$(cat)

# ============================================
# CRITICAL: Check stop_hook_active to prevent infinite loops
# ============================================

STOP_HOOK_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false')
if [ "$STOP_HOOK_ACTIVE" = "true" ]; then
    # Claude is already continuing from a previous block
    # MUST allow stop to prevent infinite loop
    echo '{"decision": "approve", "reason": "Previous block already active - allowing stop to prevent infinite loop"}'
    exit 0
fi

# Extract session info
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"')
CWD=$(echo "$INPUT" | jq -r '.cwd // "."')

# Log the event
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Stop hook fired: session=$SESSION_ID stop_hook_active=$STOP_HOOK_ACTIVE" >> "$LOG_DIR/stop-hook.log"

# ============================================
# v2.88.0: Session Isolation (Finding #5)
# ============================================

SESSION_FILE="$STATE_DIR/${SESSION_ID}/session.json"
if [[ ! -f "$SESSION_FILE" ]]; then
    # No active session, check for stale sessions to cleanup
    # SEC: Validate STATE_DIR before deletion, use -delete for files only
    if [[ -n "$STATE_DIR" && "$STATE_DIR" == *"/.ralph/"* ]]; then
        find "$STATE_DIR" -mindepth 2 -name "session.json" -mtime +1 -delete 2>/dev/null || true
    fi
    echo '{"decision": "approve", "reason": "No active session"}'
    exit 0
fi

# Check session age
SESSION_AGE=$(jq -r '.age_seconds // 0' "$SESSION_FILE" 2>/dev/null || echo "0")
if [[ "$SESSION_AGE" -gt "$SESSION_MAX_AGE" ]]; then
    # Stale session, cleanup and allow stop
    rm -rf "$STATE_DIR/${SESSION_ID}" 2>/dev/null || true
    echo '{"decision": "approve", "reason": "Stale session cleaned up"}'
    exit 0
fi

# Initialize issues
BLOCKING_ISSUES=""
ADVISORY_ISSUES=""

# ============================================
# VERIFIED_DONE CONDITION CHECKS
# ============================================

# Check 1: Is there an active orchestrator session?
ORCHESTRATOR_STATE="$STATE_DIR/${SESSION_ID}/orchestrator.json"
if [ -f "$ORCHESTRATOR_STATE" ]; then
    VERIFIED_DONE=$(jq -r '.verified_done // false' "$ORCHESTRATOR_STATE" 2>/dev/null || echo "false")
    CURRENT_PHASE=$(jq -r '.phase // "unknown"' "$ORCHESTRATOR_STATE" 2>/dev/null || echo "unknown")

    if [ "$VERIFIED_DONE" != "true" ]; then
        # Check which conditions are not met
        CONDITIONS=$(jq -r '.conditions // {}' "$ORCHESTRATOR_STATE" 2>/dev/null || echo "{}")

        # Check each condition
        IMPL_COMPLETE=$(echo "$CONDITIONS" | jq -r '.implementation_complete // false' 2>/dev/null || echo "false")
        CORRECTNESS_PASSED=$(echo "$CONDITIONS" | jq -r '.correctness_passed // false' 2>/dev/null || echo "false")
        QUALITY_PASSED=$(echo "$CONDITIONS" | jq -r '.quality_passed // false' 2>/dev/null || echo "false")

        if [ "$IMPL_COMPLETE" != "true" ]; then
            BLOCKING_ISSUES+="Implementation not complete. "
        fi
        if [ "$CORRECTNESS_PASSED" = "false" ]; then
            BLOCKING_ISSUES+="CORRECTNESS gate failed (syntax/build errors). "
        fi
        if [ "$QUALITY_PASSED" = "false" ]; then
            BLOCKING_ISSUES+="QUALITY gate failed (type/lint errors). "
        fi

        if [ -z "$BLOCKING_ISSUES" ]; then
            BLOCKING_ISSUES+="Orchestrator phase '$CURRENT_PHASE' not complete. "
        fi
    fi
fi

# Check 2: Is there an active loop session?
LOOP_STATE="$STATE_DIR/${SESSION_ID}/loop.json"
if [ -f "$LOOP_STATE" ]; then
    VERIFIED_DONE=$(jq -r '.verified_done // false' "$LOOP_STATE" 2>/dev/null || echo "false")
    ITERATION=$(jq -r '.iteration // 0' "$LOOP_STATE" 2>/dev/null || echo "0")
    MAX_ITERATIONS=$(jq -r '.max_iterations // 25' "$LOOP_STATE" 2>/dev/null || echo "25")
    VALIDATION_RESULT=$(jq -r '.validation_result // "unknown"' "$LOOP_STATE" 2>/dev/null || echo "unknown")
    LAST_ERROR=$(jq -r '.last_error // ""' "$LOOP_STATE" 2>/dev/null || echo "")

    if [ "$VERIFIED_DONE" != "true" ] && [ "$ITERATION" -lt "$MAX_ITERATIONS" ]; then
        if [ -n "$LAST_ERROR" ]; then
            BLOCKING_ISSUES+="Loop iteration $ITERATION/$MAX_ITERATIONS - Last error: $LAST_ERROR. "
        else
            BLOCKING_ISSUES+="Loop iteration $ITERATION/$MAX_ITERATIONS - validation result: $VALIDATION_RESULT. "
        fi
    fi
fi

# Check 3: Are there pending tasks in a team task list?
TEAMS_DIR="$HOME/.claude/teams"
if [ -d "$TEAMS_DIR" ]; then
    # Find any team config for current project
    for team_config in "$TEAMS_DIR"/*/config.json; do
        if [ -f "$team_config" ]; then
            TEAM_NAME=$(jq -r '.team_name // ""' "$team_config" 2>/dev/null || echo "")
            if [ -n "$TEAM_NAME" ]; then
                TASKS_DIR="$HOME/.claude/tasks/$TEAM_NAME"
                if [ -d "$TASKS_DIR" ]; then
                    PENDING_COUNT=$(find "$TASKS_DIR" -name "*.json" -exec jq -r '.status // "unknown"' {} \; 2>/dev/null | grep -c "pending\|in_progress" || echo "0")
                    if [ "$PENDING_COUNT" -gt 0 ]; then
                        BLOCKING_ISSUES+="$PENDING_COUNT pending/in-progress team tasks. "
                        break  # Only report once
                    fi
                fi
            fi
        fi
    done
fi

# Check 3b (v2.88.0): Are all teammates idle and healthy? (Finding #2)
if [ -d "$TEAMS_DIR" ]; then
    for team_config in "$TEAMS_DIR"/*/config.json; do
        [[ -f "$team_config" ]] || continue
        TEAM_NAME=$(jq -r '.name // ""' "$team_config" 2>/dev/null)
        MEMBERS_DIR="$(dirname "$team_config")/members"

        if [[ -d "$MEMBERS_DIR" ]]; then
            for member_file in "$MEMBERS_DIR"/*.json; do
                [[ -f "$member_file" ]] || continue
                MEMBER_NAME=$(basename "$member_file" .json)
                MEMBER_STATUS=$(jq -r '.status // "unknown"' "$member_file" 2>/dev/null)
                MEMBER_ERROR=$(jq -r '.last_error // ""' "$member_file" 2>/dev/null)

                if [[ "$MEMBER_STATUS" == "working" ]]; then
                    BLOCKING_ISSUES+="Teammate $MEMBER_NAME still working. "
                fi

                if [[ -n "$MEMBER_ERROR" && "$MEMBER_ERROR" != "null" ]]; then
                    BLOCKING_ISSUES+="Teammate $MEMBER_NAME has error: ${MEMBER_ERROR:0:100}. "
                fi
            done
        fi
    done
fi

# Check 4: Did the last quality gate fail?
QUALITY_STATE="$STATE_DIR/${SESSION_ID}/quality-gate.json"
if [ -f "$QUALITY_STATE" ]; then
    LAST_RESULT=$(jq -r '.last_result // "unknown"' "$QUALITY_STATE" 2>/dev/null || echo "unknown")
    if [ "$LAST_RESULT" = "failed" ]; then
        FAILED_STAGES=$(jq -r '.stages | to_entries[] | select(.value.status == "failed") | .key' "$QUALITY_STATE" 2>/dev/null || echo "")
        if [ -n "$FAILED_STAGES" ]; then
            BLOCKING_ISSUES+="Quality stages failed: $(echo $FAILED_STAGES | tr '\n' ', '). "
        else
            BLOCKING_ISSUES+="Quality gate failed. "
        fi
    fi
fi

# Check 5 (Advisory): Are there uncommitted changes?
if [ -d "$CWD/.git" ]; then
    UNCOMMITTED=$(cd "$CWD" && git status --porcelain 2>/dev/null | head -5 || echo "")
    if [ -n "$UNCOMMITTED" ]; then
        FILE_COUNT=$(echo "$UNCOMMITTED" | wc -l | tr -d ' ')
        ADVISORY_ISSUES+="$FILE_COUNT uncommitted files (advisory). "
    fi
fi

# Check 6 (Advisory): Are there TODO/FIXME in recently modified files?
if [ -d "$CWD/.git" ]; then
    RECENT_TODOS=$(cd "$CWD" && git diff --name-only HEAD~1 2>/dev/null | head -10 | xargs grep -l "TODO\|FIXME" 2>/dev/null | head -3 || echo "")
    if [ -n "$RECENT_TODOS" ]; then
        ADVISORY_ISSUES+="TODO/FIXME in recent changes (advisory). "
    fi
fi

# ============================================
# DECISION OUTPUT
# ============================================

# v2.88.0: Block State Tracking (Finding #3)
# Track blocks for escalation and audit trail
track_block() {
    local reason="$1"
    BLOCK_STATE="$STATE_DIR/${SESSION_ID}/blocks.json"
    mkdir -p "$(dirname "$BLOCK_STATE")"

    BLOCK_COUNT=$(jq -r '.block_count // 0' "$BLOCK_STATE" 2>/dev/null || echo "0")

    jq -n \
        --argjson count $((BLOCK_COUNT + 1)) \
        --arg reason "$reason" \
        --arg time "$(date -Iseconds)" \
        --argjson prev_blocks "$(jq '.blocks // []' "$BLOCK_STATE" 2>/dev/null || echo '[]')" \
        '{
            block_count: $count,
            last_block: {reason: $reason, time: $time},
            blocks: ($prev_blocks + [{reason: $reason, time: $time}])
        }' > "$BLOCK_STATE"

    # Check for escalation (too many blocks)
    if [[ $((BLOCK_COUNT + 1)) -ge $MAX_BLOCKS ]]; then
        jq '. + {escalate: true, escalate_reason: "Max blocks exceeded - manual intervention may be needed"}' "$BLOCK_STATE" > "${BLOCK_STATE}.tmp" && mv "${BLOCK_STATE}.tmp" "$BLOCK_STATE"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ESCALATE: Max blocks ($MAX_BLOCKS) exceeded" >> "$LOG_DIR/stop-hook.log"
    fi
}

# Log findings
if [ -n "$BLOCKING_ISSUES" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Stop BLOCKED: $BLOCKING_ISSUES" >> "$LOG_DIR/stop-hook.log"
fi
if [ -n "$ADVISORY_ISSUES" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Stop ADVISORY: $ADVISORY_ISSUES" >> "$LOG_DIR/stop-hook.log"
fi

# Make decision
if [ -n "$BLOCKING_ISSUES" ]; then
    # Block stop with specific feedback
    # Truncate if too long (Claude has context limits)
    REASON=$(echo "$BLOCKING_ISSUES" | cut -c1-500)

    # v2.88.0: Track this block for escalation
    track_block "$REASON"

    jq -n --arg reason "$REASON" '{
        decision: "block",
        reason: ("Quality gates not passed. " + $reason + "Continue working until VERIFIED_DONE.")
    }'
    exit 2
elif [ -n "$ADVISORY_ISSUES" ]; then
    # Advisory issues don't block, but log them
    echo '{"decision": "approve", "reason": "All blocking conditions met (advisory issues noted)"}'
    exit 0
else
    # All conditions met, allow stop
    echo '{"decision": "approve", "reason": "All VERIFIED_DONE conditions met"}'
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Stop APPROVED: All conditions met" >> "$LOG_DIR/stop-hook.log"
    exit 0
fi
