#!/usr/bin/env bash
#===============================================================================
# Hook Format Migration Script (v2.70.0)
# Migrates PreToolUse hooks from old format to new format
#===============================================================================

set -euo pipefail
umask 077

readonly VERSION="2.70.0"
readonly SCRIPT_NAME=$(basename "$0")
readonly PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
readonly HOOKS_DIR="${PROJECT_ROOT}/.claude/hooks"
readonly BACKUP_DIR="${PROJECT_ROOT}/.claude/archive/pre-migration-v2.70.0-$(date +%Y%m%d-%H%M%S)"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Dry run flag
DRY_RUN=${DRY_RUN:-false}

# Migration log
MIGRATED=0
SKIPPED=0
ERROR=0

# Print usage
usage() {
    cat <<EOF
Usage: $SCRIPT_NAME [OPTIONS]

Migrate PreToolUse hooks from old format to new format.

Old format: {"decision": "allow"}
New format: {"hookSpecificOutput": {"permissionDecision": "allow"}}

OPTIONS:
    -h, --help      Show this help message
    -d, --dry-run   Show what would be changed without making changes
    -y, --yes       Skip confirmation prompt

EXAMPLES:
    $SCRIPT_NAME --dry-run    # Preview changes
    $SCRIPT_NAME --yes        # Migrate without prompting

EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            exit 0
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -y|--yes)
            SKIP_CONFIRM=true
            shift
            ;;
        *)
            echo -e "${RED}ERROR: Unknown option: $1${NC}"
            usage
            exit 1
            ;;
    esac
done

# Print header
echo "================================================"
echo "Hook Format Migration v${VERSION}"
echo "================================================"
echo ""

# Check if hooks directory exists
if [[ ! -d "$HOOKS_DIR" ]]; then
    echo -e "${RED}ERROR: Hooks directory not found: ${HOOKS_DIR}${NC}"
    exit 1
fi

# Create backup directory
if [[ "$DRY_RUN" != "true" ]]; then
    echo "Creating backup: ${BACKUP_DIR}"
    mkdir -p "$BACKUP_DIR"

    # Backup all hooks
    cp -R "$HOOKS_DIR"/* "$BACKUP_DIR/" 2>/dev/null || true
    echo -e "${GREEN}Backup created${NC}"
    echo ""
fi

# Hooks to migrate (PreToolUse hooks using old format)
readonly HOOKS_TO_MIGRATE=(
    "lsa-pre-step.sh"
    "repo-boundary-guard.sh"
    "fast-path-check.sh"
    "smart-memory-search.sh"
    "skill-validator.sh"
    "procedural-inject.sh"
    "checkpoint-smart-save.sh"
    "checkpoint-auto-save.sh"
    "git-safety-guard.py"
    "smart-skill-reminder.sh"
    "orchestrator-auto-learn.sh"
    "task-orchestration-optimizer.sh"
    "inject-session-context.sh"
)

echo "Hooks to migrate:"
for hook in "${HOOKS_TO_MIGRATE[@]}"; do
    if [[ -f "$HOOKS_DIR/$hook" ]]; then
        echo "  - $hook"
    fi
done
echo ""

# Function to migrate a hook
migrate_hook() {
    local hook_file=$1
    local hook_name=$(basename "$hook_file")
    local temp_file="${hook_file}.tmp"

    echo -e "${BLUE}Processing: $hook_name${NC}"

    # Check if file exists
    if [[ ! -f "$hook_file" ]]; then
        echo -e "${YELLOW}SKIP${NC}: File not found: $hook_file"
        ((SKIPPED++))
        return 1
    fi

    # Check if using old format
    if ! grep -q '{"decision": "allow"}' "$hook_file"; then
        echo -e "${YELLOW}SKIP${NC}: Not using old format"
        ((SKIPPED++))
        return 0
    fi

    # Perform migration
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${YELLOW}[DRY RUN]${NC} Would replace:"
        echo '  {"decision": "allow"}'
        echo '  With:'
        echo '  {"hookSpecificOutput": {"permissionDecision": "allow"}}'
    else
        # Create temp file with replacements
        sed 's/"{"decision": "allow"}"/"{\"hookSpecificOutput\": {\"permissionDecision\": \"allow\"}}"/g' "$hook_file" > "$temp_file"

        # Handle additionalContext variant
        sed -i.tmp 's/"{"decision": "allow", "additionalContext":/"{\\"hookSpecificOutput\\": {\\"permissionDecision\\": \\"allow\\", \\"additionalContext\\":/g' "$temp_file"
        rm -f "${temp_file}.tmp"

        # Verify the temp file is valid
        if [[ -s "$temp_file" ]]; then
            mv "$temp_file" "$hook_file"
            echo -e "${GREEN}SUCCESS${NC}: Migrated $hook_name"
            ((MIGRATED++))
        else
            rm -f "$temp_file"
            echo -e "${RED}ERROR${NC}: Failed to migrate $hook_name (temp file empty)"
            ((ERROR++))
            return 1
        fi
    fi

    return 0
}

# Confirm migration
if [[ "$DRY_RUN" != "true" && "${SKIP_CONFIRM:-}" != "true" ]]; then
    echo -e "${YELLOW}This will modify ${#HOOKS_TO_MIGRATE[@]} hook files.${NC}"
    echo "A backup has been created at: ${BACKUP_DIR}"
    echo ""
    read -p "Continue? (y/N) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Migration cancelled."
        exit 0
    fi
fi

# Migrate each hook
for hook in "${HOOKS_TO_MIGRATE[@]}"; do
    migrate_hook "$HOOKS_DIR/$hook" || true
done

# Summary
echo ""
echo "================================================"
echo "Migration Summary"
echo "================================================"
echo -e "Migrated: ${GREEN}${MIGRATED}${NC}"
echo -e "Skipped:  ${YELLOW}${SKIPPED}${NC}"
echo -e "Errors:   ${RED}${ERROR}${NC}"
echo ""

if [[ "$DRY_RUN" == "true" ]]; then
    echo -e "${YELLOW}DRY RUN COMPLETE${NC}"
    echo "Run without --dry-run to apply changes."
    exit 0
fi

if [[ $ERROR -gt 0 ]]; then
    echo -e "${RED}Migration completed with errors${NC}"
    echo "Please review the errors above."
    exit 1
elif [[ $MIGRATED -gt 0 ]]; then
    echo -e "${GREEN}Migration completed successfully${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Run tests: bash .claude/scripts/validate-hook-formats.sh"
    echo "2. Test hooks: Run a Claude Code session"
    echo "3. Commit changes if everything works"
    echo ""
    echo "To restore backup if needed:"
    echo "  cp -r ${BACKUP_DIR}/* ${HOOKS_DIR}/"
    exit 0
else
    echo -e "${YELLOW}No migrations needed${NC}"
    exit 0
fi
