#!/usr/bin/env bash
#===============================================================================
# validate-skills-execution.sh - Validate skills execution and dependencies
#
# VERSION: 1.0.0
# DATE: 2026-02-15
# PURPOSE: Validate that all skills load correctly, have valid descriptions,
#          and have no circular dependencies
#
# Usage:
#   ./scripts/validate-skills-execution.sh [--format json|text] [--verbose]
#
# Exit codes:
#   0: All skills validated successfully
#   1: Some skills failed validation
#   2: Cannot run checks
#===============================================================================

set -uo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Output format
FORMAT="${FORMAT:-text}"
VERBOSE="${VERBOSE:-0}"

# Detect project root
detect_project_root() {
    local root
    root="$(git rev-parse --show-toplevel 2>/dev/null)" || root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    echo "$root"
}

PROJECT_ROOT="$(detect_project_root)"
GLOBAL_SKILLS_DIR="${HOME}/.claude/skills"
PROJECT_SKILLS_DIR="${PROJECT_ROOT}/.claude/skills"

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
Usage: validate-skills-execution.sh [OPTIONS]

Options:
  --format FORMAT  Output format: text (default) or json
  --verbose, -v    Show detailed information
  --help, -h       Show this help message

Checks:
  - Skills directory exists
  - Each skill has valid SKILL.md file
  - Frontmatter contains required fields (name, description)
  - Skill descriptions are valid (not empty, reasonable length)
  - No circular dependencies between skills
  - Core skills can be loaded without errors

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
# CORE SKILLS TO VALIDATE (from requirements)
#===============================================================================

CORE_SKILLS=(
    "orchestrator"
    "loop"
    "gates"
    "adversarial"
    "bugs"
    "security"
    "task-batch"
)

#===============================================================================
# RESULT STORAGE (using temp files for bash 3 compatibility)
#===============================================================================

RESULTS_FILE=""
MESSAGES_FILE=""
DESCRIPTIONS_FILE=""
CIRCULAR_FILE=""
UNLOADABLE_FILE=""

init_storage() {
    RESULTS_FILE=$(mktemp)
    MESSAGES_FILE=$(mktemp)
    DESCRIPTIONS_FILE=$(mktemp)
    CIRCULAR_FILE=$(mktemp)
    UNLOADABLE_FILE=$(mktemp)
}

cleanup_storage() {
    rm -f "$RESULTS_FILE" "$MESSAGES_FILE" "$DESCRIPTIONS_FILE" "$CIRCULAR_FILE" "$UNLOADABLE_FILE" 2>/dev/null || true
}

PASSED=0
FAILED=0
WARNINGS=0
TOTAL_SKILLS=0

#===============================================================================
# HELPER FUNCTIONS
#===============================================================================

# Store a result for a skill
store_result() {
    local skill="$1"
    local status="$2"
    echo "${skill}=${status}" >> "$RESULTS_FILE"
}

# Get result for a skill
get_result() {
    local skill="$1"
    local result
    result=$(grep "^${skill}=" "$RESULTS_FILE" 2>/dev/null | cut -d= -f2)
    echo "${result:-SKIP}"
}

# Store a message for a skill
store_message() {
    local skill="$1"
    local message="$2"
    # Use a delimiter that won't appear in messages
    printf '%s\t%s\n' "$skill" "$message" >> "$MESSAGES_FILE"
}

# Get message for a skill
get_message() {
    local skill="$1"
    local message
    message=$(grep "^${skill}"$'\t' "$MESSAGES_FILE" 2>/dev/null | cut -f2-)
    echo "${message:-Not checked}"
}

# Store description for a skill
store_description() {
    local skill="$1"
    local description="$2"
    printf '%s\t%s\n' "$skill" "$description" >> "$DESCRIPTIONS_FILE"
}

# Get description for a skill
get_description() {
    local skill="$1"
    local desc
    desc=$(grep "^${skill}"$'\t' "$DESCRIPTIONS_FILE" 2>/dev/null | cut -f2-)
    echo "$desc"
}

# Log verbose output
log_verbose() {
    [[ "$VERBOSE" -eq 1 ]] && echo "[DEBUG] $*" >&2
}

