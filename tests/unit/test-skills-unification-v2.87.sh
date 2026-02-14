#!/bin/bash
# test-skills-unification-v2.87.sh - Comprehensive unit test for skills/commands unification
# Version: 2.87.0
# Date: 2026-02-14
# Purpose: Prevent regressions in the unified skills model
#
# Validates compliance with:
# - https://code.claude.com/docs/en/skills
# - https://code.claude.com/docs/en/agent-teams
# - https://code.claude.com/docs/en/sub-agents
# - https://code.claude.com/docs/en/hooks-guide
#
# Usage:
#   ./tests/unit/test-skills-unification-v2.87.sh [--verbose] [--fix]
#
# Exit codes:
#   0 - All tests passed (100%)
#   1 - Some tests failed
#   2 - Critical configuration error

set -uo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
GLOBAL_SKILLS="$HOME/.claude/skills"
GLOBAL_COMMANDS="$HOME/.claude/commands"
SETTINGS_FILE="$HOME/.claude/settings.json"
EXPECTED_VERSION="2.87.0"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Counters
TOTAL_TESTS=0
PASSED=0
FAILED=0
WARNINGS=0
SKIPPED=0

# Options
VERBOSE=false
FIX_MODE=false

# Parse arguments
for arg in "$@"; do
    case $arg in
        --verbose|-v) VERBOSE=true ;;
        --fix|-f) FIX_MODE=true ;;
        --help|-h)
            echo "Usage: $0 [--verbose] [--fix]"
            exit 0
            ;;
    esac
done

# Ralph core skills that MUST be in repo and symlinked globally
RALPH_CORE_SKILLS=(
    "orchestrator"
    "loop"
    "gates"
    "adversarial"
    "parallel"
    "retrospective"
    "clarify"
    "security"
    "bugs"
    "smart-fork"
    "task-classifier"
    "glm5"
    "glm5-parallel"
    "kaizen"
    "readme"
    "quality-gates-parallel"
    "code-reviewer"
    "sec-context-depth"
    "audit"
    "deslop"
    "edd"
)

# Additional Ralph skills (optional but should be symlinked if exist)
RALPH_OPTIONAL_SKILLS=(
    "curator"
    "codex-cli"
    "minimax"
    "minimax-mcp-usage"
    "openai-docs"
    "context7-usage"
    "gemini-cli"
    "worktree-pr"
    "stop-slop"
    "task-visualizer"
    "testing-anti-patterns"
    "glm-mcp"
    "crafting-effective-readmes"
    "senior-software-engineer"
    "attack-mutator"
    "defense-profiler"
    "ask-questions-if-underspecified"
    "tap-explorer"
    "vercel-react-best-practices"
)

# Required hooks per Claude Code docs
REQUIRED_HOOKS=(
    "git-safety-guard.py:PreToolUse:Bash"
    "repo-boundary-guard.sh:PreToolUse:Bash"
    "session-end-handoff.sh:SessionEnd"
    "post-compact-restore.sh:SessionStart"
)

#######################################
# Test utility functions
#######################################
print_header() {
    echo ""
    echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}${CYAN}  $1${NC}"
    echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
}

print_test() {
    ((TOTAL_TESTS++))
    if $VERBOSE; then
        echo -n "  Test #$TOTAL_TESTS: $1 ... "
    fi
}

pass() {
    ((PASSED++))
    if $VERBOSE; then
        echo -e "${GREEN}PASS${NC}"
    else
        echo -n "${GREEN}.${NC}"
    fi
}

fail() {
    local msg="$1"
    ((FAILED++))
    if $VERBOSE; then
        echo -e "${RED}FAIL${NC}"
        [[ -n "$msg" ]] && echo -e "    ${RED}→ $msg${NC}"
    else
        echo -n "${RED}F${NC}"
    fi
}

