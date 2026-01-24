#!/bin/bash
# project-backup-metadata.sh - SessionStart/Stop hooks for project metadata backup
# VERSION: 2.68.6
#
# Purpose: Track project sessions globally for multi-project task tracking.
#          Enables viewing task history across different repositories.
#
# Trigger: SessionStart + Stop
#
# SessionStart:
#   - Detect current project from cwd
#   - Save to ~/.ralph/metadata/current-project.json
#   - Create/update session record
#
# Stop:
#   - Backup session metadata to ~/.ralph/metadata/projects/{sanitized-path}.json
#   - Update session history
#   - Generate session summary
#
# Output: Plain text (becomes additionalContext for SessionStart)
#         JSON via stdout for Stop: {"decision": "approve"}

set -euo pipefail

# SEC-033: Guaranteed JSON output on any error
output_json_stop() {
    echo '{"decision": "approve"}'
}
trap 'output_json_stop' ERR

# Configuration
METADATA_DIR="${HOME}/.ralph/metadata"
PROJECTS_DIR="${METADATA_DIR}/projects"
ACTIVE_PLAN_DIR="${HOME}/.ralph/active-plan"
LOG_FILE="${HOME}/.ralph/logs/project-backup-metadata.log"

mkdir -p "$PROJECTS_DIR" "$ACTIVE_PLAN_DIR"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [project-backup-metadata] $*" >> "$LOG_FILE"
}

# Get session ID
get_session_id() {
    if [[ -n "${CLAUDE_SESSION_ID:-}" ]]; then
        echo "$CLAUDE_SESSION_ID"
    elif [[ -n "${SESSION_ID:-}" ]]; then
        echo "$SESSION_ID"
    else
        echo "ralph-$(date +%Y%m%d)-$$"
    fi
}

# Sanitize path for filename
sanitize_path() {
    echo "$1" | sed 's|/|_|g' | sed 's/^_//' | sed 's/_$//' | tr -d ':'
}

# Detect current project
detect_project() {
    local cwd="${1:-.}"
    local result="{}"

    if ! git -C "$cwd" rev-parse --is-inside-work-tree &>/dev/null; then
        log "Not in a git repository"
        echo "$result"
        return
    fi

    local project_path repo_remote repo_name branch modified has_changes

    project_path=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null || echo "$cwd")
    repo_remote=$(git -C "$cwd" remote get-url origin 2>/dev/null || echo "")

    if [[ -n "$repo_remote" ]]; then
        if [[ "$repo_remote" =~ github\.com[:/]([^/]+)/([^/]+)\.git$ ]]; then
            repo_name="${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
        elif [[ "$repo_remote" =~ github\.com/([^/]+)/([^/]+)$ ]]; then
            repo_name="${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
        else
            repo_name=$(basename "$repo_remote" .git 2>/dev/null || echo "unknown")
        fi
    else
        repo_name="local-only"
    fi

    branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null || echo "detached")

    if ! git -C "$cwd" diff --quiet HEAD &>/dev/null; then
        modified=true
        has_changes=$(git -C "$cwd" diff --stat HEAD 2>/dev/null || echo "unknown")
    else
        modified=false
        has_changes="none"
    fi

    # Count files changed
    local files_changed=0
    if [[ -f ".claude/plan-state.json" ]]; then
        files_changed=$(git -C "$cwd" status --porcelain 2>/dev/null | wc -l | tr -d ' ' || echo "0")
    fi

    result=$(jq -n \
        --arg path "$project_path" \
        --arg repo "$repo_name" \
        --arg branch "$branch" \
        --arg modified "$modified" \
        --arg changes "$has_changes" \
        --argjson files "$files_changed" \
        '{
            path: $path,
            repo: $repo,
            branch: $branch,
            modified: ($modified == "true"),
            changes_summary: $changes,
            files_changed: $files,
            detected_at: now | strftime("%Y-%m-%dT%H:%M:%SZ")
        }')

    echo "$result"
}

# Save current project session
save_current_session() {
    local project_json="$1"
    local session_id="$2"
    local start_time="$3"

    local project_path
    project_path=$(jq -r '.path' <<< "$project_json")
    local repo_name
    repo_name=$(jq -r '.repo' <<< "$project_json")

    # Save to current-project.json (for active sessions)
    local current_file="${METADATA_DIR}/current-project.json"
    jq -n \
        --argjson project "$project_json" \
        --arg session "$session_id" \
        --arg start "$start_time" \
        '{
            project: $project,
            session_id: $session,
            session_start: $start,
            last_updated: (now | strftime("%Y-%m-%dT%H:%M:%SZ"))
        }' > "$current_file"

    log "Saved current session: $session_id for project $repo_name"

    # Also copy plan-state.json to active-plan if exists
    if [[ -f ".claude/plan-state.json" ]]; then
        local plan_id
        plan_id=$(jq -r '.plan_id // "unknown"' .claude/plan-state.json 2>/dev/null || echo "unknown")
        local active_plan_file="${ACTIVE_PLAN_DIR}/${plan_id}.json"
        cp ".claude/plan-state.json" "$active_plan_file"
        log "Copied plan-state to active-plan: $plan_id"
    fi
}

