#!/bin/bash
# simulate-context.sh - Simulate progressive context usage
# Increments GLM context by 10% until auto-compact triggers

set -euo pipefail

# Configuration
PROJECT_STATE="${HOME}/.claude/hooks/project-state.sh"
STATE_DIR=$("$PROJECT_STATE" get-dir 2>/dev/null)
CONTEXT_FILE="${STATE_DIR}/glm-context.json"
CONTEXT_WINDOW=128000

# Colors
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  📊 Context Simulation Script"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  State Dir: ${STATE_DIR}"
echo "  Context File: ${CONTEXT_FILE}"
echo "  Context Window: ${CONTEXT_WINDOW} tokens"
echo ""

# Get current percentage
get_current_percentage() {
    if [[ -f "$CONTEXT_FILE" ]]; then
        jq -r '.percentage // 0' "$CONTEXT_FILE" 2>/dev/null || echo 0
    else
        echo 0
    fi
}

# Update context file
update_context() {
    local tokens=$1
    local percentage=$2

    cat > "$CONTEXT_FILE" <<EOF
{
  "total_tokens": $tokens,
  "context_window": $CONTEXT_WINDOW,
  "percentage": $percentage,
  "last_updated": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "session_start": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "message_count": 1
}
EOF
}

# Get color for percentage
get_color() {
    local pct=$1
    if [[ $pct -ge 85 ]]; then
        echo -e "${RED}"
    elif [[ $pct -ge 75 ]]; then
        echo -e "${YELLOW}"
    elif [[ $pct -ge 50 ]]; then
        echo -e "${GREEN}"
    else
        echo -e "${CYAN}"
    fi
}

# Main simulation loop
echo "Starting simulation..."
echo ""

current_pct=$(get_current_percentage)
echo "Current: ${current_pct}%"
echo ""

# Simulate from 10% to 100% in 10% increments
for target_pct in {10..100..10}; do
    # Calculate tokens for this percentage
    tokens=$((CONTEXT_WINDOW * target_pct / 100))

    # Update context file
    update_context $tokens $target_pct

    # Get display color
    color=$(get_color $target_pct)
    reset='\033[0m'

    # Display progress
    echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "  🎯 Target: ${color}${target_pct}%${reset} | Tokens: ${tokens} / ${CONTEXT_WINDOW}"
    echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Show warnings based on thresholds
    if [[ $target_pct -ge 85 ]]; then
        echo -e "  ${RED}⚠️  CRITICAL: Context at ${target_pct}%!${reset}"
        echo -e "  ${RED}🚨 Auto-compact should be triggered!${reset}"
    elif [[ $target_pct -ge 75 ]]; then
        echo -e "  ${YELLOW}⚠️  WARNING: Context at ${target_pct}%${reset}"
        echo -e "  ${YELLOW}📝 Consider compacting soon${reset}"
    elif [[ $target_pct -ge 50 ]]; then
        echo -e "  ${GREEN}✅ Context at ${target_pct}% - Normal${reset}"
    else
        echo -e "  ${CYAN}✅ Context at ${target_pct}% - Low${reset}"
    fi

    echo ""
    echo "  Context file updated:"
    jq -c '.' "$CONTEXT_FILE" 2>/dev/null || echo "  (file not readable)"

    echo ""
    read -p "  Press Enter to continue to next increment (10%)..." || true
    echo ""
done

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${reset}"
echo -e "  ✅ Simulation complete!"
echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Final context: $(jq -r '.percentage' "$CONTEXT_FILE")%"
echo ""
echo "  Note: The statusline should show these changes in real-time."
echo "        At 75%, you should see a YELLOW warning."
echo "        At 85%, you should see a RED critical warning."
echo ""
