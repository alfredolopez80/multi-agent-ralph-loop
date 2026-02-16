#!/bin/bash
# teammate-idle-quality-gate.sh - Quality gate for Agent Teams teammates
# VERSION: 2.90.0
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

# Configuration - v2.89.2: Dynamic path + official field names
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo "${CLAUDE_PROJECT_DIR:-.}")"
LOG_DIR="$HOME/.ralph/logs"
mkdir -p "$LOG_DIR"

# Read stdin (SEC-111 compliant)
stdin_data=$(head -c 100000)

# Extract info - official Claude Code field names first, then fallbacks
teammate_id=$(echo "$stdin_data" | jq -r '.teammate_name // .teammateId // .teammate_id // "unknown"')
teammate_type=$(echo "$stdin_data" | jq -r '.agent_type // .teammateType // .teammate_type // "unknown"')
task_id=$(echo "$stdin_data" | jq -r '.task_id // .taskId // "unknown"')
team_name=$(echo "$stdin_data" | jq -r '.team_name // "unknown"')
# v2.90.0 FIX: Extract files_modified from stdin (was missing!)
files_modified=$(echo "$stdin_data" | jq -c '.files_modified // .filesModified // []')

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

# Quality Gate 3: Basic security pattern check - hardcoded secrets (CWE-798)
# v2.90.1 FIX (FINDING-007): Add deeper security validation
if [[ -n "$files_modified" ]] && [[ "$files_modified" != "[]" ]]; then
    for file in $(echo "$files_modified" | jq -r '.[]' 2>/dev/null); do
        if [[ -f "$file" ]]; then
            # Skip non-code files
            case "$file" in
                *.md|*.json|*.yaml|*.yml|*.txt|*.sh|*.log) continue ;;
            esac

            # Check for hardcoded API key prefixes (P0 Critical - CWE-798)
            if grep -qE '(sk_live_[a-zA-Z0-9]{10,}|sk_test_[a-zA-Z0-9]{10,}|AKIA[A-Z0-9]{16}|ghp_[a-zA-Z0-9]{36}|AIza[a-zA-Z0-9_-]{35})' "$file" 2>/dev/null; then
                BLOCKING_ISSUES+="SECURITY: Hardcoded API key prefix found in $file (CWE-798)\n"
            fi

            # Check for private keys
            if grep -qE '-----BEGIN (RSA |EC |DSA |OPENSSH )?PRIVATE KEY-----' "$file" 2>/dev/null; then
                BLOCKING_ISSUES+="SECURITY: Private key found in $file (CWE-321)\n"
            fi
        fi
    done
fi

# Quality Gate 4: Syntax validation for common file types
# v2.90.1 FIX (FINDING-007): Catch syntax errors before idle
if [[ -n "$files_modified" ]] && [[ "$files_modified" != "[]" ]]; then
    for file in $(echo "$files_modified" | jq -r '.[]' 2>/dev/null); do
        [[ -f "$file" ]] || continue
        case "$file" in
            *.py)
                if ! python3 -m py_compile "$file" 2>/dev/null; then
                    BLOCKING_ISSUES+="SYNTAX: Python syntax error in $file\n"
                fi
                ;;
            *.js|*.jsx)
                if command -v node &>/dev/null && ! node --check "$file" 2>/dev/null; then
                    BLOCKING_ISSUES+="SYNTAX: JavaScript syntax error in $file\n"
                fi
                ;;
            *.sh|*.bash)
                if ! bash -n "$file" 2>/dev/null; then
                    BLOCKING_ISSUES+="SYNTAX: Bash syntax error in $file\n"
                fi
                ;;
        esac
    done
fi

# Output decision
# v2.89.2 FIX: TeammateIdle uses exit codes only per official docs
# Exit 0 = allow idle, Exit 2 = block with feedback on stderr
if [[ -n "$BLOCKING_ISSUES" ]]; then
    feedback=$(echo -e "$BLOCKING_ISSUES" | tr '\n' ' ' | sed 's/\\n/ /g')
    echo "Please fix before going idle: $feedback" >&2
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] TeammateIdle BLOCKED: ${teammate_id} - $feedback" >> "$LOG_DIR/agent-teams.log"
    exit 2
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] TeammateIdle APPROVED: ${teammate_id}" >> "$LOG_DIR/agent-teams.log"
    exit 0
fi
