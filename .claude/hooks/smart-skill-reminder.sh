#!/usr/bin/env bash
#===============================================================================
# Smart Skill Reminder Hook (v2.0.0)
# PreToolUse hook - Context-aware skill suggestions BEFORE writing code
#===============================================================================
#
# VERSION: 2.68.23
# TRIGGER: PreToolUse (Edit|Write)
# PURPOSE: Intelligently suggest relevant skills based on file context
#
# IMPROVEMENTS OVER v1.0.0:
# - Fires on PreToolUse (BEFORE code is written, not after)
# - Session gating: only reminds once per session
# - Context-aware: suggests specific skills based on file type/path
# - Rate limiting: respects cooldown period
# - Skill invocation detection: skips if skill was recently used
#
# Based on adversarial review by Claude Opus + OpenAI Codex gpt-5.2

# SEC-111: Read input from stdin with length limit (100KB max)
# Prevents DoS from malicious input
INPUT=$(head -c 100000)


set -euo pipefail
umask 077

readonly VERSION="2.0.0"
readonly HOOK_NAME="smart-skill-reminder"

# Configuration
readonly MARKERS_DIR="${HOME}/.ralph/markers"
readonly COOLDOWN_MINUTES=30
readonly LOG_FILE="${HOME}/.ralph/logs/skill-reminder.log"

# Ensure directories exist
mkdir -p "$MARKERS_DIR" "$(dirname "$LOG_FILE")" 2>/dev/null || true

# Guaranteed JSON output on any error
output_empty() {
    echo '{"decision": "allow"}'
}
trap 'output_empty' ERR

# Logging (silent by default)
log() {
    echo "[$(date -Iseconds)] [$HOOK_NAME] $*" >> "$LOG_FILE" 2>/dev/null || true
}

# Get session ID (use PPID as proxy for session)
get_session_id() {
    echo "${CLAUDE_SESSION_ID:-$$}"
}

# Check if we've already reminded this session
already_reminded_this_session() {
    local session_id
    session_id=$(get_session_id)
    local marker="${MARKERS_DIR}/skill-reminded-${session_id}"
    [[ -f "$marker" ]]
}

# Mark session as reminded
mark_session_reminded() {
    local session_id
    session_id=$(get_session_id)
    local marker="${MARKERS_DIR}/skill-reminded-${session_id}"
    touch "$marker" 2>/dev/null || true
}

# Check cooldown (rate limiting)
is_within_cooldown() {
    local marker="${MARKERS_DIR}/skill-reminder-cooldown"
    if [[ -f "$marker" ]]; then
        local marker_age
        marker_age=$(( $(date +%s) - $(stat -f %m "$marker" 2>/dev/null || echo 0) ))
        (( marker_age < COOLDOWN_MINUTES * 60 ))
    else
        return 1
    fi
}

# Update cooldown marker
update_cooldown() {
    local marker="${MARKERS_DIR}/skill-reminder-cooldown"
    touch "$marker" 2>/dev/null || true
}

# Check if a skill was recently invoked (within last 5 tool calls)
skill_recently_invoked() {
    # Check if Skill tool was used recently by looking at recent logs
    local recent_skills="${MARKERS_DIR}/recent-skill-invocation"
    if [[ -f "$recent_skills" ]]; then
        local age
        age=$(( $(date +%s) - $(stat -f %m "$recent_skills" 2>/dev/null || echo 0) ))
        (( age < 300 ))  # Within last 5 minutes
    else
        return 1
    fi
}

