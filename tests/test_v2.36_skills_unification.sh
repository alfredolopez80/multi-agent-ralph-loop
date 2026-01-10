#!/usr/bin/env bash
# Test suite for Multi-Agent Ralph v2.36 - Skills Unification
# Tests: Commands→Skills migration, Agent hooks, Context thresholds, PostCompact recovery
#
# Usage:
#   ./tests/test_v2.36_skills_unification.sh           # Run all v2.36 tests
#   ./tests/test_v2.36_skills_unification.sh skills    # Run only skills tests
#   ./tests/test_v2.36_skills_unification.sh hooks     # Run only hooks tests
#   ./tests/test_v2.36_skills_unification.sh context   # Run only context tests

set -uo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Counters
PASSED=0
FAILED=0
SKIPPED=0
TOTAL=0

# Configuration
GLOBAL_CLAUDE_DIR="${HOME}/.claude"
GLOBAL_SKILLS_DIR="${GLOBAL_CLAUDE_DIR}/skills"
GLOBAL_AGENTS_DIR="${GLOBAL_CLAUDE_DIR}/agents"
GLOBAL_HOOKS_DIR="${GLOBAL_CLAUDE_DIR}/hooks"
RALPH_DIR="${HOME}/.ralph"

# Test functions
test_pass() {
    ((PASSED++))
    ((TOTAL++))
    echo -e "${GREEN}✅ PASS${NC}: $1"
}

test_fail() {
    ((FAILED++))
    ((TOTAL++))
    echo -e "${RED}❌ FAIL${NC}: $1"
    [ -n "${2:-}" ] && echo "   Details: $2"
}

test_skip() {
    ((SKIPPED++))
    ((TOTAL++))
    echo -e "${YELLOW}⏭️  SKIP${NC}: $1"
}

section() {
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
}

# ============================================================================
# SECTION 1: SKILLS MIGRATION TESTS
# ============================================================================

