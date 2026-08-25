#!/bin/bash
umask 077
# session-start-restore-context.sh - SessionStart Hook for Ralph v3.2.0
# Hook: SessionStart
# Restores context and plan state when a new session starts
#
# Input (JSON via stdin):
#   - hook_event_name: "SessionStart"
#   - session_id: New session identifier
#   - project_dir: Current working directory
#
# Output (JSON with hookSpecificOutput):
#   - additionalContext: Context to inject into the new session
#
# This hook ensures continuity across compaction boundaries by:
# 1. Detecting if this is a continuation session
# 2. Loading the most recent ledger
# 3. Restoring plan state if exists
# 4. Injecting context into the new session

# VERSION: 3.3.1
# UPDATED: 2026-08-26 (T67: ledger selection by worktree identity, fail-closed;
#          RALPH_RESTORE_CROSS_WORKTREE feature restores legacy behaviour)
set -euo pipefail

# Worktree-safe path resolution
_HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${_HOOK_DIR}/lib/worktree-utils.sh" 2>/dev/null || {
  get_project_root() { git rev-parse --show-toplevel 2>/dev/null || echo "${CLAUDE_PROJECT_DIR:-.}"; }
  get_main_repo() { get_project_root; }
}

# Configuration
# RALPH_* overrides exist for tests only; production always uses ~/.ralph.
LOG_FILE="${RALPH_LOG_FILE:-${HOME}/.ralph/logs/session-start-restore.log}"
LEDGER_DIR="${RALPH_LEDGER_DIR:-${HOME}/.ralph/ledgers}"
HANDOFF_DIR="${RALPH_HANDOFF_DIR:-${HOME}/.ralph/handoffs}"
PLAN_STATE_FILE=".claude/plan-state.json"
FEATURES_FILE="${RALPH_FEATURES_FILE:-${HOME}/.ralph/config/features.json}"
MAX_SUMMARY_LINES=50
MAX_CONTEXT_SIZE=8000  # Limit context size to avoid jq issues

# Ensure directories exist
mkdir -p "${HOME}/.ralph/logs" "$HANDOFF_DIR"

# Logging function
log() {
    echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] $*" >> "$LOG_FILE" 2>/dev/null || true
}

# Check feature flags
check_feature_enabled() {
    local feature="$1"
    local default="${2:-true}"

    if [[ -f "$FEATURES_FILE" ]]; then
        local value
        value=$(jq -r ".$feature // \"$default\"" "$FEATURES_FILE" 2>/dev/null || echo "$default")
        [[ "$value" == "true" ]]
    else
        [[ "$default" == "true" ]]
    fi
}

