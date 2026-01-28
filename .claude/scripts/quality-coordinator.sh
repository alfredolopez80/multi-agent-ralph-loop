#!/usr/bin/env bash
# Quality Coordinator - Multi-Agent Parallel Validation (Native Claude Code 2.1+)
# VERSION: 1.0.0
# Purpose: Launch 4 quality subagents in parallel using Task tool
# Integration: Called by orchestrator after implementation step
#
# Based on: https://github.com/mikekelly/claude-sneakpeek/blob/main/docs/research/native-multiagent-gates.md

set -euo pipefail

readonly VERSION="1.0.0"
readonly PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo '.')"
readonly RESULTS_DIR="${PROJECT_ROOT}/.claude/quality-results"
readonly TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
readonly RUN_ID="${TIMESTAMP}_$$"

# Ensure results directory exists
mkdir -p "${RESULTS_DIR}"

log() {
    echo "[$(date '+%H:%M:%S')] $*" | tee -a "${RESULTS_DIR}/coordinator.log"
}

# Create task for each quality check
create_quality_task() {
    local task_name="$1"
    local skill="$2"
    local target="$3"
    local task_file="${RESULTS_DIR}/${task_name}_task.json"

    cat > "$task_file" <<EOF
{
  "subject": "${task_name} - Quality Review",
  "description": "Execute ${skill} on ${target}",
  "activeForm": "Running ${task_name} review",
  "metadata": {
    "skill": "${skill}",
    "target": "${target}",
    "run_id": "${RUN_ID}",
    "timestamp": "${TIMESTAMP}"
  }
}
EOF

    echo "$task_file"
}

# Launch quality subagents in parallel
launch_quality_subagents() {
    local target_file="$1"
    local complexity="${2:-5}"

    log "Starting parallel quality review for: ${target_file} (complexity: ${complexity})"

    # Only run if complexity >= 5 (adjustable threshold)
    if [[ "$complexity" -lt 5 ]]; then
        log "Complexity ${complexity} < 5, skipping quality checks"
        echo '{"skip": true, "reason": "low_complexity"}'
        return 0
    fi

    # Create 4 quality tasks
    local security_task=$(create_quality_task "security" "sec-context-depth" "$target_file")
    local review_task=$(create_quality_task "code-review" "code-reviewer" "$target_file")
    local deslop_task=$(create_quality_task "deslop" "code-cleanup" "$target_file")
    local stopslop_task=$(create_quality_task "stop-slop" "prose-cleanup" "$target_file")

    # Output tasks to be created via TaskCreate
    cat <<TASKS
{
  "parallel_tasks": [
    {"task_file": "$security_task", "agent": "security-auditor"},
    {"task_file": "$review_task", "agent": "code-reviewer"},
    {"task_file": "$deslop_task", "agent": "refactorer"},
    {"task_file": "$stopslop_task", "agent": "docs-writer"}
  ],
  "run_id": "$RUN_ID",
  "target": "$target_file",
  "complexity": $complexity
}
TASKS

    log "Created 4 quality tasks for parallel execution"
}

# Main execution
main() {
    local target_file="${1:-}"
    local complexity="${2:-5}"

    if [[ -z "$target_file" ]]; then
        echo '{"error": "No target file specified"}' >&2
        exit 1
    fi

    launch_quality_subagents "$target_file" "$complexity"
}

main "$@"