# Parse YAML frontmatter from SKILL.md
parse_frontmatter() {
    local file="$1"
    local field="$2"

    if [[ ! -r "$file" ]]; then
        return 1
    fi

    local in_frontmatter=0
    local value=""

    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$line" == "---" ]]; then
            if [[ $in_frontmatter -eq 0 ]]; then
                in_frontmatter=1
                continue
            else
                break
            fi
        fi

        if [[ $in_frontmatter -eq 1 ]]; then
            if [[ "$line" =~ ^${field}:[[:space:]]*(.*) ]]; then
                local captured="${BASH_REMATCH[1]}"
                if [[ "$captured" == "|" || "$captured" == ">" ]]; then
                    while IFS= read -r ml_line || [[ -n "$ml_line" ]]; do
                        if [[ "$ml_line" =~ ^[[:space:]] ]]; then
                            value+="${ml_line#"${ml_line%%[![:space:]]*}"} "
                        else
                            break
                        fi
                    done
                    break
                else
                    value="$captured"
                    value="${value#\"}"
                    value="${value%\"}"
                    value="${value#\'}"
                    value="${value%\'}"
                    break
                fi
            fi
        fi
    done < "$file"

    # Trim whitespace
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"

    echo "$value"
}

# Extract related skills from SKILL.md content
extract_dependencies() {
    local file="$1"

    if [[ ! -r "$file" ]]; then
        return 0
    fi

    local in_related=0
    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$line" =~ ^##[[:space:]]*Related[[:space:]]*Skills ]]; then
            in_related=1
            continue
        fi

        if [[ $in_related -eq 1 ]]; then
            if [[ "$line" =~ ^## ]]; then
                break
            fi
            if [[ "$line" =~ \`/([a-zA-Z0-9_-]+)\` ]]; then
                echo "${BASH_REMATCH[1]}"
            elif [[ "$line" =~ \[([a-zA-Z0-9_-]+)\]\( ]]; then
                echo "${BASH_REMATCH[1]}"
            fi
        fi
    done < "$file"
}

# Check for circular dependencies using DFS
# A circular dependency exists when A references B and B references A (directly or indirectly)
check_circular_deps() {
    local skill="$1"
    local start_skill="$2"
    local path="$3"

    # If this skill references back to the start skill, we have a cycle
    if [[ -n "$start_skill" ]] && [[ "$skill" == "$start_skill" ]]; then
        echo "$skill" >> "$CIRCULAR_FILE"
        return 0
    fi

    # If skill is already in current path (not the start), skip to avoid infinite loops
    if [[ " $path " == *" $skill "* ]]; then
        return 0
    fi

    # Add to path
    path="$path $skill"

    # Check each dependency
    local deps_file="/tmp/deps_${skill}.txt"
    if [[ -f "$deps_file" ]]; then
        while IFS= read -r dep; do
            [[ -z "$dep" ]] && continue
            # If this is the first call, set start_skill
            if [[ -z "$start_skill" ]]; then
                check_circular_deps "$dep" "$skill" "$path"
            else
                check_circular_deps "$dep" "$start_skill" "$path"
            fi
        done < "$deps_file"
    fi

    return 0
}

# Run circular dependency detection
run_circular_dep_check() {
    log_verbose "Checking for circular dependencies..."

    for skill in "${CORE_SKILLS[@]}"; do
        check_circular_deps "$skill" "" ""
    done

    # Deduplicate circular dependencies
    if [[ -s "$CIRCULAR_FILE" ]]; then
        sort -u "$CIRCULAR_FILE" -o "$CIRCULAR_FILE"
    fi

    # Clean up dependency temp files
    for skill in "${CORE_SKILLS[@]}"; do
        rm -f "/tmp/deps_${skill}.txt" 2>/dev/null || true
    done
}

# Validate a single skill
validate_skill() {
    local skill="$1"
    local skill_file=""
    local status=""
    local message=""
    local issues=()

    TOTAL_SKILLS=$((TOTAL_SKILLS + 1))

    log_verbose "Validating skill: $skill"

    # Find skill file
    if [[ -f "${GLOBAL_SKILLS_DIR}/${skill}/SKILL.md" ]]; then
        skill_file="${GLOBAL_SKILLS_DIR}/${skill}/SKILL.md"
    elif [[ -f "${GLOBAL_SKILLS_DIR}/${skill}/skill.md" ]]; then
        skill_file="${GLOBAL_SKILLS_DIR}/${skill}/skill.md"
    elif [[ -f "${PROJECT_SKILLS_DIR}/${skill}/SKILL.md" ]]; then
        skill_file="${PROJECT_SKILLS_DIR}/${skill}/SKILL.md"
    elif [[ -f "${PROJECT_SKILLS_DIR}/${skill}/skill.md" ]]; then
        skill_file="${PROJECT_SKILLS_DIR}/${skill}/skill.md"
    fi

    # Check 1: Skill file exists
    if [[ -z "$skill_file" ]]; then
        status="FAIL"
        message="Skill directory or SKILL.md not found"
        echo "$skill" >> "$UNLOADABLE_FILE"
        store_result "$skill" "$status"
        store_message "$skill" "$message"
        FAILED=$((FAILED + 1))
        return
    fi

    # Check 2: Skill file is readable
    if [[ ! -r "$skill_file" ]]; then
        status="FAIL"
        message="SKILL.md is not readable"
        echo "$skill" >> "$UNLOADABLE_FILE"
        store_result "$skill" "$status"
        store_message "$skill" "$message"
        FAILED=$((FAILED + 1))
        return
    fi

    # Check 3: File has valid frontmatter (starts with ---)
    if ! head -1 "$skill_file" | grep -q "^---$"; then
        issues+=("Missing frontmatter delimiter")
    fi

    # Check 4: Required fields exist
    local name=""
    local description=""

    name=$(parse_frontmatter "$skill_file" "name")
    description=$(parse_frontmatter "$skill_file" "description")

    if [[ -z "$name" ]]; then
        issues+=("Missing 'name' field in frontmatter")
    fi

    if [[ -z "$description" ]]; then
        issues+=("Missing 'description' field in frontmatter")
    fi

    # Check 5: Description is valid (not empty, reasonable length)
    if [[ -n "$description" ]]; then
        store_description "$skill" "$description"

        if [[ ${#description} -lt 20 ]]; then
            issues+=("Description too short (min 20 chars)")
        fi

        if [[ ${#description} -gt 500 ]]; then
            issues+=("Description too long (max 500 chars)")
        fi
    fi

    # Check 6: File is valid markdown (basic check - has headers)
    if ! grep -q "^#" "$skill_file" 2>/dev/null; then
        issues+=("No markdown headers found")
    fi

    # Extract dependencies for circular dependency check
    extract_dependencies "$skill_file" > "/tmp/deps_${skill}.txt"

    # Determine final status
    if [[ ${#issues[@]} -eq 0 ]]; then
        status="PASS"
        message="Valid skill with proper frontmatter"
    else
        # Check if any issue is a critical error
        local has_error=0
        for issue in "${issues[@]}"; do
            if [[ "$issue" == *"Missing"*"field"* ]] || [[ "$issue" == *"Missing frontmatter"* ]]; then
                has_error=1
                break
            fi
        done

        if [[ $has_error -eq 1 ]]; then
            status="FAIL"
            message="Issues: ${issues[*]}"
            echo "$skill" >> "$UNLOADABLE_FILE"
            FAILED=$((FAILED + 1))
        else
            status="WARN"
            message="Warnings: ${issues[*]}"
            WARNINGS=$((WARNINGS + 1))
        fi
    fi

    store_result "$skill" "$status"
    store_message "$skill" "$message"

    if [[ "$status" == "PASS" ]]; then
        PASSED=$((PASSED + 1))
    fi
}

# Run circular dependency detection
run_circular_dep_check() {
    log_verbose "Checking for circular dependencies..."

    for skill in "${CORE_SKILLS[@]}"; do
        check_circular_deps "$skill" "" ""
    done

    # Deduplicate circular dependencies
    if [[ -s "$CIRCULAR_FILE" ]]; then
        sort -u "$CIRCULAR_FILE" -o "$CIRCULAR_FILE"
    fi

    # Clean up dependency temp files
    for skill in "${CORE_SKILLS[@]}"; do
        rm -f "/tmp/deps_${skill}.txt" 2>/dev/null || true
    done
}

# Escape string for JSON
json_escape() {
    local str="$1"
    str="${str//\\/\\\\}"
    str="${str//\"/\\\"}"
    str="${str//$'\n'/\\n}"
    str="${str//$'\r'/\\r}"
    str="${str//$'\t'/\\t}"
    echo "$str"
}

# Print text output
print_text_output() {
    echo "═══════════════════════════════════════════════════════════════"
    echo "   Skills Execution Validation - v1.0.0"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    echo "Global Skills Dir:  $GLOBAL_SKILLS_DIR"
    echo "Project Skills Dir: $PROJECT_SKILLS_DIR"
    echo ""

    echo -e "${BLUE}CORE SKILLS VALIDATION${NC}"
    echo "───────────────────────────────────────────────────────────────"

    for skill in "${CORE_SKILLS[@]}"; do
        local skill_status
        skill_status=$(get_result "$skill")
        local skill_message
        skill_message=$(get_message "$skill")

        case "$skill_status" in
            PASS) echo -e "${GREEN}PASS${NC} $skill: $skill_message" ;;
            FAIL) echo -e "${RED}FAIL${NC} $skill: $skill_message" ;;
            WARN) echo -e "${YELLOW}WARN${NC} $skill: $skill_message" ;;
            SKIP) echo -e "${BLUE}SKIP${NC} $skill: $skill_message" ;;
        esac
    done

    echo ""
    echo -e "${BLUE}CIRCULAR DEPENDENCY CHECK${NC}"
    echo "───────────────────────────────────────────────────────────────"

    if [[ -s "$CIRCULAR_FILE" ]]; then
        local circ_count
        circ_count=$(wc -l < "$CIRCULAR_FILE" | tr -d ' ')
        echo -e "${RED}FAIL${NC} Circular dependencies detected: $circ_count skill(s)"
    else
        echo -e "${GREEN}PASS${NC} No circular dependencies detected"
    fi

    # Show unloadable skills if any
    if [[ -s "$UNLOADABLE_FILE" ]]; then
        echo ""
        echo -e "${RED}UNLOADABLE SKILLS${NC}"
        echo "───────────────────────────────────────────────────────────────"
        while IFS= read -r unloadable; do
            local umsg
            umsg=$(get_message "$unloadable")
            echo -e "${RED}X${NC} $unloadable: $umsg"
        done < "$UNLOADABLE_FILE"
    fi

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
        echo -e "${GREEN}All core skills are loadable and valid${NC}"
        return 0
    else
        echo -e "${RED}Some skills failed validation${NC}"
        return 1
    fi
}

# Print JSON output
print_json_output() {
    local overall_status="pass"
    [[ $FAILED -gt 0 ]] && overall_status="fail"

    # Build circular dependencies array
    local circ_json="[]"
    if [[ -s "$CIRCULAR_FILE" ]]; then
        circ_json=$(awk '{print "\"" $0 "\""}' "$CIRCULAR_FILE" | paste -sd ',' - | sed 's/^/[/;s/$/]/')
    fi

    # Build unloadable skills array
    local unloadable_json="[]"
    if [[ -s "$UNLOADABLE_FILE" ]]; then
        unloadable_json=$(awk '{print "\"" $0 "\""}' "$UNLOADABLE_FILE" | paste -sd ',' - | sed 's/^/[/;s/$/]/')
    fi

    echo "{"
    echo "  \"status\": \"$overall_status\","
    echo "  \"global_skills_dir\": \"$GLOBAL_SKILLS_DIR\","
    echo "  \"project_skills_dir\": \"$PROJECT_SKILLS_DIR\","
    echo "  \"summary\": {"
    echo "    \"total\": $TOTAL_SKILLS,"
    echo "    \"passed\": $PASSED,"
    echo "    \"failed\": $FAILED,"
    echo "    \"warnings\": $WARNINGS"
    echo "  },"
    echo "  \"circular_dependencies\": $circ_json,"
    echo "  \"unloadable_skills\": $unloadable_json,"
    echo "  \"skills\": {"

    local first=true
    for skill in "${CORE_SKILLS[@]}"; do
        $first || echo ","
        first=false

        local skill_status
        skill_status=$(get_result "$skill")
        local skill_message
        skill_message=$(json_escape "$(get_message "$skill")")
        local skill_desc
        skill_desc=$(json_escape "$(get_description "$skill")")

        echo -n "    \"$skill\": {"
        echo -n "\"status\": \"$skill_status\", "
        echo -n "\"message\": \"$skill_message\", "
        echo -n "\"description\": \"$skill_desc\""
        echo -n "}"
    done

    echo ""
    echo "  }"
    echo "}"
}

#===============================================================================
# MAIN
#===============================================================================

# Initialize temp storage
init_storage
trap cleanup_storage EXIT

# Check if skills directories exist
if [[ ! -d "$GLOBAL_SKILLS_DIR" ]] && [[ ! -d "$PROJECT_SKILLS_DIR" ]]; then
    echo "ERROR: No skills directories found" >&2
    echo "  Checked: $GLOBAL_SKILLS_DIR" >&2
    echo "  Checked: $PROJECT_SKILLS_DIR" >&2
    exit 2
fi

# Validate core skills
for skill in "${CORE_SKILLS[@]}"; do
    validate_skill "$skill"
done

# Check for circular dependencies
run_circular_dep_check

# Output results
case "$FORMAT" in
    json)
        print_json_output
        ;;
    text|*)
        print_text_output
        ;;
esac

# Exit with appropriate code
if [[ $FAILED -gt 0 ]]; then
    exit 1
fi

exit 0