# Truncate context if too large
truncate_context() {
    local ctx="$1"
    local max_size="${2:-$MAX_CONTEXT_SIZE}"
    local len=${#ctx}

    if [[ $len -gt $max_size ]]; then
        echo "${ctx:0:$max_size}... [truncated]"
        log "INFO" "Context truncated from $len to $max_size bytes"
    else
        echo "$ctx"
    fi
}

# Get vault hints from Obsidian migrated observations (v3.2.0)
# Reads from ~/Documents/Obsidian/MiVault/migrated-from-claude-mem/decisions.json
get_vault_hints() {
    local project_name="$1"
    local hints=""
    local max_hints=5
    local vault_dir="${HOME}/Documents/Obsidian/MiVault/migrated-from-claude-mem"

    # Try decisions.json first (1283 entries for multi-agent-ralph-loop)
    if [[ -f "${vault_dir}/decisions.json" ]] && command -v jq &>/dev/null; then
        hints=$(jq -r --arg proj "$project_name" \
            '[.[] | select(.project == $proj)] | .[0:'"$max_hints"'][] | "- [decision] \(.title // .subtitle // "(untitled)")"' \
            "${vault_dir}/decisions.json" 2>/dev/null || echo "")

        # Fallback to refactors if no decisions for this project
        if [[ -z "$hints" ]] && [[ -f "${vault_dir}/refactors.json" ]]; then
            hints=$(jq -r --arg proj "$project_name" \
                '[.[] | select(.project == $proj)] | .[0:'"$max_hints"'][] | "- [refactor] \(.title // .subtitle // "(untitled)")"' \
                "${vault_dir}/refactors.json" 2>/dev/null || echo "")
        fi
    fi

    # If no hints from migrated data, try Obsidian vault wiki directly
    if [[ -z "$hints" ]] && [[ -d "${HOME}/Documents/Obsidian/MiVault/global/wiki" ]]; then
        hints=$(find "${HOME}/Documents/Obsidian/MiVault/global/wiki" -name "*.md" -type f -mtime -30 2>/dev/null | \
            head -$max_hints | xargs -I{} basename {} .md 2>/dev/null | \
            awk '{print "- [wiki] "$0}' || echo "")
    fi

    # If still no hints, return a helpful message
    if [[ -z "$hints" ]]; then
        hints="No recent observations found. Search ~/Documents/Obsidian/MiVault/ directly."
    fi

    echo "$hints"
}

# Get most recent file matching pattern (avoids pipefail issues with head)
get_most_recent_file() {
    local dir="$1"
    local pattern="$2"
    local recent=""

    # Use a while loop to avoid SIGPIPE issues with head
    while IFS= read -r -d '' file; do
        if [[ -z "$recent" ]] || [[ "$file" -nt "$recent" ]]; then
            recent="$file"
        fi
    done < <(find "$dir" -maxdepth 1 -name "$pattern" -type f -print0 2>/dev/null)

    echo "$recent"
}

# T67: ledger identity = the worktree toplevel the writer ran in.
# Writer contract (context-extractor.py): "Project: <cwd>" under ## Environment.
# "## Project:" is accepted for forward compatibility; nothing emits it today.
get_ledger_identity() {
    local identity
    identity=$(sed -n 's/^Project: //p' "$1" 2>/dev/null | head -1)
    if [[ -z "$identity" ]]; then
        identity=$(sed -n 's/^## Project: //p' "$1" 2>/dev/null | head -1)
    fi
    printf '%s' "${identity%/}"
}

# T67: filter by identity FIRST, pick most recent AFTER. The previous order
# (global most-recent, then a project check) both restored foreign ledgers
# when the check failed open AND masked our own older ledger behind a newer
# foreign one.
get_most_recent_ledger_for_identity() {
    local dir="$1"
    local identity="${2%/}"
    local recent=""
    local file ledger_id

    while IFS= read -r -d '' file; do
        ledger_id="$(get_ledger_identity "$file")"
        if [[ "$ledger_id" == "$identity" ]]; then
            if [[ -z "$recent" ]] || [[ "$file" -nt "$recent" ]]; then
                recent="$file"
            fi
        fi
    done < <(find "$dir" -maxdepth 1 -name "CONTINUITY_RALPH-*.md" -type f -print0 2>/dev/null)

    echo "$recent"
}

# SEC-111: Read stdin with length limit (100KB max) to prevent DoS
INPUT=$(head -c 100000)

# Parse input
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null || echo "unknown")
# SEC-029: Sanitize session_id
SESSION_ID=$(echo "$SESSION_ID" | tr -cd 'a-zA-Z0-9_-' | head -c 64)
[[ -z "$SESSION_ID" ]] && SESSION_ID="unknown"

# Get project directory (worktree-safe: resolves to main repo root)
PROJECT_DIR="$(get_main_repo 2>/dev/null || pwd)"
PROJECT_NAME="$(basename "$PROJECT_DIR")"

log "INFO" "SessionStart hook triggered - session: $SESSION_ID, project: $PROJECT_NAME"

# Check if context restoration is enabled
if ! check_feature_enabled "RALPH_RESTORE_CONTEXT" "true"; then
    log "INFO" "Context restoration disabled via features.json"
    # SessionStart hooks don't need JSON output when no context
    exit 0
fi

# Build context injection
CONTEXT="## Session Context Restored\n\n"
CONTEXT+="**Session ID**: ${SESSION_ID}\n"
CONTEXT+="**Project**: ${PROJECT_NAME}\n"
CONTEXT+="**Time**: $(date -u +"%Y-%m-%dT%H:%M:%SZ")\n\n"

