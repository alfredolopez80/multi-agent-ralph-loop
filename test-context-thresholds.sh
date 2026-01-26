#!/bin/bash
# test-context-thresholds.sh - Test context warning hooks at specific thresholds
# Usage: ./test-context-thresholds.sh [percentage]

set -euo pipefail

# Configuration
PROJECT_STATE="${HOME}/.claude/hooks/project-state.sh"
STATE_DIR=$("$PROJECT_STATE" get-dir 2>/dev/null)
CONTEXT_FILE="${STATE_DIR}/glm-context.json"
CONTEXT_WINDOW=128000
TEST_PCT=${1:-75}  # Default to warning threshold

# Colors
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  🧪 Context Threshold Test Script"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Testing at: ${TEST_PCT}%"
echo "  State Dir: ${STATE_DIR}"
echo ""

# Backup current context
if [[ -f "$CONTEXT_FILE" ]]; then
    cp "$CONTEXT_FILE" "${CONTEXT_FILE}.test-backup"
    echo "  ✅ Backup created"
fi

# Set context to test percentage
tokens=$((CONTEXT_WINDOW * TEST_PCT / 100))

cat > "$CONTEXT_FILE" <<EOF
{
  "total_tokens": $tokens,
  "context_window": $CONTEXT_WINDOW,
  "percentage": $TEST_PCT,
  "last_updated": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "session_start": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "message_count": 1
}
EOF

echo "  ✅ Context set to ${TEST_PCT}% (${tokens} tokens)"
echo ""

# Test the hook
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Testing context-warning.sh hook..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Simulate user prompt submit
echo "test" | ~/.claude/hooks/context-warning.sh 2>&1 || true

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Current Status"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Show current percentage
current_pct=$(jq -r '.percentage // 0' "$CONTEXT_FILE")
echo "  Context: ${current_pct}%"

# Determine expected color
if [[ $TEST_PCT -ge 85 ]]; then
    echo -e "  Expected: ${RED}RED (Critical)${NC}"
elif [[ $TEST_PCT -ge 75 ]]; then
    echo -e "  Expected: ${YELLOW}YELLOW (Warning)${NC}"
elif [[ $TEST_PCT -ge 50 ]]; then
    echo -e "  Expected: ${GREEN}GREEN (Normal)${NC}"
else
    echo -e "  Expected: ${CYAN}CYAN (Low)${NC}"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Cleanup"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Restore backup
if [[ -f "${CONTEXT_FILE}.test-backup" ]]; then
    mv "${CONTEXT_FILE}.test-backup" "$CONTEXT_FILE"
    echo "  ✅ Original context restored"
fi

echo ""
echo "  Test complete!"
echo ""
echo "  💡 To test specific thresholds:"
echo "     ./test-context-thresholds.sh 70   # Below warning"
echo "     ./test-context-thresholds.sh 75   # At warning"
echo "     ./test-context-thresholds.sh 80   # Above warning"
echo "     ./test-context-thresholds.sh 85   # At critical"
echo "     ./test-context-thresholds.sh 90   # Above critical"
echo ""
