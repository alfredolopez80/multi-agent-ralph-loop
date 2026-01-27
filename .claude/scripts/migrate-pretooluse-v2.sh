#!/usr/bin/env bash
#===============================================================================
# PreToolUse Hook Migration Script v2.70.1 - Enhanced
# Migrates ALL variants of old format to new format
#===============================================================================

set -euo pipefail
umask 077

readonly VERSION="2.70.1"
readonly PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
readonly HOOKS_DIR="${PROJECT_ROOT}/.claude/hooks"
readonly BACKUP_DIR="${PROJECT_ROOT}/.claude/archive/pre-migration-v2.70.1-$(date +%Y%m%d-%H%M%S)"

# Hooks to migrate
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

MIGRATED=0

echo "================================================"
echo "PreToolUse Migration v${VERSION}"
echo "================================================"
echo ""

# Create backup
echo "Creating backup: ${BACKUP_DIR}"
mkdir -p "$BACKUP_DIR"
cp -R "$HOOKS_DIR"/* "$BACKUP_DIR/" 2>/dev/null || true
echo ""

# Function to migrate a single file
migrate_file() {
    local file=$1
    local name=$(basename "$file")
    local temp_file="${file}.tmp"

    echo -e "Processing: $name"

    # Check if file exists
    if [[ ! -f "$file" ]]; then
        echo "  SKIP: File not found"
        return 1
    fi

    # Check if file uses old format
    if ! grep -q '"decision".*"allow"' "$file"; then
        echo "  SKIP: Not using old format"
        return 0
    fi

    # Perform multiple replacements for all variants

    # Variant 1: echo '{"decision": "allow"}'
    sed 's/echo '"'{"decision": "allow"}'"'/echo '\''{"hookSpecificOutput": {"permissionDecision": "allow"}}'\''/g' "$file" > "$temp_file"

    # Variant 2: echo "{\"decision\": \"allow\"}"
    sed -i 's/echo "{\\\"decision\\\": \\\"allow\\\"}"/echo "{\"hookSpecificOutput\": {\"permissionDecision\": \"allow\"}}"/g' "$temp_file"

    # Variant 3: jq ... '{"decision": "allow", ...}'
    sed -i 's/"{\\\"decision\\\": \\\"allow\\\",\([^}]*\)}"/"{\\\hookSpecificOutput\\\": {\\\permissionDecision\\\": \\\allow\\\}, \1}"/g' "$temp_file"

    # Variant 4: trap 'echo "{\"decision\": \"allow\"}"' ERR EXIT
    sed -i "s/trap 'echo \"{\\\\\\"decision\\\\\\"\": \\\\\\\"allow\\\\\\"\"}'/trap 'echo \"{\\\\\\"hookSpecificOutput\\\\\\"\": {\\\\\\"permissionDecision\\\\\\"\": \\\\\\\"allow\\\\\\"}}\"'/g" "$temp_file"

    # Verify temp file is valid
    if [[ -s "$temp_file" ]]; then
        mv "$temp_file" "$file"
        echo "  SUCCESS: Migrated"
        ((MIGRATED++))
        return 0
    else
        rm -f "$temp_file"
        echo "  ERROR: Temp file empty"
        return 1
    fi
}

# Migrate each hook
for hook in "${HOOKS_TO_MIGRATE[@]}"; do
    migrate_file "$HOOKS_DIR/$hook" || true
done

echo ""
echo "================================================"
echo "Migration Complete"
echo "================================================"
echo "Migrated: $MIGRATED hooks"
echo ""

if [[ $MIGRATED -gt 0 ]]; then
    echo "Verifying migration..."
    local count=$(grep -l "hookSpecificOutput.*permissionDecision.*allow" "$HOOKS_DIR"/*.sh 2>/dev/null | wc -l | tr -d ' ')
    echo "Hooks with new format: $count"
fi

echo ""
echo "Backup location: $BACKUP_DIR"