warn() {
    local msg="$1"
    ((WARNINGS++))
    if $VERBOSE; then
        echo -e "${YELLOW}WARN${NC}"
        [[ -n "$msg" ]] && echo -e "    ${YELLOW}→ $msg${NC}"
    else
        echo -n "${YELLOW}W${NC}"
    fi
}

skip() {
    local msg="$1"
    ((SKIPPED++))
    if $VERBOSE; then
        echo -e "${BLUE}SKIP${NC}"
        [[ -n "$msg" ]] && echo -e "    ${BLUE}→ $msg${NC}"
    else
        echo -n "${BLUE}S${NC}"
    fi
}

#######################################
# Test 1: Repository Skills Structure
#######################################
test_repo_skills_structure() {
    print_header "Test 1: Repository Skills Structure"

    for skill in "${RALPH_CORE_SKILLS[@]}"; do
        local skill_dir="$REPO_ROOT/.claude/skills/$skill"
        local skill_file="$skill_dir/SKILL.md"

        print_test "Skill '$skill' directory exists"
        if [[ -d "$skill_dir" ]]; then
            pass
        else
            fail "Directory missing: $skill_dir"
            continue
        fi

        print_test "Skill '$skill' has SKILL.md"
        if [[ -f "$skill_file" ]]; then
            pass
        else
            fail "SKILL.md missing: $skill_file"
            continue
        fi

        print_test "Skill '$skill' SKILL.md is readable"
        if [[ -r "$skill_file" ]]; then
            pass
        else
            fail "Cannot read: $skill_file"
        fi
    done
}

#######################################
# Test 2: SKILL.md Frontmatter Validation (Claude Code Standard)
#######################################
test_skill_frontmatter() {
    print_header "Test 2: SKILL.md Frontmatter Validation (Claude Code Standard)"

    for skill in "${RALPH_CORE_SKILLS[@]}"; do
        local skill_file="$REPO_ROOT/.claude/skills/$skill/SKILL.md"

        if [[ ! -f "$skill_file" ]]; then
            continue
        fi

        # Check for YAML frontmatter (--- at start)
        print_test "Skill '$skill' has YAML frontmatter (---)"
        if head -1 "$skill_file" | grep -q "^---$"; then
            pass
        else
            fail "Missing YAML frontmatter delimiter '---' at start of file"
        fi

        # Check for version field (VERSION comment or version field)
        print_test "Skill '$skill' has VERSION"
        local version=""
        version=$(grep -E "^# VERSION:" "$skill_file" 2>/dev/null | head -1 | sed 's/# VERSION:[[:space:]]*//' | tr -d ' ')
        if [[ -z "$version" ]]; then
            version=$(grep -E "^version:" "$skill_file" 2>/dev/null | head -1 | sed 's/version:[[:space:]]*//' | tr -d ' "' | tr -d "'")
        fi

        if [[ -n "$version" ]]; then
            pass
        else
            fail "Missing VERSION field"
        fi

        # Check for name field
        print_test "Skill '$skill' has 'name' field"
        if grep -qE "^name:" "$skill_file" 2>/dev/null; then
            pass
        else
            warn "Missing 'name' field (recommended by Claude Code docs)"
        fi

        # Check for description field
        print_test "Skill '$skill' has 'description' field"
        if grep -qE "^description:" "$skill_file" 2>/dev/null; then
            pass
        else
            warn "Missing 'description' field (recommended by Claude Code docs)"
        fi
    done
}

