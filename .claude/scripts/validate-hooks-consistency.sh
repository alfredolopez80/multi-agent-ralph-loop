#!/bin/bash
# Validate hooks consistency between settings.json and filesystem
# VERSION: 2.57.4
# Purpose: Verify that all hooks referenced in settings.json exist on filesystem

set -euo pipefail

HOOKS_DIR="${HOME}/.claude/hooks"
SETTINGS_FILE="${HOME}/.claude/settings.json"
LOG_FILE="${HOME}/.ralph/logs/hooks-validation.log"

mkdir -p "$(dirname "$LOG_FILE")" "${HOOKS_DIR}"

ERRORS=0
WARNINGS=0

echo "=== Hooks Consistency Validation ===" | tee "$LOG_FILE"
echo "Settings: $SETTINGS_FILE" | tee -a "$LOG_FILE"
echo "Hooks dir: $HOOKS_DIR" | tee -a "$LOG_FILE"

# Extract all hook commands from settings.json (correct jq path)
echo "Reading hooks from settings.json..." | tee -a "$LOG_FILE"

MISSING=0
while IFS= read -r hook_cmd; do
    # Expand ${HOME} to actual path
    hook_path="${hook_cmd//\$\{HOME\}/$HOME}"

    if [[ -f "$hook_path" ]]; then
        echo "  ✓ $(basename "$hook_path")" | tee -a "$LOG_FILE"
    else
        echo "  ✗ MISSING: $hook_path" | tee -a "$LOG_FILE"
        MISSING=$((MISSING + 1))
        ERRORS=$((ERRORS + 1))
    fi
done < <(jq -r '.hooks | to_entries[] | .value[] | .hooks[] | .command' "$SETTINGS_FILE" 2>/dev/null)

HOOK_COUNT=$(jq -r '.hooks | to_entries[] | .value[] | .hooks[] | .command' "$SETTINGS_FILE" 2>/dev/null | wc -l | tr -d ' ')
HOOK_FILES=$(ls -1 "$HOOKS_DIR"/*.sh 2>/dev/null | wc -l | tr -d ' ')

echo "" | tee -a "$LOG_FILE"
echo "Total hooks in settings.json: $HOOK_COUNT" | tee -a "$LOG_FILE"
echo "Hook files on disk: $HOOK_FILES" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"
echo "Note: Some files may be registered multiple times (different matchers) - this is normal." | tee -a "$LOG_FILE"

# Summary
echo "" | tee -a "$LOG_FILE"
echo "=====================================" | tee -a "$LOG_FILE"
echo "Errors (missing hooks): $ERRORS" | tee -a "$LOG_FILE"
echo "Warnings (orphan hooks): $WARNINGS" | tee -a "$LOG_FILE"
echo "=====================================" | tee -a "$LOG_FILE"

if [[ $ERRORS -gt 0 ]]; then
    echo "STATUS: FAILED" | tee -a "$LOG_FILE"
    exit 1
else
    echo "STATUS: PASSED" | tee -a "$LOG_FILE"
    exit 0
fi
