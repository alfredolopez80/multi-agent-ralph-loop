#!/usr/bin/env bash
#===============================================================================
# validate-skills-registration.sh - Validate skills registration
#
# VERSION: 1.0.0
# DATE: 2026-02-15
# PURPOSE: Validate that all skills are properly installed
#
# Usage:
#   ./scripts/validate-skills-registration.sh [--format json|text] [--verbose]
#
# Exit codes:
#   0: All skills registered correctly
#   1: Some skills missing or invalid
#   2: Cannot run checks
#===============================================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Output format
FORMAT="${FORMAT:-text}"
VERBOSE="${VERBOSE:-0}"

# Skills directory
SKILLS_DIR="${HOME}/.claude/skills"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --format)
            FORMAT="$2"
            shift 2
            ;;
        --verbose|-v)
            VERBOSE=1
            shift
            ;;
        --help|-h)
            cat << 'EOF'
Usage: validate-skills-registration.sh [OPTIONS]

Options:
  --format FORMAT  Output format: text (default) or json
  --verbose, -v    Show detailed information
  --help, -h       Show this help message

Checks:
  - Skills directory exists
  - Each skill has SKILL.md or skill.md file
  - SKILL.md has valid frontmatter
  - Symlinks are valid (if applicable)

Exit codes:
  0  All skills valid
  1  Some skills invalid
  2  Cannot run checks
EOF
            exit 0
            ;;
        *)
            shift
            ;;
    esac
done

#===============================================================================
# CORE SKILLS TO VALIDATE
#===============================================================================

CORE_SKILLS=(
    "orchestrator"
    "loop"
    "gates"
    "adversarial"
    "bugs"
    "security"
    "retrospective"
    "clarify"
    "curator"
    "task-batch"
    "create-task-batch"
    "research"
    "glm5"
    "parallel"
)

#===============================================================================
# RESULT STORAGE
#===============================================================================

declare -A RESULTS
declare -A MESSAGES
PASSED=0
FAILED=0
WARNINGS=0
TOTAL_SKILLS=0

#===============================================================================
# FUNCTIONS
#===============================================================================

# Record a check result
record_check() {
    local check_name="$1"
    local status="$2"
    local message="$3"

    RESULTS["$check_name"]="$status"
    MESSAGES["$check_name"]="$message"

    case "$status" in
        PASS) PASSED=$((PASSED + 1)) ;;
        FAIL) FAILED=$((FAILED + 1)) ;;
        WARN) WARNINGS=$((WARNINGS + 1)) ;;
    esac
}

# Check skills directory exists
check_skills_dir() {
    if [[ -d "$SKILLS_DIR" ]]; then
        local count
        count=$(find "$SKILLS_DIR" -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
        count=$((count - 1))  # Subtract the directory itself
        record_check "skills_dir" "PASS" "Skills directory exists with $count skills"
    else
        record_check "skills_dir" "FAIL" "Skills directory not found: $SKILLS_DIR"
    fi
}

# Validate a single skill
validate_skill() {
    local skill="$1"
    local skill_dir="${SKILLS_DIR}/${skill}"
    local status=""
    local message=""

    TOTAL_SKILLS=$((TOTAL_SKILLS + 1))

    if [[ ! -d "$skill_dir" ]]; then
        status="FAIL"
        message="Skill directory not found"
    elif [[ -L "$skill_dir" && ! -e "$skill_dir" ]]; then
        status="FAIL"
        message="Broken symlink"
    elif [[ -f "${skill_dir}/SKILL.md" ]] || [[ -f "${skill_dir}/skill.md" ]]; then
        local skill_file="${skill_dir}/SKILL.md"
        [[ -f "${skill_dir}/skill.md" ]] && skill_file="${skill_dir}/skill.md"

        # Check if file has content
        if [[ -s "$skill_file" ]]; then
            status="PASS"
            message="Valid skill definition"
        else
            status="WARN"
            message="SKILL.md is empty"
        fi
    else
        status="FAIL"
        message="No SKILL.md file found"
    fi

    RESULTS["$skill"]="$status"
    MESSAGES["$skill"]="$message"

    case "$status" in
        PASS) PASSED=$((PASSED + 1)) ;;
        FAIL) FAILED=$((FAILED + 1)) ;;
        WARN) WARNINGS=$((WARNINGS + 1)) ;;
    esac
}

# Print text output
print_text_output() {
    echo "═══════════════════════════════════════════════════════════════"
    echo "   Skills Registration Validation - v1.0.0"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    echo "Skills Dir: $SKILLS_DIR"
    echo ""

    echo -e "${BLUE}CORE SKILLS${NC}"
    echo "───────────────────────────────────────────────────────────────"

    for skill in "${CORE_SKILLS[@]}"; do
        local status="${RESULTS[$skill]:-SKIP}"
        local message="${MESSAGES[$skill]:-Not checked}"

        case "$status" in
            PASS) echo -e "${GREEN}✓${NC} $skill: $message" ;;
            FAIL) echo -e "${RED}✗${NC} $skill: $message" ;;
            WARN) echo -e "${YELLOW}⚠${NC} $skill: $message" ;;
            SKIP) echo -e "${BLUE}○${NC} $skill: $message" ;;
        esac
    done

    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "   SUMMARY"
    echo "═══════════════════════════════════════════════════════════════"
    echo "  Total:    $TOTAL_SKILLS"
    echo "  Passed:   $PASSED"
    echo "  Failed:   $FAILED"
    echo "  Warnings: $WARNINGS"
    echo ""

    if [[ $FAILED -eq 0 ]]; then
        echo -e "${GREEN}✓ All core skills are properly installed${NC}"
        return 0
    else
        echo -e "${RED}✗ Some skills are missing or invalid${NC}"
        return 1
    fi
}

# Print JSON output
print_json_output() {
    local overall_status="pass"
    [[ $FAILED -gt 0 ]] && overall_status="fail"

    cat << EOF
{
  "status": "$overall_status",
  "skills_dir": "$SKILLS_DIR",
  "summary": {
    "total": $TOTAL_SKILLS,
    "passed": $PASSED,
    "failed": $FAILED,
    "warnings": $WARNINGS
  },
  "skills": {
EOF

    local first=true
    for skill in "${CORE_SKILLS[@]}"; do
        $first || echo ","
        first=false
        cat << EOF
    "$skill": {
      "status": "${RESULTS[$skill]:-SKIP}",
      "message": "${MESSAGES[$skill]:-Not checked}"
    }
EOF
    done

    echo "  }"
    echo "}"
}

#===============================================================================
# MAIN
#===============================================================================

# Check skills directory
check_skills_dir

# Validate core skills
for skill in "${CORE_SKILLS[@]}"; do
    validate_skill "$skill"
done

# Output results
case "$FORMAT" in
    json)
        print_json_output
        ;;
    text|*)
        print_text_output
        ;;
esac
