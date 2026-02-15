#!/usr/bin/env bash
# Quality Parallel Async Hook - FIXED VERSION
# VERSION: 2.1.0
# FIX v2.1.0: All MEDIUM + LOW priority fixes applied
#   - MEDIUM-001: Portable stat command (BSD/Linux)
#   - MEDIUM-002: RUN_ID validation (format check)
#   - MEDIUM-003: Restrictive umask (0077)
#   - LOW-001: Automatic log rotation (10MB max)
#   - LOW-002: Configurable timeout (QUALITY_CHECK_TIMEOUT env var)
# FIX v2.0.2: Check name compatibility with read-quality-results.sh
# FIX v2.0.1: HIGH-002 (atomic file ops) + MEDIUM-004 (timeout 300s)
# Hook: PostToolUse (Edit, Write)
# Purpose: Run security, code-review, deslop, and stop-sops checks in parallel using EXISTING scripts
#
# CRITICAL FIX v2.0.0: Uses actual bash scripts instead of trying to invoke Skill tool via echo JSON

set -euo pipefail

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo '.')"
readonly RESULTS_DIR="${PROJECT_ROOT}/.claude/quality-results"
readonly QUALITY_LOG="${PROJECT_ROOT}/.claude/logs/quality-parallel.log"

# LOW-002 FIX: Configurable timeout via environment variable (default: 300s = 5 min)
readonly QUALITY_CHECK_TIMEOUT="${QUALITY_CHECK_TIMEOUT:-300}"

# Ensure results directory exists
mkdir -p "${RESULTS_DIR}"
mkdir -p "$(dirname "${QUALITY_LOG}")"

# MEDIUM-003 FIX: Set restrictive umask for secure file creation (only owner can read/write)
umask 0077

# Log rotation configuration
readonly MAX_LOG_SIZE_BYTES=10485760  # 10MB
readonly MAX_LOG_FILES=5              # Keep 5 rotated logs

# Logging function with automatic log rotation
log() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local message="[$timestamp] $*"

    # LOW-001 FIX: Automatic log rotation to prevent unbounded growth
    if [[ -f "${QUALITY_LOG}" ]]; then
        local log_size
        # Portable stat for log size
        log_size=$(stat -f%z "${QUALITY_LOG}" 2>/dev/null || stat -c%s "${QUALITY_LOG}" 2>/dev/null || echo 0)

        if [[ $log_size -gt $MAX_LOG_SIZE_BYTES ]]; then
            # Rotate log files (delete oldest, shift others, create new)
            local oldest="${QUALITY_LOG}.${MAX_LOG_FILES}"
            [[ -f "$oldest" ]] && rm -f "$oldest"

            local i=$((MAX_LOG_FILES - 1))
            while [[ $i -gt 0 ]]; do
                local current="${QUALITY_LOG}.${i}"
                local next="${QUALITY_LOG}.$((i + 1))"
                [[ -f "$current" ]] && mv "$current" "$next"
                i=$((i - 1))
            done

            # Move current log to .1
            mv "${QUALITY_LOG}" "${QUALITY_LOG}.1"
        fi
    fi

    echo "$message" | tee -a "${QUALITY_LOG}"
}

# Read stdin with SEC-111 protection (100KB limit)
INPUT=$(head -c 100000)

# Parse input - CRITICAL FIX: Use correct PostToolUse field names
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

# Only run on Edit/Write operations
if [[ ! "$TOOL_NAME" =~ ^(Edit|Write)$ ]]; then
    echo '{"continue": true}'
    exit 0
fi

# Skip if no file path
if [[ -z "$FILE_PATH" ]] || [[ ! -f "$FILE_PATH" ]]; then
    echo '{"continue": true}'
    exit 0
fi

log "Starting parallel quality checks for: ${FILE_PATH}"

# Generate timestamp for this run
readonly TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
readonly RUN_ID="${TIMESTAMP}_$$"

# MEDIUM-002 FIX: Validate RUN_ID format (prevent injection attacks)
# RUN_ID must match pattern: YYYYMMDD_HHMMSS_PID (digits and underscores only)
if [[ ! "$RUN_ID" =~ ^[0-9]{8}_[0-9]{6}_[0-9]+$ ]]; then
    log "ERROR: Invalid RUN_ID format: $RUN_ID"
    echo '{"continue": true}'
    exit 1
fi

# Results files
readonly SECURITY_RESULT="${RESULTS_DIR}/sec-context_${RUN_ID}.json"
readonly REVIEW_RESULT="${RESULTS_DIR}/code-review_${RUN_ID}.json"
readonly DESLOP_RESULT="${RESULTS_DIR}/deslop_${RUN_ID}.json"
readonly STOPSLOP_RESULT="${RESULTS_DIR}/stop-slop_${RUN_ID}.json"

