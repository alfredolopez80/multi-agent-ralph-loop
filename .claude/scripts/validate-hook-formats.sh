#!/usr/bin/env bash
#===============================================================================
# Hook Format Validation Script (v2.70.0)
# Validates JSON output formats against official Claude Code documentation
#===============================================================================

set -euo pipefail
umask 077

readonly VERSION="2.70.0"
readonly SCRIPT_NAME=$(basename "$0")
readonly PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
readonly HOOKS_DIR="${PROJECT_ROOT}/.claude/hooks"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m' # No Color

# Counters
TOTAL=0
PASS=0
FAIL=0
WARN=0

# Print header
echo "================================================"
echo "Hook Format Validation v${VERSION}"
echo "================================================"
echo ""

# Check if hooks directory exists
if [[ ! -d "$HOOKS_DIR" ]]; then
    echo -e "${RED}ERROR: Hooks directory not found: ${HOOKS_DIR}${NC}"
    exit 1
fi

echo "Scanning hooks in: ${HOOKS_DIR}"
echo ""

# Function to validate PreToolUse hooks
validate_pretooluse() {
    local file=$1
    local has_old_format=0
    local has_new_format=0

    # Check for old format {"decision": "allow"}
    if grep -q '{"decision": "allow"}' "$file"; then
        has_old_format=1
    fi

    # Check for new format {"hookSpecificOutput": {"permissionDecision": "allow"}}
    if grep -q '{"hookSpecificOutput":.*"permissionDecision":.*"allow"' "$file"; then
        has_new_format=1
    fi

    if [[ $has_old_format -eq 1 && $has_new_format -eq 0 ]]; then
        echo -e "${YELLOW}WARN${NC}   | $(basename "$file") | Using old PreToolUse format"
        WARN=$((WARN + 1))
        return 1
    elif [[ $has_new_format -eq 1 ]]; then
        echo -e "${GREEN}PASS${NC}   | $(basename "$file") | Using new PreToolUse format"
        PASS=$((PASS + 1))
        return 0
    else
        echo -e "${RED}FAIL${NC}   | $(basename "$file") | No valid PreToolUse format found"
        FAIL=$((FAIL + 1))
        return 2
    fi
}

# Function to validate Stop hooks
validate_stop() {
    local file=$1

    # A Stop hook allows with a clean exit 0 and NO stdout; the only valid value
    # for `decision` is "block". "approve" is not a Claude Code value and is
    # rejected by output validation, so a hook emitting it must FAIL here — the
    # previous check reported exactly that case as PASS. See
    # tests/HOOK_FORMAT_REFERENCE.md.
    # Whole-line comments are stripped first: several hooks *document* the old
    # format in their header, and matching that text reported a correct hook as
    # emitting it.
    local body
    body=$(grep -v -E '^[[:space:]]*#' "$file" || true)

    if printf '%s\n' "$body" | grep -q '"decision": *\\*"approve"'; then
        echo -e "${RED}FAIL${NC}   | $(basename "$file") | Emits invalid {\"decision\": \"approve\"}; allow is a silent exit 0"
        FAIL=$((FAIL + 1))
        return 1
    elif printf '%s\n' "$body" | grep -q '{"decision": "block"'; then
        echo -e "${GREEN}PASS${NC}   | $(basename "$file") | Valid Stop format (block payload)"
        PASS=$((PASS + 1))
        return 0
    else
        # No decision payload at all: the hook only ever allows, which is valid.
        echo -e "${GREEN}PASS${NC}   | $(basename "$file") | Valid Stop format (allow via silent exit 0)"
        PASS=$((PASS + 1))
        return 0
    fi
}

# Function to validate PostToolUse hooks
validate_posttooluse() {
    local file=$1

    # PostToolUse should use {"continue": true}
    if grep -q '{"continue": true}' "$file" || grep -q '{"continue": false}' "$file"; then
        echo -e "${GREEN}PASS${NC}   | $(basename "$file") | Valid PostToolUse format"
        PASS=$((PASS + 1))
        return 0
    else
        echo -e "${RED}FAIL${NC}   | $(basename "$file") | Invalid PostToolUse format"
        FAIL=$((FAIL + 1))
        return 1
    fi
}

# Function to validate error traps
validate_error_trap() {
    local file=$1

    # Should have trap 'output_json' ERR EXIT or similar
    if grep -q "trap.*output_json.*ERR.*EXIT" "$file" || grep -q "trap.*ERR.*EXIT" "$file"; then
        echo -e "${GREEN}PASS${NC}   | $(basename "$file") | Has ERR EXIT trap"
        PASS=$((PASS + 1))
        return 0
    else
        echo -e "${YELLOW}WARN${NC}   | $(basename "$file") | Missing ERR EXIT trap"
        WARN=$((WARN + 1))
        return 1
    fi
}

# Main validation loop
echo "Hook Type    | File | Status"
echo "-------------|------|--------"

for hook_file in "$HOOKS_DIR"/*.sh "$HOOKS_DIR"/*.py; do
    if [[ -f "$hook_file" ]]; then
        TOTAL=$((TOTAL + 1))

        # Determine hook type by filename and validate accordingly
        # `|| true` is required: each validator returns non-zero to signal WARN or
        # FAIL, and under `set -euo pipefail` that aborted the whole run on the
        # first non-passing hook. The verdict is carried by the counters and
        # applied by the summary below, so swallowing the status here is safe.
        if [[ "$hook_file" =~ (lsa-pre|repo-boundary|fast-path|smart-memory|skill-validator|procedural-inject|checkpoint-smart|checkpoint-auto|git-safety|smart-skill|orchestrator-auto-learn|task-orchestration|inject-session) ]]; then
            validate_pretooluse "$hook_file" || true
        elif [[ "$hook_file" =~ (continuous-learning|orchestrator-report|project-backup|reflection-engine|semantic-auto-extractor|sentry-report|stop-verification) ]]; then
            validate_stop "$hook_file" || true
        elif [[ "$hook_file" =~ (quality-gates|sec-context|security-full|decision-extractor|semantic-realtime|plan-sync|glm-context|progress-tracker|typescript-quick) ]]; then
            validate_posttooluse "$hook_file" || true
        fi

        # All hooks should have error traps
        validate_error_trap "$hook_file" || true
    fi
done

# Summary
echo ""
echo "================================================"
echo "Summary"
echo "================================================"
echo "Total hooks checked: $TOTAL"
echo -e "${GREEN}Passed: $PASS${NC}"
echo -e "${YELLOW}Warnings: $WARN${NC}"
echo -e "${RED}Failed: $FAIL${NC}"
echo ""

if [[ $FAIL -gt 0 ]]; then
    echo -e "${RED}VALIDATION FAILED${NC}"
    echo "Some hooks have critical format errors."
    exit 1
elif [[ $WARN -gt 0 ]]; then
    echo -e "${YELLOW}VALIDATION PASSED WITH WARNINGS${NC}"
    echo "Some hooks are using deprecated formats."
    echo "Consider running migrate-hook-formats.sh to update."
    exit 0
else
    echo -e "${GREEN}VALIDATION PASSED${NC}"
    echo "All hooks are using correct formats."
    exit 0
fi
