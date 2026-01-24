#!/bin/bash
# ============================================================================
# procedural-forget.sh - v2.59.2
# Hook: UserPromptSubmit (manual trigger) or scheduled via cron
# Purpose: Remove obsolete/low-quality patterns from procedural memory
#
# v2.59.2: FIXED - Proper jq filter (removed "or true" bug), ISO8601 date parsing
# GAP-G04: "No forgetting mechanism - obsolete/low-quality patterns persist"
#
# Removal criteria:
# 1. usage_count == 0 after 30 days (never used)
# 2. confidence < 0.5 (low confidence patterns)
# 3. age > 90 days AND usage_count < 2 (rarely used old patterns)
# ============================================================================

set -euo pipefail
umask 077

# Paths
PROCEDURAL_FILE="${HOME}/.ralph/procedural/rules.json"
BACKUP_DIR="${HOME}/.ralph/procedural/backup"
LOG_DIR="${HOME}/.ralph/logs"
TEMP_FILE="${PROCEDURAL_FILE}.forget.$$"

# Create directories
mkdir -p "$BACKUP_DIR" "$LOG_DIR"

# Logging
log() {
    echo "[procedural-forget] $(date -Iseconds): $1" >> "${LOG_DIR}/procedural-forget.log" 2>&1
}

log "=== Starting procedural memory cleanup ==="

# Check if rules file exists
if [[ ! -f "$PROCEDURAL_FILE" ]]; then
    log "No rules file found, skipping cleanup"
    exit 0
fi

# Count rules before cleanup
BEFORE_COUNT=$(jq -r '.rules | length // 0' "$PROCEDURAL_FILE" 2>/dev/null || echo "0")
log "Rules before cleanup: $BEFORE_COUNT"

# Backup current rules
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/rules_${TIMESTAMP}.json.bak"
cp "$PROCEDURAL_FILE" "$BACKUP_FILE"
log "Backup saved: $BACKUP_FILE"

# Calculate cutoff dates
CUTOFF_30_DAYS_AGO=$(date -d "30 days ago" +%s 2>/dev/null || date -u -v-30d +%s 2>/dev/null || echo "0")
CUTOFF_90_DAYS_AGO=$(date -d "90 days ago" +%s 2>/dev/null || date -u -v-90d +%s 2>/dev/null || echo "0")

# Get current timestamp for rule age calculation
NOW_TS=$(date +%s)

# Function to convert ISO8601 to epoch
iso8601_to_epoch() {
    local ts="$1"
    # macOS date -j -f, fallback to Linux date -d
    if [[ "$ts" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2} ]]; then
        date -j -f "%Y-%m-%dT%H:%M:%S" "${ts:0:19}" +%s 2>/dev/null || \
        date -d "${ts:0:19}" +%s 2>/dev/null || \
        echo "0"
    else
        echo "$ts"
    fi
}

# Function to check if rule should be removed
should_remove() {
    local rule="$1"
    local confidence usage_count created_ts age_days

    confidence=$(echo "$rule" | jq -r '.confidence // 0' 2>/dev/null || echo "0")
    usage_count=$(echo "$rule" | jq -r '.usage_count // 0' 2>/dev/null || echo "0")
    created_ts=$(echo "$rule" | jq -r '.created_at // "0"' 2>/dev/null || echo "0")

    # Convert ISO8601 to epoch if needed
    if [[ ! "$created_ts" =~ ^[0-9]+$ ]]; then
        created_ts=$(iso8601_to_epoch "$created_ts")
    fi

    # Calculate age in days
    if [[ "$created_ts" =~ ^[0-9]+$ ]] && [[ "$created_ts" -gt 0 ]]; then
        age_days=$(( (NOW_TS - created_ts) / 86400 ))
    else
        age_days=0
    fi

    # Rule 1: Never used after 30 days
    if [[ $usage_count -eq 0 ]] && [[ $age_days -gt 30 ]]; then
        return 0
    fi

    # Rule 2: Low confidence
    if (( $(echo "$confidence < 0.5" | bc -l 2>/dev/null || echo "0") )); then
        return 0
    fi

    # Rule 3: Old and rarely used
    if [[ $age_days -gt 90 ]] && [[ $usage_count -lt 2 ]]; then
        return 0
    fi

    return 1
}

# Count rules to remove
REMOVE_COUNT=0
while IFS= read -r rule; do
    [[ -z "$rule" ]] && continue
    if should_remove "$rule"; then
        REMOVE_COUNT=$((REMOVE_COUNT + 1))
    fi
done < <(jq -c '.rules[]' "$PROCEDURAL_FILE" 2>/dev/null)

log "Rules to remove: $REMOVE_COUNT"

# If too many rules to remove (>20%), require confirmation or log warning
if [[ $REMOVE_COUNT -gt 0 ]]; then
    TOTAL_RULES=$(jq -r '.rules | length // 0' "$PROCEDURAL_FILE" 2>/dev/null || echo "0")
    REMOVE_PCT=$((REMOVE_COUNT * 100 / TOTAL_RULES))

    if [[ $REMOVE_PCT -gt 20 ]]; then
        log "WARNING: Removing $REMOVE_PCT% of rules ($REMOVE_COUNT/$TOTAL_RULES)"
        log "This is more than 20% - consider reviewing backup before proceeding"
    fi
fi

# FIXED v2.59.2: Use should_remove function to filter rules properly
# Previously had "or true" bug that kept all rules
REMOVE_COUNT=0
RULES_TO_KEEP=""
while IFS= read -r rule; do
    [[ -z "$rule" ]] && continue
    if should_remove "$rule"; then
        REMOVE_COUNT=$((REMOVE_COUNT + 1))
    else
        if [[ -n "$RULES_TO_KEEP" ]]; then
            RULES_TO_KEEP="${RULES_TO_KEEP},${rule}"
        else
            RULES_TO_KEEP="${rule}"
        fi
    fi
done < <(jq -c '.rules[]' "$PROCEDURAL_FILE" 2>/dev/null)

# Rebuild rules array from kept rules
if [[ -n "$RULES_TO_KEEP" ]]; then
    jq --argjson rules "[${RULES_TO_KEEP}]" '.rules = $rules' "$PROCEDURAL_FILE" > "$TEMP_FILE" 2>/dev/null
else
    jq '.rules = []' "$PROCEDURAL_FILE" > "$TEMP_FILE" 2>/dev/null
fi

# If jq succeeds, replace the file
if [[ -s "$TEMP_FILE" ]]; then
    mv "$TEMP_FILE" "$PROCEDURAL_FILE"
    log "Cleanup completed successfully"
else
    log "ERROR: Cleanup failed, restoring backup"
    cp "$BACKUP_FILE" "$PROCEDURAL_FILE"
    rm -f "$TEMP_FILE"
    exit 1
fi

# Count rules after cleanup
AFTER_COUNT=$(jq -r '.rules | length // 0' "$PROCEDURAL_FILE" 2>/dev/null || echo "0")
REMOVED=$((BEFORE_COUNT - AFTER_COUNT))

log "Rules after cleanup: $AFTER_COUNT"
log "Total removed: $REMOVED"

# Cleanup old backups (keep last 10)
ls -t "${BACKUP_DIR}"/rules_*.json.bak 2>/dev/null | tail -n +11 | xargs rm -f 2>/dev/null || true
log "Old backups cleaned up"

log "=== Procedural memory cleanup complete ==="

# Output summary
echo "{\"removed\": $REMOVED, \"before\": $BEFORE_COUNT, \"after\": $AFTER_COUNT}"