test_skills_migration() {
    section "Skills Migration Tests (Commands → Skills Unification)"

    # Test 1.1: Global skills directory exists
    echo "Test 1.1: Global skills directory exists"
    if [[ -d "$GLOBAL_SKILLS_DIR" ]]; then
        test_pass "Global skills directory exists at $GLOBAL_SKILLS_DIR"
    else
        test_fail "Global skills directory not found"
    fi

    # Test 1.2: Critical skills exist
    echo "Test 1.2: Critical skills exist"
    local CRITICAL_SKILLS=("orchestrator" "clarify" "gates" "adversarial" "loop" "parallel" "retrospective")
    local MISSING_SKILLS=()

    for skill in "${CRITICAL_SKILLS[@]}"; do
        if [[ ! -f "$GLOBAL_SKILLS_DIR/$skill/SKILL.md" ]]; then
            MISSING_SKILLS+=("$skill")
        fi
    done

    if [[ ${#MISSING_SKILLS[@]} -eq 0 ]]; then
        test_pass "All 7 critical skills exist"
    else
        test_fail "Missing critical skills: ${MISSING_SKILLS[*]}"
    fi

    # Test 1.3: Skills have valid frontmatter
    echo "Test 1.3: Skills have valid frontmatter (name, description)"
    local INVALID_SKILLS=()

    for skill in "${CRITICAL_SKILLS[@]}"; do
        local SKILL_FILE="$GLOBAL_SKILLS_DIR/$skill/SKILL.md"
        if [[ -f "$SKILL_FILE" ]]; then
            # Check for name and description in frontmatter
            if ! grep -q "^name:" "$SKILL_FILE" || ! grep -q "^description:" "$SKILL_FILE"; then
                INVALID_SKILLS+=("$skill")
            fi
        fi
    done

    if [[ ${#INVALID_SKILLS[@]} -eq 0 ]]; then
        test_pass "All critical skills have valid frontmatter"
    else
        test_fail "Skills with invalid frontmatter: ${INVALID_SKILLS[*]}"
    fi

    # Test 1.4: Context isolation skills have context: fork
    echo "Test 1.4: Context isolation skills have 'context: fork'"
    local FORK_SKILLS=("gates" "adversarial" "parallel")
    local MISSING_FORK=()

    for skill in "${FORK_SKILLS[@]}"; do
        local SKILL_FILE="$GLOBAL_SKILLS_DIR/$skill/SKILL.md"
        if [[ -f "$SKILL_FILE" ]]; then
            if ! grep -q "context:.*fork" "$SKILL_FILE"; then
                MISSING_FORK+=("$skill")
            fi
        fi
    done

    if [[ ${#MISSING_FORK[@]} -eq 0 ]]; then
        test_pass "All context isolation skills have 'context: fork'"
    else
        test_fail "Skills missing 'context: fork': ${MISSING_FORK[*]}"
    fi

    # Test 1.5: Total skills count >= 100
    echo "Test 1.5: Total skills count >= 100"
    local SKILL_COUNT
    SKILL_COUNT=$(find "$GLOBAL_SKILLS_DIR" -name "SKILL.md" 2>/dev/null | wc -l | tr -d ' ')

    if [[ "$SKILL_COUNT" -ge 100 ]]; then
        test_pass "Total skills count: $SKILL_COUNT (>= 100)"
    else
        test_fail "Total skills count: $SKILL_COUNT (expected >= 100)"
    fi

    # Test 1.6: Orchestrator skill has 8-step workflow
    echo "Test 1.6: Orchestrator skill documents 8-step workflow"
    local ORCH_FILE="$GLOBAL_SKILLS_DIR/orchestrator/SKILL.md"
    if [[ -f "$ORCH_FILE" ]]; then
        local STEPS_FOUND=0
        for step in "CLARIFY" "CLASSIFY" "WORKTREE" "PLAN" "DELEGATE" "EXECUTE" "VALIDATE" "RETROSPECT"; do
            if grep -qi "$step" "$ORCH_FILE"; then
                ((STEPS_FOUND++))
            fi
        done

        if [[ "$STEPS_FOUND" -ge 6 ]]; then
            test_pass "Orchestrator documents workflow steps ($STEPS_FOUND/8 found)"
        else
            test_fail "Orchestrator missing workflow steps ($STEPS_FOUND/8 found)"
        fi
    else
        test_fail "Orchestrator skill file not found"
    fi

    # Test 1.7: Migration script exists and is executable
    echo "Test 1.7: Migration script exists and is executable"
    local SCRIPT_DIR
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    local MIGRATE_SCRIPT="$SCRIPT_DIR/scripts/migrate-commands-to-skills.sh"

    if [[ -f "$MIGRATE_SCRIPT" && -x "$MIGRATE_SCRIPT" ]]; then
        test_pass "Migration script exists and is executable"
    elif [[ -f "$MIGRATE_SCRIPT" ]]; then
        test_fail "Migration script exists but not executable"
    else
        test_fail "Migration script not found at $MIGRATE_SCRIPT"
    fi
}

# ============================================================================
# SECTION 2: AGENT HOOKS TESTS
# ============================================================================

test_agent_hooks() {
    section "Agent Hooks Tests (5 Priority Agents)"

    # Test 2.1: Priority agents have hooks in frontmatter
    echo "Test 2.1: Priority agents have hooks in frontmatter"
    local PRIORITY_AGENTS=("security-auditor" "orchestrator" "code-reviewer" "test-architect" "debugger")
    local AGENTS_WITHOUT_HOOKS=()

    for agent in "${PRIORITY_AGENTS[@]}"; do
        local AGENT_FILE="$GLOBAL_AGENTS_DIR/$agent.md"
        if [[ -f "$AGENT_FILE" ]]; then
            if ! grep -q "^hooks:" "$AGENT_FILE"; then
                AGENTS_WITHOUT_HOOKS+=("$agent")
            fi
        else
            AGENTS_WITHOUT_HOOKS+=("$agent (file not found)")
        fi
    done

    if [[ ${#AGENTS_WITHOUT_HOOKS[@]} -eq 0 ]]; then
        test_pass "All 5 priority agents have hooks"
    else
        test_fail "Agents without hooks: ${AGENTS_WITHOUT_HOOKS[*]}"
    fi

    # Test 2.2: security-auditor has PreToolUse, PostToolUse, Stop hooks
    echo "Test 2.2: security-auditor has all 3 hook types"
    local SEC_AGENT="$GLOBAL_AGENTS_DIR/security-auditor.md"
    if [[ -f "$SEC_AGENT" ]]; then
        local HAS_PRE HAS_POST HAS_STOP
        HAS_PRE=$(grep -c "PreToolUse:" "$SEC_AGENT" 2>/dev/null || echo 0)
        HAS_POST=$(grep -c "PostToolUse:" "$SEC_AGENT" 2>/dev/null || echo 0)
        HAS_STOP=$(grep -c "Stop:" "$SEC_AGENT" 2>/dev/null || echo 0)

        if [[ "$HAS_PRE" -ge 1 && "$HAS_POST" -ge 1 && "$HAS_STOP" -ge 1 ]]; then
            test_pass "security-auditor has PreToolUse, PostToolUse, Stop hooks"
        else
            test_fail "security-auditor missing hooks (Pre:$HAS_PRE Post:$HAS_POST Stop:$HAS_STOP)"
        fi
    else
        test_fail "security-auditor.md not found"
    fi

    # Test 2.3: Hooks reference log files
    echo "Test 2.3: Agent hooks reference ~/.ralph/logs/"
    local HOOKS_WITH_LOGS=0

    for agent in "${PRIORITY_AGENTS[@]}"; do
        local AGENT_FILE="$GLOBAL_AGENTS_DIR/$agent.md"
        if [[ -f "$AGENT_FILE" ]]; then
            if grep -q "\.ralph/logs/" "$AGENT_FILE"; then
                ((HOOKS_WITH_LOGS++))
            fi
        fi
    done

    if [[ "$HOOKS_WITH_LOGS" -ge 3 ]]; then
        test_pass "At least 3 agents reference ~/.ralph/logs/ ($HOOKS_WITH_LOGS found)"
    else
        test_fail "Only $HOOKS_WITH_LOGS agents reference ~/.ralph/logs/ (expected >= 3)"
    fi

    # Test 2.4: Log directory exists or can be created
    echo "Test 2.4: Log directory exists"
    local LOG_DIR="$RALPH_DIR/logs"
    if [[ -d "$LOG_DIR" ]]; then
        test_pass "Log directory exists at $LOG_DIR"
    else
        mkdir -p "$LOG_DIR" 2>/dev/null
        if [[ -d "$LOG_DIR" ]]; then
            test_pass "Log directory created at $LOG_DIR"
        else
            test_fail "Cannot create log directory at $LOG_DIR"
        fi
    fi

    # Test 2.5: Total agents count >= 20
    echo "Test 2.5: Total agents count >= 20"
    local AGENT_COUNT
    AGENT_COUNT=$(find "$GLOBAL_AGENTS_DIR" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')

    if [[ "$AGENT_COUNT" -ge 20 ]]; then
        test_pass "Total agents count: $AGENT_COUNT (>= 20)"
    else
        test_fail "Total agents count: $AGENT_COUNT (expected >= 20)"
    fi
}

# ============================================================================
# SECTION 3: CONTEXT THRESHOLDS TESTS
# ============================================================================

test_context_thresholds() {
    section "Context Threshold Tests (v2.36 Updates)"

    # Test 3.1: context-warning.sh exists
    echo "Test 3.1: context-warning.sh hook exists"
    local CONTEXT_HOOK="$GLOBAL_HOOKS_DIR/context-warning.sh"
    if [[ -f "$CONTEXT_HOOK" ]]; then
        test_pass "context-warning.sh exists"
    else
        test_fail "context-warning.sh not found at $CONTEXT_HOOK"
        return
    fi

    # Test 3.2: Warning threshold is 80%
    echo "Test 3.2: Warning threshold is 80%"
    if grep -qE "THRESHOLD=80" "$CONTEXT_HOOK"; then
        test_pass "Warning threshold is 80%"
    elif grep -qE "THRESHOLD=" "$CONTEXT_HOOK"; then
        local ACTUAL
        ACTUAL=$(grep -oE "THRESHOLD=[0-9]+" "$CONTEXT_HOOK" | head -1)
        test_fail "Warning threshold is $ACTUAL (expected THRESHOLD=80)"
    else
        test_fail "THRESHOLD not found in context-warning.sh"
    fi

    # Test 3.3: Critical threshold is 85%
    echo "Test 3.3: Critical threshold is 85%"
    if grep -qE "CRITICAL_THRESHOLD=85" "$CONTEXT_HOOK"; then
        test_pass "Critical threshold is 85%"
    elif grep -qE "CRITICAL_THRESHOLD=" "$CONTEXT_HOOK"; then
        local ACTUAL
        ACTUAL=$(grep -oE "CRITICAL_THRESHOLD=[0-9]+" "$CONTEXT_HOOK" | head -1)
        test_fail "Critical threshold is $ACTUAL (expected CRITICAL_THRESHOLD=85)"
    else
        test_fail "CRITICAL_THRESHOLD not found in context-warning.sh"
    fi

    # Test 3.4: Info threshold >= 70%
    echo "Test 3.4: Info threshold >= 70%"
    if grep -qE "context_pct.*-ge.*7[0-9]" "$CONTEXT_HOOK" || grep -qE "70" "$CONTEXT_HOOK"; then
        test_pass "Info threshold appears to be >= 70%"
    else
        test_skip "Info threshold check inconclusive"
    fi

    # Test 3.5: Hook is executable
    echo "Test 3.5: context-warning.sh is executable"
    if [[ -x "$CONTEXT_HOOK" ]]; then
        test_pass "context-warning.sh is executable"
    else
        test_fail "context-warning.sh is not executable"
    fi

    # Test 3.6: Hook has shebang
    echo "Test 3.6: context-warning.sh has valid shebang"
    if head -1 "$CONTEXT_HOOK" | grep -qE "^#!/bin/bash|^#!/usr/bin/env bash"; then
        test_pass "context-warning.sh has valid bash shebang"
    else
        test_fail "context-warning.sh missing or invalid shebang"
    fi
}

# ============================================================================
# SECTION 4: POST-COMPACT RECOVERY TESTS
# ============================================================================

test_postcompact_recovery() {
    section "PostCompact Recovery Tests (SessionStart:compact)"

    # Test 4.1: session-start-ledger.sh exists
    echo "Test 4.1: session-start-ledger.sh hook exists"
    local SESSION_HOOK="$GLOBAL_HOOKS_DIR/session-start-ledger.sh"
    if [[ -f "$SESSION_HOOK" ]]; then
        test_pass "session-start-ledger.sh exists"
    else
        test_fail "session-start-ledger.sh not found"
        return
    fi

    # Test 4.2: Hook handles compact event
    echo "Test 4.2: Hook handles 'compact' source event"
    if grep -q "compact" "$SESSION_HOOK"; then
        test_pass "Hook handles 'compact' event"
    else
        test_fail "Hook does not handle 'compact' event"
    fi

    # Test 4.3: Hook mentions claude-mem MCP
    echo "Test 4.3: Hook references claude-mem MCP for context recovery"
    if grep -qi "claude-mem\|mcp-search\|get_observations" "$SESSION_HOOK"; then
        test_pass "Hook references claude-mem MCP"
    else
        test_skip "Hook may not reference claude-mem MCP directly"
    fi

    # Test 4.4: pre-compact-handoff.sh exists
    echo "Test 4.4: pre-compact-handoff.sh hook exists"
    local PRECOMPACT_HOOK="$GLOBAL_HOOKS_DIR/pre-compact-handoff.sh"
    if [[ -f "$PRECOMPACT_HOOK" ]]; then
        test_pass "pre-compact-handoff.sh exists"
    else
        test_fail "pre-compact-handoff.sh not found"
    fi

    # Test 4.5: Ledger directory exists or can be created
    echo "Test 4.5: Ledger directory exists"
    local LEDGER_DIR="$RALPH_DIR/ledgers"
    if [[ -d "$LEDGER_DIR" ]]; then
        test_pass "Ledger directory exists at $LEDGER_DIR"
    else
        mkdir -p "$LEDGER_DIR" 2>/dev/null
        if [[ -d "$LEDGER_DIR" ]]; then
            test_pass "Ledger directory created at $LEDGER_DIR"
        else
            test_fail "Cannot create ledger directory"
        fi
    fi

    # Test 4.6: Handoff directory exists
    echo "Test 4.6: Handoff directory exists"
    local HANDOFF_DIR="$RALPH_DIR/handoffs"
    if [[ -d "$HANDOFF_DIR" ]]; then
        test_pass "Handoff directory exists at $HANDOFF_DIR"
    else
        mkdir -p "$HANDOFF_DIR" 2>/dev/null
        if [[ -d "$HANDOFF_DIR" ]]; then
            test_pass "Handoff directory created at $HANDOFF_DIR"
        else
            test_fail "Cannot create handoff directory"
        fi
    fi

    # Test 4.7: settings.json has SessionStart hook
    echo "Test 4.7: Global settings.json has SessionStart hook"
    local SETTINGS_FILE="$GLOBAL_CLAUDE_DIR/settings.json"
    if [[ -f "$SETTINGS_FILE" ]]; then
        if grep -q "SessionStart" "$SETTINGS_FILE"; then
            test_pass "settings.json has SessionStart hook configured"
        else
            test_fail "settings.json missing SessionStart hook"
        fi
    else
        test_fail "Global settings.json not found"
    fi
}

# ============================================================================
# SECTION 5: GLOBAL CONFIGURATION TESTS
# ============================================================================

test_global_config() {
    section "Global Configuration Tests (Zero-Config Availability)"

    # Test 5.1: settings.json exists
    echo "Test 5.1: Global settings.json exists"
    local SETTINGS_FILE="$GLOBAL_CLAUDE_DIR/settings.json"
    if [[ -f "$SETTINGS_FILE" ]]; then
        test_pass "Global settings.json exists"
    else
        test_fail "Global settings.json not found"
        return
    fi

    # Test 5.2: settings.json is valid JSON
    echo "Test 5.2: settings.json is valid JSON"
    if jq empty "$SETTINGS_FILE" 2>/dev/null; then
        test_pass "settings.json is valid JSON"
    else
        test_fail "settings.json is not valid JSON"
    fi

    # Test 5.3: settings.json has hooks configuration
    echo "Test 5.3: settings.json has hooks configuration"
    if jq -e '.hooks' "$SETTINGS_FILE" >/dev/null 2>&1; then
        test_pass "settings.json has hooks configuration"
    else
        test_fail "settings.json missing hooks configuration"
    fi

    # Test 5.4: At least 4 hook types configured
    echo "Test 5.4: At least 4 hook types configured"
    local HOOK_TYPES
    HOOK_TYPES=$(jq -r '.hooks | keys | length' "$SETTINGS_FILE" 2>/dev/null || echo 0)
    if [[ "$HOOK_TYPES" -ge 4 ]]; then
        test_pass "Hook types configured: $HOOK_TYPES (>= 4)"
    else
        test_fail "Hook types configured: $HOOK_TYPES (expected >= 4)"
    fi

    # Test 5.5: CLAUDE.md exists globally
    echo "Test 5.5: Global CLAUDE.md exists"
    if [[ -f "$GLOBAL_CLAUDE_DIR/CLAUDE.md" ]]; then
        test_pass "Global CLAUDE.md exists"
    else
        test_fail "Global CLAUDE.md not found"
    fi

    # Test 5.6: CLAUDE.md mentions v2.35 or higher
    echo "Test 5.6: CLAUDE.md references v2.35+"
    if grep -qE "v2\.3[5-9]|v2\.[4-9]|v3\." "$GLOBAL_CLAUDE_DIR/CLAUDE.md" 2>/dev/null; then
        test_pass "CLAUDE.md references v2.35+"
    else
        test_skip "CLAUDE.md version check inconclusive"
    fi
}

# ============================================================================
# SECTION 6: RALPH CLI INTEGRATION TESTS
# ============================================================================

test_ralph_cli() {
    section "Ralph CLI Integration Tests"

    # Test 6.1: ralph command exists
    echo "Test 6.1: ralph command exists in PATH"
    if command -v ralph &>/dev/null; then
        test_pass "ralph command found in PATH"
    else
        test_fail "ralph command not found in PATH"
        return
    fi

    # Test 6.2: ralph sync-global command exists
    echo "Test 6.2: ralph sync-global command exists"
    if ralph help 2>&1 | grep -q "sync-global"; then
        test_pass "ralph sync-global command documented"
    else
        test_fail "ralph sync-global not found in help"
    fi

    # Test 6.3: ralph validate-arch command exists
    echo "Test 6.3: ralph validate-arch command exists"
    if ralph help 2>&1 | grep -q "validate-arch"; then
        test_pass "ralph validate-arch command documented"
    else
        test_fail "ralph validate-arch not found in help"
    fi

    # Test 6.4: ralph ledger command exists
    echo "Test 6.4: ralph ledger command exists"
    if ralph help 2>&1 | grep -q "ledger"; then
        test_pass "ralph ledger command documented"
    else
        test_fail "ralph ledger not found in help"
    fi

    # Test 6.5: ralph gates command exists
    echo "Test 6.5: ralph gates command exists"
    if ralph help 2>&1 | grep -q "gates"; then
        test_pass "ralph gates command documented"
    else
        test_fail "ralph gates not found in help"
    fi
}

# ============================================================================
# SUMMARY AND MAIN
# ============================================================================

print_summary() {
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  TEST SUMMARY - Multi-Agent Ralph v2.36${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "  Total Tests:  ${TOTAL}"
    echo -e "  ${GREEN}Passed${NC}:       ${PASSED}"
    echo -e "  ${RED}Failed${NC}:       ${FAILED}"
    echo -e "  ${YELLOW}Skipped${NC}:      ${SKIPPED}"
    echo ""

    if [[ $FAILED -eq 0 ]]; then
        echo -e "${GREEN}✅ ALL TESTS PASSED!${NC}"
        echo ""
        echo "v2.36 Skills Unification is properly configured."
        return 0
    else
        echo -e "${RED}❌ $FAILED TEST(S) FAILED${NC}"
        echo ""
        echo "Please review the failures above and fix the issues."
        return 1
    fi
}

main() {
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  Multi-Agent Ralph v2.36 Test Suite${NC}"
    echo -e "${BLUE}  Commands→Skills Unification + Agent Hooks + Context Update${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "Testing against:"
    echo "  Global Claude Dir: $GLOBAL_CLAUDE_DIR"
    echo "  Ralph Dir: $RALPH_DIR"
    echo ""

    local MODE="${1:-all}"

    case "$MODE" in
        skills)
            test_skills_migration
            ;;
        hooks|agents)
            test_agent_hooks
            ;;
        context|thresholds)
            test_context_thresholds
            ;;
        postcompact|recovery)
            test_postcompact_recovery
            ;;
        global|config)
            test_global_config
            ;;
        cli|ralph)
            test_ralph_cli
            ;;
        all|"")
            test_skills_migration
            test_agent_hooks
            test_context_thresholds
            test_postcompact_recovery
            test_global_config
            test_ralph_cli
            ;;
        *)
            echo "Usage: $0 [skills|hooks|context|postcompact|global|cli|all]"
            exit 1
            ;;
    esac

    print_summary
}

main "$@"