# Determine suggested skill based on file path
# PRIORITY ORDER: Tests > Security > Language > Architecture
suggest_skill_for_file() {
    local file_path="$1"
    local filename
    filename=$(basename "$file_path" 2>/dev/null || echo "")
    local dir_path
    dir_path=$(dirname "$file_path" 2>/dev/null || echo "")

    # HIGHEST PRIORITY: Test files (check first to avoid false positives like test_auth.py)
    # SC2221/SC2222 FIX: Removed redundant patterns (*test* already covers *.test.* and *__tests__*)
    case "$file_path" in
        *test*|*spec*)
            echo "/test-driven-development for test files"
            return 0
            ;;
    esac

    # Security-sensitive files
    # SC2221/SC2222 FIX: Removed *oauth* (already covered by *auth*)
    case "$file_path" in
        *auth*|*login*|*password*|*credential*|*secret*|*token*|*jwt*)
            echo "/security-loop for security-sensitive code"
            return 0
            ;;
        *payment*|*billing*|*stripe*|*checkout*|*transaction*)
            echo "/security-loop for payment/financial code"
            return 0
            ;;
    esac

    # Language-specific suggestions
    case "$filename" in
        *.py)
            echo "/python-pro for Python best practices"
            return 0
            ;;
        *.ts|*.tsx)
            echo "/typescript-pro for TypeScript patterns"
            return 0
            ;;
        *.js|*.jsx)
            echo "/javascript-pro for JavaScript patterns"
            return 0
            ;;
        *.sh|*.bash)
            echo "/bash-pro for shell scripting"
            return 0
            ;;
        *.sol)
            echo "/blockchain-web3:blockchain-developer for Solidity"
            return 0
            ;;
        *.rs)
            echo "/rust-pro for Rust patterns"
            return 0
            ;;
        *.go)
            echo "/go-pro for Go patterns"
            return 0
            ;;
    esac

    # Architecture/config files
    case "$filename" in
        Dockerfile*|docker-compose*|*.dockerfile)
            echo "/cicd-automation:deployment-engineer for Docker"
            return 0
            ;;
        *.tf|*.tfvars)
            echo "/cicd-automation:terraform-specialist for Terraform"
            return 0
            ;;
        *.yaml|*.yml)
            if [[ "$file_path" == *k8s* ]] || [[ "$file_path" == *kubernetes* ]]; then
                echo "/kubernetes-operations:kubernetes-architect for K8s"
                return 0
            fi
            ;;
    esac

    # API/Backend patterns
    case "$dir_path" in
        *api*|*routes*|*controllers*|*handlers*)
            echo "/backend-development:backend-architect for API design"
            return 0
            ;;
        *components*|*pages*|*views*)
            echo "/frontend-mobile-development:frontend-developer for UI components"
            return 0
            ;;
    esac

    # No specific suggestion
    return 1
}

# Main logic
main() {
    # Read input from stdin (PreToolUse provides tool context)
    local input
    input=$(cat 2>/dev/null || echo '{"decision": "allow"}')

    # Extract file path from tool input
    local file_path
    file_path=$(echo "$input" | jq -r '.tool_input.file_path // .tool_input.path // empty' 2>/dev/null || echo "")

    # Gate 1: Skip if no file path (can't make context-aware suggestion)
    if [[ -z "$file_path" ]]; then
        log "No file path in input, skipping"
        echo '{"decision": "allow"}'
        exit 0
    fi

    # Gate 2: Skip if already reminded this session
    if already_reminded_this_session; then
        log "Already reminded this session, skipping"
        echo '{"decision": "allow"}'
        exit 0
    fi

    # Gate 3: Skip if within cooldown period
    if is_within_cooldown; then
        log "Within cooldown period, skipping"
        echo '{"decision": "allow"}'
        exit 0
    fi

    # Gate 4: Skip if a skill was recently invoked
    if skill_recently_invoked; then
        log "Skill recently invoked, skipping"
        echo '{"decision": "allow"}'
        exit 0
    fi

    # Get context-aware suggestion
    local suggestion
    if suggestion=$(suggest_skill_for_file "$file_path"); then
        # Mark as reminded and update cooldown
        mark_session_reminded
        update_cooldown

        log "Suggesting: $suggestion for $file_path"

        # Output suggestion
        # CRIT-012: PreToolUse MUST use {"decision": "allow"}, NOT hookSpecificOutput
        jq -n --arg ctx "Consider using $suggestion" \
            '{"decision": "allow", "additionalContext": $ctx}'
    else
        # No suggestion for this file type
        log "No specific skill suggestion for: $file_path"
        echo '{"decision": "allow"}'
    fi
}

main "$@"
