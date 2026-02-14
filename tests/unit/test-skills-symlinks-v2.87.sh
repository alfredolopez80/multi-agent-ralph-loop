#!/bin/bash
#
# Skills Symlink Validation Test Suite v2.87.0
# Validates that Ralph skills are in repo and symlinked globally
# Ensures external skills (~1800) remain accessible
#
# Usage: ./tests/unit/test-skills-symlinks-v2.87.sh [-v] [-f]
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
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
REPO_SKILLS="$REPO_ROOT/.claude/skills"
GLOBAL_SKILLS="$HOME/.claude/skills"
EXPECTED_VERSION="2.87.0"
VERBOSE=false
FIX_MODE=false

# Counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_WARNED=0

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--verbose) VERBOSE=true; shift ;;
        -f|--fix) FIX_MODE=true; shift ;;
        *) shift ;;
    esac
done

# Helper functions
pass() { ((TESTS_PASSED++)); printf "${GREEN}.${NC}"; }
fail() { ((TESTS_FAILED++)); printf "${RED}F${NC}"; }
warn() { ((TESTS_WARNED++)); printf "${YELLOW}W${NC}"; }

print_header() {
    echo -e "\n${BLUE}${BOLD}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}${BOLD}  $1${NC}"
    echo -e "${BLUE}${BOLD}═══════════════════════════════════════════════════════════════${NC}"
}

print_test() {
    if $VERBOSE; then
        echo -e "  Test: $1"
    fi
}

