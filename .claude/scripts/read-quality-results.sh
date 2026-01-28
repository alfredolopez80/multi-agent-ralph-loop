#!/usr/bin/env bash
# Quality Results Reader - Post-Analysis for Orchestrator
# VERSION: 1.0.0
# Purpose: Read and aggregate quality results from parallel subagents
# Integration: Called by orchestrator before validation step
#
# This script polls for completed quality checks and aggregates results

set -euo pipefail

readonly VERSION="1.0.0"
readonly PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo '.')"
readonly RESULTS_DIR="${PROJECT_ROOT}/.claude/quality-results"
readonly POLL_TIMEOUT=120  # 2 minutes max wait
readonly POLL_INTERVAL=2   # Check every 2 seconds

log() {
    echo "[$(date '+%H:%M:%S')] $*" >&2
}

# Check if a quality check is complete
is_check_complete() {
    local check_name="$1"
    local run_id="$2"

    # Check for .done marker file
    if [[ -f "${RESULTS_DIR}/${check_name}_${run_id}.done" ]]; then
        # Check if result file exists
        if [[ -f "${RESULTS_DIR}/${check_name}_${run_id}.json" ]]; then
            return 0  # Complete
        fi
    fi

    return 1  # Not complete
}

# Wait for all quality checks to complete
wait_for_completion() {
    local run_id="$1"
    local checks=("sec-context" "code-review" "deslop" "stop-slop")
    local elapsed=0

    log "Waiting for quality checks to complete (timeout: ${POLL_TIMEOUT}s)..."

    while [[ $elapsed -lt $POLL_TIMEOUT ]]; do
        local all_complete=true

        for check in "${checks[@]}"; do
            if ! is_check_complete "$check" "$run_id"; then
                all_complete=false
                break
            fi
        done

        if [[ "$all_complete" == "true" ]]; then
            log "All quality checks complete!"
            return 0
        fi

        sleep $POLL_INTERVAL
        elapsed=$((elapsed + POLL_INTERVAL))
    done

    log "Timeout waiting for quality checks"
    return 1
}

# Aggregate results from all checks
aggregate_results() {
    local run_id="$1"
    local output_file="${RESULTS_DIR}/aggregated_${run_id}.json"

    cat > "$output_file" <<EOF
{
  "run_id": "$run_id",
  "timestamp": "$(date -Iseconds)",
  "checks": {}
}
EOF

    local checks=("sec-context" "code-review" "deslop" "stop-slop")

    for check in "${checks[@]}"; do
        local result_file="${RESULTS_DIR}/${check}_${run_id}.json"

        if [[ -f "$result_file" ]]; then
            # Extract check status and findings
            local status=$(jq -r '.status // "unknown"' "$result_file" 2>/dev/null || echo "unknown")
            local findings_count=$(jq -r '.findings // 0' "$result_file" 2>/dev/null || echo "0")

            # Add to aggregated results
            jq --arg check "$check" \
               --argjson result "$(cat "$result_file")" \
               '.checks[$check] = $result' "$output_file" > "${output_file}.tmp"
            mv "${output_file}.tmp" "$output_file"

            log "✅ ${check}: ${status} (${findings_count} findings)"
        else
            log "⚠️  ${check}: No result file found"
        fi
    done

    # Add summary
    jq '.summary = {
        total_checks: (.checks | length),
        completed: ([.checks[] | select(.status == "complete")] | length),
        total_findings: ([.checks[].findings // 0] | add)
    }' "$output_file" > "${output_file}.tmp"
    mv "${output_file}.tmp" "$output_file"

    echo "$output_file"
}

# Main execution
main() {
    local run_id="${1:-}"

    if [[ -z "$run_id" ]]; then
        # Find most recent run_id
        run_id=$(ls -t "${RESULTS_DIR}"/*.done 2>/dev/null | head -1 | sed "s/.*_${RUN_ID//_/}\.done/\1/" | head -1)
        if [[ -z "$run_id" ]]; then
            echo '{"error": "No quality checks found"}' >&2
            exit 1
        fi
    fi

    log "Reading quality results for run_id: ${run_id}"

    # Wait for completion
    if wait_for_completion "$run_id"; then
        # Aggregate results
        local aggregated=$(aggregate_results "$run_id")

        # Output aggregated results
        cat "$aggregated"

        # Also output as summary
        log "=== QUALITY RESULTS SUMMARY ==="
        jq -r '.summary | "Completed: \(.completed)/\(.total_checks) checks | Total findings: \(.total_findings)"' "$aggregated"
    else
        echo '{"error": "Quality checks did not complete in time"}' >&2
        exit 1
    fi
}

main "$@"
