#!/bin/bash
# diagnose-context-window.sh - Diagnostic tool for context window statusline issues
#
# VERSION: 1.0.0
#
# Usage:
#   1. Temporarily set in settings.json:
#      "statusLine": { "type": "command", "command": "bash /path/to/diagnose-context-window.sh" }
#   2. Send a message in Claude Code
#   3. Check the output file: ~/.ralph/logs/context-window-diagnosis-*.json
#
# Purpose:
#   This script captures the complete statusline JSON input and analyzes the
#   context_window fields to identify issues with percentage calculations.

set -euo pipefail

# Configuration
LOG_DIR="${HOME}/.ralph/logs"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
OUTPUT_FILE="${LOG_DIR}/context-window-diagnosis-${TIMESTAMP}.json"
SUMMARY_FILE="${LOG_DIR}/context-window-summary-${TIMESTAMP}.txt"

# Ensure log directory exists
mkdir -p "$LOG_DIR"

# Read stdin JSON
stdin_data=$(cat)

# Save raw JSON
echo "$stdin_data" | jq '.' > "$OUTPUT_FILE" 2>/dev/null || echo "$stdin_data" > "$OUTPUT_FILE"

# Extract relevant fields
version=$(echo "$stdin_data" | jq -r '.version // "unknown"')
model=$(echo "$stdin_data" | jq -r '.model.display_name // "unknown"')

# Extract context_window data
context_window=$(echo "$stdin_data" | jq -r '.context_window // "{}"')
has_context=$(echo "$stdin_data" | jq 'has("context_window")')

# Calculate values
total_input=$(echo "$context_window" | jq -r '.total_input_tokens // 0')
total_output=$(echo "$context_window" | jq -r '.total_output_tokens // 0')
context_size=$(echo "$context_window" | jq -r '.context_window_size // 200000')
used_percentage=$(echo "$context_window" | jq -r '.used_percentage // "null"')
remaining_percentage=$(echo "$context_window" | jq -r '.remaining_percentage // "null"')

# Calculate actual usage
total_used=$((total_input + total_output))
calculated_percentage=$((total_used * 100 / context_size))

# Determine if there's a bug
has_bug=false
bug_description=""

if [[ "$has_context" == "false" ]]; then
    bug_description="❌ NO context_window field in JSON"
    has_bug=true
elif [[ "$used_percentage" == "0" ]] && [[ "$total_used" -gt 0 ]]; then
    bug_description="❌ BUG: used_percentage is 0 but total_used is $total_used"
    has_bug=true
elif [[ "$remaining_percentage" == "100" ]] && [[ "$total_used" -gt 0 ]]; then
    bug_description="❌ BUG: remaining_percentage is 100 but total_used is $total_used"
    has_bug=true
elif [[ "$used_percentage" != "null" ]] && [[ "$used_percentage" != "0" ]]; then
    expected_diff=$((calculated_percentage - used_percentage))
    if [[ ${expected_diff#-} -gt 5 ]]; then
        bug_description="⚠️  WARNING: used_percentage ($used_percentage) differs from calculated ($calculated_percentage) by ${expected_diff}%"
        has_bug=true
    else
        bug_description="✅ OK: Percentages appear accurate"
    fi
else
    bug_description="✅ OK: No obvious issues detected"
fi

# Build statusline output
if [[ "$has_bug" == "true" ]]; then
    if [[ "$used_percentage" == "null" ]] || [[ "$used_percentage" == "0" ]]; then
        # Use calculated percentage
        if [[ $calculated_percentage -lt 50 ]]; then
            color_code="\033[0;36m"  # CYAN
        elif [[ $calculated_percentage -lt 75 ]]; then
            color_code="\033[0;32m"  # GREEN
        elif [[ $calculated_percentage -lt 85 ]]; then
            color_code="\033[0;33m"  # YELLOW
        else
            color_code="\033[0;31m"  # RED
        fi
        reset_code="\033[0m"
        echo -e "${color_code}🔍 ctx:${calculated_percentage}%${reset_code} ${bug_description}"
    else
        echo "🔍 ctx:${calculated_percentage}% ${bug_description}"
    fi
else
    echo "🔍 ctx:${calculated_percentage}% ${bug_description}"
fi

# Write summary to file
cat > "$SUMMARY_FILE" << EOF
=================================================================
Context Window Statusline Diagnosis - ${TIMESTAMP}
=================================================================

Claude Code Version: ${version}
Model: ${model}

-----------------------------------------------------------------
Context Window Data
-----------------------------------------------------------------
Total Input Tokens:  ${total_input}
Total Output Tokens: ${total_output}
Total Used:          ${total_used}
Context Size:        ${context_size}

Calculated Usage:    ${calculated_percentage}%

-----------------------------------------------------------------
JSON Fields (from Claude Code)
-----------------------------------------------------------------
used_percentage:      ${used_percentage}
remaining_percentage: ${remaining_percentage}

-----------------------------------------------------------------
Diagnosis
-----------------------------------------------------------------
${bug_description}

-----------------------------------------------------------------
Recommendation
-----------------------------------------------------------------
EOF

if [[ "$has_bug" == "true" ]]; then
    if [[ "$used_percentage" == "0" ]] || [[ "$remaining_percentage" == "100" ]]; then
        cat >> "$SUMMARY_FILE" << EOF
The context_window.used_percentage and context_window.remaining_percentage
fields are unreliable in this version of Claude Code.

SOLUTION: Calculate usage from total_input_tokens + total_output_tokens
instead of using the pre-calculated percentage fields.

See: docs/context-window-bug-2026-01-27.md for details.
EOF
    else
        cat >> "$SUMMARY_FILE" << EOF
There is a discrepancy between the calculated percentage and the
pre-calculated fields. Review the full JSON output for details.

Full JSON: ${OUTPUT_FILE}
EOF
    fi
else
    cat >> "$SUMMARY_FILE" << EOF
No issues detected. The context window fields are working correctly.
EOF
fi

# Add file locations to summary
cat >> "$SUMMARY_FILE" << EOF

-----------------------------------------------------------------
Files
-----------------------------------------------------------------
Full JSON:    ${OUTPUT_FILE}
This Summary: ${SUMMARY_FILE}
=================================================================
EOF

# Show summary location (truncated for statusline)
echo "📁 ${SUMMARY_FILE##*/}"
