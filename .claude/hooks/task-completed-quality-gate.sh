#!/bin/bash
# task-completed-quality-gate.sh - Quality gate before task completion
# VERSION: 2.88.0
# REPO: multi-agent-ralph-loop
#
# Triggered by: TaskCompleted hook event
# Exit codes:
#   0 = Allow task to complete
#   2 = Prevent completion + send feedback
#
# Input (stdin JSON):
#   {
#     "taskId": "task-xxx",
#     "taskDescription": "Implement feature X",
#     "filesModified": ["file1.ts", "file2.py"],
#     "teammateId": "teammate-xxx"
#   }
#
# Output (stdout JSON):
#   {"decision": "approve", "reason": "All acceptance criteria verified"}
#   {"decision": "request_changes", "reason": "Task incomplete", "feedback": "..."}

set -euo pipefail

# Configuration - v2.89.2: Dynamic path + official field names
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo "${CLAUDE_PROJECT_DIR:-.}")"
LOG_DIR="$HOME/.ralph/logs"
mkdir -p "$LOG_DIR"

# Read stdin (SEC-111 compliant)
stdin_data=$(head -c 100000)

# Extract info - official Claude Code field names first, then fallbacks
task_id=$(echo "$stdin_data" | jq -r '.task_id // .taskId // "unknown"')
task_description=$(echo "$stdin_data" | jq -r '.task_description // .taskDescription // ""')
task_subject=$(echo "$stdin_data" | jq -r '.task_subject // ""')
teammate_id=$(echo "$stdin_data" | jq -r '.teammate_name // .teammateId // .teammate_id // "unknown"')
team_name=$(echo "$stdin_data" | jq -r '.team_name // "unknown"')

# Log the event
echo "[$(date '+%Y-%m-%d %H:%M:%S')] TaskCompleted: ${task_id} by ${teammate_id}" >> "$LOG_DIR/agent-teams.log"

# Initialize blocking issues
BLOCKING_ISSUES=""
ADVISORY_ISSUES=""

# Quality Gate 1: Check for TODO/FIXME/XXX (blocking for task completion)
if [[ -n "$files_modified" ]] && [[ "$files_modified" != "[]" ]]; then
    for file in $(echo "$files_modified" | jq -r '.[]' 2>/dev/null); do
        if [[ -f "$file" ]] && [[ "$file" =~ \.(ts|tsx|js|jsx|py|go|rs|java|kt)$ ]]; then
            if grep -qE "TODO:|FIXME:|XXX:|HACK:" "$file" 2>/dev/null; then
                BLOCKING_ISSUES+="Unresolved TODO/FIXME in $file\n"
            fi
        fi
    done
fi

# Quality Gate 2: Check for placeholder code (blocking)
if [[ -n "$files_modified" ]] && [[ "$files_modified" != "[]" ]]; then
    for file in $(echo "$files_modified" | jq -r '.[]' 2>/dev/null); do
        if [[ -f "$file" ]]; then
            if grep -qE "(throw new Error\\('Not implemented|throw new Error\\(\"Not implemented|# TODO:|pass # placeholder|raise NotImplementedError)" "$file" 2>/dev/null; then
                BLOCKING_ISSUES+="Placeholder code found in $file\n"
            fi
        fi
    done
fi

# Quality Gate 3: Check for console.log (blocking for completion)
if [[ -n "$files_modified" ]] && [[ "$files_modified" != "[]" ]]; then
    for file in $(echo "$files_modified" | jq -r '.[]' 2>/dev/null); do
        if [[ -f "$file" ]] && [[ "$file" =~ \.(ts|tsx|js|jsx|py)$ ]]; then
            if grep -qE "console\.(log|debug)\(" "$file" 2>/dev/null; then
                BLOCKING_ISSUES+="console.log/debug found in $file (remove before completion)\n"
            fi
        fi
    done
fi

# Quality Gate 4: Check for debugger statements (blocking)
if [[ -n "$files_modified" ]] && [[ "$files_modified" != "[]" ]]; then
    for file in $(echo "$files_modified" | jq -r '.[]' 2>/dev/null); do
        if [[ -f "$file" ]] && [[ "$file" =~ \.(ts|tsx|js|jsx|py)$ ]]; then
            if grep -qE "debugger;|breakpoint\(\)|import pdb" "$file" 2>/dev/null; then
                BLOCKING_ISSUES+="debugger/breakpoint found in $file\n"
            fi
        fi
    done
fi

# Quality Gate 5: Check for empty function bodies (advisory)
if [[ -n "$files_modified" ]] && [[ "$files_modified" != "[]" ]]; then
    for file in $(echo "$files_modified" | jq -r '.[]' 2>/dev/null); do
        if [[ -f "$file" ]] && [[ "$file" =~ \.(ts|tsx|js|jsx)$ ]]; then
            # Check for functions with only empty body or just comments
            if grep -qE "(function|const|let|var)\s+\w+\s*=\s*(async\s*)?\([^)]*\)\s*(=>|:\s*\w+\s*\{)\s*(//|/\*)?\s*\}" "$file" 2>/dev/null; then
                ADVISORY_ISSUES+="Potential empty function in $file\n"
            fi
        fi
    done
fi

# Output decision
# v2.89.2 FIX: TaskCompleted uses exit codes only per official docs
# Exit 0 = allow completion, Exit 2 = block with feedback on stderr
if [[ -n "$BLOCKING_ISSUES" ]]; then
    feedback=$(echo -e "$BLOCKING_ISSUES" | tr '\n' ' ' | sed 's/\\n/ /g')
    echo "Please resolve before marking complete: $feedback" >&2
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] TaskCompleted BLOCKED: ${task_id} - $feedback" >> "$LOG_DIR/agent-teams.log"
    exit 2
elif [[ -n "$ADVISORY_ISSUES" ]]; then
    advisory=$(echo -e "$ADVISORY_ISSUES" | tr '\n' ' ')
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] TaskCompleted ADVISORY: ${task_id} - $advisory" >> "$LOG_DIR/agent-teams.log"
fi

# All checks passed
echo "[$(date '+%Y-%m-%d %H:%M:%S')] TaskCompleted APPROVED: ${task_id}" >> "$LOG_DIR/agent-teams.log"
exit 0
