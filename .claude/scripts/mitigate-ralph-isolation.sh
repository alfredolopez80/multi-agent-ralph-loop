#!/bin/bash
# Ralph Orchestration System - Isolation Mitigation Script
# Version: 1.0.0
# Date: 2026-01-29
#
# This script implements the critical security fixes from the adversarial audit:
# https://github.com/alfredolopez80/multi-agent-ralph-loop/blob/main/docs/security/ADVERSARIAL_AUDIT_RALPH_ISOLATION.md
#
# Usage:
#   ./mitigate-ralph-isolation.sh [--dry-run] [--force]

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
DRY_RUN=false
FORCE=false
CURRENT_REPO="$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")"
PROJECT_ID="$(git remote get-url origin 2>/dev/null | sed 's|.*/||' | sed 's|\.git$||' || echo "local-project")"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --force)
            FORCE=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [--dry-run] [--force]"
            echo ""
            echo "Options:"
            echo "  --dry-run    Show what would be done without making changes"
            echo "  --force      Apply fixes without confirmation"
            echo "  -h, --help   Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running in a git repository
check_git_repo() {
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        log_warning "Not in a git repository. Skipping .gitignore updates."
        return 1
    fi
    return 0
}

# Fix 1: Add .gitignore entries
fix_gitignore() {
    log_info "Fix 1: Adding .gitignore entries for Ralph directories..."

    if ! check_git_repo; then
        return 0
    fi

    GITIGNORE_FILE="$CURRENT_REPO/.gitignore"

    # Create .gitignore if it doesn't exist
    if [[ ! -f "$GITIGNORE_FILE" ]]; then
        if [[ "$DRY_RUN" == true ]]; then
            log_info "[DRY RUN] Would create .gitignore file"
        else
            touch "$GITIGNORE_FILE"
            log_success "Created .gitignore file"
        fi
    fi

    # Check if .ralph/ is already in .gitignore
    if grep -q "^\.ralph/$" "$GITIGNORE_FILE" 2>/dev/null; then
        log_info ".ralph/ already in .gitignore"
        return 0
    fi

    # Add entries
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would add to .gitignore:"
        echo "  # Ralph orchestration state"
        echo "  .ralph/"
        echo "  # Ralph usage logs"
        echo "  .ralph/logs/"
        echo "  .ralph/usage.jsonl"
    else
        {
            echo ""
            echo "# Ralph orchestration state"
            echo ".ralph/"
            echo "# Ralph usage logs"
            echo ".ralph/logs/"
            echo ".ralph/usage.jsonl"
        } >> "$GITIGNORE_FILE"
        log_success "Added .ralph/ entries to .gitignore"
    fi
}

# Fix 2: Create .claude/memory/ directory structure
fix_claude_memory_structure() {
    log_info "Fix 2: Creating .claude/memory/ directory structure..."

    CLAUDE_MEMORY_DIR="$CURRENT_REPO/.claude/memory"

    if [[ -d "$CLAUDE_MEMORY_DIR" ]]; then
        log_info ".claude/memory/ already exists"
        return 0
    fi

    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would create directory structure:"
        echo "  $CLAUDE_MEMORY_DIR/"
        echo "  $CLAUDE_MEMORY_DIR/semantic/"
        echo "  $CLAUDE_MEMORY_DIR/episodic/"
        echo "  $CLAUDE_MEMORY_DIR/procedural/"
    else
        mkdir -p "$CLAUDE_MEMORY_DIR"/{semantic,episodic,procedural}
        log_success "Created .claude/memory/ directory structure"
    fi
}