#######################################
# Test 1: Repository Skills Structure
#######################################
test_repo_skills_structure() {
    print_header "Test 1: Repository Skills Structure"

    # Check repo skills directory exists
    print_test "Repository skills directory exists"
    if [[ -d "$REPO_SKILLS" ]]; then
        pass
    else
        fail; echo "  ✗ Repository skills directory not found: $REPO_SKILLS"
    fi

    # Count skills with SKILL.md
    print_test "Skills with SKILL.md in repo"
    local skill_count=$(find "$REPO_SKILLS" -maxdepth 2 -name "SKILL.md" -o -name "skill.md" 2>/dev/null | wc -l | tr -d ' ')
    if [[ $skill_count -ge 30 ]]; then
        pass
        if $VERBOSE; then echo "    → Found $skill_count skills"; fi
    else
        warn; echo "  ⚠ Only $skill_count skills found (expected 30+)"
    fi

    # Check for valid SKILL.md files
    print_test "All skills have valid frontmatter"
    local invalid=0
    for skill_dir in "$REPO_SKILLS"/*/; do
        if [[ -f "$skill_dir/SKILL.md" ]] || [[ -f "$skill_dir/skill.md" ]]; then
            local skill_file="${skill_dir}SKILL.md"
            [[ -f "$skill_file" ]] || skill_file="${skill_dir}skill.md"
            if ! head -5 "$skill_file" | grep -q "^---"; then
                ((invalid++))
            fi
        fi
    done
    if [[ $invalid -eq 0 ]]; then
        pass
    else
        warn; echo "  ⚠ $invalid skills have invalid frontmatter"
    fi
}

#######################################
# Test 2: Global Symlinks to Repo
#######################################
test_global_symlinks() {
    print_header "Test 2: Global Symlinks to Repo Skills"

    # Check global skills directory exists
    print_test "Global skills directory exists"
    if [[ -d "$GLOBAL_SKILLS" ]]; then
        pass
    else
        fail; echo "  ✗ Global skills directory not found: $GLOBAL_SKILLS"
    fi

    # Count symlinks pointing to repo
    print_test "Symlinks pointing to Ralph repo"
    local repo_symlinks=$(find "$GLOBAL_SKILLS" -maxdepth 1 -type l -exec readlink {} \; 2>/dev/null | grep "multi-agent-ralph-loop" | wc -l | tr -d ' ')
    if [[ $repo_symlinks -ge 30 ]]; then
        pass
        if $VERBOSE; then echo "    → Found $repo_symlinks symlinks to repo"; fi
    else
        warn; echo "  ⚠ Only $repo_symlinks symlinks to repo (expected 30+)"
    fi

    # Verify all repo skills are symlinked
    print_test "All repo skills have symlinks in global"
    local missing_symlinks=0
    for skill_dir in "$REPO_SKILLS"/*/; do
        local skill_name=$(basename "$skill_dir")
        if [[ ! -L "$GLOBAL_SKILLS/$skill_name" ]]; then
            ((missing_symlinks++))
            if $VERBOSE; then echo "    ⚠ Missing symlink: $skill_name"; fi
        fi
    done

    if [[ $missing_symlinks -eq 0 ]]; then
        pass
    else
        if $FIX_MODE; then
            echo -e "\n${YELLOW}  Creating missing symlinks...${NC}"
            for skill_dir in "$REPO_SKILLS"/*/; do
                local skill_name=$(basename "$skill_dir")
                if [[ ! -L "$GLOBAL_SKILLS/$skill_name" ]] && [[ ! -e "$GLOBAL_SKILLS/$skill_name" ]]; then
                    ln -s "$skill_dir" "$GLOBAL_SKILLS/$skill_name"
                    echo "    ✓ Created: $skill_name"
                fi
            done
            pass
        else
            warn; echo "  ⚠ $missing_symlinks skills missing symlinks (run with -f to fix)"
        fi
    fi
}

#######################################
# Test 3: External Skills Preserved
#######################################
test_external_skills() {
    print_header "Test 3: External Skills Preserved (~1800)"

    # Count external symlinks (not pointing to repo)
    print_test "External skills accessible"
    local external_symlinks=$(find "$GLOBAL_SKILLS" -maxdepth 1 -type l -exec readlink {} \; 2>/dev/null | grep -v "multi-agent-ralph-loop" | wc -l | tr -d ' ')
    if [[ $external_symlinks -ge 1000 ]]; then
        pass
        if $VERBOSE; then echo "    → Found $external_symlinks external skills"; fi
    else
        warn; echo "  ⚠ Only $external_symlinks external skills (expected 1000+)"
    fi

    # Check some known external skills exist
    print_test "Sample external skills accessible"
    local sample_skills=("content-research-writer" "senior-frontend" "backend-development" "security")
    local found=0
    for skill in "${sample_skills[@]}"; do
        if [[ -L "$GLOBAL_SKILLS/$skill" ]] || [[ -d "$GLOBAL_SKILLS/$skill" ]]; then
            ((found++))
        fi
    done
    if [[ $found -ge 2 ]]; then
        pass
    else
        warn; echo "  ⚠ Only $found/4 sample skills found"
    fi
}

#######################################
# Test 4: Symlink Integrity
#######################################
test_symlink_integrity() {
    print_header "Test 4: Symlink Integrity"

    # Check for broken symlinks (only Ralph skills, ignore external)
    print_test "No broken Ralph symlinks in global"
    local broken=$(find "$GLOBAL_SKILLS" -maxdepth 1 -type l -exec sh -c 'readlink "$1" | grep -q "multi-agent-ralph-loop" && [ ! -d "$(readlink "$1")" ] && echo "$1"' _ {} \; 2>/dev/null | wc -l | tr -d ' ')
    if [[ $broken -eq 0 ]]; then
        pass
    else
        warn; echo "  ⚠ $broken broken Ralph symlinks found"
        if $VERBOSE; then
            find "$GLOBAL_SKILLS" -maxdepth 1 -type l -exec sh -c 'readlink "$1" | grep -q "multi-agent-ralph-loop" && [ ! -d "$(readlink "$1")" ] && echo "$1"' _ {} \; 2>/dev/null | head -5
        fi
    fi

    # Check symlinks point to correct targets
    print_test "Repo symlinks point to valid paths"
    local invalid_targets=0
    for link in "$GLOBAL_SKILLS"/*; do
        if [[ -L "$link" ]]; then
            local target=$(readlink "$link")
            if [[ "$target" == *"multi-agent-ralph-loop"* ]]; then
                if [[ ! -d "$target" ]]; then
                    ((invalid_targets++))
                fi
            fi
        fi
    done
    if [[ $invalid_targets -eq 0 ]]; then
        pass
    else
        fail; echo "  ✗ $invalid_targets symlinks point to non-existent directories"
    fi

    # No symlink loops (only check Ralph skills)
    print_test "No symlink loops in Ralph skills"
    local loops=0
    for link in "$GLOBAL_SKILLS"/*; do
        if [[ -L "$link" ]]; then
            local target=$(readlink "$link" 2>/dev/null)
            if [[ "$target" == *"multi-agent-ralph-loop"* ]]; then
                if [[ "$link" -ef "$(readlink -f "$link" 2>/dev/null)" ]]; then
                    ((loops++))
                fi
            fi
        fi
    done 2>/dev/null
    if [[ $loops -eq 0 ]]; then
        pass
    else
        warn; echo "  ⚠ $loops potential symlink loops"
    fi
}

#######################################
# Test 5: Version Consistency
#######################################
test_version_consistency() {
    print_header "Test 5: Ralph Skills Version Consistency"

    print_test "All Ralph skills have VERSION $EXPECTED_VERSION"
    local wrong_version=0
    local missing_version=0

    for skill_dir in "$REPO_SKILLS"/*/; do
        local skill_file="${skill_dir}SKILL.md"
        [[ -f "$skill_file" ]] || skill_file="${skill_dir}skill.md"

        if [[ -f "$skill_file" ]]; then
            local version=$(grep -m1 "# VERSION:" "$skill_file" 2>/dev/null | sed 's/.*VERSION: *//' | tr -d ' ')
            if [[ -z "$version" ]]; then
                ((missing_version++))
            elif [[ "$version" != "$EXPECTED_VERSION" ]]; then
                ((wrong_version++))
                if $VERBOSE; then echo "    ⚠ $(basename $skill_dir): $version"; fi
            fi
        fi
    done

    if [[ $wrong_version -eq 0 ]] && [[ $missing_version -eq 0 ]]; then
        pass
    elif [[ $wrong_version -gt 0 ]]; then
        warn; echo "  ⚠ $wrong_version skills with wrong version"
    else
        warn; echo "  ⚠ $missing_version skills missing version"
    fi
}