# Flag to track if we found any context
FOUND_CONTEXT=false

# 1. Check for plan state in current project
if [[ -f "${PROJECT_DIR}/${PLAN_STATE_FILE}" ]]; then
    log "INFO" "Found plan-state.json in project"

    PLAN_STATUS=$(jq -r '.plan.status // "unknown"' "${PROJECT_DIR}/${PLAN_STATE_FILE}" 2>/dev/null || echo "unknown")

    if [[ "$PLAN_STATUS" == "in_progress" ]]; then
        CONTEXT+="### Active Plan\n\n"
        CONTEXT+="There is an **active plan** in progress for this project.\n\n"

        # Extract plan summary
        PLAN_SUMMARY=$(jq -r '.plan.summary // "No summary available"' "${PROJECT_DIR}/${PLAN_STATE_FILE}" 2>/dev/null || echo "No summary")
        CONTEXT+="**Summary**: ${PLAN_SUMMARY}\n\n"

        # Extract current step
        CURRENT_STEP=$(jq -r '.current_step // "unknown"' "${PROJECT_DIR}/${PLAN_STATE_FILE}" 2>/dev/null || echo "unknown")
        if [[ "$CURRENT_STEP" != "unknown" && "$CURRENT_STEP" != "null" ]]; then
            CONTEXT+="**Current Step**: ${CURRENT_STEP}\n\n"
        fi

        # Extract progress
        TOTAL_STEPS=$(jq -r '.steps | length' "${PROJECT_DIR}/${PLAN_STATE_FILE}" 2>/dev/null || echo "0")
        COMPLETED_STEPS=$(jq -r '[.steps[] | select(.status == "completed")] | length' "${PROJECT_DIR}/${PLAN_STATE_FILE}" 2>/dev/null || echo "0")

        if [[ "$TOTAL_STEPS" -gt 0 ]]; then
            PROGRESS=$((COMPLETED_STEPS * 100 / TOTAL_STEPS))
            CONTEXT+="**Progress**: ${COMPLETED_STEPS}/${TOTAL_STEPS} steps completed (${PROGRESS}%)\n\n"
        fi

        FOUND_CONTEXT=true
        log "INFO" "Plan context added - status: $PLAN_STATUS, step: $CURRENT_STEP"
    fi
fi

# 2. Look for recent ledger for this worktree
# FIXED v3.3.1 (T67): select by worktree identity, not global mtime.
# ~/.ralph/ledgers is shared by every session of every worktree, so "most
# recent file" restored whichever session ended last (measured 2026-08-26:
# 4,668 of 7,916 restores since 2026-01-30 crossed identities). The old
# project check was dead code twice over: it grepped "^## Project:", a
# format no writer emits (fail-open on empty), and compared against
# get_main_repo, which collapses every worktree to the repo root.
# Identity on the read side is get_project_root — this worktree's toplevel.
RESTORE_IDENTITY="$(get_project_root 2>/dev/null || pwd)"

if check_feature_enabled "RALPH_RESTORE_CROSS_WORKTREE" "false"; then
    # Annotated escape hatch: legacy behaviour — most recent ledger globally.
    MOST_RECENT_LEDGER=$(get_most_recent_file "$LEDGER_DIR" "CONTINUITY_RALPH-*.md")
    if [[ -n "$MOST_RECENT_LEDGER" ]]; then
        log "INFO" "Cross-worktree restore enabled via features.json: $MOST_RECENT_LEDGER"
    fi
else
    MOST_RECENT_LEDGER=$(get_most_recent_ledger_for_identity "$LEDGER_DIR" "$RESTORE_IDENTITY")
fi

