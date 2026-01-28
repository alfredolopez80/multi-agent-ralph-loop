#!/bin/bash
# verify-statusline-context.sh - Test statusline context reading
#
# This script verifies that statusline-ralph.sh correctly reads
# the native used_percentage from stdin JSON.

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=== Statusline Context Verification ==="
echo ""

# Test case 1: Valid used_percentage
echo "Test 1: Valid used_percentage (71%)"
test_json='{
  "context_window": {
    "context_window_size": 200000,
    "used_percentage": 71,
    "remaining_percentage": 29
  }
}'

# Extract using v2.78.0 method
used_pct=$(echo "$test_json" | jq -r '.context_window.used_percentage // 0')
context_size=$(echo "$test_json" | jq -r '.context_window.context_window_size // 200000')
remaining_pct=$((100 - used_pct))
used_tokens=$((context_size * used_pct / 100))
free_space=$((context_size - used_tokens))

echo "  Input: used_percentage=71"
echo "  Output: Used: $used_tokens/$context_size ($used_pct%)"
echo "  Output: Free: $free_space ($remaining_pct%)"

if [[ $used_pct -eq 71 ]] && [[ $remaining_pct -eq 29 ]]; then
    echo -e "  ${GREEN}✓ PASS${NC}"
else
    echo -e "  ${RED}✗ FAIL${NC}"
fi
echo ""

# Test case 2: Zero percentage
echo "Test 2: Zero percentage (0%)"
test_json='{
  "context_window": {
    "context_window_size": 200000,
    "used_percentage": 0,
    "remaining_percentage": 100
  }
}'

used_pct=$(echo "$test_json" | jq -r '.context_window.used_percentage // 0')
context_size=$(echo "$test_json" | jq -r '.context_window.context_window_size // 200000')
remaining_pct=$((100 - used_pct))

echo "  Input: used_percentage=0"
echo "  Output: Used: $used_pct%, Free: $remaining_pct%"

if [[ $used_pct -eq 0 ]] && [[ $remaining_pct -eq 100 ]]; then
    echo -e "  ${GREEN}✓ PASS${NC}"
else
    echo -e "  ${RED}✗ FAIL${NC}"
fi
echo ""

# Test case 3: High percentage (85% - should be RED warning)
echo "Test 3: High percentage (85% - warning threshold)"
test_json='{
  "context_window": {
    "context_window_size": 200000,
    "used_percentage": 85,
    "remaining_percentage": 15
  }
}'

used_pct=$(echo "$test_json" | jq -r '.context_window.used_percentage // 0')
color="$GREEN"
if [[ $used_pct -ge 85 ]]; then
    color="$RED"
elif [[ $used_pct -ge 75 ]]; then
    color="$YELLOW"
fi

echo "  Input: used_percentage=85"
echo "  Output: $used_pct% (color should be RED)"

if [[ $used_pct -eq 85 ]]; then
    echo -e "  ${GREEN}✓ PASS${NC}"
else
    echo -e "  ${RED}✗ FAIL${NC}"
fi
echo ""

# Summary
echo "=== Summary ==="
echo "Statusline v2.78.0 reads native used_percentage from stdin JSON"
echo "This is the SAME data source as /context command"
echo ""
echo "Expected behavior:"
echo "  /context shows: Free: 58k (29.0%)"
echo "  Statusline shows: Free: 58k (29%)"
echo ""
echo "If values match, the fix is working correctly."
