#!/bin/bash
# validate-compact-hooks.sh - Validate compact hooks configuration
# v2.84.3

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
PASS=0
FAIL=0
WARN=0

# Functions
pass() {
    echo -e "${GREEN}✅ PASS${NC}: $1"
    ((PASS++))
}

fail() {
    echo -e "${RED}❌ FAIL${NC}: $1"
    ((FAIL++))
}

warn() {
    echo -e "${YELLOW}⚠️  WARN${NC}: $1"
    ((WARN++))
}

info() {
    echo -e "${BLUE}ℹ️  INFO${NC}: $1"
}

echo "====================================="
echo "Compact Hooks Validation v2.81.1"
echo "====================================="
echo ""

# 1. JSON Syntax Validation
echo "1. JSON Syntax Validation"
echo "-------------------------"

if python3 -m json.tool ~/.claude-sneakpeek/zai/config/settings.json > /dev/null 2>&1; then
    pass "settings.json has valid JSON syntax (Python parser)"
else
    fail "settings.json has invalid JSON syntax (Python parser)"
fi

if cat ~/.claude-sneakpeek/zai/config/settings.json | jq '.' --exit-status > /dev/null 2>&1; then
    pass "settings.json is valid according to jq"
else
    fail "settings.json failed jq validation"
fi

# 2. Hook Events Exist
echo ""
echo "2. Hook Events Configuration"
echo "----------------------------"

if cat ~/.claude-sneakpeek/zai/config/settings.json | jq -e '.hooks.PreCompact' > /dev/null 2>&1; then
    pass "PreCompact event exists in configuration"
else
    fail "PreCompact event missing from configuration"
fi

if cat ~/.claude-sneakpeek/zai/config/settings.json | jq -e '.hooks.PostCompact' > /dev/null 2>&1; then
    pass "PostCompact event exists in configuration"
else
    fail "PostCompact event missing from configuration"
fi

# 3. Hook Files Exist
echo ""
echo "3. Hook Files Existence"
echo "-----------------------"

PRE_COMPACT_HOOK="$HOME/.claude-sneakpeek/zai/config/hooks/pre-compact-handoff.sh"
POST_COMPACT_HOOK="$HOME/.claude-sneakpeek/zai/config/hooks/post-compact-restore.sh"

if [ -f "$PRE_COMPACT_HOOK" ]; then
    pass "pre-compact-handoff.sh exists at $PRE_COMPACT_HOOK"
else
    fail "pre-compact-handoff.sh NOT FOUND at $PRE_COMPACT_HOOK"
fi

if [ -f "$POST_COMPACT_HOOK" ]; then
    pass "post-compact-restore.sh exists at $POST_COMPACT_HOOK"
else
    fail "post-compact-restore.sh NOT FOUND at $POST_COMPACT_HOOK"
fi

# 4. Hook Permissions
echo ""
echo "4. Hook Permissions"
echo "-------------------"

if [ -x "$PRE_COMPACT_HOOK" ]; then
    pass "pre-compact-handoff.sh is executable"
else
    fail "pre-compact-handoff.sh is NOT executable"
fi

if [ -x "$POST_COMPACT_HOOK" ]; then
    pass "post-compact-restore.sh is executable"
else
    fail "post-compact-restore.sh is NOT executable"
fi

# 5. Hook Paths in Configuration
echo ""
echo "5. Configuration Paths"
echo "----------------------"

CONFIG_PRE_PATH=$(cat ~/.claude-sneakpeek/zai/config/settings.json | jq -r '.hooks.PreCompact[0].hooks[0].command')
CONFIG_POST_PATH=$(cat ~/.claude-sneakpeek/zai/config/settings.json | jq -r '.hooks.PostCompact[0].hooks[0].command')

if [ "$CONFIG_PRE_PATH" = "$PRE_COMPACT_HOOK" ]; then
    pass "PreCompact hook path matches expected global path"
else
    fail "PreCompact hook path mismatch: $CONFIG_PRE_PATH != $PRE_COMPACT_HOOK"
fi

if [ "$CONFIG_POST_PATH" = "$POST_COMPACT_HOOK" ]; then
    pass "PostCompact hook path matches expected global path"
