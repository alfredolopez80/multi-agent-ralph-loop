#!/bin/bash
# action-report-generator.sh - Unified Action Report Generator
# VERSION: 2.93.0
#
# Purpose: Generate comprehensive action reports for all Ralph skills
# Output: (1) Markdown report to stdout, (2) JSON metadata to file
# Location: docs/actions/{skill-name}/{timestamp}.md
#
# Usage:
#   source .claude/lib/action-report-generator.sh
#   generate_action_report "orchestrator" "Session completed" "details..."
#
# Features:
# - Always outputs to stdout (visible in Claude conversation)
# - Saves to docs/actions/{skill-name}/ with timestamp
# - Works in foreground AND background tasks
# - Includes session metadata, metrics, and recommendations

set -euo pipefail

# Configuration
ACTION_REPORTS_DIR="docs/actions"
METADATA_DIR=".claude/metadata/actions"
MAX_REPORTS_PER_SKILL=50

# Colors for terminal output (optional, falls back gracefully)
readonly COLOR_RESET='\033[0m'
readonly COLOR_BOLD='\033[1m'
readonly COLOR_GREEN='\033[32m'
readonly COLOR_BLUE='\033[34m'
readonly COLOR_YELLOW='\033[33m'

# ============================================================================
# Public API - Main Functions
# ============================================================================

# Main entry point - Generate complete action report
# Usage: generate_action_report <skill_name> <status> <description> [details_json]
generate_action_report() {
    local skill_name="$1"
    local status="$2"        # completed | failed | partial | in_progress
    local description="$3"
    local details_json="${4:-{}}"

    # Validate inputs
    if [[ -z "$skill_name" || -z "$status" || -z "$description" ]]; then
        echo "ERROR: Missing required arguments" >&2
        return 1
    fi

    # Generate timestamp
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local filename_date=$(date +"%Y%m%d-%H%M%S")

    # Create directories
    local skill_dir="${ACTION_REPORTS_DIR}/${skill_name}"
    local metadata_dir="${METADATA_DIR}/${skill_name}"
    mkdir -p "$skill_dir" "$metadata_dir"

    # Generate filenames
    local report_file="${skill_dir}/${filename_date}.md"
    local metadata_file="${metadata_dir}/${filename_date}.json"

    # Gather session information
    local session_info=$(gather_session_info)

    # Generate report content
    local report_content=$(generate_markdown_report \
        "$skill_name" \
        "$status" \
        "$description" \
        "$details_json" \
        "$timestamp" \
        "$session_info"
    )

    # Generate metadata
    local metadata=$(generate_metadata \
        "$skill_name" \
        "$status" \
        "$description" \
        "$details_json" \
        "$timestamp" \
        "$report_file"
    )

    # Write to file (atomic operation)
    echo "$report_content" > "$report_file"
    echo "$metadata" > "$metadata_file"

    # Clean old reports
    cleanup_old_reports "$skill_dir" "$metadata_dir"

    # Output to stdout (VISIBLE IN CLAUDE CONVERSATION)
    echo "$report_content"

    # Log location
    echo ""
    echo "---"
    echo "**Report saved**: \`$report_file\`"
    echo "**Metadata**: \`$metadata_file\`"

    return 0
}

# Append progress update to existing report
# Usage: append_progress <skill_name> <timestamp> <update_message>
append_progress() {
    local skill_name="$1"
    local timestamp="$2"
    local message="$3"

    local latest_report=$(find_latest_report "$skill_name")

    if [[ -n "$latest_report" ]]; then
        {
            echo ""
            echo "#### Progress Update: $timestamp"
            echo "$message"
        } >> "$latest_report"

        # Also output to stdout
        echo "[$timestamp] $message"
    fi
}

# ============================================================================
# Internal Functions
# ============================================================================

gather_session_info() {
    # Gather git information
    local git_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
    local git_commit=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
    local git_status=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ' || echo "0")

    # Gather session info from environment if available
    local session_id="${SESSION_ID:-unknown}"
    local model="${ANTHROPIC_MODEL:-unknown}"

    # Generate JSON
    jq -n \
        --arg session_id "$session_id" \
        --arg model "$model" \
        --arg git_branch "$git_branch" \
        --arg git_commit "$git_commit" \
        --argjson git_status "$git_status" \
        '{
            session_id: $session_id,
            model: $model,
            git: {
                branch: $git_branch,
                commit: $git_commit,
                changed_files: $git_status
            }
        }'
}

