#!/bin/bash
# task-project-tracker.sh - Track project metadata for all tasks
# VERSION: 2.68.20
#
# Purpose: Add project metadata to every task created, enabling
#          multi-project tracking and claude-task-viewer integration.
#
# Trigger: PostToolUse (TaskCreate, TaskUpdate)
#
# This hook ensures:
# 1. Every task has project metadata (path, repo, branch)
# 2. Tasks from adversarial/codex/gemini are properly tracked
# 3. Global task viewer can filter by project
#
# Output (JSON via stdout for PostToolUse):
#   - {"continue": true}: Continue execution
#   - {"continue": true, "systemMessage": "..."}: Continue with feedback

set -euo pipefail

# SEC-004: Restrictive umask for secure temp file creation
umask 077

# SEC-033: Guaranteed JSON output on any error
output_json() {
    echo '{"continue": true}'
}
trap 'output_json' ERR

# Configuration
CLAUDE_TASKS_DIR="${HOME}/.claude/tasks"
METADATA_DIR="${HOME}/.ralph/metadata"
LOG_FILE="${HOME}/.ralph/logs/task-project-tracker.log"

mkdir -p "$(dirname "$LOG_FILE")" "$METADATA_DIR"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [task-project-tracker] $*" >> "$LOG_FILE"
}

# Detect current project information
detect_project() {
    local cwd="${1:-.}"
    local result="{}"

    # Check if in a git repository
    if ! git -C "$cwd" rev-parse --is-inside-work-tree &>/dev/null; then
        log "Not in a git repository, returning empty project metadata"
        echo "$result"
        return
    fi

    local project_path repo_remote repo_name branch modified

    # Get absolute path
    project_path=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null || echo "$cwd")

    # Get git remote (prefer origin)
    repo_remote=$(git -C "$cwd" remote get-url origin 2>/dev/null || echo "")

    # Extract repo name from remote
    if [[ -n "$repo_remote" ]]; then
        # Handle both HTTPS and SSH URLs
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

    # Get current branch
    branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null || echo "detached")

    # Check for uncommitted changes
    if ! git -C "$cwd" diff --quiet HEAD &>/dev/null; then
        modified=true
    else
        modified=false
    fi

    # Build JSON result
    result=$(jq -n \
        --arg path "$project_path" \
        --arg repo "$repo_name" \
        --arg branch "$branch" \
        --arg modified "$modified" \
        '{
            path: $path,
            repo: $repo,
            branch: $branch,
            modified: ($modified == "true"),
            detected_at: now | strftime("%Y-%m-%dT%H:%M:%SZ")
        }')

    log "Detected project: $repo_name (path: $project_path, branch: $branch)"
    echo "$result"
}

# Get session ID - INPUT.session_id is CANONICAL (from Claude Code)
get_session_id() {
    # FIRST: Try INPUT.session_id (canonical source from Claude Code)
    if [[ -n "${SESSION_ID_FROM_INPUT:-}" ]]; then
        echo "$SESSION_ID_FROM_INPUT"
        return
    fi
    # Fallback: Environment variables
    if [[ -n "${CLAUDE_SESSION_ID:-}" ]]; then
        echo "$CLAUDE_SESSION_ID"
    elif [[ -n "${SESSION_ID:-}" ]]; then
        echo "$SESSION_ID"
    elif [[ -f ".claude/session-id" ]]; then
        cat ".claude/session-id"
    else
        echo "ralph-$(date +%Y%m%d)-$$"
    fi
}

# Update task with project metadata
update_task_with_project() {
    local task_file="$1"
    local project_json="$2"
    local tool_name="$3"

    if [[ ! -f "$task_file" ]]; then
        log "Task file not found: $task_file"
        return 1
    fi

    # Read current task
    local current_content
    current_content=$(cat "$task_file")

    # Check if project already exists
    local has_project
    has_project=$(jq '.project // empty' <<< "$current_content" 2>/dev/null || echo "")

    if [[ -n "$has_project" ]]; then
        log "Task already has project metadata, skipping update"
        return 0
    fi

    # Add project metadata and tool field
    local updated_content
    updated_content=$(jq \
        --argjson project "$project_json" \
        --arg tool "$tool_name" \
        '.project = $project | .tool = $tool | .updated_at = (now | strftime("%Y-%m-%dT%H:%M:%SZ"))' \
        <<< "$current_content")

    # Write back atomically
    local temp_file
    temp_file=$(mktemp)
    echo "$updated_content" | jq '.' > "$temp_file"
    mv "$temp_file" "$task_file"
    chmod 600 "$task_file"

    log "Updated task with project: $(jq -r '.repo // "unknown"' <<< "$project_json")"
}

# Read stdin to get tool info
INPUT=$(cat)

# Extract session_id from INPUT FIRST (canonical source from Claude Code)
SESSION_ID_FROM_INPUT=$(echo "$INPUT" | jq -r '.session_id // ""' 2>/dev/null || echo "")

# Extract tool name and path
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null || echo "")

# Only process Task operations
case "$TOOL_NAME" in
    TaskCreate|TaskUpdate)
        log "Processing $TOOL_NAME for project tracking"
        ;;
    *)
        echo '{"continue": true}'
        exit 0
        ;;
esac

# Get session ID
SESSION_ID=$(get_session_id)
# SEC-029: Sanitize session_id to prevent path traversal
SESSION_ID=$(echo "$SESSION_ID" | tr -cd 'a-zA-Z0-9_-' | head -c 64)
[[ -z "$SESSION_ID" ]] && SESSION_ID="ralph-$(date +%Y%m%d)-$$"
SESSION_TASKS_DIR="${CLAUDE_TASKS_DIR}/${SESSION_ID}"

if [[ ! -d "$SESSION_TASKS_DIR" ]]; then
    log "No session tasks directory found: $SESSION_TASKS_DIR"
    echo '{"continue": true}'
    exit 0
fi

# Detect current project
CWD=$(pwd)
PROJECT_JSON=$(detect_project "$CWD")

# Determine which tool is being used (adversarial, codex, gemini, etc.)
TOOL_TYPE=""
if [[ "$TOOL_NAME" == "TaskCreate" ]]; then
    # Try to infer tool from context or stdin
    TOOL_TYPE=$(echo "$INPUT" | jq -r '.prompt // ""' 2>/dev/null | grep -iE "(adversarial|codex|gemini)" | head -1 || echo "")
fi

# Update the most recent task file
LATEST_TASK=$(ls -t "$SESSION_TASKS_DIR"/*.json 2>/dev/null | head -1)

if [[ -n "$LATEST_TASK" ]] && [[ -f "$LATEST_TASK" ]]; then
    update_task_with_project "$LATEST_TASK" "$PROJECT_JSON" "$TOOL_TYPE"
    TASK_ID=$(basename "$LATEST_TASK" .json)
    log "Updated task $TASK_ID with project metadata"
    echo "{\"continue\": true, \"systemMessage\": \"📍 Project tracked: $(jq -r '.project.repo // "unknown"' <<< "$PROJECT_JSON")\"}"
else
    log "No task files found to update"
    echo '{"continue": true}'
fi