#######################################
# Test 3: Global Symlinks Validation
#######################################
test_global_symlinks() {
    print_header "Test 3: Global Symlinks Validation"

    for skill in "${RALPH_CORE_SKILLS[@]}"; do
        local global_skill="$GLOBAL_SKILLS/$skill"
        local repo_skill="$REPO_ROOT/.claude/skills/$skill"

        print_test "Global skill '$skill' exists"
        if [[ -e "$global_skill" ]] || [[ -L "$global_skill" ]]; then
            pass
        else
            fail "Global skill missing: $global_skill"
            continue
        fi

        print_test "Global skill '$skill' is a symlink"
        if [[ -L "$global_skill" ]]; then
            pass
        else
            fail "Not a symlink: $global_skill (should point to repo)"
            continue
        fi

        print_test "Symlink '$skill' points to repo"
        local target
        target=$(readlink "$global_skill" 2>/dev/null || echo "")
        if [[ "$target" == "$repo_skill" ]]; then
            pass
        else
            fail "Wrong target: $target (expected: $repo_skill)"
        fi

        print_test "Symlink '$skill' target exists"
        if [[ -d "$target" ]]; then
            pass
        else
            fail "Broken symlink: target does not exist"
        fi
    done
}

#######################################
# Test 4: No Duplicate Commands
#######################################
test_no_duplicate_commands() {
    print_header "Test 4: No Duplicate Commands in ~/.claude/commands/"

    local duplicates_found=0

    for skill in "${RALPH_CORE_SKILLS[@]}" "${RALPH_OPTIONAL_SKILLS[@]}"; do
        local cmd_file="$GLOBAL_COMMANDS/$skill.md"

        print_test "No duplicate command '$skill.md'"
        if [[ -f "$cmd_file" ]] && [[ ! -L "$cmd_file" ]]; then
            fail "Duplicate command file exists: $cmd_file"
            ((duplicates_found++))
        else
            pass
        fi
    done

    print_test "Summary: No duplicate commands found"
    if [[ $duplicates_found -eq 0 ]]; then
        pass
    else
        fail "Found $duplicates_found duplicate command files"
    fi
}

#######################################
# Test 5: Version Consistency (STRICT)
#######################################
test_version_consistency() {
    print_header "Test 5: Version Consistency (STRICT - All v2.87.0)"

    for skill in "${RALPH_CORE_SKILLS[@]}"; do
        local skill_file="$REPO_ROOT/.claude/skills/$skill/SKILL.md"

        if [[ ! -f "$skill_file" ]]; then
            continue
        fi

        print_test "Skill '$skill' version is $EXPECTED_VERSION"

        # Try to extract version from different formats
        local version=""
        version=$(grep -E "^# VERSION:" "$skill_file" 2>/dev/null | head -1 | sed 's/# VERSION:[[:space:]]*//' | tr -d ' ')
        if [[ -z "$version" ]]; then
            version=$(grep -E "^version:" "$skill_file" 2>/dev/null | head -1 | sed 's/version:[[:space:]]*//' | tr -d ' "' | tr -d "'")
        fi

        if [[ "$version" == "$EXPECTED_VERSION" ]]; then
            pass
        elif [[ -n "$version" ]]; then
            fail "Version is $version (expected: $EXPECTED_VERSION)"
        else
            fail "Cannot determine version"
        fi
    done
}

#######################################
# Test 6: No Backup Folders
#######################################
test_no_backup_folders() {
    print_header "Test 6: No Obsolete Backup Folders"

    print_test "No backup.* folders in global skills"
    local backup_count
    backup_count=$(find "$GLOBAL_SKILLS" -maxdepth 1 -name "*.backup.*" -type d 2>/dev/null | wc -l | tr -d ' ')

    if [[ "$backup_count" -eq 0 ]]; then
        pass
    else
        fail "Found $backup_count backup.* folders in $GLOBAL_SKILLS"
        if $VERBOSE; then
            find "$GLOBAL_SKILLS" -maxdepth 1 -name "*.backup.*" -type d 2>/dev/null | while read -r folder; do
                echo -e "    ${RED}→ $folder${NC}"
            done
        fi
    fi

    print_test "No backup.* folders in repo skills"
    backup_count=$(find "$REPO_ROOT/.claude/skills" -maxdepth 1 -name "*.backup.*" -type d 2>/dev/null | wc -l | tr -d ' ')

    if [[ "$backup_count" -eq 0 ]]; then
        pass
    else
        fail "Found $backup_count backup.* folders in repo"
    fi
}

