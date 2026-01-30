#!/usr/bin/env bash
# rule-verification.sh - Verify that injected rules were actually applied
# Version 1.0.0 - v2.81.2 Implementation
# Part of Ralph Multi-Agent System
#
# CRITICAL HOOK for learning quality validation
# Triggers: PostToolUse (TaskUpdate)
# Purpose: Verify procedural rules were applied after Task completion
#
# Verification Process:
#  1. Identify rules marked as "injected" for this step
#  2. Analyze generated code/files for rule application
#  3. Update rule metrics (applied_count, last_applied)
#  4. Flag rules that were skipped despite injection
#
# This enables:
#  - Rule utilization rate tracking
#  - Detection of "ghost rules" (injected but not applied)
#  - Quality feedback for rule refinement

set -euo pipefail

VERSION="1.0.0"
RALPH_DIR="${HOME}/.ralph"
PROCEDURAL_RULES="${RALPH_DIR}/procedural/rules.json"
PLAN_STATE="${PWD}/.claude/plan-state.json"
METRICS_DIR="${RALPH_DIR}/metrics"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

log_info() { echo -e "${CYAN}[rule-verification]${NC} $1" >&2; }
log_warning() { echo -e "${YELLOW}[rule-verification]${NC} $1" >&2; }
log_error() { echo -e "${RED}[rule-verification]${NC} $1" >&2; }
log_success() { echo -e "${GREEN}[rule-verification]${NC} $1" >&2; }
log_debug() { echo -e "${MAGENTA}[rule-verification]${NC} $1" >&2; }

# Ensure metrics directory exists
mkdir -p "$METRICS_DIR"

# Extract step ID from stdin
extract_step_id() {
    local stdin_data="$1"
    echo "$stdin_data" | jq -r '.toolInput.taskId // .toolInput.step_id // ""' 2>/dev/null || echo ""
}

# Get injected rules for a step
get_injected_rules() {
    local step_id="$1"

    if [ ! -f "$PLAN_STATE" ]; then
        echo "[]"
        return 0
    fi

    # Extract injected rules from plan-state
    jq -r --arg step_id "$step_id" '
        .phases[]?
        | select(.steps[]? | select(.id == $step_id))
        | .steps[]?
        | select(.id == $step_id)
        | .injected_rules // []
    ' "$PLAN_STATE" 2>/dev/null || echo "[]"
}

# Get modified files from git diff
get_modified_files() {
    local base_commit="${1:-HEAD}"

    # Get list of modified files
    git diff --name-only "$base_commit" 2>/dev/null | grep -E '\.(ts|tsx|js|jsx|py|rs|go|java)$' || echo ""
}

# Analyze file for rule application patterns
analyze_file_for_rule() {
    local file="$1"
    local rule="$2"

    local rule_pattern
    local rule_domain

    rule_pattern=$(echo "$rule" | jq -r '.pattern // .keywords // [] | join("|")' 2>/dev/null || echo "")
    rule_domain=$(echo "$rule" | jq -r '.domain // ""' 2>/dev/null || echo "")

    if [ -z "$rule_pattern" ]; then
        echo "0"
        return 0
    fi

    # Count occurrences of pattern in file
    local count=0
    count=$(grep -ciE "$rule_pattern" "$file" 2>/dev/null || echo "0")

    echo "$count"
}

# Verify rule application in codebase
verify_rule_application() {
    local rule_id="$1"
    local step_id="$2"

    # Get rule details
    local rule
    rule=$(jq -r --arg id "$rule_id" '.rules[] | select(.id == $id)' "$PROCEDURAL_RULES" 2>/dev/null || echo "{}")

    if [ "$rule" = "{}" ]; then
        log_debug "Rule $rule_id not found in rules.json"
        return 1
    fi

    # Get modified files
    local modified_files
    modified_files=$(get_modified_files "HEAD~1")

    if [ -z "$modified_files" ]; then
        log_debug "No modified files found for rule verification"
        return 1
    fi

    # Check each file for rule application
    local total_matches=0
    local files_checked=0

    while IFS= read -r file; do
        [ -z "$file" ] && continue

        if [ ! -f "$file" ]; then
            continue
        fi

        local matches
        matches=$(analyze_file_for_rule "$file" "$rule")
        total_matches=$((total_matches + matches))
        files_checked=$((files_checked + 1))

        log_debug "File $file: $matches matches for rule $rule_id"

    done <<< "$modified_files"

    # Rule applied if found in at least one file
    if [ "$total_matches" -gt 0 ]; then
        log_success "Rule $rule_id applied: $total_matches matches in $files_checked files"
        update_rule_metrics "$rule_id" "$step_id" "applied" "$total_matches"
        return 0
    else
        log_warning "Rule $rule_id NOT applied: 0 matches in $files_checked files"
        update_rule_metrics "$rule_id" "$step_id" "skipped" 0
        return 1
    fi
}

