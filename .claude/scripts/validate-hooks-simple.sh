#!/usr/bin/env bash
# validate-hooks-simple.sh - Simplified hook validation
# VERSION: 1.0.0

set -euo pipefail

readonly VERSION="1.0.0"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

main() {
    log_info "Starting hook validation (simplified)..."
    echo ""

    local results_file=".claude/hooks-validation-results-simple.md"

    {
        echo "# Hooks Validation Results (Simplified)"
        echo ""
        echo "**Date**: $(date -Iseconds)"
        echo "**Version**: $VERSION"
        echo ""
        echo "## Results"
        echo ""
    } > "$results_file"

    local total=0
    local exists_count=0
    local critical_count=0

    for hook in "${OBSOLETE_HOOKS[@]}"; do
        total=$((total + 1))
        log_info "Checking: $hook"

        local hook_path=".claude/hooks/${hook}"
        local exists="MISSING"
        local referenced="NOT_REFERENCED"
        local status="UNKNOWN"
        local recommendation="REVIEW"

        # Check if exists
        if [[ -f "$hook_path" ]]; then
            exists="EXISTS"
            exists_count=$((exists_count + 1))

            # Check if referenced by other scripts
            local ref_count=0
            ref_count=$(find .claude/hooks ~/.ralph/scripts 2>/dev/null -name "*.sh" -exec grep -l "$hook" {} \; 2>/dev/null | wc -l | tr -d ' ' || echo "0")

            if [[ $ref_count -gt 0 ]]; then
                referenced="REFERENCED:$ref_count"
            fi

            # Check if critical
            case "$hook" in
                "orchestrator-auto-learn.sh"|"procedural-inject.sh"|"plan-state-init.sh")
                    status="CRITICAL"
                    recommendation="DO NOT REMOVE - Essential for learning system"
                    critical_count=$((critical_count + 1))
                    ;;
                "semantic-auto-extractor.sh"|"agent-memory-auto-init.sh")
                    status="SAFE"
                    recommendation="Can be removed - Replaced by manual processes"
                    ;;
                *)
                    status="REVIEW"
                    recommendation="Review before removal - May have dependencies"
                    ;;
            esac
        else
            status="MISSING"
            recommendation="Already removed"
        fi

        # Output
        echo "  Status: $exists | $referenced"
        echo "  Assessment: $status"
        echo "  Recommendation: $recommendation"
        echo ""

        # Write to results
        {
            echo "### $hook"
            echo ""
            echo "- **Status**: $exists"
            echo "- **Referenced**: $referenced"
            echo "- **Assessment**: $status"
            echo "- **Recommendation**: $recommendation"
            echo ""
        } >> "$results_file"
    done

    # Summary
    {
        echo "## Summary"
        echo ""
        echo "- **Total Hooks**: $total"
        echo "- **Currently Exist**: $exists_count"
        echo "- **Critical**: $critical_count"
        echo ""
        echo "## Recommendations"
        echo ""
        echo "⚠️  **CRITICAL hooks found**: $critical_count"
        echo "   These hooks are ESSENTIAL for the learning system."
        echo "   DO NOT remove without complete understanding."
        echo ""
    } >> "$results_file"

    log_success "Validation complete! Results saved to: $results_file"
    echo ""
    log_info "Summary:"
    echo "  Total: $total"
    echo "  Exists: $exists_count"
    echo "  Critical: $critical_count"
    echo ""

    if [[ $critical_count -gt 0 ]]; then
        log_warning "CRITICAL hooks found! Review before removing."
        return 1
    else
        log_success "No critical hooks found."
        return 0
    fi
}

main "$@"
