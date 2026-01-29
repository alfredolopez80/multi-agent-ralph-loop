#!/usr/bin/env bash
# validate-hooks-before-removal.sh - Validate hooks before removing them
# VERSION: 1.0.0
# Purpose: Comprehensive validation of "obsolete" hooks before removal
#
# This script validates each hook marked as "obsolete" to ensure:
# 1. The functionality is not critical
# 2. The functionality is replaced by newer hooks
# 3. No active workflows depend on it

set -euo pipefail

umask 077

readonly VERSION="1.0.0"
readonly SCRIPT_NAME="$(basename "$0")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

# Hooks marked as "obsolete" in previous analysis
OBSOLETE_HOOKS=(
    "plan-state-init.sh"
    "plan-state-lifecycle.sh"
    "plan-analysis-cleanup.sh"
    "semantic-auto-extractor.sh"
    "orchestrator-auto-learn.sh"
    "agent-memory-auto-init.sh"
    "curator-suggestion.sh"
    "global-task-sync.sh"
    "orchestrator-init.sh"
)

# Validation functions
validate_hook_exists() {
    local hook="$1"
    local hook_path=".claude/hooks/${hook}"

    if [[ -f "$hook_path" ]]; then
        echo "EXISTS"
        return 0
    else
        echo "MISSING"
        return 1
    fi
}

validate_hook_registered() {
    local hook="$1"
    local settings="$HOME/.claude-sneakpeek/zai/config/settings.json"

    if [[ -f "$settings" ]]; then
        if jq -r '.hooks | to_entries[] | select(.value | type == "array") | .value[] | select(.hook? == "'"$hook"'") | .hook' "$settings" 2>/dev/null | grep -q .; then
            echo "REGISTERED"
            return 0
        fi
    fi

    echo "NOT_REGISTERED"
    return 1
}

validate_hook_referenced() {
    local hook="$1"
    local count=0

    # Search in shell scripts
    count=$(find .claude/hooks ~/.ralph/scripts 2>/dev/null -name "*.sh" -exec grep -l "$hook" {} \; 2>/dev/null | wc -l | tr -d ' ')

    if [[ $count -gt 0 ]]; then
        echo "REFERENCED:$count"
        return 0
    else
        echo "NOT_REFERENCED"
        return 1
    fi
}

validate_hook_functionality() {
    local hook="$1"
    local hook_path=".claude/hooks/${hook}"

    if [[ ! -f "$hook_path" ]]; then
        echo "N/A"
        return 1
    fi

    # Check if hook has executable logic
    local logic_lines
    logic_lines=$(grep -vE '^(#|$|[[:space:]]*#)' "$hook_path" | wc -l | tr -d ' ')

    if [[ $logic_lines -gt 20 ]]; then
        echo "COMPLEX:$logic_lines"
    elif [[ $logic_lines -gt 5 ]]; then
        echo "SIMPLE:$logic_lines"
    else
        echo "MINIMAL:$logic_lines"
    fi
}

validate_replacement_exists() {
    local hook="$1"

    case "$hook" in
        "plan-state-init.sh")
            if compgen -G ".claude/hooks/plan-state-*.sh" > /dev/null; then
                echo "REPLACED:plan-state-adaptive.sh"
                return 0
            fi
            ;;
        "semantic-auto-extractor.sh")
            echo "REPLACED:manual-learning"
            return 0
            ;;
        "orchestrator-init.sh")
            if [[ -f ".claude/hooks/orchestrator-auto-learn.sh" ]]; then
                echo "REPLACED:orchestrator-auto-learn.sh"
                return 0
            fi
            ;;
        "agent-memory-auto-init.sh")
            echo "REPLACED:manual-init"
            return 0
            ;;
        "curator-suggestion.sh")
            echo "REPLACED:orchestrator-auto-learn.sh"
            return 0
            ;;
        "global-task-sync.sh")
            echo "REPLACED:task-primitive-sync.sh"
            return 0
            ;;
        *)
            echo "NO_REPLACEMENT"
            return 1
            ;;
    esac
}