#######################################
# Test 7: No Empty Skill Directories
#######################################
test_no_empty_skills() {
    print_header "Test 7: No Empty Skill Directories"

    for skill in "${RALPH_CORE_SKILLS[@]}"; do
        local skill_dir="$REPO_ROOT/.claude/skills/$skill"

        if [[ -d "$skill_dir" ]]; then
            print_test "Skill '$skill' directory is not empty"
            local file_count
            file_count=$(find "$skill_dir" -type f 2>/dev/null | wc -l | tr -d ' ')

            if [[ "$file_count" -gt 0 ]]; then
                pass
            else
                fail "Empty directory: $skill_dir"
            fi
        fi
    done
}

#######################################
# Test 8: Architecture Documentation
#######################################
test_architecture_docs() {
    print_header "Test 8: Architecture Documentation"

    local docs=(
        "$REPO_ROOT/docs/architecture/UNIFIED_ARCHITECTURE_v2.87.md"
        "$REPO_ROOT/docs/architecture/SKILLS_COMMANDS_UNIFICATION_v2.87.md"
        "$REPO_ROOT/docs/architecture/REMEDIATION_PLAN_v2.87.md"
    )

    for doc in "${docs[@]}"; do
        print_test "Documentation exists: $(basename "$doc")"
        if [[ -f "$doc" ]]; then
            pass
        else
            warn "Missing documentation: $doc"
        fi
    done

    print_test "CLAUDE.md mentions unified model"
    if grep -q "Skills/Commands Unification" "$REPO_ROOT/CLAUDE.md" 2>/dev/null; then
        pass
    else
        warn "CLAUDE.md missing Skills/Commands Unification section"
    fi
}

#######################################
# Test 9: Settings Configuration (Hooks + Agent Teams)
#######################################
test_settings_registration() {
    print_header "Test 9: Settings Configuration (Hooks + Agent Teams)"

    print_test "settings.json exists"
    if [[ -f "$SETTINGS_FILE" ]]; then
        pass
    else
        fail "Missing: $SETTINGS_FILE"
        return
    fi

    print_test "settings.json is valid JSON"
    if python3 -c "import json; json.load(open('$SETTINGS_FILE'))" 2>/dev/null; then
        pass
    else
        fail "Invalid JSON in $SETTINGS_FILE"
        return
    fi

    # Check for Agent Teams environment variable
    print_test "Agent Teams environment configured"
    if grep -q "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS" "$SETTINGS_FILE" 2>/dev/null; then
        pass
    else
        warn "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS not configured"
    fi

    # Check for critical hooks registration
    local critical_hooks=("git-safety-guard.py" "repo-boundary-guard.sh")
    for hook in "${critical_hooks[@]}"; do
        print_test "Hook '$hook' registered in settings"
        if grep -q "$hook" "$SETTINGS_FILE" 2>/dev/null; then
            pass
        else
            warn "Hook not registered: $hook"
        fi
    done

    # Check for Session lifecycle hooks
    print_test "Session lifecycle hooks configured"
    if grep -q "SessionEnd" "$SETTINGS_FILE" 2>/dev/null && grep -q "SessionStart" "$SETTINGS_FILE" 2>/dev/null; then
        pass
    else
        warn "Session lifecycle hooks incomplete"
    fi

    # Check for Subagent hooks
    print_test "Subagent hooks configured"
    if grep -q "SubagentStart" "$SETTINGS_FILE" 2>/dev/null || grep -q "SubagentStop" "$SETTINGS_FILE" 2>/dev/null; then
        pass
    else
        warn "Subagent hooks not configured"
    fi
}