generate_markdown_report() {
    local skill_name="$1"
    local status="$2"
    local description="$3"
    local details_json="$4"
    local timestamp="$5"
    local session_info="$6"

    # Parse session info
    local session_id=$(echo "$session_info" | jq -r '.session_id // "unknown"')
    local model=$(echo "$session_info" | jq -r '.model // "unknown"')
    local git_branch=$(echo "$session_info" | jq -r '.git.branch // "unknown"')
    local git_commit=$(echo "$session_info" | jq -r '.git.commit // "unknown"')
    local git_changed=$(echo "$session_info" | jq -r '.git.changed_files // "0"')

    # Status emoji
    local status_emoji
    case "$status" in
        completed) status_emoji="✅" ;;
        failed) status_emoji="❌" ;;
        partial) status_emoji="⚠️" ;;
        in_progress) status_emoji="🔄" ;;
        *) status_emoji="📋" ;;
    esac

    # Extract details
    local duration=$(echo "$details_json" | jq -r '.duration // "N/A"')
    local iterations=$(echo "$details_json" | jq -r '.iterations // "N/A"')
    local files_modified=$(echo "$details_json" | jq -r '.files_modified // "N/A"')
    local errors=$(echo "$details_json" | jq -r '.errors // "None"')
    local recommendations=$(echo "$details_json" | jq -r '.recommendations // "None"')

    # Generate report
    cat <<EOF
# ${status_emoji} Action Report: ${skill_name}

**Generated**: ${timestamp}
**Status**: ${status^^}
**Session**: \`${session_id}\`

---

## Summary

${description}

---

## Execution Details

| Metric | Value |
|--------|-------|
| **Duration** | ${duration} |
| **Iterations** | ${iterations} |
| **Files Modified** | ${files_modified} |
| **Model** | ${model} |

### Git State

| Property | Value |
|----------|-------|
| **Branch** | \`${git_branch}\` |
| **Commit** | \`${git_commit}\` |
| **Changed Files** | ${git_changed} |

---

## Results

### Errors
\`\`\`
${errors}
\`\`\`

### Recommendations
${recommendations}

---

## Next Steps

1. Review the changes made
2. Run quality gates: \`/gates\`
3. Run security audit: \`/security\`
4. Commit changes if verified

---

*Report generated by action-report-generator.sh v2.93.0*
EOF
}

generate_metadata() {
    local skill_name="$1"
    local status="$2"
    local description="$3"
    local details_json="$4"
    local timestamp="$5"
    local report_file="$6"

    jq -n \
        --arg skill_name "$skill_name" \
        --arg status "$status" \
        --arg description "$description" \
        --argjson details "$details_json" \
        --arg timestamp "$timestamp" \
        --arg report_file "$report_file" \
        '{
            skill_name: $skill_name,
            status: $status,
            description: $description,
            details: $details,
            timestamp: $timestamp,
            report_file: $report_file,
            version: "2.93.0"
        }'
}

find_latest_report() {
    local skill_name="$1"
    local skill_dir="${ACTION_REPORTS_DIR}/${skill_name}"

    if [[ -d "$skill_dir" ]]; then
        find "$skill_dir" -name "*.md" -type f -printf '%T@ %p\n' 2>/dev/null | \
            sort -rn | head -1 | cut -d' ' -f2-
    fi
}

cleanup_old_reports() {
    local skill_dir="$1"
    local metadata_dir="$2"

    # Count reports
    local count=$(find "$skill_dir" -name "*.md" -type f 2>/dev/null | wc -l | tr -d ' ')

    if [[ "$count" -gt "$MAX_REPORTS_PER_SKILL" ]]; then
        # Remove oldest reports
        local to_delete=$((count - MAX_REPORTS_PER_SKILL))

        find "$skill_dir" -name "*.md" -type f -printf '%T@ %p\n' 2>/dev/null | \
            sort -n | head -"$to_delete" | cut -d' ' -f2- | \
            while read -r old_report; do
                local basename=$(basename "$old_report" .md)
                rm -f "$old_report"
                rm -f "${metadata_dir}/${basename}.json"
            done
    fi
}

# ============================================================================
# Utility Functions
# ============================================================================

# List all reports for a skill
list_reports() {
    local skill_name="$1"
    local skill_dir="${ACTION_REPORTS_DIR}/${skill_name}"

    if [[ -d "$skill_dir" ]]; then
        find "$skill_dir" -name "*.md" -type f | sort -r
    fi
}

# Get summary statistics for a skill
get_skill_stats() {
    local skill_name="$1"
    local metadata_dir="${METADATA_DIR}/${skill_name}"

    if [[ ! -d "$metadata_dir" ]]; then
        echo "No reports found for skill: $skill_name"
        return 1
    fi

    local total=$(find "$metadata_dir" -name "*.json" -type f 2>/dev/null | wc -l | tr -d ' ')
    local completed=$(grep -l '"status": "completed"' "$metadata_dir"/*.json 2>/dev/null | wc -l | tr -d ' ')
    local failed=$(grep -l '"status": "failed"' "$metadata_dir"/*.json 2>/dev/null | wc -l | tr -d ' ')

    cat <<EOF
Skill: $skill_name
Total Reports: $total
Completed: $completed
Failed: $failed
Success Rate: $(( (completed * 100) / total ))%
EOF
}

# Export functions for use in other scripts
export -f generate_action_report
export -f append_progress
export -f list_reports
export -f get_skill_stats
