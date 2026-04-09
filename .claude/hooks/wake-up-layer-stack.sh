#!/bin/bash
# wake-up-layer-stack.sh — SessionStart Hook, Wave 2.2 Layer Stack
# ================================================================
#
# Event: SessionStart
# Wave:  W2.2 (layer-stack)
# Plan:  .ralph/plans/cheeky-dazzling-catmull.md
#
# Loads only L0 (identity) + L1 (essential rules) at session start.
# Target: <1500 tokens total wake-up cost.
#
# Activation: NOT yet registered in settings.json (W4.2 hook-consolidation
#             will activate this hook and retire session-start-restore-context.sh).
#
# Input (JSON via stdin):
#   - hook_event_name: "SessionStart"
#   - session_id: session identifier
#
# Output (JSON via stdout):
#   {
#     "hookSpecificOutput": {
#       "hookEventName": "SessionStart",
#       "additionalContext": "<L0 + L1 content>"
#     }
#   }
#
# Format reference: tests/HOOK_FORMAT_REFERENCE.md
# SessionStart hooks use hookSpecificOutput.additionalContext per official docs.
#
# VERSION: 1.0.0
# CREATED: 2026-04-07

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
REPO_DIR="${HOME}/Documents/GitHub/multi-agent-ralph-loop"
LIB_DIR="${REPO_DIR}/.claude/lib"
LOG_FILE="${HOME}/.ralph/logs/wake-up-layer-stack.log"
L0_PATH="${HOME}/.ralph/layers/L0_identity.md"
L1_PATH="${HOME}/.ralph/layers/L1_essential.md"
VAULT_DIR="${HOME}/Documents/Obsidian/MiVault"
VAULT_INDEX="${VAULT_DIR}/_vault-index.md"
L2_DIR="${HOME}/.ralph/layers/L2_wings"
LINT_REPORT_DIR="${VAULT_DIR}/global/output/reports"

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
mkdir -p "${HOME}/.ralph/logs"

log() {
    echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] wake-up-layer-stack: $*" >> "$LOG_FILE" 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# Read stdin (SEC-111: limit to 100KB to prevent DoS)
# ---------------------------------------------------------------------------
INPUT=$(head -c 100000)

SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null || echo "unknown")
SESSION_ID=$(echo "$SESSION_ID" | tr -cd 'a-zA-Z0-9_-' | head -c 64)
[[ -z "$SESSION_ID" ]] && SESSION_ID="unknown"

log "INFO SessionStart triggered session=${SESSION_ID}"

# ---------------------------------------------------------------------------
# Load L0 — Identity
# ---------------------------------------------------------------------------
L0_CONTENT=""
if [[ -f "$L0_PATH" ]]; then
    L0_CONTENT=$(cat "$L0_PATH" 2>/dev/null || echo "")
    log "INFO L0 loaded chars=${#L0_CONTENT}"
else
    L0_CONTENT="[L0 identity file missing at ${L0_PATH}]"
    log "WARN L0 file not found at ${L0_PATH}"
fi

# ---------------------------------------------------------------------------
# Load L1 — Essential rules (plain markdown, no decoding needed)
# Note: Original W2.2 design used AAAK encoding here, but cl100k_base
# measurement showed AAAK INCREASED tokens by ~20%. Plain markdown is now
# canonical. See docs/architecture/AAAK_LIMITATIONS_ADR_2026-04-07.md.
# ---------------------------------------------------------------------------
L1_CONTENT=""
if [[ -f "$L1_PATH" ]]; then
    L1_CONTENT=$(cat "$L1_PATH" 2>/dev/null || echo "")
    log "INFO L1 loaded chars=${#L1_CONTENT}"
else
    L1_CONTENT="[L1 not built — run: python3 -c \"import sys; sys.path.insert(0, '${LIB_DIR}'); from layers import Layer1; Layer1().build()\"]"
    log "WARN L1 file not found at ${L1_PATH}"
fi

# ---------------------------------------------------------------------------
# Load Vault Stats (from _vault-index.md)
# W1.1: Karpathy-style vault context at wake-up
# ---------------------------------------------------------------------------
VAULT_STATS=""
if [[ -f "$VAULT_INDEX" ]]; then
    # Extract only the ## Statistics section (first 8 lines after that header)
    VAULT_STATS=$(sed -n '/^## Statistics/,/^## /{ /^## Statistics/p; /^## /!p; }' "$VAULT_INDEX" 2>/dev/null | head -8 || echo "")
    if [[ -n "$VAULT_STATS" ]]; then
        log "INFO vault stats loaded chars=${#VAULT_STATS}"
    fi
else
    log "WARN vault index not found at ${VAULT_INDEX}"
fi

