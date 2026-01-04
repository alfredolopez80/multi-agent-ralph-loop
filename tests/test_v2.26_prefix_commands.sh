#!/usr/bin/env bash
# v2.26 Test Suite - Prefix-Based Slash Commands
# Tests prefix system, Anthropic directives, task persistence, and /commands

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASSED=0
FAILED=0
TOTAL=0

test_pass() {
    echo -e "${GREEN}✓${NC} $1"
    ((PASSED++))
    ((TOTAL++))
}

test_fail() {
    echo -e "${RED}✗${NC} $1"
    ((FAILED++))
    ((TOTAL++))
}

# ============================================================================
# Test Group 1: Command Frontmatter Validation
# ============================================================================

echo ""
echo "=== Group 1: Command Frontmatter Validation ==="

# Test 1: All commands have prefix field
test_prefix_field() {
    local count=$(grep -l "^prefix:" "$PROJECT_ROOT"/.claude/commands/*.md 2>/dev/null | wc -l)
    if [ "$count" -ge 21 ]; then
        test_pass "All commands have prefix field ($count files)"
    else
        test_fail "Not all commands have prefix field ($count/21)"
    fi
}
test_prefix_field

# Test 2: All commands have category field
test_category_field() {
    local count=$(grep -l "^category:" "$PROJECT_ROOT"/.claude/commands/*.md 2>/dev/null | wc -l)
    if [ "$count" -ge 21 ]; then
        test_pass "All commands have category field ($count files)"
    else
        test_fail "Not all commands have category field ($count/21)"
    fi
}
test_category_field

# Test 3: All commands have color field
test_color_field() {
    local count=$(grep -l "^color:" "$PROJECT_ROOT"/.claude/commands/*.md 2>/dev/null | wc -l)
    if [ "$count" -ge 21 ]; then
        test_pass "All commands have color field ($count files)"
    else
        test_fail "Not all commands have color field ($count/21)"
    fi
}
test_color_field

# Test 4: Orchestration category is purple
test_orchestration_purple() {
    local orch_color=$(grep -A1 "^category: orchestration" "$PROJECT_ROOT"/.claude/commands/orchestrator.md | grep "^color:" | awk '{print $2}')
    if [ "$orch_color" = "purple" ]; then
        test_pass "Orchestration category is purple"
    else
        test_fail "Orchestration category should be purple, got: $orch_color"
    fi
}
test_orchestration_purple

# Test 5: Review category is red
test_review_red() {
    local sec_color=$(grep -A1 "^category: review" "$PROJECT_ROOT"/.claude/commands/security.md | grep "^color:" | awk '{print $2}')
    if [ "$sec_color" = "red" ]; then
        test_pass "Review category is red"
    else
        test_fail "Review category should be red, got: $sec_color"
    fi
}
test_review_red

# Test 6: Research category is blue
test_research_blue() {
    local res_color=$(grep -A1 "^category: research" "$PROJECT_ROOT"/.claude/commands/research.md | grep "^color:" | awk '{print $2}')
    if [ "$res_color" = "blue" ]; then
        test_pass "Research category is blue"
    else
        test_fail "Research category should be blue, got: $res_color"
    fi
}
test_research_blue

# Test 7: Tools category is green
test_tools_green() {
    local tools_color=$(grep -A1 "^category: tools" "$PROJECT_ROOT"/.claude/commands/gates.md | grep "^color:" | awk '{print $2}')
    if [ "$tools_color" = "green" ]; then
        test_pass "Tools category is green"
    else
        test_fail "Tools category should be green, got: $tools_color"
    fi
}
test_tools_green

# ============================================================================
# Test Group 2: Prefix Format Validation
# ============================================================================

echo ""
echo "=== Group 2: Prefix Format Validation ==="

# Test 8: All prefixes start with @
test_prefix_format() {
    local bad_prefixes=$(grep "^prefix:" "$PROJECT_ROOT"/.claude/commands/*.md | grep -v '@' | wc -l)
    if [ "$bad_prefixes" -eq 0 ]; then
        test_pass "All prefixes start with @"
    else
        test_fail "Some prefixes don't start with @ ($bad_prefixes)"
    fi
}
test_prefix_format

# Test 9: Orchestrator prefix is @orch
test_orch_prefix() {
    local prefix=$(grep "^prefix:" "$PROJECT_ROOT"/.claude/commands/orchestrator.md | awk '{print $2}' | tr -d '"')
    if [ "$prefix" = "@orch" ]; then
        test_pass "Orchestrator prefix is @orch"
    else
        test_fail "Orchestrator prefix should be @orch, got: $prefix"
    fi
}
test_orch_prefix

# Test 10: Security prefix is @sec
test_sec_prefix() {
    local prefix=$(grep "^prefix:" "$PROJECT_ROOT"/.claude/commands/security.md | awk '{print $2}' | tr -d '"')
    if [ "$prefix" = "@sec" ]; then
        test_pass "Security prefix is @sec"
    else
        test_fail "Security prefix should be @sec, got: $prefix"
    fi
}
test_sec_prefix

# Test 11: Library-docs prefix is @lib
test_lib_prefix() {
    local prefix=$(grep "^prefix:" "$PROJECT_ROOT"/.claude/commands/library-docs.md | awk '{print $2}' | tr -d '"')
    if [ "$prefix" = "@lib" ]; then
        test_pass "Library-docs prefix is @lib"
    else
        test_fail "Library-docs prefix should be @lib, got: $prefix"
    fi
}
test_lib_prefix

# Test 12: Gates prefix is @gates
test_gates_prefix() {
    local prefix=$(grep "^prefix:" "$PROJECT_ROOT"/.claude/commands/gates.md | awk '{print $2}' | tr -d '"')
    if [ "$prefix" = "@gates" ]; then
        test_pass "Gates prefix is @gates"
    else
        test_fail "Gates prefix should be @gates, got: $prefix"
    fi
}
test_gates_prefix

# ============================================================================
# Test Group 3: New Commands Validation
# ============================================================================

echo ""
echo "=== Group 3: New Commands Validation ==="

# Test 13: /commands command exists
test_commands_exists() {
    if [ -f "$PROJECT_ROOT/.claude/commands/commands.md" ]; then
        test_pass "/commands command file exists"
    else
        test_fail "/commands command file does not exist"
    fi
}
test_commands_exists

# Test 14: /diagram command exists
test_diagram_exists() {
    if [ -f "$PROJECT_ROOT/.claude/commands/diagram.md" ]; then
        test_pass "/diagram command file exists"
    else
        test_fail "/diagram command file does not exist"
    fi
}
test_diagram_exists

# Test 15: /commands has @cmds prefix
test_cmds_prefix() {
    if [ -f "$PROJECT_ROOT/.claude/commands/commands.md" ]; then
        local prefix=$(grep "^prefix:" "$PROJECT_ROOT"/.claude/commands/commands.md | awk '{print $2}' | tr -d '"')
        if [ "$prefix" = "@cmds" ]; then
            test_pass "/commands has @cmds prefix"
        else
            test_fail "/commands should have @cmds prefix, got: $prefix"
        fi
    else
        test_fail "/commands file not found"
    fi
}
test_cmds_prefix

# Test 16: /diagram has @diagram prefix
test_diagram_prefix() {
    if [ -f "$PROJECT_ROOT/.claude/commands/diagram.md" ]; then
        local prefix=$(grep "^prefix:" "$PROJECT_ROOT"/.claude/commands/diagram.md | awk '{print $2}' | tr -d '"')
        if [ "$prefix" = "@diagram" ]; then
            test_pass "/diagram has @diagram prefix"
        else
            test_fail "/diagram should have @diagram prefix, got: $prefix"
        fi
    else
        test_fail "/diagram file not found"
    fi
}
test_diagram_prefix

# ============================================================================
# Test Group 4: Task Persistence Files
# ============================================================================

echo ""
echo "=== Group 4: Task Persistence Files ==="

# Test 17: .ralph directory exists
test_ralph_dir() {
    if [ -d "$PROJECT_ROOT/.ralph" ]; then
        test_pass ".ralph directory exists"
    else
        test_fail ".ralph directory does not exist"
    fi
}
test_ralph_dir

# Test 18: tasks.json exists
test_tasks_json() {
    if [ -f "$PROJECT_ROOT/.ralph/tasks.json" ]; then
        test_pass "tasks.json exists"
    else
        test_fail "tasks.json does not exist"
    fi
}
test_tasks_json

# Test 19: tasks-schema.json exists
test_tasks_schema() {
    if [ -f "$PROJECT_ROOT/.ralph/tasks-schema.json" ]; then
        test_pass "tasks-schema.json exists"
    else
        test_fail "tasks-schema.json does not exist"
    fi
}
test_tasks_schema

# Test 20: tasks.json is valid JSON
test_tasks_json_valid() {
    if [ -f "$PROJECT_ROOT/.ralph/tasks.json" ]; then
        if jq empty "$PROJECT_ROOT/.ralph/tasks.json" 2>/dev/null; then
            test_pass "tasks.json is valid JSON"
        else
            test_fail "tasks.json is not valid JSON"
        fi
    else
        test_fail "tasks.json not found"
    fi
}
test_tasks_json_valid

# Test 21: tasks.json has version 2.26.0
test_tasks_version() {
    if [ -f "$PROJECT_ROOT/.ralph/tasks.json" ]; then
        local version=$(jq -r '.version' "$PROJECT_ROOT/.ralph/tasks.json")
        if [ "$version" = "2.26.0" ]; then
            test_pass "tasks.json version is 2.26.0"
        else
            test_fail "tasks.json version should be 2.26.0, got: $version"
        fi
    else
        test_fail "tasks.json not found"
    fi
}
test_tasks_version

# ============================================================================
# Test Group 5: Anthropic Directives in CLAUDE.md
# ============================================================================

echo ""
echo "=== Group 5: Anthropic Directives in CLAUDE.md ==="

# Test 22: CLAUDE.md has investigate_before_answering
test_investigate_directive() {
    if grep -q "<investigate_before_answering>" "$PROJECT_ROOT/CLAUDE.md"; then
        test_pass "CLAUDE.md has investigate_before_answering directive"
    else
        test_fail "CLAUDE.md missing investigate_before_answering directive"
    fi
}
test_investigate_directive

# Test 23: CLAUDE.md has use_parallel_tool_calls
test_parallel_directive() {
    if grep -q "<use_parallel_tool_calls>" "$PROJECT_ROOT/CLAUDE.md"; then
        test_pass "CLAUDE.md has use_parallel_tool_calls directive"
    else
        test_fail "CLAUDE.md missing use_parallel_tool_calls directive"
    fi
}
test_parallel_directive

# Test 24: CLAUDE.md has default_to_action
test_action_directive() {
    if grep -q "<default_to_action>" "$PROJECT_ROOT/CLAUDE.md"; then
        test_pass "CLAUDE.md has default_to_action directive"
    else
        test_fail "CLAUDE.md missing default_to_action directive"
    fi
}
test_action_directive

# Test 25: CLAUDE.md has avoid_overengineering
test_overengineering_directive() {
    if grep -q "<avoid_overengineering>" "$PROJECT_ROOT/CLAUDE.md"; then
        test_pass "CLAUDE.md has avoid_overengineering directive"
    else
        test_fail "CLAUDE.md missing avoid_overengineering directive"
    fi
}
test_overengineering_directive

# Test 26: CLAUDE.md has code_exploration
test_exploration_directive() {
    if grep -q "<code_exploration>" "$PROJECT_ROOT/CLAUDE.md"; then
        test_pass "CLAUDE.md has code_exploration directive"
    else
        test_fail "CLAUDE.md missing code_exploration directive"
    fi
}
test_exploration_directive

# ============================================================================
# Test Group 6: Version Consistency
# ============================================================================

echo ""
echo "=== Group 6: Version Consistency ==="

# Test 27: CLAUDE.md references v2.26
test_claude_md_version() {
    if grep -q "v2.26" "$PROJECT_ROOT/CLAUDE.md"; then
        test_pass "CLAUDE.md references v2.26"
    else
        test_fail "CLAUDE.md should reference v2.26"
    fi
}
test_claude_md_version

# Test 28: README.md references v2.26
test_readme_version() {
    if grep -q "v2.26" "$PROJECT_ROOT/README.md"; then
        test_pass "README.md references v2.26"
    else
        test_fail "README.md should reference v2.26"
    fi
}
test_readme_version

# Test 29: ralph script has VERSION="2.26.0"
test_ralph_version() {
    if grep -q 'VERSION="2.26.0"' "$PROJECT_ROOT/scripts/ralph"; then
        test_pass "ralph script has VERSION=2.26.0"
    else
        test_fail "ralph script should have VERSION=2.26.0"
    fi
}
test_ralph_version

# ============================================================================
# Test Group 7: Task Visualizer Skill
# ============================================================================

echo ""
echo "=== Group 7: Task Visualizer Skill ==="

# Test 30: task-visualizer skill exists
test_task_visualizer_exists() {
    if [ -d "$PROJECT_ROOT/.claude/skills/task-visualizer" ]; then
        test_pass "task-visualizer skill directory exists"
    else
        test_fail "task-visualizer skill directory does not exist"
    fi
}
test_task_visualizer_exists

# Test 31: task-visualizer has skill.md
test_task_visualizer_skill() {
    if [ -f "$PROJECT_ROOT/.claude/skills/task-visualizer/skill.md" ]; then
        test_pass "task-visualizer skill.md exists"
    else
        test_fail "task-visualizer skill.md does not exist"
    fi
}
test_task_visualizer_skill

# ============================================================================
# Summary
# ============================================================================

echo ""
echo "=============================================="
echo "v2.26 Test Suite Summary"
echo "=============================================="
echo -e "Passed: ${GREEN}$PASSED${NC}"
echo -e "Failed: ${RED}$FAILED${NC}"
echo -e "Total:  $TOTAL"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed.${NC}"
    exit 1
fi
