#!/bin/bash
# Checkpoint Manager - v2.54.0
# LangGraph-style "time travel" for Ralph orchestration
#
# Save and restore plan states with full context:
# - plan-state.json
# - orchestrator-analysis.md
# - git status
# - working directory
# - v2.54: handoffs, events, agent-memory (complete state capture)
#
# Usage:
#   checkpoint-manager.sh save <name> [description]
#   checkpoint-manager.sh restore <name>
#   checkpoint-manager.sh list [--json]
#   checkpoint-manager.sh show <name>
#   checkpoint-manager.sh delete <name>
#   checkpoint-manager.sh diff <name1> [name2]

set -uo pipefail
umask 077

# Configuration
VERSION="2.84.3"
CHECKPOINTS_DIR="${HOME}/.ralph/checkpoints"
PLAN_STATE_FILE=".claude/plan-state.json"
ANALYSIS_FILE=".claude/orchestrator-analysis.md"
LOG_DIR="${HOME}/.ralph/logs"

# v2.54: Additional state directories
HANDOFFS_DIR="${HOME}/.ralph/handoffs"
EVENTS_LOG="${HOME}/.ralph/events/event-log.jsonl"
AGENT_MEMORY_DIR="${HOME}/.ralph/agent-memory"
STATE_COORDINATOR="${HOME}/.claude/scripts/state-coordinator.sh"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Ensure directories exist
mkdir -p "$CHECKPOINTS_DIR" "$LOG_DIR"

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[OK]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# Generate checkpoint ID from name
get_checkpoint_id() {
    local name="$1"
    # Sanitize name: alphanumeric, dash, underscore only
    echo "$name" | tr -cd '[:alnum:]-_' | head -c 50
}

# Get checkpoint directory
get_checkpoint_dir() {
    local name="$1"
    local checkpoint_id
    checkpoint_id=$(get_checkpoint_id "$name")
    echo "${CHECKPOINTS_DIR}/${checkpoint_id}"
}

