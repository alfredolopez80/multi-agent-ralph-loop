#!/bin/bash
# fix-statusline-context-tracking.sh - Fix context tracking in statusline-ralph.sh
#
# VERSION: 1.0.0
# Fixes GitHub Issue #13783: Statusline uses cumulative tokens instead of current usage
#
# Changes:
#   - Replace total_input_tokens/total_output_tokens with used_percentage
#   - Add fallback to current_usage calculation
#   - Add validation to clamp percentage to 0-100 range
#   - Create backup before modification
#
# Usage: ./fix-statusline-context-tracking.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATUSLINE_SCRIPT="${SCRIPT_DIR}/statusline-ralph.sh"
BACKUP_SCRIPT="${SCRIPT_DIR}/statusline-ralph.sh.backup.$(date +%Y%m%d-%H%M%S)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

# Check if script exists
if [[ ! -f "$STATUSLINE_SCRIPT" ]]; then
    error "Statusline script not found: $STATUSLINE_SCRIPT"
    exit 1
fi

log "Found statusline script: $STATUSLINE_SCRIPT"

# Create backup
log "Creating backup: $BACKUP_SCRIPT"
cp "$STATUSLINE_SCRIPT" "$BACKUP_SCRIPT"

# Define the old code (lines ~465-495)
OLD_CODE='# Get values
total_input=$(echo "$context_info" | jq -r '\''.total_input_tokens // 0'\'')
total_output=$(echo "$context_info" | jq -r '\''.total_output_tokens // 0'\'')
context_size=$(echo "$context_info" | jq -r '\''.context_window_size // 200000'\'')

# Calculate actual usage
if [[ "$context_size" -gt 0 ]]; then
    total_used=$((total_input + total_output))
    context_usage=$((total_used * 100 / context_size))'

# Define the new code (FIXED)
NEW_CODE='# FIX GitHub #13783: Use used_percentage instead of cumulative totals
# Method 1: Use pre-calculated percentage (RECOMMENDED)
context_usage=$(echo "$context_info" | jq -r '\''.used_percentage // 0'\'')

# Method 2: Fallback to current_usage calculation if used_percentage is null/0
if [[ -z "$context_usage" ]] || [[ "$context_usage" == "0" ]] || [[ "$context_usage" == "null" ]]; then
    # Calculate from current_usage object (actual tokens in context window)
    CURRENT_USAGE=$(echo "$context_info" | jq '\''.current_usage // empty'\'')

    if [[ "$CURRENT_USAGE" != "null" ]] && [[ -n "$CURRENT_USAGE" ]]; then
        # Sum actual tokens: input + cache_creation + cache_read
        CURRENT_TOKENS=$(echo "$CURRENT_USAGE" | jq '\''
            .input_tokens +
            (.cache_creation_input_tokens // 0) +
            (.cache_read_input_tokens // 0)
        '\'')

        context_size=$(echo "$context_info" | jq -r '\''.context_window_size // 200000'\'')

        if [[ "$context_size" -gt 0 ]]; then
            context_usage=$((CURRENT_TOKENS * 100 / context_size))
        fi
    fi
fi

# Validate: Clamp percentage to 0-100 range
if [[ -z "$context_usage" ]] || [[ "$context_usage" == "null" ]]; then
    context_usage=0
fi

# Ensure integer value
context_usage=${context_usage%.*}  # Remove decimal if present

# Clamp to valid range
if [[ $context_usage -lt 0 ]]; then
    context_usage=0
fi
if [[ $context_usage -gt 100 ]]; then
    context_usage=100
fi'

# Apply the fix
log "Applying fix to statusline script..."

# Use sed to replace the old code with new code
# Note: Using delimiter | to avoid conflicts with / in paths
if sed -i.tmp \
    -e "/# Get values/,/context_usage=/c\\
$NEW_CODE" \
    "$STATUSLINE_SCRIPT" 2>/dev/null; then

    # Clean up temp file
    rm -f "${STATUSLINE_SCRIPT}.tmp"

    log "Fix applied successfully!"
else
    error "Failed to apply fix using sed"
    log "Restoring from backup..."
    cp "$BACKUP_SCRIPT" "$STATUSLINE_SCRIPT"
    exit 1
fi

# Verify the fix was applied
log "Verifying fix..."
if grep -q "FIX GitHub #13783" "$STATUSLINE_SCRIPT"; then
    log "✓ Fix comment found in script"
else
    warn "Fix comment not found - may need manual verification"
fi

if grep -q "used_percentage" "$STATUSLINE_SCRIPT"; then
    log "✓ used_percentage field is now used"
else
    warn "used_percentage field not found - may need manual verification"
fi

if grep -q "Clamp percentage to 0-100" "$STATUSLINE_SCRIPT"; then
    log "✓ Validation code added"
else
    warn "Validation code not found - may need manual verification"
fi

# Summary
echo ""
log "=== Fix Summary ==="
log "Backup saved to: $BACKUP_SCRIPT"
log "Fixed script: $STATUSLINE_SCRIPT"
echo ""
log "Changes made:"
log "  1. Replaced total_input_tokens/total_output_tokens with used_percentage"
log "  2. Added fallback to current_usage calculation"
log "  3. Added validation to clamp percentage to 0-100 range"
log "  4. Added detailed comments explaining the fix"
echo ""
log "To restore the original version:"
log "  cp $BACKUP_SCRIPT $STATUSLINE_SCRIPT"
echo ""
log "To test the fix:"
log "  1. Restart Claude Code"
log "  2. Check the statusline shows correct percentage"
log "  3. Run /clear and verify percentage resets appropriately"
echo ""
