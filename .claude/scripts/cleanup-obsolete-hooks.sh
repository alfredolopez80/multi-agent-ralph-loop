#!/usr/bin/env bash
#
# cleanup-obsolete-hooks.sh
# Remove obsolete hooks related to deprecated ralph memory/ledger/plan functionality
#
# Version: 2.81.0
# Date: 2026-01-29
# Status: ANALYSIS COMPLETE

set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Script directory
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly HOOKS_DIR="${SCRIPT_DIR}/../hooks"
readonly BACKUP_DIR="${HOME}/.ralph/backups/obsolete-hooks-$(date +%Y%m%d-%H%M%S)"

# Obsolete hooks to remove (confirmed not registered in settings.json)
readonly OBSOLETE_HOOKS=(
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

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

# Check if hook is registered in settings.json
is_hook_registered() {
    local hook_name="$1"
    local settings_file="${HOME}/.claude-sneakpeek/zai/config/settings.json"

    if [[ -f "$settings_file" ]]; then
        if grep -q "$hook_name" "$settings_file" 2>/dev/null; then
            return 0  # Registered
        fi
    fi
    return 1  # Not registered
}

# Create backup of hooks before removal
backup_hooks() {
    log_info "Creating backup of obsolete hooks..."
    mkdir -p "$BACKUP_DIR"

    local backed_up=0
    for hook in "${OBSOLETE_HOOKS[@]}"; do
        local hook_path="${HOOKS_DIR}/${hook}"
        if [[ -f "$hook_path" ]]; then
            cp "$hook_path" "$BACKUP_DIR/"
            ((backed_up++))
        fi
    done

    log_success "Backed up $backed_up hooks to: $BACKUP_DIR"
}

# Remove obsolete hooks
remove_obsolete_hooks() {
    log_info "Removing obsolete hooks..."
    log_info ""

    local removed=0
    local skipped=0

    for hook in "${OBSOLETE_HOOKS[@]}"; do
        local hook_path="${HOOKS_DIR}/${hook}"

        if [[ ! -f "$hook_path" ]]; then
            log_warning "  ⚠ $hook - NOT FOUND (already removed?)"
            ((skipped++))
            continue
        fi

        # Double-check it's not registered
        if is_hook_registered "$hook"; then
            log_error "  ✗ $hook - REGISTERED in settings.json, SKIPPED"
            ((skipped++))
            continue
        fi

        # Safe to remove
        rm -f "$hook_path"
        log_success "  ✓ $hook - REMOVED"
        ((removed++))
    done

    log_info ""
    log_success "Removed: $removed hooks"
    log_info "Skipped: $skipped hooks"
}

# Verify active hooks still present
verify_active_hooks() {
    log_info "Verifying active hooks are still present..."

    # Critical hooks that MUST be present
    local critical_hooks=(
        "memory-write-trigger.sh"
        "session-start-ledger.sh"
        "plan-state-adaptive.sh"
        "auto-migrate-plan-state.sh"
        "plan-sync-post-step.sh"
        "smart-memory-search.sh"
        "semantic-realtime-extractor.sh"
        "decision-extractor.sh"
        "procedural-inject.sh"
        "reflection-engine.sh"
        "orchestrator-report.sh"
    )

    local missing=0
    for hook in "${critical_hooks[@]}"; do
        local hook_path="${HOOKS_DIR}/${hook}"
        if [[ ! -f "$hook_path" ]]; then
            log_error "  ✗ CRITICAL: $hook is MISSING!"
            ((missing++))
        fi
    done

    if [[ $missing -eq 0 ]]; then
        log_success "All critical hooks verified ✓"
    else
        log_error "Missing $missing critical hooks!"
        return 1
    fi
}

# Generate cleanup report
generate_report() {
    local report_file="${BACKUP_DIR}/cleanup-report.txt"

    log_info "Generating cleanup report..."

    cat > "$report_file" <<EOF
Obsolete Hooks Cleanup Report
=============================
Date: $(date -u +"%Y-%m-%d %H:%M:%S UTC")
Version: 2.81.0

REMOVED HOOKS:
--------------
$(for hook in "${OBSOLETE_HOOKS[@]}"; do
    if [[ ! -f "${HOOKS_DIR}/${hook}" ]]; then
        echo "  ✓ $hook"
    else
        echo "  ✗ $hook (skipped)"
    fi
done)

BACKUP LOCATION:
----------------
$BACKUP_DIR

ACTIVE HOOKS VERIFIED:
----------------------
$(ls -1 "${HOOKS_DIR}"/*.sh 2>/dev/null | wc -l) hooks remaining

DATA STORAGE:
-------------
- ~/.ralph/memory/     (semantic, learning)
- ~/.ralph/episodes/   (episodic, 30d TTL)
- ~/.ralph/procedural/ (learned patterns)
- ~/.ralph/ledgers/    (session continuity)
- ~/.ralph/checkpoints/ (time travel backups)
- ~/.ralph/agent-memory/ (per-agent memory)

DEPRECATED:
-----------
- ralph memory → claude-mem MCP
- ralph ledger → learning only (no critical data)
- ralph plan   → backup only (Claude Code source of truth)

EOF

    log_success "Report saved to: $report_file"
    cat "$report_file"
}

# Main execution
main() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║     Obsolete Hooks Cleanup v2.81.0                        ║"
    echo "║     Memory/Ledger/Plan Hooks Analysis                     ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""

    # Safety check: require confirmation
    log_warning "This will REMOVE the following obsolete hooks:"
    for hook in "${OBSOLETE_HOOKS[@]}"; do
        echo "  - $hook"
    done
    echo ""

    read -p "Continue? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Cleanup cancelled."
        exit 0
    fi

    # Execute cleanup
    backup_hooks
    remove_obsolete_hooks
    verify_active_hooks
    generate_report

    log_success ""
    log_success "Cleanup complete!"
    log_info "Backup location: $BACKUP_DIR"
    log_info ""
    log_info "Next steps:"
    log_info "  1. Test Claude Code functionality"
    log_info "  2. Verify memory/ledger/plan systems work correctly"
    log_info "  3. If issues occur, restore from backup:"
    log_info "     cp $BACKUP_DIR/* ${HOOKS_DIR}/"
    echo ""
}

# Run main function
main "$@"
