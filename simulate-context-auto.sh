#!/bin/bash
# simulate-context-auto.sh - Automatic context simulation (no interaction)
# Runs through 10-100% with configurable delay

set -euo pipefail

# Configuration
PROJECT_STATE="${HOME}/.claude/hooks/project-state.sh"
STATE_DIR=$("$PROJECT_STATE" get-dir 2>/dev/null)
CONTEXT_FILE="${STATE_DIR}/glm-context.json"
CONTEXT_WINDOW=128000
DELAY=${1:-2}  # Default 2 seconds between increments

# Colors
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  ${BOLD}🤖 Automatic Context Simulation${NC}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "  State Dir: ${STATE_DIR}"
echo "  Delay: ${DELAY}s per increment"
echo ""

# Backup original context
if [[ -f "$CONTEXT_FILE" ]]; then
    cp "$CONTEXT_FILE" "${CONTEXT_FILE}.backup"
    echo "  ✅ Backup created: ${CONTEXT_FILE}.backup"
fi

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

echo ""
echo -e "${BOLD}Starting automatic simulation...${NC}"
echo ""

# Simulate from 10% to 100% in 10% increments
for i in {1..10}; do
    target_pct=$((i * 10))
    tokens=$((CONTEXT_WINDOW * target_pct / 100))
    update_context $tokens $target_pct

    color=$(get_color $target_pct)
    reset='\033[0m'

    # Clear screen for cleaner output
    clear 2>/dev/null || true

    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  ${BOLD}📊 Context: ${color}${target_pct}%${reset}${BOLD} | Tokens: ${tokens} / ${CONTEXT_WINDOW}${NC}"
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    # Show status indicators
    if [[ $target_pct -ge 85 ]]; then
        echo -e "  ${RED}${BOLD}🚨 CRITICAL LEVEL${NC}"
        echo -e "  ${RED}⚠️  Context at ${target_pct}% - Auto-compact should trigger!${NC}"
        echo -e "  ${RED}📋 PreCompact hook should save state now${NC}"
    elif [[ $target_pct -ge 75 ]]; then
        echo -e "  ${YELLOW}${BOLD}⚠️  WARNING LEVEL${NC}"
        echo -e "  ${YELLOW}📝 Context at ${target_pct}% - Consider compacting${NC}"
        echo -e "  ${YELLOW}👀 Statusline should show YELLOW${NC}"
    elif [[ $target_pct -ge 50 ]]; then
        echo -e "  ${GREEN}${BOLD}✅ NORMAL LEVEL${NC}"
        echo -e "  ${GREEN}📊 Context at ${target_pct}% - Statusline GREEN${NC}"
    else
        echo -e "  ${CYAN}${BOLD}✅ LOW LEVEL${NC}"
        echo -e "  ${CYAN}📊 Context at ${target_pct}% - Statusline CYAN${NC}"
    fi

    echo ""
    echo -e "  ${BOLD}Context File Contents:${NC}"
    echo "  ──────────────────────────────────────────────────────────"
    jq -C '.' "$CONTEXT_FILE" 2>/dev/null | sed 's/^/  /' || echo "  (file not readable)"
    echo ""

    echo -e "  ${CYAN}Next increment: $((target_pct + 10))% in ${DELAY}s...${NC}"
    echo -e "  ${CYAN}Press Ctrl+C to stop and restore backup${NC}"

    sleep "$DELAY"
done

echo ""
echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  ${GREEN}${BOLD}✅ Simulation Complete!${NC}"
echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "  Final: 100% (${CONTEXT_WINDOW} tokens)"
echo ""
echo -e "  ${YELLOW}💡 To restore original context:${NC}"
echo "      cp ${CONTEXT_FILE}.backup ${CONTEXT_FILE}"
echo ""
echo -e "  ${YELLOW}💡 To test PreCompact hook manually:${NC}"
echo "      echo 'test' | ~/.claude/hooks/pre-compact-test.sh"
echo ""