# ---------------------------------------------------------------------------
# Load L2 Wing Summary (project-specific context, if exists)
# W2.2: Auto-compiled project context from facts/decisions
# ---------------------------------------------------------------------------
WING_SUMMARY=""
PROJECT_NAME=""
if command -v git &>/dev/null; then
    PROJECT_NAME=$(basename "$(git -C "${REPO_DIR}" rev-parse --show-toplevel 2>/dev/null || echo "")" 2>/dev/null || echo "")
fi
if [[ -n "$PROJECT_NAME" && -f "${L2_DIR}/${PROJECT_NAME}/context.md" ]]; then
    WING_SUMMARY=$(head -20 "${L2_DIR}/${PROJECT_NAME}/context.md" 2>/dev/null || echo "")
    if [[ -n "$WING_SUMMARY" ]]; then
        log "INFO L2 wing loaded project=${PROJECT_NAME} chars=${#WING_SUMMARY}"
    fi
fi

# ---------------------------------------------------------------------------
# Load Lint Summary (if vault lint ran yesterday)
# W5.3: One-line lint health check
# ---------------------------------------------------------------------------
LINT_SUMMARY=""
YESTERDAY=$(date -u -v-1d +"%Y-%m-%d" 2>/dev/null || date -u -d "yesterday" +"%Y-%m-%d" 2>/dev/null || echo "")
if [[ -n "$YESTERDAY" && -f "${LINT_REPORT_DIR}/vault-lint-${YESTERDAY}.md" ]]; then
    LINT_ORPHANS=$(grep -c "orphan" "${LINT_REPORT_DIR}/vault-lint-${YESTERDAY}.md" 2>/dev/null || echo "0")
    LINT_STALE=$(grep -c "stale" "${LINT_REPORT_DIR}/vault-lint-${YESTERDAY}.md" 2>/dev/null || echo "0")
    LINT_CONFLICTS=$(grep -c "contradiction" "${LINT_REPORT_DIR}/vault-lint-${YESTERDAY}.md" 2>/dev/null || echo "0")
    LINT_SUMMARY="Vault lint (${YESTERDAY}): ${LINT_ORPHANS} orphans, ${LINT_STALE} stale, ${LINT_CONFLICTS} contradictions"
    log "INFO lint summary loaded: ${LINT_SUMMARY}"
fi

# ---------------------------------------------------------------------------
# Compose context (L0 + L1 + Vault Stats + Wing + Lint)
# ---------------------------------------------------------------------------
EXTRA_SECTIONS=""

if [[ -n "$VAULT_STATS" ]]; then
    EXTRA_SECTIONS="${EXTRA_SECTIONS}

### Vault Stats
${VAULT_STATS}

"
fi

if [[ -n "$WING_SUMMARY" ]]; then
    EXTRA_SECTIONS="${EXTRA_SECTIONS}

### Project Wing (L2): ${PROJECT_NAME}
${WING_SUMMARY}

"
fi

if [[ -n "$LINT_SUMMARY" ]]; then
    EXTRA_SECTIONS="${EXTRA_SECTIONS}

### Vault Health
${LINT_SUMMARY}

"
fi

CONTEXT="## Ralph Layer Stack — Session Wake-Up

### Identity (L0)

${L0_CONTENT}

---

### Essential Rules (L1)

${L1_CONTENT}
${EXTRA_SECTIONS}
---

*Layer stack loaded at $(date -u +"%Y-%m-%dT%H:%M:%SZ") | Living Wiki v4.0 | Karpathy cycle: INGEST→QUERY→WRITEBACK→LINT*"

log "INFO context composed chars=${#CONTEXT}"

# ---------------------------------------------------------------------------
# Measure token estimate and log it
# ---------------------------------------------------------------------------
WORD_COUNT=$(echo "$CONTEXT" | wc -w | tr -d ' ')
TOKEN_ESTIMATE=$(( (WORD_COUNT * 4 + 2) / 3 ))  # wc -w / 0.75 ≈ * 4/3
log "INFO token_estimate words=${WORD_COUNT} tokens~=${TOKEN_ESTIMATE} target=1500"

# ---------------------------------------------------------------------------
# Output SessionStart hook JSON
# Per tests/HOOK_FORMAT_REFERENCE.md:
#   SessionStart format: {"hookSpecificOutput": {"additionalContext": "..."}}
# ---------------------------------------------------------------------------
jq -n \
    --arg ctx "$CONTEXT" \
    --arg sess "$SESSION_ID" \
    --argjson tokens "$TOKEN_ESTIMATE" \
    '{
        "hookSpecificOutput": {
            "hookEventName": "SessionStart",
            "additionalContext": $ctx,
            "_meta": {
                "hook": "wake-up-layer-stack",
                "wave": "W2.2",
                "session_id": $sess,
                "token_estimate": $tokens,
                "layers_loaded": ["L0", "L1"]
            }
        }
    }'

log "INFO hook completed token_estimate=${TOKEN_ESTIMATE}"