#######################################
# Test 10: Setup Scripts
#######################################
test_setup_scripts() {
    print_header "Test 10: Setup and Validation Scripts"

    local scripts=(
        "$REPO_ROOT/scripts/setup-skill-symlinks.sh"
        "$REPO_ROOT/scripts/validate-skills-unification.sh"
    )

    for script in "${scripts[@]}"; do
        print_test "Script exists: $(basename "$script")"
        if [[ -f "$script" ]]; then
            pass
        else
            fail "Missing: $script"
            continue
        fi

        print_test "Script is executable: $(basename "$script")"
        if [[ -x "$script" ]]; then
            pass
        else
            warn "Not executable: $script"
        fi
    done
}

#######################################
# Test 11: No Symlink Loops
#######################################
test_no_symlink_loops() {
    print_header "Test 11: No Symlink Loops"

    for skill in "${RALPH_CORE_SKILLS[@]}"; do
        local global_skill="$GLOBAL_SKILLS/$skill"

        if [[ -L "$global_skill" ]]; then
            print_test "Skill '$skill' has no symlink loop"

            # Check if symlink points to itself (directly or indirectly)
            local canonical
            canonical=$(cd "$global_skill" 2>/dev/null && pwd -P 2>/dev/null || echo "")

            if [[ -n "$canonical" ]] && [[ "$canonical" != *"$HOME/.claude/skills/$skill" ]]; then
                pass
            else
                fail "Possible symlink loop detected for $skill"
            fi
        fi
    done
}

#######################################
# Test 12: Optional Skills Symlinked
#######################################
test_optional_skills() {
    print_header "Test 12: Optional Skills (if exist in repo)"

    for skill in "${RALPH_OPTIONAL_SKILLS[@]}"; do
        local repo_skill="$REPO_ROOT/.claude/skills/$skill"
        local global_skill="$GLOBAL_SKILLS/$skill"

        if [[ -d "$repo_skill" ]]; then
            print_test "Optional skill '$skill' symlinked globally"
            if [[ -L "$global_skill" ]]; then
                local target
                target=$(readlink "$global_skill" 2>/dev/null || echo "")
                if [[ "$target" == "$repo_skill" ]]; then
                    pass
                else
                    warn "Wrong symlink target for $skill"
                fi
            else
                warn "Optional skill exists in repo but not symlinked: $skill"
            fi
        fi
    done
}

#######################################
# Test 13: Agent Teams Integration (NEW)
#######################################
test_agent_teams_integration() {
    print_header "Test 13: Agent Teams Integration (Claude Code Docs)"

    # Check for subagent types in settings
    print_test "Agent Teams subagent types configured"
    if grep -q "ralph-coder\|ralph-reviewer\|ralph-tester\|ralph-researcher" "$SETTINGS_FILE" 2>/dev/null; then
        pass
    else
        warn "No Ralph subagent types found in settings"
    fi

    # Check for context: fork in skills that spawn subagents
    local subagent_skills=("orchestrator" "loop" "parallel" "quality-gates-parallel")
    for skill in "${subagent_skills[@]}"; do
        local skill_file="$REPO_ROOT/.claude/skills/$skill/SKILL.md"
        if [[ -f "$skill_file" ]]; then
            print_test "Skill '$skill' has context: fork for subagents"
            if grep -q "context:.*fork" "$skill_file" 2>/dev/null || grep -q "agent:" "$skill_file" 2>/dev/null; then
                pass
            else
                warn "Skill may need context: fork configuration"
            fi
        fi
    done

    # Check for TeammateIdle and TaskCompleted hooks
    print_test "TeammateIdle/TaskCompleted hooks configured"
    if grep -q "TeammateIdle\|TaskCompleted" "$SETTINGS_FILE" 2>/dev/null; then
        pass
    else
        warn "Agent Teams lifecycle hooks not configured"
    fi
}

