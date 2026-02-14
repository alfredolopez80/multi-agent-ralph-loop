#!/bin/bash
# validate-context-accuracy.sh - Validates that statusline CtxUse matches /context command
#
# VERSION: 1.0.0
#
# Usage: ./validate-context-accuracy.sh <used_tokens> <total_tokens> <percentage>
# Example: ./validate-context-accuracy.sh 133000 200000 66
#
# This script compares the values from /context command with the statusline display
# to ensure accuracy.

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
RESET='\033[0m'

# Check arguments
if [[ $# -lt 3 ]]; then
    echo -e "${CYAN}Context Accuracy Validator${RESET}"
    echo ""
    echo "Usage: $0 <used_tokens> <total_tokens> <percentage>"
    echo ""
    echo "Steps:"
    echo "1. Run ${YELLOW}/context${RESET} in Claude Code"
    echo "2. Note the values: used_tokens, total_tokens, percentage"
    echo "3. Run this script with those values"
    echo ""
    echo "Example:"
    echo "  If /context shows: '133k/200k tokens (66.5%)'"
    echo "  Run: $0 133000 200000 66"
    exit 1
fi

CONTEXT_USED=$1
CONTEXT_TOTAL=$2
CONTEXT_PCT=$3

# Format tokens helper
format_tokens() {
    local val=$1
    if [[ $val -ge 1000 ]]; then
        echo "$((val / 1000))k"
    else
        echo "${val}"
    fi
}

# Get current statusline values by simulating stdin JSON
# We need to extract from the actual running session
# For now, we'll read from a temp file if it exists

STATUSLINE_CACHE="/tmp/ralph-statusline-context.json"

echo -e "${CYAN}═══════════════════════════════════════════════════════════${RESET}"
echo -e "${CYAN}Context Accuracy Validation${RESET}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════${RESET}"
echo ""

# Format the expected values from /context
EXPECTED_DISPLAY=$(format_tokens $CONTEXT_USED)
EXPECTED_TOTAL=$(format_tokens $CONTEXT_TOTAL)
EXPECTED_PCT=$CONTEXT_PCT

echo -e "${YELLOW}Expected (from /context):${RESET}"
echo -e "  CtxUse: ${EXPECTED_DISPLAY}/${EXPECTED_TOTAL} (${EXPECTED_PCT}%)"
echo ""

# Check if we have cached statusline data
if [[ -f "$STATUSLINE_CACHE" ]]; then
    STATUSLINE_USED=$(jq -r '.used_tokens // 0' "$STATUSLINE_CACHE" 2>/dev/null || echo "0")
    STATUSLINE_TOTAL=$(jq -r '.total_tokens // 0' "$STATUSLINE_CACHE" 2>/dev/null || echo "0")
    STATUSLINE_PCT=$(jq -r '.percentage // 0' "$STATUSLINE_CACHE" 2>/dev/null || echo "0")

    STATUSLINE_DISPLAY=$(format_tokens $STATUSLINE_USED)
    STATUSLINE_TOTAL_DISPLAY=$(format_tokens $STATUSLINE_TOTAL)

    echo -e "${YELLOW}Statusline shows:${RESET}"
    echo -e "  CtxUse: ${STATUSLINE_DISPLAY}/${STATUSLINE_TOTAL_DISPLAY} (${STATUSLINE_PCT}%)"
    echo ""

    # Compare values
    USED_DIFF=$((CONTEXT_USED - STATUSLINE_USED))
    PCT_DIFF=$((CONTEXT_PCT - STATUSLINE_PCT))

    echo -e "${CYAN}───────────────────────────────────────────────────────────${RESET}"
    echo -e "${YELLOW}Comparison:${RESET}"

    # Used tokens comparison
    if [[ $USED_DIFF -eq 0 ]]; then
        echo -e "  Used tokens:  ${GREEN}✓ MATCH${RESET} (${CONTEXT_USED})"
    else
        echo -e "  Used tokens:  ${RED}✗ MISMATCH${RESET} (diff: ${USED_DIFF})"
        echo -e "                /context: ${CONTEXT_USED}, statusline: ${STATUSLINE_USED}"
    fi

    # Total tokens comparison
    if [[ $CONTEXT_TOTAL -eq $STATUSLINE_TOTAL ]]; then
        echo -e "  Total tokens: ${GREEN}✓ MATCH${RESET} (${CONTEXT_TOTAL})"
    else
        echo -e "  Total tokens: ${RED}✗ MISMATCH${RESET}"
        echo -e "                /context: ${CONTEXT_TOTAL}, statusline: ${STATUSLINE_TOTAL}"
    fi

    # Percentage comparison (allow 1% tolerance)
    if [[ ${PCT_DIFF#-} -le 1 ]]; then
        echo -e "  Percentage:   ${GREEN}✓ MATCH${RESET} (${CONTEXT_PCT}% vs ${STATUSLINE_PCT}%)"
    else
        echo -e "  Percentage:   ${RED}✗ MISMATCH${RESET} (diff: ${PCT_DIFF}%)"
        echo -e "                /context: ${CONTEXT_PCT}%, statusline: ${STATUSLINE_PCT}%"
    fi

    echo -e "${CYAN}───────────────────────────────────────────────────────────${RESET}"

    # Final verdict
    if [[ $USED_DIFF -eq 0 ]] && [[ ${PCT_DIFF#-} -le 1 ]]; then
        echo -e ""
        echo -e "${GREEN}✓ VALIDATION PASSED${RESET} - Statusline matches /context"
        exit 0
    else
        echo -e ""
        echo -e "${RED}✗ VALIDATION FAILED${RESET} - Statusline does NOT match /context"
        echo ""
        echo -e "${YELLOW}Possible causes:${RESET}"
        echo "  1. Statusline cache is stale (wait a few seconds)"
        echo "  2. Session compaction occurred"
        echo "  3. Context calculation method differs"
        exit 1
    fi
else
    echo -e "${YELLOW}No cached statusline data found.${RESET}"
    echo ""
    echo "To enable validation, the statusline must save its context data."
    echo ""
    echo -e "${CYAN}Manual comparison:${RESET}"
    echo "  1. Look at your current statusline output"
    echo "  2. Compare the CtxUse values with /context"
    echo "  3. They should match within 1% tolerance"
    echo ""
    echo -e "Expected from /context: ${GREEN}CtxUse: ${EXPECTED_DISPLAY}/${EXPECTED_TOTAL} (${EXPECTED_PCT}%)${RESET}"
fi
