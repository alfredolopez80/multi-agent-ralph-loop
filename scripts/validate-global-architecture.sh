#!/bin/bash
# validate-global-architecture.sh - Ralph v2.35 Global Architecture Validator
# Tests that all components are available globally across projects

set -uo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0

check() {
    local name="$1"
    local condition="$2"
    # SEC: Use bash -c with single-quoted condition to prevent injection
    # All callers use hardcoded strings; no user input reaches here
    if bash -c "$condition" 2>/dev/null; then
        echo -e "${GREEN}✓${NC} $name"
        PASS=$((PASS + 1))
    else
        echo -e "${RED}✗${NC} $name"
        FAIL=$((FAIL + 1))
    fi
}

warn() {
    local name="$1"
    local condition="$2"
    # SEC: Use bash -c with single-quoted condition to prevent injection
    if bash -c "$condition" 2>/dev/null; then
        echo -e "${GREEN}✓${NC} $name"
        PASS=$((PASS + 1))
    else
        echo -e "${YELLOW}⚠${NC} $name (optional)"
        WARN=$((WARN + 1))
    fi
}

echo "=============================================="
echo "  Ralph v2.35 Global Architecture Validator"
echo "=============================================="
echo ""

# ==================== LAYER 1: HOOKS ====================
echo "LAYER 1: HOOKS (settings.json)"
echo "----------------------------------------------"
check "Global settings.json exists" "[ -f ~/.claude/settings.json ]"
check "SessionStart hook configured" "grep -q 'SessionStart' ~/.claude/settings.json"
check "PreCompact hook configured" "grep -q 'PreCompact' ~/.claude/settings.json"
check "PostToolUse hook configured" "grep -q 'PostToolUse' ~/.claude/settings.json"
check "PreToolUse hook configured" "grep -q 'PreToolUse' ~/.claude/settings.json"
check "Stop hook configured" "grep -q 'Stop' ~/.claude/settings.json"

echo ""
echo "Hook Scripts:"
check "session-start-ledger.sh exists" "[ -f ~/.claude/hooks/session-start-ledger.sh ]"
check "pre-compact-handoff.sh exists" "[ -f ~/.claude/hooks/pre-compact-handoff.sh ]"
check "quality-gates.sh exists" "[ -f ~/.claude/hooks/quality-gates.sh ]"
check "git-safety-guard.py exists" "[ -f ~/.claude/hooks/git-safety-guard.py ]"
check "auto-sync-global.sh exists" "[ -f ~/.claude/hooks/auto-sync-global.sh ]"

echo ""

# ==================== LAYER 2: AGENTS ====================
echo "LAYER 2: AGENTS (global inheritance)"
echo "----------------------------------------------"
GLOBAL_AGENTS=$(ls ~/.claude/agents/*.md 2>/dev/null | wc -l | tr -d ' ')
check "Global agents directory exists" "[ -d ~/.claude/agents ]"
check "Global agents count >= 20" "[ $GLOBAL_AGENTS -ge 20 ]"
echo "  → Found $GLOBAL_AGENTS global agents"

# Core agents
check "@orchestrator agent exists" "[ -f ~/.claude/agents/orchestrator.md ]"
check "@security-auditor agent exists" "[ -f ~/.claude/agents/security-auditor.md ]"
check "@code-reviewer agent exists" "[ -f ~/.claude/agents/code-reviewer.md ]"
check "@test-architect agent exists" "[ -f ~/.claude/agents/test-architect.md ]"
check "@debugger agent exists" "[ -f ~/.claude/agents/debugger.md ]"

# v2.35 auxiliary agents
check "@code-simplicity-reviewer exists" "[ -f ~/.claude/agents/code-simplicity-reviewer.md ]"
check "@architecture-strategist exists" "[ -f ~/.claude/agents/architecture-strategist.md ]"
check "@kieran-python-reviewer exists" "[ -f ~/.claude/agents/kieran-python-reviewer.md ]"
check "@kieran-typescript-reviewer exists" "[ -f ~/.claude/agents/kieran-typescript-reviewer.md ]"

echo ""

# ==================== LAYER 3: CLI ====================
echo "LAYER 3: CLI FALLBACK (ralph)"
echo "----------------------------------------------"
check "ralph command in PATH" "command -v ralph &>/dev/null"
check "ralph orch command works" "ralph help 2>/dev/null | grep -q 'orch'"
check "ralph clarify command works" "ralph help 2>/dev/null | grep -q 'clarify'"
check "ralph gates command works" "ralph help 2>/dev/null | grep -q 'gates'"
check "ralph adversarial command works" "ralph help 2>/dev/null | grep -q 'adversarial'"
check "ralph retrospective command works" "ralph help 2>/dev/null | grep -q 'retrospective'"
check "ralph worktree command works" "ralph help 2>/dev/null | grep -q 'worktree'"
check "ralph ledger command exists" "grep -q 'cmd_ledger' ~/Documents/GitHub/multi-agent-ralph-loop/scripts/ralph 2>/dev/null || grep -q 'ledger' ~/bin/ralph 2>/dev/null"
check "ralph handoff command exists" "grep -q 'cmd_handoff' ~/Documents/GitHub/multi-agent-ralph-loop/scripts/ralph 2>/dev/null || grep -q 'handoff' ~/bin/ralph 2>/dev/null"

echo ""

# ==================== CONTEXT PRESERVATION ====================
echo "CONTEXT PRESERVATION (v2.35)"
echo "----------------------------------------------"
check "Ledgers directory exists" "[ -d ~/.ralph/ledgers ]"
check "Handoffs directory exists" "[ -d ~/.ralph/handoffs ]"
LEDGER_COUNT=$(ls ~/.ralph/ledgers/*.md 2>/dev/null | wc -l | tr -d ' ')
HANDOFF_COUNT=$(ls -d ~/.ralph/handoffs/*/ 2>/dev/null | wc -l | tr -d ' ')
check "Has saved ledgers" "[ $LEDGER_COUNT -gt 0 ]"
check "Has saved handoffs" "[ $HANDOFF_COUNT -gt 0 ]"
echo "  → Found $LEDGER_COUNT ledgers, $HANDOFF_COUNT handoff sessions"