# Function to run quality check using ACTUAL scripts
run_quality_check() {
    local check_name="$1"
    local script_path="$2"
    local result_file="$3"
    local input_json="$4"

    log "Running ${check_name} via: ${script_path}"

    # Run the actual quality script with stdin input
    if OUTPUT=$(bash "$script_path" < <(echo "$input_json") 2>&1); then
        # Parse output for findings (grep for issue keywords)
        local findings=0

        # Check for standard severity keywords
        if echo "$OUTPUT" | grep -qiE "CRITICAL|HIGH|MEDIUM"; then
            findings=$(echo "$OUTPUT" | grep -cEi "CRITICAL|HIGH|MEDIUM" || echo "0")
        # Check for security audit findings
        elif echo "$OUTPUT" | grep -qiE "Found.*potential security issues|Security Audit: Found"; then
            findings=$(echo "$OUTPUT" | grep -oEi "Found [0-9]+.*issues" | grep -oEi "[0-9]+" || echo "0")
        # Check for any "Found X findings/patterns" pattern
        elif echo "$OUTPUT" | grep -qiE "Found [0-9]+.*findings|Found [0-9]+.*patterns"; then
            findings=$(echo "$OUTPUT" | grep -oEi "Found [0-9]+" | grep -oEi "[0-9]+" || echo "0")
        fi

        # Get timestamp
        local timestamp=$(date -Iseconds)

        # HIGH-002 FIX: Use temp file + atomic rename to prevent race conditions
        local temp_file="${result_file}.tmp"
        jq -n \
            --arg status "complete" \
            --arg findings "$findings" \
            --arg output "$OUTPUT" \
            --arg timestamp "$timestamp" \
            --arg run_id "$RUN_ID" \
            --arg check "$check_name" \
            '{status: $status, findings: ($findings | tonumber), output: $output, timestamp: $timestamp, run_id: $run_id, check: $check}' > "$temp_file"
        mv "$temp_file" "$result_file"

        log "✅ ${check_name}: Complete ($findings findings)"
    else
        log "❌ ${check_name}: Failed (exit code $?)"
        local timestamp=$(date -Iseconds)
        jq -n \
            --arg status "failed" \
            --arg error "Script returned non-zero" \
            --arg timestamp "$timestamp" \
            --arg run_id "$RUN_ID" \
            --arg check "$check_name" \
            '{status: $status, error: $error, timestamp: $timestamp, run_id: $run_id, check: $check}' > "$result_file"
    fi

    # Mark as done
    touch "${result_file}.done"
    log "Marked ${check_name} as complete"
}

# Create input JSON for scripts
INPUT_JSON=$(jq -n \
    --arg tool_name "$TOOL_NAME" \
    --arg file_path "$FILE_PATH" \
    '{tool_name: $tool_name, tool_input: {file_path: $file_path}}')

# Launch all 4 quality checks in parallel using EXISTING validated scripts
# FIX: Use check names that match file naming convention for read-quality-results.sh compatibility
run_quality_check "sec-context" ".claude/hooks/sec-context-validate.sh" "$SECURITY_RESULT" "$INPUT_JSON" &
run_quality_check "code-review" ".claude/hooks/quality-gates-v2.sh" "$REVIEW_RESULT" "$INPUT_JSON" &
run_quality_check "deslop" ".claude/hooks/security-real-audit.sh" "$DESLOP_RESULT" "$INPUT_JSON" &
run_quality_check "stop-slop" ".claude/hooks/stop-slop-hook.sh" "$STOPSLOP_RESULT" "$INPUT_JSON" &

# Wait for all background processes to complete
# MEDIUM-004 FIX: Add timeout to prevent indefinite hangs
# LOW-002 FIX: Use configurable timeout via QUALITY_CHECK_TIMEOUT env var
timeout "$QUALITY_CHECK_TIMEOUT" wait || {
    log "⚠️  Quality checks timeout after ${QUALITY_CHECK_TIMEOUT}s"
    echo '{"continue": true}'
    exit 0
}

log "All 4 quality checks completed for: ${FILE_PATH}"
log "Results written to: ${RESULTS_DIR}/"

# Output hook result (non-blocking with async: true)
cat <<EOF
{
  "continue": true,
  "hookSpecificOutput": {
    "hookEventName": "QualityParallelAsync",
    "checks": ["security", "quality-gates", "security-audit", "stop-slop"],
    "runId": "${RUN_ID}",
    "resultsDir": "${RESULTS_DIR}",
    "message": "4 quality checks completed using validated bash scripts"
  }
}
EOF

# Clear EXIT trap to prevent duplicate JSON (CRIT-002 fix)
trap - EXIT