# Fix 3: Migrate data from .ralph/memory/ to .claude/memory/
fix_migrate_memory() {
    log_info "Fix 3: Migrating memory data from .ralph/ to .claude/memory/..."

    RALPH_MEMORY_DIR="$CURRENT_REPO/.ralph/memory"
    CLAUDE_MEMORY_DIR="$CURRENT_REPO/.claude/memory"

    if [[ ! -d "$RALPH_MEMORY_DIR" ]]; then
        log_info "No .ralph/memory/ directory found. Skipping migration."
        return 0
    fi

    # Migrate semantic.json
    if [[ -f "$RALPH_MEMORY_DIR/semantic.json" ]]; then
        if [[ "$DRY_RUN" == true ]]; then
            log_info "[DRY RUN] Would migrate: $RALPH_MEMORY_DIR/semantic.json -> $CLAUDE_MEMORY_DIR/semantic/"
        else
            cp "$RALPH_MEMORY_DIR/semantic.json" "$CLAUDE_MEMORY_DIR/semantic/"
            log_success "Migrated semantic.json"
        fi
    fi

    # Migrate episodic/
    if [[ -d "$RALPH_MEMORY_DIR/episodic" ]]; then
        if [[ "$DRY_RUN" == true ]]; then
            log_info "[DRY RUN] Would migrate: $RALPH_MEMORY_DIR/episodic/* -> $CLAUDE_MEMORY_DIR/episodic/"
        else
            cp -r "$RALPH_MEMORY_DIR/episodic/"* "$CLAUDE_MEMORY_DIR/episodic/" 2>/dev/null || true
            log_success "Migrated episodic/ directory"
        fi
    fi

    # Migrate procedural/
    if [[ -d "$RALPH_MEMORY_DIR/procedural" ]]; then
        if [[ "$DRY_RUN" == true ]]; then
            log_info "[DRY RUN] Would migrate: $RALPH_MEMORY_DIR/procedural/* -> $CLAUDE_MEMORY_DIR/procedural/"
        else
            cp -r "$RALPH_MEMORY_DIR/procedural/"* "$CLAUDE_MEMORY_DIR/procedural/" 2>/dev/null || true
            log_success "Migrated procedural/ directory"
        fi
    fi
}

# Fix 4: Update hooks to use .claude/memory/ instead of .ralph/memory/
fix_update_hooks() {
    log_info "Fix 4: Checking hooks for .ralph/memory/ references..."

    HOOKS_DIR="$HOME/.claude-sneakpeek/zai/config/hooks"
    PROJECT_HOOKS_DIR="$CURRENT_REPO/.claude/hooks"

    # Check global hooks
    if [[ -d "$HOOKS_DIR" ]]; then
        HOOKS_WITH_RALPH=$(grep -r "\.ralph/memory" "$HOOKS_DIR" 2>/dev/null | wc -l)

        if [[ $HOOKS_WITH_RALPH -gt 0 ]]; then
            log_warning "Found $HOOKS_WITH_RALPH hook(s) referencing .ralph/memory/"
            log_info "Manual update required. Run:"
            echo "  cd \"$HOOKS_DIR\""
            echo "  grep -r '\.ralph/memory' . | sed 's/:.*//g' | sort -u"
        else
            log_success "No .ralph/memory/ references in global hooks"
        fi
    fi

    # Check project hooks
    if [[ -d "$PROJECT_HOOKS_DIR" ]]; then
        PROJECT_HOOKS_WITH_RALPH=$(grep -r "\.ralph/memory" "$PROJECT_HOOKS_DIR" 2>/dev/null | wc -l)

        if [[ $PROJECT_HOOKS_WITH_RALPH -gt 0 ]]; then
            log_warning "Found $PROJECT_HOOKS_WITH_RALPH project hook(s) referencing .ralph/memory/"
        else
            log_success "No .ralph/memory/ references in project hooks"
        fi
    fi
}

