#!/bin/bash
# Hook Diagnostic Script
# Verifica que todos los hooks estén funcionando correctamente

set -e

LOG_FILE="/tmp/claude-hook-diagnostic.log"
echo "=== Claude Code Hook Diagnostic ===" | tee "$LOG_FILE"
echo "Date: $(date)" | tee -a "$LOG_FILE"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

pass() { echo -e "${GREEN}✅ $1${NC}" | tee -a "$LOG_FILE"; }
fail() { echo -e "${RED}❌ $1${NC}" | tee -a "$LOG_FILE"; }
warn() { echo -e "${YELLOW}⚠️  $1${NC}" | tee -a "$LOG_FILE"; }

# 1. Check settings.json exists
echo "" | tee -a "$LOG_FILE"
echo "=== 1. Settings File ===" | tee -a "$LOG_FILE"
SETTINGS_FILE="$HOME/.claude/settings.json"
if [ -f "$SETTINGS_FILE" ]; then
    pass "settings.json exists: $SETTINGS_FILE"
else
    fail "settings.json NOT FOUND: $SETTINGS_FILE"
    exit 1
fi

# 2. Check hooks configuration
echo "" | tee -a "$LOG_FILE"
echo "=== 2. Hooks Configuration ===" | tee -a "$LOG_FILE"
HOOK_TYPES=$(jq -r '.hooks | keys[]' "$SETTINGS_FILE" 2>/dev/null)
if [ -n "$HOOK_TYPES" ]; then
    echo "Hook types configured:" | tee -a "$LOG_FILE"
    for type in $HOOK_TYPES; do
        count=$(jq ".hooks.$type | length" "$SETTINGS_FILE" 2>/dev/null)
        echo "  - $type: $count hook groups" | tee -a "$LOG_FILE"
    done
    pass "Hooks are configured"
else
    fail "No hooks configured in settings.json"
fi

# 3. Check each hook file exists and is executable
echo "" | tee -a "$LOG_FILE"
echo "=== 3. Hook Files ===" | tee -a "$LOG_FILE"

check_hooks() {
    local hook_type=$1
    local hooks=$(jq -r ".hooks.$hook_type[]?.hooks[]?.command" "$SETTINGS_FILE" 2>/dev/null)

    for hook in $hooks; do
        # Skip non-file commands (like inline scripts)
        if [[ "$hook" == /* ]]; then
            if [ -f "$hook" ]; then
                if [ -x "$hook" ]; then
                    pass "$hook"
                else
                    warn "$hook (NOT EXECUTABLE - run: chmod +x $hook)"
                fi
            else
                fail "$hook (FILE NOT FOUND)"
            fi
        fi
    done
}

for type in $HOOK_TYPES; do
    echo "" | tee -a "$LOG_FILE"
    echo "Checking $type hooks:" | tee -a "$LOG_FILE"
    check_hooks "$type"
done

# 4. Check claude-mem plugin
echo "" | tee -a "$LOG_FILE"
echo "=== 4. Claude-mem Plugin ===" | tee -a "$LOG_FILE"

PLUGIN_ROOT="$HOME/.claude/plugins/cache/thedotmack/claude-mem/10.0.6"
if [ -d "$PLUGIN_ROOT" ]; then
    pass "Plugin directory exists: $PLUGIN_ROOT"

    # Check hooks.json
    if [ -f "$PLUGIN_ROOT/hooks/hooks.json" ]; then
        pass "Plugin hooks.json exists"

        # Check matcher
        MATCHER=$(jq -r '.hooks.SessionStart[0].matcher' "$PLUGIN_ROOT/hooks/hooks.json" 2>/dev/null)
        echo "  SessionStart matcher: $MATCHER" | tee -a "$LOG_FILE"
    else
        fail "Plugin hooks.json NOT FOUND"
    fi

    # Check worker-service.cjs
    if [ -f "$PLUGIN_ROOT/scripts/worker-service.cjs" ]; then
        pass "worker-service.cjs exists"
    else
        fail "worker-service.cjs NOT FOUND"
    fi
else
    fail "Plugin directory NOT FOUND"
fi

# 5. Test hook execution
echo "" | tee -a "$LOG_FILE"
echo "=== 5. Test Hook Execution ===" | tee -a "$LOG_FILE"

# Test a simple hook
TEST_HOOK="/Users/alfredolopez/Documents/GitHub/multi-agent-ralph-loop/.claude/hooks/session-start-restore-context.sh"
if [ -x "$TEST_HOOK" ]; then
    echo "Testing: $TEST_HOOK" | tee -a "$LOG_FILE"
    OUTPUT=$("$TEST_HOOK" 2>&1 | head -5)
    EXIT_CODE=$?
    if [ $EXIT_CODE -eq 0 ]; then
        pass "Hook executed successfully"
        echo "  Output preview: ${OUTPUT:0:100}..." | tee -a "$LOG_FILE"
    else
        fail "Hook failed with exit code: $EXIT_CODE"
    fi
fi

# 6. Test claude-mem worker
echo "" | tee -a "$LOG_FILE"
echo "=== 6. Claude-mem Worker Test ===" | tee -a "$LOG_FILE"

export CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT"
cd /Users/alfredolopez/Documents/GitHub/multi-agent-ralph-loop 2>/dev/null || true

if [ -f "$PLUGIN_ROOT/scripts/worker-service.cjs" ]; then
    echo "Testing worker status..." | tee -a "$LOG_FILE"
    WORKER_OUTPUT=$(bun "$PLUGIN_ROOT/scripts/worker-service.cjs" status 2>&1)
    if echo "$WORKER_OUTPUT" | grep -q "running"; then
        pass "Worker is running"
    else
        warn "Worker not running - starting..."
        bun "$PLUGIN_ROOT/scripts/worker-service.cjs" start 2>&1 | head -3 | tee -a "$LOG_FILE"
    fi

    echo "" | tee -a "$LOG_FILE"
    echo "Testing context generation..." | tee -a "$LOG_FILE"
    CONTEXT_OUTPUT=$(bun "$PLUGIN_ROOT/scripts/worker-service.cjs" hook claude-code context 2>&1 | head -3)
    if echo "$CONTEXT_OUTPUT" | grep -q "additionalContext"; then
        pass "Context generation works"
    else
        fail "Context generation failed"
    fi
fi

# 7. Check CLAUDE_PLUGIN_ROOT environment
echo "" | tee -a "$LOG_FILE"
echo "=== 7. Environment Variables ===" | tee -a "$LOG_FILE"

if [ -n "$CLAUDE_PLUGIN_ROOT" ]; then
    if [ -d "$CLAUDE_PLUGIN_ROOT" ]; then
        pass "CLAUDE_PLUGIN_ROOT is set and exists: $CLAUDE_PLUGIN_ROOT"
    else
        fail "CLAUDE_PLUGIN_ROOT is set but directory doesn't exist: $CLAUDE_PLUGIN_ROOT"
    fi
else
    warn "CLAUDE_PLUGIN_ROOT is not set (may cause plugin hooks to fail)"
fi

# Summary
echo "" | tee -a "$LOG_FILE"
echo "=== Summary ===" | tee -a "$LOG_FILE"
echo "Log saved to: $LOG_FILE" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"
echo "If hooks are configured correctly but not running:" | tee -a "$LOG_FILE"
echo "1. Restart Claude Code" | tee -a "$LOG_FILE"
echo "2. Check if hooks.json matcher matches your session type" | tee -a "$LOG_FILE"
echo "3. Run: source ~/.zshrc to ensure CLAUDE_PLUGIN_ROOT is set" | tee -a "$LOG_FILE"