# Update rule metrics
update_rule_metrics() {
    local rule_id="$1"
    local step_id="$2"
    local status="$3"
    local match_count="$4"

    if [ ! -f "$PROCEDURAL_RULES" ]; then
        return 1
    fi

    local temp_file="${PROCEDURAL_RULES}.tmp.$$"

    # Update rule metrics
    jq --arg id "$rule_id" \
       --arg step_id "$step_id" \
       --arg status "$status" \
       --argjson matches "$match_count" \
       --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '
        (.rules[] | select(.id == $id)) |= (
            if $status == "applied" then
                .applied_count = (.applied_count // 0) + 1 |
                .last_applied = $timestamp |
                .match_count = (.match_count // 0) + $matches
            else
                .skipped_count = (.skipped_count // 0) + 1 |
                .last_skipped = $timestamp
            end
        )
    ' "$PROCEDURAL_RULES" > "$temp_file"

    mv "$temp_file" "$PROCEDURAL_RULES"

    # Record in metrics
    local metric_file="${METRICS_DIR}/rule-verification.jsonl"
    echo "{\"rule_id\":\"$rule_id\",\"step_id\":\"$step_id\",\"status\":\"$status\",\"matches\":$match_count,\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}" >> "$metric_file"
}

# Calculate rule utilization rate
calculate_utilization_rate() {
    if [ ! -f "$PROCEDURAL_RULES" ]; then
        echo "0"
        return 0
    fi

    local total_rules
    local applied_rules

    total_rules=$(jq '[.rules[] | select(.injected_count // 0 > 0)] | length' "$PROCEDURAL_RULES" 2>/dev/null || echo "0")
    applied_rules=$(jq '[.rules[] | select(.applied_count // 0 > 0)] | length' "$PROCEDURAL_RULES" 2>/dev/null || echo "0")

    if [ "$total_rules" -eq 0 ]; then
        echo "0"
        return 0
    fi

    local rate
    rate=$(awk "BEGIN {printf \"%.1f\", ($applied_rules / $total_rules) * 100}")
    echo "$rate"
}

# Main verification logic
main() {
    # Read stdin
    local stdin_data
    stdin_data=$(cat)

    # Only process TaskUpdate tool invocations
    local tool_name
    tool_name=$(echo "$stdin_data" | jq -r '.toolName // ""' 2>/dev/null || echo "")

    if [ "$tool_name" != "TaskUpdate" ]; then
        # Return continue for other tools
        echo '{"continue": true}'
        return 0
    fi

    # Extract step ID
    local step_id
    step_id=$(extract_step_id "$stdin_data")

    if [ -z "$step_id" ]; then
        log_debug "No step ID found in TaskUpdate"
        echo '{"continue": true}'
        return 0
    fi

    log_info "Verifying rule application for step: $step_id"

    # Get injected rules for this step
    local injected_rules
    injected_rules=$(get_injected_rules "$step_id")

    local rule_count
    rule_count=$(echo "$injected_rules" | jq 'length' 2>/dev/null || echo "0")

    if [ "$rule_count" -eq 0 ]; then
        log_debug "No injected rules for step $step_id"
        echo '{"continue": true}'
        return 0
    fi

    log_info "Checking $rule_count injected rules"

    # Verify each rule
    local applied_count=0
    local skipped_count=0

    while IFS= read -r rule_id; do
        [ -z "$rule_id" ] && continue

        if verify_rule_application "$rule_id" "$step_id"; then
            applied_count=$((applied_count + 1))
        else
            skipped_count=$((skipped_count + 1))
        fi
    done <<< "$(echo "$injected_rules" | jq -r '.[]')"

    # Calculate utilization rate
    local utilization_rate
    utilization_rate=$(calculate_utilization_rate)

    # Report results
    cat >&2 << VERIFICATION_REPORT

╔════════════════════════════════════════════════════════════════╗
║            📊 RULE VERIFICATION REPORT - Step $step_id        ║
╚════════════════════════════════════════════════════════════════╝

Rules Injected:    $rule_count
Rules Applied:     $applied_count
Rules Skipped:     $skipped_count
Utilization Rate:  ${utilization_rate}%

VERIFICATION_REPORT

    # Warn if many rules were skipped
    if [ "$skipped_count" -gt 0 ]; then
        local skip_rate
        skip_rate=$(awk "BEGIN {printf \"%.1f\", ($skipped_count / $rule_count) * 100}")

        if [ "$skip_rate" -gt 50 ]; then
            log_warning "High skip rate (${skip_rate}%): Rules may need refinement"
        fi
    fi

    echo '{"continue": true}'
    return 0
}

main "$@"