# Save current state as checkpoint
cmd_save() {
    local name="${1:-}"
    local description="${2:-Manual checkpoint}"

    if [[ -z "$name" ]]; then
        log_error "Checkpoint name required"
        echo "Usage: checkpoint-manager.sh save <name> [description]"
        exit 1
    fi

    local checkpoint_id
    checkpoint_id=$(get_checkpoint_id "$name")
    local checkpoint_dir="${CHECKPOINTS_DIR}/${checkpoint_id}"

    # v2.84.3: FIX TOCTOU - Use atomic lock directory to prevent race conditions
    local lock_dir="${checkpoint_dir}.lock.$$"
    if ! mkdir "$lock_dir" 2>/dev/null; then
        log_error "Checkpoint '$name' is being created by another process"
        exit 1
    fi
    trap 'rmdir "$lock_dir" 2>/dev/null || true' EXIT

    # Check if checkpoint already exists
    if [[ -d "$checkpoint_dir" ]]; then
        log_warn "Checkpoint '$name' already exists. Overwriting..."
        rm -rf "$checkpoint_dir"
    fi

    mkdir -p "$checkpoint_dir"

    local project_dir
    project_dir=$(pwd)
    local timestamp
    timestamp=$(date -Iseconds)

    log_info "Creating checkpoint: $name"

    # 1. Save plan-state.json if exists
    if [[ -f "$PLAN_STATE_FILE" ]]; then
        cp "$PLAN_STATE_FILE" "$checkpoint_dir/plan-state.json"
        log_info "  ✓ Saved plan-state.json"
    else
        log_warn "  ⚠ No plan-state.json found"
    fi

    # 2. Save orchestrator-analysis.md if exists
    if [[ -f "$ANALYSIS_FILE" ]]; then
        cp "$ANALYSIS_FILE" "$checkpoint_dir/orchestrator-analysis.md"
        log_info "  ✓ Saved orchestrator-analysis.md"
    fi

    # 3. Save git status and diff
    if git rev-parse --git-dir &>/dev/null; then
        git status --porcelain > "$checkpoint_dir/git-status.txt" 2>/dev/null || true
        git diff > "$checkpoint_dir/git-diff.patch" 2>/dev/null || true
        git diff --staged > "$checkpoint_dir/git-staged.patch" 2>/dev/null || true
        git log -1 --format="%H %s" > "$checkpoint_dir/git-head.txt" 2>/dev/null || true
        log_info "  ✓ Saved git state"
    fi

    # v2.54: 4. Save handoff transfers
    local handoffs_saved="false"
    if [[ -d "$HANDOFFS_DIR/transfers" ]]; then
        mkdir -p "$checkpoint_dir/handoffs"
        if cp -r "$HANDOFFS_DIR/transfers" "$checkpoint_dir/handoffs/" 2>/dev/null; then
            handoffs_saved="true"
            local handoff_count
            handoff_count=$(find "$checkpoint_dir/handoffs/transfers" -name "*.jsonl" 2>/dev/null | wc -l | tr -d ' ')
            log_info "  ✓ Saved handoff transfers ($handoff_count files)"
        fi
    fi

    # v2.54: 5. Save event log
    local events_saved="false"
    if [[ -f "$EVENTS_LOG" ]]; then
        mkdir -p "$checkpoint_dir/events"
        if cp "$EVENTS_LOG" "$checkpoint_dir/events/event-log.jsonl" 2>/dev/null; then
            events_saved="true"
            local event_count
            event_count=$(wc -l < "$checkpoint_dir/events/event-log.jsonl" | tr -d ' ')
            log_info "  ✓ Saved event log ($event_count events)"
        fi
    fi

    # v2.54: 6. Save agent memory (active agent or all)
    local agent_memory_saved="false"
    local active_agent=""

    # Get active agent from plan-state or State Coordinator
    if [[ -f "$PLAN_STATE_FILE" ]]; then
        active_agent=$(jq -r '.active_agent // ""' "$PLAN_STATE_FILE" 2>/dev/null || echo "")
    fi
    if [[ -z "$active_agent" ]] && [[ -x "$STATE_COORDINATOR" ]]; then
        active_agent=$("$STATE_COORDINATOR" get-active-agent 2>/dev/null || echo "")
    fi

    if [[ -d "$AGENT_MEMORY_DIR" ]]; then
        mkdir -p "$checkpoint_dir/agent-memory"

        if [[ -n "$active_agent" ]] && [[ -d "$AGENT_MEMORY_DIR/$active_agent" ]]; then
            # Save active agent's memory
            if cp -r "$AGENT_MEMORY_DIR/$active_agent" "$checkpoint_dir/agent-memory/" 2>/dev/null; then
                agent_memory_saved="true"
                log_info "  ✓ Saved agent memory for: $active_agent"
            fi
        else
            # Save all agent memories
            local agents_with_memory
            agents_with_memory=$(find "$AGENT_MEMORY_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
            if [[ "$agents_with_memory" -gt 0 ]]; then
                if cp -r "$AGENT_MEMORY_DIR"/* "$checkpoint_dir/agent-memory/" 2>/dev/null; then
                    agent_memory_saved="true"
                    log_info "  ✓ Saved agent memory ($agents_with_memory agents)"
                fi
            fi
        fi
    fi

    # 7. Create metadata (v2.54 enhanced)
    cat > "$checkpoint_dir/metadata.json" <<EOF
{
    "version": "$VERSION",
    "checkpoint_id": "$checkpoint_id",
    "name": "$name",
    "description": "$description",
    "created_at": "$timestamp",
    "project_dir": "$project_dir",
    "active_agent": "${active_agent:-null}",
    "files_saved": {
        "plan_state": $([ -f "$checkpoint_dir/plan-state.json" ] && echo "true" || echo "false"),
        "orchestrator_analysis": $([ -f "$checkpoint_dir/orchestrator-analysis.md" ] && echo "true" || echo "false"),
        "git_status": $([ -f "$checkpoint_dir/git-status.txt" ] && echo "true" || echo "false"),
        "git_diff": $([ -f "$checkpoint_dir/git-diff.patch" ] && echo "true" || echo "false"),
        "handoffs": $handoffs_saved,
        "events": $events_saved,
        "agent_memory": $agent_memory_saved
    }
}
EOF

    log_success "Checkpoint saved: $checkpoint_dir"
    echo ""
    echo "Restore with: checkpoint-manager.sh restore $name"
}

# Restore state from checkpoint
cmd_restore() {
    local name="${1:-}"

    if [[ -z "$name" ]]; then
        log_error "Checkpoint name required"
        echo "Usage: checkpoint-manager.sh restore <name>"
        exit 1
    fi

    local checkpoint_dir
    checkpoint_dir=$(get_checkpoint_dir "$name")

    if [[ ! -d "$checkpoint_dir" ]]; then
        log_error "Checkpoint not found: $name"
        echo "Available checkpoints:"
        cmd_list
        exit 1
    fi

    log_info "Restoring checkpoint: $name"

    # Read metadata
    local original_project
    original_project=$(jq -r '.project_dir // "."' "$checkpoint_dir/metadata.json")

    # 1. Restore plan-state.json
    if [[ -f "$checkpoint_dir/plan-state.json" ]]; then
        mkdir -p "$(dirname "$PLAN_STATE_FILE")"
        cp "$checkpoint_dir/plan-state.json" "$PLAN_STATE_FILE"
        log_info "  ✓ Restored plan-state.json"
    fi

    # 2. Restore orchestrator-analysis.md
    if [[ -f "$checkpoint_dir/orchestrator-analysis.md" ]]; then
        mkdir -p "$(dirname "$ANALYSIS_FILE")"
        cp "$checkpoint_dir/orchestrator-analysis.md" "$ANALYSIS_FILE"
        log_info "  ✓ Restored orchestrator-analysis.md"
    fi

    # v2.54: 3. Restore handoff transfers
    if [[ -d "$checkpoint_dir/handoffs/transfers" ]]; then
        mkdir -p "$HANDOFFS_DIR"
        if cp -r "$checkpoint_dir/handoffs/transfers" "$HANDOFFS_DIR/" 2>/dev/null; then
            local handoff_count
            handoff_count=$(find "$HANDOFFS_DIR/transfers" -name "*.jsonl" 2>/dev/null | wc -l | tr -d ' ')
            log_info "  ✓ Restored handoff transfers ($handoff_count files)"
        fi
    fi

    # v2.54: 4. Restore event log
    if [[ -f "$checkpoint_dir/events/event-log.jsonl" ]]; then
        mkdir -p "$(dirname "$EVENTS_LOG")"
        if cp "$checkpoint_dir/events/event-log.jsonl" "$EVENTS_LOG" 2>/dev/null; then
            local event_count
            event_count=$(wc -l < "$EVENTS_LOG" | tr -d ' ')
            log_info "  ✓ Restored event log ($event_count events)"
        fi
    fi

    # v2.54: 5. Restore agent memory
    if [[ -d "$checkpoint_dir/agent-memory" ]]; then
        local agents_restored=0

        for agent_dir in "$checkpoint_dir/agent-memory"/*/; do
            [[ -d "$agent_dir" ]] || continue
            local agent_id
            agent_id=$(basename "$agent_dir")

            mkdir -p "$AGENT_MEMORY_DIR/$agent_id"
            if cp -r "$agent_dir"* "$AGENT_MEMORY_DIR/$agent_id/" 2>/dev/null; then
                ((agents_restored++))
            fi
        done

        if [[ $agents_restored -gt 0 ]]; then
            log_info "  ✓ Restored agent memory ($agents_restored agents)"
        fi
    fi

    # v2.54: 6. Update active_agent via State Coordinator
    local saved_active_agent
    saved_active_agent=$(jq -r '.active_agent // ""' "$checkpoint_dir/metadata.json" 2>/dev/null || echo "")

    if [[ -n "$saved_active_agent" ]] && [[ "$saved_active_agent" != "null" ]] && [[ -x "$STATE_COORDINATOR" ]]; then
        if "$STATE_COORDINATOR" set-active-agent "$saved_active_agent" 2>/dev/null; then
            log_info "  ✓ Restored active agent: $saved_active_agent"
        fi
    fi

    # 7. Show git state (don't auto-apply - user decides)
    if [[ -f "$checkpoint_dir/git-head.txt" ]]; then
        log_info "  ℹ Original git HEAD:"
        echo "    $(cat "$checkpoint_dir/git-head.txt")"
    fi

    if [[ -f "$checkpoint_dir/git-diff.patch" ]] && [[ -s "$checkpoint_dir/git-diff.patch" ]]; then
        log_warn "  ⚠ Checkpoint has uncommitted changes. Apply with:"
        echo "    git apply $checkpoint_dir/git-diff.patch"
    fi

    if [[ -f "$checkpoint_dir/git-staged.patch" ]] && [[ -s "$checkpoint_dir/git-staged.patch" ]]; then
        log_warn "  ⚠ Checkpoint has staged changes. Apply with:"
        echo "    git apply --cached $checkpoint_dir/git-staged.patch"
    fi

    log_success "Checkpoint restored: $name"

    # Log the restore for auditing
    echo "[$(date -Iseconds)] Restored checkpoint: $name from $checkpoint_dir" >> "$LOG_DIR/checkpoint-$(date +%Y%m%d).log"
}

# List all checkpoints
cmd_list() {
    local json_output="${1:-}"

    local checkpoints=()

    for dir in "$CHECKPOINTS_DIR"/*/; do
        [[ -d "$dir" ]] || continue
        [[ -f "${dir}metadata.json" ]] || continue

        local metadata
        metadata=$(cat "${dir}metadata.json")
        checkpoints+=("$metadata")
    done

    if [[ ${#checkpoints[@]} -eq 0 ]]; then
        if [[ "$json_output" == "--json" ]]; then
            echo "[]"
        else
            log_info "No checkpoints found"
            echo "Create one with: checkpoint-manager.sh save <name>"
        fi
        return
    fi

    if [[ "$json_output" == "--json" ]]; then
        printf '%s\n' "${checkpoints[@]}" | jq -s '.'
    else
        echo ""
        printf "%-20s %-25s %-40s\n" "NAME" "CREATED" "DESCRIPTION"
        echo "────────────────────────────────────────────────────────────────────────────────"

        for metadata in "${checkpoints[@]}"; do
            local name created description
            name=$(echo "$metadata" | jq -r '.name // "unknown"')
            created=$(echo "$metadata" | jq -r '.created_at // "unknown"' | cut -d'T' -f1,2 | tr 'T' ' ' | cut -d'+' -f1)
            description=$(echo "$metadata" | jq -r '.description // ""' | head -c 38)
            printf "%-20s %-25s %-40s\n" "$name" "$created" "$description"
        done

        echo ""
        echo "Total: ${#checkpoints[@]} checkpoint(s)"
    fi
}

# Show checkpoint details
cmd_show() {
    local name="${1:-}"

    if [[ -z "$name" ]]; then
        log_error "Checkpoint name required"
        echo "Usage: checkpoint-manager.sh show <name>"
        exit 1
    fi

    local checkpoint_dir
    checkpoint_dir=$(get_checkpoint_dir "$name")

    if [[ ! -d "$checkpoint_dir" ]]; then
        log_error "Checkpoint not found: $name"
        exit 1
    fi

    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "  CHECKPOINT: $name"
    echo "═══════════════════════════════════════════════════════════════"

    if [[ -f "$checkpoint_dir/metadata.json" ]]; then
        echo ""
        echo "Metadata:"
        jq '.' "$checkpoint_dir/metadata.json"
    fi

    echo ""
    echo "Files in checkpoint:"
    ls -la "$checkpoint_dir/"

    if [[ -f "$checkpoint_dir/plan-state.json" ]]; then
        echo ""
        echo "Plan State Summary:"
        jq '{
            version: .version,
            current_step: .current_step,
            status: .status,
            classification: .classification
        }' "$checkpoint_dir/plan-state.json" 2>/dev/null || cat "$checkpoint_dir/plan-state.json"
    fi

    if [[ -f "$checkpoint_dir/git-status.txt" ]] && [[ -s "$checkpoint_dir/git-status.txt" ]]; then
        echo ""
        echo "Git Status at checkpoint:"
        cat "$checkpoint_dir/git-status.txt"
    fi

    # v2.54: Show handoffs summary
    if [[ -d "$checkpoint_dir/handoffs/transfers" ]]; then
        local handoff_count
        handoff_count=$(find "$checkpoint_dir/handoffs/transfers" -name "*.jsonl" 2>/dev/null | wc -l | tr -d ' ')
        echo ""
        echo "Handoffs: $handoff_count transfer file(s)"
    fi

    # v2.54: Show events summary
    if [[ -f "$checkpoint_dir/events/event-log.jsonl" ]]; then
        local event_count
        event_count=$(wc -l < "$checkpoint_dir/events/event-log.jsonl" | tr -d ' ')
        echo ""
        echo "Events: $event_count event(s) logged"

        # Show last few events
        echo "  Recent events:"
        tail -3 "$checkpoint_dir/events/event-log.jsonl" 2>/dev/null | \
            jq -r '"    " + .timestamp[0:19] + " " + .event_type + " - " + (.source_agent // "system")' 2>/dev/null || true
    fi

    # v2.54: Show agent memory summary
    if [[ -d "$checkpoint_dir/agent-memory" ]]; then
        echo ""
        echo "Agent Memory:"
        for agent_dir in "$checkpoint_dir/agent-memory"/*/; do
            [[ -d "$agent_dir" ]] || continue
            local agent_id
            agent_id=$(basename "$agent_dir")
            local mem_files
            mem_files=$(find "$agent_dir" -name "*.json" 2>/dev/null | wc -l | tr -d ' ')
            echo "  • $agent_id ($mem_files memory files)"
        done
    fi
}

# Delete a checkpoint
cmd_delete() {
    local name="${1:-}"

    if [[ -z "$name" ]]; then
        log_error "Checkpoint name required"
        echo "Usage: checkpoint-manager.sh delete <name>"
        exit 1
    fi

    local checkpoint_dir
    checkpoint_dir=$(get_checkpoint_dir "$name")

    if [[ ! -d "$checkpoint_dir" ]]; then
        log_error "Checkpoint not found: $name"
        exit 1
    fi

    rm -rf "$checkpoint_dir"
    log_success "Deleted checkpoint: $name"
}

# Compare two checkpoints or current state vs checkpoint
cmd_diff() {
    local name1="${1:-}"
    local name2="${2:-}"

    if [[ -z "$name1" ]]; then
        log_error "At least one checkpoint name required"
        echo "Usage: checkpoint-manager.sh diff <name1> [name2]"
        echo "       If name2 is omitted, compares with current state"
        exit 1
    fi

    local dir1
    dir1=$(get_checkpoint_dir "$name1")

    if [[ ! -d "$dir1" ]]; then
        log_error "Checkpoint not found: $name1"
        exit 1
    fi

    echo ""
    echo "═══════════════════════════════════════════════════════════════"

    if [[ -n "$name2" ]]; then
        # Compare two checkpoints
        local dir2
        dir2=$(get_checkpoint_dir "$name2")

        if [[ ! -d "$dir2" ]]; then
            log_error "Checkpoint not found: $name2"
            exit 1
        fi

        echo "  Comparing: $name1 ↔ $name2"
        echo "═══════════════════════════════════════════════════════════════"

        if [[ -f "$dir1/plan-state.json" ]] && [[ -f "$dir2/plan-state.json" ]]; then
            echo ""
            echo "Plan State Diff:"
            diff --color=auto -u "$dir1/plan-state.json" "$dir2/plan-state.json" || true
        fi
    else
        # Compare checkpoint with current state
        echo "  Comparing: $name1 ↔ CURRENT"
        echo "═══════════════════════════════════════════════════════════════"

        if [[ -f "$dir1/plan-state.json" ]] && [[ -f "$PLAN_STATE_FILE" ]]; then
            echo ""
            echo "Plan State Diff (checkpoint → current):"
            diff --color=auto -u "$dir1/plan-state.json" "$PLAN_STATE_FILE" || true
        elif [[ -f "$dir1/plan-state.json" ]]; then
            log_warn "Current plan-state.json not found"
        fi
    fi
}

# Main
main() {
    local command="${1:-help}"
    shift || true

    case "$command" in
        save)
            cmd_save "$@"
            ;;
        restore)
            cmd_restore "$@"
            ;;
        list)
            cmd_list "$@"
            ;;
        show)
            cmd_show "$@"
            ;;
        delete|rm)
            cmd_delete "$@"
            ;;
        diff)
            cmd_diff "$@"
            ;;
        version)
            echo "checkpoint-manager.sh v$VERSION"
            ;;
        help|--help|-h)
            cat <<'EOF'
