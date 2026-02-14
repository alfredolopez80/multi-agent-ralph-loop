#!/bin/bash
# teammate-idle-quality-gate.sh - Quality gate for Agent Teams teammates
# VERSION: 2.85.0
# REPO: multi-agent-ralph-loop
#
# Triggered by: TeammateIdle hook event
# Exit codes:
#   0 = Allow teammate to go idle
#   2 = Block idle + send feedback to keep working
#
# Input (stdin JSON):
#   {
#     "teammateId": "teammate-xxx",
#     "teammateType": "coder|reviewer|tester|researcher",
#     "taskId": "task-xxx",
#     "filesModified": ["file1.ts", "file2.py"]
#   }
#
# Output (stdout JSON):
#   {"decision": "approve", "reason": "All quality checks passed"}
#   {"decision": "request_changes", "reason": "Quality issues found", "feedback": "..."}

set -euo pipefail

# Configuration
REPO_ROOT="/Users/alfredolopez/Documents/GitHub/multi-agent-ralph-loop"
LOG_DIR="$HOME/.ralph/logs"
mkdir -p "$LOG_DIR"

# Read stdin for teammate info
stdin_data=$(cat)

# Extract info with fallbacks
teammate_id=$(echo "$stdin_data" | jq -r '.teammateId // .teammate_id // "unknown"')
teammate_type=$(echo "$stdin_data" | jq -r '.teammateType // .teammate_type // "unknown"')
task_id=$(echo "$stdin_data" | jq -r '.taskId // .task_id // "unknown"')
files_modified=$(echo "$stdin_data" | jq -r '.filesModified // .files_modified // []')

# Log the event
echo "[$(date '+%Y-%m-%d %H:%M:%S')] TeammateIdle: ${teammate_id} (${teammate_type}) task=${task_id}" >> "$LOG_DIR/agent-teams.log"

# Initialize blocking issues
BLOCKING_ISSUES=""

# Quality Gate 1: Check for console.log/console.debug in modified files
if [[ -n "$files_modified" ]] && [[ "$files_modified" != "[]" ]]; then
    for file in $(echo "$files_modified" | jq -r '.[]' 2>/dev/null); do
        if [[ -f "$file" ]]; then
            # Skip non-code files
            case "$file" in
                *.md|*.json|*.yaml|*.yml|*.txt|*.sh) continue ;;
            esac

            if grep -qE "console\.(log|debug)\(" "$file" 2>/dev/null; then
                BLOCKING_ISSUES+="console.log/debug found in $file\n"
            fi
        fi
    done
fi

# Quality Gate 2: Check for debugger statements
if [[ -n "$files_modified" ]] && [[ "$files_modified" != "[]" ]]; then
    for file in $(echo "$files_modified" | jq -r '.[]' 2>/dev/null); do
        if [[ -f "$file" ]] && [[ "$file" =~ \.(ts|tsx|js|jsx|py)$ ]]; then
            if grep -qE "debugger;|breakpoint\(\)" "$file" 2>/dev/null; then
                BLOCKING_ISSUES+="debugger statement found in $file\n"
            fi
        fi
    done
fi

# Quality Gate 3: Check for TODO/FIXME in new code (advisory, not blocking for idle)
# This is logged but doesn't block idle - task completion will catch it

# Output decision
if [[ -n "$BLOCKING_ISSUES" ]]; then
    feedback=$(echo -e "$BLOCKING_ISSUES" | tr '\n' ' ' | sed 's/\\n/ /g')
    cat <<EOF
{"decision": "request_changes", "reason": "Quality issues found", "feedback": "Please fix before going idle: $feedback"}
EOF
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] TeammateIdle BLOCKED: ${teammate_id} - $feedback" >> "$LOG_DIR/agent-teams.log"
    exit 2
else
    cat <<EOF
{"decision": "approve", "reason": "All quality checks passed"}
EOF
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] TeammateIdle APPROVED: ${teammate_id}" >> "$LOG_DIR/agent-teams.log"
    exit 0
fi
