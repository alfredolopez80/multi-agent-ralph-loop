#!/bin/bash
#
# Skills Synchronization Validation Test Suite v2.87.0
# Validates sync between ~/.claude/skills, ~/backup/claude-skills, ~/.agents/skills
#
# Usage: ./tests/unit/test-skills-sync-v2.87.sh [-v]
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

# Configuration
GLOBAL_SKILLS="$HOME/.claude/skills"
BACKUP_SKILLS="$HOME/backup/claude-skills"
AGENTS_SKILLS="$HOME/.agents/skills"
VERBOSE=false

# Counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_WARNED=0

# Parse arguments
[[ "$1" == "-v" || "$1" == "--verbose" ]] && VERBOSE=true

pass() { ((TESTS_PASSED++)); printf "${GREEN}.${NC}"; }
fail() { ((TESTS_FAILED++)); printf "${RED}F${NC}"; }
warn() { ((TESTS_WARNED++)); printf "${YELLOW}W${NC}"; }

print_test() {
    if $VERBOSE; then
        echo -e "  Test: $1"
    fi
}

print_header() {
    echo -e "\n${BLUE}${BOLD}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}${BOLD}  $1${NC}"
    echo -e "${BLUE}${BOLD}═══════════════════════════════════════════════════════════════${NC}"
}

#######################################
# Test 1: Directory Structure
#######################################
test_directory_structure() {
    print_header "Test 1: Directory Structure"

    print_test "Global skills directory exists"
    [[ -d "$GLOBAL_SKILLS" ]] && pass || fail

    print_test "Backup directory exists"
    [[ -d "$BACKUP_SKILLS" ]] && pass || warn

    print_test "Agents directory exists"
    [[ -d "$AGENTS_SKILLS" ]] && pass || warn
}

#######################################
# Test 2: Ralph Skills (Symlinks to Repo)
#######################################
test_ralph_skills() {
    print_header "Test 2: Ralph Skills (Symlinks to Repo)"

    print_test "Ralph symlinks exist in global"
    local ralph_count=$(find "$GLOBAL_SKILLS" -maxdepth 1 -type l -exec readlink {} \; 2>/dev/null | grep -c "multi-agent-ralph-loop" || echo 0)
    if [[ $ralph_count -ge 30 ]]; then
        pass
        $VERBOSE && echo "    → Found $ralph_count Ralph symlinks"
    else
        warn; echo "  ⚠ Only $ralph_count Ralph symlinks (expected 30+)"
    fi

    print_test "Ralph symlinks point to valid directories"
    local broken=0
    for link in "$GLOBAL_SKILLS"/*; do
        if [[ -L "$link" ]]; then
            local target=$(readlink "$link")
            if [[ "$target" == *"multi-agent-ralph-loop"* ]] && [[ ! -d "$target" ]]; then
                ((broken++))
            fi
        fi
    done
    [[ $broken -eq 0 ]] && pass || fail
}

#######################################
# Test 3: External Skills (Real Directories)
#######################################
test_external_skills() {
    print_header "Test 3: External Skills (Real Directories)"

    print_test "External skills are real directories"
    local real_dirs=$(find "$GLOBAL_SKILLS" -maxdepth 1 -type d ! -name skills 2>/dev/null | wc -l | tr -d ' ')
    if [[ $real_dirs -ge 100 ]]; then
        pass
        $VERBOSE && echo "    → Found $real_dirs real directories"
    else
        warn; echo "  ⚠ Only $real_dirs real directories (expected 100+)"
    fi

    print_test "External skills have SKILL.md"
    local with_skill=0
    for dir in "$GLOBAL_SKILLS"/*/; do
        [[ -f "$dir/SKILL.md" ]] || [[ -f "$dir/skill.md" ]] && ((with_skill++))
    done
    if [[ $with_skill -ge 50 ]]; then
        pass
    else
        warn; echo "  ⚠ Only $with_skill have SKILL.md"
    fi
}

#######################################
# Test 4: Backup Sync
#######################################
test_backup_sync() {
    print_header "Test 4: Backup Sync"

    print_test "Backup has skills"
    local backup_count=$(ls "$BACKUP_SKILLS" 2>/dev/null | wc -l | tr -d ' ')
    if [[ $backup_count -ge 100 ]]; then
        pass
        $VERBOSE && echo "    → Backup has $backup_count skills"
    else
        warn; echo "  ⚠ Backup only has $backup_count skills"
    fi

    print_test "Backup skills are real directories"
    local backup_real=$(find "$BACKUP_SKILLS" -maxdepth 1 -type d ! -name claude-skills 2>/dev/null | wc -l | tr -d ' ')
    if [[ $backup_real -ge 100 ]]; then
        pass
    else
        warn
    fi
}

