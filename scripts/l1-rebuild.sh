#!/usr/bin/env bash
# l1-rebuild.sh — Daily L1 essential rules rebuild
# VERSION: 1.0.0
#
# Runs automatically via cron (6:00 AM daily) or triggered after curator runs.
# Rebuilds L1_essential.md from rules.json with improved scoring pipeline.
#
# Features:
#   - Lock file prevents concurrent runs
#   - Idempotent: checks if rules.json changed since last rebuild
#   - Logging to ~/.ralph/logs/l1-rebuild.log
#
# Usage:
#   bash scripts/l1-rebuild.sh              # Manual run
#   python3 .claude/lib/layers.py --install-cron  # Install cron

set -euo pipefail

# --- Configuration ---
LOCK_FILE="/tmp/l1-rebuild.lock"
LOG_DIR="${HOME}/.ralph/logs"
LOG_FILE="${LOG_DIR}/l1-rebuild.log"
RULES_JSON="${HOME}/.ralph/procedural/rules.json"
L1_OUTPUT="${HOME}/.ralph/layers/L1_essential.md"
STATE_FILE="${HOME}/.ralph/layers/.l1-last-rebuild"
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
LAYERS_PY="${REPO_DIR}/.claude/lib/layers.py"

# --- Logging ---
log() {
    echo "[$(date -Iseconds)] l1-rebuild: $*" | tee -a "$LOG_FILE" 2>/dev/null || true
}

# --- Setup ---
mkdir -p "$LOG_DIR" "${HOME}/.ralph/layers"

# --- Lock file ---
if [ -f "$LOCK_FILE" ]; then
    # Check if lock is stale (>10 minutes old)
    if [ "$(uname)" = "Darwin" ]; then
        lock_age=$(( $(date +%s) - $(stat -f %m "$LOCK_FILE" 2>/dev/null || echo 0) ))
    else
        lock_age=$(( $(date +%s) - $(stat -c %Y "$LOCK_FILE" 2>/dev/null || echo 0) ))
    fi
    if [ "$lock_age" -gt 600 ]; then
        log "WARN: Stale lock file (${lock_age}s old), removing"
        rm -f "$LOCK_FILE"
    else
        log "INFO: Another rebuild running (lock file ${lock_age}s old), exiting"
        exit 0
    fi
fi
trap 'rm -f "$LOCK_FILE"' EXIT
echo $$ > "$LOCK_FILE"

# --- Idempotency check ---
if [ -f "$RULES_JSON" ] && [ -f "$STATE_FILE" ] && [ -f "$L1_OUTPUT" ]; then
    current_hash="$(shasum "$RULES_JSON" 2>/dev/null | cut -d' ' -f1 || echo 'unknown')"
    last_hash="$(cat "$STATE_FILE" 2>/dev/null || echo 'none')"
    if [ "$current_hash" = "$last_hash" ]; then
        log "INFO: rules.json unchanged (hash: ${current_hash:0:8}...), skipping rebuild"
        exit 0
    fi
fi

# --- Rebuild ---
log "INFO: Starting L1 rebuild from ${RULES_JSON}"

if [ ! -f "$LAYERS_PY" ]; then
    log "ERROR: layers.py not found at ${LAYERS_PY}"
    exit 1
fi

python3 "$LAYERS_PY" --build-l1 2>&1 | while IFS= read -r line; do
    log "BUILD: $line"
done

# --- Record state ---
if [ -f "$RULES_JSON" ]; then
    shasum "$RULES_JSON" | cut -d' ' -f1 > "$STATE_FILE"
fi

# --- Verify ---
if [ -f "$L1_OUTPUT" ]; then
    rule_count=$(grep -c "^## " "$L1_OUTPUT" 2>/dev/null || echo 0)
    token_est=$(( $(wc -c < "$L1_OUTPUT" 2>/dev/null || echo 0) / 4 ))
    log "INFO: Rebuild complete — ${rule_count} rules, ~${token_est} estimated tokens"
else
    log "ERROR: L1 output not created at ${L1_OUTPUT}"
    exit 1
fi
