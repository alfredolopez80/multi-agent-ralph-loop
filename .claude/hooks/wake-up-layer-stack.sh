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
REPO_DIR="~/Documents/GitHub/multi-agent-ralph-loop"
LIB_DIR="${REPO_DIR}/.claude/lib"
LOG_FILE="${HOME}/.ralph/logs/wake-up-layer-stack.log"
L0_PATH="${HOME}/.ralph/layers/L0_identity.md"
L1_PATH="${HOME}/.ralph/layers/L1_essential.md"

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
# Compose context (L0 + L1)
# ---------------------------------------------------------------------------
CONTEXT="## Ralph Layer Stack — Session Wake-Up

### Identity (L0)

${L0_CONTENT}

---

### Essential Rules (L1)

${L1_CONTENT}

---

*Layer stack loaded at $(date -u +"%Y-%m-%dT%H:%M:%SZ") | L2/L3 available on-demand*"

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
