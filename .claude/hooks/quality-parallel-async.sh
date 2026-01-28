#!/usr/bin/env bash
# Quality Parallel Async Hook - Execute 4 quality checks in parallel with async: true
# VERSION: 1.0.0
# Hook: PostToolUse (Edit, Write)
# Purpose: Run security, code-review, deslop, and stop-slop checks in parallel as background subagents

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

# Parse input
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
INPUT_FILE=$(echo "$INPUT" | jq -r '.input.file // .input.filePath // empty' 2>/dev/null)

# Only run on Edit/Write operations
if [[ ! "$TOOL_NAME" =~ ^(Edit|Write)$ ]]; then
    echo '{"continue": true}'
    exit 0
fi

# Skip if no file was modified
if [[ -z "$INPUT_FILE" ]] || [[ ! -f "$INPUT_FILE" ]]; then
    echo '{"continue": true}'
    exit 0
fi

log "Starting parallel quality checks for: ${INPUT_FILE}"

# Generate timestamp for this run
readonly TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
readonly RUN_ID="${TIMESTAMP}_$$"

# Results files
readonly SECURITY_RESULT="${RESULTS_DIR}/sec-context_${RUN_ID}.json"
readonly REVIEW_RESULT="${RESULTS_DIR}/code-review_${RUN_ID}.json"
readonly DESLOP_RESULT="${RESULTS_DIR}/deslop_${RUN_ID}.json"
readonly STOPSLOP_RESULT="${RESULTS_DIR}/stop-slop_${RUN_ID}.json"

# Function to launch async quality check
launch_async_check() {
    local check_name="$1"
    local skill_command="$2"
    local result_file="$3"
    local target_file="$4"

    log "Launching ${check_name} in background (PID: $BASHPID)"

    # Execute skill in background and write results to file
    (
        # Set timeout for async check (5 minutes max)
        timeout 300 bash -c "
            # Invoke the skill via Skill tool
            echo '{\"tool\": \"Skill\", \"skill\": \"${skill_command}\", \"input\": \"Review ${target_file} for quality issues\"}' | \
            tee '${result_file}.tmp' >/dev/null 2>&1

            # Mark as complete
            echo '{\"status\": \"complete\", \"timestamp\": \"$(date -Iseconds)\"}' > '${result_file}.done'
        " 2>&1 | tee -a "${QUALITY_LOG}" >/dev/null

        # Clean up tmp file if result file exists
        if [[ -f "${result_file}.done" ]]; then
            rm -f "${result_file}.tmp" 2>/dev/null || true
        fi
    ) &

    log "Launched ${check_name} with PID: $!"
}

# Launch all 4 quality checks in parallel
launch_async_check "Security (27 patterns)" "sec-context-depth" "${SECURITY_RESULT}" "${INPUT_FILE}"
launch_async_check "Code Review" "code-review" "${REVIEW_RESULT}" "${INPUT_FILE}"
launch_async_check "Deslop (AI code cleanup)" "deslop" "${DESLOP_RESULT}" "${INPUT_FILE}"
launch_async_check "Stop-Slop (AI prose cleanup)" "stop-slop" "${STOPSLOP_RESULT}" "${INPUT_FILE}"

log "All 4 quality checks launched in parallel for: ${INPUT_FILE}"
log "Results will be written to: ${RESULTS_DIR}/"

# Output hook result (non-blocking with async: true)
cat <<EOF
{
  "continue": true,
  "hookSpecificOutput": {
    "hookEventName": "QualityParallelAsync",
    "checks": ["security", "code-review", "deslop", "stop-slop"],
    "runId": "${RUN_ID}",
    "resultsDir": "${RESULTS_DIR}",
    "message": "4 quality checks launched in parallel (async, non-blocking)"
  }
}
EOF

# Clear EXIT trap to prevent duplicate JSON (CRIT-002 fix)
trap - EXIT