Checkpoint Manager v2.54.0 - LangGraph-style "Time Travel"

USAGE:
    checkpoint-manager.sh <command> [options]

COMMANDS:
    save <name> [desc]     Save current state as checkpoint
    restore <name>         Restore state from checkpoint
    list [--json]          List all checkpoints
    show <name>            Show checkpoint details
    delete <name>          Delete a checkpoint
    diff <n1> [n2]         Compare checkpoints (or vs current)

EXAMPLES:
    # Save before refactoring
    checkpoint-manager.sh save "before-refactor" "Pre-auth refactoring"

    # List available checkpoints
    checkpoint-manager.sh list

    # Restore if things go wrong
    checkpoint-manager.sh restore "before-refactor"

    # Compare checkpoint with current state
    checkpoint-manager.sh diff "before-refactor"

STORED DATA (v2.54 Enhanced):
    Each checkpoint saves:
    - .claude/plan-state.json          (orchestration state)
    - .claude/orchestrator-analysis.md (planning analysis)
    - git status and diff              (uncommitted changes)
    - ~/.ralph/handoffs/transfers/     (agent handoffs)
    - ~/.ralph/events/event-log.jsonl  (event bus log)
    - ~/.ralph/agent-memory/           (agent memory buffers)
    - metadata (timestamp, description, project dir, active agent)

v2.54 FEATURES:
    - Complete state capture (handoffs, events, agent-memory)
    - Active agent tracking and restoration
    - State Coordinator integration for atomic updates
    - Full "time travel" for multi-agent orchestration

LOCATION:
    ~/.ralph/checkpoints/
EOF
            ;;
        *)
            log_error "Unknown command: $command"
            echo "Run 'checkpoint-manager.sh help' for usage"
            exit 1
            ;;
    esac
}

main "$@"