#######################################
# Test 6: Setup Script
#######################################
test_setup_script() {
    print_header "Test 6: Setup and Maintenance Scripts"

    print_test "Symlink setup script exists"
    if [[ -f "$REPO_ROOT/scripts/setup-skills-symlinks.sh" ]]; then
        pass
    else
        warn; echo "  ⚠ setup-skills-symlinks.sh not found"
    fi

    print_test "Setup script is executable"
    if [[ -x "$REPO_ROOT/scripts/setup-skills-symlinks.sh" ]]; then
        pass
    else
        warn; echo "  ⚠ Setup script not executable"
    fi
}

#######################################
# Summary
#######################################
print_summary() {
    echo -e "\n${BLUE}${BOLD}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}${BOLD}  TEST SUMMARY${NC}"
    echo -e "${BLUE}${BOLD}═══════════════════════════════════════════════════════════════${NC}"

    local total=$((TESTS_PASSED + TESTS_FAILED + TESTS_WARNED))

    echo -e "\n  ${GREEN}Passed:${NC}   $TESTS_PASSED"
    echo -e "  ${RED}Failed:${NC}   $TESTS_FAILED"
    echo -e "  ${YELLOW}Warnings:${NC} $TESTS_WARNED"
    echo -e "  ${BOLD}Total:${NC}    $total"

    if [[ $total -gt 0 ]]; then
        local rate=$((TESTS_PASSED * 100 / total))
        echo -e "\n  ${BOLD}Pass Rate: ${rate}%${NC}"
    fi

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
    echo -e "${BLUE}${BOLD}║     Skills Symlink Validation Test Suite v2.87.0             ║${NC}"
    echo -e "${BLUE}${BOLD}║     Repository: multi-agent-ralph-loop                       ║${NC}"
    echo -e "${BLUE}${BOLD}║     Global: ~/.claude/skills                                 ║${NC}"
    echo -e "${BLUE}${BOLD}╚═══════════════════════════════════════════════════════════════╝${NC}"

    echo -e "\nRepository: $REPO_ROOT"
    echo -e "Repo Skills: $REPO_SKILLS"
    echo -e "Global Skills: $GLOBAL_SKILLS"
    echo -e "Expected Version: $EXPECTED_VERSION"
    echo -e "Verbose: $VERBOSE"
    echo -e "Fix Mode: $FIX_MODE"

    test_repo_skills_structure
    test_global_symlinks
    test_external_skills
    test_symlink_integrity
    test_version_consistency
    test_setup_script

    print_summary
}

main "$@"