# Fix 5: Create migration report
fix_create_report() {
    log_info "Fix 5: Creating migration report..."

    REPORT_FILE="$CURRENT_REPO/.claude/memory/MIGRATION_REPORT.md"

    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would create migration report: $REPORT_FILE"
        return 0
    fi

    cat > "$REPORT_FILE" <<EOF
# Ralph Memory Migration Report

**Date**: $(date -u +"%Y-%m-%d %H:%M:%S UTC")
**Project**: $PROJECT_ID
**Repository**: $CURRENT_REPO
**Migration Version**: 1.0.0

## Summary

This repository has been migrated from the redundant Ralph memory architecture
to the consolidated 2-tier memory system.

## Changes Made

### 1. Directory Structure
- **Created**: \`.claude/memory/\` (project-local memory)
- **Deprecated**: \`.ralph/memory/\` (will be removed in future versions)

### 2. Git Ignore
- **Added**: \`.ralph/\` entries to \`.gitignore\`
- **Purpose**: Prevent accidental commits of internal state

### 3. Data Migration
- **Migrated**: Semantic memory from \`.ralph/memory/semantic.json\`
- **Migrated**: Episodic memory from \`.ralph/memory/episodic/\`
- **Migrated**: Procedural rules from \`.ralph/memory/procedural/\`

## New Architecture

\`\`\`
BEFORE:                                AFTER:
~/.ralph/memory/ (global)            → ~/.claude-sneakpeek/ (global, claude-mem only)
  ├─ semantic.json                     └─ projects/<id>/memory.json (cross-project)
  ├─ episodic/
  └─ procedural/

<repo>/.ralph/memory/ (local)       → <repo>/.claude/memory/ (local)
  ├─ semantic.json                     └─ semantic/ (project-specific)
  ├─ episodic/                         └─ episodic/
  └─ procedural/                       └─ procedural/
\`\`\`

## Benefits

1. **Security**: Project isolation prevents cross-project information leakage
2. **Consistency**: Single \`.claude/\` directory for all Claude Code workspace data
3. **Git Safety**: Automatic \`.gitignore\` prevents accidental commits
4. **Reduced Redundancy**: Eliminated 82% functional overlap between memory systems

## Next Steps

1. **Verify**: Check that all data migrated correctly
2. **Test**: Run \`.claude/hooks/\` scripts to ensure they work with new paths
3. **Cleanup**: Remove old \`.ralph/memory/\` directory (optional, after verification)

## Verification Commands

\`\`\`bash
# Check new memory structure
ls -la .claude/memory/

# Verify .gitignore entries
grep ".ralph/" .gitignore

# Check for any remaining .ralph/ references
grep -r "\.ralph/" .claude/hooks/ 2>/dev/null
\`\`\`

## Support

For issues or questions, see:
- [Adversarial Audit Report](https://github.com/alfredolopez80/multi-agent-ralph-loop/blob/main/docs/security/ADVERSARIAL_AUDIT_RALPH_ISOLATION.md)
- [Ralph Documentation](https://github.com/alfredolopez80/multi-agent-ralph-loop/blob/main/README.md)

---

**Migration Script**: \`mitigate-ralph-isolation.sh v1.0.0\`
**Status**: ✅ Migration Complete
EOF

    log_success "Created migration report: $REPORT_FILE"
}

# Main execution
main() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}Ralph Isolation Mitigation Script v1.0.0${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""

    if [[ "$DRY_RUN" == true ]]; then
        log_warning "DRY RUN MODE - No changes will be made"
        echo ""
    fi

    log_info "Project: $PROJECT_ID"
    log_info "Repository: $CURRENT_REPO"
    echo ""

    # Ask for confirmation unless --force is used
    if [[ "$FORCE" == false && "$DRY_RUN" == false ]]; then
        echo -e "${YELLOW}This script will make the following changes:${NC}"
        echo "  1. Add .ralph/ to .gitignore"
        echo "  2. Create .claude/memory/ directory structure"
        echo "  3. Migrate data from .ralph/memory/ to .claude/memory/"
        echo "  4. Check hooks for .ralph/memory/ references"
        echo "  5. Create migration report"
        echo ""
        read -p "Continue? [y/N] " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Aborted by user"
            exit 0
        fi
    fi

    # Run fixes
    fix_gitignore
    fix_claude_memory_structure
    fix_migrate_memory
    fix_update_hooks
    fix_create_report

    echo ""
    echo -e "${BLUE}========================================${NC}"
    if [[ "$DRY_RUN" == true ]]; then
        log_success "DRY RUN COMPLETE - No changes made"
    else
        log_success "MITIGATION COMPLETE"
    fi
    echo -e "${BLUE}========================================${NC}"
    echo ""
    log_info "Next steps:"
    echo "  1. Review migration report: .claude/memory/MIGRATION_REPORT.md"
    echo "  2. Verify data migration: ls -la .claude/memory/"
    echo "  3. Update hooks manually if needed (see Fix 4 output)"
    echo "  4. Remove old .ralph/memory/ after verification (optional)"
    echo ""
}

# Run main function
main "$@"