if [[ -n "$MOST_RECENT_LEDGER" && -f "$MOST_RECENT_LEDGER" ]]; then
    log "INFO" "Found recent ledger (identity: $RESTORE_IDENTITY): $MOST_RECENT_LEDGER"

    CONTEXT+="### Recent Session Context\n\n"
    CONTEXT+="Context restored from most recent ledger:\n\n"

    # Add ledger summary (first MAX_SUMMARY_LINES lines)
    LEDGER_SUMMARY=$(head -n "$MAX_SUMMARY_LINES" "$MOST_RECENT_LEDGER" 2>/dev/null || echo "Unable to read ledger")
    CONTEXT+="\`\`\`\n${LEDGER_SUMMARY}\n\`\`\`\n\n"

    FOUND_CONTEXT=true
    log "INFO" "Ledger context added"
else
    # Fail-closed: no ledger belongs to this worktree. Restoring a foreign
    # one injects another session's task state (T67); restore nothing.
    log "INFO" "No ledger for identity ${RESTORE_IDENTITY}; skipping cross-worktree restore"
fi

# 3. Look for recent handoff
SESSION_HANDOFF_DIR="${HANDOFF_DIR}/${SESSION_ID}"
if [[ -d "$SESSION_HANDOFF_DIR" ]]; then
    # FIXED v2.84.2: Use custom function to avoid pipefail+head SIGPIPE issue
    MOST_RECENT_HANDOFF=$(get_most_recent_file "$SESSION_HANDOFF_DIR" "handoff-*.md")

    if [[ -n "$MOST_RECENT_HANDOFF" && -f "$MOST_RECENT_HANDOFF" ]]; then
        log "INFO" "Found recent handoff: $MOST_RECENT_HANDOFF"

        CONTEXT+="### Previous Session Handoff\n\n"
        HANDOFF_CONTENT=$(cat "$MOST_RECENT_HANDOFF" 2>/dev/null || echo "Unable to read handoff")
        CONTEXT+="\`\`\`\n${HANDOFF_CONTENT}\n\`\`\`\n\n"

        FOUND_CONTEXT=true
        log "INFO" "Handoff context added"
    fi
fi

# 4. Get vault hints for this project (v3.2.0: Obsidian-backed)
VAULT_HINTS=$(get_vault_hints "$PROJECT_NAME")
if [[ -n "$VAULT_HINTS" ]] && [[ "$VAULT_HINTS" != "No recent observations found. Search ~/Documents/Obsidian/MiVault/ directly." ]]; then
    CONTEXT+="### Vault Context\n\n"
    CONTEXT+="Recent observations from Obsidian vault:\n\n"
    CONTEXT+="${VAULT_HINTS}\n\n"
    FOUND_CONTEXT=true
    log "INFO" "Vault hints added"
fi

# 5. Add continuity guidance if context was found
if [[ "$FOUND_CONTEXT" == "true" ]]; then
    CONTEXT+="---\n\n"
    CONTEXT+="### Next Steps\n\n"
    CONTEXT+="1. Review the context above to understand what was being worked on\n"
    CONTEXT+="2. Continue with the current task or plan\n"
    # FIXED v2.84.0: Escape backticks to prevent command substitution
    CONTEXT+="3. Use \`/plan show\` to see the current plan status\n"
    CONTEXT+="4. Use \`/context\` to check current context usage\n\n"
    CONTEXT+="**Note**: Your work progress has been preserved. Focus on completing the current task.\n"

    log "INFO" "Context restoration complete - context injected"
else
    CONTEXT+="### New Session\n\n"
    CONTEXT+="No previous context found for this project. Starting fresh.\n\n"
    CONTEXT+="To get started:\n"
    # FIXED v2.84.0: Escape backticks to prevent command substitution
    CONTEXT+="- Use \`/orchestrator\` for complex tasks\n"
    CONTEXT+="- Use \`/help\` to see available commands\n"

    log "INFO" "No previous context found - starting fresh"
fi

# Truncate context if too large (avoids jq argument limit)
CONTEXT=$(truncate_context "$CONTEXT")

# Output context for injection
# SessionStart hooks can use hookSpecificOutput to inject context
jq -n --arg ctx "$CONTEXT" '{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "permissionDecision": "allow",
    "additionalContext": $ctx
  }
}'

log "INFO" "SessionStart hook completed"