# Check recent activity
RECENT_LEDGER=$(ls -t ~/.ralph/ledgers/*.md 2>/dev/null | head -1)
if [ -n "$RECENT_LEDGER" ]; then
    AGE=$(( ($(date +%s) - $(stat -f %m "$RECENT_LEDGER" 2>/dev/null || stat -c %Y "$RECENT_LEDGER" 2>/dev/null)) / 3600 ))
    check "Recent ledger (< 24h old)" "[ $AGE -lt 24 ]"
    echo "  → Most recent ledger is ${AGE}h old"
fi

echo ""

# ==================== COMMANDS ====================
echo "COMMANDS (global inheritance)"
echo "----------------------------------------------"
GLOBAL_CMDS=$(ls ~/.claude/commands/*.md 2>/dev/null | wc -l | tr -d ' ')
check "Global commands directory exists" "[ -d ~/.claude/commands ]"
check "Global commands count >= 30" "[ $GLOBAL_CMDS -ge 30 ]"
echo "  → Found $GLOBAL_CMDS global commands"

# Core commands
check "/orchestrator command exists" "[ -f ~/.claude/commands/orchestrator.md ]"
check "/clarify command exists" "[ -f ~/.claude/commands/clarify.md ]"
check "/gates command exists" "[ -f ~/.claude/commands/gates.md ]"
check "/adversarial command exists" "[ -f ~/.claude/commands/adversarial.md ]"
check "/retrospective command exists" "[ -f ~/.claude/commands/retrospective.md ]"

echo ""

# ==================== SKILLS ====================
echo "SKILLS (global reference)"
echo "----------------------------------------------"
GLOBAL_SKILLS=$(ls -d ~/.claude/skills/*/ 2>/dev/null | wc -l | tr -d ' ')
warn "Global skills directory exists" "[ -d ~/.claude/skills ]"
warn "Global skills count >= 50" "[ $GLOBAL_SKILLS -ge 50 ]"
echo "  → Found $GLOBAL_SKILLS global skills"

# Critical skills for orchestrator
warn "task-classifier skill exists" "[ -d ~/.claude/skills/task-classifier ] || [ -f ~/.claude/skills/task-classifier.md ]"
warn "retrospective skill exists" "[ -d ~/.claude/skills/retrospective ] || [ -f ~/.claude/skills/retrospective.md ]"
warn "deep-clarification skill exists" "[ -d ~/.claude/skills/deep-clarification ] || [ -f ~/.claude/skills/deep-clarification.md ]"

echo ""

# ==================== SUMMARY ====================
echo "=============================================="
echo "  SUMMARY"
echo "=============================================="
echo -e "  ${GREEN}PASSED${NC}: $PASS"
echo -e "  ${RED}FAILED${NC}: $FAIL"
echo -e "  ${YELLOW}WARNINGS${NC}: $WARN"
echo ""

if [ $FAIL -eq 0 ]; then
    echo -e "${GREEN}✓ Global architecture is VALID${NC}"
    echo ""
    echo "All critical components are available globally."
    echo "The orchestrator flow will work in any project."
    exit 0
else
    echo -e "${RED}✗ Global architecture has ISSUES${NC}"
    echo ""
    echo "Fix the failed checks above to ensure global availability."
    exit 1
fi
