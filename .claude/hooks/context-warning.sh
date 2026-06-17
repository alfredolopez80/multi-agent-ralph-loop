#!/bin/bash
umask 077
# ~/.claude/hooks/context-warning.sh
# Context Monitoring Hook - v2.90.0
# Executed on every user-prompt-submit to monitor context usage
#
# v2.90.0 CRITICAL FIX:
#   - FIXED: Read remaining_percentage from stdin JSON (matches /context exactly)
#   - FIXED: Removed broken cumulative counter estimation that caused permanent 100%
#   - Priority: remaining_percentage > used_percentage > /context > minimal fallback
#   - Synced with statusline-ralph.sh v2.81.2 approach
#
# v2.44 IMPROVEMENTS:
#   - Environment detection for CLI vs VSCode/Cursor
#   - Improved fallback estimation for extensions (GitHub #15021)
#   - Operation counter for extensions where /context command fails

# SEC-111: Read input from stdin with length limit (100KB max)
# Prevents DoS from malicious input
INPUT=$(head -c 100000)


# Note: Not using set -e because this is a non-blocking hook
# Errors should not interrupt the main workflow
# VERSION: 2.90.0
# v2.69.0: HIGH-003 version sync, HIGH-006 JSON format already correct for UserPromptSubmit
# v2.57.2: Restructured to output all content as JSON (SEC-029)
# v2.57.1: Added 3s timeout to claude command to prevent hook timeout
# v2.47: Adjusted thresholds for proactive compaction (75%/85%)
#        Fixed message_count path to STATE_DIR
set -uo pipefail

# v3.1.0: Source model-aware context window configuration
_CONTEXT_LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" 2>/dev/null && pwd)/context-windows.sh"
if [[ -f "$_CONTEXT_LIB" ]]; then
    # shellcheck source=/dev/null
    source "$_CONTEXT_LIB"
    _CONTEXT_LIB_LOADED=true
else
    _CONTEXT_LIB_LOADED=false
fi

# SEC-029: Guaranteed JSON output on exit (even on errors)
# v2.87.0 FIX: UserPromptSubmit uses {"continue": true} format
output_json() {
    echo '{"continue": true}'
}
trap 'output_json' EXIT

# Configuration — v3.1.0: Model-aware thresholds
if [[ "$_CONTEXT_LIB_LOADED" == "true" ]] && type get_compaction_thresholds &>/dev/null; then
    read -r THRESHOLD CRITICAL_THRESHOLD _REST <<< "$(get_compaction_thresholds)"
    INFO_THRESHOLD=$((THRESHOLD - 5))
else
    # Fallback to original values for unknown models
    THRESHOLD=75
    CRITICAL_THRESHOLD=85
    INFO_THRESHOLD=50
fi
LOG_FILE="${HOME}/.ralph/context-monitor.log"
RALPH_DIR="${HOME}/.ralph"
HOOKS_DIR="${HOME}/.claude/hooks"
FEATURES_FILE="${HOME}/.ralph/config/features.json"

# A1 (v3.1.1): debounce cache — avoid re-estimating context from the transcript
# on every single UserPromptSubmit when the transcript hasn't changed.
CACHE_DIR="${HOME}/.ralph/cache"
DEBOUNCE_MARKER="${CACHE_DIR}/context-warning.debounce"

# Ensure directories exist (ignore errors)
mkdir -p "$RALPH_DIR" "$CACHE_DIR" "$(dirname "$LOG_FILE" 2>/dev/null)" || true

