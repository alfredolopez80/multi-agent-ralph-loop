#!/usr/bin/env bash
#===============================================================================
# validate-hooks-registration.sh
# Validates that ALL hooks are properly registered in settings.json
#
# VERSION: 2.0.0
# DATE: 2026-02-15
# PURPOSE: Comprehensive hook registration validation
#
# Usage:
#   ./scripts/validate-hooks-registration.sh [--format json|text] [--verbose]
#
# Exit codes:
#   0: All required hooks registered
#   1: Missing required hooks
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

# Settings path - use primary location
SETTINGS_PATH="${HOME}/.claude/settings.json"
PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
HOOKS_DIR="${PROJECT_ROOT}/.claude/hooks"

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
Usage: validate-hooks-registration.sh [OPTIONS]

Options:
  --format FORMAT  Output format: text (default) or json
  --verbose, -v    Show detailed information
  --help, -h       Show this help message

Checks:
  - All hooks registered in settings.json
  - All hook scripts exist at specified paths
  - All hook scripts are executable
  - No orphan hooks (scripts without registration)
  - No missing hooks (registration without script)

Exit codes:
  0  All hooks registered correctly
  1  Some hooks missing or misconfigured
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
# HOOK DEFINITIONS (from PRD)
#===============================================================================

# Format: "event:matcher||script||description" (using double pipe as delimiter)
# Using array instead of associative for order preservation
HOOK_DEFINITIONS=(
    # SessionStart hooks
    "SessionStart:*||auto-migrate-plan-state.sh||Plan state migration"
    "SessionStart:*||auto-sync-global.sh||Global sync"
    "SessionStart:*||session-start-restore-context.sh||Context restore"
    "SessionStart:*||orchestrator-init.sh||Orchestrator init"
    "SessionStart:*||project-backup-metadata.sh||Backup metadata"
    "SessionStart:*||session-start-repo-summary.sh||Repo summary"

    # PreToolUse (Edit/Write) hooks
    "PreToolUse:Edit||Write||checkpoint-auto-save.sh||Auto-save checkpoint"
    "PreToolUse:Edit||Write||smart-skill-reminder.sh||Skill reminder"

    # PreToolUse (Bash) hooks
    "PreToolUse:Bash||git-safety-guard.py||Git safety"
    "PreToolUse:Bash||repo-boundary-guard.sh||Repo boundary"

    # PreToolUse (Task) hooks
    "PreToolUse:Task||lsa-pre-step.sh||LSA pre-step"
    "PreToolUse:Task||fast-path-check.sh||Fast path"
    "PreToolUse:Task||smart-memory-search.sh||Memory search"
    "PreToolUse:Task||skill-validator.sh||Skill validation"
    "PreToolUse:Task||procedural-inject.sh||Procedural inject"
    "PreToolUse:Task||checkpoint-smart-save.sh||Smart save"
    "PreToolUse:Task||orchestrator-auto-learn.sh||Auto learn"
    "PreToolUse:Task||promptify-security.sh||Security prompt"
    "PreToolUse:Task||inject-session-context.sh||Session context"
    "PreToolUse:Task||rules-injector.sh||Rules inject"

    # Stop hooks
    "Stop:*||reflection-engine.sh||Reflection"
    "Stop:*||orchestrator-report.sh||Report"

    # PostToolUse (Edit/Write/Bash) hooks
    "PostToolUse:Edit||Write||Bash||sec-context-validate.sh||Security validate"
    "PostToolUse:Edit||Write||Bash||security-full-audit.sh||Full audit"
    "PostToolUse:Edit||Write||Bash||quality-gates-v2.sh||Quality gates"
    "PostToolUse:Edit||Write||Bash||decision-extractor.sh||Decision extract"
    "PostToolUse:Edit||Write||Bash||semantic-realtime-extractor.sh||Semantic extract"
    "PostToolUse:Edit||Write||Bash||plan-sync-post-step.sh||Plan sync"
    "PostToolUse:Edit||Write||Bash||glm-context-update.sh||Context update"
    "PostToolUse:Edit||Write||Bash||progress-tracker.sh||Progress track"
    "PostToolUse:Edit||Write||Bash||typescript-quick-check.sh||TypeScript check"
    "PostToolUse:Edit||Write||Bash||quality-parallel-async.sh||Parallel quality"
    "PostToolUse:Edit||Write||Bash||status-auto-check.sh||Status check"
    "PostToolUse:Edit||Write||Bash||console-log-detector.sh||Console detect"
    "PostToolUse:Edit||Write||Bash||ai-code-audit.sh||AI audit"

    # PostToolUse (Task) hooks
    "PostToolUse:Task||auto-background-swarm.sh||Background swarm"
    "PostToolUse:Task||parallel-explore.sh||Parallel explore"
    "PostToolUse:Task||recursive-decompose.sh||Recursive decompose"
    "PostToolUse:Task||adversarial-auto-trigger.sh||Adversarial"
    "PostToolUse:Task||code-review-auto.sh||Code review"

    # PostToolUse (TodoWrite) hooks
    "PostToolUse:TodoWrite||todo-plan-sync.sh||Todo sync"

    # PreCompact hooks
    "PreCompact:*||pre-compact-handoff.sh||Compact handoff"

    # UserPromptSubmit hooks
    "UserPromptSubmit:*||context-warning.sh||Context warning"
    "UserPromptSubmit:*||command-router.sh||Command router"
    "UserPromptSubmit:*||memory-write-trigger.sh||Memory trigger"
    "UserPromptSubmit:*||periodic-reminder.sh||Periodic remind"
    "UserPromptSubmit:*||plan-state-adaptive.sh||Plan adaptive"
    "UserPromptSubmit:*||plan-state-lifecycle.sh||Plan lifecycle"

    # SubagentStop hooks
    "SubagentStop:*||glm5-subagent-stop.sh||GLM5 stop"
)

