#!/usr/bin/env bash
# Quality Parallel Async Hook - FIXED VERSION
# VERSION: 2.0.0
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

# Ensure results directory exists
mkdir -p "${RESULTS_DIR}"
mkdir -p "$(dirname "${QUALITY_LOG}")"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "${QUALITY_LOG}"
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

        # Write structured result
        jq -n \
            --arg status "complete" \
            --arg findings "$findings" \
            --arg output "$OUTPUT" \
            --arg timestamp "$timestamp" \
            --arg run_id "$RUN_ID" \
            --arg check "$check_name" \
            '{status: $status, findings: ($findings | tonumber), output: $output, timestamp: $timestamp, run_id: $run_id, check: $check}' > "$result_file"

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
run_quality_check "Security (27 patterns)" ".claude/hooks/sec-context-validate.sh" "$SECURITY_RESULT" "$INPUT_JSON" &
run_quality_check "Code Quality" ".claude/hooks/quality-gates-v2.sh" "$REVIEW_RESULT" "$INPUT_JSON" &
run_quality_check "Security Full Audit" ".claude/hooks/security-real-audit.sh" "$DESLOP_RESULT" "$INPUT_JSON" &
run_quality_check "Stop-Slop Check" ".claude/hooks/stop-slop-hook.sh" "$STOPSLOP_RESULT" "$INPUT_JSON" &

# Wait for all background processes to complete
wait

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