#######################################
# Test 5: Agents Sync
#######################################
test_agents_sync() {
    print_header "Test 5: ~/.agents/skills Sync"

    print_test "Agents symlinks exist"
    local agents_count=$(ls "$AGENTS_SKILLS" 2>/dev/null | wc -l | tr -d ' ')
    if [[ $agents_count -ge 100 ]]; then
        pass
        $VERBOSE && echo "    → Agents has $agents_count symlinks"
    else
        warn; echo "  ⚠ Agents only has $agents_count entries"
    fi

    print_test "Agents symlinks point to global"
    local correct=0
    local broken=0
    for link in "$AGENTS_SKILLS"/*; do
        if [[ -L "$link" ]]; then
            local target=$(readlink "$link")
            if [[ "$target" == "$GLOBAL_SKILLS"* ]]; then
                ((correct++))
            else
                ((broken++))
            fi
        fi
    done

    if [[ $broken -eq 0 ]] && [[ $correct -ge 50 ]]; then
        pass
    else
        warn; echo "  ⚠ $broken broken, $correct correct"
    fi
}

#######################################
# Test 6: Consistency Check
#######################################
test_consistency() {
    print_header "Test 6: Cross-Location Consistency"

    print_test "No broken symlinks in global"
    local broken=$(find "$GLOBAL_SKILLS" -maxdepth 1 -type l ! -exec test -e {} \; -print 2>/dev/null | wc -l | tr -d ' ')
    if [[ $broken -eq 0 ]]; then
        pass
    else
        warn; echo "  ⚠ $broken broken symlinks"
    fi

    print_test "No broken symlinks in agents"
    local agents_broken=$(find "$AGENTS_SKILLS" -maxdepth 1 -type l ! -exec test -e {} \; -print 2>/dev/null | wc -l | tr -d ' ')
    if [[ $agents_broken -eq 0 ]]; then
        pass
    else
        warn; echo "  ⚠ $agents_broken broken symlinks in agents"
    fi
}

#######################################
# Summary
#######################################
print_summary() {
    local total=$((TESTS_PASSED + TESTS_FAILED + TESTS_WARNED))

    echo -e "\n${BLUE}${BOLD}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}${BOLD}  TEST SUMMARY${NC}"
    echo -e "${BLUE}${BOLD}═══════════════════════════════════════════════════════════════${NC}"

    echo -e "\n  ${GREEN}Passed:${NC}   $TESTS_PASSED"
    echo -e "  ${RED}Failed:${NC}   $TESTS_FAILED"
    echo -e "  ${YELLOW}Warnings:${NC} $TESTS_WARNED"
    echo -e "  ${BOLD}Total:${NC}    $total"

    if [[ $total -gt 0 ]]; then
        local rate=$((TESTS_PASSED * 100 / total))
        echo -e "\n  ${BOLD}Pass Rate: ${rate}%${NC}"
    fi

    echo ""
    echo "Locations:"
    echo "  Global: $GLOBAL_SKILLS ($(ls $GLOBAL_SKILLS 2>/dev/null | wc -l | tr -d ' ') items)"
    echo "  Backup: $BACKUP_SKILLS ($(ls $BACKUP_SKILLS 2>/dev/null | wc -l | tr -d ' ') items)"
    echo "  Agents: $AGENTS_SKILLS ($(ls $AGENTS_SKILLS 2>/dev/null | wc -l | tr -d ' ') items)"

    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "\n${GREEN}${BOLD}✓ ALL TESTS PASSED${NC}"
        return 0
    else
        echo -e "\n${RED}${BOLD}✗ SOME TESTS FAILED${NC}"
        return 1
    fi
}

#######################################
# Main
#######################################
main() {
    echo -e "${BLUE}${BOLD}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}${BOLD}║     Skills Sync Validation Test Suite v2.87.0                ║${NC}"
    echo -e "${BLUE}${BOLD}╚═══════════════════════════════════════════════════════════════╝${NC}"

    test_directory_structure
    test_ralph_skills
    test_external_skills
    test_backup_sync
    test_agents_sync
    test_consistency

    print_summary
}

main "$@"