# Backup session to project history
backup_session() {
    local project_json="$1"
    local session_id="$2"

    local project_path repo_name
    project_path=$(jq -r '.path' <<< "$project_json")
    repo_name=$(jq -r '.repo' <<< "$project_json")

    # Sanitized filename for the project
    local sanitized
    sanitized=$(sanitize_path "$project_path")
    local project_file="${PROJECTS_DIR}/${sanitized}.json"

    # Read existing project history or create new
    local existing_history="[]"
    if [[ -f "$project_file" ]]; then
        existing_history=$(jq -c '.session_history // []' "$project_file" 2>/dev/null || echo "[]")
    fi

    # Add current session to history
    local session_entry
    session_entry=$(jq -n \
        --arg session "$session_id" \
        --arg repo "$repo_name" \
        --arg path "$project_path" \
        --arg end "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        '{
            session_id: $session,
            repo: $repo,
            path: $path,
            session_end: $end
        }')

    # Build updated project file
    local updated_project
    updated_project=$(jq -n \
        --argjson history "$existing_history" \
        --argjson last "$session_entry" \
        --arg repo "$repo_name" \
        --arg path "$project_path" \
        '{
            project: {
                repo: $repo,
                path: $path
            },
            session_history: ($history + [$last]),
            last_session: $last.session_id,
            last_access: $last.session_end
        }')

    # Write atomically
    local temp_file
    temp_file=$(mktemp)
    echo "$updated_project" | jq '.' > "$temp_file"
    mv "$temp_file" "$project_file"
    chmod 600 "$project_file"

    log "Backed up session to project history: $project_file"
}

# Get session duration
get_session_duration() {
    local start_time="$1"
    local end_time="$2"

    local start_epoch end_epoch duration

    # Try to parse dates (macOS compatible)
    if [[ "$OSTYPE" == "darwin"* ]]; then
        start_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$start_time" +%s 2>/dev/null || echo "0")
        end_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$end_time" +%s 2>/dev/null || echo "0")
    else
        start_epoch=$(date -d "$start_time" +%s 2>/dev/null || echo "0")
        end_epoch=$(date -d "$end_time" +%s 2>/dev/null || echo "0")
    fi

    if [[ "$start_epoch" -gt 0 ]] && [[ "$end_epoch" -gt 0 ]]; then
        duration=$((end_epoch - start_epoch))

        if [[ "$duration" -lt 60 ]]; then
            echo "${duration}s"
        elif [[ "$duration" -lt 3600 ]]; then
            echo "$((duration / 60))m"
        else
            echo "$((duration / 3600))h $(((duration % 3600) / 60))m"
        fi
    else
        echo "unknown"
    fi
}

# Determine hook type from arguments or environment
HOOK_TYPE="${1:-SessionStart}"

case "$HOOK_TYPE" in
    SessionStart)
        log "=== SessionStart: Saving current project ==="

        CWD=$(pwd)
        SESSION_ID=$(get_session_id)
        START_TIME=$(date -u +%Y-%m-%dT%H:%M:%SZ)

        PROJECT_JSON=$(detect_project "$CWD")

        if [[ "$(jq -r '.repo' <<< "$PROJECT_JSON")" != "null" ]]; then
            save_current_session "$PROJECT_JSON" "$SESSION_ID" "$START_TIME"

            REPO_NAME=$(jq -r '.repo' <<< "$PROJECT_JSON")
            echo ""
            echo "📁 Project: $REPO_NAME"
            echo "📂 Path: $(jq -r '.path' <<< "$PROJECT_JSON")"
            echo "🌿 Branch: $(jq -r '.branch' <<< "$PROJECT_JSON")"
            echo "🆔 Session: $SESSION_ID"
            echo ""
        else
            echo "⚠️ Not in a git repository - project tracking disabled"
        fi
        ;;

    Stop)
        log "=== Stop: Backing up session ==="

        CURRENT_FILE="${METADATA_DIR}/current-project.json"

        if [[ -f "$CURRENT_FILE" ]]; then
            local session_id project_json
            session_id=$(jq -r '.session_id' "$CURRENT_FILE")
            project_json=$(jq -r '.project' "$CURRENT_FILE")

            local end_time
            end_time=$(date -u +%Y-%m-%dT%H:%M:%SZ)
            local start_time
            start_time=$(jq -r '.session_start' "$CURRENT_FILE")

            backup_session "$project_json" "$session_id"

            local duration
            duration=$(get_session_duration "$start_time" "$end_time")

            local repo_name
            repo_name=$(jq -r '.repo' <<< "$project_json")

            echo ""
            echo "📊 Session Summary"
            echo "━━━━━━━━━━━━━━━━"
            echo "📁 Project: $repo_name"
            echo "🆔 Session: $session_id"
            echo "⏱️ Duration: $duration"
            echo "💾 Metadata backed up to: ~/.ralph/metadata/projects/"
            echo ""

            # Clean up current-project.json
            rm -f "$CURRENT_FILE"
            log "Cleaned up current-project.json"
        else
            log "No current session found to backup"
        fi

        echo '{"decision": "approve"}'
        ;;

    *)
        echo "Unknown hook type: $HOOK_TYPE"
        echo '{"decision": "approve"}'
        ;;
esac