else
    fail "PostCompact hook path mismatch: $CONFIG_POST_PATH != $POST_COMPACT_HOOK"
fi

# 6. No Local Paths
echo ""
echo "6. No Project-Local Paths"
echo "-------------------------"

if echo "$CONFIG_PRE_PATH" | grep -q "Documents/GitHub/multi-agent-ralph-loop/.claude/hooks"; then
    fail "PreCompact still uses project-local path"
else
    pass "PreCompact uses global path (not project-local)"
fi

if echo "$CONFIG_POST_PATH" | grep -q "Documents/GitHub/multi-agent-ralph-loop/.claude/hooks"; then
    fail "PostCompact still uses project-local path"
else
    pass "PostCompact uses global path (not project-local)"
fi

# 7. /compact Skill Removed
echo ""
echo "7. /compact Skill Status"
echo "------------------------"

if [ -L ~/.claude-sneakpeek/zai/config/skills/compact ]; then
    warn "/compact skill symlink still exists (may interfere with automatic compaction)"
elif [ -e ~/.claude-sneakpeek/zai/config/skills/compact ]; then
    warn "/compact skill exists but is not a symlink"
else
    pass "/compact skill symlink has been removed"
fi

# 8. Hook Execution Test
echo ""
echo "8. Hook Execution Test"
echo "---------------------"

TEST_SESSION="test-validation-$(date +%s)"
TEST_INPUT=$(cat <<EOF
{"hook_event_name":"PreCompact","session_id":"$TEST_SESSION","transcript_path":""}
EOF
)

if echo "$TEST_INPUT" | "$PRE_COMPACT_HOOK" 2>&1 | grep -q '{"continue": true}'; then
    pass "pre-compact-handoff.sh executes successfully"
else
    fail "pre-compact-handoff.sh execution failed"
fi

TEST_INPUT_POST=$(cat <<EOF
{"hook_event_name":"PostCompact","session_id":"$TEST_SESSION","transcript_path":""}
EOF
)

if echo "$TEST_INPUT_POST" | "$POST_COMPACT_HOOK" 2>&1 | grep -q '{"continue": true}'; then
    pass "post-compact-restore.sh executes successfully"
else
    fail "post-compact-restore.sh execution failed"
fi

# 9. Hook Count
echo ""
echo "9. Hook Count Verification"
echo "--------------------------"

PRE_HOOK_COUNT=$(cat ~/.claude-sneakpeek/zai/config/settings.json | jq '.hooks.PreCompact[0].hooks | length')
POST_HOOK_COUNT=$(cat ~/.claude-sneakpeek/zai/config/settings.json | jq '.hooks.PostCompact[0].hooks | length')

if [ "$PRE_HOOK_COUNT" -eq 1 ]; then
    pass "PreCompact has exactly 1 hook (correct)"
else
    warn "PreCompact has $PRE_HOOK_COUNT hooks (expected 1)"
fi

if [ "$POST_HOOK_COUNT" -eq 1 ]; then
    pass "PostCompact has exactly 1 hook (correct)"
else
    warn "PostCompact has $POST_HOOK_COUNT hooks (expected 1)"
fi

# 10. Required Scripts Exist
echo ""
echo "10. Required Dependencies"
echo "-------------------------"

if [ -x ~/.claude/scripts/ledger-manager.py ]; then
    pass "ledger-manager.py exists and is executable"
else
    warn "ledger-manager.py not found or not executable"
fi

if [ -x ~/.claude/scripts/handoff-generator.py ]; then
    pass "handoff-generator.py exists and is executable"
else
    warn "handoff-generator.py not found or not executable"
fi

# Summary
echo ""
echo "====================================="
echo "VALIDATION SUMMARY"
echo "====================================="
echo -e "${GREEN}Passed:${NC}   $PASS"
echo -e "${RED}Failed:${NC}   $FAIL"
echo -e "${YELLOW}Warnings:${NC} $WARN"
echo ""

if [ $FAIL -eq 0 ]; then
    echo -e "${GREEN}✅ All critical checks passed!${NC}"
    exit 0
else
    echo -e "${RED}❌ Validation failed with $FAIL error(s)${NC}"
    exit 1
fi