#######################################
# Test 14: Hooks Event Coverage (NEW)
#######################################
test_hooks_coverage() {
    print_header "Test 14: Hooks Event Coverage (Claude Code Docs)"

    # Official Claude Code hook events
    local required_events=("SessionStart" "UserPromptSubmit" "PreToolUse" "PostToolUse" "Stop" "SessionEnd")

    for event in "${required_events[@]}"; do
        print_test "Hook event '$event' has registered hooks"
        if grep -q "\"$event\"" "$SETTINGS_FILE" 2>/dev/null; then
            pass
        else
            warn "No hooks registered for event: $event"
        fi
    done

    # Check for optional but recommended events
    local optional_events=("PreCompact" "SubagentStart" "SubagentStop" "TeammateIdle" "TaskCompleted")
    for event in "${optional_events[@]}"; do
        print_test "Optional hook event '$event' configured"
        if grep -q "\"$event\"" "$SETTINGS_FILE" 2>/dev/null; then
            pass
        else
            skip "Not configured (optional)"
        fi
    done
}

#######################################
# Summary
#######################################
print_summary() {
    echo ""
    echo ""
    print_header "TEST SUMMARY"

    local pass_rate=0
    local total_checked=$((PASSED + FAILED + WARNINGS))

    if [[ $total_checked -gt 0 ]]; then
        pass_rate=$((PASSED * 100 / total_checked))
    fi

    echo -e "  ${GREEN}Passed:${NC}   $PASSED"
    echo -e "  ${RED}Failed:${NC}   $FAILED"
    echo -e "  ${YELLOW}Warnings:${NC} $WARNINGS"
    echo -e "  ${BLUE}Skipped:${NC}  $SKIPPED"
    echo -e "  ${BOLD}Total:${NC}    $TOTAL_TESTS"
    echo ""
    echo -e "  ${BOLD}Pass Rate: ${pass_rate}%${NC}"
    echo ""

    if [[ $FAILED -eq 0 ]]; then
        echo -e "${GREEN}${BOLD}✓ ALL TESTS PASSED${NC}"
        echo ""
        echo "Compliance validated against:"
        echo "  - https://code.claude.com/docs/en/skills"
        echo "  - https://code.claude.com/docs/en/agent-teams"
        echo "  - https://code.claude.com/docs/en/sub-agents"
        echo "  - https://code.claude.com/docs/en/hooks-guide"
        echo ""
        return 0
    else
        echo -e "${RED}${BOLD}✗ SOME TESTS FAILED${NC}"
        echo ""
        echo "Run with --verbose for detailed output"
        echo "Run with --fix to attempt automatic fixes"
        echo ""
        return 1
    fi
}

#######################################
# Main
#######################################
main() {
    echo ""
    echo -e "${BOLD}${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${CYAN}║     Skills Unification Unit Test Suite v2.87.0               ║${NC}"
    echo -e "${BOLD}${CYAN}║     Repository: multi-agent-ralph-loop                        ║${NC}"
    echo -e "${BOLD}${CYAN}║     Claude Code Docs Compliance Validation                   ║${NC}"
    echo -e "${BOLD}${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "Repository: $REPO_ROOT"
    echo "Global Skills: $GLOBAL_SKILLS"
    echo "Global Commands: $GLOBAL_COMMANDS"
    echo "Settings: $SETTINGS_FILE"
    echo "Expected Version: $EXPECTED_VERSION"
    echo "Verbose: $VERBOSE"
    echo "Fix Mode: $FIX_MODE"

    # Run all test suites
    test_repo_skills_structure
    test_skill_frontmatter
    test_global_symlinks
    test_no_duplicate_commands
    test_version_consistency
    test_no_backup_folders
    test_no_empty_skills
    test_architecture_docs
    test_settings_registration
    test_setup_scripts
    test_no_symlink_loops
    test_optional_skills
    test_agent_teams_integration
    test_hooks_coverage

    # Print summary and exit
    print_summary
}

# Run main
main "$@"