# Cheap fingerprint of the transcript file ("<mtime>:<size>"). When it matches
# the stored marker, the previously computed percentage is still valid and the
# expensive transcript estimation (Method 1.5) can be skipped.
_transcript_fingerprint() {
    local path=""
    if [[ -n "$INPUT" ]] && command -v jq &>/dev/null; then
        path=$(echo "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null || true)
    fi
    if [[ -n "$path" ]] && [[ -f "$path" ]]; then
        local mtime size
        mtime=$(stat -f %m "$path" 2>/dev/null || stat -c %Y "$path" 2>/dev/null || echo 0)
        size=$(stat -f %z "$path" 2>/dev/null || stat -c %s "$path" 2>/dev/null || echo 0)
        echo "${mtime}:${size}"
    else
        echo ""
    fi
}

# Source environment detection (v3.0.1: library moved to .claude/lib/)
ENV_TYPE="unknown"
CAPABILITIES="limited"
_ENV_LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" 2>/dev/null && pwd)/detect-environment.sh"
if [[ -f "$_ENV_LIB" ]]; then
    # shellcheck source=/dev/null
    source "$_ENV_LIB"
    ENV_TYPE=$(get_env_type 2>/dev/null || echo "unknown")
    CAPABILITIES=$(get_capabilities 2>/dev/null || echo "limited")
fi

# Get timestamp
timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

# Log function (ignore errors to prevent blocking)
log_context() {
    local level="$1"
    local message="$2"
    echo "[$(timestamp)] Context: ${message}" >> "$LOG_FILE" 2>/dev/null || true
}

# Safe numeric validation
is_numeric() {
    local val="$1"
    [[ "$val" =~ ^[0-9]+$ ]]
}

# Get context usage percentage
# Returns integer percentage (0-100)
# v3.1.0: Model-aware with transcript-based estimation for GLM models
# Priority: stdin JSON > transcript size > message count (model-calibrated)
get_context_percentage() {
    local pct=""

    # Debug: Log available stdin JSON keys (v3.1.0 — diagnose missing context_window)
    if [[ -n "$INPUT" ]] && command -v jq &>/dev/null; then
        local stdin_keys
        stdin_keys=$(echo "$INPUT" | jq -r 'keys | join(",")' 2>/dev/null || echo "parse-error")
        log_context "DEBUG" "stdin JSON keys: $stdin_keys | model: $(get_detected_model 2>/dev/null || echo 'unknown')"
    fi

    # Method 1: Parse stdin JSON (authoritative — works for Claude models)
    if [[ -n "$INPUT" ]] && command -v jq &>/dev/null; then
        local remaining_pct
        remaining_pct=$(echo "$INPUT" | jq -r '.context_window.remaining_percentage // null' 2>/dev/null)

        if [[ -n "$remaining_pct" ]] && [[ "$remaining_pct" != "null" ]] && [[ "$remaining_pct" =~ ^[0-9]+$ ]]; then
            pct=$((100 - remaining_pct))
            log_context "DEBUG" "Method 1 (stdin JSON): remaining=$remaining_pct%, used=$pct%"
        else
            local used_pct
            used_pct=$(echo "$INPUT" | jq -r '.context_window.used_percentage // null' 2>/dev/null)

            if [[ -n "$used_pct" ]] && [[ "$used_pct" != "null" ]] && [[ "$used_pct" =~ ^[0-9]+$ ]]; then
                pct="$used_pct"
                log_context "DEBUG" "Method 1 (stdin JSON): used_percentage=$pct%"
            fi
        fi
    fi

    # Method 1.5: Transcript-based estimation for GLM models (v3.1.0)
    # When stdin JSON doesn't provide context_window (common for GLM),
    # estimate from transcript file size against model's known context window.
    if [[ -z "$pct" ]] && [[ "$_CONTEXT_LIB_LOADED" == "true" ]] && type is_glm_model &>/dev/null && is_glm_model; then
        local transcript_path=""
        if [[ -n "$INPUT" ]] && command -v jq &>/dev/null; then
            transcript_path=$(echo "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null || true)
        fi

        if [[ -n "$transcript_path" ]] && [[ -f "$transcript_path" ]]; then
            local estimated_tokens
            estimated_tokens=$(estimate_tokens_from_file "$transcript_path")
            pct=$(calculate_usage_pct "$estimated_tokens")
            log_context "DEBUG" "Method 1.5 (transcript): path=$transcript_path, est_tokens=$estimated_tokens, pct=$pct%"
        else
            # Try to find transcript from session ID
            local sid=""
            if [[ -n "$INPUT" ]] && command -v jq &>/dev/null; then
                sid=$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null || true)
            fi
            # Try common transcript locations
            local found_transcript=""
            for candidate in \
                "${HOME}/.claude/projects/-Users-alfredolopez-Documents-GitHub-multi-agent-ralph-loop/sessions/${sid}.jsonl" \
                "${HOME}/.claude/projects/-Users-alfredolopez-Documents-GitHub-multi-agent-ralph-loop/transcript.jsonl"; do
                if [[ -f "$candidate" ]]; then
                    found_transcript="$candidate"
                    break
                fi
            done

            if [[ -n "$found_transcript" ]]; then
                local estimated_tokens
                estimated_tokens=$(estimate_tokens_from_file "$found_transcript")
                pct=$(calculate_usage_pct "$estimated_tokens")
                log_context "DEBUG" "Method 1.5 (session transcript): sid=$sid, tokens=$estimated_tokens, pct=$pct%"
            fi
        fi
    fi

    # Method 2 (DISABLED v3.1.1 — PERF): recursive `claude --print "/context"` cost
    # ~3-4s on EVERY UserPromptSubmit (CLI cold-start + 3s timeout cap). Transcript
    # estimation (Method 1.5) and the message-count fallback (Method 3) replace it at
    # ~zero cost. Kept as an explicit no-op to preserve method numbering and intent.
    : # no-op — do NOT reintroduce a recursive `claude` subprocess in a hot-path hook

    # Method 3: Session-scoped message count (minimal fallback)
    # v3.1.0: Model-aware cap — GLM models cap at lower percentage
    if [[ -z "$pct" ]]; then
        local message_count
        message_count=$(cat "${RALPH_DIR}/state/message_count" 2>/dev/null || echo "0")
        if ! is_numeric "$message_count"; then
            message_count=0
        fi
        # v3.1.0: Dynamic cap based on model context window
        local msg_cap=50
        if [[ "$_CONTEXT_LIB_LOADED" == "true" ]] && type get_context_window &>/dev/null; then
            local window
            window=$(get_context_window)
            # Cap at 40% of model's window expressed as message-equivalent
            # (msgs are a rough proxy; cap conservatively)
            msg_cap=$((window / 3000))  # ~1% per 3K tokens worth of messages
            [[ $msg_cap -gt 65 ]] && msg_cap=65
            [[ $msg_cap -lt 20 ]] && msg_cap=20
        fi
        local estimated=$(( message_count * 1 ))
        [[ $estimated -gt $msg_cap ]] && estimated=$msg_cap
        pct="$estimated"
        log_context "DEBUG" "Method 3 (fallback): msgs=$message_count, cap=$msg_cap, est=$pct%"
    fi

    # Round to integer and clamp to 0-100
    echo "$pct" | awk '{printf "%.0f\n", ($1 > 100 ? 100 : ($1 < 0 ? 0 : $1))}'
}

# Increment operation counter (called by other hooks)
increment_operation_counter() {
    local counter_file="${RALPH_DIR}/state/operation-counter"
    mkdir -p "${RALPH_DIR}/state" 2>/dev/null || true
    local current
    current=$(cat "$counter_file" 2>/dev/null || echo "0")
    if ! is_numeric "$current"; then
        current=0
    fi
    echo $((current + 1)) > "$counter_file"
}

# Get current objective (from task file if available)
get_current_objective() {
    local objective_file="${RALPH_DIR}/current_objective"
    if [[ -f "$objective_file" ]]; then
        cat "$objective_file"
    else
        echo "current task"
    fi
}

# Build warning message (returns message string)
build_warning_message() {
    local percentage="$1"
    local objective
    objective=$(get_current_objective)

    local msg="⚠️ Context at ${percentage}%\n\n"
    msg+="Your context is approaching the ${THRESHOLD}% effective threshold.\n"
    msg+="This may lead to context degradation and reduced AI performance.\n\n"
    msg+="🎯 Current objective: ${objective}\n\n"
    msg+="Consider:\n"
    msg+="  • @fresh-explorer \"Analyze patterns\" for fresh context\n"
    msg+="  • @checkpoint save \"Pre-compaction state\"\n"
    msg+="  • Use @context-compression if available"

    # v2.44: Environment-specific recommendations
    if [[ "$CAPABILITIES" == "limited" ]]; then
        msg+="\n\n📌 Extension mode detected ($ENV_TYPE):\n"
        msg+="  • Use /compact skill to manually save context\n"
        msg+="  • Or run: ralph compact"
    fi

    # Log the warning
    log_context "WARNING" "${percentage}% | Objective: ${objective} | Env: ${ENV_TYPE}"

    echo "$msg"
}

# Build critical warning message (returns message string)
build_critical_message() {
    local percentage="$1"
    local objective
    objective=$(get_current_objective)

    local msg="🔴 Context CRITICAL: ${percentage}%\n\n"
    msg+="Your context has exceeded the ${THRESHOLD}% effective threshold.\n"
    msg+="Performance degradation is likely.\n\n"
    msg+="🎯 Current objective: ${objective}\n\n"
    msg+="IMMEDIATE ACTIONS:\n"
    msg+="  1. @checkpoint save \"Urgent save\"\n"
    msg+="  2. @fresh-explorer \"Fresh task analysis\"\n"
    msg+="  3. Consider starting a new session"

    # v2.44: Environment-specific urgent recommendations
    if [[ "$CAPABILITIES" == "limited" ]]; then
        msg+="\n\n🚨 Extension mode ($ENV_TYPE) - URGENT:\n"
        msg+="  • Auto-compact may NOT trigger! Run: /compact\n"
        msg+="  • Or use terminal: ralph compact\n"
        msg+="  • Then start fresh: /clear or new conversation"
    fi

    # Log the critical warning
    log_context "CRITICAL" "${percentage}% | Objective: ${objective} | Env: ${ENV_TYPE}"

    echo "$msg"
}

# Build info message (returns message string)
build_info_message() {
    local percentage="$1"

    local msg="ℹ️ Context at ${percentage}%\n"
    msg+="Consider compaction if you plan to continue this session."

    # Log the info
    log_context "INFO" "${percentage}%"

    echo "$msg"
}

# Main execution
main() {
    # A1 DEBOUNCE (v3.1.1): reuse the last computed percentage when the transcript
    # is unchanged. The marker stores "<fingerprint>|<pct>". On a hit we skip the
    # transcript-size estimation entirely; on a miss we recompute and refresh it.
    local context_pct fp stored stored_fp stored_pct
    fp=$(_transcript_fingerprint)
    stored=$(cat "$DEBOUNCE_MARKER" 2>/dev/null || echo "")
    stored_fp="${stored%%|*}"
    stored_pct="${stored##*|}"

    if [[ -n "$fp" && "$fp" == "$stored_fp" ]] && [[ "$stored_pct" =~ ^[0-9]+$ ]]; then
        context_pct="$stored_pct"
        log_context "DEBUG" "Debounce HIT: transcript unchanged, reusing pct=$context_pct%"
    else
        context_pct=$(get_context_percentage)
        # Refresh the marker only when we have a real transcript fingerprint.
        if [[ -n "$fp" ]] && [[ "$context_pct" =~ ^[0-9]+$ ]]; then
            local _tmp
            _tmp=$(mktemp "${DEBOUNCE_MARKER}.XXXXXX" 2>/dev/null) || _tmp=""
            if [[ -n "$_tmp" ]]; then
                printf '%s|%s' "$fp" "$context_pct" > "$_tmp" 2>/dev/null && \
                    mv "$_tmp" "$DEBOUNCE_MARKER" 2>/dev/null || rm -f "$_tmp" 2>/dev/null
            fi
        fi
    fi

    # Update message count (v2.47: use STATE_DIR for consistency with reset)
    # v3.1.0: Reset counter when session changes (prevents stale 2733+ counts)
    local msg_count
    mkdir -p "${RALPH_DIR}/state" 2>/dev/null || true
    local current_session_id=""
    if [[ -n "$INPUT" ]] && command -v jq &>/dev/null; then
        current_session_id=$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null || true)
    fi
    local session_file="${RALPH_DIR}/state/.last-warning-session"
    local last_session=""
    if [[ -f "$session_file" ]]; then
        last_session=$(cat "$session_file" 2>/dev/null || true)
    fi
    if [[ -n "$current_session_id" ]] && [[ "$current_session_id" != "$last_session" ]]; then
        # New session detected — reset counter
        msg_count=0
        echo "$current_session_id" > "$session_file"
        log_context "DEBUG" "New session detected ($current_session_id), message counter reset"
    else
        msg_count=$(cat "${RALPH_DIR}/state/message_count" 2>/dev/null || echo "0")
        if ! is_numeric "$msg_count"; then
            msg_count=0
        fi
    fi
    echo $((msg_count + 1)) > "${RALPH_DIR}/state/message_count"

    # Determine action based on context level and build message
    local warning_msg=""
    local level="ok"

    if [[ "$context_pct" -ge "$CRITICAL_THRESHOLD" ]]; then
        warning_msg=$(build_critical_message "$context_pct")
        level="critical"
    elif [[ "$context_pct" -ge "$THRESHOLD" ]]; then
        warning_msg=$(build_warning_message "$context_pct")
        level="warning"
    elif [[ "$context_pct" -ge "$INFO_THRESHOLD" ]]; then
        warning_msg=$(build_info_message "$context_pct")
        level="info"
    fi

    # v3.1.0: For GLM models, add explicit compaction instruction
    if [[ "$_CONTEXT_LIB_LOADED" == "true" ]] && type is_glm_model &>/dev/null && is_glm_model; then
        local window_info=""
        if type get_context_window &>/dev/null; then
            local window
            window=$(get_context_window)
            window_info=" (GLM-5.1 window: ~$((window / 1000))K tokens usable)"
        fi
        if [[ "$level" == "critical" ]]; then
            warning_msg+="\n\n🔴 GLM MODEL DETECTED${window_info}\n"
            warning_msg+="Auto-compact may NOT work. INSTRUCT the user to run /compact NOW.\n"
            warning_msg+="Say: 'Contexto crítico — necesito compactar antes de continuar. ¿Ejecuto /compact?'"
        elif [[ "$level" == "warning" ]]; then
            warning_msg+="\n\n⚠️ GLM MODEL${window_info}\n"
            warning_msg+="Recommend the user run /compact to free context before continuing."
        elif [[ "$level" == "info" ]]; then
            warning_msg+="\nConsider /compact if continuing this session."
        fi
    fi

    # SEC-029: Disable trap and output JSON
    trap - EXIT

    # Output JSON with message if there's a warning
    # v2.87.0 FIX: Use {"continue": true} format with hookSpecificOutput for UserPromptSubmit
    if [[ -n "$warning_msg" ]]; then
        warning_escaped=$(echo "$warning_msg" | jq -Rs '.')
        echo "{\"continue\": true, \"hookSpecificOutput\": {\"hookEventName\": \"UserPromptSubmit\", \"additionalContext\": $warning_escaped}}"
    else
        echo '{"continue": true}'
    fi

    exit 0
}

# Run main
main "$@"