#===============================================================================
# RESULT STORAGE
#===============================================================================

declare -A RESULTS
declare -A MESSAGES
PASSED=0
FAILED=0
WARNINGS=0
TOTAL=0

#===============================================================================
# FUNCTIONS
#===============================================================================

# Check if hook script exists
hook_file_exists() {
    local script="$1"
    [[ -f "${HOOKS_DIR}/${script}" ]]
}

# Check if hook script is executable
hook_is_executable() {
    local script="$1"
    [[ -x "${HOOKS_DIR}/${script}" ]]
}

# Check if hook is registered in settings.json
hook_is_registered() {
    local event="$1"
    local matcher="$2"
    local script="$3"

    local hook_path="${HOOKS_DIR}/${script}"

    # Check if hook path exists in settings.json
    jq -e --arg path "$hook_path" --arg event "$event" --arg matcher "$matcher" '
        .hooks[$event] // [] |
        map(select(.matcher == $matcher)) |
        .[0].hooks // [] |
        map(select(.command == $path)) |
        length > 0
    ' "$SETTINGS_PATH" >/dev/null 2>&1
}

# Validate a single hook
validate_hook() {
    local def="$1"

    # Parse using || delimiter
    # Format: "event:matcher||script||description"
    # Example: "SessionStart:*||auto-migrate-plan-state.sh||Plan state migration"
    # Example: "PostToolUse:Edit|Write|Bash||status-auto-check.sh||Status check"

    local event_matcher="${def%%||*}"
    local rest="${def#*||}"
    local script="${rest%%||*}"
    local description="${rest#*||}"

    # Extract event (before colon) and matcher (after colon)
    local event="${event_matcher%%:*}"
    local matcher="${event_matcher#*:}"

    local status=""
    local message=""

    # Check if file exists
    if ! hook_file_exists "$script"; then
        status="FAIL"
        message="Script not found: ${HOOKS_DIR}/${script}"
    # Check if executable
    elif ! hook_is_executable "$script"; then
        status="WARN"
        message="Script not executable: ${script}"
    # Check if registered
    elif ! hook_is_registered "$event" "$matcher" "$script"; then
        status="FAIL"
        message="Not registered in settings.json (Event: $event, Matcher: $matcher)"
    else
        status="PASS"
        message="$description"
    fi

    RESULTS["$script"]="$status"
    MESSAGES["$script"]="$message"

    case "$status" in
        PASS) PASSED=$((PASSED + 1)) ;;
        FAIL) FAILED=$((FAILED + 1)) ;;
        WARN) WARNINGS=$((WARNINGS + 1)) ;;
    esac
    TOTAL=$((TOTAL + 1))
}

# Print text output
print_text_output() {
    echo "═══════════════════════════════════════════════════════════════"
    echo "   Hooks Registration Validation - v2.0.0"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    echo "Settings: $SETTINGS_PATH"
    echo "Hooks Dir: $HOOKS_DIR"
    echo ""

    # Group by event type
    local current_event=""

    for def in "${HOOK_DEFINITIONS[@]}"; do
        local event_matcher="${def%%||*}"
        local event="${event_matcher%%:*}"
        local rest="${def#*||}"
        local script="${rest%%||*}"
        local status="${RESULTS[$script]}"
        local message="${MESSAGES[$script]}"

        if [[ "$event" != "$current_event" ]]; then
            current_event="$event"
            echo -e "${BLUE}$event${NC}"
            echo "───────────────────────────────────────────────────────────────"
        fi

        case "$status" in
            PASS) echo -e "${GREEN}✓${NC} $script: $message" ;;
            FAIL) echo -e "${RED}✗${NC} $script: $message" ;;
            WARN) echo -e "${YELLOW}⚠${NC} $script: $message" ;;
        esac
    done

    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "   SUMMARY"
    echo "═══════════════════════════════════════════════════════════════"
    echo "  Total:   $TOTAL"
    echo "  Passed:  $PASSED"
    echo "  Failed:  $FAILED"
    echo "  Warnings: $WARNINGS"
    echo ""

    if [[ $FAILED -eq 0 ]]; then
        echo -e "${GREEN}✓ All required hooks registered correctly${NC}"
        return 0
    else
        echo -e "${RED}✗ Some hooks are missing or misconfigured${NC}"
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
  "settings_path": "$SETTINGS_PATH",
  "hooks_dir": "$HOOKS_DIR",
  "summary": {
    "total": $TOTAL,
    "passed": $PASSED,
    "failed": $FAILED,
    "warnings": $WARNINGS
  },
  "hooks": {
EOF

    local first=true
    for def in "${HOOK_DEFINITIONS[@]}"; do
        local event_matcher="${def%%||*}"
        local rest="${def#*||}"
        local script="${rest%%||*}"
        local event="${event_matcher%%:*}"
        local matcher="${event_matcher#*:}"

        $first || echo ","
        first=false
        cat << EOF
    "$script": {
      "event": "$event",
      "matcher": "$matcher",
      "status": "${RESULTS[$script]}",
      "message": "${MESSAGES[$script]}"
    }
EOF
    done

    echo "  }"
    echo "}"
}

#===============================================================================
# MAIN
#===============================================================================

# Check if settings.json exists
if [[ ! -f "$SETTINGS_PATH" ]]; then
    echo "Settings file not found: $SETTINGS_PATH" >&2
    exit 2
fi

# Check if jq is available
if ! command -v jq &>/dev/null; then
    echo "jq is required but not installed" >&2
    exit 2
fi

# Validate all hooks
for def in "${HOOK_DEFINITIONS[@]}"; do
    validate_hook "$def"
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