# Main validation
main() {
    log_info "Starting comprehensive hook validation..."
    echo ""

    # Create results file
    local results_file=".claude/hooks-validation-results.md"
    {
        echo "# Hooks Validation Results"
        echo ""
        echo "**Date**: $(date -Iseconds)"
        echo "**Version**: $VERSION"
        echo ""
        echo "## Summary"
        echo ""
    } > "$results_file"

    local total=0
    local safe_to_remove=0
    local needs_review=0
    local critical=0

    for hook in "${OBSOLETE_HOOKS[@]}"; do
        total=$((total + 1))
        log_info "Validating: $hook"

        # Run validations
        local exists status registered referenced functionality replacement
        exists=$(validate_hook_exists "$hook")
        status=$(validate_hook_registered "$hook")
        referenced=$(validate_hook_referenced "$hook")
        functionality=$(validate_hook_functionality "$hook")
        replacement=$(validate_replacement_exists "$hook")

        # Determine safety
        local safety="REVIEW"
        local reason=""

        if [[ "$exists" == "MISSING" ]]; then
            safety="SAFE"
            reason="Already removed"
            safe_to_remove=$((safe_to_remove + 1))
        elif [[ "$referenced" == "REFERENCED"* ]]; then
            local ref_count="${referenced#*:}"
            if [[ $ref_count -gt 2 ]]; then
                safety="CRITICAL"
                reason="Referenced by $ref_count other scripts"
                critical=$((critical + 1))
            else
                safety="REVIEW"
                reason="Referenced by $ref_count script(s)"
                needs_review=$((needs_review + 1))
            fi
        elif [[ "$status" == "REGISTERED" ]]; then
            safety="REVIEW"
            reason="Currently registered in settings.json"
            needs_review=$((needs_review + 1))
        elif [[ "$replacement" == "NO_REPLACEMENT" ]]; then
            safety="CRITICAL"
            reason="No replacement found"
            critical=$((critical + 1))
        elif [[ "$functionality" == "COMPLEX"* ]]; then
            local lines="${functionality#*:}"
            safety="REVIEW"
            reason="Complex logic ($lines lines), verify replacement"
            needs_review=$((needs_review + 1))
        else
            safety="SAFE"
            reason="Minimal functionality, has replacement"
            safe_to_remove=$((safe_to_remove + 1))
        fi

        # Output results
        echo "  Status: $exists | $status"
        echo "  References: $referenced"
        echo "  Functionality: $functionality"
        echo "  Replacement: $replacement"
        echo "  Safety: ${safety} - $reason"
        echo ""

        # Write to results file
        {
            echo "### $hook"
            echo ""
            echo "- **Status**: $exists"
            echo "- **Registered**: $status"
            echo "- **Referenced**: $referenced"
            echo "- **Functionality**: $functionality"
            echo "- **Replacement**: $replacement"
            echo "- **Safety**: ${safety}"
            echo "- **Reason**: $reason"
            echo ""
        } >> "$results_file"
    done

    # Write summary
    {
        echo "## Statistics"
        echo ""
        echo "- **Total Hooks**: $total"
        echo "- **Safe to Remove**: $safe_to_remove"
        echo "- **Needs Review**: $needs_review"
        echo "- **Critical**: $critical"
        echo ""
        echo "## Recommendations"
        echo ""
    } >> "$results_file"

    if [[ $critical -gt 0 ]]; then
        {
            echo "⚠️ **CRITICAL**: $critical hook(s) are marked as CRITICAL."
            echo "   These hooks should NOT be removed without careful review."
            echo ""
        } >> "$results_file"
    fi

    if [[ $needs_review -gt 0 ]]; then
        {
            echo "🔍 **REVIEW**: $needs_review hook(s) need manual review."
            echo "   Please verify the functionality before removal."
            echo ""
        } >> "$results_file"
    fi

    if [[ $safe_to_remove -gt 0 ]]; then
        {
            echo "✅ **SAFE**: $safe_to_remove hook(s) are safe to remove."
            echo "   These can be removed without issues."
            echo ""
        } >> "$results_file"
    fi

    log_success "Validation complete! Results saved to: $results_file"
    echo ""
    log_info "Summary:"
    echo "  Total: $total"
    echo "  Safe to remove: $safe_to_remove"
    echo "  Needs review: $needs_review"
    echo "  Critical: $critical"
    echo ""

    if [[ $critical -gt 0 ]]; then
        log_warning "CRITICAL hooks found! Review before removing."
        return 1
    elif [[ $needs_review -gt 0 ]]; then
        log_warning "Some hooks need review. Check results file."
        return 0
    else
        log_success "All hooks are safe to remove!"
        return 0
    fi
}

# Run main
main "$@"
